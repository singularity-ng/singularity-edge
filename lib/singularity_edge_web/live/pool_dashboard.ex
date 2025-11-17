defmodule SingularityEdgeWeb.PoolDashboard do
  @moduledoc """
  LiveDashboard page for monitoring backend pools.
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Backend Pools"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h2 class="text-2xl font-bold mb-4">Backend Pools</h2>
      <p class="text-gray-600">
        Monitor and manage backend server pools and load balancing.
      </p>
      <div class="mt-4">
        <p class="text-sm text-gray-500">
          Pool management coming soon...
        </p>
      </div>
    </div>
    """
  end
end
