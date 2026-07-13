# MEKAAR 3.0: Aplikasi Chat & Keamanan Personal Modern

MEKAAR 3.0 adalah aplikasi obrolan modern yang dirancang khusus untuk segmen remaja/youth dengan mengutamakan aspek estetika breathable, interaksi dinamis, serta sistem perlindungan keamanan berlapis yang sepenuhnya dikendalikan oleh pengguna.

Aplikasi ini memadukan obrolan pribadi sehari-hari yang seru dengan protokol darurat terpadu (SOS) bersama orang tua/wali tepercaya (Guardian).

---

## 🌟 Fitur Utama

### 💬 1. Obrolan Sehari-hari (Standard Chat Layer)
* **Visual Premium & Breathable**: Antarmuka responsif dengan skema warna kurasi (Coral, Teal, Dark Mode).
* **View-Once Media**: Kirim media gambar sekali lihat yang langsung dikaburkan (*blurry*) setelah dibuka untuk melindungi privasi.
* **Hapus Pesan Penuh**: Kebebasan menghapus pesan obrolan biasa secara permanen dari basis data lokal maupun remote.

### 🛡️ 2. Sistem Saling Menjaga (Guardian & Swap System)
* **Izin Terkontrol**: Guardian tidak bisa melacak atau mendengar audio Anda saat mode normal. Akses pelacakan GPS dan mikrofon hanya terbuka **jika dan hanya jika** Anda menekan tombol SOS dalam bahaya.
* **Durasi Otorisasi Terbatas**: Hubungan Guardian aktif maksimal selama 30 hari demi menjaga relevansi lingkaran kepercayaan.
* **Dynamic Role Swapping**: Tukar peran instan (misal, Anak menjadi Wali bagi Ibunya) secara fleksibel dengan persetujuan dua arah.

### 🚨 3. Protokol Darurat Terpadu (SOS Mode)
* **Breathing Panic Button**: Tombol darurat dengan efek pulsasi visual agresif dan getaran (*haptic feedback*) berat.
* **Real-time GPS Pings**: Pembaruan koordinat posisi Anda setiap saat ke Supabase dan dipetakan di OpenStreetMap (OSM) interaktif.
* **Audio & Video WebRTC Streaming**: Kirim streaming umpan kamera dan mikrofon langsung ke layar wali Anda secara real-time.
* **Inactivity Watchdog**: Streaming video akan otomatis ditutup setelah 2 menit jika sensor mendeteksi perangkat tidak bergerak/tidak aktif untuk menjaga privasi pengguna.
* **Device Lost Mode**: Cari ponsel hilang via map, bunyikan alarm keras jarak jauh, dan kirim pesan kustom pada layar kunci hp.

### 🔒 4. Keamanan & Logs Bukti Hukum
* **Persistent Security Logs**: Setiap penghapusan pesan guardian, pemicuan/pengakhiran SOS, akses GPS/mic, akan dicatat secara permanen di database. Penghapusan log keamanan ini tetap akan meninggalkan jejak log baru.
* **Secure Storage PIN**: Enkripsi lokal menggunakan `flutter_secure_storage` untuk verifikasi PIN 6-digit dengan auto-lockout (5 kali salah = kunci 30 menit).

---

## 🛠️ Arsitektur & Teknologi
* **Core**: Flutter (Dart)
* **State Management**: Riverpod (`StateNotifierProvider`, `StreamProvider`, dll.)
* **Database & Auth**: Supabase (PostgreSQL, Row Level Security, Real-time Subscription)
* **Live Streaming**: WebRTC (`flutter_webrtc`)
* **Mapping**: OpenStreetMap (`flutter_map`)
* **Security Storage**: AES PIN Hashing (`crypto` SHA-256) & `flutter_secure_storage`

---

## 📂 Struktur Direktori Proyek
```text
lib/
├── core/
│   ├── constants/       # Tema, warna (Colors), rute aplikasi
│   ├── routes/          # Navigasi AppRoutes terpusat
│   └── widgets/         # Komponen UI tersentralisasi (CustomAppBar, SOSButton, Avatar, ChatBubble, CustomCard)
├── data/
│   ├── models/          # Model data Supabase (User, Message, Guardian, SOSSession, SecurityLog)
│   ├── repositories/    # Repositori logika bisnis Supabase
│   └── services/        # Layanan pendukung (Location, WebRTC, Notification, Secure Storage)
└── features/
    ├── auth/            # Halaman Login/Register, PIN Setup, Lockout, Splash, Onboarding
    ├── chat/            # Obrolan rooms, streaming pesan masuk, pengiriman media sekali lihat
    ├── guardian/        # Manajemen wali, tukar posisi peran, persetujuan undangan
    ├── map/             # Peta pelacakan lokasi OSM
    └── sos/             # Papan darurat SOS aktif, camera WebRTC, HP hilang
```

---

## 🚀 Panduan Memulai

### 1. Konfigurasi Backend Supabase
Jalankan skrip migrasi database di **SQL Editor** Supabase Anda secara berurutan:
1. `supabase/migrations/01_initial_schema.sql` (Membuat tabel)
2. `supabase/migrations/02_rls_policies.sql` (Mengatur keamanan RLS)
3. `supabase/migrations/03_database_triggers.sql` (Mencatat log otomatis)

Di panel Supabase, pastikan Email Auth aktif. Matikan **"Confirm email"** di tab Authentication Settings jika ingin proses registrasi instan untuk keperluan pengujian.

### 2. Pengaturan Variabel Lingkungan
Buat file `.env` di direktori utama proyek Anda:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 3. Instalasi dan Menjalankan Aplikasi
```bash
# Unduh paket dependensi
flutter pub get

# Jalankan pengujian unit & widget
flutter test

# Jalankan aplikasi
flutter run
```
