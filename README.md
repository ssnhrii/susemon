# SUSEMON — Suhu dan Kelembapan Server Monitoring

> Nomor ID: PBL-TRPL412
> Manajer Proyek: Iqbal Afif, A.Md.Kom
> Pengusul/Klien: Supardianto
> Waktu: 14 Minggu (1 Semester)

<invoke name="SUSEMON">adalah solusi monitoring lingkungan ruang server berbasis IoT yang memantau suhu dan kelembapan secara real-time menggunakan node sensor nirkabel dengan komunikasi LoRa.</invoke>

---

## Arsitektur Sistem

```
Node Sensor (TTGO LoRa32 + DHT22)
        │  LoRa
        ▼
Gateway (TTGO LoRa32)
        │  MQTT over WiFi
        ▼
Server Monitoring (FastAPI + MySQL + AI)
        │  REST API
        ▼
Flutter Mobile App
```

Tiga komponen utama sesuai desain produk:

| Komponen | Hardware | Fungsi |
|---|---|---|
| Node Sensor | TTGO LoRa32 + DHT22 + OLED | Baca suhu & kelembapan, kirim via LoRa |
| Gateway LoRa | TTGO LoRa32 + OLED | Terima data LoRa, teruskan ke server via MQTT/WiFi |
| Server Monitoring | Laptop + FastAPI + MySQL | Preprocessing, AI anomaly detection, API, dashboard |

---

## Status Kondisi

Penentuan status berdasarkan analisis kombinasi suhu dan kelembapan menggunakan AI, bukan hanya threshold tetap:

| Status | Indikator | Warna |
|---|---|---|
| Aman | Suhu dan kelembapan dalam batas normal | Hijau |
| Waspada | Indikasi perubahan tidak normal pada salah satu/kedua parameter | Kuning |
| Berbahaya | Anomali signifikan terdeteksi oleh AI | Merah |

---

## Stack Teknologi

| Layer | Teknologi |
|---|---|
| Backend | Python 3.8+ · FastAPI · paho-mqtt |
| Database | MySQL |
| AI | scikit-learn (Isolation Forest + threshold) |
| Frontend | Flutter · Riverpod · fl_chart |
| Hardware Node | TTGO LoRa32 · DHT22 · OLED Display · Arduino IDE |
| Hardware Gateway | TTGO LoRa32 · OLED Display · Router WiFi |
| Protokol IoT | LoRa (node → gateway) · MQTT topic `sensor/data` (gateway → server) |

---

## Struktur Proyek (Software)

```
├── backend/
│   ├── app/
│   │   ├── core/
│   │   │   ├── config.py           # Konfigurasi env
│   │   │   └── logging_config.py   # Setup logging
│   │   ├── models/
│   │   │   ├── database.py         # MySQL pool + init tabel
│   │   │   └── schemas.py          # Pydantic models
│   │   ├── routers/
│   │   │   └── sensor.py           # API endpoints
│   │   └── services/
│   │       ├── ai_service.py       # Threshold + Isolation Forest
│   │       ├── mqtt_service.py     # MQTT subscriber + reconnect
│   │       └── sensor_service.py   # DB operations
│   ├── main.py                     # FastAPI app entry point
│   ├── simulate_sensor.py          # Simulator node sensor untuk testing
│   ├── requirements.txt
│   └── .env.example
│
└── mobile/
    └── lib/
        ├── models/sensor_model.dart
        ├── services/api_service.dart
        ├── providers/sensor_provider.dart
        ├── widgets/sensor_card.dart
        └── screens/
            ├── dashboard_screen.dart     # Status global + list node
            ├── detail_screen.dart        # Grafik suhu + histori
            ├── analysis_screen.dart      # AI status + bar chart
            └── notifications_screen.dart # List anomali by severity
```

---

## Format Data MQTT

Topic: `sensor/data`

```json
{
  "node_id": "A1",
  "temperature": 27.5,
  "humidity": 65.0,
  "timestamp": "2024-01-15T10:30:00+00:00"
}
```

---

