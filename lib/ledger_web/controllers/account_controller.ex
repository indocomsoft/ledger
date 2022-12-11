defmodule LedgerWeb.AccountController do
  use LedgerWeb, :controller

  alias Ledger.Book
  alias Ledger.Book.Account

  @spec serialize_account(Account.t()) :: map()
  defp serialize_account(account = %Account{}) do
    %{
      id: Base.url_encode64(account.external_id, padding: false),
      account_type: account.account_type,
      currency: account.currency,
      name: account.name,
      description: account.description,
      placeholder: account.placeholder
    }
  end

  defp construct_account_tree(
         accounts_by_parent_id,
         parent_id_mapping,
         root_account
       ) do
    children =
      Enum.map(
        accounts_by_parent_id[root_account.id] || [],
        &construct_account_tree(accounts_by_parent_id, parent_id_mapping, &1)
      )

    serialize_account(root_account) |> Map.put(:children, children)
  end

  def index(conn = %Plug.Conn{assigns: %{current_user: user}}, _params) do
    accounts = Book.all_accounts_for_user(user)
    parent_id_mapping = Map.new(accounts, &{&1.id, &1.parent_id})
    accounts_by_parent_id = Enum.group_by(accounts, & &1.parent_id)
    [root_account] = accounts_by_parent_id[nil]
    account_tree = construct_account_tree(accounts_by_parent_id, parent_id_mapping, root_account)

    conn
    |> put_status(:ok)
    |> json(account_tree)
  end

  def create(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end

  def show(conn, %{"id" => id}) do
    with {:ok, external_id} <- Base.url_decode64(id, padding: false),
         account = %Account{} <- Book.get_account_by_external_id(external_id) do
      conn
      |> put_status(:ok)
      |> json(serialize_account(account))
    else
      _ -> conn |> put_status(:not_found) |> json(%{"error" => "not found"})
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, external_id} <- Base.url_decode64(id, padding: false),
         account = %Account{} <- Book.get_account_by_external_id(external_id),
         {:ok, account} <- Ledger.Book.delete_account(account) do
      conn
      |> put_status(:ok)
      |> json(serialize_account(account))
    else
      {:error, :root} ->
        conn
        |> put_status(:method_not_allowed)
        |> json(%{"error" => "cannot delete the root account"})

      # TODO handle this case more gracefully
      # GNUCash offers to move the children to a different account
      {:error, :has_children} ->
        conn
        |> put_status(:method_not_allowed)
        |> json(%{"error" => "cannot delete an account that still has children"})

      _ ->
        conn |> put_status(:not_found) |> json(%{"error" => "not found"})
    end
  end
end
