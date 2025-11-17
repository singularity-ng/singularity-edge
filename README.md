# Singularity Edge

Global load balancer and edge routing service built with Elixir and Rust.

## Overview

Singularity Edge is a distributed, fault-tolerant load balancing solution designed for global deployments. It provides:

- **Intelligent Traffic Routing**: Multiple load balancing algorithms (round-robin, least-connections, weighted, random)
- **Health Checking**: Automatic backend health monitoring with configurable intervals
- **High Availability**: Distributed Elixir nodes with automatic clustering
- **Real-time Monitoring**: Phoenix LiveDashboard for observability
- **REST API**: Full API for programmatic management
- **CLI Tool**: Rust-based CLI for automation (coming soon)

## Architecture

### Components

1. **Edge Nodes** (Elixir/Phoenix)
   - HTTP/HTTPS proxy with multiple routing algorithms
   - Backend health checking and failover
   - Clustered for high availability

2. **Admin Dashboard** (Phoenix LiveView)
   - Real-time pool and backend monitoring
   - Performance metrics and health status
   - Located at `/admin/dashboard`

3. **REST API**
   - Pool management: `POST /api/pools`, `GET /api/pools/:id`
   - Backend management: `POST /api/pools/:id/backends`
   - Health checks: `GET /api/health`

4. **CLI Tool** (Rust - coming soon)
   - Pool and backend management from command line
   - Automation and CI/CD integration

### Load Balancing Algorithms

- **Round Robin**: Distributes requests evenly across backends
- **Least Connections**: Routes to backend with fewest active connections
- **Weighted Round Robin**: Weighted distribution based on backend capacity
- **Random**: Random selection from healthy backends

## Getting Started

### Prerequisites

- Nix with flakes enabled
- direnv (optional but recommended)

### Setup

```bash
# Clone the repository
cd singularity-edge

# Allow direnv (automatic environment setup)
direnv allow

# Or manually enter Nix shell
nix develop

# Install dependencies
just init

# Start development server
just dev
```

Visit `http://localhost:4000/admin/dashboard` for the monitoring dashboard.

### Creating a Pool

```bash
# Create a new pool via API
curl -X POST http://localhost:4000/api/pools \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "algorithm": "least_connections"
  }'

# Add backends
curl -X POST http://localhost:4000/api/pools/my-app/backends \
  -H "Content-Type: application/json" \
  -d '{"url": "http://192.168.1.10:8080"}'

curl -X POST http://localhost:4000/api/pools/my-app/backends \
  -H "Content-Type: application/json" \
  -d '{"url": "http://192.168.1.11:8080"}'
```

### Deployment

Deploy to Fly.io (multiple regions for global coverage):

```bash
# Coming soon
just deploy
```

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development instructions.

```bash
just               # Interactive command picker
just dev           # Start development server
just test          # Run tests
just check         # Quick pre-commit checks
just ci            # Full CI pipeline
```

## License

Apache 2.0