## API Endpoints

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/sensor/latest` | Data terbaru per node (sorted by severity) |
| GET | `/sensor/history` | Histori data dengan filter waktu |
| GET | `/sensor/anomaly` | Daftar anomali terdeteksi |
| POST | `/sensor/retrain` | Trigger retrain Isolation Forest |

**GET /sensor/history** — query params:
```
node_id     string    required
limit       int       optional  default 100, max 1000
start_time  datetime  optional  ISO 8601
end_time    datetime  optional  ISO 8601
```

Contoh response `/sensor/latest`:
```json
[
  {
    "node_id": "A1",
    "temperature": 32.5,
    "humidity": 68.0,
    "timestamp": "2024-01-15T10:30:00",
    "is_anomaly": true,
    "anomaly_score": 0.712,
    "status": "critical"
  }
]
```

---

## AI Anomaly Detection

Dua tahap sesuai desain sistem:

**Tahap 1 — Threshold (selalu aktif)**
| Kondisi | Status |
|---|---|
| Suhu ≥ 30°C | Berbahaya |
| Suhu ≥ 28°C | Waspada |
| Kelembapan ≥ 70% | Waspada |

**Tahap 2 — Isolation Forest (aktif setelah ≥ 50 data)**
- Training otomatis saat startup dari data historis
- Retrain manual via `POST /sensor/retrain`
- Mendeteksi pola kenaikan suhu dan perubahan kelembapan yang tidak normal
- Output: `is_anomaly` + `anomaly_score` (0.0 – 1.0)
- Fallback ke threshold jika data belum cukup

---

## Instalasi & Menjalankan

### Prasyarat

- Python 3.8+
- MySQL 8.0+
- MQTT Broker (Mosquitto)
- Flutter 3.19+
- Arduino IDE (untuk firmware node & gateway)

### 1. Setup MySQL

```sql
CREATE DATABASE iot_monitoring CHARACTER SET utf8mb4;
```

Tabel dibuat otomatis saat backend pertama kali dijalankan.

### 2. Backend

```bash
cd backend
cp .env.example .env   # isi DB_PASSWORD dan sesuaikan konfigurasi
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### 3. Simulator Sensor (untuk testing tanpa hardware)

```bash
cd backend
python simulate_sensor.py
```

Simulator mengirim data dari 4 node (A1, A2, B1, B2) setiap 2 detik dengan 10% chance spike anomali.

### 4. Flutter App

```bash
cd mobile
flutter pub get
flutter run
```

> Untuk device fisik, ubah `baseUrl` di `lib/services/api_service.dart` dari `10.0.2.2` ke IP server.

---

## Konfigurasi (.env)

```env
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=iot_monitoring

# MQTT
MQTT_BROKER=localhost
MQTT_PORT=1883
MQTT_TOPIC=sensor/data
MQTT_CLIENT_ID=fastapi-backend

# Threshold AI
TEMP_WARNING=28.0
TEMP_CRITICAL=30.0
HUMIDITY_WARNING=70.0

# Isolation Forest
IF_CONTAMINATION=0.05
IF_MIN_SAMPLES=50
```

---

## Skema Database

```sql
CREATE TABLE sensor_data (
    id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    node_id       VARCHAR(64)  NOT NULL,
    temperature   FLOAT        NOT NULL,
    humidity      FLOAT        NOT NULL,
    timestamp     DATETIME(3)  NOT NULL,
    is_anomaly    TINYINT(1)   NOT NULL DEFAULT 0,
    anomaly_score FLOAT        NULL,
    INDEX idx_timestamp (timestamp),
    INDEX idx_node_id   (node_id),
    INDEX idx_node_time (node_id, timestamp)
);
```

---

## Komponen Hardware

