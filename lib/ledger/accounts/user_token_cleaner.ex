defmodule Ledger.Accounts.UserTokenCleaner do
  @moduledoc """
  Cleans up expired user tokens from the database.
  """

  use GenServer

  require Logger

  @impl true
  def init(_) do
    handle_info(:cleanup, nil)
    {:ok, nil}
  end

  @impl true
  def handle_info(:cleanup, nil) do
    Logger.info("Cleaning up expired user tokens")

    {num_deleted, nil} =
      Ledger.Accounts.UserToken.expired_session_token_query()
      |> Ledger.Repo.delete_all(skip_user_id: true)

    Logger.info("Deleted #{num_deleted} expired user tokens")

    interval_ms = Application.get_env(:ledger, __MODULE__)[:interval_ms]
    Process.send_after(self(), :cleanup, interval_ms)

    {:noreply, nil}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end
end
