defmodule LedgerWeb.AuthPlug do
  @moduledoc """
  This plug extracts the session token from the authorization bearer token HTTP header, verifies
  that it hasn't been tampered with, and then checks that the session token belongs to a valid user.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> signed_token] <- get_req_header(conn, "authorization"),
         {:ok, token} <- LedgerWeb.Auth.verify(signed_token),
         user = %Ledger.Accounts.User{} <- Ledger.Accounts.get_user_by_session_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          "error" => "Missing/invalid HTTP Authorization header Bearer token"
        })
        |> halt()
    end
  end
end
