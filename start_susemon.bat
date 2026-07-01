@echo off
setlocal enabledelayedexpansion
title SUSEMON v2.2 - Smart Auto-Start
color 0A

echo ========================================
echo   SUSEMON v2.2 - Smart Server Monitoring
echo   PBL-TRPL412 Politeknik Negeri Batam
echo ========================================
echo.

:: ── Path Konfigurasi ─────────────────────────────────────────────────────────
set PROJECT_DIR=C:\laragon\www\susemon
set BACKEND_DIR=%PROJECT_DIR%\backend
set MOBILE_DIR=%PROJECT_DIR%\mobile
set FIRMWARE_DIR=%PROJECT_DIR%\firmware
set GATEWAY_DIR=%PROJECT_DIR%\firmware\gateway
set MOSQUITTO_EXE=C:\Program Files\mosquitto\mosquitto.exe
set MOSQUITTO_PASSWD=C:\Program Files\mosquitto\mosquitto_passwd.exe
set MQTT_PASSWD_FILE=%BACKEND_DIR%\mosquitto_config\passwd
set MQTT_USER=susemonmqtt
set MQTT_PASS=ZkxJsPkXJVr86@v

:: ── Auto-detect Python (venv prioritas) ──────────────────────────────────────
set PYTHON_EXE=
if exist "%BACKEND_DIR%\venv\Scripts\python.exe" (
    set PYTHON_EXE=%BACKEND_DIR%\venv\Scripts\python.exe
    echo [PYTHON] Menggunakan venv.
    goto :PYTHON_OK
)
for %%P in (
    "C:\laragon\bin\python\python-3.12\python.exe"
    "C:\laragon\bin\python\python-3.11\python.exe"
    "C:\laragon\bin\python\python-3.10\python.exe"
    "C:\laragon\bin\python\python-3.13\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
    "C:\Python310\python.exe"
) do (
    if exist %%P ( set PYTHON_EXE=%%~P & echo [PYTHON] Ditemukan: %%~P & goto :PYTHON_OK )
)
where python >NUL 2>&1
if not errorlevel 1 ( set PYTHON_EXE=python & echo [PYTHON] Menggunakan python dari PATH & goto :PYTHON_OK )
echo [ERROR] Python tidak ditemukan! Install Python terlebih dahulu.
pause & exit /b 1
:PYTHON_OK
echo.

:: ── Auto-detect IP Laptop (prioritas Ethernet, skip Wi-Fi & VPN) ─────────────
set LOCAL_IP=
:: Coba ambil IP Ethernet dulu
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "127.0.0.1" ^| findstr /v "169.254"') do (
    set CANDIDATE=%%a
    set CANDIDATE=!CANDIDATE: =!
    :: Skip IP Wi-Fi range 192.168.x.x dan Tailscale 100.x.x.x — pakai Ethernet 10.x.x.x
    echo !CANDIDATE! | findstr /r "^10\." >nul 2>&1
    if not errorlevel 1 (
        if "!LOCAL_IP!"=="" set LOCAL_IP=!CANDIDATE!
    )
)
:: Fallback: ambil IP apapun yang bukan loopback jika Ethernet tidak ada
if "%LOCAL_IP%"=="" (
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "127.0.0.1" ^| findstr /v "169.254" ^| findstr /v "100\."') do (
        if "!LOCAL_IP!"=="" (
            set LOCAL_IP=%%a
            set LOCAL_IP=!LOCAL_IP: =!
        )
    )
)
if "%LOCAL_IP%"=="" set LOCAL_IP=127.0.0.1

echo [IP]   IP terdeteksi: %LOCAL_IP%
echo.

