# Claude Code Development Guide

## Development Environment

This project uses **Nix** for reproducible development environments. The entire toolchain is defined in `flake.nix` and managed via `direnv`.

### Quick Start with Claude Code

1. **Automatic Environment Loading**:
   - The `.envrc` file automatically loads the Nix development shell when you enter the directory
   - Allow direnv: `direnv allow`
   - Verify the environment: `nix --version`

2. **Manual Environment Entry** (if needed):
   ```bash
   nix develop
   ```

### Available Commands

Once in the Nix environment, you have access to:

**Quick Start**:
- `just` - Interactive command picker (explore all commands)
- `just list` - List all available commands
- `just fmt` - Format all code (Nix)
- `just check` - Check Nix flake
- `just update` - Update flake inputs
- `just stats` - Show code statistics
- `just clean` - Clean build artifacts

### Project Structure

- `nix/` - Nix configuration modules
  - `devShells/` - Development shell configurations
  - `lib.nix` - Shared utility functions
- `README.md` - Project overview
- `flake.nix` - Main Nix flake configuration
- `.envrc` - Direnv configuration

### Coding Conventions

**Nix**:
- Use `nixpkgs-fmt` for formatting (`just fmt`)
- Follow the Inputs Design Pattern (Nix Pills #12)
- Keep flake structure modular (separate devShells, packages, checks)

### Git & Commits

Follow Conventional Commits:
```
type: short description

Optional body explaining motivation and changes.
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`

Example:
```
feat: add load balancing algorithm

Implements consistent hashing for edge routing.
Closes #42
```

### Common Issues

**"direnv: error .envrc is blocked"**:
- Run: `direnv allow`

**Nix flake check failures**:
- Ensure all files are formatted: `just fmt`
- Update inputs if needed: `just update`

### Further Reading

- Nix Pills: https://nixos.org/guides/nix-pills/
- direnv documentation: https://direnv.net/
- Flake reference: https://nixos.wiki/wiki/Flakes
