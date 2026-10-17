@echo off
setlocal
where powershell.exe >nul 2>nul || (echo PowerShell was not found. & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-17d-Magisk.ps1" %*
exit /b %errorlevel%
