@echo off
REM ===========================================================================
REM  cmder-nvm bootstrap installer (Windows / Cmder)
REM
REM  Prepares the portable nvm environment inside this distribution and then
REM  installs a Node.js version. It does NOT download anything: bin\nvm.exe
REM  ships with the distribution and is verified against manifest.json, so the
REM  bootstrap is deterministic and works with no network.
REM
REM  Usage:
REM    install.cmd                     interactive version menu
REM    install.cmd --node 22           install a specific version
REM    install.cmd --node lts          install the latest LTS
REM    install.cmd --node lts --yes    same, without prompting (CI, provisioning)
REM    install.cmd --no-activate       install only, do not switch to it
REM
REM  Installing and activating are separate steps. Use bin\use\node.cmd to
REM  switch, or pass --no-activate here. The nvm-windows commands (nvm list,
REM  nvm install, nvm use) keep working exactly as before.
REM ===========================================================================
setlocal EnableExtensions

REM --- Environment layout ---------------------------------------------------
REM NVM_PATH    : root of this distribution
REM NVM_HOME    : where nvm-windows keeps the installed Node.js versions
REM NVM_SYMLINK : where nvm-windows points the "active" version
REM
REM nvm-windows reads settings.txt from its own directory, so it is written to
REM bin\ next to nvm.exe, not to NVM_HOME. NVM_HOME holds the version store.
set "NVM_PATH=%~dp0"
if "%NVM_PATH:~-1%"=="\" set "NVM_PATH=%NVM_PATH:~0,-1%"
set "NVM_HOME=%NVM_PATH%\nodejs"
set "NVM_SYMLINK=%NVM_PATH%\node"
set "NVM_EXE=%NVM_PATH%\bin\nvm.exe"
set "NVM_SETTINGS=%NVM_PATH%\bin\settings.txt"

