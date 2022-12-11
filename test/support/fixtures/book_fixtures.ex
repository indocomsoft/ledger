defmodule Ledger.BookFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ledger.Book` context.
  """

  @spec account_fixtures(Ledger.Accounts.User.t()) :: map()
  def account_fixtures(user) do
    original_user_id = Ledger.Repo.put_user_id(user.id)
    root = Ledger.Book.create_or_get_root_account_for_user!(user)

    {:ok, income} =
      Ledger.Book.create_child_account(root, %{
        account_type: :income,
        name: "Income",
        currency: :SGD,
        placeholder: true
      })

    {:ok, expense} =
      Ledger.Book.create_child_account(root, %{
        account_type: :expense,
        name: "Expense",
        currency: :SGD,
        placeholder: true
      })

    {:ok, tax} =
      Ledger.Book.create_child_account(expense, %{
        account_type: :expense,
        name: "Tax",
        currency: :SGD,
        placeholder: true
      })

    {:ok, us_federal_tax} =
      Ledger.Book.create_child_account(tax, %{
        account_type: :expense,
        name: "US Federal Tax",
        currency: :USD,
        placeholder: true
      })

    {:ok, us_state_tax} =
      Ledger.Book.create_child_account(tax, %{
        account_type: :expense,
        name: "US State Tax",
        currency: :USD,
        placeholder: true
      })

    case original_user_id do
      nil -> Ledger.Repo.delete_user_id()
      original_user_id -> Ledger.Repo.put_user_id(original_user_id)
    end

    %{
      root: root,
      income: income,
      expense: expense,
      tax: tax,
      us_federal_tax: us_federal_tax,
      us_state_tax: us_state_tax
    }
  end
end
