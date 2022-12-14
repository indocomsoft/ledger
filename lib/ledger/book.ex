defmodule Ledger.Book do
  @moduledoc """
  The Book context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Ledger.Repo

  alias Ledger.Book.Account
  alias Ledger.Book.Split
  alias Ledger.Book.Transaction
  alias Ledger.Users.User

  @doc """
  Creates or get the root account for the given user.

  There should only ever be 1 root account for a given user, validated on the DB layer too.
  """
  @spec create_or_get_root_account_for_user!(User.t()) :: Account.t()
  def create_or_get_root_account_for_user!(user = %User{id: user_id}) do
    Account
    |> where(user_id: ^user_id, account_type: :root)
    |> Repo.one()
    |> case do
      nil -> Account.create_root_account_for_user_changeset(user) |> Repo.insert!()
      account -> account
    end
  end

  @spec create_child_account(Account.t(), map()) :: {:ok, Account.t()} | {:error, term()}
  def create_child_account(parent_account = %Account{}, attrs) do
    Account.child_account_changeset(parent_account, attrs)
    |> Repo.insert()
  end

  @spec all_accounts_for_user(User.t()) :: [Account.t(), ...]
  def all_accounts_for_user(user = %User{id: user_id}) do
    Account
    |> where(user_id: ^user_id)
    |> join(:left, [a], p in assoc(a, :parent))
    |> preload([a, p], parent: p)
    |> Repo.all()
    |> case do
      [] -> [create_or_get_root_account_for_user!(user)]
      accounts -> accounts
    end
  end

  @spec get_account_by_external_id(binary()) :: Account.t() | nil
  def get_account_by_external_id(external_id) do
    Account
    |> where(external_id: ^external_id)
    |> join(:left, [a], p in assoc(a, :parent))
    |> preload([a, p], parent: p)
    |> Repo.one()
  end

  @spec update_account(Account.t(), map()) ::
          {:ok, Account.t()} | {:error, :root | Ecto.Changeset.t()}
  def update_account(%Account{account_type: :root}, _attrs) do
    {:error, :root}
  end

  def update_account(account = %Account{}, attrs) do
    account
    |> Account.update_changeset(attrs)
    |> Repo.update()
  end

  @spec update_account_parent_id(Account.t(), Account.t()) ::
          {:ok, Account.t()} | {:error, term()}
  def update_account_parent_id(
        account = %Account{id: id},
        parent_account = %Account{id: new_parent_id}
      ) do
    Repo.transaction(fn ->
      initial_query = Account |> where(id: ^id)

      recursion_query =
        Account |> join(:inner, [a], s in "self_and_descendants", on: a.parent_id == s.id)

      query = initial_query |> union_all(^recursion_query)

      self_and_descendants =
        "self_and_descendants"
        |> recursive_ctes(true)
        |> with_cte("self_and_descendants", as: ^query)
        |> select([s], s.id)
        |> Repo.all()

      if new_parent_id in self_and_descendants do
        Repo.rollback(:in_self_and_descendants)
      else
        account
        |> change()
        |> Account.put_parent_assoc(parent_account)
        |> Repo.update()
        |> case do
          {:ok, account} -> account
          {:error, error} -> Repo.rollback(error)
        end
      end
    end)
  end

  @spec delete_account(Account.t()) :: {:ok, Account.t()} | {:error, :root | Ecto.Changeset.t()}
  def delete_account(%Account{account_type: :root}) do
    {:error, :root}
  end

  def delete_account(account = %Account{}) do
    # TODO prevent deletion when account is referenced in splits
    # but honestly this can probably be implemented in the DB layer ON DELETE RESTRICT
    account
    |> change()
    |> no_assoc_constraint(:children, name: "accounts_parent_id_fkey")
    |> Repo.delete()
    |> case do
      {:ok, account} ->
        {:ok, account}

      {:error, changeset = %Ecto.Changeset{errors: errors}} ->
        case errors[:children] do
          {_, [constraint: :no_assoc, constraint_name: "accounts_parent_id_fkey"]} ->
            {:error, :has_children}

          _ ->
            {:error, changeset}
        end
    end
  end

  @spec create_transaction_and_splits(User.t(), map(), [{map(), Account.t()}]) ::
          {:ok, %{transaction: Transaction.t(), splits: [Split.t()]}}
          | {:error, :transaction | :splits, :placeholder | :splits_sum | Ecto.Changeset.t(),
             map()}
  def create_transaction_and_splits(user = %User{}, transaction_attrs, splits_attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:transaction, Transaction.create_changeset(transaction_attrs, user))
    |> Ecto.Multi.run(:splits, fn _repo, %{transaction: transaction} ->
      splits_or_changeset =
        Enum.reduce_while(splits_attrs, [], fn {split_attrs, account}, acc ->
          changeset = Split.create_changeset(split_attrs, user, transaction, account)

          case apply_action(changeset, :create_split) do
            {:ok, split} ->
              split =
                split
                |> Split.to_map()
                |> Map.put(:transaction_id, {:placeholder, :transaction_id})
                |> Map.put(:user_id, {:placeholder, :user_id})
                |> Map.put(:inserted_at, {:placeholder, :now})
                |> Map.put(:updated_at, {:placeholder, :now})

              {:cont, [split | acc]}

            {:error, changeset} ->
              {:halt, changeset}
          end
        end)

      placeholders = %{
        transaction_id: transaction.id,
        user_id: transaction.user_id,
        now: transaction.inserted_at
      }

      with splits when is_list(splits) <- splits_or_changeset,
           {:sum, 0} <-
             {:sum, splits |> Enum.map(& &1[:transaction_currency_amount]) |> Enum.sum()},
           num_splits <- length(splits),
           {^num_splits, splits} <-
             Repo.insert_all(Split, splits, returning: true, placeholders: placeholders) do
        {:ok, splits}
      else
        %Ecto.Changeset{} = changeset -> {:error, changeset}
        {:sum, _} -> {:error, :splits_sum}
      end
    end)
    |> Repo.transaction()
  end
end
