@echo off
setlocal

if not exist .venv (
  python -m venv .venv
)

if exist .env.example (
  if not exist .env (
    copy .env.example .env > nul
    echo Created .env from .env.example. Update SUPABASE_SERVICE_ROLE_KEY before production use.
  )
)

call .venv\Scripts\python -m pip install --upgrade pip
call .venv\Scripts\python -m pip install -r requirements.txt
call .venv\Scripts\python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
