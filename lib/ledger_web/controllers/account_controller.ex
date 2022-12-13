defmodule LedgerWeb.AccountController do
  use LedgerWeb, :controller

  alias Ledger.Book
  alias Ledger.Book.Account

  @spec load_account(String.t()) :: {:ok, Account.t()} | {:error, :not_found}
  defp load_account(external_id) do
    with {:ok, external_id} <- decode_external_id(external_id),
         account = %Account{} <- Book.get_account_by_external_id(external_id) do
      {:ok, account}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec serialize_account(Account.t()) :: map()
  defp serialize_account(account = %Account{}) do
    %{
      id: encode_external_id(account.external_id),
      account_type: account.account_type,
      currency: account.currency,
      name: account.name,
      description: account.description,
      placeholder: account.placeholder,
      parent_id:
        case account.parent do
          nil -> nil
          %{external_id: external_id} -> encode_external_id(external_id)
        end
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

  def create(conn, params = %{"account_id" => parent_id}) do
    with {:ok, parent_account} <- load_account(parent_id),
         attrs = Map.delete(params, "account_id"),
         {:ok, child_account = %Account{}} <- Book.create_child_account(parent_account, attrs) do
      conn |> put_status(:ok) |> json(serialize_account(child_account))
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        conn
        |> put_status(:bad_request)
        |> put_view(LedgerWeb.ErrorView)
        |> render("changeset_error.json", changeset: changeset)

      _ ->
        conn |> put_status(:not_found) |> json(%{"error" => "parent account not found"})
    end
  end

  def show(conn, %{"id" => id}) do
    case load_account(id) do
      {:ok, account} ->
        conn
        |> put_status(:ok)
        |> json(serialize_account(account))

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{"error" => "not found"})
    end
  end

  def update(conn, params = %{"parent_id" => parent_id}) when is_binary(parent_id) do
    case load_account(parent_id) do
      {:ok, parent_account = %Account{}} ->
        update(conn, Map.delete(params, "parent_id"), parent_account)

      {:error, :not_found} ->
        conn |> put_status(:bad_request) |> json(%{"errors" => %{"parent_id" => ["not found"]}})
    end
  end

  def update(conn, params = %{"parent_id" => nil}) do
    conn |> put_status(:bad_request) |> json(%{"errors" => %{"parent_id" => ["cannot be null"]}})
  end

  def update(conn, params = %{"id" => id}, parent_account \\ nil) do
    with {:ok, account} <- load_account(id),
         attrs = Map.delete(params, "id"),
         {:ok, account = %Account{}} <- Book.update_account(account, attrs, parent_account) do
      conn
      |> put_status(:ok)
      |> json(serialize_account(account))
    else
      {:error, :root} ->
        conn
        |> put_status(:method_not_allowed)
        |> json(%{"error" => "cannot update the root account"})

      {:error, changeset = %Ecto.Changeset{}} ->
        conn
        |> put_status(:bad_request)
        |> put_view(LedgerWeb.ErrorView)
        |> render("changeset_error.json", changeset: changeset)

      _ ->
        conn |> put_status(:not_found) |> json(%{"error" => "not found"})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, account} <- load_account(id),
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
