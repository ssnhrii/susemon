# Laporan Progress Mingguan - Minggu ke-8
**Periode:** 11 – 17 Mei 2026
**Proyek:** Rancang Bangun Node Sensor Nirkabel Berbasis LoRa untuk Monitoring Anomali Suhu Ruang Server Menggunakan Analisis Data Berbasis AI (SUSEMON)

---

## 1. Deskripsi Tugas & Target Mingguan (Minggu ke-8)

Fokus minggu ini adalah pada pengembangan modul core (AI & Backend) serta inisialisasi visualisasi pada aplikasi mobile.

| Nama | Deskripsi Tugas | Target Mingguan |
|------|-----------------|-----------------|
| **Chris Jericho Sembiring** | Riset algoritma Isolation Forest dan modul preprocessing data. | Modul Data Cleaning selesai 100%. |
| **Aulia Cahya Lamira** | Dokumentasi Aktivitas Tengah Semester (ATS) dan draf Manual Book. | Laporan ATS selesai 100%. |
| **Yetro Zifora Elkana Sitohang**| Layouting Dashboard Flutter dan implementasi library grafik. | Dashboard utama selesai 70%. |
| **Ignasius Pandego Simbolon** | Implementasi UI Design (Figma to Flutter) dan aset visual. | Aset ikon dan skema warna selesai. |
| **Dicky Dwi Hardana Putra** | Pengujian akurasi sensor DHT22 dan stabilitas transmisi LoRa. | Validasi sensor & uji jarak LoRa 100m. |
| **Achmad Fathoni Najmil Arsya**| Pengembangan MQTT Subscriber dan optimasi skema database. | MQTT listener FastAPI berjalan 100%. |

---

## 2. Progres Pengerjaan Anggota Tim

- **Chris (100%):** Berhasil menyelesaikan modul *Data Cleaning* dan inisialisasi algoritma *Isolation Forest* (scikit-learn). Skema integrasi antara AI dan pipeline MQTT telah siap untuk tahap berikutnya.
- **Aulia (100%):** Laporan ATS telah selesai disusun. Struktur Manual Book mulai dikerjakan (5%) dengan fokus pada alur instalasi backend.
- **Yetro (70%):** Halaman dashboard utama sudah memiliki layout yang fungsional dengan widget grafik (`fl_chart`) yang terintegrasi menggunakan data dummy untuk simulasi tren.
- **Ignasius (100%):** Seluruh aset visual (ikon sensor, skema warna *Dark Theme*) telah diintegrasikan ke dalam proyek Flutter. Draf video demo produk mulai disusun.
- **Dicky (100%):** Pengujian hardware menunjukkan hasil positif dengan error pembacaan DHT22 <0.5°C dan koneksi LoRa (SX1276) stabil pada jarak 100 meter di lingkungan *indoor*.
- **Achmad (100%):** Service MQTT listener pada backend FastAPI telah berfungsi menangkap data gateway secara real-time. Indexing database MySQL untuk performa query histori telah dioptimasi.

---

## 3. Progres Pemenuhan CPL Setiap Matakuliah

| Matakuliah | Progress Capaian Materi | Pemenuhan CPL |
|------------|-------------------------|---------------|
| **Kecerdasan Buatan** | Implementasi algoritma deteksi anomali menggunakan *Isolation Forest* dan statistik *Z-score* pada dataset suhu. | **CPL 1, 2, 3:** Mampu menerapkan algoritma Unsupervised Learning untuk mendeteksi anomali pada data *time-series*. |
| **Keamanan Perangkat Lunak** | *Authentication* menggunakan IP Address & Access Code, serta implementasi *Rate Limiting* pada API FastAPI. | **CPL 1, 2, 4:** Mampu merancang mekanisme proteksi endpoint API dari serangan *brute force* dan akses tidak sah. |
| **Kalkulus** | Analisis tren kenaikan suhu menggunakan konsep turunan/slope (Linear Regression) untuk prediksi overheating. | **CPL 1, 3:** Mampu melakukan pemodelan matematis untuk memprediksi perubahan status suhu server secara presisi. |
| **Bahasa Inggris Umum** | Penyusunan laporan teknis dan dokumentasi kode menggunakan istilah teknis IoT yang tepat dalam bahasa Inggris. | **CPL 2, 4:** Mampu berkomunikasi secara tertulis melalui laporan progres mingguan dengan standar bahasa yang baik. |
| **Pemrograman Perangkat Keras** | Integrasi Broker Mosquitto MQTT dengan FastAPI untuk memproses data sensor dari Gateway LoRa (ESP32). | **CPL 3, 4:** Mampu mengintegrasikan protokol IoT dengan backend modern secara sistematis dan reliabel. |
| **Pemeliharaan Perangkat Lunak** | Implementasi modul *daily cleanup* untuk retensi data sensor guna mencegah *database bloating*. | **CPL 1, 3:** Mampu merancang strategi pemeliharaan preventif pada sistem penyimpanan data berskala besar. |
| **Proyek Pengembangan Aplikasi IoT** | Integrasi arsitektur sistem IoT mulai dari akuisisi data sensor (LoRa), broker pesan (MQTT), hingga visualisasi dashboard pada aplikasi mobile. | **CPL 1, 3, 4:** Mampu membangun solusi IoT yang utuh dengan menerapkan standar pengembangan perangkat lunak dan koordinasi tim yang efektif. |

---

## 4. Rencana Pengerjaan Minggu Depan (Minggu ke-9)

Rencana kerja untuk periode berikutnya akan difokuskan pada integrasi sistem secara menyeluruh (End-to-End).

1. **Integrasi AI Real-time:** Menghubungkan modul AI ke pipeline MQTT untuk klasifikasi status (AMAN/WASPADA/BERBAHAYA) secara otomatis (Chris).
2. **Pengumpulan Dataset:** Memulai pengumpulan data suhu asli dari ruang server untuk proses tuning model AI (Aulia).
3. **Integrasi REST API:** Menghubungkan aplikasi Flutter dengan endpoint `/sensors/data` untuk pengambilan data historis (Yetro).
4. **Usability Testing:** Melakukan pengujian awal *user journey* pada prototipe mobile untuk memastikan kemudahan monitoring (Ignasius).
5. **Perakitan Fisik:** Finalisasi skema perkabelan dan pemasangan komponen ke dalam casing pelindung (Dicky).
6. **Pembuatan Endpoint AI:** Menyelesaikan seluruh endpoint REST yang dibutuhkan oleh aplikasi mobile (Achmad).
