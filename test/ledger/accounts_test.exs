defmodule Ledger.UsersTest do
  use Ledger.DataCase, async: true

  alias Ledger.Users

  import Ledger.UsersFixtures
  alias Ledger.Users.{User, UserToken}

  describe "get_user_by_username/1" do
    test "does not return the user if the username does not exist" do
      refute Users.get_user_by_username("unknown")
    end

    test "returns the user if the username exists" do
      %{id: id, username: username} = user_fixture()
      assert %User{id: ^id} = Users.get_user_by_username(username)
    end
  end

  describe "get_user_by_username_and_password/2" do
    test "does not return the user if the username does not exist" do
      refute Users.get_user_by_username_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      %{username: username} = user_fixture()
      refute Users.get_user_by_username_and_password(username, "invalid")
    end

    test "returns the user if the username and password are valid" do
      %{id: id, username: username} = user_fixture()

      assert %User{id: ^id} =
               Users.get_user_by_username_and_password(username, valid_user_password())
    end
  end

  describe "register_user/1" do
    test "requires username and password to be set" do
      {:error, changeset} = Users.register_user(%{})

      assert %{
               password: ["can't be blank"],
               username: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates username and password when given" do
      {:error, changeset} = Users.register_user(%{username: "not valid", password: "not valid"})

      assert %{
               username: ["only alphanumeric and underscore"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates username uniqueness" do
      %{username: username} = user_fixture()

      {:error, changeset} =
        Users.register_user(%{
          username: username,
          password: valid_user_password(),
          base_currency: :SGD
        })

      assert "has already been taken" in errors_on(changeset).username

      # Now try with the upper cased username too, to check that username case is ignored.
      {:error, changeset} =
        Users.register_user(%{
          username: String.upcase(username),
          password: valid_user_password(),
          base_currency: :SGD
        })

      assert "has already been taken" in errors_on(changeset).username
    end

    test "registers users with a hashed password" do
      username = unique_username()

      {:ok, user = %{username: ^username, password: nil}} =
        Users.register_user(valid_user_attributes(username: username))

      assert is_binary(user.hashed_password)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{required: [:password]} = Users.change_user_password(%User{})
    end

    test "allows fields to be set" do
      %Ecto.Changeset{valid?: true} =
        changeset =
        Users.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      user = %{id: user_id} = user_fixture()
      Ledger.Repo.put_user_id(user_id)
      %{user: user}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Users.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Users.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, %{username: username, password: nil}} =
        Users.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert Users.get_user_by_username_and_password(username, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user = %{id: user_id}} do
      token = Users.generate_user_session_token(user)

      assert Repo.get_by(UserToken, user_id: user_id)
      assert Repo.get_by(UserToken, token: token)

      {:ok, _} =
        Users.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Users.generate_user_session_token(user)

      assert %{context: "session", token: token} =
               Repo.get_by(UserToken, [token: token], skip_user_id: true)

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Users.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: %{id: user_id}, token: token} do
      assert %{id: ^user_id} = Users.get_user_by_session_token(token)
    end

    test "does not return user for invalid token" do
      refute Users.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} =
        Repo.update_all(UserToken, [set: [inserted_at: ~N[2020-01-01 00:00:00]]],
          skip_user_id: true
        )

      refute Users.get_user_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Users.generate_user_session_token(user)
      assert Users.delete_session_token(token) == :ok
      refute Users.get_user_by_session_token(token)
    end
  end
end
