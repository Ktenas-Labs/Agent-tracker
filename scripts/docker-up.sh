#!/usr/bin/env bash
# Start API + Postgres + Flutter web (from repo root). Requires Docker Desktop (or compatible engine).
set -euo pipefail
cd "$(dirname "$0")/.."
exec docker compose up --build
