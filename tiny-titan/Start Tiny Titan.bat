@echo off
title Tiny Titan
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 goto nonode

if exist node_modules goto run
echo.
echo   Setting up Tiny Titan for the first time. This takes about a minute...
echo.
call npm install
if errorlevel 1 goto failed

:run
call npm run app
goto end

:nonode
echo.
echo   Node.js is not installed yet.
echo.
echo   1. Go to https://nodejs.org and install the LTS version.
echo   2. Then double-click this file again.
goto end

:failed
echo.
echo   Setup did not finish. The messages above say why.

:end
echo.
pause
