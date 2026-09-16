@echo off
setlocal
cd /d "%~dp0"
title Anti-Spoofing Bench

echo ============================================
echo   BANCADA DE ANTI-SPOOFING FACIAL
echo ============================================
echo.
echo Verificando o servidor local (porta 8000)...

powershell -NoProfile -Command "if(-not (Test-NetConnection -ComputerName 127.0.0.1 -Port 8000 -InformationLevel Quiet -WarningAction SilentlyContinue)){ exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 (
    echo   servidor caido - subindo agora...
    start "servidor anti-spoofing" /min cmd /c "python -m http.server 8000 --bind 127.0.0.1"
    timeout /t 3 /nobreak >nul
) else (
    echo   servidor ja estava no ar.
)

echo.
echo Abrindo as quatro paginas...
echo.
echo   1. AUTENTICADOR   - identidade + prova de vida  ^(o principal^)
start "" "http://localhost:8000/autenticador.html"
timeout /t 1 /nobreak >nul

echo   2. DETECTOR       - foto ou gesto, versao simples
start "" "http://localhost:8000/liveness.html"
timeout /t 1 /nobreak >nul

echo   3. BANCADA        - mede APCER / BPCER / ACER
start "" "http://localhost:8000/index.html"
timeout /t 1 /nobreak >nul

echo   4. VERSAO COMPLETA - todos os sinais, para a tese
start "" "http://localhost:8000/liveness-completo.html"

echo.
echo ============================================
echo   Tudo aberto. O servidor fica rodando
echo   em segundo plano (janela minimizada).
echo.
echo   Pode fechar esta janela.
echo ============================================
echo.
pause >nul
