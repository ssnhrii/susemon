# Laporan PBL Terpadu - PBL-TRPL412
## Rancang Bangun Node Sensor Nirkabel Berbasis LoRa untuk Monitoring Anomali Suhu Ruang Server Menggunakan Analisis Data Berbasis AI

---

## Bagian 1: Identitas Tim & Proyek

| Kode PBL          | PBL-TRPL412                                                                 |
| ----------------- | --------------------------------------------------------------------------- |
| **Judul PBL**     | Rancang Bangun Node Sensor Nirkabel Berbasis LoRa untuk Monitoring Anomali Suhu Ruang Server Menggunakan Analisis Data Berbasis AI |
| **Nama Manpro**   | Iqbal Afif, A.Md.Kom                                                        |

### Anggota Tim PBL

| ID | NIM | Nama | Peran | Kontribusi Utama |
|----|------------------|--------------------------------|------------------|--------------------------------|
| 1 | 4342411084 | Chris Jericho Sembiring | Ketua + AI Analyst + FullStack | Integrasi Sistem, AI Model, Arsitektur |
| 2 | 4342411063 | Aulia Cahya Lamira | Anggota + Analyst Docs | Laporan Akhir, Dataset, Evaluasi |
| 3 | 4342411064 | Yetro Zifora Elkana Sitohang | Anggota + Frontend | Mobile App, UI Implementation, Video |
| 4 | 4342411086 | Ignasius Pandego Simbolon | Anggota + Desainer UI/UX | UI Design, Usability Test, Poster |
| 5 | 4342411087 | Dicky Dwi Hardana Putra | Anggota + IoT Engineer | LoRa, Sensor, Hardware Assembly |
| 6 | 4342411090 | Achmad Fathoni Najmil Arsya | Anggota + Backend | Gateway, API, Database, Security |

---

## Bagian 2: Daftar Lengkap Backlog (ID 1–32)

### Tahap Planning (ID 1–6)

| ID | Phase | Tanggal | % | Status | PIC |
|----|-----------|-----------------------|-----|--------|------|
| 1 | Planning | 23 Feb - 14 Mar 2026 | 100% | Done | Semua tim |
| 2 | Planning | 23 Feb - 28 Feb 2026 | 100% | Done | Aulia + Chris |
| 3 | Planning | 23 Feb - 28 Feb 2026 | 100% | Done | Achmad + Chris |
| 4 | Planning | 02 Mar - 07 Mar 2026 | 100% | Done | Aulia + Ignasius |
| 5 | Planning | 02 Mar - 07 Mar 2026 | 100% | Done | Chris |
| 6 | Planning | 02 Mar - 04 Mar 2026 | 100% | Done | Semua tim |

### Tahap Design (ID 7–11)

| ID | Phase | Tanggal | % | Status | PIC |
|----|--------|-----------------------|-----|--------|------|
| 7 | Design | 09 Mar - 14 Mar 2026 | 100% | Done | Chris |
| 8 | Design | 09 Mar - 14 Mar 2026 | 100% | Done | Achmad |
| 9 | Design | 09 Mar - 14 Mar 2026 | 100% | Done | Ignasius |
| 10 | Design | 09 Mar - 14 Mar 2026 | 100% | Done | Yetro |
| 11 | Design | 09 Mar - 14 Mar 2026 | 100% | Done | Achmad + Ignasius |

### Tahap Development, Testing, Review, Dokumentasi (ID 12–32)

| ID | Phase | Backlog | Detail Backlog | PIC | Tanggal | % | Status |
|----|--------------|-------------------------------|---------------------------------------------------|--------------------------------|-----------------------|-----|-----------|
| 12 | Development | Firmware Node Sensor | Program DHT22 dan transmisi LoRa | Dicky | 06 Apr - 11 Apr 2026 | 100% | Done |
| 13 | Development | Firmware Gateway | Program penerima LoRa dan forwarder MQTT | Achmad | 13 Apr - 18 Apr 2026 | 100% | Done |
| 14 | Development | UI Implementation | Implementasi desain ke Flutter | Ignasius | 13 Apr - 18 Apr 2026 | 100% | Done |
| 15 | Development | Backend Setup | Inisialisasi FastAPI dan Database | Achmad | 20 Apr - 25 Apr 2026 | 100% | Done |
| 16 | Development | MQTT Subscriber | Listener data sensor real-time | Achmad | 20 Apr - 25 Apr 2026 | 100% | Done |
| 17 | Development | Mobile Layouting | Halaman Dashboard dan Detail | Yetro | 18 May - 23 May 2026 | 100% | Done |
| 18 | Development | Mobile API Integration | Koneksi Flutter ke REST API | Yetro | 18 May - 23 May 2026 | 100% | Done |
| 19 | Development | Data Cleaning | Modul preprocessing data AI | Chris | 25 May - 30 May 2026 | 100% | Done |
| 20 | Development | AI Integration | Integrasi model ke pipeline data | Chris | 25 May - 30 May 2026 | 100% | Done |
| 21 | Development | WebSocket Service | Update data real-time tanpa refresh | Chris | 01 Jun - 06 Jun 2026 | 100% | Done |
| 22 | Testing | Dataset Preparation | Pengumpulan dan pelabelan data | Aulia + Chris | 01 Jun - 06 Jun 2026 | 100% | Done |
| 23 | Development | Training Model AI | Pelatihan algoritma Isolation Forest | Chris | 01 Jun - 06 Jun 2026 | 100% | Done |
| 24 | Testing | Uji Akurasi Sensor | Kalibrasi dengan standar ruang server | Dicky | 08 Jun - 13 Jun 2026 | 100% | Done |
| 25 | Testing | Uji Jarak LoRa | Range test indoor/outdoor | Dicky + Yetro | 08 Jun - 13 Jun 2026 | 100% | Done |
| 26 | Testing | Stress Test API | Uji beban request backend | Achmad | 15 Jun - 20 Jun 2026 | 100% | Done |
| 27 | Review | Uji Dashboard | Usability testing dan bug fixing | Ignasius + Yetro | 15 Jun - 20 Jun 2026 | 100% | Done |
| 28 | Development | Pasang Sensor | Perakitan casing dan instalasi fisik | Dicky | 22 Jun - 27 Jun 2026 | 50% | In Progress |
| 29 | Testing | Uji AI Final | Validasi deteksi anomali real-time | Chris | 22 Jun - 27 Jun 2026 | 100% | Done |
| 30 | Review | Evaluasi Sistem | Review performa sistem keseluruhan | Aulia + Ignasius | 22 Jun - 27 Jun 2026 | 0% | Backlog |
| 31 | Dokumentasi | Laporan Akhir | Penyusunan laporan teknis lengkap | Aulia | 29 Jun - 04 Jul 2026 | 20% | In Progress |
| 32 | Dokumentasi | Video & Poster | Media promosi dan HKI | Aulia + Ignasius + Yetro | 29 Jun - 04 Jul 2026 | 0% | Backlog |

