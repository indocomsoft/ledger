defmodule LedgerWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use LedgerWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import LedgerWeb.ConnCase

      alias LedgerWeb.Router.Helpers, as: Routes

      import LedgerWeb.ExternalId

      # The default endpoint for testing
      @endpoint LedgerWeb.Endpoint

      defp login(conn, user = %Ledger.Users.User{}) do
        token =
          user
          |> Ledger.Users.generate_user_session_token()
          |> LedgerWeb.Auth.sign()

        put_req_header(conn, "authorization", "Bearer #{token}")
      end
    end
  end

  setup tags do
    Ledger.DataCase.setup_sandbox(tags)

    {:ok,
     conn:
       Phoenix.ConnTest.build_conn()
       |> Plug.Conn.put_req_header("content-type", "application/json")}
  end
end
