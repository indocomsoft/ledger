defmodule LedgerWeb.Auth do
  @moduledoc """
  Provides helpers for signing user session tokens and verifying them.
  """

  @token_signing_salt "user auth"

  @spec sign(binary()) :: String.t()
  def sign(token) when is_binary(token) do
    Phoenix.Token.sign(LedgerWeb.Endpoint, @token_signing_salt, token)
  end

  @spec verify(String.t()) :: {:ok, binary()} | {:error, atom()}
  def verify(token) when is_binary(token) do
    Phoenix.Token.verify(LedgerWeb.Endpoint, @token_signing_salt, token)
  end
end
