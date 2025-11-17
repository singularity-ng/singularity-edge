defmodule SingularityEdgeWeb.ProxyController do
  @moduledoc """
  Controller that proxies all requests to backend servers.
  """

  use SingularityEdgeWeb, :controller

  alias SingularityEdge.Proxy.Handler

  def forward(conn, _params) do
    # Get pool name from host header or use default
    pool_name = get_pool_name(conn)

    Handler.proxy(conn, pool_name)
  end

  defp get_pool_name(conn) do
    # Simple routing: use host header to determine pool
    # Example: app1.singularity-edge.com -> pool: "app1"
    # For now, use a default pool
    Application.get_env(:singularity_edge, :default_pool, "default")
  end
end
