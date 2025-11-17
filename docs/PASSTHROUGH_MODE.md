# SSL Passthrough Mode

**SSL Passthrough** forwards encrypted TLS traffic directly to backends **without decryption** at the edge. This provides true end-to-end encryption.

## When to Use Passthrough Mode

### ✅ Use Passthrough When:

1. **Compliance Requirements**
   - HIPAA, PCI-DSS, or other regulations require end-to-end encryption
   - No intermediate decryption allowed
   - Backend must control SSL certificates

2. **Maximum Security**
   - Zero-trust architecture
   - Prevent any edge inspection
   - Sensitive data (payments, health records, financial)

3. **Backend Owns SSL**
   - Backends already handle SSL well
   - Custom SSL configurations needed
   - Certificate pinning required

4. **Simple Forwarding**
   - No need for HTTP routing/inspection
   - Just need TCP load balancing
   - Backends are homogeneous

### ❌ Avoid Passthrough When:

1. **Need Smart Routing**
   - Route based on HTTP headers, paths, cookies
   - Content-based routing
   - A/B testing or canary deployments

2. **Want Request Inspection**
   - Logging HTTP requests
   - Adding custom headers
   - Request/response metrics

3. **Need Caching**
   - CDN-like caching
   - Response compression
   - Content optimization

4. **Web Application Firewall (WAF)**
   - Block malicious requests
   - Rate limiting at HTTP level
   - SQL injection/XSS protection

## How Passthrough Works

### Architecture

```
Client (HTTPS)
    ↓ (encrypted TLS handshake)
Singularity Edge (TCP proxy only)
    ↓ (forwarded encrypted bytes)
Backend Server (decrypts and handles)
```

**Edge sees**: Raw encrypted bytes
**Edge cannot**: Inspect HTTP, route by path/header, cache, add headers
**Backend must**: Handle SSL, have valid certificate

### vs. Termination Modes

| Feature | Passthrough | Termination (Full Strict) |
|---------|-------------|---------------------------|
| **End-to-end encryption** | ✅ Yes | ⚠️ Re-encrypted |
| **Edge decrypts** | ❌ No | ✅ Yes |
| **HTTP inspection** | ❌ No | ✅ Yes |
| **Smart routing** | ❌ No | ✅ Yes |
| **Request logging** | ❌ No | ✅ Yes |
| **Add headers** | ❌ No | ✅ Yes |
| **WAF/Rate limiting** | ❌ No | ✅ Yes |
| **Compliance** | ✅ Strictest | ✅ Most cases |
| **Performance** | ✅ Faster (no decrypt) | ⚠️ Slight overhead |

## Configuration

### Create Passthrough Pool

```bash
curl -X POST http://localhost:4000/api/pools \
  -H "Content-Type: application/json" \
  -d '{
    "name": "secure-app",
    "algorithm": "least_connections",
    "ssl_mode": "passthrough"
  }'
```

### Add HTTPS Backends

Backends **must** use HTTPS and handle SSL:

```bash
curl -X POST http://localhost:4000/api/pools/secure-app/backends \
  -H "Content-Type: application/json" \
  -d '{"url": "https://backend1.internal:8443"}'

curl -X POST http://localhost:4000/api/pools/secure-app/backends \
  -H "Content-Type: application/json" \
  -d '{"url": "https://backend2.internal:8443"}'
```

### Pool Configuration

```elixir
%{
  name: "payments",
  algorithm: :least_connections,
  ssl_mode: :passthrough,          # Enable passthrough
  health_check_interval: 10_000,
  backends: [
    %{url: "https://payment-1.internal:8443"},
    %{url: "https://payment-2.internal:8443"}
  ]
}
```

## How It's Implemented

### TCP-Level Proxy

Passthrough uses **TCP proxy** instead of HTTP proxy:

1. **Accept TCP connection** from client
2. **Select backend** using load balancing algorithm
3. **Open TCP connection** to backend
4. **Bidirectional forwarding**:
   - Client → Edge → Backend (encrypted)
   - Backend → Edge → Client (encrypted)
5. **No decryption** at any point

### Code Flow

```elixir
# Client connects
Client → Singularity Edge (TCP socket)

# Select backend
{:ok, backend} = Pool.select_backend("payments")

# Connect to backend
{:ok, backend_socket} = :gen_tcp.connect(backend.host, backend.port)

# Forward in both directions
spawn(fn -> forward(client_socket, backend_socket) end)
spawn(fn -> forward(backend_socket, client_socket) end)

# Just copy bytes - no inspection
```

## Performance Characteristics

### Passthrough Benefits

1. **Lower Latency**: No SSL decryption/re-encryption overhead
2. **Higher Throughput**: Raw TCP forwarding is very fast
3. **Less CPU**: No crypto operations at edge
4. **Simple Code Path**: Just copy bytes

### Passthrough Limitations

