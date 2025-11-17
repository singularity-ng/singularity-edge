defmodule SingularityEdge.Mnesia do
  @moduledoc """
  Mnesia database setup and management.

  Provides distributed, replicated storage for:
  - SSL certificates
  - Backend pools
  - Health check state
  - Configuration

  Benefits:
  - Zero external dependencies (no PostgreSQL)
  - Automatic replication across nodes
  - Built-in distributed transactions
  - Fast in-memory + disk persistence
  """

  require Logger

  @doc """
  Creates Mnesia schema and tables.
  Call this once on first deployment per node.
  """
  def create_schema do
    nodes = [node()]

    # Stop Mnesia if running
    :mnesia.stop()

    # Create schema
    case :mnesia.create_schema(nodes) do
      :ok ->
        Logger.info("Created Mnesia schema on #{inspect(nodes)}")
        :ok

      {:error, {_node, {:already_exists, _}}} ->
        Logger.info("Mnesia schema already exists")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create Mnesia schema: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Starts Mnesia and creates tables.
  """
  def setup do
    # Ensure Mnesia directory exists
    ensure_mnesia_dir()

    # Start Mnesia
    :mnesia.start()

    # Create tables
    create_tables()

    # Wait for tables
    :mnesia.wait_for_tables([:certificates, :pools, :backends], 5000)

    Logger.info("Mnesia setup complete")
    :ok
  end

  @doc """
  Creates Mnesia tables for all schemas using disc persistence.

  Mnesia disc_copies provides:
  - Data persisted to disk
  - In-memory caching for performance
  - Built into Erlang/OTP
  """
  def create_tables do
    # Certificates table (disc persistence)
    create_table(:certificates, [
      {:type, :set},
      {:disc_copies, [node()]},  # Persisted to disk
      {:attributes, [:id, :domain, :certificate, :private_key, :chain, :issuer, :expires_at, :auto_renew, :provider, :metadata, :inserted_at, :updated_at]},
      {:index, [:domain, :expires_at]}
    ])

    # Pools table (disc persistence)
    create_table(:pools, [
      {:type, :set},
      {:disc_copies, [node()]},
      {:attributes, [:name, :algorithm, :ssl_mode, :ssl_domain, :ssl_cert_id, :validate_backend_cert, :health_check_interval, :metadata, :inserted_at, :updated_at]},
      {:index, [:ssl_domain]}
    ])

    # Backends table (disc persistence)
    create_table(:backends, [
      {:type, :set},
      {:disc_copies, [node()]},
      {:attributes, [:id, :pool_name, :host, :port, :scheme, :weight, :healthy, :current_connections, :total_requests, :last_check, :ssl_verify, :metadata, :inserted_at, :updated_at]},
      {:index, [:pool_name, :healthy]}
    ])
  end

  defp create_table(name, opts) do
    case :mnesia.create_table(name, opts) do
      {:atomic, :ok} ->
        Logger.info("Created Mnesia table: #{name}")
        :ok

      {:aborted, {:already_exists, ^name}} ->
        Logger.debug("Mnesia table #{name} already exists")
        :ok

      {:aborted, reason} ->
        Logger.error("Failed to create Mnesia table #{name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Adds a node to the Mnesia cluster.
  """
  def add_node(node) when is_atom(node) do
    case :mnesia.change_config(:extra_db_nodes, [node]) do
      {:ok, [^node]} ->
        Logger.info("Added Mnesia node: #{node}")
        replicate_tables(node)
        :ok

      {:ok, []} ->
        Logger.warn("Node #{node} not found or already connected")
        :ok

      {:error, reason} ->
        Logger.error("Failed to add Mnesia node #{node}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp replicate_tables(node) do
    tables = [:certificates, :pools, :backends]

    Enum.each(tables, fn table ->
      # Use disc_copies for replication
      case :mnesia.add_table_copy(table, node, :disc_copies) do
        {:atomic, :ok} ->
          Logger.info("Replicated table #{table} to #{node}")

        {:aborted, {:already_exists, ^table, ^node}} ->
          Logger.debug("Table #{table} already exists on #{node}")

        {:aborted, reason} ->
          Logger.warn("Failed to replicate #{table} to #{node}: #{inspect(reason)}")
      end
    end)
  end

  @doc """
  Returns Mnesia info (tables, size, memory).
  """
  def info do
    tables = :mnesia.system_info(:tables)
    running_nodes = :mnesia.system_info(:running_db_nodes)

    %{
      tables: tables,
      nodes: running_nodes,
      node: node(),
      directory: :mnesia.system_info(:directory),
      is_running: :mnesia.system_info(:is_running)
    }
  end

  defp ensure_mnesia_dir do
    dir = Application.get_env(:mnesia, :dir, 'data/mnesia')
    File.mkdir_p!(to_string(dir))
  end
end
