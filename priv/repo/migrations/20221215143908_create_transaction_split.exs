defmodule Ledger.Repo.Migrations.CreateTransactionSplit do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :currency, :string, null: false
      add :post_date, :date, null: false
      add :description, :string, null: false

      timestamps()
    end

    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", ""

    # Add 'transactions_' as prefix to prevent external_id collision with accounts
    execute """
            ALTER TABLE transactions
              ADD COLUMN external_id bytea
                GENERATED ALWAYS AS
                  (digest('transactions_' || id::varchar(255) || '_' || user_id::varchar(255), 'sha256'))
                STORED
            """,
            "ALTER TABLE transactions DROP COLUMN external_id"

    execute """
            CREATE FUNCTION check_transactions_immutable()
            RETURNS TRIGGER
            AS $func$
              BEGIN
                IF OLD.currency <> NEW.currency THEN
                  RAISE EXCEPTION
                    'currency should be immutable'
                    USING ERRCODE = 'integrity_constraint_violation';
                END IF;
                RETURN NEW;
              END
            $func$ LANGUAGE plpgsql
            """,
            "DROP FUNCTION check_transactions_immutable()"

    execute """
            CREATE TRIGGER check_transactions_immutable BEFORE UPDATE OF currency
              ON transactions
              FOR EACH ROW
              EXECUTE PROCEDURE check_transactions_immutable()
            """,
            "DROP TRIGGER check_transactions_immutable ON transactions"

    create table(:splits) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :transaction_id, references(:transactions, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :restrict), null: false

      add :account_currency_amount, :bigint, null: false
      add :transaction_currency_amount, :bigint, null: false
      add :reconcile_date, :date

      timestamps()
    end

    # Add 'splits_' as prefix to prevent external_id collision with accounts
    execute """
            ALTER TABLE splits
              ADD COLUMN external_id bytea
                GENERATED ALWAYS AS
                  (digest('splits_' || id::varchar(255) || '_' || user_id::varchar(255), 'sha256'))
                STORED
            """,
            "ALTER TABLE splits DROP COLUMN external_id"

    execute """
            CREATE FUNCTION
              ensure_split_sum()
              RETURNS TRIGGER
              AS $func$
                BEGIN
                  IF SUM(transaction_currency_amount) <> 0 FROM changed_table THEN
                    RAISE EXCEPTION 'splits for transaction do not sum up to 0'
                      USING ERRCODE = 'integrity_constraint_violation';
                  END IF;
                  RETURN NULL; -- return value is ignored
                END
              $func$ LANGUAGE plpgsql
            """,
            "DROP FUNCTION ensure_split_sum()"

    Enum.each([{:insert, :NEW}, {:update, :NEW}, {:delete, :OLD}], fn {action, table_type} ->
      action = to_string(action)

      execute """
              CREATE TRIGGER ensure_split_sum_#{action} AFTER #{String.upcase(action)}
                ON splits
                REFERENCING #{table_type} TABLE AS changed_table
                FOR EACH STATEMENT
                EXECUTE PROCEDURE ensure_split_sum()
              """,
              "DROP TRIGGER ensure_split_sum_#{action} ON splits"
    end)
  end
end
