# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Ledger.Repo.insert!(%Ledger.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

{:ok, user} = Ledger.Users.register_user("test", "test12345678", "SGD")
Ledger.Repo.put_user_id(user.id)

root_account = Ledger.Book.create_or_get_root_account_for_user!(user)

{:ok, income} =
  Ledger.Book.create_child_account(root_account, %{
    "account_type" => "income",
    "currency" => "SGD",
    "name" => "Income",
    "placeholder" => true
  })

{:ok, salary} =
  Ledger.Book.create_child_account(income, %{
    "account_type" => "income",
    "currency" => "SGD",
    "name" => "Salary",
    "placeholder" => false
  })

{:ok, bonus} =
  Ledger.Book.create_child_account(income, %{
    "account_type" => "income",
    "currency" => "SGD",
    "name" => "Bonus",
    "placeholder" => false
  })

{:ok, expense} =
  Ledger.Book.create_child_account(root_account, %{
    "account_type" => "expense",
    "currency" => "SGD",
    "name" => "Expense",
    "placeholder" => true
  })

{:ok, tax} =
  Ledger.Book.create_child_account(root_account, %{
    "account_type" => "expense",
    "currency" => "SGD",
    "name" => "Tax",
    "placeholder" => true
  })

{:ok, us_federal_tax} =
  Ledger.Book.create_child_account(tax, %{
    "account_type" => "expense",
    "currency" => "USD",
    "name" => "US Federal Tax",
    "placeholder" => false
  })

{:ok, us_state_tax} =
  Ledger.Book.create_child_account(tax, %{
    "account_type" => "expense",
    "currency" => "USD",
    "name" => "US State Tax",
    "placeholder" => false
  })

{:ok, sg_tax} =
  Ledger.Book.create_child_account(tax, %{
    "account_type" => "expense",
    "currency" => "SGD",
    "name" => "SG Tax",
    "placeholder" => false
  })

{:ok, asset} =
  Ledger.Book.create_child_account(root_account, %{
    "account_type" => "asset",
    "currency" => "SGD",
    "name" => "Asset",
    "placeholder" => true
  })

{:ok, bank_account} =
  Ledger.Book.create_child_account(asset, %{
    "account_type" => "asset",
    "currency" => "SGD",
    "name" => "Bank Account",
    "placeholder" => false
  })
