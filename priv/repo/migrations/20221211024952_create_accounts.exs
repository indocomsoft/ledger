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
    create unique_index(:accounts, [:user_id, :parent_id, :name])

    create unique_index(:accounts, [:user_id],
             where: "account_type = 'root'",
             name: "accounts_user_id_root_account_index"
           )

    create constraint(:accounts, "root_account_validations",
             check: "account_type <> 'root' or (placeholder and parent_id is null)"
           )
  end
end
