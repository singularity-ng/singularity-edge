defmodule SingularityEdge.Storage.Backend do
  @moduledoc """
  Mnesia-based storage for backends.

  Stores backend configuration and health state.
  """

  require Logger

  @table :backends

  @doc """
  Creates or updates a backend in Mnesia.
  """
  def create(backend_attrs) do
    now = DateTime.utc_now()

    backend_record = {
      @table,
      backend_attrs[:id],
      backend_attrs[:pool_name],
      backend_attrs[:host],
      backend_attrs[:port],
      backend_attrs[:scheme] || :http,
      backend_attrs[:weight] || 1,
      backend_attrs[:healthy] || true,
      backend_attrs[:current_connections] || 0,
      backend_attrs[:total_requests] || 0,
      backend_attrs[:last_check] || now,
      backend_attrs[:ssl_verify] || true,
      backend_attrs[:metadata] || %{},
      backend_attrs[:inserted_at] || now,
      now  # updated_at
    }

    case :mnesia.transaction(fn -> :mnesia.write(backend_record) end) do
      {:atomic, :ok} ->
        Logger.debug("Saved backend to Mnesia: #{backend_attrs[:id]}")
        {:ok, backend_attrs}

      {:aborted, reason} ->
        Logger.error("Failed to save backend to Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets a backend by ID from Mnesia.
  """
  def get(id) do
    case :mnesia.transaction(fn -> :mnesia.read(@table, id) end) do
      {:atomic, [{@table, backend_id, pool_name, host, port, scheme, weight, healthy,
                  current_connections, total_requests, last_check, ssl_verify,
                  metadata, inserted_at, updated_at}]} ->
        {:ok, %{
          id: backend_id,
          pool_name: pool_name,
          host: host,
          port: port,
          scheme: scheme,
          weight: weight,
          healthy: healthy,
          current_connections: current_connections,
          total_requests: total_requests,
          last_check: last_check,
          ssl_verify: ssl_verify,
          metadata: metadata,
          inserted_at: inserted_at,
          updated_at: updated_at
        }}

      {:atomic, []} ->
        {:error, :not_found}

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all backends for a given pool.
  """
  def list_by_pool(pool_name) do
    case :mnesia.transaction(fn ->
      # Use index on pool_name for efficient lookup
      :mnesia.index_read(@table, pool_name, 3)  # 3 is the position of pool_name field
    end) do
      {:atomic, records} ->
        backends = Enum.map(records, fn {_table, id, pool_name, host, port, scheme, weight, healthy,
                                         current_connections, total_requests, last_check, ssl_verify,
                                         metadata, inserted_at, updated_at} ->
          %{
            id: id,
            pool_name: pool_name,
            host: host,
            port: port,
            scheme: scheme,
            weight: weight,
            healthy: healthy,
            current_connections: current_connections,
            total_requests: total_requests,
            last_check: last_check,
            ssl_verify: ssl_verify,
            metadata: metadata,
            inserted_at: inserted_at,
            updated_at: updated_at
          }
        end)
        {:ok, backends}

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a backend from Mnesia.
  """
  def delete(id) do
    case :mnesia.transaction(fn -> :mnesia.delete({@table, id}) end) do
      {:atomic, :ok} ->
        Logger.debug("Deleted backend from Mnesia: #{id}")
        :ok

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates backend health and stats.
  """
  def update_health(id, healthy, last_check) do
    case get(id) do
      {:ok, backend} ->
        updated = backend
        |> Map.put(:healthy, healthy)
        |> Map.put(:last_check, last_check)
        |> Map.put(:updated_at, DateTime.utc_now())
        create(updated)

      error ->
        error
    end
  end

  @doc """
  Updates backend connection count.
  """
  def update_connections(id, current_connections) do
    case get(id) do
      {:ok, backend} ->
        updated = backend
        |> Map.put(:current_connections, current_connections)
        |> Map.put(:updated_at, DateTime.utc_now())
        create(updated)

      error ->
        error
    end
  end

  @doc """
  Increments total requests counter.
  """
  def increment_requests(id) do
    case get(id) do
      {:ok, backend} ->
        updated = backend
        |> Map.put(:total_requests, backend.total_requests + 1)
        |> Map.put(:updated_at, DateTime.utc_now())
        create(updated)

      error ->
        error
    end
  end
end
