defmodule SingularityEdge.Balancer.SSLMode do
  @moduledoc """
  SSL/TLS modes for backend pools, inspired by Cloudflare's SSL modes.

  ## Modes

  ### Flexible (Not Recommended)
  Client → [HTTPS] → Edge → [HTTP] → Origin
  - Client to edge: Encrypted
  - Edge to origin: Plain HTTP
  - Fast but origin traffic unencrypted

  ### Full
  Client → [HTTPS] → Edge → [HTTPS] → Origin
  - Client to edge: Encrypted
  - Edge to origin: Encrypted
  - Origin cert can be self-signed (not validated)

  ### Full (Strict) - RECOMMENDED
  Client → [HTTPS] → Edge → [HTTPS] → Origin
  - Client to edge: Encrypted with valid cert
  - Edge to origin: Encrypted with valid cert
  - Origin certificate is validated
  - Most secure option

  ### Passthrough
  Client → [HTTPS] → Edge (no termination) → [HTTPS] → Origin
  - SSL traffic passes through without decryption
  - End-to-end encryption
  - No HTTP inspection possible
  """

  @type mode :: :flexible | :full | :full_strict | :passthrough

  @doc """
  Validates SSL mode configuration.
  """
  def validate(:flexible, opts) do
    # Client-to-edge: HTTPS
    # Edge-to-origin: HTTP
    {:ok, %{
      client_ssl: true,
      backend_ssl: false,
      validate_backend_cert: false,
      ssl_domain: Keyword.fetch!(opts, :ssl_domain)
    }}
  end

  def validate(:full, opts) do
    # Client-to-edge: HTTPS
    # Edge-to-origin: HTTPS (self-signed OK)
    {:ok, %{
      client_ssl: true,
      backend_ssl: true,
      validate_backend_cert: false,
      ssl_domain: Keyword.fetch!(opts, :ssl_domain)
    }}
  end

  def validate(:full_strict, opts) do
    # Client-to-edge: HTTPS
    # Edge-to-origin: HTTPS (valid cert required)
    {:ok, %{
      client_ssl: true,
      backend_ssl: true,
      validate_backend_cert: true,
      ssl_domain: Keyword.fetch!(opts, :ssl_domain)
    }}
  end

  def validate(:passthrough, _opts) do
    # No SSL termination at edge
    {:ok, %{
      client_ssl: false,
      backend_ssl: false,
      validate_backend_cert: false,
      passthrough: true
    }}
  end

  def validate(mode, _opts) do
    {:error, "Invalid SSL mode: #{inspect(mode)}. Valid modes: :flexible, :full, :full_strict, :passthrough"}
  end

  @doc """
  Returns recommended SSL mode for production.
  """
  def recommended, do: :full_strict

  @doc """
  Returns human-readable description of SSL mode.
  """
  def describe(:flexible) do
    """
    Flexible SSL (Not Recommended)
    - Client to edge: HTTPS (encrypted)
    - Edge to origin: HTTP (plain text)
    - Fast but insecure between edge and origin
    - Use only for development or trusted internal networks
    """
  end

  def describe(:full) do
    """
    Full SSL
    - Client to edge: HTTPS (encrypted)
    - Edge to origin: HTTPS (encrypted, self-signed OK)
    - Good balance of security and flexibility
    - Origin can use self-signed certificates
    """
  end

  def describe(:full_strict) do
    """
    Full (Strict) SSL - RECOMMENDED
    - Client to edge: HTTPS (encrypted)
    - Edge to origin: HTTPS (encrypted, valid cert required)
    - Maximum security with certificate validation
    - Origin must have valid SSL certificate
    - Best for production environments
    """
  end

  def describe(:passthrough) do
    """
    SSL Passthrough
    - SSL traffic passes through without termination
    - End-to-end encryption
    - No HTTP inspection or routing possible
    - Use when backends must handle SSL directly
    """
  end
end
