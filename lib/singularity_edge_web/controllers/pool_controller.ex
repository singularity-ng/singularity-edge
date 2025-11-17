defmodule SingularityEdgeWeb.PoolController do
  @moduledoc """
  REST API for managing backend pools.
  """

  use SingularityEdgeWeb, :controller

  alias SingularityEdge.Balancer.Pool
  alias SingularityEdge.Storage

  def index(conn, _params) do
    case Storage.Pool.list() do
      {:ok, pools} ->
        json(conn, %{pools: pools})

      {:error, _reason} ->
        json(conn, %{pools: []})
    end
  end

  def create(conn, %{"name" => name, "algorithm" => algorithm}) do
    pool_opts = [
      name: name,
      algorithm: String.to_atom(algorithm)
    ]

    case DynamicSupervisor.start_child(
      SingularityEdge.PoolSupervisor,
      {Pool, pool_opts}
    ) do
      {:ok, _pid} ->
        conn
        |> put_status(:created)
        |> json(%{status: "created", name: name})

      {:error, {:already_started, _pid}} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Pool already exists"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def show(conn, %{"id" => pool_name}) do
    try do
      stats = Pool.stats(pool_name)
      backends = Pool.list_backends(pool_name)

      json(conn, %{
        stats: stats,
        backends: backends
      })
    rescue
      _e ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pool not found"})
    end
  end

  def delete(conn, %{"id" => pool_name}) do
    # Would need to implement pool termination
    conn
    |> put_status(:no_content)
    |> json(%{})
  end

  def add_backend(conn, %{"id" => pool_name, "url" => backend_url}) do
    case Pool.add_backend(pool_name, backend_url) do
      :ok ->
        json(conn, %{status: "added"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def remove_backend(conn, %{"id" => pool_name, "backend_id" => backend_id}) do
    case Pool.remove_backend(pool_name, backend_id) do
      :ok ->
        json(conn, %{status: "removed"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Backend not found"})
    end
  end
end
