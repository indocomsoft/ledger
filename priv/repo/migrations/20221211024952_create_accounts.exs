defmodule Ledger.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    account_type_values = ~w(root asset equity liability income expense)a

    execute "CREATE TYPE account_type AS ENUM (#{Enum.map_join(account_type_values, ", ", &"'#{&1}'")})",
            "DROP TYPE account_type"

    create table(:accounts) do
      add :account_type, :account_type, null: false
      add :currency, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :placeholder, :boolean, null: false
      add :parent_id, references(:accounts, on_delete: :restrict)
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", ""

    execute """
            ALTER TABLE accounts
              ADD COLUMN external_id bytea
                GENERATED ALWAYS AS
                  (digest(id::varchar(255) || '_' || user_id::varchar(255), 'sha256'))
                STORED
            """,
            "ALTER TABLE accounts DROP COLUMN external_id"

    create index(:accounts, [:user_id, :account_type])
    create unique_index(:accounts, [:external_id])
    create unique_index(:accounts, [:parent_id, :user_id, :name])

    create unique_index(:accounts, [:user_id],
             where: "account_type = 'root'",
             name: "accounts_user_id_root_account_index"
           )

    create constraint(:accounts, "root_account_validations",
             check: "account_type <> 'root' or (placeholder and parent_id is null)"
           )

    execute """
            CREATE FUNCTION
              ensure_tree_account()
              RETURNS trigger
              AS $func$
                BEGIN
                  IF EXISTS (
                    WITH RECURSIVE self_and_descendants AS (
                      SELECT accounts.id, accounts.parent_id
                      FROM accounts
                      WHERE accounts.id = OLD.id
                      UNION ALL
                      SELECT accounts.id, accounts.parent_id
                      FROM accounts
                      JOIN self_and_descendants ON self_and_descendants.id = accounts.parent_id
                    )
                    SELECT self_and_descendants.id
                    FROM self_and_descendants
                    WHERE self_and_descendants.id = NEW.parent_id
                  ) THEN
                    RAISE EXCEPTION
                      'new parent_id refers to one of the self_and_descendants of the current account'
                      USING ERRCODE = 'integrity_constraint_violation';
                  END IF;
                  RETURN NEW;
                END
              $func$ LANGUAGE plpgsql
            """,
            "DROP FUNCTION ensure_tree_account()"

    execute """
            CREATE TRIGGER ensure_tree BEFORE UPDATE OF parent_id
              ON accounts
              FOR EACH ROW
              EXECUTE PROCEDURE ensure_tree_account()
            """,
            "DROP TRIGGER ensure_tree ON accounts"
  end
end
