@echo off
title SUSEMON - Server Startup
color 0A

echo ========================================
echo   SUSEMON - Smart Server Monitoring
echo   PBL-TRPL412 Politeknik Negeri Batam
echo ========================================
echo.

:: ── 1. Kill proses lama ──────────────────────────────────────────────────────
echo [INIT] Membersihkan proses lama...
taskkill /F /IM mosquitto.exe >NUL 2>&1
taskkill /F /IM python.exe >NUL 2>&1
timeout /t 2 /nobreak >NUL

:: ── 2. Setup MQTT Auth (otomatis, hanya jika belum ada) ──────────────────────
set MQTT_PASSWD_FILE=C:\laragon\www\susemon\backend\mosquitto_config\passwd
set MOSQUITTO_EXE=C:\Program Files\mosquitto\mosquitto.exe
set MOSQUITTO_PASSWD=C:\Program Files\mosquitto\mosquitto_passwd.exe

if not exist "%MOSQUITTO_EXE%" (
    echo [MQTT] ERROR: Mosquitto tidak ditemukan di "%MOSQUITTO_EXE%"
    echo [MQTT] Download: https://mosquitto.org/download/
    echo [MQTT] Jalankan tanpa auth sementara...
    goto :SKIP_AUTH
)

if not exist "C:\laragon\www\susemon\backend\mosquitto_config" (
    mkdir "C:\laragon\www\susemon\backend\mosquitto_config"
)

if not exist "%MQTT_PASSWD_FILE%" (
    echo [MQTT] Membuat password file MQTT...
    echo [MQTT] Username: susemon  Password: susemon2026mqtt
    :: Buat password file secara otomatis (non-interactive)
    echo susemon:susemon2026mqtt > "%TEMP%\mqtt_plain.txt"
    "%MOSQUITTO_PASSWD%" -b "%MQTT_PASSWD_FILE%" susemon susemon2026mqtt >NUL 2>&1
    if exist "%MQTT_PASSWD_FILE%" (
        echo [MQTT] Password file berhasil dibuat!
        :: Aktifkan auth di mosquitto.conf
        powershell -Command "(Get-Content 'C:\laragon\www\susemon\backend\mosquitto.conf') -replace 'allow_anonymous true','allow_anonymous false' | Set-Content 'C:\laragon\www\susemon\backend\mosquitto.conf'"
        powershell -Command "(Get-Content 'C:\laragon\www\susemon\backend\mosquitto.conf') -replace '# allow_anonymous false','allow_anonymous false' | Set-Content 'C:\laragon\www\susemon\backend\mosquitto.conf'"
        powershell -Command "(Get-Content 'C:\laragon\www\susemon\backend\mosquitto.conf') -replace '# password_file','password_file' | Set-Content 'C:\laragon\www\susemon\backend\mosquitto.conf'"
    ) else (
        echo [MQTT] Gagal buat password file, lanjut tanpa auth...
    )
    del "%TEMP%\mqtt_plain.txt" >NUL 2>&1
) else (
    echo [MQTT] Password file sudah ada, skip setup.
)

:SKIP_AUTH

:: ── 3. Jalankan Mosquitto MQTT Broker ────────────────────────────────────────
echo [MQTT] Menjalankan Mosquitto...
start "SUSEMON - MQTT Broker" "%MOSQUITTO_EXE%" -c "C:\laragon\www\susemon\backend\mosquitto.conf" -v
timeout /t 2 /nobreak >NUL
echo [MQTT] Mosquitto started di port 1883

:: ── 4. Jalankan Backend FastAPI ──────────────────────────────────────────────
echo [API]  Menjalankan Backend FastAPI...

:: Cek apakah ada virtual environment
if exist "C:\laragon\www\susemon\backend\venv\Scripts\activate.bat" (
    echo [API]  Menggunakan virtual environment...
    start "SUSEMON - Backend API" cmd /k "cd /d C:\laragon\www\susemon\backend && venv\Scripts\activate && uvicorn main:app --host 0.0.0.0 --port 3000"
) else (
    start "SUSEMON - Backend API" cmd /k "cd /d C:\laragon\www\susemon\backend && uvicorn main:app --host 0.0.0.0 --port 3000"
)
timeout /t 4 /nobreak >NUL
echo [API]  Backend started di port 3000

:: ── 5. Set JAVA_HOME untuk Flutter ───────────────────────────────────────────
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

:: ── 6. Jalankan Flutter App ───────────────────────────────────────────────────
echo [APP]  Menjalankan Flutter App...
start "SUSEMON - Flutter App" cmd /k "cd /d C:\laragon\www\susemon\mobile && flutter run"
echo [APP]  Flutter started - pilih device di jendela Flutter

:: ── 7. Tampilkan info ─────────────────────────────────────────────────────────
:: Auto-detect IP laptop
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set LOCAL_IP=%%a
    goto :SHOW_INFO
)
:SHOW_INFO
set LOCAL_IP=%LOCAL_IP: =%

echo.
echo ========================================
echo   Semua service berjalan!
echo ========================================
echo.
echo   MQTT Broker : localhost:1883
echo   Backend API : http://localhost:3000
echo   API Docs    : http://localhost:3000/docs
echo.
echo   IP Laptop   : %LOCAL_IP%
echo.
echo   Login Flutter:
echo     IP Address  : %LOCAL_IP%  (jaringan)
echo     IP Address  : 127.0.0.1   (lokal)
echo     Access Code : SUSEMON2026  atau  ADMIN123 (lokal)
echo.
echo   Gateway Arduino:
echo     MQTT Server : %LOCAL_IP%
echo     MQTT Port   : 1883
echo     MQTT User   : susemon
echo     MQTT Pass   : susemon2026mqtt
echo     Topic Up    : sensor/data
echo     Topic Down  : sensor/ai_result
echo.
echo   Ganti WiFi/IP Gateway:
echo     Tekan BOOT 3 detik -> konek ke SUSEMON-Gateway
echo     Buka 192.168.4.1 -> isi WiFi + IP server baru
echo ========================================
echo.
pause
