defmodule LedgerWeb.AuthController do
  use LedgerWeb, :controller

  def create(conn, %{"username" => username, "password" => password}) do
    case Ledger.Accounts.get_user_by_username_and_password(username, password) do
      user = %Ledger.Accounts.User{} ->
        raw_token = Ledger.Accounts.generate_user_session_token(user)
        token = LedgerWeb.Auth.sign(raw_token)

        json(conn, %{token: token})

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{"error" => "wrong username or password"})
    end
  end

  def create(conn, _) do
    conn
    |> put_status(:bad_request)
    |> json(%{"error" => "malformed request"})
  end
end
