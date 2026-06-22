# 📘 Panduan Hubungan Gateway Dragino LG02 & Sistem SUSEMON

Panduan ini menjelaskan cara menghubungkan gateway **Dragino LG02** dengan sistem pemantauan **SUSEMON** (Backend FastAPI & MQTT Broker).

---

## 🌐 1. Topologi Jaringan & Alur Hubungan

Pastikan Laptop Server dan Dragino LG02 berada di satu jaringan lokal (Wi-Fi/LAN) yang sama.

```
┌─────────────────┐       LoRa (Radio)       ┌──────────────────┐
│  Node Sensor    │ ───────────────────────▶ │  Dragino LG02    │
│  (LILYGO T3)    │ ◀─────────────────────── │  LoRa Gateway    │
└─────────────────┘                          └──────────────────┘
                                                       │
                                                       │ MQTT (TCP/IP)
                                                       ▼
                                             ┌──────────────────┐
                                             │  Laptop Server   │
                                             │  (Mosquitto +    │
                                             │   Backend API)   │
                                             └──────────────────┘
```

> [!IMPORTANT]
> Catat **IP Address Laptop Server** Anda (misalnya: `192.168.1.100` atau `10.130.1.206`). IP ini akan digunakan sebagai alamat **MQTT Broker** pada pengaturan Dragino.

---

## 🔧 2. Konfigurasi Gateway Dragino LG02

### A. Pengaturan LoRa (Custom/Raw)
1. Buka browser dan akses Web Admin Dragino di **`http://10.130.1.1`** (IP default Dragino).
   * **Username**: `root`
   * **Password**: `dragino`
2. Navigasi ke menu **Service** -> **LoRaWan GateWay**.
3. Atur parameter berikut pada **LoRaWAN Server Settings**:
   * **IoT Service**: Pilih **`LoRaWanRAW forwarder`** (bukan LoRaWAN/semtech).
4. Atur parameter berikut pada **Radio Settings (Radio A & B)**:
   * **Frequency**: `923000000` (923 MHz - AS923)
   * **Spreading Factor (SF)**: `SF7`
   * **Signal Bandwidth**: `125 kHz`
   * **Coding Rate**: `4/5`
   * **LoRa Sync Word**: **`18`** *(Sangat penting! Wajib diubah dari default `52` agar gateway dapat membaca paket RAW point-to-point)*.
5. Klik **Save & Apply** di bagian bawah halaman.

### B. Pengaturan MQTT
1. Navigasi ke menu **Service** -> **MQTT**.
2. Masukkan konfigurasi server broker:
   * **Select Server**: `General Server`
   * **Broker Address**: *Isi dengan IP Laptop Server Anda* (contoh: `10.130.1.206` atau `192.168.1.100`)
   * **Broker Port**: `1883`
   * *Kosongkan username dan password jika tidak diset pada broker*.
3. Pada tabel **MQTT Channel**, klik **Add** lalu tambahkan dua topik berikut:

| Nama Channel (Lokal) | Remote Channel (Topik MQTT) | Keterangan |
| :--- | :--- | :--- |
| **uplink** | `sensor/data` | Mengirim data mentah sensor ke server |
| **downlink** | `sensor/ai_result` | Menerima status keputusan AI dari server |

4. Klik **Save & Apply** dan tunggu hingga gateway melakukan restart modul.

---

## 💻 3. Sisi Server (Backend FastAPI)

Kami telah menerapkan logika integrasi penuh pada backend di file [mqtt_listener.py](file:///C:/laragon/www/susemon/backend/app/services/mqtt_listener.py):

*   **Proses Uplink (JSON dari Dragino)**:
    Data sensor yang ditangkap LoRa dikirim Dragino ke broker dengan payload:
    `{"data": "hex_representation_of_sensor_json"}`.
    Backend secara otomatis mendeteksi field `data`, mendekode *hex* menjadi string JSON (`{"node_id":"A1","temperature":28.5,...}`), lalu memprosesnya melalui model AI.
    
*   **Proses Downlink (Keputusan AI ke Node)**:
    Hasil analisis AI (`AMAN`, `WASPADA`, `BERBAHAYA`) dikirim balik ke topik `sensor/ai_result`.
    Backend secara otomatis membungkus status tersebut ke format *hex* di dalam field `data` agar gateway Dragino bisa memancarkannya kembali ke Node Sensor melalui gelombang radio LoRa.

---

## 🧪 4. Cara Pengujian Hubungan

1. **Jalankan Layanan Server**:
   Jalankan file [start_susemon.bat](file:///C:/laragon/www/susemon/start_susemon.bat) di laptop Anda. Ini akan otomatis mengaktifkan **Mosquitto MQTT Broker**, **Backend FastAPI**, dan **Aplikasi Flutter mobile**.
2. **Lihat Log Backend**:
   Saat Node Sensor mengirim data LoRa, Anda akan melihat log di konsol Backend FastAPI:
   ```bash
   INFO: MQTT IN (Dragino Hex Decoded): {'node_id': 'A1', 'temperature': 28.5, 'humidity': 62.0}
   INFO: Downlink → A1: AMAN | LOW | 91%
   ```
3. **Pantau Layar Node**:
   Node sensor (LILYGO T3) akan menerima downlink, menampilkan status `"AMAN"`, `"WASPADA"`, atau `"BERBAHAYA"`, dan menyalakan indikator LED yang sesuai tanpa adanya status jeda (*paused*).
