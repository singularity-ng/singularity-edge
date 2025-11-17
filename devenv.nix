{ pkgs, lib, config, ... }:

{
  # Disable automatic cachix management (handled by nix.conf instead)
  cachix.enable = false;
  cachix.push = "mikkihugo";

  # PostgreSQL service for development
  services.postgres = {
    enable = true;
    package = pkgs.postgresql_17;

    # Listen on localhost only (security)
    listen_addresses = "127.0.0.1";

    # Use port 5433 to match existing docker-compose setup
    # This avoids conflicts with system PostgreSQL on default port 5432
    port = 5433;

    # Additional PostgreSQL settings to ensure TCP listening
    settings = {
      listen_addresses = lib.mkForce "127.0.0.1";
    };

    # Auto-create databases on first start
    initialDatabases = [
      { name = "singularity_edge_dev"; }
      { name = "singularity_edge_test"; }
    ];

    # Data directory (will be created in .devenv/state/postgres)
    # This is managed by devenv and gitignored
    initialScript = ''
      CREATE ROLE postgres SUPERUSER LOGIN;
    '';
  };

  # Process management (auto-start services)
  # PostgreSQL service is managed by devenv automatically
  # It will auto-start when you enter the development shell
  # For auto-stop after idle time, see the convenience scripts below

  # Environment variables for the development shell
  env = {
    # Ensure Elixir/Mix knows where to find PostgreSQL
    # These match the existing config/dev.exs configuration
    PGHOST = "localhost";
    # PGPORT is automatically set by devenv from services.postgres.port
    PGUSER = "postgres";
    PGDATABASE = "singularity_edge_dev";
  };

  # Scripts available in the shell
  scripts = {
    # Convenience script to check PostgreSQL status
    db-status.exec = ''
      if ${pkgs.postgresql_17}/bin/pg_isready -h localhost -p 5433 > /dev/null 2>&1; then
        echo "✅ PostgreSQL is running on port 5433"
      else
        echo "❌ PostgreSQL is not running"
        echo "Run: devenv up -d"
      fi
    '';

    # Stop PostgreSQL gracefully
    db-stop.exec = ''
      if ${pkgs.postgresql_17}/bin/pg_isready -h localhost -p 5433 > /dev/null 2>&1; then
        echo "🛑 Stopping PostgreSQL..."
        ${pkgs.postgresql_17}/bin/pg_ctl -D .devenv/state/postgres stop
        echo "✅ PostgreSQL stopped"
      else
        echo "PostgreSQL is not running"
      fi
    '';

    # Monitor and stop PostgreSQL after 15 minutes of inactivity
    db-monitor.exec = ''
      IDLE_TIMEOUT=900  # 15 minutes in seconds
      CHECK_INTERVAL=30  # Check every 30 seconds
      LAST_ACTIVITY=$(date +%s)

      echo "🔍 Starting PostgreSQL idle monitor (15 minute timeout)..."
      echo "   PostgreSQL will auto-stop if no activity is detected"
      echo "   Press Ctrl+C to stop monitoring"

      trap "echo 'Monitor stopped'; exit 0" INT TERM

      while true; do
        NOW=$(date +%s)
        IDLE_TIME=$((NOW - LAST_ACTIVITY))
        IDLE_MINUTES=$((IDLE_TIME / 60))

        # If idle for 15 minutes, stop PostgreSQL
        if [ $IDLE_TIME -gt $IDLE_TIMEOUT ]; then
          if ${pkgs.postgresql_17}/bin/pg_isready -h localhost -p 5433 > /dev/null 2>&1; then
            echo "⏱️  PostgreSQL idle for 15+ minutes, stopping..."
            ${pkgs.postgresql_17}/bin/pg_ctl -D .devenv/state/postgres stop 2>/dev/null || true
          fi
        fi

        # Check if there's any database activity (connections)
        CONN_COUNT=$(${pkgs.postgresql_17}/bin/psql -h localhost -p 5433 -U postgres -d postgres -tc "SELECT count(*) FROM pg_stat_activity WHERE pid != pg_backend_pid();" 2>/dev/null | tr -d ' ' || echo "0")

        if [ "$CONN_COUNT" != "0" ] && [ "$CONN_COUNT" != "" ]; then
          # Reset idle timer if there are active connections
          LAST_ACTIVITY=$(date +%s)
          echo "✅ Activity detected ($CONN_COUNT connection(s)) - resetting idle timer"
        fi

        sleep $CHECK_INTERVAL
      done
    '';

    # Reset database (useful for testing)
    db-reset.exec = ''
      echo "🗑️  Dropping databases..."
      ${pkgs.postgresql_17}/bin/dropdb -h localhost -p 5433 --if-exists singularity_edge_dev
      ${pkgs.postgresql_17}/bin/dropdb -h localhost -p 5433 --if-exists singularity_edge_test
      echo "📦 Recreating databases..."
      ${pkgs.postgresql_17}/bin/createdb -h localhost -p 5433 singularity_edge_dev
      ${pkgs.postgresql_17}/bin/createdb -h localhost -p 5433 singularity_edge_test
      echo "✅ Databases reset complete"
    '';
  };

  # Pre-commit hooks (optional, can be added later)
  # pre-commit.hooks = {
  #   nixpkgs-fmt.enable = true;
  #   shellcheck.enable = true;
  # };
}
