defmodule Ledger.Accounts.UserTokenCleaner do
  @moduledoc """
  Cleans up expired user tokens from the database.
  """

  use GenServer

  require Logger

  # 1 hour
  @interval_ms 60 * 60 * 1000

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
      |> Ledger.Repo.delete_all()

    Logger.info("Deleted #{num_deleted} expired user tokens")

    Process.send_after(self(), :cleanup, @interval_ms)

    {:noreply, nil}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end
end
