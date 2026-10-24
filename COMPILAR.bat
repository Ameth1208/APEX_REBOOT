@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0COMPILAR.ps1" %*
exit /b %errorlevel%
