defmodule Ledger.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :username, :citext, null: false
      add :hashed_password, :string, null: false
      add :base_currency, :string, null: false

      timestamps()
    end

    create unique_index(:users, [:username])

    execute """
            CREATE FUNCTION
              check_immutable_users()
              RETURNS TRIGGER
              AS $func$
                BEGIN
                  IF (OLD.base_currency) <> (NEW.base_currency) THEN
                    RAISE EXCEPTION
                      'base_currency should be immutable'
                      USING ERRCODE = 'integrity_constraint_violation';
                  END IF;
                  RETURN NEW;
                END
              $func$ LANGUAGE plpgsql
            """,
            "DROP FUNCTION check_immutable_users()"

    execute """
            CREATE TRIGGER check_immutable_users BEFORE UPDATE OF base_currency
              ON users
              FOR EACH ROW
              EXECUTE PROCEDURE check_immutable_users()
            """,
            "DROP TRIGGER check_immutable_users ON users"

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create index(:users_tokens, [:inserted_at])
    create index(:users_tokens, [:context, :token, :inserted_at])
    create unique_index(:users_tokens, [:context, :token])

    execute """
            CREATE FUNCTION
              check_immutable_users_tokens()
              RETURNS TRIGGER
              AS $func$
                BEGIN
                  RAISE EXCEPTION
                    'users_tokens rows are immutable'
                    USING ERRCODE = 'integrity_constraint_violation';
                END
              $func$ LANGUAGE plpgsql
            """,
            "DROP FUNCTION check_immutable_users_tokens()"

    execute """
            CREATE TRIGGER check_immutable_users_tokens BEFORE UPDATE
              ON users_tokens
              FOR EACH ROW
              EXECUTE PROCEDURE check_immutable_users_tokens()
            """,
            "DROP TRIGGER check_immutable_users_tokens ON users_tokens"
  end
end
