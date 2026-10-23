@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\export.ps1"
if errorlevel 1 (
  echo La exportacion no se completo. Revisa el mensaje anterior.
  pause
  exit /b 1
)
echo Exportaciones listas en la carpeta build.
pause
