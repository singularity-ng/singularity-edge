# Deployment Guide

Complete guide for deploying Singularity Edge to Fly.io with automatic GitHub deployments.

## Prerequisites

1. **Fly.io Account**: Sign up at https://fly.io
2. **GitHub Repository**: Push code to GitHub (e.g., `singularity-ng/singularity-edge`)
3. **Fly.io CLI**: Install via Nix shell (`nix develop`) or manually

## Automatic Deployments from GitHub

### One-Time Setup

#### 1. Create Fly.io App

```bash
# Authenticate with Fly.io
flyctl auth login

# Create a new app (choose your app name)
flyctl launch --no-deploy

# Follow the prompts:
# - Choose app name: singularity-edge (or your preferred name)
# - Choose region: iad (Washington DC) or closest to you
# - Don't deploy yet: N
```

This creates `fly.toml` with your app configuration.

#### 2. Get Fly.io API Token

```bash
# Generate a deploy token
flyctl tokens create deploy

# Copy the token output
```

#### 3. Add GitHub Secret

1. Go to your GitHub repository: `https://github.com/singularity-ng/singularity-edge`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `FLY_API_TOKEN`
5. Value: Paste the token from step 2
6. Click **Add secret**

#### 4. (Optional) Add Cachix for Faster CI

If you want faster CI builds:

```bash
# Create a Cachix account at https://app.cachix.org
# Create a cache (e.g., "singularity-edge")
# Get your auth token from Settings

# Add to GitHub Secrets:
# Name: CACHIX_AUTH_TOKEN
# Value: <your-cachix-token>
```

### How It Works

The GitHub Actions workflow (`.github/workflows/fly-deploy.yml`) automatically:

1. **Triggers on**:
   - Push to `main` branch
   - Push to `production` branch
   - Manual workflow dispatch

2. **Runs checks** (optional):
   - Code formatting verification
   - Test suite
   - Can be extended with more quality gates

3. **Deploys to Fly.io**:
   - Uses `flyctl deploy --remote-only`
   - Builds Docker image on Fly.io's builders
   - Performs rolling deployment (zero-downtime)
   - Auto-rollback on health check failures

### First Deployment

```bash
# Push your code to GitHub
git add .
git commit -m "feat: initial deployment setup"
git push origin main

# GitHub Actions will automatically deploy!
# Watch the deployment: https://github.com/singularity-ng/singularity-edge/actions
```

### Monitoring Deployments

```bash
# View deployment status
flyctl status

# View logs
flyctl logs

# Open the app
flyctl open

# View dashboard
flyctl dashboard
```

## Manual Deployment

If you prefer manual deployments:

```bash
# Deploy from local machine
flyctl deploy

# Or deploy specific Dockerfile
flyctl deploy --dockerfile Dockerfile

# Deploy to specific region
flyctl deploy --region lhr
```

## Environment Variables

Set secrets and environment variables:

```bash
# Set secret (encrypted)
flyctl secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)"

# Set environment variable
flyctl config set PHX_HOST="your-custom-domain.com"

# List all secrets
flyctl secrets list

# List all config
flyctl config show
```

## Multi-Region Deployment

Deploy globally for low latency:

```bash
# View available regions
flyctl platform regions

# Add regions (creates replicas)
flyctl scale count 3 --region iad,lhr,nrt

# Deploy to all regions
flyctl deploy
```

### Recommended Global Setup

```bash
# North America + Europe + Asia
flyctl scale count 6 --region iad,lax,lhr,fra,nrt,syd

# Global coverage (9 regions)
flyctl scale count 9 --region iad,lax,lhr,fra,ams,nrt,syd,sin,gru
```

## Mnesia Clustering

Singularity Edge uses Mnesia with RocksDB for distributed storage. When you deploy to multiple regions, nodes automatically cluster via libcluster.

### Clustering Setup

1. **Deploy to first region**:
   ```bash
   flyctl deploy --region iad
   ```

2. **Scale to additional regions**:
   ```bash
   flyctl scale count 3 --region iad,lhr,nrt
   ```

3. **Nodes automatically discover each other** via Fly.io's 6PN network

4. **Mnesia replicates data** across all nodes automatically

### Verify Clustering

```bash
# SSH into a running machine
flyctl ssh console

# Check connected nodes
bin/singularity_edge remote

# In the Elixir shell:
Node.list()  # Should show other region nodes
SingularityEdge.Mnesia.info()  # Shows replication status
```

## Scaling

