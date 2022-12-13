defmodule Ledger.RepoTest do
  use Ledger.DataCase, async: true

  test "raises if user_id is not set" do
    assert_raise RuntimeError,
                 "expected user_id or skip_user_id to be set for operation all",
                 fn ->
                   Ledger.Book.Account |> Ledger.Repo.all()
                 end
  end
end
