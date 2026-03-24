#!/usr/bin/env bash
set -euo pipefail

cp -n backend/.env.example backend/.env || true
cp -n frontend/.env.example frontend/.env || true
docker compose up --build -d
echo "Backend: http://localhost:8000/docs"
echo "Frontend: http://localhost:8080"
