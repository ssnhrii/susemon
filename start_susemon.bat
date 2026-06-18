@echo off
title SUSEMON v2.1 - Server Startup
color 0A

echo ========================================
echo   SUSEMON v2.1 - Smart Server Monitoring
echo   PBL-TRPL412 Politeknik Negeri Batam
echo ========================================
echo.

:: ── Konfigurasi Path ─────────────────────────────────────────────────────────
set PROJECT_DIR=C:\laragon\www\susemon
set BACKEND_DIR=%PROJECT_DIR%\backend
set MOBILE_DIR=%PROJECT_DIR%\mobile
set PYTHON_EXE=C:\laragon\bin\python\python-3.10\python.exe
set MOSQUITTO_EXE=C:\Program Files\mosquitto\mosquitto.exe
set MOSQUITTO_PASSWD=C:\Program Files\mosquitto\mosquitto_passwd.exe
set MQTT_PASSWD_FILE=%BACKEND_DIR%\mosquitto_config\passwd
set MQTT_USER=susemon
set MQTT_PASS=Susemon2026mqtt

:: ── Auto-detect IP Laptop ────────────────────────────────────────────────────
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set LOCAL_IP=%%a
    goto :IP_FOUND
)
:IP_FOUND
set LOCAL_IP=%LOCAL_IP: =%

:: ── 1. Kill proses lama ──────────────────────────────────────────────────────
echo [INIT] Membersihkan proses lama...
taskkill /F /IM mosquitto.exe >NUL 2>&1
taskkill /F /IM uvicorn.exe   >NUL 2>&1
timeout /t 2 /nobreak >NUL
echo [INIT] Selesai.
echo.

:: ── 2. Setup MQTT Auth ───────────────────────────────────────────────────────
if not exist "%MOSQUITTO_EXE%" (
    echo [MQTT] Mosquitto tidak ditemukan.
    echo [MQTT] Download: https://mosquitto.org/download/
    echo [MQTT] Lanjut tanpa MQTT - hardware tidak akan terhubung.
    echo.
    goto :SKIP_MQTT
)

echo [MQTT] Mosquitto ditemukan.

:: Buat folder config jika belum ada
if not exist "%BACKEND_DIR%\mosquitto_config" (
    mkdir "%BACKEND_DIR%\mosquitto_config"
)

:: Buat password file jika belum ada
if not exist "%MQTT_PASSWD_FILE%" (
    echo [MQTT] Membuat password file...
    "%MOSQUITTO_PASSWD%" -b "%MQTT_PASSWD_FILE%" %MQTT_USER% %MQTT_PASS% >NUL 2>&1
    if exist "%MQTT_PASSWD_FILE%" (
        echo [MQTT] Password file berhasil dibuat.
    ) else (
        echo [MQTT] Gagal buat password file. Lanjut dengan allow_anonymous.
    )
) else (
    echo [MQTT] Password file sudah ada.
)

:: Jalankan Mosquitto
echo [MQTT] Menjalankan Mosquitto di port 1883...
start "SUSEMON - MQTT Broker" "%MOSQUITTO_EXE%" -c "%BACKEND_DIR%\mosquitto.conf" -v
timeout /t 3 /nobreak >NUL
echo [MQTT] Mosquitto started.
echo.

:SKIP_MQTT

:: ── 3. Jalankan Backend FastAPI ──────────────────────────────────────────────
echo [API]  Menjalankan Backend FastAPI di port 3000...

:: Cek virtual environment dulu, fallback ke Python sistem
if exist "%BACKEND_DIR%\venv\Scripts\python.exe" (
    set PYTHON_EXE=%BACKEND_DIR%\venv\Scripts\python.exe
    echo [API]  Menggunakan virtual environment.
) else (
    echo [API]  Menggunakan Python sistem: %PYTHON_EXE%
)

start "SUSEMON - Backend API" cmd /k "cd /d %BACKEND_DIR% && %PYTHON_EXE% -m uvicorn main:app --host 0.0.0.0 --port 3000 --reload"
timeout /t 5 /nobreak >NUL
echo [API]  Backend started.
echo.

:: ── 4. Jalankan Flutter App ──────────────────────────────────────────────────
echo [APP]  Menjalankan Flutter App...
echo [APP]  Pilih device di jendela Flutter yang terbuka.
start "SUSEMON - Flutter App" cmd /k "cd /d %MOBILE_DIR% && flutter run"
echo.

:: ── 5. Tampilkan Info ────────────────────────────────────────────────────────
echo ========================================
echo   SUSEMON v2.1 - Semua Service Aktif
echo ========================================
echo.
echo   MQTT Broker  : localhost:1883
echo   Backend API  : http://localhost:3000
echo   API Docs     : http://localhost:3000/api/docs
echo   Health Check : http://localhost:3000/api/health
echo.
echo   IP Laptop    : %LOCAL_IP%
echo.
echo   Login Flutter (dari HP di jaringan sama):
echo     IP Address  : %LOCAL_IP%
echo     Access Code : SUSEMON2026
echo.
echo   Login Flutter (dari laptop):
echo     IP Address  : 127.0.0.1
echo     Access Code : ADMIN123
echo.
echo   Konfigurasi Gateway Arduino:
echo     MQTT Server : %LOCAL_IP%
echo     MQTT Port   : 1883
echo     MQTT User   : %MQTT_USER%
echo     MQTT Pass   : %MQTT_PASS%
echo     Topic Up    : sensor/data
echo     Topic Down  : sensor/ai_result
echo.
echo   Reset Gateway WiFi:
echo     Tahan tombol IO38 selama 3 detik
echo     Konek ke WiFi: SUSEMON-Gateway (pass: susemon123)
echo     Buka browser: 192.168.4.1
echo     Isi WiFi + IP Server: %LOCAL_IP%
echo ========================================
echo.
echo Tekan sembarang tombol untuk keluar...
pause >NUL
