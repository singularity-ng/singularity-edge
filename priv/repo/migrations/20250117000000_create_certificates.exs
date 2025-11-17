defmodule SingularityEdge.Repo.Migrations.CreateCertificates do
  use Ecto.Migration

  def change do
    create table(:certificates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :string, null: false
      add :certificate, :text, null: false
      add :private_key, :text, null: false
      add :chain, :text
      add :issuer, :string
      add :expires_at, :utc_datetime, null: false
      add :auto_renew, :boolean, default: true
      add :provider, :string, default: "letsencrypt"
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:certificates, [:domain])
    create index(:certificates, [:expires_at])
  end
end
