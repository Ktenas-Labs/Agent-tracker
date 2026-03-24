#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d backend/.venv ]; then
  python -m venv backend/.venv
fi
# shellcheck source=/dev/null
source backend/.venv/bin/activate
python -m pip install --upgrade pip
pip install -r backend/requirements.txt

cd frontend && flutter pub get
