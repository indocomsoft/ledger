defmodule LedgerWeb.AccountControllerTest do
  use LedgerWeb.ConnCase, async: true
  import Ledger.AccountsFixtures
  import Ledger.BookFixtures

  import Ecto.Query

  setup %{conn: conn} do
    user = user_fixture()

    conn = login(conn, user)

    %{user: user, conn: conn}
  end

  describe "index/2" do
    test "creates a root account if there isn't already one", %{conn: conn} do
      assert 0 = Ledger.Book.Account |> select(count()) |> Ledger.Repo.one(skip_user_id: true)

      assert %{"children" => [], "account_type" => "root", "id" => external_id_base64} =
               conn |> get(Routes.account_path(conn, :index)) |> json_response(200)

      assert {:ok, external_id} = decode_external_id(external_id_base64)

      assert ^external_id =
               Ledger.Book.Account
               |> select([a], a.external_id)
               |> Ledger.Repo.one(skip_user_id: true)
    end

    test "constructs the account tree correctly", %{conn: conn, user: user} do
      account_fixtures(user)

      assert %{"account_type" => "root", "children" => root_children} =
               conn |> get(Routes.account_path(conn, :index)) |> json_response(200)

      assert 2 = length(root_children)

      assert [
               %{
                 "name" => "Expense",
                 "account_type" => "expense",
                 "children" => [
                   %{"name" => "Tax", "account_type" => "expense", "children" => tax_children}
                 ]
               },
               %{"name" => "Income", "account_type" => "income", "children" => []}
             ] = Enum.sort_by(root_children, & &1["name"])

      assert [
               %{"name" => "US Federal Tax", "account_type" => "expense", "children" => []},
               %{"name" => "US State Tax", "account_type" => "expense", "children" => []}
             ] = Enum.sort_by(tax_children, & &1["name"])
    end
  end

  describe "show/2" do
    setup %{user: user} do
      %{accounts: account_fixtures(user)}
    end

    test "works correctly for root account", %{conn: conn, accounts: accounts} do
      root_id = encode_external_id(accounts[:root].external_id)

      assert %{"account_type" => "root", "id" => ^root_id, "parent_id" => nil} =
               conn
               |> get(Routes.account_path(conn, :show, root_id))
               |> json_response(200)
    end

    test "works correctly for non-root account", %{conn: conn, accounts: accounts} do
      tax_id = encode_external_id(accounts[:tax].external_id)
      tax_parent_id = encode_external_id(accounts[:tax].parent.external_id)

      assert %{"account_type" => "expense", "id" => ^tax_id, "parent_id" => ^tax_parent_id} =
               conn |> get(Routes.account_path(conn, :show, tax_id)) |> json_response(200)
    end

    test "handles not found correctly", %{conn: conn} do
      assert %{"error" => "not found"} =
               conn |> get(Routes.account_path(conn, :show, "unknown")) |> json_response(404)
    end
  end

  describe "delete/2" do
    setup %{user: user} do
      %{accounts: account_fixtures(user)}
    end

    test "happy_path", %{conn: conn, accounts: accounts} do
      us_state_tax_id = encode_external_id(accounts[:us_state_tax].external_id)

      assert %{"id" => ^us_state_tax_id} =
               conn
               |> delete(Routes.account_path(conn, :delete, us_state_tax_id))
               |> json_response(200)

      refute Ledger.Repo.get(Ledger.Book.Account, accounts[:us_state_tax].id)
    end

    test "does not allow deleting root account", %{conn: conn, accounts: accounts} do
      root_external_id = encode_external_id(accounts[:root].external_id)

      assert %{"error" => "cannot delete the root account"} =
               conn
               |> delete(Routes.account_path(conn, :delete, root_external_id))
               |> json_response(405)

      root_id = accounts[:root].id
      assert %Ledger.Book.Account{id: ^root_id} = Ledger.Repo.get(Ledger.Book.Account, root_id)
    end

    test "does not allow deleting account with children", %{conn: conn, accounts: accounts} do
      tax_external_id = encode_external_id(accounts[:tax].external_id)

      assert %{"error" => "cannot delete an account that still has children"} =
               conn
               |> delete(Routes.account_path(conn, :delete, tax_external_id))
               |> json_response(405)

      tax_id = accounts[:tax].id
      assert %Ledger.Book.Account{id: ^tax_id} = Ledger.Repo.get(Ledger.Book.Account, tax_id)
    end
  end
end
