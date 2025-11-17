defmodule SingularityEdge.Balancer.Backend do
  @moduledoc """
  Represents a backend server that can receive proxied requests.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          host: String.t(),
          port: integer(),
          scheme: :http | :https,
          weight: integer(),
          healthy: boolean(),
          current_connections: integer(),
          total_requests: integer(),
          last_check: DateTime.t() | nil,
          metadata: map()
        }

  @enforce_keys [:id, :host, :port]
  defstruct [
    :id,
    :host,
    :port,
    :last_check,
    scheme: :http,
    weight: 1,
    healthy: true,
    current_connections: 0,
    total_requests: 0,
    metadata: %{}
  ]

  @doc """
  Creates a new backend from a URL string.

  ## Examples

      iex> Backend.new("http://192.168.1.10:8080")
      %Backend{host: "192.168.1.10", port: 8080, scheme: :http}
  """
  def new(url) when is_binary(url) do
    uri = URI.parse(url)

    %__MODULE__{
      id: generate_id(uri),
      host: uri.host,
      port: uri.port || default_port(uri.scheme),
      scheme: String.to_atom(uri.scheme)
    }
  end

  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Returns the full URL for this backend.
  """
  def url(%__MODULE__{} = backend) do
    "#{backend.scheme}://#{backend.host}:#{backend.port}"
  end

  @doc """
  Marks backend as healthy or unhealthy.
  """
  def set_health(%__MODULE__{} = backend, healthy) when is_boolean(healthy) do
    %{backend | healthy: healthy, last_check: DateTime.utc_now()}
  end

  @doc """
  Increments the connection counter.
  """
  def inc_connections(%__MODULE__{} = backend) do
    %{backend |
      current_connections: backend.current_connections + 1,
      total_requests: backend.total_requests + 1
    }
  end

  @doc """
  Decrements the connection counter.
  """
  def dec_connections(%__MODULE__{} = backend) do
    %{backend | current_connections: max(0, backend.current_connections - 1)}
  end

  defp generate_id(uri) do
    "#{uri.scheme}://#{uri.host}:#{uri.port}"
  end

  defp default_port("http"), do: 80
  defp default_port("https"), do: 443
  defp default_port(_), do: 80
end
