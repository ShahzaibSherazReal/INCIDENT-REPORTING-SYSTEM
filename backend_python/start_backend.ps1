param(
  [string]$HostAddress = "0.0.0.0",
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

if (Get-Command py -ErrorAction SilentlyContinue) {
  $PyCmd = "py"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
  $PyCmd = "python"
} else {
  throw "Python was not found. Install Python 3.10+ and retry."
}

if (-not (Test-Path ".venv")) {
  & $PyCmd -m venv .venv
}

if ((Test-Path ".\.env.example") -and (-not (Test-Path ".\.env"))) {
  Copy-Item ".\.env.example" ".\.env"
  Write-Host "Created .env from .env.example. Update SUPABASE_SERVICE_ROLE_KEY before production use."
}

.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\python -m pip install -r requirements.txt
.\.venv\Scripts\python -m uvicorn main:app --host $HostAddress --port $Port --reload
