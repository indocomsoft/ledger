defmodule Ledger.BookFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ledger.Book` context.
  """

  @doc """
  Generate a account.
  """
  def account_fixture(attrs \\ %{}) do
    {:ok, account} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        placeholder: true
      })
      |> Ledger.Book.create_account()

    account
  end
end
