defmodule LedgerWeb.CheckController do
  use LedgerWeb, :controller

  def check(
        conn = %Plug.Conn{assigns: %{current_user: %Ledger.Accounts.User{username: username}}},
        _params
      ) do
    json(conn, %{"username" => username})
  end
end
