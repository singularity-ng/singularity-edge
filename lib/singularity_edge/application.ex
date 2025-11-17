defmodule SingularityEdge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Setup Mnesia before starting children
    setup_mnesia()

    children = [
      SingularityEdgeWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:singularity_edge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SingularityEdge.PubSub},

      # Registry for backend pools
      {Registry, keys: :unique, name: SingularityEdge.PoolRegistry},

      # Cluster topology for distributed edge nodes
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, []), [name: SingularityEdge.ClusterSupervisor]]},

      # Dynamic supervisor for pools
      {DynamicSupervisor, name: SingularityEdge.PoolSupervisor, strategy: :one_for_one},

      # Start to serve requests, typically the last entry
      SingularityEdgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SingularityEdge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp setup_mnesia do
    # Setup Mnesia on application start
    try do
      SingularityEdge.Mnesia.setup()
    rescue
      e ->
        require Logger
        Logger.error("Failed to setup Mnesia: #{inspect(e)}")
        Logger.error("Mnesia stacktrace: #{Exception.format_stacktrace()}")
        # Re-raise to prevent app from starting with broken database
        reraise e, __STACKTRACE__
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SingularityEdgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
