defmodule SingularityEdge.Proxy.TCPHandler do
  @moduledoc """
  TCP-level proxy for SSL passthrough mode.

  When SSL passthrough is enabled, we forward raw TCP streams without
  decryption or HTTP inspection. This provides true end-to-end encryption.
  """

  require Logger

  alias SingularityEdge.Balancer.Pool

  @doc """
  Handles SSL passthrough by forwarding raw TCP stream to backend.

  This is used when ssl_mode is :passthrough.
  """
  def proxy(client_socket, pool_name) do
    case Pool.select_backend(pool_name) do
      {:ok, backend} ->
        forward_tcp_stream(client_socket, backend)

      {:error, :no_backends} ->
        Logger.error("No healthy backends for passthrough to #{pool_name}")
        :gen_tcp.close(client_socket)
        {:error, :no_backends}
    end
  end

  defp forward_tcp_stream(client_socket, backend) do
    Logger.debug("Opening passthrough connection to #{backend.host}:#{backend.port}")

    case :gen_tcp.connect(
           String.to_charlist(backend.host),
           backend.port,
           [:binary, active: false, packet: :raw],
           5000
         ) do
      {:ok, backend_socket} ->
        # Bidirectional forwarding
        spawn(fn -> forward_direction(client_socket, backend_socket, :client_to_backend) end)
        spawn(fn -> forward_direction(backend_socket, client_socket, :backend_to_client) end)

        {:ok, :forwarding}

      {:error, reason} ->
        Logger.error("Failed to connect to backend #{backend.host}:#{backend.port}: #{inspect(reason)}")
        :gen_tcp.close(client_socket)
        {:error, reason}
    end
  end

  defp forward_direction(from_socket, to_socket, direction) do
    case :gen_tcp.recv(from_socket, 0) do
      {:ok, data} ->
        case :gen_tcp.send(to_socket, data) do
          :ok ->
            forward_direction(from_socket, to_socket, direction)

          {:error, reason} ->
            Logger.debug("Error sending #{direction}: #{inspect(reason)}")
            :gen_tcp.close(from_socket)
            :gen_tcp.close(to_socket)
        end

      {:error, :closed} ->
        Logger.debug("Connection closed: #{direction}")
        :gen_tcp.close(to_socket)

      {:error, reason} ->
        Logger.debug("Error receiving #{direction}: #{inspect(reason)}")
        :gen_tcp.close(from_socket)
        :gen_tcp.close(to_socket)
    end
  end
end
