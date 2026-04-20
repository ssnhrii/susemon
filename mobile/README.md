# 📱 SUSEMON Flutter App

Aplikasi mobile SUSEMON (Suhu dan Kelembapan Server Monitoring) menggunakan Flutter untuk monitoring real-time ruang server berbasis IoT dengan komunikasi LoRa.

## 🎯 Proyek

- **ID Proyek**: PBL-TRPL412
- **Institusi**: Politeknik Negeri Batam
- **Program Studi**: Teknologi Rekayasa Perangkat Lunak
- **Durasi**: 14 Minggu (1 Semester)

## 📱 Fitur Aplikasi

### 1. **Dashboard Real-time**
- Monitoring suhu dan kelembapan live
- Update otomatis setiap 5 detik
- Simulasi OLED display (Node Sensor & Gateway)

### 2. **Arsitektur Sistem**
- **Node Sensor**: TTGO LoRa32 + DHT22
  - Menampilkan suhu, kelembapan, status
  - LED indicators (Hijau/Kuning/Merah)
  - Info hardware lengkap
  
- **Gateway LoRa**: TTGO LoRa32
  - Menerima data dari node via LoRa
  - Parameter LoRa (Frekuensi, SF, Bandwidth, Tx Power)
  - Counter paket diterima
  - Status WiFi connection
  
- **Server Monitoring**: Laptop + Python
  - Analisis AI (Z-score + Moving Average)
  - Deteksi anomali
  - Confidence level 94%

### 3. **Status Monitoring**
- 🟢 **AMAN**: Kondisi normal
- 🟡 **WASPADA**: Indikasi perubahan tidak normal
- 🔴 **BERBAHAYA**: Anomali signifikan terdeteksi AI

## 🚀 Cara Menjalankan

### **Prasyarat:**
```bash
# Install Flutter SDK
# Download dari: https://flutter.dev/docs/get-started/install

# Verifikasi instalasi
flutter doctor
```

### **Run di Chrome (Web):**
```bash
cd susemon_flutter
flutter run -d chrome
```

### **Run di Android Emulator:**
```bash
# Pastikan Android emulator sudah running
flutter emulators --launch <emulator_id>
flutter run
```

### **Run di Android Device:**
```bash
# Hubungkan HP via USB dengan USB Debugging aktif
flutter devices
flutter run
```

### **Build APK (Android):**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### **Build untuk iOS:**
```bash
flutter build ios --release
# Memerlukan macOS dan Xcode
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

## 🎨 Teknologi

- **Framework**: Flutter 3.35.3
- **Language**: Dart 3.9.2
- **UI**: Material Design 3
- **State Management**: StatefulWidget
- **Real-time Update**: Timer (5 seconds interval)

## 📱 Platform Support

- ✅ **Android** (API 21+)
- ✅ **iOS** (iOS 12+)
- ✅ **Web** (Chrome, Firefox, Safari, Edge)
- ✅ **Windows** (Desktop)
- ✅ **macOS** (Desktop)
- ✅ **Linux** (Desktop)

## 🎯 Sesuai RPP

### **Komponen Hardware:**
- ✅ TTGO LoRa32 (Node & Gateway)
- ✅ Sensor DHT22
- ✅ OLED Display
- ✅ LED Indicators
- ✅ LoRa Communication

### **Metode AI:**
- ✅ Moving Average
- ✅ Z-score Analysis
- ✅ Multi-parameter (Suhu + Kelembapan)

### **Status Sistem:**
- ✅ Aman / Waspada / Berbahaya
- ✅ Deteksi anomali berbasis AI
- ✅ Real-time monitoring

## 📂 Struktur Project

```
susemon_flutter/
├── lib/
│   └── main.dart           # Main application code
├── android/                # Android specific files
├── ios/                    # iOS specific files
├── web/                    # Web specific files
├── windows/                # Windows specific files
├── macos/                  # macOS specific files
├── linux/                  # Linux specific files
├── pubspec.yaml            # Dependencies
└── README.md               # This file
```

## 🔧 Development

### **Hot Reload:**
Saat aplikasi running, tekan `r` untuk hot reload atau `R` untuk hot restart.

### **Debug Mode:**
```bash
flutter run --debug
```

### **Release Mode:**
```bash
flutter run --release
```

### **Profile Mode:**
```bash
flutter run --profile
```

## 📊 Fitur Real-time

- **Auto Update**: Data sensor update setiap 5 detik
- **Random Simulation**: Simulasi variasi suhu ±1°C dan kelembapan ±5%
- **Packet Counter**: Counter paket LoRa bertambah otomatis
- **LED Animation**: LED indicators berkedip sesuai status

## 🎨 UI/UX

- **Dark Theme**: Background gradient gelap (monitoring room style)
- **OLED Simulation**: Layar hitam dengan teks hijau (seperti hardware asli)
- **Glassmorphism**: Efek blur dan transparansi pada card
- **Responsive**: Otomatis menyesuaikan ukuran layar
- **Smooth Animation**: Transisi halus antar state

## 🔐 Security

- Aplikasi ini adalah prototype untuk pembelajaran
- Untuk production, tambahkan:
  - Authentication & Authorization
  - HTTPS/SSL untuk komunikasi
  - Data encryption
  - Input validation
  - Error handling yang robust

## 📝 Catatan

- Data saat ini adalah simulasi (random)
- Untuk integrasi dengan hardware real:
  - Tambahkan HTTP client untuk API
  - Implementasi MQTT untuk real-time data
  - Koneksi ke backend server

## 👥 Tim Proyek

**Manajer Proyek**: Iqbal Afif, A.Md.Kom  
**Pengusul**: Supardianto, S.ST.M.Eng  
**Mahasiswa**: TRPL 4C Malam (6 orang)

## 📄 Lisensi

Project ini dibuat untuk keperluan akademik PBL-TRPL412 Politeknik Negeri Batam.

## 🚀 Next Steps

1. ✅ Aplikasi Flutter dasar
2. ⏳ Integrasi dengan backend API
3. ⏳ Real-time data via MQTT
4. ⏳ Push notifications
5. ⏳ Historical data & charts
6. ⏳ User authentication
7. ⏳ Settings & configuration

---

**Dibuat dengan ❤️ menggunakan Flutter**
