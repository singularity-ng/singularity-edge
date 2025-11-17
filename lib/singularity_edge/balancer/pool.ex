defmodule SingularityEdge.Balancer.Pool do
  @moduledoc """
  Manages a pool of backend servers with health checking and load balancing.

  Each pool represents a group of backends serving the same application.
  """

  use GenServer
  require Logger

  alias SingularityEdge.Balancer.{Backend, Algorithm}

  @type ssl_mode :: :flexible | :full | :full_strict | :passthrough | :off

  defstruct [
    :name,
    :algorithm,
    backends: [],
    algorithm_state: %{},
    health_check_interval: 10_000,  # 10 seconds
    ssl_mode: :full_strict,         # :flexible | :full | :full_strict | :passthrough | :off
    ssl_domain: nil,                # Domain for SSL cert (if terminating)
    ssl_cert_id: nil,               # Certificate ID (if using custom cert)
    validate_backend_cert: true     # Validate backend SSL certificates (full_strict)
  ]

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Adds a backend to the pool.
  """
  def add_backend(pool_name, backend_url) when is_binary(backend_url) do
    backend = Backend.new(backend_url)
    GenServer.call(via_tuple(pool_name), {:add_backend, backend})
  end

  def add_backend(pool_name, %Backend{} = backend) do
    GenServer.call(via_tuple(pool_name), {:add_backend, backend})
  end

  @doc """
  Removes a backend from the pool.
  """
  def remove_backend(pool_name, backend_id) do
    GenServer.call(via_tuple(pool_name), {:remove_backend, backend_id})
  end

  @doc """
  Selects a backend for handling a request.
  """
  def select_backend(pool_name) do
    GenServer.call(via_tuple(pool_name), :select_backend)
  end

  @doc """
  Lists all backends in the pool.
  """
  def list_backends(pool_name) do
    GenServer.call(via_tuple(pool_name), :list_backends)
  end

  @doc """
  Gets pool statistics.
  """
  def stats(pool_name) do
    GenServer.call(via_tuple(pool_name), :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      algorithm: Keyword.get(opts, :algorithm, :round_robin),
      backends: Keyword.get(opts, :backends, []) |> Enum.map(&Backend.new/1),
      health_check_interval: Keyword.get(opts, :health_check_interval, 10_000)
    }

    # Schedule first health check
    schedule_health_check(state.health_check_interval)

    Logger.info("Started pool #{state.name} with #{length(state.backends)} backends")
    {:ok, state}
  end

  @impl true
  def handle_call({:add_backend, backend}, _from, state) do
    if Enum.any?(state.backends, &(&1.id == backend.id)) do
      {:reply, {:error, :already_exists}, state}
    else
      new_state = %{state | backends: [backend | state.backends]}
      Logger.info("Added backend #{backend.id} to pool #{state.name}")
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:remove_backend, backend_id}, _from, state) do
    new_backends = Enum.reject(state.backends, &(&1.id == backend_id))

    if length(new_backends) == length(state.backends) do
      {:reply, {:error, :not_found}, state}
    else
      new_state = %{state | backends: new_backends}
      Logger.info("Removed backend #{backend_id} from pool #{state.name}")
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:select_backend, _from, state) do
    case Algorithm.select(state.backends, state.algorithm, state.algorithm_state) do
      {:ok, backend} ->
        # Update backend connection count
        updated_backends = Enum.map(state.backends, fn b ->
          if b.id == backend.id, do: Backend.inc_connections(b), else: b
        end)

        # Update algorithm state
        new_algorithm_state = Algorithm.update_state(state.algorithm, state.algorithm_state)

        new_state = %{state |
          backends: updated_backends,
          algorithm_state: new_algorithm_state
        }

        {:reply, {:ok, backend}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list_backends, _from, state) do
    {:reply, state.backends, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total_backends = length(state.backends)
    healthy_backends = Enum.count(state.backends, & &1.healthy)
    total_connections = Enum.sum(Enum.map(state.backends, & &1.current_connections))
    total_requests = Enum.sum(Enum.map(state.backends, & &1.total_requests))

    stats = %{
      pool_name: state.name,
      algorithm: state.algorithm,
      total_backends: total_backends,
      healthy_backends: healthy_backends,
      unhealthy_backends: total_backends - healthy_backends,
      current_connections: total_connections,
      total_requests: total_requests
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Perform health checks on all backends
    updated_backends = Enum.map(state.backends, &check_backend_health/1)

    # Schedule next health check
    schedule_health_check(state.health_check_interval)

    {:noreply, %{state | backends: updated_backends}}
  end

  # Private Functions

  defp via_tuple(name) do
    {:via, Registry, {SingularityEdge.PoolRegistry, name}}
  end

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  defp check_backend_health(%Backend{} = backend) do
    # Simple TCP connection check
    case :gen_tcp.connect(
      String.to_charlist(backend.host),
      backend.port,
      [:binary, active: false],
      1000
    ) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        Backend.set_health(backend, true)

      {:error, _reason} ->
        Backend.set_health(backend, false)
    end
  end
end
