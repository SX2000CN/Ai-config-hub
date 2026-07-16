@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-claude-success.ps1" %*
exit /b %ERRORLEVEL%
