defmodule LedgerWeb.AuthPlug do
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
