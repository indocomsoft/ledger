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

    test "validates that account can be found", %{conn: conn} do
      assert %{"error" => "not found"} =
               conn |> delete(Routes.account_path(conn, :delete, "unknown")) |> json_response(404)
    end
  end

  describe "create/2" do
    setup %{user: user} do
      %{accounts: account_fixtures(user)}
    end

    @valid_attrs %{
      "account_type" => "asset",
      "name" => "Assets",
      "placeholder" => true,
      "currency" => "SGD"
    }

    test "happy path - new child of root", %{conn: conn, accounts: %{root: root}} do
      root_external_id = encode_external_id(root.external_id)

      valid_attrs = @valid_attrs

      assert %{"parent_id" => ^root_external_id} =
               ^valid_attrs =
               conn
               |> post(Routes.account_account_path(conn, :create, root_external_id), valid_attrs)
               |> json_response(200)
    end

    test "happy path - new child of child", %{conn: conn, accounts: %{income: income}} do
      income_external_id = encode_external_id(income.external_id)

      valid_attrs = @valid_attrs |> Map.put("account_type", "income") |> Map.put("name", "Salary")

      assert %{"parent_id" => ^income_external_id} =
               ^valid_attrs =
               conn
               |> post(
                 Routes.account_account_path(conn, :create, income_external_id),
                 valid_attrs
               )
               |> json_response(200)
    end

    test "validates new child account type cannot be root", %{
      conn: conn,
      accounts: %{income: income}
    } do
      income_external_id = encode_external_id(income.external_id)

      invalid_attrs = @valid_attrs |> Map.put("account_type", "root")

      assert %{"errors" => %{"account_type" => ["cannot be root for child accounts"]}} =
               conn
               |> post(
                 Routes.account_account_path(conn, :create, income_external_id),
                 invalid_attrs
               )
               |> json_response(400)
    end

    test "validates account_type", %{conn: conn, accounts: %{root: root}} do
      root_external_id = encode_external_id(root.external_id)

      assert %{
               "errors" => %{
                 "account_type" => [
                   "is invalid -- must be one of (root, asset, equity, liability, income, expense)"
                 ]
               }
             } =
               conn
               |> post(
                 Routes.account_account_path(conn, :create, root_external_id),
                 @valid_attrs |> Map.put("account_type", "invalid")
               )
               |> json_response(400)
    end

    test "validates that parent account can be found", %{conn: conn} do
      assert %{"error" => "parent account not found"} =
               conn
               |> post(Routes.account_account_path(conn, :create, "unknown"), @valid_attrs)
               |> json_response(404)
    end
  end

  describe "update/2" do
    setup %{user: user} do
      %{accounts: account_fixtures(user)}
    end

    @valid_attrs %{
      "placeholder" => false,
      "name" => "US Tax"
    }

    test "happy path", %{conn: conn, accounts: %{tax: tax}} do
      tax_external_id = encode_external_id(tax.external_id)

      attrs = @valid_attrs

      assert %{"id" => ^tax_external_id} =
               ^attrs =
               conn
               |> put(Routes.account_path(conn, :update, tax_external_id), attrs)
               |> json_response(200)
    end

    test "handles not found correctly", %{conn: conn} do
      assert %{"error" => "not found"} =
               conn
               |> put(Routes.account_path(conn, :update, "unknown"), @valid_attrs)
               |> json_response(404)
    end

    test "ensures name is unique", %{conn: conn, accounts: %{us_state_tax: us_state_tax}} do
      us_state_tax_external_id = encode_external_id(us_state_tax.external_id)

      assert %{"errors" => %{"name" => ["has to be unique for a given parent account"]}} =
               conn
               |> put(Routes.account_path(conn, :update, us_state_tax_external_id), %{
                 "name" => "US Federal Tax"
               })
               |> json_response(400)
    end

    test "validate cannot update root account", %{conn: conn, accounts: %{root: root}} do
      root_external_id = encode_external_id(root.external_id)

      assert %{"error" => "cannot update the root account"} =
               conn
               |> put(Routes.account_path(conn, :update, root_external_id), @valid_attrs)
               |> json_response(405)
    end

    test "parent_id - happy path", %{conn: conn, accounts: %{root: root, tax: tax}} do
      root_external_id = encode_external_id(root.external_id)
      tax_external_id = encode_external_id(tax.external_id)

      assert %{"id" => ^tax_external_id, "parent_id" => ^root_external_id} =
               conn
               |> put(Routes.account_path(conn, :update, tax_external_id), %{
                 "parent_id" => root_external_id
               })
               |> json_response(200)
    end

    test "parent_id - ensure parent account exists", %{conn: conn, accounts: %{tax: tax}} do
      tax_external_id = encode_external_id(tax.external_id)

      assert %{"errors" => %{"parent_id" => ["not found"]}} =
               conn
               |> put(Routes.account_path(conn, :update, tax_external_id), %{
                 "parent_id" => "unknown"
               })
               |> json_response(400)
    end

    test "parent_id - validates against setting it to nil", %{conn: conn, accounts: %{tax: tax}} do
      tax_external_id = encode_external_id(tax.external_id)

      assert %{"errors" => %{"parent_id" => ["cannot be null"]}} =
               conn
               |> put(Routes.account_path(conn, :update, tax_external_id), %{"parent_id" => nil})
               |> json_response(400)
    end

    test "parent_id - validates against setting it to itself", %{
      conn: conn,
      accounts: %{tax: tax}
    } do
      tax_external_id = encode_external_id(tax.external_id)

      assert %{"errors" => %{"parent_id" => ["cannot be pointing to itself"]}} =
               conn
               |> put(Routes.account_path(conn, :update, tax_external_id), %{
                 "parent_id" => tax_external_id
               })
               |> json_response(400)
    end
  end
end
