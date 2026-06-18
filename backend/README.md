# SUSEMON Backend API v2.1

Backend untuk **SUSEMON** (Suhu dan Kelembapan Server Monitoring) — sistem monitoring server room berbasis IoT dengan AI.

## Versi

| Komponen | Versi |
|---|---|
| Backend API | 2.1.0 |
| Python | 3.10+ |
| FastAPI | 0.111.0 |

## Tech Stack

- **Framework**: Python FastAPI + Uvicorn
- **Database**: MySQL 8.0 (aiomysql async pool)
- **Auth**: JWT (python-jose) + bcrypt (passlib)
- **MQTT**: paho-mqtt (subscribe dari LoRa Gateway)
- **AI**: scikit-learn (Isolation Forest) + Moving Average + EWMA + Z-score
- **WebSocket**: FastAPI native WebSocket (real-time ke Flutter)

## Instalasi

```bash
cd backend
pip install -r requirements.txt
```

## Setup Database

```bash
Get-Content init_db.sql | mysql -u root
```

Lalu jalankan migrasi password (hash bcrypt untuk data lama):
```bash
python migrate_passwords.py
```

## Konfigurasi

Copy `.env.example` ke `.env`:
```bash
copy .env.example .env
```

Variabel penting:
- `JWT_SECRET` — ganti dengan string acak 64 karakter
- `GATEWAY_API_KEY` — ganti dengan key acak
- `MQTT_USER`, `MQTT_PASS` — sesuai konfigurasi Mosquitto
- `DATA_RETENTION_DAYS` — retensi data sensor (default 90 hari)

Generate secret:
```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

## Menjalankan

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 3000 --reload
```

## MQTT Broker (Mosquitto)

```bash
mosquitto -c mosquitto.conf
```

Buat password file:
```bash
mosquitto_passwd -c mosquitto_config/passwd susemon
```

## Keamanan

- JWT token dengan expiry 8 jam + unique JTI
- bcrypt hashing untuk semua access code
- Brute force protection: lockout 5 menit setelah 5x gagal
- Rate limiting: 120 req/60 detik per IP
- Role-based access control: admin / pic
- Security headers: X-Content-Type-Options, X-Frame-Options, dll
- Timing-safe API key comparison

## API Endpoints

| Method | Endpoint | Auth | Keterangan |
|--------|----------|------|------------|
| POST | `/api/auth/login` | — | Login IP + Access Code |
| GET | `/api/auth/verify` | JWT | Verifikasi token |
| POST | `/api/auth/logout` | JWT | Logout |
| GET | `/api/users` | Admin | List semua user |
| POST | `/api/users` | Admin | Buat user baru |
| PUT | `/api/users/{id}` | Admin | Update user |
| DELETE | `/api/users/{id}` | Admin | Hapus user |
| GET | `/api/users/me` | JWT | Info user sendiri |
| GET | `/api/sensors/nodes` | JWT | Semua node + data terkini |
| GET | `/api/sensors/latest` | JWT | Pembacaan terbaru semua node |
| GET | `/api/sensors/data/{node_id}` | JWT | Riwayat data node |
| GET | `/api/sensors/statistics` | JWT | Statistik agregat |
| GET | `/api/sensors/export/{node_id}` | JWT | Export CSV |
| POST | `/api/sensors/data` | API Key | Submit data dari gateway |
| GET | `/api/ai/analysis` | JWT | Analisis AI semua node |
| GET | `/api/ai/prediction/{node_id}` | JWT | Prediksi AI satu node |
| GET | `/api/ai/summary` | JWT | Status global sistem |
| GET | `/api/notifications` | JWT | Daftar notifikasi |
| PUT | `/api/notifications/read-all` | JWT | Tandai semua dibaca |
| PUT | `/api/notifications/{id}/read` | JWT | Tandai satu dibaca |
| DELETE | `/api/notifications/{id}` | JWT | Hapus notifikasi |
| GET | `/api/health` | — | Status komponen sistem |
| WS | `/ws` | — | WebSocket real-time |
| GET | `/api/docs` | — | Swagger UI |

## Akun Default

| IP | Access Code | Role |
|----|-------------|------|
| `127.0.0.1` | `ADMIN123` | admin |
| `0.0.0.0` | `SUSEMON2026` | admin |

## Changelog

### v2.1.0 (2026)
- bcrypt hashing untuk access code
- Brute force protection dengan lockout
- JWT secret kuat + JTI unique
- Timing-safe API key comparison
- Security headers middleware
- Input validation di users router
- Login attempt logging
- Export CSV sensor data
- Mark all notifications as read
- Data retention cleanup harian

### v2.0.0 (2026)
- Multi-user dengan role admin/pic
- WebSocket real-time
- AI Engine (Moving Avg + EWMA + Z-Score + Isolation Forest)
- Hysteresis untuk status sensor
- UDP beacon auto-discovery
- Rate limiting per IP