| Komponen | Jumlah | Fungsi |
|---|---|---|
| TTGO LoRa32 (Node) | 1 | Node sensor — baca DHT22, kirim via LoRa |
| TTGO LoRa32 (Gateway) | 1 | Gateway — terima LoRa, kirim MQTT via WiFi |
| Sensor DHT22 | 1 | Membaca suhu dan kelembapan |
| OLED Display | 2 | Tampilkan data real-time di node & gateway |
| Antena LoRa | 1 | Komunikasi jarak jauh antar perangkat |
| Buzzer | 1 | Notifikasi suara saat kondisi waspada/bahaya |
| LED (Merah, Kuning, Hijau) | 1 set | Indikator kondisi visual |
| Breadboard | 1 | Merangkai komponen node sensor |
| Kabel Jumper | ±15 pcs | Menghubungkan komponen |
| Power Supply/Powerbank | 2 | Sumber daya perangkat |
| Router | 1 | Koneksi internet untuk gateway |

Total estimasi biaya hardware: **Rp1.276.000**

---

## Fitur Flutter App

| Halaman | Fitur |
|---|---|
| Dashboard | Status global (AMAN/WASPADA/BERBAHAYA), jumlah sensor bermasalah, list node real-time |
| Detail Node | Grafik suhu + garis threshold, histori data, ringkasan AI |
| Analisis | Status AI per node, bar chart suhu semua node, statistik anomali |
| Notifikasi | List anomali diurutkan by severity, tap → buka detail node |

- Auto-refresh setiap 3 detik (data sensor) dan 5 detik (anomali)
- Warna status: hijau (aman) · kuning (waspada) · merah (berbahaya)
- Badge notifikasi menampilkan jumlah anomali aktif

---

## Tim Proyek

| No | Nama | NIK/NIM | Program Studi |
|---|---|---|---|
| 1 | Iqbal Afif, A.Md.Kom | 222332 | Teknik Informatika |
| 2 | Supardianto, S.ST.M.Eng | 113105 | Teknologi Rekayasa Perangkat Lunak |
| 3 | Feby, M.Pd | 122270 | Animasi |
| 4 | Ghufron Ramadhan, A.Md.T | 223343 | Teknologi Geomatika |
| 5 | Gilang Bagus Ramadhan, A.Md.Kom | 222331 | Teknik Informatika |
| 6 | Kevin Riady, A.Md.Kom | 225362 | Teknik Informatika |
| 7 | Sukma Evadini, S.T., M.Kom | 125360 | Teknologi Rekayasa Perangkat Lunak |
| 8 | Hajrul Khaira, S.Tr.Kom | 220315 | Rekayasa Keamanan Siber |
| 9 | Chris Jericho Sembiring | 4342411084 | Teknologi Rekayasa Perangkat Lunak |
| 10 | Aulia Cahya Lamira | 4342411063 | Teknologi Rekayasa Perangkat Lunak |
| 11 | Yetro Zifora Elkana Sitohang | 4342411064 | Teknologi Rekayasa Perangkat Lunak |
| 12 | Ignasius Pandego Simbolon | 4342411086 | Teknologi Rekayasa Perangkat Lunak |
| 13 | Dicky Dwi Hardana Putra | 4342411087 | Teknologi Rekayasa Perangkat Lunak |
| 14 | Achmad Fathoni Najmil Arsya | 4342411090 | Teknologi Rekayasa Perangkat Lunak |

---

## Estimasi Waktu Pengerjaan

| Fase | Estimasi | Uraian |
|---|---|---|
| Planning | 3 minggu | Diskusi awal, analisis kebutuhan, penyusunan RPP |
| Design | 2 minggu | Arsitektur sistem, ERD, wireframe, alur AI, endpoint API |
| Development | 6 minggu | Hardware IoT, backend, AI, dashboard, integrasi |
| Testing | 2 minggu | Uji sensor, LoRa, deteksi anomali, integrasi sistem |
| Review | 1 minggu | Evaluasi kinerja sistem, perbaikan akhir |
| Total | 14 minggu | 1 Semester |

---

## Luaran Proyek

1. Aplikasi (backend + mobile)
2. Laporan Akhir
3. Manual Book
4. Video Demo Aplikasi
5. Poster
6. Dokumen Pengajuan HKI

---

> Proyek PBL-TRPL412 — Politeknik Negeri Batam
> Mahasiswa TRPL 4C Malam
