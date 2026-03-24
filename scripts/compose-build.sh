#!/usr/bin/env bash
# Build all Compose images locally. Requires Docker Desktop (or engine) running.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v docker >/dev/null 2>&1; then
  echo "docker: command not found. Install and start Docker Desktop, then retry." >&2
  exit 1
fi
exec docker compose build "$@"
