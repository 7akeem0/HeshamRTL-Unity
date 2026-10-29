@echo off
rem Removes HeshamRTL from the game and restores what it changed.
if "%~1"=="" (
  echo Drag the game folder onto Uninstall.bat
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Install-HeshamRTL.ps1" -GamePath "%~1" -Uninstall
pause
