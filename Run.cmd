@echo off
rem Double-click this to rebuild AC-Setupbook.html from your own setups folder.
setlocal
cd /d "%~dp0"

where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Setupbook.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Setupbook.ps1"
)

echo.
echo Done. Open AC-Setupbook.html in this folder.
pause
