# SSL/TLS Configuration Guide

Singularity Edge supports multiple SSL/TLS modes to fit different deployment scenarios.

## SSL Modes

### 1. **Termination Mode** (Recommended)

SSL is terminated at the edge load balancer. Traffic from clients is encrypted, but backend communication can be HTTP or HTTPS.

**Use cases:**
- Smart routing based on HTTP headers/paths
- Request inspection and logging
- Offload SSL processing from backends
- Centralized certificate management

**Configuration:**

```elixir
# When creating a pool
%{
  name: "my-app",
  algorithm: "least_connections",
  ssl_mode: :terminate,
  ssl_domain: "api.example.com"
}
```

**API Example:**

```bash
curl -X POST http://localhost:4000/api/pools \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "algorithm": "least_connections",
    "ssl_mode": "terminate",
    "ssl_domain": "api.example.com"
  }'
```

### 2. **Passthrough Mode**

SSL traffic passes through to backends without decryption. The backend handles SSL termination.

**Use cases:**
- End-to-end encryption required
- Backends already handle SSL
- Compliance requirements (medical, financial)
- No need for HTTP-level routing

**Configuration:**

```elixir
%{
  name: "secure-app",
  algorithm: "round_robin",
  ssl_mode: :passthrough
}
```

### 3. **Off Mode**

No SSL - plain HTTP only. Only use in development or trusted internal networks.

**Configuration:**

```elixir
%{
  name: "internal-app",
  ssl_mode: :off
}
```

## Certificate Management

### Automatic Certificates (Let's Encrypt)

Singularity Edge can automatically provision and renew SSL certificates using Let's Encrypt.

**Requirements:**
- Domain must point to your edge load balancer
- HTTP-01 challenge endpoint must be accessible
- Valid email for Let's Encrypt notifications

**Provision a certificate:**

```bash
# Via API
curl -X POST http://localhost:4000/api/certificates \
  -H "Content-Type: application/json" \
  -d '{"domain": "api.example.com"}'
```

**Auto-renewal:**
- Certificates are automatically renewed 30 days before expiration
- Renewal runs daily
- Failed renewals trigger alerts

**List certificates:**

```bash
curl http://localhost:4000/api/certificates
```

**Manual renewal:**

```bash
curl -X POST http://localhost:4000/api/certificates/:id/renew
```

### Custom Certificates (Manual Upload)

You can upload your own certificates (wildcard, EV, etc.).

```bash
# Coming soon
curl -X POST http://localhost:4000/api/certificates/upload \
  -F "domain=*.example.com" \
  -F "certificate=@cert.pem" \
  -F "private_key=@key.pem" \
  -F "chain=@chain.pem"
```

### Certificate Storage

Certificates are stored securely in PostgreSQL:
- Private keys are encrypted at rest
- Access controlled via API authentication
- Automatic expiration tracking
- Audit logs for certificate operations

## Fly.io Deployment

When deploying to Fly.io, SSL is handled automatically:

**For `*.fly.dev` domains:**
- Fly.io provides automatic SSL certificates
- No configuration needed
- Just deploy: `flyctl deploy`

**For custom domains:**

```bash
# Add custom domain
flyctl certs create api.example.com

# Check certificate status
flyctl certs list

# Fly.io handles Let's Encrypt automatically
```

## Security Best Practices

1. **Always use SSL in production** - Set `ssl_mode: :terminate` or `:passthrough`
2. **Enable auto-renewal** - Let's Encrypt certs expire after 90 days
3. **Monitor expiration** - Set up alerts for certificates expiring soon
4. **Use strong ciphers** - Modern TLS 1.2+ only
5. **HSTS headers** - Force HTTPS in browsers

## Example Configurations

### Public API with Auto SSL

```bash
# Create pool with SSL termination
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "api",
    "algorithm": "least_connections",
    "ssl_mode": "terminate",
    "ssl_domain": "api.example.com"
  }'

# Provision Let's Encrypt certificate
curl -X POST http://localhost:4000/api/certificates \
  -d '{"domain": "api.example.com"}'

# Add backends (HTTP is fine - SSL terminated at edge)
curl -X POST http://localhost:4000/api/pools/api/backends \
  -d '{"url": "http://10.0.1.10:8080"}'
```

### High-Security App with Passthrough

```bash
# Create pool with SSL passthrough
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "secure-app",
    "algorithm": "round_robin",
    "ssl_mode": "passthrough"
  }'

# Add backends (must handle HTTPS)
curl -X POST http://localhost:4000/api/pools/secure-app/backends \
  -d '{"url": "https://10.0.1.10:8443"}'
```

## Troubleshooting

**Certificate provisioning fails:**
- Verify domain DNS points to your load balancer
- Check HTTP-01 challenge endpoint is accessible: `curl http://yourdomain/.well-known/acme-challenge/test`
- Review Let's Encrypt rate limits (50 certs/week per domain)

**SSL handshake errors:**
- Check certificate matches domain
- Verify certificate not expired
- Ensure TLS 1.2+ supported

**Auto-renewal not working:**
- Check renewal worker is running
- Verify API credentials still valid
- Check Let's Encrypt account status

## API Reference

### Certificates

- `GET /api/certificates` - List all certificates
- `GET /api/certificates/:id` - Get certificate details
- `POST /api/certificates` - Provision new certificate
- `POST /api/certificates/:id/renew` - Manually renew certificate
- `DELETE /api/certificates/:id` - Delete certificate

### ACME

- `GET /.well-known/acme-challenge/:token` - HTTP-01 challenge endpoint

## Further Reading

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [ACME Protocol Specification](https://datatracker.ietf.org/doc/html/rfc8555)
- [Fly.io SSL Certificates](https://fly.io/docs/networking/custom-domain/)
- [SSL Labs Testing](https://www.ssllabs.com/ssltest/)
