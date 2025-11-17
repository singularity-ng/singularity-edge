defmodule SingularityEdgeWeb.CertificateController do
  @moduledoc """
  REST API for SSL certificate management.
  """

  use SingularityEdgeWeb, :controller

  alias SingularityEdge.{Repo, SSL.Certificate, SSL.ACME}
  import Ecto.Query

  def index(conn, _params) do
    certificates =
      Certificate
      |> order_by(desc: :inserted_at)
      |> Repo.all()

    json(conn, %{
      certificates: Enum.map(certificates, &serialize_certificate/1)
    })
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Certificate, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Certificate not found"})

      certificate ->
        json(conn, serialize_certificate(certificate))
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
    case Repo.get(Certificate, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Certificate not found"})

      certificate ->
        Repo.delete!(certificate)

        conn
        |> put_status(:no_content)
        |> json(%{})
    end
  end

  def renew(conn, %{"id" => id}) do
    case Repo.get(Certificate, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Certificate not found"})

      certificate ->
        case ACME.renew_certificate(certificate) do
          {:ok, _cert} ->
            json(conn, %{status: "renewed"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: inspect(reason)})
        end
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
