defmodule SingularityEdgeWeb.Router do
  use SingularityEdgeWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SingularityEdgeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Admin interface
  scope "/admin" do
    pipe_through :browser

    live_dashboard "/dashboard",
      metrics: SingularityEdgeWeb.Telemetry,
      additional_pages: [
        pools: SingularityEdgeWeb.PoolDashboard
      ]
  end

  scope "/", SingularityEdgeWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API endpoints for management
  scope "/api", SingularityEdgeWeb do
    pipe_through :api

    get "/health", HealthController, :index
    resources "/pools", PoolController, except: [:new, :edit]
    post "/pools/:id/backends", PoolController, :add_backend
    delete "/pools/:id/backends/:backend_id", PoolController, :remove_backend

    # SSL certificate management
    resources "/certificates", CertificateController, except: [:new, :edit]
    post "/certificates/:id/renew", CertificateController, :renew

    # ACME challenge endpoint (Let's Encrypt HTTP-01)
    get "/.well-known/acme-challenge/:token", ACMEController, :challenge
  end

  # Proxy catch-all (must be last)
  # This forwards all other traffic to configured backend pools
  scope "/", SingularityEdgeWeb do
    # No pipeline - direct proxy
    match :*, "/*path", ProxyController, :forward
  end
end
