defmodule Ledger.Users.UserTokenCleanerTest do
  use Ledger.DataCase, async: true

  import Ledger.UsersFixtures
  import Ecto.Query

  alias Ledger.Users.UserToken

  describe "cleanup" do
    setup do
      %{user: user_fixture()}
    end

    @spec generate_user_token(Ledger.Users.User.t(), NaiveDateTime.t()) ::
            Ledger.Users.UserToken.t()
    def generate_user_token(user, inserted_at) do
      {_, user_token} = Ledger.Users.UserToken.build_session_token(user)

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
               Ledger.Users.UserToken
               |> select([t], t.id)
               |> order_by(:id)
               |> Repo.all(skip_user_id: true)

      Ledger.Users.UserTokenCleaner.handle_info(:cleanup, nil)

      assert ^valid_user_token_id =
               Ledger.Users.UserToken |> select([t], t.id) |> Repo.one(skip_user_id: true)

      assert_receive :cleanup
    end
  end
end
