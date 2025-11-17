defmodule SingularityEdge.SSL.Certificate do
  @moduledoc """
  SSL/TLS certificate management with Mnesia storage.
  """

  require Logger

  @type t :: %{
          id: binary(),
          domain: String.t(),
          certificate: String.t(),
          private_key: String.t(),
          chain: String.t() | nil,
          issuer: String.t() | nil,
          expires_at: DateTime.t(),
          auto_renew: boolean(),
          provider: String.t(),
          metadata: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Creates a new certificate record in Mnesia.
  """
  def create(attrs) do
    now = DateTime.utc_now()
    id = attrs[:id] || generate_id()

    cert_record = {
      :certificates,
      id,
      attrs[:domain],
      attrs[:certificate],
      attrs[:private_key],
      attrs[:chain],
      attrs[:issuer],
      attrs[:expires_at],
      attrs[:auto_renew] || true,
      attrs[:provider] || "letsencrypt",
      attrs[:metadata] || %{},
      now,
      now
    }

    case :mnesia.transaction(fn -> :mnesia.write(cert_record) end) do
      {:atomic, :ok} ->
        Logger.info("Created certificate for domain: #{attrs[:domain]}")
        {:ok, to_map(cert_record)}

      {:aborted, reason} ->
        Logger.error("Failed to create certificate: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets a certificate by ID.
  """
  def get(id) do
    case :mnesia.transaction(fn -> :mnesia.read(:certificates, id) end) do
      {:atomic, [cert_record]} ->
        {:ok, to_map(cert_record)}

      {:atomic, []} ->
        {:error, :not_found}

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a certificate by domain.
  """
  def get_by_domain(domain) do
    case :mnesia.transaction(fn ->
           :mnesia.index_read(:certificates, domain, 3)
         end) do
      {:atomic, [cert_record | _]} ->
        {:ok, to_map(cert_record)}

      {:atomic, []} ->
        {:error, :not_found}

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all certificates, ordered by inserted_at descending.
  """
  def list do
    case :mnesia.transaction(fn ->
           :mnesia.foldl(fn cert, acc -> [cert | acc] end, [], :certificates)
         end) do
      {:atomic, certs} ->
        certs
        |> Enum.map(&to_map/1)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> then(&{:ok, &1})

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a certificate record.
  """
  def update(id, attrs) do
    case :mnesia.transaction(fn ->
           case :mnesia.read(:certificates, id) do
             [] ->
               {:error, :not_found}

             [
               {:certificates, ^id, domain, certificate, private_key, chain, issuer, expires_at,
                auto_renew, provider, metadata, inserted_at, _updated_at}
             ] ->
               updated_record = {
                 :certificates,
                 id,
                 attrs[:domain] || domain,
                 attrs[:certificate] || certificate,
                 attrs[:private_key] || private_key,
                 attrs[:chain] || chain,
                 attrs[:issuer] || issuer,
                 attrs[:expires_at] || expires_at,
                 Map.get(attrs, :auto_renew, auto_renew),
                 attrs[:provider] || provider,
                 attrs[:metadata] || metadata,
                 inserted_at,
                 DateTime.utc_now()
               }

               :mnesia.write(updated_record)
               {:ok, to_map(updated_record)}
           end
         end) do
      {:atomic, result} ->
        result

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a certificate.
  """
  def delete(id) do
    case :mnesia.transaction(fn -> :mnesia.delete({:certificates, id}) end) do
      {:atomic, :ok} ->
        Logger.info("Deleted certificate: #{id}")
        :ok

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if certificate is expiring soon (within 30 days).
  """
  def expiring_soon?(%{expires_at: expires_at}) do
    days_until_expiry = DateTime.diff(expires_at, DateTime.utc_now(), :day)
    days_until_expiry <= 30
  end

  @doc """
  Checks if certificate has expired.
  """
  def expired?(%{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Validates certificate attributes.
  """
  def validate(attrs) do
    errors = []

    errors =
      if is_nil(attrs[:domain]) or attrs[:domain] == "",
        do: [{:domain, "can't be blank"} | errors],
        else: errors

    errors =
      if is_nil(attrs[:certificate]) or attrs[:certificate] == "",
        do: [{:certificate, "can't be blank"} | errors],
        else: errors

    errors =
      if is_nil(attrs[:private_key]) or attrs[:private_key] == "",
        do: [{:private_key, "can't be blank"} | errors],
        else: errors

    errors =
      if is_nil(attrs[:expires_at]), do: [{:expires_at, "can't be blank"} | errors], else: errors

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  # Private functions

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp to_map(
         {:certificates, id, domain, certificate, private_key, chain, issuer, expires_at,
          auto_renew, provider, metadata, inserted_at, updated_at}
       ) do
    %{
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
end