### Vertical Scaling (Larger Machines)

```bash
# Upgrade to 1GB RAM, 2 CPUs
flyctl scale vm shared-cpu-2x --memory 1024

# Upgrade to 2GB RAM, 4 CPUs
flyctl scale vm shared-cpu-4x --memory 2048

# Performance tier (dedicated CPU)
flyctl scale vm performance-2x --memory 4096
```

### Horizontal Scaling (More Machines)

```bash
# Scale to 3 machines in current region
flyctl scale count 3

# Scale specific region
flyctl scale count 5 --region iad

# Auto-scaling (coming soon in fly.toml)
```

## Health Checks

Health checks are configured in `fly.toml`:

```toml
[[http_service.checks]]
  interval = "10s"
  timeout = "2s"
  grace_period = "30s"
  path = "/api/health"
```

If health checks fail, Fly.io automatically rolls back the deployment.

## Persistent Storage (Mnesia Data)

Mnesia data is stored in `/app/data/mnesia`. For persistence across deployments:

```bash
# Create a volume (persistent disk)
flyctl volumes create mnesia_data --size 10 --region iad

# Update fly.toml to mount the volume
# (Already configured in fly.toml)
```

## Custom Domains

```bash
# Add custom domain
flyctl certs add your-domain.com

# Add wildcard certificate
flyctl certs add *.your-domain.com

# View certificate status
flyctl certs list

# Fly.io will automatically provision Let's Encrypt certificates
```

## Rollback

```bash
# List recent releases
flyctl releases

# Rollback to specific version
flyctl releases rollback <version>
```

## Troubleshooting

### Deployment Fails

```bash
# View build logs
flyctl logs --app singularity-edge

# SSH into machine
flyctl ssh console

# Restart app
flyctl apps restart
```

### Health Checks Failing

```bash
# Check health endpoint locally
curl https://your-app.fly.dev/api/health

# View detailed logs
flyctl logs --app singularity-edge

# Increase grace period in fly.toml
grace_period = "60s"
```

### Mnesia Issues

```bash
# SSH into machine
flyctl ssh console

# Check Mnesia status
bin/singularity_edge remote

# In Elixir shell:
SingularityEdge.Mnesia.info()
:mnesia.system_info(:running_db_nodes)
```

## Cost Optimization

### Free Tier

Fly.io free tier includes:
- Up to 3 shared-cpu-1x machines (256MB RAM)
- 3GB persistent storage
- 160GB outbound data transfer

Perfect for development and small deployments.

### Production Recommendations

**Small** (< 1000 req/s):
- 3 machines (iad, lhr, nrt)
- shared-cpu-1x, 512MB RAM
- ~$15-20/month

**Medium** (1000-10000 req/s):
- 6 machines (global coverage)
- shared-cpu-2x, 1GB RAM
- ~$50-70/month

**Large** (> 10000 req/s):
- 9+ machines (full global)
- performance-2x, 2GB RAM
- ~$150-200/month

## Monitoring

### Fly.io Dashboard

```bash
# Open web dashboard
flyctl dashboard
```

### Phoenix LiveDashboard

Visit: `https://your-app.fly.dev/admin/dashboard`

Shows:
- Request metrics
- Node connectivity
- Backend pool health
- System resources

### Metrics API

```bash
# Get app metrics
flyctl metrics

# View specific machine metrics
flyctl machine list
flyctl machine status <machine-id>
```

## CI/CD Best Practices

### Branch Strategy

```yaml
# .github/workflows/fly-deploy.yml
on:
  push:
    branches:
      - main        # Auto-deploy to staging
      - production  # Auto-deploy to production
```

### Multiple Environments

Create separate apps for staging and production:

```bash
# Staging
flyctl launch --name singularity-edge-staging --region iad

# Production
flyctl launch --name singularity-edge-prod --region iad
```

Update GitHub Actions to deploy to different apps based on branch.

### Pre-Deployment Checks

Add quality gates in `.github/workflows/fly-deploy.yml`:

```yaml
- name: Run tests
  run: nix develop --command just test

- name: Security audit
  run: nix develop --command mix deps.audit
```

## Further Reading

- [Fly.io Documentation](https://fly.io/docs/)
- [Fly.io Phoenix Deployment](https://fly.io/docs/elixir/getting-started/)
- [Fly.io Multi-Region](https://fly.io/docs/reference/regions/)
- [libcluster on Fly.io](https://fly.io/docs/elixir/the-basics/clustering/)
