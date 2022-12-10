defmodule Ledger.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ledger.Accounts` context.
  """

  def unique_username, do: "user#{System.unique_integer([:positive])}"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      username: unique_username(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Ledger.Accounts.register_user()

    user
  end
end
