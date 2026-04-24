# SUSEMON — Arduino IDE Programs

Firmware untuk hardware IoT SUSEMON (PBL-TRPL412).

## Struktur

```
Arduino-IDE/
├── node_sensor/node_sensor.ino   ← TTGO LoRa32 + DHT22 + LED + Buzzer
└── gateway/gateway.ino           ← TTGO LoRa32 + OLED only
```

---

## Node Sensor

### Hardware

| Komponen | Keterangan |
|---|---|
| TTGO LoRa32 V2.1 | ESP32 + SX1276 + OLED built-in |
| DHT22 | Sensor suhu & kelembapan |
| LED Hijau | Status AMAN |
| LED Kuning | Status WASPADA |
| LED Merah | Status BERBAHAYA |
| LED Biru | Indikator kirim LoRa |
| Buzzer | Alarm kondisi BERBAHAYA |

### Wiring

```
DHT22 VCC   → 3.3V
DHT22 GND   → GND
DHT22 DATA  → GPIO 13

LED Hijau   → GPIO 2   (+ resistor 220Ω ke GND)
LED Kuning  → GPIO 4   (+ resistor 220Ω ke GND)
LED Merah   → GPIO 12  (+ resistor 220Ω ke GND)
LED Biru    → GPIO 15  (+ resistor 220Ω ke GND)

Buzzer +    → GPIO 32
Buzzer -    → GND

OLED & LoRa → built-in TTGO LoRa32
```

### Logika LED & Buzzer

| Kondisi | LED | Buzzer |
|---|---|---|
| Suhu < 35°C & Hum < 70% | Hijau ON | Diam |
| Suhu 35–40°C atau Hum ≥ 70% | Kuning ON | 2 beep pendek (saat masuk) |
| Suhu ≥ 40°C atau Hum ≥ 80% | Merah ON | 3 beep panjang (setiap interval) |
| Kirim LoRa | Biru kedip | - |
| Error startup | Semua OFF | 1 beep panjang |

---

## Gateway

### Hardware

| Komponen | Keterangan |
|---|---|
| TTGO LoRa32 V2.1 | ESP32 + SX1276 + OLED built-in |
| WiFi | Built-in ESP32 |

### Wiring

```
Semua built-in — tidak ada wiring tambahan
```

### OLED Gateway menampilkan

```
SUSEMON  Gateway
─────────────────
WiFi:OK  MQTT:OK
Node: A1   RSSI:-52
T:28.5C  H:62.0%
RX:47   TX:47
Lost:0   923MHz SF7
```

---

## Setup Arduino IDE

### 1. Tambah Board ESP32

File → Preferences → Additional Board Manager URLs:
```
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```
Tools → Board Manager → cari **esp32** → Install **esp32 by Espressif Systems**

### 2. Pilih Board

Tools → Board → ESP32 Arduino → **TTGO LoRa32-OLED**

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

### 4. Konfigurasi node_sensor.ino

```cpp
#define NODE_ID       "A1"   // A1 / B2 / C3 / D4
#define SEND_INTERVAL 5000   // interval kirim ms
#define TEMP_WARNING  35.0   // threshold waspada
#define TEMP_DANGER   40.0   // threshold berbahaya
```

### 5. Konfigurasi gateway.ino

```cpp
#define WIFI_SSID     "NamaWiFi"
#define WIFI_PASSWORD "PasswordWiFi"
#define MQTT_SERVER   "192.168.1.100"  // IP server backend
#define MQTT_PORT     1883
#define MQTT_TOPIC    "sensor/data"
```

---

## Alur Data

```
DHT22 → Node Sensor
          ↓ LoRa 923MHz (JSON)
        Gateway
          ↓ WiFi → MQTT broker
        Backend FastAPI
          ↓ WebSocket
        Flutter App
```

## Format JSON MQTT

```json
{
  "node_id": "A1",
  "temperature": 28.5,
  "humidity": 62.0,
  "timestamp": "2026-04-21T10:30:00+07:00"
}
```
