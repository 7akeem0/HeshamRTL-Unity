@echo off
rem HeshamRTL: Arabic for Unity games. Drag the game folder (or its .exe) onto this file.
rem If BepInEx is installed and no other BepInEx plugin needs it, it goes to the Recycle Bin.
if "%~1"=="" (
  echo Drag the game folder onto Install.bat
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Install-HeshamRTL.ps1" -GamePath "%~1" -RemoveBepInEx
pause
