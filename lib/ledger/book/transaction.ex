defmodule Ledger.Book.Transaction do
  @moduledoc """
  Represents a transaction associated with multiple splits.

  The splits in a transaction must all sum up to 0.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ledger.Book.Transaction
  alias Ledger.Users.User

  @type t :: %__MODULE__{
          currency: atom(),
          post_date: Date.t(),
          description: String.t(),
          user_id: integer()
        }

  schema "transactions" do
    field :currency, Ecto.Enum, values: Cldr.known_currencies()
    field :post_date, :date
    field :description, :string

    belongs_to :user, User
  end

  @spec create_changeset(map(), User.t()) :: Ecto.Changeset.t()
  def create_changeset(attrs, %User{id: user_id}) do
    %Transaction{user_id: user_id}
    |> cast(attrs, [:currency, :post_date, :description])
    |> validate_fields()
  end

  @spec update_changeset(Transaction.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:description])
    |> validate_fields()
  end

  @spec validate_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_fields(changeset) do
    changeset
    |> validate_required([:currency, :post_date, :description])
    |> foreign_key_constraint(:user_id)
  end
end
