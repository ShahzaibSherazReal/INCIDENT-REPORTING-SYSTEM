#!/usr/bin/env bash
set -euo pipefail

HOST_ADDRESS="${1:-0.0.0.0}"
PORT="${2:-8000}"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

if [ -f ".env.example" ] && [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Update SUPABASE_SERVICE_ROLE_KEY before production use."
fi

source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m uvicorn main:app --host "$HOST_ADDRESS" --port "$PORT" --reload
