# Cloudflare SSL Mode Comparison

This document compares Singularity Edge's SSL modes with Cloudflare's approach.

## Cloudflare's SSL Strategy

Cloudflare **always terminates SSL** at their edge network. This gives them control for:
- DDoS protection
- Web Application Firewall (WAF)
- Caching and optimization
- Analytics and bot management
- Smart routing

They never do "passthrough" mode - SSL is always decrypted at the edge.

## SSL Mode Comparison

| Mode | Cloudflare | Singularity Edge | Use Case |
|------|-----------|------------------|----------|
| **Off** | ❌ No SSL | `:off` | Development only |
| **Flexible** | Client→CF: HTTPS<br>CF→Origin: HTTP | `:flexible` | Quick setup, trusted network |
| **Full** | Client→CF: HTTPS<br>CF→Origin: HTTPS (self-signed OK) | `:full` | Self-signed origin certs |
| **Full (Strict)** ⭐ | Client→CF: HTTPS<br>CF→Origin: HTTPS (validated) | `:full_strict` | **Production (recommended)** |
| **Passthrough** | ❌ Not supported | `:passthrough` | End-to-end encryption needs |

## Feature Comparison

### Certificate Provisioning

| Feature | Cloudflare | Singularity Edge |
|---------|-----------|------------------|
| **Universal SSL** | ✅ Free Let's Encrypt for all domains | ✅ Free Let's Encrypt via ACME |
| **Auto-renewal** | ✅ Automatic | ✅ Automatic (30 days before expiry) |
| **Wildcard certs** | ✅ `*.example.com` included | ✅ Supported |
| **Custom certs** | ✅ $10/month (Advanced CM) | ✅ Free upload |
| **Multi-domain (SAN)** | ✅ Advanced Certificate Manager | 🔄 Coming soon |
| **Origin CA** | ✅ Free 15-year certs for origins | 🔄 Coming soon |

### SSL/TLS Features

| Feature | Cloudflare | Singularity Edge |
|---------|-----------|------------------|
| **TLS 1.3** | ✅ | ✅ (via Bandit/Erlang) |
| **Custom cipher suites** | ✅ | 🔄 Coming soon |
| **HSTS** | ✅ | 🔄 Coming soon |
| **Min TLS version** | ✅ Configurable | 🔄 Coming soon |
| **Opportunistic Encryption** | ✅ | ❌ Not needed |
| **Authenticated Origin Pull** | ✅ mTLS to origin | 🔄 Coming soon |

## Configuration Examples

### Cloudflare "Full (Strict)" → Singularity Edge

**Cloudflare Setup:**
1. SSL/TLS → Overview → Full (Strict)
2. Edge Certificates → Universal SSL (automatic)
3. Origin Server → Install valid certificate

**Singularity Edge Equivalent:**

```bash
# 1. Create pool with Full (Strict) mode
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "production",
    "algorithm": "least_connections",
    "ssl_mode": "full_strict",
    "ssl_domain": "api.example.com"
  }'

# 2. Provision Let's Encrypt certificate (automatic like Cloudflare)
curl -X POST http://localhost:4000/api/certificates \
  -d '{"domain": "api.example.com"}'

# 3. Add backends with valid HTTPS
curl -X POST http://localhost:4000/api/pools/production/backends \
  -d '{"url": "https://backend1.example.com:443"}'
```

### Cloudflare "Flexible" → Singularity Edge

**Cloudflare Setup:**
1. SSL/TLS → Overview → Flexible
2. Origin uses plain HTTP

**Singularity Edge Equivalent:**

```bash
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "internal",
    "ssl_mode": "flexible",
    "ssl_domain": "api.example.com"
  }'

# Backends use HTTP (no SSL)
curl -X POST http://localhost:4000/api/pools/internal/backends \
  -d '{"url": "http://backend1:8080"}'
```

## What Cloudflare Does That We Should Add

### 1. Origin CA Certificates (Priority: High)
Free long-lived certificates for origin servers:
- Issued by Singularity Edge CA (self-signed)
- Only trusted by Singularity Edge
- Perfect for Full (Strict) mode
- 15-year validity

```bash
# Generate origin certificate (coming soon)
curl -X POST http://localhost:4000/api/origin-ca/certificates \
  -d '{
    "hostname": "backend1.internal",
    "validity_days": 5475
  }'
```

### 2. Authenticated Origin Pull (Priority: Medium)
Mutual TLS - origins validate edge nodes:
- Edge presents client certificate to origin
- Origin only accepts traffic from edge
- Prevents direct origin access

```bash
# Enable mTLS to origin (coming soon)
curl -X PATCH http://localhost:4000/api/pools/production \
  -d '{"origin_pull_auth": true}'
```

### 3. Custom Cipher Suites (Priority: Low)
Fine-grained TLS configuration:
- Choose specific cipher suites
- Disable weak ciphers
- Compliance requirements

```bash
# Configure ciphers (coming soon)
curl -X PATCH http://localhost:4000/api/pools/production \
  -d '{
    "ssl_ciphers": [
      "TLS_AES_128_GCM_SHA256",
      "TLS_AES_256_GCM_SHA384"
    ]
  }'
```

## Architecture Differences

### Cloudflare
```
Client → [Cloudflare Edge (200+ cities)]
           ↓ (Anycast routing)
         [Origin Server]
```
- Global Anycast network
- Nearest edge serves request
- Caches aggressively
- Always terminates SSL

### Singularity Edge
```
Client → [Fly.io Edge (30+ regions)]
           ↓ (Fly private network)
         [Singularity Edge Nodes]
           ↓ (Load balancing)
         [Backend Servers]
```
- Multi-region deployment
- Flexible SSL modes (including passthrough)
- Clustered for HA
- Smart HTTP routing

## Recommendations

For most users, match Cloudflare's **Full (Strict)** mode:

1. **Edge**: Let's Encrypt certificates (automatic)
2. **Origin**: Valid SSL certificates (Let's Encrypt or commercial)
3. **Validate**: Always verify origin certificates
4. **Auto-renew**: Both edge and origin certs

This provides:
- ✅ End-to-end encryption
- ✅ Certificate validation
- ✅ Smart HTTP routing
- ✅ Request inspection
- ✅ Zero-trust security

## Migration from Cloudflare

Switching from Cloudflare to Singularity Edge:

1. **DNS**: Update A/AAAA records to point to Singularity Edge
2. **SSL Mode**: Map Cloudflare mode to equivalent
3. **Certificates**: Provision Let's Encrypt certs
4. **Origin**: Keep existing origin SSL setup
5. **Test**: Verify SSL handshake and routing

**No downtime migration:**
1. Deploy Singularity Edge in parallel
2. Test with `/etc/hosts` override
3. Switch DNS with low TTL
4. Monitor and rollback if needed

## See Also

- [SSL Configuration Guide](SSL_CONFIGURATION.md)
- [Cloudflare SSL Documentation](https://developers.cloudflare.com/ssl/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
