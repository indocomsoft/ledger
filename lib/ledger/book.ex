defmodule Ledger.Book do
  @moduledoc """
  The Book context.
  """

  import Ecto.Query, warn: false
  alias Ledger.Repo

  alias Ledger.Accounts.User
  alias Ledger.Book.Account

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
end
