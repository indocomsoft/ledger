defmodule LedgerWeb.AccountController do
  use LedgerWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end

  def create(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end

  def show(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end

  def update(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end

  def delete(conn, _params) do
    conn
    |> put_status(:not_implemented)
    |> json(%{"error" => "TODO to be implemented"})
  end
end
