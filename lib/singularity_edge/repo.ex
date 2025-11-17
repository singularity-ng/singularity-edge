defmodule SingularityEdge.Repo do
  use Ecto.Repo,
    otp_app: :singularity_edge,
    adapter: Ecto.Adapters.Postgres
end
