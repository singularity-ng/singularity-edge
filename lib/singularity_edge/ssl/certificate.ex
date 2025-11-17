defmodule SingularityEdge.SSL.Certificate do
  @moduledoc """
  Schema for SSL/TLS certificates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "certificates" do
    field :domain, :string
    field :certificate, :string
    field :private_key, :string
    field :chain, :string
    field :issuer, :string
    field :expires_at, :utc_datetime
    field :auto_renew, :boolean, default: true
    field :provider, :string, default: "letsencrypt"
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(certificate, attrs) do
    certificate
    |> cast(attrs, [
      :domain,
      :certificate,
      :private_key,
      :chain,
      :issuer,
      :expires_at,
      :auto_renew,
      :provider,
      :metadata
    ])
    |> validate_required([:domain, :certificate, :private_key, :expires_at])
    |> unique_constraint(:domain)
  end

  @doc """
  Checks if certificate is expiring soon (within 30 days).
  """
  def expiring_soon?(%__MODULE__{expires_at: expires_at}) do
    days_until_expiry = DateTime.diff(expires_at, DateTime.utc_now(), :day)
    days_until_expiry <= 30
  end

  @doc """
  Checks if certificate has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end
end