:: ── Update .env dengan IP yang benar ─────────────────────────────────────────
echo [ENV]  Menulis backend\.env ...
(
echo # Auto-generated oleh start_susemon.bat — DO NOT EDIT MANUAL
echo # Generated: %DATE% %TIME%
echo.
echo # Server
echo PORT=3000
echo NODE_ENV=development
echo.
echo # Database
echo DB_HOST=localhost
echo DB_USER=root
echo DB_PASSWORD=
echo DB_NAME=susemon_db
echo DB_PORT=3306
echo.
echo # JWT
echo JWT_SECRET=7f3a9c2e1b8d4f6a0e5c7b9d2f4a8e1c3b5d7f9a2c4e6b8d0f2a4c6e8b0d2f4
echo.
echo # CORS — izinkan semua origin ^(development^)
echo CORS_ORIGIN=*
echo.
echo # AI Thresholds
echo AI_THRESHOLD_TEMP=40
echo AI_THRESHOLD_TEMP_WARNING=35
echo AI_THRESHOLD_HUMIDITY=85
echo AI_THRESHOLD_HUM_WARNING=80
echo.
echo # MQTT — HiveMQ Cloud Cluster ^(Secure SSL/TLS^)
echo MQTT_BROKER=7df6c70556054ac4a953adf4a8e3b970.s1.eu.hivemq.cloud
echo MQTT_PORT=8883
echo MQTT_TOPIC=sensor/data
echo MQTT_DOWNLINK_TOPIC=sensor/ai_result
echo MQTT_CLIENT_ID=susemon-fastapi
echo MQTT_USER=susemonmqtt
echo MQTT_PASS=ZkxJsPkXJVr86@v
echo.
echo # API Key gateway
echo GATEWAY_API_KEY=gw-Xk9mP2nQ8rL5vT3wY7uJ4hF6cB1eA0sD
echo.
echo # Data retention ^(hari^)
echo DATA_RETENTION_DAYS=90
echo.
echo # IP Server ^(auto-detected^)
echo SERVER_IP=%LOCAL_IP%
) > "%BACKEND_DIR%\.env"
echo [ENV]  backend\.env diperbarui dengan IP: %LOCAL_IP%
echo.

:: ── Generate gateway_config.h untuk Arduino ──────────────────────────────────
echo [FW]   Menulis firmware\gateway\gateway_config.h ...
(
echo // Auto-generated oleh start_susemon.bat — DO NOT EDIT MANUAL
echo // Regenerate: jalankan start_susemon.bat di laptop baru
echo // Generated: %DATE% %TIME%
echo #ifndef GATEWAY_CONFIG_H
echo #define GATEWAY_CONFIG_H
echo.
echo // WiFi — ubah sesuai jaringan lokal Anda
echo #define WIFI_SSID_DEFAULT    "IoT_Susemon"
echo #define WIFI_PASS_DEFAULT    "12345678"
echo.
echo // MQTT Server — HiveMQ Cloud Cluster ^(Secure SSL/TLS^)
echo #define MQTT_SERVER_DEFAULT  "7df6c70556054ac4a953adf4a8e3b970.s1.eu.hivemq.cloud"
echo #define MQTT_PORT_DEFAULT    8883
echo #define MQTT_USER_DEFAULT    "susemonmqtt"
echo #define MQTT_PASS_DEFAULT    "ZkxJsPkXJVr86@v"
echo.
echo // Topics — Lintas Jaringan
echo #define TOPIC_UP_DEFAULT     "sensor/data"
echo #define TOPIC_DOWN_DEFAULT   "sensor/ai_result"
echo.
echo // Health check endpoint — kosong karena beda jaringan (fallback via MQTT)
echo #define BACKEND_HEALTH_URL   ""
echo #define BACKEND_IP           ""
echo #define BACKEND_PORT         3000
echo.
echo #endif // GATEWAY_CONFIG_H
) > "%GATEWAY_DIR%\gateway_config.h"
echo [FW]   firmware\gateway\gateway_config.h diperbarui dengan IP: %LOCAL_IP%
echo.

:: ── Update susemon_forward.sh dengan IP terbaru ───────────────────────────────
echo [SH]   Memperbarui firmware\susemon_forward.sh default IP...
"%PYTHON_EXE%" -c "import re; path=r'%FIRMWARE_DIR%\susemon_forward.sh'.replace('\\\\', '/'); f=open(path,'r'); c=f.read(); f.close(); c=re.sub(r'(SUSEMON_SERVER:-)[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+', r'\g<1>%LOCAL_IP%', c); f=open(path,'w'); f.write(c); f.close(); print('[SH] susemon_forward.sh default IP diperbarui')" 2>nul
echo.

:: ── 1. Kill proses lama ───────────────────────────────────────────────────────
echo [INIT] Membersihkan proses lama...
taskkill /F /IM mosquitto.exe >NUL 2>&1
taskkill /F /IM uvicorn.exe   >NUL 2>&1
ping 127.0.0.1 -n 3 >NUL
echo [INIT] Selesai.
echo.

