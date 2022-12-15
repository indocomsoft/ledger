defmodule Ledger.BookTest do
  use Ledger.DataCase, async: true

  alias Ledger.Book

  alias Ledger.Book.Account

  import Ledger.UsersFixtures
  import Ecto.Query

  setup do
    user = %{id: user_id} = user_fixture()
    Ledger.Repo.put_user_id(user_id)
    %{user: user}
  end

  describe "create_or_get_root_account_for_user!/1" do
    test "creates a root account for user if one doesn't exist yet", %{user: user} do
      assert 0 = Ledger.Book.Account |> select(count()) |> Ledger.Repo.one()

      assert %Account{id: id, external_id: external_id} =
               Book.create_or_get_root_account_for_user!(user)

      assert id
      assert external_id

      assert ^id = Ledger.Book.Account |> select([a], a.id) |> Ledger.Repo.one()
    end

    test "does not recreate root account if one already exists", %{user: user = %{id: user_id}} do
      assert %Account{id: id, external_id: external_id} =
               %Account{
                 account_type: :root,
                 user_id: user_id,
                 placeholder: true,
                 currency: :SGD,
                 name: "Root"
               }
               |> Ledger.Repo.insert!()

      assert %Account{id: ^id, external_id: ^external_id} =
               Book.create_or_get_root_account_for_user!(user)
    end
  end

  describe "create_child_account/2" do
    @valid_attrs %{
      "account_type" => "income",
      "name" => "Income",
      "description" => "Placeholder account for income subaccounts",
      "currency" => "SGD",
      "placeholder" => true
    }

    setup %{user: user} do
      %{root: Book.create_or_get_root_account_for_user!(user)}
    end

    test "happy path", %{root: root = %Account{id: root_id}} do
      assert {:ok, %Account{parent_id: ^root_id}} = Book.create_child_account(root, @valid_attrs)
    end

    test "ignores extra keys in attrs", %{root: root} do
      assert {:ok, %Account{}} =
               Book.create_child_account(root, @valid_attrs |> Map.put("parent_id", 2))
    end

    test "validate required fields and allows nil for optional", %{root: root} do
      Enum.each(~w(account_type currency name placeholder)a, fn field ->
        assert {:error, changeset = %Ecto.Changeset{}} =
                 Book.create_child_account(root, Map.delete(@valid_attrs, to_string(field)))

        assert %{^field => ["can't be blank"]} = errors_on(changeset)
      end)

      assert {:ok, %Account{}} =
               Book.create_child_account(root, @valid_attrs |> Map.delete("description"))
    end

    test "validate child account type - root's children can be of any type but root", %{
      root: root
    } do
      valid_account_types = Ecto.Enum.values(Ledger.Book.Account, :account_type) -- [:root]

      Enum.each(valid_account_types, fn account_type ->
        account_type = to_string(account_type)

        assert {:ok, %Account{}} =
                 Book.create_child_account(
                   root,
                   @valid_attrs
                   |> Map.put("account_type", account_type)
                   |> Map.put("name", account_type)
                 )
      end)

      assert {:error, changeset} =
               Book.create_child_account(root, Map.put(@valid_attrs, "account_type", "root"))

      assert %{account_type: ["cannot be root for child accounts"]} = errors_on(changeset)
    end

    test "validate child account type - account type must match its parent account type except if parent is root",
         %{root: root} do
      assert {:ok, direct_child} =
               Book.create_child_account(root, Map.put(@valid_attrs, "account_type", "income"))

      assert {:error, changeset} =
               Book.create_child_account(
                 direct_child,
                 Map.put(@valid_attrs, "account_type", "expense")
               )

      assert %{account_type: ["must match its parent account type"]} = errors_on(changeset)
    end

    test "validate unique name for all children of the same parent", %{root: root} do
      assert {:ok, %Account{}} = Book.create_child_account(root, @valid_attrs)
      assert {:error, changeset} = Book.create_child_account(root, @valid_attrs)
      assert %{name: ["has to be unique for a given parent account"]} = errors_on(changeset)
    end
  end
end
