# Mnesia with RocksDB Backend

Singularity Edge uses **Mnesia with RocksDB backend** for distributed, persistent storage.

## Why RocksDB Backend?

### Plain Mnesia Limitations

| Limitation | Impact | RocksDB Solution |
|------------|--------|------------------|
| **2GB table limit** | Can't store >2GB per table | ✅ **No limit** - handles 100s of GBs |
| **High RAM usage** | All data loaded in RAM | ✅ **Lower RAM** - efficient disk storage |
| **Write amplification** | Slower for heavy writes | ✅ **LSM-tree** - optimized for writes |

### RocksDB Benefits

1. **Unlimited storage** - No 2GB limit per table
2. **Lower RAM usage** - Data stays on disk, cached intelligently
3. **Better write performance** - LSM-tree architecture
4. **Same Mnesia API** - Drop-in replacement
5. **Production proven** - Used in Riak KV, CockroachDB
6. **Still distributed** - Works with Mnesia clustering

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Singularity Edge Application             │
├─────────────────────────────────────────────────┤
│                  Mnesia API                      │
│            (Standard Erlang/Elixir)              │
├─────────────────────────────────────────────────┤
│              RocksDB Storage Engine              │
│  • Certificates (unlimited SSL certs)            │
│  • Pools (unlimited backend pools)               │
│  • Backends (millions of backends supported)     │
│  • Health state (distributed across nodes)       │
└─────────────────────────────────────────────────┘
```

## Data Storage

### What's Stored in Mnesia/RocksDB

1. **SSL Certificates**
   - Domain certificates (Let's Encrypt)
   - Private keys (encrypted)
   - Certificate chains
   - Expiration tracking

2. **Backend Pools**
   - Pool configurations
   - Load balancing algorithms
   - SSL modes
   - Health check intervals

3. **Backends**
   - Backend server details
   - Health status
   - Connection counters
   - Request statistics

4. **Distributed State**
   - Automatically replicated across nodes
   - ACID transactions
   - Consistent reads

## Table Configuration

### Certificates Table

```elixir
:mnesia.create_table(:certificates, [
  {:type, :set},
  {:rocksdb_copies, [node()]},  # RocksDB backend
  {:attributes, [
    :id, :domain, :certificate, :private_key,
    :chain, :issuer, :expires_at, :auto_renew,
    :provider, :metadata, :inserted_at, :updated_at
  ]},
  {:index, [:domain, :expires_at]}
])
```

### Pools Table

```elixir
:mnesia.create_table(:pools, [
  {:type, :set},
  {:rocksdb_copies, [node()]},
  {:attributes, [
    :name, :algorithm, :ssl_mode, :ssl_domain,
    :ssl_cert_id, :validate_backend_cert,
    :health_check_interval, :metadata,
    :inserted_at, :updated_at
  ]},
  {:index, [:ssl_domain]}
])
```

### Backends Table

```elixir
:mnesia.create_table(:backends, [
  {:type, :set},
  {:rocksdb_copies, [node()]},
  {:attributes, [
    :id, :pool_name, :host, :port, :scheme,
    :weight, :healthy, :current_connections,
    :total_requests, :last_check, :ssl_verify,
    :metadata, :inserted_at, :updated_at
  ]},
  {:index, [:pool_name, :healthy]}
])
```

## Performance Characteristics

### Read Performance

- **In-memory cache**: Hot data cached in RAM
- **Block cache**: Frequently accessed blocks cached
- **Bloom filters**: Fast negative lookups

### Write Performance

- **LSM-tree**: Optimized for writes
- **Write batching**: Efficient bulk writes
- **Compaction**: Background cleanup

### Scalability

| Metric | Plain Mnesia | RocksDB Backend |
|--------|--------------|-----------------|
| **Max table size** | 2GB | Unlimited |
| **RAM usage** | High (all data) | Low (cached only) |
| **Write throughput** | Good | Excellent |
| **Read throughput** | Excellent | Excellent |
| **Concurrent writes** | Good | Excellent |

## Distributed Clustering

### Multi-Node Setup

```elixir
# Node 1 (US-East)
Node.connect(:"edge@us-west")
Node.connect(:"edge@europe")

