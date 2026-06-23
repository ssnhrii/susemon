# Daftar Backlog & Task PBL-TRPL412 - SUSEMON
## Rancang Bangun Node Sensor Nirkabel Berbasis LoRa untuk Monitoring Anomali Suhu Ruang Server Menggunakan Analisis Data Berbasis AI

**Status Proyek:** Development Phase (Minggu 10)
**Update Terakhir:** 31 Mei 2026

---

### Progres Mingguan (Minggu 1 - 9)

#### Minggu 1 - 3: Planning Phase
*   **Minggu 1:** Brainstorming ide proyek monitoring server dan analisis kebutuhan hardware (LoRa, DHT22) serta software stack (FastAPI, Flutter).
*   **Minggu 2:** Studi literatur protokol LoRa dan riset algoritma *Isolation Forest*. Penyusunan proposal RPP dan rencana anggaran.
*   **Minggu 3:** Pembagian jobdesc tim (IoT, Backend, UI/UX, AI, Docs) dan finalisasi planning dengan Manajer Proyek.

#### Minggu 4 - 5: Design Phase
*   **Minggu 4:** Perancangan arsitektur sistem (Node-Gateway-Server-App) dan desain ERD Database (MySQL). Pembuatan wireframe lo-fi aplikasi mobile.
*   **Minggu 5:** Desain High-Fidelity (Mockup Figma) untuk dashboard dan detail sensor. Penentuan skema warna (Dark Mode) dan aset ikon visual.

#### Minggu 6 - 7: Core Development
*   **Minggu 6:** Pengembangan Firmware Node Sensor (Dicky) untuk pembacaan DHT22 dan transmisi LoRa. Firmware Gateway (Achmad) untuk bridge LoRa-to-MQTT.
*   **Minggu 7:** Implementasi UI Design ke Flutter widget (Ignasius). Inisialisasi Backend FastAPI dan konfigurasi database MySQL (Achmad).

#### Minggu 8: Backend & Hardware Integration
*   **Minggu 8:** 
    *   **Achmad:** Pengembangan MQTT Subscriber untuk menangkap data sensor real-time.
    *   **Chris:** Riset algoritma *Isolation Forest* dan modul *Data Cleaning*.
    *   **Yetro:** Layouting Dashboard Flutter dengan integrasi `fl_chart` (data dummy).
    *   **Dicky:** Pengujian akurasi sensor (error <0.5°C) dan stabilitas LoRa (jarak 100m).
    *   **Ignasius:** Integrasi aset visual dan skema warna ke proyek Flutter.

#### Minggu 9: Mobile & API Integration
*   **Minggu 9:** 
    *   **Yetro:** Integrasi REST API backend ke aplikasi Flutter (fetch data history).
    *   **Yetro:** Finalisasi layouting halaman detail sensor dan riwayat anomali.
    *   **Chris:** Finalisasi modul *Data Cleaning* dan mulai integrasi AI ke pipeline data.
    *   **Achmad:** Pembuatan endpoint REST untuk konsumsi data mobile.

---

### Status Task Berdasarkan ID (Hingga Minggu 9)

| ID | Task | PIC | Status |
|----|------|-----|--------|
| 1-6| Tahap Planning | Semua Tim | Done |
| 7-11| Tahap Design | Semua Tim | Done |
| 12 | Firmware Node Sensor | Dicky | Done |
| 13 | Firmware Gateway | Achmad | Done |
| 14 | UI Implementation | Ignasius | Done |
| 15 | Backend Setup | Achmad | Done |
| 16 | MQTT Subscriber | Achmad | Done |
| 17 | Mobile Layouting | Yetro | Done |
| 18 | Mobile API Integration| Yetro | Done |
| 19 | Data Cleaning Service | Chris | Done |

---

### Rencana Minggu 10 (Sedang Berjalan)
*   **ID 20:** Integrasi AI (Isolation Forest) ke pipeline data real-time (Chris).
*   **ID 21:** Implementasi WebSocket untuk update dashboard instan (Chris).
*   **ID 28:** Persiapan pemasangan fisik node sensor di ruang server (Dicky).
*   **ID 31:** Penyusunan draf Laporan Akhir (Aulia).
