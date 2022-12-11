defmodule Ledger.Repo do
  use Ecto.Repo,
    otp_app: :ledger,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  @impl true
  @spec prepare_query(operation, query :: Ecto.Query.t(), opts :: Keyword.t()) ::
          {Ecto.Query.t(), Keyword.t()}
        when operation: :all | :update_all | :delete_all | :stream | :insert_all
  def prepare_query(operation, query, opts) do
    cond do
      opts[:skip_user_id] || opts[:schema_migration] ->
        {query, opts}

      user_id = opts[:user_id] ->
        {Ecto.Query.where(query, user_id: ^user_id), opts}

      true ->
        raise "expected user_id or skip_user_id to be set for operation #{operation}"
    end
  end

  @impl true
  @spec default_options(atom()) :: Keyword.t()
  def default_options(_operation) do
    case get_user_id() do
      nil -> []
      user_id -> [user_id: user_id]
    end
  end

  @tenant_key {__MODULE__, :user_id}

  @spec put_user_id(integer() | nil) :: integer() | nil
  def put_user_id(user_id) when is_integer(user_id) do
    Process.put(@tenant_key, user_id)
  end

  @spec delete_user_id() :: integer() | nil
  def delete_user_id() do
    Process.delete(@tenant_key)
  end

  @spec get_user_id :: integer() | nil
  def get_user_id() do
    Process.get(@tenant_key)
  end
end
