defmodule SingularityEdgeWeb.HealthController do
  @moduledoc """
  Health check endpoint for load balancers and monitoring.
  """

  use SingularityEdgeWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      status: "healthy",
      node: node(),
      uptime: System.monotonic_time(:second)
    })
  end
end
