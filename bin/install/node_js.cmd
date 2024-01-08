@REM Install Script Node.js
@echo off
set NODE_VER=%1

nvm install %NODE_VER%
echo Change to this version, using: use\node %NODE_VER%