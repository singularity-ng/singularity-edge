defmodule SingularityEdge.Proxy.Handler do
  @moduledoc """
  HTTP/HTTPS proxy handler that forwards requests to backend servers.

  Supports multiple SSL modes:
  - Termination (flexible, full, full_strict): Decrypt at edge, inspect HTTP
  - Passthrough: Forward raw TCP stream, no decryption
  """

  require Logger

  alias SingularityEdge.Balancer.Pool
  alias SingularityEdge.Proxy.TCPHandler

  @doc """
  Proxies a request to a backend server from the given pool.

  For SSL passthrough mode, delegates to TCPHandler.
  For termination modes, uses HTTP-level proxying.
  """
  def proxy(conn, pool_name, opts \\ []) do
    ssl_mode = Keyword.get(opts, :ssl_mode, :full_strict)

    case ssl_mode do
      :passthrough ->
        # TCP-level passthrough (handled outside Plug pipeline)
        Logger.warn("SSL passthrough mode requires TCP listener, not HTTP. Falling back to HTTP proxy.")
        http_proxy(conn, pool_name)

      _ ->
        # HTTP-level proxy with SSL termination
        http_proxy(conn, pool_name)
    end
  end

  defp http_proxy(conn, pool_name) do
    case Pool.select_backend(pool_name) do
      {:ok, backend} ->
        forward_request(conn, backend)

      {:error, :no_backends} ->
        conn
        |> Plug.Conn.put_status(503)
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, Jason.encode!(%{error: "No healthy backends available"}))
    end
  end

  defp forward_request(conn, backend) do
    url = build_backend_url(backend, conn.request_path, conn.query_string)
    headers = prepare_headers(conn)

    # Read request body if present
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    Logger.debug("Proxying #{conn.method} #{conn.request_path} to #{url}")

    # Forward request to backend
    case :hackney.request(
      String.to_atom(String.downcase(conn.method)),
      url,
      headers,
      body,
      [pool: false, follow_redirect: false]
    ) do
      {:ok, status, resp_headers, client_ref} ->
        {:ok, resp_body} = :hackney.body(client_ref)

        conn
        |> put_response_headers(resp_headers)
        |> Plug.Conn.send_resp(status, resp_body)

      {:error, reason} ->
        Logger.error("Backend request failed: #{inspect(reason)}")

        conn
        |> Plug.Conn.put_status(502)
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(502, Jason.encode!(%{error: "Bad Gateway"}))
    end
  end

  defp build_backend_url(backend, path, query_string) do
    base = "#{backend.scheme}://#{backend.host}:#{backend.port}#{path}"
    if query_string != "", do: "#{base}?#{query_string}", else: base
  end

  defp prepare_headers(conn) do
    conn.req_headers
    |> Enum.reject(fn {name, _} -> name in ["host", "connection"] end)
    |> Enum.map(fn {name, value} -> {String.to_charlist(name), String.to_charlist(value)} end)
  end

  defp put_response_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, acc ->
      # Skip hop-by-hop headers
      header_name = to_string(name)
      if header_name in ["connection", "transfer-encoding", "keep-alive"] do
        acc
      else
        Plug.Conn.put_resp_header(acc, String.downcase(header_name), to_string(value))
      end
    end)
  end
end