---

## Bagian 3: Laporan Aktivitas Mandiri - Minggu ke-10

**Periode:** 25 – 31 Mei 2026

### 3.1 Pembagian Tugas Individu (Minggu ke-10)

| Nama | Modul/Fitur/Komponen | Target Mingguan |
|------|---------------------|-----------------|
| Chris Jericho Sembiring | Optimasi AI & WebSocket | Finalisasi deteksi anomali dan update real-time |
| Aulia Cahya Lamira | Dataset & Documentation | Pelabelan data final dan draf laporan teknis |
| Yetro Zifora Elkana Sitohang | Flutter Chart & Integration | Optimasi grafik suhu dan integrasi API detail |
| Ignasius Pandego Simbolon | UI Polish & Usability | Perbaikan aset visual dan draf video demo |
| Dicky Dwi Hardana Putra | Hardware Installation Prep | Kalibrasi akhir sensor dan persiapan casing |
| Achmad Fathoni Najmil Arsya | Backend Security | Implementasi JWT dan optimasi query MQTT |

---

## Bagian 4: Ringkasan Kontribusi per Anggota (Seluruh Proyek)

### Chris Jericho Sembiring (Ketua, AI Analyst, FullStack)
| ID | Tugas | Status |
|----|-------|--------|
| 12 | Arsitektur Sistem | Done |
| 19 | Data Cleaning | Done |
| 20 | AI Integration | Done |
| 21 | WebSocket Service | Done |
| 23 | Training Model AI | Done |
| 29 | Uji AI Final | Done |

### Aulia Cahya Lamira (Analyst Docs)
| ID | Tugas | Status |
|----|-------|--------|
| 2 | Analisis Kebutuhan | Done |
| 22 | Dataset Preparation | Done |
| 30 | Evaluasi Sistem | Backlog |
| 31 | Laporan Akhir | In Progress |
| 32 | Video & Poster | Backlog |

### Yetro Zifora Elkana Sitohang (Frontend)
| ID | Tugas | Status |
|----|-------|--------|
| 10 | UI High-Fidelity | Done |
| 17 | Mobile Layouting | Done |
| 18 | Mobile API Integration | Done |
| 25 | Uji Jarak LoRa | Done |
| 27 | Uji Dashboard | Done |
| 32 | Video & Poster | Backlog |

### Ignasius Pandego Simbolon (Desainer UI/UX)
| ID | Tugas | Status |
|----|-------|--------|
| 9 | UI Wireframing | Done |
| 14 | UI Implementation | Done |
| 27 | Uji Dashboard | Done |
| 30 | Evaluasi Sistem | Backlog |
| 32 | Video & Poster | Backlog |

### Dicky Dwi Hardana Putra (IoT Engineer)
| ID | Tugas | Status |
|----|-------|--------|
| 12 | Firmware Node Sensor | Done |
| 24 | Uji Akurasi Sensor | Done |
| 25 | Uji Jarak LoRa | Done |
| 28 | Pasang Sensor | In Progress |

### Achmad Fathoni Najmil Arsya (Backend)
| ID | Tugas | Status |
|----|-------|--------|
| 13 | Firmware Gateway | Done |
| 15 | Backend Setup | Done |
| 16 | MQTT Subscriber | Done |
| 26 | Stress Test API | Done |

---

## Bagian 5: Status Keseluruhan Proyek

| Status | Jumlah Tugas | Persentase |
|--------|---------------|-------------|
| Done | 29 tugas (ID 1–29) | 90.6% |
| In Progress | 2 tugas (ID 28, 31) | 6.3% |
| Backlog | 1 tugas (ID 30, 32*) | 3.1% |

**Target penyelesaian seluruh backlog:** 4 Juli 2026
**Laporan ini diperbarui pada:** 29 Mei 2026
