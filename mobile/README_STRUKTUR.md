# 📁 SUSEMON - Struktur Aplikasi

## 🎯 Alur Aplikasi
```
Splash Screen (3 detik)
    ↓
Onboarding (3 halaman)
    ↓
Login (IP + Kode)
    ↓
Dashboard Layout
    ├── Header (Logo, Title, Live Status, Notifikasi, Settings)
    ├── Navbar (Dashboard, Analisis AI, History)
    └── Main Content (Konten halaman)
```

## 📂 Struktur Folder

```
lib/
├── main.dart                          # Entry point aplikasi
│
├── core/                              # Core utilities & constants
│   ├── constants/
│   │   ├── app_colors.dart           # Warna aplikasi (dark theme)
│   │   └── app_sizes.dart            # Ukuran & spacing konsisten
│   └── theme/
│       └── app_theme.dart            # Theme configuration
│
├── shared/                            # Shared widgets
│   └── widgets/
│       ├── app_header.dart           # Header konsisten (Logo, Notif, Settings)
│       └── app_navbar.dart           # Navbar konsisten (3 menu)
│
└── features/                          # Feature modules
    ├── splash/
    │   └── splash_screen.dart        # Splash screen dengan animasi
    │
    ├── onboarding/
    │   └── onboarding_screen.dart    # Onboarding 3 halaman
    │
    ├── auth/
    │   └── login_screen.dart         # Login dengan IP + Kode
    │
    └── dashboard/
        ├── main_layout.dart          # Layout utama (Header + Navbar + Content)
        ├── pages/
        │   ├── dashboard_page.dart   # Dashboard dengan grafik real-time
        │   ├── analisis_page.dart    # Analisis AI
        │   ├── history_page_new.dart # History data
        │   ├── notifikasi_page_new.dart # Notifikasi (modal)
        │   └── settings_page_new.dart   # Settings (modal)
        └── widgets/
            └── (widget khusus dashboard)
```

## 🎨 Konsistensi Layout

### Header (Semua Halaman)
```
┌─────────────────────────────────────────────────────────┐
│ [Logo] SUSEMON                    [LIVE] [🔔3] [⚙️]    │
│        Subtitle                                          │
└─────────────────────────────────────────────────────────┘
```

### Navbar (3 Menu Utama)
```
┌─────────────────────────────────────────────────────────┐
│ [📊 Dashboard] [🧠 Analisis AI] [📜 History]           │
└─────────────────────────────────────────────────────────┘
```

### Main Content
```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  [Konten halaman dengan padding konsisten]              │
│                                                          │
│  - Cards dengan border radius 24px                      │
│  - Background: transparent (gradient shows through)     │
│  - Spacing: 24px antar elemen                           │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 🎨 Design System

### Colors (AppColors)
```dart
// Background
darkGradient: #0F2027 → #203A43 → #2C5364

// Primary
primary: #64B5F6 (Cyan)
secondary: #1F6E8A (Teal)

// Status
success: #4CAF50 (Hijau - AMAN)
warning: #E67E22 (Orange - WASPADA)
danger: #E53E3E (Merah - BERBAHAYA)

// Text
textPrimary: White (100%)
textSecondary: White (70%)
textTertiary: White (50%)

// Cards
bgCard: White (8%)
cardBorder: White (15%)
```

### Sizes (AppSizes)
```dart
// Padding
paddingXS: 8px
paddingS: 12px
paddingM: 16px
paddingL: 24px
paddingXL: 32px

// Border Radius
radiusS: 12px
radiusM: 16px
radiusL: 24px
radiusXL: 32px

// Icons
iconS: 20px
iconM: 24px
iconL: 32px
iconXL: 48px

// Fonts
fontXS: 11px
fontS: 13px
fontM: 15px
fontL: 18px
fontXL: 24px
fontXXL: 32px

// Layout
headerHeight: 70px
navbarHeight: 60px
maxContentWidth: 1400px
```

## 📊 Fitur Dashboard

### 1. Dashboard Page
- ✅ 4 Stat Cards (Suhu, Kelembapan, Status, Node Aktif)
- ✅ 2 Grafik Real-time (Suhu & Kelembapan)
- ✅ 4 Node Sensor Status
- ✅ Update otomatis setiap 3 detik

### 2. Analisis AI Page
- 🔄 Coming Soon
- AI Detection cards
- Prediksi anomali
- Rekomendasi

### 3. History Page
- 🔄 Coming Soon
- Grafik tren 7 hari
- Data table
- Filter periode

### 4. Notifikasi (Modal)
- 🔄 Coming Soon
- List notifikasi
- Badge counter di header

### 5. Settings (Modal)
- 🔄 Coming Soon
- Threshold settings
- Notifikasi preferences
- Node management

## 🚀 Cara Menjalankan

```bash
# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run on Android
flutter run -d android

# Build for web
flutter build web
```

## 📝 Naming Convention

### Files
- `snake_case.dart` untuk semua file
- `_screen.dart` untuk halaman utama
- `_page.dart` untuk sub-halaman
- `_widget.dart` untuk widget reusable

### Classes
- `PascalCase` untuk class names
- `camelCase` untuk variables & functions
- `SCREAMING_SNAKE_CASE` untuk constants

### Folders
- `lowercase` untuk folder names
- Organize by feature, bukan by type

## ✅ Checklist Konsistensi

- [x] Splash screen dengan animasi
- [x] Onboarding 3 halaman
- [x] Login dengan IP + Kode
- [x] Header konsisten di semua halaman
- [x] Navbar konsisten (3 menu)
- [x] Dark theme gradient background
- [x] Cards dengan style konsisten
- [x] Notifikasi & Settings di header kanan
- [x] Grafik suhu & kelembapan real-time
- [x] Status colors (Aman, Waspada, Berbahaya)
- [x] Responsive layout
- [x] Font Orbitron untuk judul
- [x] Font Inter untuk body text
- [x] Font Roboto Mono untuk angka

## 🎯 Next Steps

1. ✅ Implementasi Analisis AI page dengan grafik prediksi
2. ✅ Implementasi History page dengan data table
3. ✅ Implementasi Notifikasi page dengan real-time updates
4. ✅ Implementasi Settings page dengan form
5. ✅ Integrasi dengan backend API
6. ✅ Testing & bug fixes

---

**Status**: ✅ Struktur dasar selesai, siap untuk development lanjutan
**Version**: 1.0.0
**Last Update**: 18 April 2026