SingularityEdge.Mnesia.add_node(:"edge@us-west")
SingularityEdge.Mnesia.add_node(:"edge@europe")
```

Tables are automatically replicated:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   US-East    │────▶│   US-West    │────▶│   Europe     │
│  (Primary)   │     │  (Replica)   │     │  (Replica)   │
│              │◀────│              │◀────│              │
│  RocksDB     │     │  RocksDB     │     │  RocksDB     │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Replication

- **Automatic**: New nodes sync automatically
- **ACID**: Transactions work across nodes
- **Eventual consistency**: Updates propagate quickly
- **Conflict resolution**: Last-write-wins

## Data Directory Structure

```
data/mnesia/
├── LATEST.LOG
├── schema.DAT
├── certificates/
│   ├── 000001.sst
│   ├── 000002.sst
│   ├── MANIFEST
│   └── CURRENT
├── pools/
│   ├── 000001.sst
│   └── MANIFEST
└── backends/
    ├── 000001.sst
    └── MANIFEST
```

## Backup & Recovery

### Backup

```elixir
# Backup all tables
:mnesia.backup("backup/singularity-edge-#{Date.utc_today()}.bak")

# Backup specific table
:mnesia.backup_checkpoint("certificates_checkpoint", "backup/certs.bak")
```

### Restore

```elixir
# Restore from backup
:mnesia.restore("backup/singularity-edge-2025-01-17.bak", [])
```

### RocksDB Snapshots

RocksDB also supports native snapshots:

```bash
# Copy RocksDB data directory
cp -r data/mnesia/certificates /backups/certs-snapshot-$(date +%Y%m%d)
```

## Monitoring

### Mnesia Info

```elixir
SingularityEdge.Mnesia.info()
# => %{
#      tables: [:schema, :certificates, :pools, :backends],
#      nodes: [:"edge@us-east", :"edge@us-west"],
#      node: :"edge@us-east",
#      directory: "data/mnesia/prod",
#      is_running: true
#    }
```

### Table Statistics

```elixir
:mnesia.table_info(:certificates, :size)
# => 1523 (number of certificates)

:mnesia.table_info(:backends, :memory)
# => 45678 (bytes in RAM cache)
```

### RocksDB Statistics

```elixir
# Get RocksDB stats per table
:mnesia_rocksdb.stats(:certificates)
```

## Deployment

### Docker (Fly.io)

RocksDB is included in the Docker image:

```dockerfile
# Build stage
RUN apk add --no-cache rocksdb rocksdb-dev

# Runtime stage
RUN apk add --no-cache rocksdb
```

### Nix Development

RocksDB is included in the dev shell:

```nix
buildInputs = [ pkgs.rocksdb ];
```

### First Deploy

```bash
# Deploy to Fly.io
flyctl deploy

# Mnesia schema is created automatically on first boot
# RocksDB tables are initialized
# No migrations needed!
```

### Add New Node

```bash
# Deploy to new region
flyctl regions add lhr

# Node joins automatically via libcluster
# Mnesia replicates tables automatically
```

## Advantages Over PostgreSQL

| Feature | PostgreSQL | Mnesia + RocksDB |
|---------|-----------|------------------|
| **External dependency** | ✅ Requires PostgreSQL | ❌ **Built-in** |
| **Setup complexity** | Medium | **Minimal** |
| **Distributed by default** | ❌ No (needs extensions) | ✅ **Yes** |
| **Replication** | Manual setup | **Automatic** |
| **Deployment** | 2 services | **1 service** |
| **Horizontal scaling** | Complex | **Simple** |
| **Data locality** | External | **Co-located** |
| **Failover** | Manual | **Automatic** |

## Troubleshooting

### Table Not Found

```elixir
# Recreate tables
SingularityEdge.Mnesia.create_tables()
```

### Node Not Replicating

```elixir
# Check node connectivity
Node.list()

# Manually add node
SingularityEdge.Mnesia.add_node(:"edge@other-region")
```

### RocksDB Corruption

```bash
# Stop application
flyctl app stop

# Remove corrupted RocksDB directory
rm -rf data/mnesia/prod/certificates

# Restart (will sync from other nodes)
flyctl app start
```

### High Disk Usage

RocksDB auto-compacts, but you can trigger manually:

```elixir
:mnesia_rocksdb.compact(:certificates)
```

## Best Practices

1. **Monitor disk usage**: RocksDB uses disk space
2. **Regular backups**: Use Mnesia backup or RocksDB snapshots
3. **Test restores**: Verify backups work
4. **Cluster size**: 3+ nodes for HA
5. **Compaction**: Let RocksDB auto-compact (don't disable)

## Further Reading

- [Mnesia User's Guide](https://www.erlang.org/doc/apps/mnesia/mnesia.html)
- [RocksDB Wiki](https://github.com/facebook/rocksdb/wiki)
- [mnesia_rocksdb on GitHub](https://github.com/aeternity/mnesia_rocksdb)
