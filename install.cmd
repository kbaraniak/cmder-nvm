@echo off
REM ===========================================================================
REM  cmder-nvm bootstrap installer (Windows / Cmder)
REM
REM  Creates the portable nvm environment inside this distribution and then
REM  offers to install a Node.js version. The repository root is resolved from
REM  the script location so the installer works from any working directory.
REM ===========================================================================
setlocal EnableExtensions

REM --- Environment layout ---------------------------------------------------
REM NVM_PATH    : root of this distribution
REM NVM_HOME    : where nvm-windows keeps the installed Node.js versions
REM NVM_SYMLINK : where nvm-windows points the "active" version
set "NVM_PATH=%~dp0"
if "%NVM_PATH:~-1%"=="\" set "NVM_PATH=%NVM_PATH:~0,-1%"
set "NVM_HOME=%NVM_PATH%\nodejs"
set "NVM_SYMLINK=%NVM_PATH%\node"
set "NVM_SETTINGS=%NVM_HOME%\settings.txt"

echo Bootstrap Installer (cmder-nvm v2.1)
echo.

REM --- Verify we are running on a 64-bit OS ---------------------------------
REM nvm-windows is a 64-bit binary; PROCESSOR_ARCHITEW6432 is only set when a
REM 32-bit process runs on a 64-bit OS, so both variables must be checked.
set "SYS_ARCH=32"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "SYS_ARCH=64"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "SYS_ARCH=64"
if "%SYS_ARCH%"=="32" (
    echo [ERROR] cmder-nvm requires 64-bit Windows, nvm-windows is 64-bit only.
    exit /b 1
)

REM --- Create the nvm home --------------------------------------------------
if not exist "%NVM_HOME%" (
    mkdir "%NVM_HOME%"
    if not exist "%NVM_HOME%" (
        echo [ERROR] Unable to create "%NVM_HOME%".
        exit /b 1
    )
)

REM --- Write settings.txt ---------------------------------------------------
REM One redirect per line instead of a parenthesised block: a block breaks when
REM the path itself contains a parenthesis, which is common under Program Files.
>"%NVM_SETTINGS%"  echo root: %NVM_HOME%
>>"%NVM_SETTINGS%" echo path: %NVM_SYMLINK%
>>"%NVM_SETTINGS%" echo arch: %SYS_ARCH%
>>"%NVM_SETTINGS%" echo proxy: none
if not exist "%NVM_SETTINGS%" (
    echo [ERROR] Unable to write "%NVM_SETTINGS%".
    exit /b 1
)
echo nvm home : %NVM_HOME%
echo nvm link : %NVM_SYMLINK%
echo nvm arch : %SYS_ARCH%
echo.

REM ===========================================================================
REM  Node.js version menu
REM ===========================================================================
echo NodeJS: Select node version to install in 5 sec:
echo ^- 1. NodeJS v16
echo ^- 2. NodeJS v18 (LTS)
echo ^- 3. NodeJS v19
echo ^- 4. NodeJS v20 (LTS)
echo ^- 5. NodeJS v21
echo ^- 6. NodeJS latest LTS
echo ^- 7. NodeJS latest
echo ^- 0. Exit
choice /T 5 /N /C:12345670 /D 7 /M "Option > "

REM ERRORLEVEL is the 1-based position inside /C, so "0" is the 8th option.
if "%ERRORLEVEL%"=="1" goto n16
if "%ERRORLEVEL%"=="2" goto n18
if "%ERRORLEVEL%"=="3" goto n19
if "%ERRORLEVEL%"=="4" goto n20
if "%ERRORLEVEL%"=="5" goto n21
if "%ERRORLEVEL%"=="6" goto n_lts
if "%ERRORLEVEL%"=="7" goto n_latest
if "%ERRORLEVEL%"=="8" goto stop

:n16
call :install_version v16.20.2 "NodeJS v16"
exit /b %ERRORLEVEL%

:n18
call :install_version v18.19.0 "NodeJS v18 (LTS)"
exit /b %ERRORLEVEL%

:n19
call :install_version v19.9.0 "NodeJS v19"
exit /b %ERRORLEVEL%

:n20
call :install_version v20.10.0 "NodeJS v20 (LTS)"
exit /b %ERRORLEVEL%

:n21
call :install_version v21.5.0 "NodeJS v21"
exit /b %ERRORLEVEL%

:n_lts
call :install_version lts "NodeJS latest LTS"
exit /b %ERRORLEVEL%

:n_latest
call :install_version latest "NodeJS latest"
exit /b %ERRORLEVEL%

:stop
echo Thank you for use
echo NodeJS: You can install, other version later, using install\node/version
exit /b 0

REM ===========================================================================
REM  :install_version <version> <label>
REM
REM  Installs the requested version and then switches to it. `call` is used
REM  instead of `start` so the child runs in this console and the exit code of
REM  the install is visible here.
REM ===========================================================================
:install_version
echo NodeJS: Installing %~2. Please Wait...
call "%NVM_PATH%\bin\install\node_js.cmd" %~1
if errorlevel 1 (
    echo [ERROR] Installation of %~2 failed.
    exit /b 1
)
call "%NVM_PATH%\bin\use\node.cmd" %~1
exit /b %ERRORLEVEL%
