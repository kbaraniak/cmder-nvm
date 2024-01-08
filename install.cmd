@echo off
set NVM_PATH=%CD%
set NVM_HOME=%NVM_PATH%\nodejs
set NVM_SYMLINK=%CD%\nodejs
REM setx /M NVM_HOME "%NVM_HOME%" // Uncomment if use Admin Profile
REM setx /M NVM_SYMLINK "%NVM_SYMLINK%" // Uncomment if use Admin Profile

echo Bootstrap Installer (cmder-nvm v2.1)
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
echo ^- 4. NodeJS v20 (LTS)
echo ^- 5. NodeJS v21 (latest)
echo ^- 0. Exit
choice /T 5 /N /C:123450 /M "Option >" /D 2

REM Sprawdź, którą wersję Node.js użytkownik chce zainstalować
if %ERRORLEVEL% == 1 (goto n16)
if %ERRORLEVEL% == 2 (goto n18)
if %ERRORLEVEL% == 3 (goto n19)
if %ERRORLEVEL% == 4 (goto n20)
if %ERRORLEVEL% == 5 (goto n21)
if %ERRORLEVEL% == 6 (goto stop)

REM Install NodeJS scripts
:n16
echo NodeJS: Installing NodeJS v16. Please Wait...
start /wait /b cmd bin\install\node_js v16.20.2
start /wait /b cmd bin\use\node v16.20.2
exit /b

:n18
echo NodeJS: Installing NodeJS v18. Please Wait...
start /wait /b cmd /c bin\install\node_js v18.19.0
start /wait /b cmd /c bin\use\node v18.19.0
exit /b

:n19
echo NodeJS: Installing NodeJS v19. Please Wait...
start /wait /b cmd /c bin\install\node_js v19.9.0
start /wait /b cmd /c bin\use\node v19.9.0
exit /b

:n20
echo NodeJS: Installing NodeJS v20. Please Wait...
start /wait /b cmd /c bin\install\node_js v20.10.0
start /wait /b cmd /c bin\use\node v20.10.0
exit /b

:n21
echo NodeJS: Installing NodeJS v21. Please Wait...
start /wait /b cmd /c bin\install\node_js v21.5.0
start /wait /b cmd /c bin\use\node v21.5.0
exit /b

:stop
echo Thank you for use
echo NodeJS: You can install, other version later, using install/node/version



