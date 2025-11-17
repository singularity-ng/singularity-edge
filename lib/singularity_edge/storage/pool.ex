defmodule SingularityEdge.Storage.Pool do
  @moduledoc """
  Mnesia-based storage for backend pools.

  Stores pool configuration and ensures persistence across deployments.
  """

  require Logger

  @table :pools

  @doc """
  Creates or updates a pool in Mnesia.
  """
  def create(pool_attrs) do
    now = DateTime.utc_now()

    pool_record = {
      @table,
      pool_attrs[:name],
      pool_attrs[:algorithm] || :round_robin,
      pool_attrs[:ssl_mode] || :full_strict,
      pool_attrs[:ssl_domain],
      pool_attrs[:ssl_cert_id],
      pool_attrs[:validate_backend_cert] || true,
      pool_attrs[:health_check_interval] || 10_000,
      pool_attrs[:metadata] || %{},
      pool_attrs[:inserted_at] || now,
      now  # updated_at
    }

    case :mnesia.transaction(fn -> :mnesia.write(pool_record) end) do
      {:atomic, :ok} ->
        Logger.info("Saved pool to Mnesia: #{pool_attrs[:name]}")
        {:ok, pool_attrs}

      {:aborted, reason} ->
        Logger.error("Failed to save pool to Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets a pool by name from Mnesia.
  """
  def get(name) do
    case :mnesia.transaction(fn -> :mnesia.read(@table, name) end) do
      {:atomic, [{@table, pool_name, algorithm, ssl_mode, ssl_domain, ssl_cert_id,
                  validate_backend_cert, health_check_interval, metadata, inserted_at, updated_at}]} ->
        {:ok, %{
          name: pool_name,
          algorithm: algorithm,
          ssl_mode: ssl_mode,
          ssl_domain: ssl_domain,
          ssl_cert_id: ssl_cert_id,
          validate_backend_cert: validate_backend_cert,
          health_check_interval: health_check_interval,
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
  Lists all pools from Mnesia.
  """
  def list do
    case :mnesia.transaction(fn ->
      :mnesia.foldl(
        fn {_table, name, algorithm, ssl_mode, ssl_domain, ssl_cert_id,
            validate_backend_cert, health_check_interval, metadata, inserted_at, updated_at}, acc ->
          pool = %{
            name: name,
            algorithm: algorithm,
            ssl_mode: ssl_mode,
            ssl_domain: ssl_domain,
            ssl_cert_id: ssl_cert_id,
            validate_backend_cert: validate_backend_cert,
            health_check_interval: health_check_interval,
            metadata: metadata,
            inserted_at: inserted_at,
            updated_at: updated_at
          }
          [pool | acc]
        end,
        [],
        @table
      )
    end) do
      {:atomic, pools} -> {:ok, pools}
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a pool from Mnesia.
  """
  def delete(name) do
    case :mnesia.transaction(fn -> :mnesia.delete({@table, name}) end) do
      {:atomic, :ok} ->
        Logger.info("Deleted pool from Mnesia: #{name}")
        :ok

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a pool in Mnesia.
  """
  def update(name, attrs) do
    case get(name) do
      {:ok, existing} ->
        updated = Map.merge(existing, attrs) |> Map.put(:updated_at, DateTime.utc_now())
        create(updated)

      error ->
        error
    end
  end
end
