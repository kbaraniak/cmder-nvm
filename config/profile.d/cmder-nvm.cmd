@echo off
REM ===========================================================================
REM  cmder-nvm - first-run bootstrap
REM
REM  Cmder runs every *.cmd in %CMDER_ROOT%\config\profile.d on shell start
REM  (see vendor\init.bat), and %CMDER_ROOT%\bin is already on PATH by then
REM  (line 377 of the same script). This file lives there so the project never
REM  has to modify config\user_profile.cmd, which is Cmder's own tracked file.
REM
REM  The guard is "are any Node.js versions installed?", not "does a file
REM  exist?". A failed install therefore retries on the next shell instead of
REM  being silently skipped forever.
REM ===========================================================================

if not defined CMDER_ROOT set "CMDER_ROOT=%~dp0..\.."
if not defined CMDER_ROOT exit /b 0

REM nvm-windows stores each version in a directory named vX.Y.Z under nodejs\.
dir /b /ad "%CMDER_ROOT%\nodejs" 2>nul | findstr /r /c:"^v[0-9]" >nul 2>&1
if not errorlevel 1 exit /b 0

echo.
echo   cmder-nvm: first run, preparing the environment.
echo.
call "%CMDER_ROOT%\install.cmd" --node lts --yes
exit /b %ERRORLEVEL%
