@echo off
setlocal
cd /d "%~dp0"

echo Verificando se o servidor local (porta 8000) ja esta no ar...
powershell -NoProfile -Command "if(-not (Test-NetConnection -ComputerName 127.0.0.1 -Port 8000 -InformationLevel Quiet -WarningAction SilentlyContinue)){ exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo Subindo o servidor local...
    start "anti-spoofing-bench servidor" /min cmd /c "python -m http.server 8000 --bind 127.0.0.1"
    timeout /t 2 /nobreak >nul
) else (
    echo Servidor ja estava no ar.
)

echo Abrindo as paginas...
start "" "http://localhost:8000/index.html"
timeout /t 1 /nobreak >nul
start "" "http://localhost:8000/liveness.html"

echo Pronto. Feche esta janela quando quiser (o servidor continua rodando em segundo plano).
pause >nul
