@echo off
REM ===========================================================================
REM  cmder-nvm - first-run bootstrap
REM
REM  SETUP.cmd copies this file into %CMDER_ROOT%\config\profile.d\, which is
REM  where Cmder runs every *.cmd on shell start (see vendor\init.bat). It is
REM  kept in src\ rather than config\ because config\ is generated: Cmder is
REM  unpacked from lib\cmder-<version>.zip, so anything in config\ is created at
REM  setup time and must not be tracked in git.
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