:: ── 2. Setup Mosquitto ────────────────────────────────────────────────────────
echo [MQTT] Menggunakan HiveMQ Cloud. Melewati startup Mosquitto lokal...
goto :SKIP_MQTT
netsh advfirewall firewall show rule name="SUSEMON Backend 3000" >nul 2>&1
if errorlevel 1 (
    netsh advfirewall firewall add rule name="SUSEMON Backend 3000" dir=in action=allow protocol=TCP localport=3000 >nul 2>&1
    if not errorlevel 1 (echo [FW] Port 3000 dibuka di Windows Firewall.) else (echo [FW] Gagal buka port 3000.)
)
:SKIP_MQTT

:: ── 3. Jalankan Backend FastAPI ───────────────────────────────────────────────
echo.
echo [API]  Menjalankan Backend FastAPI di port 3000...
start "SUSEMON - Backend API" cmd /k "cd /d "%BACKEND_DIR%" && "%PYTHON_EXE%" -m uvicorn main:app --host 0.0.0.0 --port 3000 --reload"
ping 127.0.0.1 -n 7 >NUL
echo [API]  Backend started.
echo.

:: ── 4. Jalankan Flutter App ───────────────────────────────────────────────────
echo [APP]  Menjalankan Flutter App (Windows desktop)...
set FLUTTER_EXE=
if exist "C:\src\flutter\bin\flutter.bat"                    set FLUTTER_EXE=C:\src\flutter\bin\flutter.bat
if "!FLUTTER_EXE!"=="" if exist "%USERPROFILE%\flutter\bin\flutter.bat" set FLUTTER_EXE=%USERPROFILE%\flutter\bin\flutter.bat
if "!FLUTTER_EXE!"=="" if exist "C:\flutter\bin\flutter.bat"            set FLUTTER_EXE=C:\flutter\bin\flutter.bat
if "!FLUTTER_EXE!"=="" (
    where flutter >NUL 2>&1
    if not errorlevel 1 set FLUTTER_EXE=flutter
)
if "!FLUTTER_EXE!"=="" (
    echo [APP]  Flutter tidak ditemukan! Tambahkan ke PATH atau install di C:\src\flutter
    echo [APP]  Download: https://docs.flutter.dev/get-started/install/windows
    goto :SKIP_FLUTTER
)
echo [APP]  Flutter: !FLUTTER_EXE!
start "SUSEMON - Flutter App" cmd /k "cd /d %MOBILE_DIR% && "!FLUTTER_EXE!" run -d windows"
echo [APP]  Flutter started.
:SKIP_FLUTTER
echo.

:: ── 5. Info ───────────────────────────────────────────────────────────────────
echo ========================================
echo   SUSEMON v2.2 - Semua Service Aktif
echo ========================================
echo.
echo   IP Laptop (auto)  : %LOCAL_IP%
echo.
echo   MQTT Broker       : 7df6c70556054ac4a953adf4a8e3b970.s1.eu.hivemq.cloud:8883 (SSL/TLS)
echo   Backend API       : http://%LOCAL_IP%:3000
echo   API Docs          : http://%LOCAL_IP%:3000/api/docs
echo   Health Check      : http://%LOCAL_IP%:3000/api/health
echo.
echo   ── Login Flutter ───────────────────────
echo   Dari HP (jaringan sama):
echo     IP Address  : %LOCAL_IP%
echo     Access Code : SUSEMON2026
echo   Dari laptop ini:
echo     IP Address  : 127.0.0.1
echo     Access Code : ADMIN123
echo.
echo   ── Upload Firmware Arduino ─────────────
echo   File config    : firmware\gateway\gateway_config.h
echo   MQTT Server    : 7df6c70556054ac4a953adf4a8e3b970.s1.eu.hivemq.cloud
echo   Buka Arduino IDE, File > Open: firmware\gateway\gateway.ino
echo   Upload ke gateway TTGO, lalu power on.
echo.
echo   ── Konfigurasi Dragino LG02 ────────────
echo   MQTT Server    : 7df6c70556054ac4a953adf4a8e3b970.s1.eu.hivemq.cloud
echo   MQTT Port      : 8883
echo   MQTT User      : susemonmqtt
echo   MQTT Pass      : ZkxJsPkXJVr86@v (SSL/TLS enabled)
echo   Topic Up       : sensor/data
echo   Topic Down     : sensor/ai_result
echo ========================================
echo.
echo Tekan sembarang tombol untuk keluar...
pause >NUL
