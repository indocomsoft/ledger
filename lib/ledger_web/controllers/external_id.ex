defmodule LedgerWeb.ExternalId do
  @moduledoc """
  Helper to encode the binary external id into a url-safe string.
  """

  @spec encode_external_id(binary()) :: String.t()
  def encode_external_id(external_id) do
    Base.url_encode64(external_id, padding: false)
  end

  @spec decode_external_id(String.t()) :: {:ok, binary()} | :error
  def decode_external_id(id) do
    Base.url_decode64(id, padding: false)
  end
end
