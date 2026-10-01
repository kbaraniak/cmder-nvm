@REM ==========================================================================
@REM  Switch the active Node.js version for the current Cmder session.
@REM
@REM  Usage: use\node <version>
@REM         <version> may be a folder name under the nvm home, or one of the
@REM         nvm-windows keywords: latest, lts.
@REM
@REM  This is the activate step only. It never installs anything; use
@REM  install\node_js first if the version is missing.
@REM ==========================================================================
@echo off
setlocal EnableExtensions

set "NODEVER=%~1"
if "%NODEVER%"=="" (
    echo [ERROR] Usage: use\node ^<version^>
    echo         Example: use\node lts
    echo         Example: use\node 22
    exit /b 1
)

REM Resolve paths from the script location, not from the current directory.
REM NVM_HOME holds the installed versions; settings.txt lives next to nvm.exe.
set "NVM_HOME=%~dp0..\..\nodejs"
set "NVM_EXE=%~dp0nvm.exe"

if not exist "%NVM_EXE%" (
    echo [ERROR] nvm.exe not found at "%NVM_EXE%".
    exit /b 1
)
if not exist "%NVM_HOME%" (
    echo [ERROR] No nvm home at "%NVM_HOME%".
    echo         Run install.cmd first.
    exit /b 1
)

REM Keywords such as "lts" or "latest" are not folder names: ask nvm-windows
REM which concrete version they currently resolve to.
REM
REM Delayed expansion is deliberately NOT enabled here: nodevars.bat rebuilds
REM PATH, and delayed expansion corrupts any PATH entry containing "!".
set "RESOLVED="
for /f "usebackq tokens=* delims=" %%v in (`"%NVM_EXE%" version %NODEVER% 2^>nul`) do (
    if not "%%v"=="" set "RESOLVED=%%v"
)
if not defined RESOLVED set "RESOLVED=%NODEVER%"

set "SCRIPTPATH=%NVM_HOME%\%RESOLVED%\nodevars.bat"

if not exist "%SCRIPTPATH%" (
    echo [ERROR] You don't have installed version node.js %RESOLVED%
    echo         Run: install\node_js %NODEVER%
    endlocal & exit /b 1
)

echo NodeJS: Using Node.js %RESOLVED%

REM nodevars.bat rewrites PATH; its chatter is not interesting to the user.
call "%SCRIPTPATH%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to activate Node.js %RESOLVED%
    endlocal & exit /b 1
)

echo NodeJS enabled: node, npm
endlocal & exit /b 0
