defmodule Ledger.Book.Account do
  @moduledoc """
  Represents a book account.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ledger.Accounts.User
  alias Ledger.Book.Account

  @type account_type :: :root | :asset | :equity | :liability | :income | :expense
  @type t :: %__MODULE__{
          external_id: String.t(),
          account_type: account_type(),
          currency: atom(),
          name: String.t(),
          description: String.t() | nil,
          placeholder: boolean(),
          parent_id: integer() | nil,
          user_id: integer()
        }

  @account_type_values ~w(root asset equity liability income expense)a
  @currencies Cldr.known_currencies()

  schema "accounts" do
    field :external_id, :binary, read_after_writes: true
    field :account_type, Ecto.Enum, values: @account_type_values
    field :currency, Ecto.Enum, values: @currencies
    field :name, :string
    field :description, :string
    field :placeholder, :boolean
    belongs_to :parent, Account
    belongs_to :user, User

    has_many :children, Account

    timestamps()
  end

  @spec create_root_account_for_user_changeset(User.t()) :: Ecto.Changeset.t()
  def create_root_account_for_user_changeset(%User{id: user_id}) do
    %Account{}
    |> change(%{
      account_type: :root,
      # TODO: save user's base currency in a UserPreference table
      currency: :SGD,
      name: "Root Account",
      placeholder: true,
      parent_id: nil,
      user_id: user_id
    })
  end

  @spec child_account_changeset(Account.t(), map()) :: Ecto.Changeset.t()
  def child_account_changeset(parent_account = %Account{user_id: user_id}, attrs) do
    %Account{user_id: user_id}
    |> cast(attrs, [:account_type, :currency, :name, :description, :placeholder])
    |> put_assoc(:parent, parent_account)
    |> validate_required([:account_type, :currency, :name, :placeholder])
    |> validate_child_account_type()
    |> unique_constraint([:user_id, :parent_id, :name],
      error_key: :name,
      message: "has to be unique for a given parent account"
    )
  end

  @spec validate_child_account_type(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_child_account_type(changeset) do
    account_type = get_change(changeset, :account_type)
    parent_account_type = changeset |> get_change(:parent) |> fetch_field!(:account_type)

    if account_type == :root do
      add_error(changeset, :account_type, "cannot be root for child accounts")
    else
      if parent_account_type == :root or parent_account_type == account_type do
        changeset
      else
        add_error(changeset, :account_type, "must match its parent account type")
      end
    end
  end
end
