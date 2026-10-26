@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run-tests.ps1" -OpenReport %*
set "TEST_EXIT=%ERRORLEVEL%"
echo.
echo Test run finished. Exit code: %TEST_EXIT%
pause
exit /b %TEST_EXIT%
