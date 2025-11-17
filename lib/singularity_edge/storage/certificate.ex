defmodule SingularityEdge.Storage.Certificate do
  @moduledoc """
  Mnesia-based certificate storage.

  Stores SSL/TLS certificates in distributed Mnesia database.
  """

  require Logger
  alias :mnesia, as: Mnesia

  @table :certificates

  defstruct [
    :id,
    :domain,
    :certificate,
    :private_key,
    :chain,
    :issuer,
    :expires_at,
    :auto_renew,
    :provider,
    :metadata,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new certificate record.
  """
  def create(attrs) do
    cert = %__MODULE__{
      id: generate_id(),
      domain: attrs[:domain] || attrs["domain"],
      certificate: attrs[:certificate] || attrs["certificate"],
      private_key: attrs[:private_key] || attrs["private_key"],
      chain: attrs[:chain] || attrs["chain"],
      issuer: attrs[:issuer] || attrs["issuer"] || "letsencrypt",
      expires_at: attrs[:expires_at] || attrs["expires_at"],
      auto_renew: attrs[:auto_renew] || attrs["auto_renew"] || true,
      provider: attrs[:provider] || attrs["provider"] || "letsencrypt",
      metadata: attrs[:metadata] || attrs["metadata"] || %{},
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    transaction(fn ->
      Mnesia.write({@table, cert.id, cert.domain, cert.certificate, cert.private_key,
                    cert.chain, cert.issuer, cert.expires_at, cert.auto_renew,
                    cert.provider, cert.metadata, cert.inserted_at, cert.updated_at})
    end)

    {:ok, cert}
  end

  @doc """
  Gets a certificate by ID.
  """
  def get(id) do
    case transaction(fn -> Mnesia.read(@table, id) end) do
      {:atomic, [record]} -> {:ok, record_to_struct(record)}
      {:atomic, []} -> {:error, :not_found}
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets a certificate by domain.
  """
  def get_by_domain(domain) do
    match_spec = [
      {{@table, :"$1", domain, :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9", :"$10", :"$11"},
       [],
       [:"$_"]}
    ]

    case transaction(fn -> Mnesia.select(@table, match_spec) end) do
      {:atomic, [record | _]} -> {:ok, record_to_struct(record)}
      {:atomic, []} -> {:error, :not_found}
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all certificates.
  """
  def list do
    case transaction(fn -> Mnesia.all_keys(@table) end) do
      {:atomic, keys} ->
        certs = Enum.map(keys, fn key ->
          {:atomic, [record]} = transaction(fn -> Mnesia.read(@table, key) end)
          record_to_struct(record)
        end)
        {:ok, certs}

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a certificate.
  """
  def delete(id) do
    transaction(fn -> Mnesia.delete({@table, id}) end)
    :ok
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

  defp transaction(fun) do
    Mnesia.transaction(fun)
  end

  defp record_to_struct({@table, id, domain, certificate, private_key, chain, issuer, expires_at, auto_renew, provider, metadata, inserted_at, updated_at}) do
    %__MODULE__{
      id: id,
      domain: domain,
      certificate: certificate,
      private_key: private_key,
      chain: chain,
      issuer: issuer,
      expires_at: expires_at,
      auto_renew: auto_renew,
      provider: provider,
      metadata: metadata,
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
