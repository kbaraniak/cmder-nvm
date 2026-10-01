@REM ==========================================================================
@REM  Install a Node.js version through nvm-windows.
@REM
@REM  Usage: install\node_js <version>
@REM         <version> may be a full version (18.19.0), a major line (18),
@REM         or one of the nvm-windows keywords: latest, lts.
REM ==========================================================================
@echo off
setlocal EnableExtensions

set "NODE_VER=%~1"
if "%NODE_VER%"=="" (
    echo [ERROR] Usage: install\node_js ^<version^>
    echo         Example: install\node_js 18
    exit /b 1
)

REM `call` is required: without it control does not return to this script.
call nvm install "%NODE_VER%"
if errorlevel 1 (
    echo [ERROR] nvm failed to install Node.js %NODE_VER%
    exit /b 1
)

echo Install complete
echo Change to this version, using: use\node %NODE_VER%
endlocal & exit /b 0
