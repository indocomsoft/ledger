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
  end
end
