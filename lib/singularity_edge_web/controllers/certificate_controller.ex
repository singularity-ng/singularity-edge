defmodule SingularityEdgeWeb.CertificateController do
  @moduledoc """
  REST API for SSL certificate management.
  """

  use SingularityEdgeWeb, :controller

  alias SingularityEdge.SSL.{Certificate, ACME}

  def index(conn, _params) do
    case Certificate.list() do
      {:ok, certificates} ->
        json(conn, %{
          certificates: Enum.map(certificates, &serialize_certificate/1)
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(reason)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Certificate.get(id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Certificate not found"})

      {:ok, certificate} ->
        json(conn, serialize_certificate(certificate))

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(reason)})
    end
  end

  def create(conn, %{"domain" => domain}) do
    # Provision certificate via Let's Encrypt
    case ACME.provision_certificate(domain) do
      {:ok, :certificate_provisioned} ->
        conn
        |> put_status(:created)
        |> json(%{status: "provisioning", domain: domain})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Certificate.get(id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Certificate not found"})

      {:ok, _certificate} ->
        case Certificate.delete(id) do
          :ok ->
            conn
            |> put_status(:no_content)
            |> json(%{})

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: inspect(reason)})
        end

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(reason)})
    end
  end

  def renew(conn, %{"id" => id}) do
    case Certificate.get(id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Certificate not found"})

      {:ok, certificate} ->
        case ACME.renew_certificate(certificate) do
          {:ok, _cert} ->
            json(conn, %{status: "renewed"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: inspect(reason)})
        end

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(reason)})
    end
  end

  defp serialize_certificate(cert) do
    %{
      id: cert.id,
      domain: cert.domain,
      issuer: cert.issuer,
      expires_at: cert.expires_at,
      auto_renew: cert.auto_renew,
      provider: cert.provider,
      expiring_soon: Certificate.expiring_soon?(cert),
      expired: Certificate.expired?(cert),
      inserted_at: cert.inserted_at,
      updated_at: cert.updated_at
    }
  end
end
