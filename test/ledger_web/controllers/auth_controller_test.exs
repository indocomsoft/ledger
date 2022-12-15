defmodule LedgerWeb.AuthControllerTest do
  use LedgerWeb.ConnCase, async: true
  import Ledger.UsersFixtures

  describe "create/2" do
    setup do
      %{user: user_fixture()}
    end

    @spec login(Plug.Conn.t(), String.t(), String.t()) :: Plug.Conn.t()
    defp login(conn, username, password) do
      post(
        conn,
        Routes.auth_path(conn, :create),
        %{"username" => username, "password" => password}
        # Jason.encode!(%{"username" => username, "password" => password})
      )
    end

    test "returns session token for correct username and password", %{
      user: %{id: user_id, username: username},
      conn: conn
    } do
      assert %{"token" => token} =
               login(conn, username, valid_user_password()) |> json_response(200)

      {:ok, verified_token} = LedgerWeb.Auth.verify(token)
      assert %{id: ^user_id} = Ledger.Users.get_user_by_session_token(verified_token)
    end

    test "returns 401 on wrong username/password", %{user: %{username: username}, conn: conn} do
      assert login(conn, "invalid", valid_user_password()) |> json_response(401)

      assert login(conn, username, "invalid") |> json_response(401)
    end

    test "returns 400 on malformed request", %{conn: conn} do
      conn =
        post(conn, Routes.auth_path(conn, :create), %{
          "email" => "hello@example.com",
          "password" => "never gonna give you up"
        })

      assert json_response(conn, 400)
    end
  end
end
