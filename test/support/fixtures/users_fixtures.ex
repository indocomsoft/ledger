defmodule Ledger.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ledger.Users` context.
  """

  def unique_username, do: "user#{System.unique_integer([:positive])}"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      username: unique_username(),
      password: valid_user_password(),
      base_currency: :SGD
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Ledger.Users.register_user()

    user
  end
end
