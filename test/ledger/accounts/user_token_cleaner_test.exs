defmodule Ledger.Accounts.UserTokenCleanerTest do
  use Ledger.DataCase, async: true

  import Ledger.AccountsFixtures
  import Ecto.Query

  alias Ledger.Accounts.UserToken

  describe "cleanup" do
    setup do
      %{user: user_fixture()}
    end

    @spec generate_user_token(Ledger.Accounts.User.t(), NaiveDateTime.t()) ::
            Ledger.Accounts.UserToken.t()
    def generate_user_token(user, inserted_at) do
      {_, user_token} = Ledger.Accounts.UserToken.build_session_token(user)

      user_token
      |> Ecto.Changeset.change(%{inserted_at: inserted_at})
      |> Ledger.Repo.insert!()
    end

    test "deletes expired token and schedules the next run", %{user: user} do
      %{id: expired_user_token_id} =
        generate_user_token(
          user,
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(-UserToken.session_validity_in_days() - 1, :day)
          |> NaiveDateTime.truncate(:second)
        )

      %{id: valid_user_token_id} =
        generate_user_token(
          user,
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(-UserToken.session_validity_in_days() + 1, :day)
          |> NaiveDateTime.truncate(:second)
        )

      expected = [expired_user_token_id, valid_user_token_id] |> Enum.sort()

      assert ^expected =
               Ledger.Accounts.UserToken |> select([t], t.id) |> order_by(:id) |> Repo.all()

      Ledger.Accounts.UserTokenCleaner.handle_info(:cleanup, nil)

      assert ^valid_user_token_id = Ledger.Accounts.UserToken |> select([t], t.id) |> Repo.one()

      assert_receive :cleanup
    end
  end
end
