defmodule SingularityEdgeWeb.ProxyController do
  @moduledoc """
  Controller that proxies all requests to backend servers.

  Supports multiple routing strategies:
  1. X-Pool header (highest priority)
  2. Subdomain routing (app1.example.com -> pool "app1")
  3. Domain mapping stored in Mnesia
  4. Default pool fallback
  """

  use SingularityEdgeWeb, :controller
  require Logger

  alias SingularityEdge.Proxy.Handler

  def forward(conn, _params) do
    # Get pool name from host header or use default
    pool_name = get_pool_name(conn)

    Logger.debug("Routing request to pool: #{pool_name}, host: #{get_host(conn)}")

    Handler.proxy(conn, pool_name)
  end

  defp get_pool_name(conn) do
    # Priority 1: X-Pool header (for testing and explicit routing)
    case get_req_header(conn, "x-pool") do
      [pool | _] when is_binary(pool) and byte_size(pool) > 0 ->
        pool

      _ ->
        # Priority 2: Extract from host header
        host = get_host(conn)
        extract_pool_from_host(host)
    end
  end

  defp get_host(conn) do
    case get_req_header(conn, "host") do
      [host | _] -> host
      _ -> ""
    end
  end

  defp extract_pool_from_host(host) do
    base_domain = Application.get_env(:singularity_edge, :base_domain, "singularity-edge.fly.dev")

    cond do
      # Subdomain routing: app1.singularity-edge.fly.dev -> pool "app1"
      String.ends_with?(host, ".#{base_domain}") ->
        host
        |> String.replace_suffix(".#{base_domain}", "")
        |> case do
          "" -> Application.get_env(:singularity_edge, :default_pool, "default")
          subdomain -> subdomain
        end

      # Exact match on base domain -> use default pool
      host == base_domain ->
        Application.get_env(:singularity_edge, :default_pool, "default")

      # Custom domain -> look up in Mnesia (TODO: implement domain mapping)
      # For now, fall back to default
      true ->
        Logger.debug("Custom domain #{host}, using default pool")
        Application.get_env(:singularity_edge, :default_pool, "default")
    end
  end
end
