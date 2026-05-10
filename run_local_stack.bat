@echo off
setlocal
cd /d "%~dp0"

if not exist "backend_python\start_backend.bat" (
  echo ERROR: backend_python\start_backend.bat not found.
  exit /b 1
)

echo [AIRS] Backend alag window mein start ho raha hai...
start "AIRS Backend" /D "%~dp0backend_python" cmd /k call start_backend.bat

echo [AIRS] API ke ready hone ka thoda wait...
timeout /t 5 /nobreak >nul

cd /d "%~dp0frontend_flutter"
echo [AIRS] Flutter ^(Chrome^) start. Flutter band karne se sirf UI band hoti hai; Backend window alag se band karein.
flutter run -d chrome --dart-define=BACKEND_URL=http://localhost:8000