set "NODE_TARGET="
set "ACTIVATE=1"

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--node" (
    if "%~2"=="" (
        echo [ERROR] --node requires a version, for example: install.cmd --node lts
        exit /b 1
    )
    set "NODE_TARGET=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--yes" (
    set "YES=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--no-activate" (
    set "ACTIVATE=0"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="/?" goto :usage
echo [ERROR] Unknown option: %~1
goto :usage

:args_done
if not defined YES set "YES="

call "%NVM_PATH%\lib\manifest.cmd" version >"%TEMP%\cmder-nvm-version.tmp" 2>nul
set "CMDER_NVM_VERSION=unknown"
if exist "%TEMP%\cmder-nvm-version.tmp" (
    set /p CMDER_NVM_VERSION=<"%TEMP%\cmder-nvm-version.tmp"
    del /q "%TEMP%\cmder-nvm-version.tmp" >nul 2>&1
)
if not defined CMDER_NVM_VERSION set "CMDER_NVM_VERSION=unknown"

echo Bootstrap Installer (cmder-nvm v%CMDER_NVM_VERSION%)
echo.

REM ===========================================================================
REM  1. Validate the platform
REM ===========================================================================
REM nvm-windows is a 64-bit binary; PROCESSOR_ARCHITEW6432 is only set when a
REM 32-bit process runs on a 64-bit OS, so both variables must be checked.
set "SYS_ARCH=32"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "SYS_ARCH=64"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "SYS_ARCH=64"
if "%SYS_ARCH%"=="32" (
    echo [ERROR] cmder-nvm requires 64-bit Windows, nvm-windows is 64-bit only.
    exit /b 1
)
echo [1/4] Platform      : Windows x64
echo.

REM ===========================================================================
REM  2. Verify the nvm-windows binary
REM ===========================================================================
REM The distribution ships bin\nvm.exe. It is never downloaded: upstream no
REM longer publishes the portable archive, and a binary fetched at install time
REM would make the install non-reproducible anyway.
call "%NVM_PATH%\lib\manifest.cmd" get "nvm-windows.version" >"%TEMP%\cmder-nvm-nvmver.tmp" 2>nul
set "NVM_VERSION="
if exist "%TEMP%\cmder-nvm-nvmver.tmp" set /p NVM_VERSION=<"%TEMP%\cmder-nvm-nvmver.tmp"
del /q "%TEMP%\cmder-nvm-nvmver.tmp" >nul 2>&1

echo [2/4] Verifying nvm-windows ...
if not exist "%NVM_EXE%" goto :nvm_missing

call "%NVM_PATH%\lib\manifest.cmd" verify "%NVM_EXE%" "nvm-windows.sha256"
if errorlevel 1 goto :nvm_bad
if not defined NVM_VERSION goto :nvm_no_version
echo        version %NVM_VERSION%
goto :step3

:nvm_missing
echo [FAIL] %NVM_EXE% is missing.
echo.
echo        This distribution is incomplete. Re-download the release zip;
echo        nvm-windows is bundled and is not fetched at install time.
echo.
endlocal & exit /b 1

:nvm_bad
echo.
echo [ERROR] bin\nvm.exe does not match manifest.json. Refusing to continue
echo         with an unverified binary.
endlocal & exit /b 1

:nvm_no_version
echo [WARN] Could not read the nvm-windows version from manifest.json.

:step3
echo.

REM ===========================================================================
REM  3. Create the nvm home and write settings.txt
REM ===========================================================================
echo [3/4] Preparing the nvm home ...
if not exist "%NVM_HOME%" (
    mkdir "%NVM_HOME%"
    if not exist "%NVM_HOME%" (
        echo [FAIL] Unable to create "%NVM_HOME%".
        exit /b 1
    )
)

REM One redirect per line instead of a parenthesised block: a block breaks when
REM the path itself contains a parenthesis, which is common under Program Files.
>"%NVM_SETTINGS%" echo root: %NVM_HOME%
>>"%NVM_SETTINGS%" echo path: %NVM_SYMLINK%
>>"%NVM_SETTINGS%" echo arch: %SYS_ARCH%
>>"%NVM_SETTINGS%" echo proxy: none
if not exist "%NVM_SETTINGS%" (
    echo [FAIL] Unable to write "%NVM_SETTINGS%".
    exit /b 1
)

echo        home %NVM_HOME%
echo        link %NVM_SYMLINK%
echo.

REM ===========================================================================
REM  4. Install a Node.js version
REM ===========================================================================
if not defined NODE_TARGET (
    if defined YES (
        echo [ERROR] --yes needs a version: install.cmd --node lts --yes
        exit /b 1
    )
    call :menu
    if not defined NODE_TARGET (
        echo.
        echo Nothing to do. Install a version later, using: install\node_js {VER}
        exit /b 0
    )
)

echo [4/4] Installing Node.js %NODE_TARGET% ...
call "%NVM_PATH%\bin\install\node_js.cmd" %NODE_TARGET%
if errorlevel 1 (
    echo.
    echo [ERROR] Installation of Node.js %NODE_TARGET% failed.
    exit /b 1
)

if "%ACTIVATE%"=="0" (
    echo.
    echo Installed. Activate it with: use\node %NODE_TARGET%
    exit /b 0
)

REM Activation is a separate step, delegated to bin\use\node.cmd, so the same
REM code path is used whether a version is installed now or switched to later.
call "%NVM_PATH%\bin\use\node.cmd" %NODE_TARGET%
if errorlevel 1 (
    echo.
    echo [ERROR] Node.js %NODE_TARGET% was installed but could not be activated.
    echo         Run: use\node %NODE_TARGET%
    exit /b 1
)

echo.
echo Done. Node.js %NODE_TARGET% is active in this session.
exit /b 0

REM ===========================================================================
REM  :menu - ask which version to install
REM ===========================================================================
:menu
echo NodeJS: Select node version to install in 5 sec:
echo ^- 1. NodeJS v20
echo ^- 2. NodeJS v22
echo ^- 3. NodeJS v24
echo ^- 4. NodeJS latest LTS
echo ^- 5. NodeJS latest
echo ^- 0. Exit
choice /T 5 /N /C:123450 /D 4 /M "Option > "

REM ERRORLEVEL is the 1-based position inside /C, so "0" is the 6th option.
if "%ERRORLEVEL%"=="1" set "NODE_TARGET=20"
if "%ERRORLEVEL%"=="2" set "NODE_TARGET=22"
if "%ERRORLEVEL%"=="3" set "NODE_TARGET=24"
if "%ERRORLEVEL%"=="4" set "NODE_TARGET=lts"
if "%ERRORLEVEL%"=="5" set "NODE_TARGET=latest"
if "%ERRORLEVEL%"=="6" set "NODE_TARGET="
exit /b 0

:usage
echo Usage:
echo    install.cmd                        interactive version menu
echo    install.cmd --node ^<version^>      e.g. --node 22, --node 22.14.0, --node lts
echo    install.cmd --node lts --yes       non-interactive, for CI and provisioning
echo    install.cmd --no-activate          install without switching to it
echo.
echo nvm-windows is bundled and verified against manifest.json; nothing is
echo downloaded during the install.
echo.
echo After installing, switch versions with: use\node ^<version^>
exit /b 0
