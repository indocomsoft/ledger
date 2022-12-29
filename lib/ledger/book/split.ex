defmodule Ledger.Book.Split do
  @moduledoc """
  Represents a split associated with an account that is a part of a transaction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ledger.Book.Account
  alias Ledger.Book.Split
  alias Ledger.Book.Transaction
  alias Ledger.Users.User

  @type t :: %__MODULE__{
          external_id: String.t(),
          account_currency_amount: integer(),
          transaction_currency_amount: integer(),
          reconcile_date: Date.t(),
          user_id: integer(),
          transaction_id: integer(),
          account_id: integer()
        }

  schema "splits" do
    field :external_id, :binary, read_after_writes: true
    field :account_currency_amount, :integer
    field :transaction_currency_amount, :integer
    field :reconcile_date, :date

    belongs_to :user, User
    belongs_to :transaction, Transaction
    belongs_to :account, Account

    timestamps()
  end

  @spec to_map(Split.t()) :: map()
  def to_map(split = %Split{}) do
    split
    |> Map.from_struct()
    |> Map.take(Split.__schema__(:fields))
    |> Map.drop([:id, :external_id])
    |> Map.reject(fn {_k, v} -> v == nil end)
  end

  @spec create_changeset(map(), User.t(), Transaction.t(), Account.t()) :: Ecto.Changeset.t()
  def create_changeset(attrs, %User{id: user_id}, %Transaction{id: transaction_id}, %Account{
        id: account_id
      }) do
    %Split{user_id: user_id, transaction_id: transaction_id, account_id: account_id}
    |> cast(attrs, [:account_currency_amount, :transaction_currency_amount, :reconcile_date])
    |> validate_fields()
  end

  @spec validate_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_fields(changeset) do
    changeset
    |> validate_required([
      :account_currency_amount,
      :transaction_currency_amount,
      :user_id,
      :transaction_id,
      :account_id
    ])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:account_id)
  end
end
