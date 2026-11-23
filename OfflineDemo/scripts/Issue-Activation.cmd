@echo off
cd /d "%~dp0"
node --disable-warning=ExperimentalWarning offline-issuer.mjs
pause
