@echo off
set NVM_PATH=%CD%
set NVM_HOME=%NVM_PATH%\nodejs
set NVM_SYMLINK=%CD%\nodejs
REM setx /M NVM_HOME "%NVM_HOME%" // Uncomment if use Admin Profile
REM setx /M NVM_SYMLINK "%NVM_SYMLINK%" // Uncomment if use Admin Profile

echo Bootstrap Installer (cmder-nvm v2.0)
echo.

mkdir %NVM_PATH%\nodejs
if exist "%SYSTEMDRIVE%\Program Files (x86)\" (
set SYS_ARCH=64
) else (
set SYS_ARCH=32
)
(echo root: %NVM_HOME% && echo path: %NVM_SYMLINK% && echo arch: %SYS_ARCH% && echo proxy: none) > %NVM_HOME%\settings.txt

if not ERRORLEVEL 1 goto final

@echo on


:final
REM Wyświetl menu wyboru wersji Node.js
echo PATH: Installed Complete
echo NodeJS: Select node version to install in 5 sec:
echo ^- 1. NodeJS v16
echo ^- 2. NodeJS v18 (default)
echo ^- 3. NodeJS v19
echo ^- 0. Exit
choice /T 5 /N /C:1230 /M "Option >" /D 2

REM Sprawdź, którą wersję Node.js użytkownik chce zainstalować
if %ERRORLEVEL% == 1 (goto n16)
if %ERRORLEVEL% == 2 (goto n18)
if %ERRORLEVEL% == 3 (goto n19)
if %ERRORLEVEL% == 4 (goto stop)

REM Install NodeJS scripts
:n16
echo NodeJS: Installing NodeJS v16. Please Wait...
call install\node_16
exit /b

:n18
echo NodeJS: Installing NodeJS v18. Please Wait...
call install\node_18
exit /b


:n19
echo NodeJS: Installing NodeJS v19. Please Wait...
call install\node_19
exit /b

:stop
echo Thank you for use
echo NodeJS: You can install later using install/node_version



