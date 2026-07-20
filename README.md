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
Jalankan **SELURUH** skrip migrasi di `supabase/migrations/` secara berurutan (01 → 26) di **SQL Editor** Supabase Anda — jangan berhenti di beberapa file awal saja.

> ⚠️ **Wajib, bukan opsional:** migrasi 01–03 saja *tidak cukup* untuk keamanan dasar. Migrasi-migrasi berikutnya (khususnya `05_security_hardening.sql`) mengunci akses ke kolom sangat sensitif di tabel `profiles` (`pin_hash`, `duress_pin_hash`, `two_fa_secret`, `e2ee_key_backup`) sekaligus mempersempit akses tabel `messages`. Menjalankan aplikasi tanpa migrasi lengkap akan membuat data ini berpotensi terbaca oleh pengguna lain.

Di panel Supabase, pastikan Email Auth aktif. Matikan **"Confirm email"** di tab Authentication Settings jika ingin proses registrasi instan untuk keperluan pengujian.

### 2. Pengaturan Variabel Lingkungan
Buat file `.env` di direktori utama proyek Anda:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 3. Konfigurasi Tambahan Sebelum Produksi

Dua hal ini **wajib** dikonfigurasi sebelum aplikasi dipakai dengan data pengguna sungguhan (lihat `AUDIT_MEKAAR_MVP_ke_Produksi.md` untuk detail risikonya):

**a) TURN server privat untuk WebRTC (video/audio darurat)**
Secara default aplikasi jatuh ke relay TURN publik gratis (`openrelay.metered.ca`) yang tidak punya SLA — tidak layak untuk fitur SOS. Set server TURN privat Anda sendiri saat build:
```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://your-project-id.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=TURN_URL=turn:turn.domain-anda.com:3478 \
  --dart-define=TURN_USERNAME=xxxx \
  --dart-define=TURN_CREDENTIAL=yyyy
```
Bisa pakai `coturn` self-hosted atau layanan terkelola (Twilio, Cloudflare Calls, dsb). Selama `TURN_URL` kosong, aplikasi memakai fallback publik dan akan mencetak peringatan di log debug.

**b) Kunci penandatanganan log bukti hukum (Edge Function `sign-logs`)**
```bash
# 1. Generate keypair Ed25519 sekali (lihat komentar lengkap di
#    supabase/functions/sign-logs/index.ts):
deno run -A -e '
  import * as ed from "https://esm.sh/@noble/ed25519@2.1.0";
  const priv = ed.utils.randomPrivateKey();
  const pub = await ed.getPublicKeyAsync(priv);
  console.log("PRIVATE:", Array.from(priv).map(b=>b.toString(16).padStart(2,"0")).join(""));
  console.log("PUBLIC :", Array.from(pub).map(b=>b.toString(16).padStart(2,"0")).join(""));
'

# 2. Simpan private key sebagai secret (JANGAN commit ke repo):
supabase secrets set LOG_SIGNING_ED25519_PRIVATE_KEY=<hex_private_key>

# 3. Deploy function:
supabase functions deploy sign-logs

# 4. Publikasikan PUBLIC key di halaman "Tentang"/dokumen resmi aplikasi
#    agar pihak ketiga (mis. kepolisian/pengadilan) bisa memverifikasi
#    ekspor log secara independen.
```
Tanpa langkah ini, fungsi `sign-logs` akan menolak menandatangani (fail-closed) dan aplikasi otomatis fallback ke ekspor CSV lokal tanpa tanda tangan.

### 4. Instalasi dan Menjalankan Aplikasi
```bash
# Unduh paket dependensi
flutter pub get

# Jalankan pengujian unit & widget
flutter test

# Jalankan aplikasi
flutter run
```
