defmodule LedgerWeb.AuthPlugTest do
  use LedgerWeb.ConnCase, async: true
  import Ledger.UsersFixtures

  setup %{conn: conn} do
    %{user: user_fixture(), path: Routes.account_path(conn, :index)}
  end

  test "missing authorization HTTP header", %{conn: conn, path: path} do
    assert %{"error" => "Missing/invalid HTTP Authorization header Bearer token"} =
             conn |> get(path) |> json_response(401)
  end

  test "invalid authorization HTTP header", %{conn: conn, path: path} do
    assert %{"error" => "Missing/invalid HTTP Authorization header Bearer token"} =
             conn
             |> put_req_header("authorization", "Bearer invalid")
             |> get(path)
             |> json_response(401)
  end

  test "valid authorization HTTP header", %{conn: conn, user: user, path: path} do
    token = user |> Ledger.Users.generate_user_session_token() |> LedgerWeb.Auth.sign()

    assert conn
           |> put_req_header("authorization", "Bearer #{token}")
           |> get(path)
           |> json_response(200)
  end
end
