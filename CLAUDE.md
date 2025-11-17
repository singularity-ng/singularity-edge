# Claude Code Development Guide

## Development Environment

This project uses **Nix** for reproducible development environments. The entire toolchain—Elixir, Erlang, Rust, and all quality tools—are defined in `flake.nix` and managed via `direnv`.

### Quick Start with Claude Code

1. **Automatic Environment Loading**:
   - The `.envrc` file automatically loads the Nix development shell when you enter the directory
   - Allow direnv: `direnv allow`
   - Verify the environment: `elixir --version` should show Elixir 1.19.2+

2. **Manual Environment Entry** (if needed):
   ```bash
   nix develop
   ```

3. **PostgreSQL Auto-Starts**:
   ```bash
   # PostgreSQL starts automatically when needed (via 'just dev')
   # Or start manually: devenv up -d
   ```

### Available Commands

Once in the Nix environment, you have access to:

**Quick Start**:
- `just` - Interactive command picker (explore all commands)
- `just init` - Initialize workspace (deps, database, assets)
- `just dev` - Start development server (Phoenix on localhost:4000)
- `just test` - Run all tests

**Fast Feedback Loop**:
- `just fmt` - Format all code (Elixir + Rust)
- `just check` - Quick pre-commit checks (~30s: format, compile, credo)
- `just ci` - Full CI pipeline simulation

**Database Management**:
- `just db-migrate` - Run pending migrations
- `just db-rollback` - Rollback last migration
- `just db-reset` - Drop, create, migrate, seed databases
- `just db-new-migration NAME` - Create a new migration

**Quality Checks**:
- `just quality` - Run all quality checks
- `just quality-format` - Check code formatting
- `just quality-lint` - Run linters (Credo)

**Development Tools**:
- `just clean` - Clean build artifacts
- `just update` - Update all dependencies
- `just stats` - Show code statistics

### Project Structure

- `lib/singularity_edge/` - Domain logic
  - `balancer/` - Load balancing algorithms and backend pools
  - `proxy/` - HTTP proxy handler
  - `admin/` - Admin LiveView interfaces
- `lib/singularity_edge_web/` - Web layer
  - `controllers/` - API controllers (health, pools, proxy)
  - `live/` - LiveView dashboards
  - `router.ex` - Route definitions
- `config/` - Application configuration
- `priv/repo/` - Database migrations and seeds
- `test/` - Test suite
- `assets/` - Frontend assets (Tailwind + esbuild)
- `nix/` - Nix configuration modules

### Code Quality Standards

This project enforces strict quality gates:

**Elixir**:
- `mix format` (auto-format)
- `credo --strict` (linting)
- Dialyzer (type checking - coming soon)

**Rust** (for CLI tool):
- `cargo fmt` (auto-format)
- `cargo clippy` (linting)

Run `just quality` to check everything at once.

### Coding Conventions

**Elixir**:
- `CamelCase` for modules (matching file paths)
- `snake_case` for functions and variables
- Environment variables in `SCREAMING_SNAKE_CASE`
- Add `@spec` annotations for public functions
- Include docstrings with examples

**Nix**:
- Use `nixpkgs-fmt` for formatting (`just fmt`)
- Follow the Inputs Design Pattern (Nix Pills #12)

### Testing

- Tests live in `test/` (mirroring `lib/` structure)
- Run individual test files: `mix test test/path/to/test.exs`
- Use `test/support/data_case.ex` for shared test utilities

### Deployment

Deploy to Fly.io for global edge deployment:

```bash
# First time setup
flyctl launch

# Deploy to production
flyctl deploy

# Scale globally (example: 3 regions)
flyctl scale count 3 --region iad,lhr,nrt

# View dashboard
flyctl dashboard
```

Available regions: IAD (US-East), ORD (US-Central), LAX (US-West), LHR (London), FRA (Frankfurt), NRT (Tokyo), SYD (Sydney), and more.

### Git & Commits

Follow Conventional Commits:
```
type: short description

Optional body explaining motivation and changes.
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`

Example:
```
feat: add weighted round-robin algorithm

Implements weighted distribution for backends with different capacities.
Closes #42
```

### Common Issues

**"Elixir version mismatch"**:
- Ensure direnv is loaded: `direnv allow`
- Or manually: `nix develop`

**"Database connection refused"**:
- Database starts automatically with `just dev`
- Check config: `config/dev.exs`

**Phoenix LiveDashboard not loading**:
- Visit: `http://localhost:4000/admin/dashboard`
- Ensure Phoenix server is running: `just dev`

### Architecture Overview

**Load Balancing**:
- Backend pools managed by GenServers
- Algorithms: round-robin, least-connections, weighted, random
- Automatic health checking every 10 seconds
- Connection tracking per backend

**HTTP Proxy**:
- Uses hackney for efficient HTTP forwarding
- Preserves headers (except hop-by-hop)
- Automatic backend selection via pool

**Distributed Edge Nodes**:
- libcluster for automatic node discovery
- Can cluster across regions via Fly.io private network
- Share backend health state across nodes

### Further Reading

- Phoenix: https://www.phoenixframework.org/
- Elixir: https://elixir-lang.org/
- Fly.io: https://fly.io/docs/
- Nix Pills: https://nixos.org/guides/nix-pills/
