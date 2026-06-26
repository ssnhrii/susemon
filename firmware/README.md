# SUSEMON — Firmware & Gateway v2.2

Firmware node sensor dan konfigurasi gateway untuk SUSEMON (PBL-TRPL412) — Politeknik Negeri Batam.

## Versi

| File | Versi | Hardware |
|---|---|---|
| `node_sensor.ino` | v2.5 | LILYGO T3 V1.6.1 (ESP32-PICO-D4 + SX1276) |
| `dragino_gateway_script.lua` | v1.0 | Dragino LG02 (Full Gateway) |

> ESP32 gateway (`gateway.ino`) sudah **dihapus** — digantikan sepenuhnya oleh Dragino LG02.
> Lihat `dragino_setup.md` untuk panduan setup lengkap.

---

## Node Sensor

### Hardware

| Komponen | Keterangan |
|---|---|
| LILYGO T3 V1.6.1 | ESP32-PICO-D4 + SX1276 + OLED built-in |
| DHT22 | Sensor suhu & kelembapan |
| LED Hijau | Status AMAN |
| LED Kuning | Status WASPADA |
| LED Merah | Status BERBAHAYA |
| LED Biru | Indikator TX LoRa |
| Buzzer | Alarm kondisi BERBAHAYA |

### Wiring T3 V1.6.1

```
DHT22 DATA  → GPIO 13
LED Hijau   → GPIO 2   (+ resistor 220Ω ke GND)
LED Kuning  → GPIO 4   (+ resistor 220Ω ke GND)
LED Merah   → GPIO 15  (+ resistor 220Ω ke GND)
LED Biru    → GPIO 25  (+ resistor 220Ω ke GND)
Buzzer +    → GPIO 14
OLED SDA    → GPIO 21  (built-in)
OLED SCL    → GPIO 22  (built-in)
LoRa RST    → GPIO 23  (built-in)
```

### Logika LED & Buzzer

| Status AI | LED | Buzzer |
|---|---|---|
| AMAN | Hijau ON | 1 beep pendek (saat kembali aman) |
| WASPADA | Kuning ON | 2 beep (saat masuk waspada) |
| BERBAHAYA | Merah ON | 3 beep panjang |
| TX LoRa | Biru kedip | - |
| Menunggu AI | Semua OFF | - |

---

## Gateway

> **Dragino LG02 digunakan sebagai full gateway** — tidak perlu ESP32 gateway terpisah.
> Lihat `dragino_setup.md` untuk panduan konfigurasi lengkap.

---

## Setup Arduino IDE

### 1. Tambah Board ESP32

File → Preferences → Additional Board Manager URLs:
```
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```
Tools → Board Manager → cari **esp32** → Install **esp32 by Espressif Systems**

### 2. Pilih Board

- Node Sensor: Tools → Board → **TTGO LoRa32-OLED** (atau ESP32 PICO-D4)
- Gateway: Tools → Board → **TTGO LoRa32-OLED**

Settings:
- Upload Speed: 921600
- CPU Frequency: 240MHz

### 3. Library (install via Library Manager)

| Library | Author | Untuk |
|---|---|---|
| LoRa | Sandeep Mistry | Keduanya |
| DHT sensor library | Adafruit | Node |
| Adafruit Unified Sensor | Adafruit | Node |
| Adafruit SSD1306 | Adafruit | Keduanya |
| Adafruit GFX Library | Adafruit | Keduanya |
| ArduinoJson | Benoit Blanchon | Keduanya |
| PubSubClient | Nick O'Leary | Gateway |
| WiFiManager | tzapu | Gateway |

### 4. Konfigurasi node_sensor.ino

```cpp
#define NODE_ID          "A1"    // A1 / B2 / C3 / D4
#define SEND_INTERVAL    5000    // interval kirim (ms)
#define DOWNLINK_TIMEOUT 60000   // timeout downlink (ms)
```

---

## Alur Data

```
DHT22 → Node Sensor (T3 V1.6.1)
           ↓ LoRa 923MHz SF7 (JSON + timestamp UTC)
         Gateway (T22_V1.1)
           ↓ WiFi → MQTT broker (topic: sensor/data)
         Backend FastAPI
           ↓ AI Analysis
           ↓ MQTT downlink (topic: sensor/ai_result)
         Gateway
           ↓ LoRa downlink
         Node Sensor → LED + Buzzer + OLED
           ↓ WebSocket
         Flutter App
```

## Format JSON Uplink (Node → Gateway → Backend)

```json
{
  "node_id": "A1",
  "temperature": 28.5,
  "humidity": 62.0,
  "timestamp": "2026-04-21T10:30:00Z",
  "rssi": -52
}
```

## Format JSON Downlink (Backend → Gateway → Node)

```json
{
  "node_id": "A1",
  "status": "AMAN",
  "risk": "LOW",
  "confidence": 91
}
```

## Changelog

### v2.1 (2026)
- MQTT credentials dari flash via WiFiManager (tidak hardcoded)
- Timestamp UTC ISO8601 dari NTP
- RSSI ditambahkan ke payload uplink
- Buffer JSON downlink diperbesar (192 bytes)
- RSSI downlink ditampilkan di OLED node sensor

### v2.0 (2026)
- Rilis awal dengan LoRa + MQTT + AI downlink
