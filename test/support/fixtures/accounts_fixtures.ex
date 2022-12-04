defmodule Ledger.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ledger.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        hashed_password: "some hashed_password",
        username: "some username"
      })
      |> Ledger.Accounts.create_user()

    user
  end
end
