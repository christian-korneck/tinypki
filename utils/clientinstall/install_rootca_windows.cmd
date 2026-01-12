@echo off
setlocal

if "%~1"=="" (
    echo Usage: install_rootca_windows.cmd file.pem
    exit /b 1
)

certutil.exe -addstore "Root" %~1


exit /B %errorlevel%