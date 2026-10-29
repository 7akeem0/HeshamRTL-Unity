@echo off
rem Preview for a game without an Arabic translation: English letters are shown as Arabic letters.
if "%~1"=="" (
  echo Drag the game folder onto Install-Preview.bat
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Install-HeshamRTL.ps1" -GamePath "%~1" -Preview
pause
