# Panduan Implementasi Gateway Dragino LG02 — SUSEMON

## Info Perangkat
| Parameter | Nilai |
|---|---|
| Model | Dragino LG02 (HE) |
| IP Gateway | `10.130.1.1` |
| Firmware | LG02_LG08-5.1.1 |
| Frekuensi LoRa | 915 MHz |
| Sync Word | `0x12` (18 desimal) |

---

## Topologi Sistem

```
Internet
   │
   │ (WAN)
┌──▼─────────────────┐
│  Dragino LG02      │  IP: 10.130.1.1
│  LoRa Gateway      │
└──┬─────────────────┘
   │ (LAN — kabel Ethernet)
   │
┌──▼─────────────────┐
│  Laptop Server     │  IP: 10.130.1.206
│  Mosquitto :1883   │  (assigned oleh Dragino DHCP)
│  FastAPI Backend   │
└────────────────────┘
```

---

## Langkah 1: Persiapan Server (Laptop)

### 1.1 Jalankan SUSEMON
Klik dua kali atau jalankan:
```
start_susemon.bat
```
Pastikan Mosquitto dan Backend FastAPI sudah berjalan sebelum mengkonfigurasi Dragino.

### 1.2 Verifikasi Mosquitto berjalan
```cmd
netstat -an | findstr :1883
```
Hasilnya harus ada `0.0.0.0:1883 ... LISTENING`.

---

## Langkah 2: Konfigurasi Dragino LG02

Buka browser → akses **`http://10.130.1.1`**
- Username: `root`
- Password: `dragino`

### 2.1 Konfigurasi LoRa
Navigasi: **Service → LoRaWan GateWay**

**LoRaWAN Server Settings:**
| Parameter | Nilai |
|---|---|
| IoT Service | **`LoRaRAW forward to MQTT server`** |

**Radio Settings (Radio A & Radio B):**
| Parameter | Nilai |
|---|---|
| Frequency | `915000000` |
| Spreading Factor | `SF7` |
| Signal Bandwidth | `125 kHz` |
| Coding Rate | `4/5` |
| LoRa Sync Word | **`18`** (desimal dari `0x12`) |

Klik **Save & Apply**.

### 2.2 Konfigurasi MQTT (muncul setelah pilih IoT Service di atas)
Field MQTT langsung tersedia di halaman yang sama setelah memilih `LoRaRAW forward to MQTT server`:

| Parameter | Nilai |
|---|---|
| Select Server | **`General Server`** |
| Broker Address | `10.130.1.206` |
| Broker Port | `1883` |
| Uplink Topic | `sensor/data` |
| Downlink Topic | `sensor/ai_result` |
| Username | *(kosongkan)* |
| Password | *(kosongkan)* |

Klik **Save & Apply** dan tunggu restart modul (~30 detik).

---

## Langkah 3: Upload Firmware Node Sensor

Flash file `firmware/node_sensor/node_sensor.ino` ke LILYGO T3 V1.6.1 via Arduino IDE.

Verifikasi parameter firmware sudah sesuai:
```cpp
#define LORA_BAND  915E6           // ✅ 915 MHz — sama dengan Dragino
LoRa.setSpreadingFactor(7);        // ✅ SF7
LoRa.setSignalBandwidth(125E3);    // ✅ 125 kHz
LoRa.setCodingRate4(5);            // ✅ 4/5
LoRa.setSyncWord(0x12);            // ✅ = 18 desimal (RAW private)
```

---

## Langkah 4: Verifikasi Alur Data

Setelah semua berjalan, cek log Backend FastAPI. Saat node mengirim data, Anda akan melihat:

```
INFO: MQTT connected → subscribed 'sensor/data'
INFO: MQTT IN (Dragino Hex Decoded): {'node_id': 'TA11', 'temperature': 28.5, 'humidity': 62.0}
INFO: DB saved id=1: node=TA11 temp=28.5 hum=62.0
INFO: Downlink → TA11: AMAN | LOW | 91%
```

---

## Troubleshooting

### Dragino tidak bisa connect ke MQTT Broker
- Pastikan Laptop dan Dragino di jaringan yang sama
- Cek firewall Windows — port 1883 sudah dibuka:
  ```powershell
  # Jalankan sebagai Administrator (sudah dilakukan)
  netsh advfirewall firewall add rule name="Mosquitto MQTT" dir=in action=allow protocol=TCP localport=1883
  ```
- Jangan isi username/password di Dragino karena Mosquitto dikonfigurasi `allow_anonymous true`

### Node tidak terima downlink
- Pastikan **Sync Word sama**: node `0x12` = Dragino `18`
- Pastikan frekuensi sama: keduanya `915 MHz`
- Setelah TX, firmware otomatis masuk mode `LoRa.receive()` — ini sudah benar

### Data muncul sebagai hex tidak terdekode
- Backend secara otomatis decode hex payload dari Dragino
- Format Dragino: `{"data": "7b226e6f64655f6964..."}` → backend decode ke JSON normal

### Cek koneksi MQTT manual
Install MQTT Explorer atau pakai mosquitto_pub/sub:
```cmd
mosquitto_sub -h localhost -p 1883 -t "sensor/data" -v
```
Jika ada data masuk, akan tampil di terminal ini.

---

## Format Data

**Uplink (Node → Dragino → Server):**
Dragino meneruskan payload LoRa sebagai hex di field `data`:
```json
{"data": "7b226e6f64655f6964223a2254413131222c..."}
```
Backend decode otomatis → menjadi:
```json
{"node_id": "TA11", "temperature": 28.5, "humidity": 62.0}
```

**Downlink (Server → Dragino → Node):**
```json
{
  "node_id": "TA11",
  "status": "AMAN",
  "risk": "LOW",
  "confidence": 91,
  "data": "7b226e6f64655f6964..."
}
```
Field `data` (hex) dipakai Dragino untuk transmit balik ke node via LoRa.
