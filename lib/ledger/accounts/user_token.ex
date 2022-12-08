defmodule Ledger.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  alias Ledger.Accounts.User
  alias Ledger.Accounts.UserToken

  @rand_size 32

  @session_validity_in_days 60

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(%User{id: user_id}) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %UserToken{token: token, context: "session", user_id: user_id}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  @spec verify_session_token_query(String.t()) :: Ecto.Query.t()
  def verify_session_token_query(token) when is_binary(token) do
    token_and_context_query(token, "session")
    |> where([user_token], user_token.inserted_at > ago(@session_validity_in_days, "day"))
    |> join(:inner, [user_token], user in assoc(user_token, :user))
    |> select([..., user], user)
  end

  @spec expired_session_token_query :: Ecto.Query.t()
  def expired_session_token_query do
    Ledger.Accounts.UserToken
    |> where([t], t.inserted_at <= ago(@session_validity_in_days, "day"))
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def token_and_context_query(token, context) do
    UserToken
    |> where(token: ^token, context: ^context)
  end

  @doc """
  Gets all tokens for the given user for the given contexts.
  """
  @spec user_and_contexts_query(User.t(), :all | [String.t()]) :: Ecto.Query.t()
  def user_and_contexts_query(%User{id: user_id}, :all) do
    UserToken
    |> where(user_id: ^user_id)
  end

  def user_and_contexts_query(user = %User{}, contexts) when is_list(contexts) do
    user_and_contexts_query(user, :all)
    |> where([t], t.context in ^contexts)
  end
end
