defmodule Ledger.Book.Account do
  @moduledoc """
  Represents a book account.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ledger.Users.User
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

  schema "accounts" do
    field :external_id, :binary, read_after_writes: true
    field :account_type, Ecto.Enum, values: @account_type_values
    field :currency, Ecto.Enum, values: Cldr.known_currencies()
    field :name, :string
    field :description, :string
    field :placeholder, :boolean
    belongs_to :parent, Account, on_replace: :nilify
    belongs_to :user, User

    has_many :children, Account

    timestamps()
  end

  @spec create_root_account_for_user_changeset(User.t()) :: Ecto.Changeset.t()
  def create_root_account_for_user_changeset(%User{id: user_id, base_currency: base_currency}) do
    %Account{}
    |> change(%{
      account_type: :root,
      currency: base_currency,
      name: "Root Account",
      placeholder: true,
      user_id: user_id
    })
    |> put_assoc(:parent, nil)
  end

  @spec child_account_changeset(Account.t(), map()) :: Ecto.Changeset.t()
  def child_account_changeset(parent_account = %Account{user_id: user_id}, attrs) do
    %Account{user_id: user_id}
    |> cast(attrs, [:account_type, :currency, :name, :description, :placeholder])
    |> put_parent_assoc(parent_account)
    |> validate_fields()
  end

  @spec validate_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_fields(changeset) do
    changeset
    |> validate_required([:account_type, :currency, :name, :placeholder])
    |> unique_constraint([:parent_id, :user_id, :name],
      error_key: :name,
      message: "has to be unique for a given parent account"
    )
  end

  @spec put_parent_assoc(Ecto.Changeset.t(), Account.t() | nil) :: Ecto.Changeset.t()
  def put_parent_assoc(changeset, parent_account) do
    changeset
    |> put_assoc(:parent, parent_account)
    |> validate_child_account_type()
  end

  @spec validate_child_account_type(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_child_account_type(changeset) do
    account_type = fetch_field!(changeset, :account_type)
    parent_account_type = fetch_field!(changeset, :parent).account_type

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

  @spec update_changeset(Account.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :description, :placeholder])
    |> validate_fields()
  end
end
