@REM ==========================================================================
@REM  Install a Node.js version through nvm-windows.
@REM
@REM  Usage: install\node_js <version>
@REM         <version> may be a full version (18.19.0), a major line (18),
@REM         or one of the nvm-windows keywords: latest, lts.
@REM
@REM  This installs only. Switching to the version is a separate step, done by
@REM  use\node.cmd or by nvm use, so install and activate stay independent.
@REM ==========================================================================
@echo off
setlocal EnableExtensions

set "NODE_VER=%~1"
if "%NODE_VER%"=="" (
    echo [ERROR] Usage: install\node_js ^<version^>
    echo         Example: install\node_js lts
    echo         Example: install\node_js 22
    echo         Example: install\node_js 22.14.0
    exit /b 1
)

REM nvm-windows reads settings.txt from its own directory, so point it there
REM rather than at the version store. nvm.exe sits in bin\, one level up from
REM this script, not beside it.
set "NVM_EXE=%~dp0..\nvm.exe"
if not exist "%NVM_EXE%" (
    echo [ERROR] nvm.exe not found at "%NVM_EXE%".
    echo         This distribution is incomplete; re-download the release zip.
    exit /b 1
)

REM `call` is required: without it control does not return to this script.
call "%NVM_EXE%" install "%NODE_VER%"
if errorlevel 1 (
    echo [ERROR] nvm failed to install Node.js %NODE_VER%
    exit /b 1
)

echo Install complete: %NODE_VER%
echo Activate it with: use\node %NODE_VER%
endlocal & exit /b 0
