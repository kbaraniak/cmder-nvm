@echo off
SET NODEVER=v18.12.1

echo Using Node.js %NODEVER%
REM Changing PATH using nodevars
..\%CD%\%NODEVER%\nodevars.cmd>nul
IF ERRORLEVEL 1 ECHO You don't have installed version node.js %NODEVER%