1. **No Caching**: Can't cache without seeing content
2. **No Compression**: Can't optimize responses
3. **Basic Load Balancing**: Round-robin, least-conn only (no path-based)
4. **Limited Metrics**: Can only count bytes, not requests

## Security Considerations

### Advantages

- ✅ **True E2E encryption**: Edge cannot decrypt
- ✅ **Zero knowledge**: Edge never sees plaintext
- ✅ **Backend control**: Backend manages certs
- ✅ **Compliance**: Meets strictest requirements

### Disadvantages

- ❌ **No WAF**: Can't block malicious HTTP
- ❌ **No DDoS protection**: Can't inspect/rate-limit requests
- ❌ **No visibility**: Can't log requests for debugging
- ❌ **Trust backends**: Must trust backends to handle SSL correctly

## Example Use Cases

### 1. Payment Processing (PCI-DSS)

```bash
# Create passthrough pool for payment API
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "payments",
    "ssl_mode": "passthrough",
    "algorithm": "least_connections"
  }'

# Add PCI-compliant payment backends
curl -X POST http://localhost:4000/api/pools/payments/backends \
  -d '{"url": "https://payment-gateway-1.internal:8443"}'
```

**Why**: PCI-DSS may require end-to-end encryption without intermediate decryption.

### 2. Healthcare API (HIPAA)

```bash
# Create passthrough pool for health records
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "ehr",
    "ssl_mode": "passthrough",
    "algorithm": "round_robin"
  }'

# Add HIPAA-compliant backends
curl -X POST http://localhost:4000/api/pools/ehr/backends \
  -d '{"url": "https://ehr-api-1.internal:8443"}'
```

**Why**: HIPAA requires strict patient data protection; passthrough ensures no edge inspection.

### 3. Internal Microservices (Zero Trust)

```bash
# Internal service-to-service communication
curl -X POST http://localhost:4000/api/pools \
  -d '{
    "name": "internal-auth",
    "ssl_mode": "passthrough",
    "algorithm": "random"
  }'

curl -X POST http://localhost:4000/api/pools/internal-auth/backends \
  -d '{"url": "https://auth-service-1.internal:8443"}'
```

**Why**: Zero-trust architecture requires mTLS; passthrough preserves client certificates.

## Comparison with Cloudflare

| Feature | Cloudflare | Singularity Edge |
|---------|-----------|------------------|
| **Passthrough Mode** | ❌ Not supported | ✅ Supported |
| **Reason** | Always needs to decrypt for WAF/caching | Flexible per-pool configuration |
| **Use Case** | Public web apps | Private APIs, compliance, microservices |

**Cloudflare always terminates SSL** - they can't do passthrough because their entire value (WAF, caching, optimization) requires seeing HTTP.

**Singularity Edge is flexible** - choose termination for smart routing, or passthrough for maximum security.

## Monitoring Passthrough Connections

### Available Metrics

With passthrough mode, you can still monitor:

- ✅ **Connection count**: Active connections per backend
- ✅ **Bytes transferred**: Volume of data
- ✅ **Backend health**: TCP health checks
- ✅ **Connection errors**: Failed backend connections
- ✅ **Load balancing**: Distribution across backends

### Unavailable Metrics

Cannot monitor (requires HTTP inspection):

- ❌ HTTP status codes
- ❌ Request/response sizes
- ❌ Request paths/methods
- ❌ Request headers
- ❌ Response times (application-level)

### Example Metrics

```bash
# Get pool stats (works for passthrough)
curl http://localhost:4000/api/pools/payments

{
  "stats": {
    "total_backends": 3,
    "healthy_backends": 3,
    "current_connections": 42,
    "total_bytes_transferred": 1048576000
  }
}
```

## Best Practices

1. **Use for sensitive data**: Payments, health, auth
2. **Ensure backend SSL**: Backends must have valid certs
3. **Health checks**: Use TCP health checks (port open/closed)
4. **Load balancing**: Use least_connections for fair distribution
5. **Monitor backends**: Backend-side logging for request inspection
6. **Firewall backends**: Only allow edge nodes to connect

## Troubleshooting

### Issue: Connection refused to backend

**Cause**: Backend not listening on HTTPS port

**Fix**: Ensure backend SSL is configured:
```bash
# Test backend directly
curl -v https://backend1.internal:8443
```

### Issue: SSL handshake failures

**Cause**: Client/backend SSL incompatibility

**Fix**: Check TLS versions and ciphers match:
```bash
# Check backend SSL config
openssl s_client -connect backend1.internal:8443
```

### Issue: Slow performance

**Cause**: Not actually a passthrough issue - check backend

**Fix**: Profile backend SSL performance:
```bash
# Benchmark backend
ab -n 1000 -c 10 https://backend1.internal:8443/
```

## See Also

- [SSL Configuration Guide](SSL_CONFIGURATION.md)
- [Cloudflare Comparison](CLOUDFLARE_COMPARISON.md)
- [Load Balancing Algorithms](../README.md#load-balancing-algorithms)
