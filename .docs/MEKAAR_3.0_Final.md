```markdown
# MEKAAR 3.0
**Aplikasi Chat dengan Fitur Keamanan Personal**
**Untuk Kehilangan, Pencurian, dan Situasi Darurat**

| | |
|---|---|
| **Versi:** | 3.0 – Final (Revisi Infrastruktur & Fitur Chat) |
| **Tanggal:** | 11 Juli 2026 |
| **Revisi:** | Pergantian backend ke Supabase, peta ke OpenStreetMap, penambahan fitur chat modern |
| **Status:** | Dokumen Pengembangan |

---

## DAFTAR ISI

1. PENDAHULUAN DAN FILOSOFI
2. FITUR DARURAT & FITUR CHAT
3. SISTEM GUARDIAN DAN PENGAMANAN
4. MANAJEMEN DATA 3 LAPISAN
5. ALUR KERJA
6. IMPLEMENTASI TEKNIS
7. PANDUAN DESAIN UI/UX (Modern, Youth, Breathable)
8. ETIKA, HUKUM, DAN KEPATUHAN
9. PENUTUP

---

## 1. PENDAHULUAN DAN FILOSOFI

### 1.1 Latar Belakang

Ponsel selalu kita bawa ke mana-mana dan memiliki GPS, mikrofon, serta kamera. Saat terjadi kehilangan, pencurian, atau situasi darurat, ponsel seharusnya bisa menjadi alat penyelamat. Masalahnya, saat insiden terjadi, kita sering panik dan tidak bisa mengoperasikannya.

Mekaar menjawab kebutuhan ini: sebuah aplikasi chat modern yang dilengkapi tombol darurat (SOS) dan sistem guardian — orang terpercaya yang langsung mendapat sinyal saat Anda dalam bahaya.

### 1.2 Filosofi Produk

- **Inisiatif dari Dalam** — Tidak ada seorang pun yang bisa mengakses sensor perangkat Anda tanpa Anda memulai. Guardian adalah penerima sinyal bahaya, bukan pengawas proaktif.
- **Chat adalah fondasi, keamanan adalah nilai tambah.** Mekaar adalah aplikasi chat yang layak digunakan bahkan tanpa mengaktifkan fitur darurat.
- **Persetujuan sadar + real-time.** Izin diberikan di awal, tetapi akses hanya aktif saat Anda menekan SOS. Tidak ada akses "siaga" yang bisa digunakan kapan saja oleh guardian.
- **Transparansi total.** Setiap akses dicatat secara permanen dan bisa diekspor kapan saja.
- **Kesetaraan.** Fitur Tukar Posisi memungkinkan hubungan guardian dua arah yang setara.
- **Privasi sejak awal** — Pilihan penyimpanan menghormati privasi pengguna.
- **Tidak ada fitur pengintaian.** Mekaar tidak memiliki aktivasi kamera jarak jauh, auto-answer panggilan tanpa indikasi, menyembunyikan aplikasi, atau menyembunyikan indikator sistem OS.

### 1.3 Definisi Istilah

| Istilah | Penjelasan |
|---|---|
| **Mekaar** | Dari bahasa Afrikaans, berarti "satu sama lain" atau "saling". |
| **Pengguna A** | Pemilik sah perangkat. |
| **Guardian (B)** | Orang terpercaya yang dipilih A. Hanya aktif saat A menekan SOS. |
| **Tombol SOS** | Tombol darurat satu sentuhan. Tersedia di layar utama, layar input PIN, dan widget. |
| **Mode Darurat** | Status aktif setelah A menekan SOS. Guardian bisa melihat lokasi dan (jika diizinkan) mendengar audio. |
| **Mode Perangkat Hilang** | Mode untuk HP hilang/dicuri. Hanya GPS, alarm, dan pesan layar. Mikrofon dan kamera dinonaktifkan total. |
| **Indikator Sistem** | Titik hijau/oranye bawaan OS. Tidak pernah disembunyikan. |

---

## 2. FITUR DARURAT & FITUR CHAT

### 2.1 Aplikasi Chat Modern

Mekaar berfungsi penuh sebagai aplikasi chat yang *breathable* dan modern untuk segmen youth. Fitur keamanan berada di menu terpisah dan hanya aktif jika dikehendaki.

#### 2.1.1 Fitur Chat Standar
Mendukung: teks, gambar, pesan suara, panggilan suara/video dua arah, **Reply/Quote** (mengutip pesan spesifik), **Typing Indicator** (*sentuh kehadiran* saat menunggu balasan darurat), hapus pesan untuk semua pihak, dan forward pesan.
- *Catatan Forward:* Pesan yang mengandung lokasi SOS atau log sistem **tidak bisa** di-forward. Hanya pesan chat biasa yang diizinkan.

#### 2.1.2 Fitur Privasi Chat
- **View-Once Media:** Mengirim foto/video sensitif (misal: KTP, SIM, foto rumah) yang otomatis hilang setelah dibuka penerima, tidak tersimpan di galeri.
- **Non-SOS Live Location:** Berbagi lokasi sementara secara sukarela (misal: 15 menit / 1 jam) untuk urusan sosial. **WAJIB** memiliki indikator visual yang sangat berbeda (warna coral + timer) dengan GPS Darurat SOS (warna merah + badge DARURAT) agar tidak ada ambiguitas.
- **Pin Messages:** Menyematkan pesan penting di atas chat room (misal: titik kumpul darurat atau kode rahasia).
- **Kontrol Centang & Terakhir Dilihat:** Read Receipts (centang baca) dan Last Seen **default-nya nonaktif**. Sepenuhnya menjadi kendali pengguna untuk menjaga privasi dari *stalkerware behavior*.

#### 2.1.3 Batasan Etis pada Chat
- **Tidak Ada Edit Message di Chat Guardian:** Mengedit pesan bisa mengubah konteks bukti hukum. Jika salah kirim, pengguna harus menghapus pesan, bukan mengeditnya.
- **Tidak Ada Send Without Notification:** Notifikasi ke Guardian bersifat mutlak dan tidak bisa dibypass. Ini mencegah pelaku kekerasan memaksa korban mengirim pesan diam-diam tanpa Guardian tahu.
- **Integritas Hapus Pesan:** Jika pesan dihapus di Chat Guardian, kontennya hilang dari layar, tetapi **Log Sistem (Lapisan 3) tetap mencatat**: *"Pesan dihapus oleh [Pengguna] pada [Waktu]"*.

### 2.2 Tombol SOS Darurat — Akses dari Mana Saja

**Lokasi tombol SOS:**

| Lokasi | Ketersediaan | Fungsi |
|---|---|---|
| Layar utama aplikasi | ✅ | Tombol merah besar — memicu mode darurat |
| Layar input PIN | ✅ | Tombol terpisah — darurat tetap bisa dipicu meski lupa PIN |
| Layar terkunci PIN (30 menit) | ✅ | Akses darurat tidak pernah diblokir |
| Widget notifikasi | ✅ | Bawaan OS — akses cepat dari luar aplikasi |

**Yang terjadi saat SOS ditekan:**

1. Mode Darurat aktif.
2. Guardian mendapat notifikasi: *"[Nama A] dalam keadaan darurat! Lokasi: [tautan peta]"*
3. GPS mulai mengirim lokasi real-time ke guardian.
4. Mikrofon (jika diizinkan) mulai streaming audio.
5. A bisa mengakhiri mode darurat kapan saja.

### 2.3 Streaming Audio (Mikrofon) Setelah SOS Aktif

Hanya jika:
- A sudah mengizinkan akses mikrofon ke guardian di pengaturan
- Mode Darurat sedang aktif (SOS sudah ditekan)

- Guardian mendengar audio sekitar perangkat A secara real-time
- Bisa diatur **streaming saja** (tidak disimpan) atau **disimpan ke server/drive**
- Indikator OS (titik hijau) muncul selama mikrofon aktif
- Berhenti saat A mengakhiri Mode Darurat

### 2.4 Video Darurat — Atas Permintaan Sendiri

Fitur kamera di MEKAAR bukan remote streaming. Ini adalah video call satu arah yang dimulai oleh A sendiri, mirip VC biasa tetapi dengan kemampuan layar terkunci.

**Alur Lengkap**

```
① A dalam perjalanan, merasa tidak aman
│
② A tekan SOS → Mode Darurat aktif
│
③ A buka menu → tekan "Kirim Video ke Guardian"
│
▼
┌─────────────────────────────────────┐
│    KIRIM VIDEO KE GUARDIAN          │
│                                     │
│  Pilih kamera:                      │
│  [🔙 Depan (wajah)] [🔎 Belakang (sekitar)] │
│                                     │
│  Layar tetap menyala?               │
│  ○ Ya  ○ Tidak (streaming lanjut)   │
│                                     │
│  Timer otomatis:                    │
│  [ Tanpa batas ▼ ]                  │
│  Atur: 5/10/15/30 mnt / Tanpa batas │
│                                     │
│  [──── MULAI VIDEO ────]            │
└─────────────────────────────────────┘
│
④ Kamera menyala sesuai pilihan A
   Indikator OS hijau menyala
│
⑤ A bisa kunci layar → streaming TETAP JALAN
│
⑥ Status bar: titik hijau OS aktif
   Notifikasi persisten (tidak bisa di-swipe):
   "📹 Video darurat → [B] — Ketuk untuk kelola / Hentikan"
│
⑦ A berhenti dengan:
   - Ketuk notifikasi → "Hentikan"
   - Buka aplikasi → "Hentikan"
   - Timer habis (jika diatur)
   - Inactivity auto-end (lihat di bawah)
│
⑧ Log: "A mengirim video ke B selama X menit"
```

**Inactivity Auto-End**

Jika A tidak menyentuh layar >2 menit dan akselerometer mendeteksi HP diam/tidak bergerak, sistem anggap:
- A tidak sadar, atau
- HP tertinggal/terlepas
→ Streaming otomatis berhenti untuk melindungi privasi A.

**Aturan Video Darurat**

| Aturan | Nilai |
|---|---|
| Siapa mulai? | ✅ Hanya A |
| Guardian bisa minta? | ❌ Tidak |
| Pilihan kamera | ✅ Depan (wajah) / Belakang (sekitar) |
| Layar terkunci? | ✅ Streaming tetap jalan |
| Notifikasi persisten | ✅ Wajib, tidak bisa di-swipe |
| Indikator OS hijau | ✅ Wajib, tidak disembunyikan |
| Timer | ✅ Custom: 5/10/15/30 mnt atau tanpa batas |
| Inactivity auto-end | ✅ 2 menit no touch + HP diam |
| Stop dari notifikasi | ✅ Bisa tanpa buka aplikasi |
| Bisa mulai ulang? | ✅ Kapan saja, tanpa batas sesi |
| Bisa unduh oleh B? | ❌ Tidak (streaming saja) |

### 2.5 Mode Perangkat Hilang (Self-Guardian)

Fitur untuk menemukan ponsel yang hilang atau dicuri. **Tidak ada akses mikrofon atau kamera.**

| Fitur | Tersedia? |
|---|---|
| Lacak lokasi GPS | ✅ Ya |
| Bunyikan alarm jarak jauh | ✅ Ya |
| Kirim pesan ke layar | ✅ Ya (*"HP ini hilang. Hubungi [nomor]."* ) |
| Streaming mikrofon | ❌ Dihapus total |
| Kamera / foto | ❌ Dihapus total |

---

## 3. SISTEM GUARDIAN DAN PENGAMANAN

### 3.1 Sistem Guardian — Berbasis Izin yang Terpicu

| Prinsip | Penjelasan |
|---|---|
| Izin tidak aktif dalam keadaan normal | Guardian tidak bisa mengakses apa pun tanpa SOS |
| Izin aktif hanya saat Mode Darurat menyala | Setelah A menekan SOS, izin yang sudah diberikan baru berlaku |
| A mengakhiri → semua akses terputus | Kapan saja, kendali penuh di A |

**Yang guardian bisa lakukan:**
- ✅ Menerima notifikasi saat A menekan SOS
- ✅ Melihat lokasi live A (setelah SOS)
- ✅ Mendengar audio sekitar A (jika diizinkan, setelah SOS)
- ✅ Menerima video yang dikirim A (A yang memulai)
- ✅ Membalas pesan di chat

**Yang guardian TIDAK bisa lakukan:**
- ❌ Mengirim perintah `/lacak`, `/dengar`, `/foto`
- ❌ Meminta video dari jarak jauh
- ❌ Mengaktifkan sensor apa pun secara sepihak
- ❌ Menghapus log akses
- ❌ Mengunduh rekaman secara permanen

### 3.2 Izin yang Bisa Diatur Per Komponen

| Komponen | Tersedia? | Aktif kapan? | Catatan |
|---|---|---|---|
| Lokasi (GPS) | ✅ Ya | Setelah SOS | Real-time ke guardian |
| Mikrofon | ✅ Ya | Setelah SOS | Streaming audio |
| Kamera | ⚠️ A yang mulai | Saat A tekan tombol video | Bukan remote access |
| Panggilan suara/video | ✅ Ya | Normal & darurat | Indikasi jelas di A |

### 3.3 Switch Guardian — Saling Bertukar Peran

A dan B bisa bertukar peran secara sukarela. Kedua pihak harus menyetujui. Izin masing-masing diatur terpisah.

### 3.4 Izin Guardian Kedaluwarsa

Izin guardian otomatis kedaluwarsa setelah **30 hari** dan perlu diperbarui oleh A. Ini mencegah izin yang terlupakan dan menjaga hubungan guardian tetap sadar.

### 3.5 Keamanan Berlapis dengan PIN + Akses Darurat

- PIN 6 digit wajib untuk membuka aplikasi.
- PIN terpisah (pilihan) untuk pengaturan.
- Tombol SOS di layar input PIN — darurat tetap bisa dipicu.
- 5x salah PIN → aplikasi terkunci 30 menit, **tetapi tombol SOS tetap bisa ditekan**.
- Pendaftaran via email/Google.

### 3.6 Indikator Sistem OS — Wajib Tampil

Saat kamera atau mikrofon aktif:
- ✅ Titik hijau (Android) / oranye (iOS) di status bar
- ✅ Tidak bisa disembunyikan oleh aplikasi
- ✅ Mengikuti aturan bawaan OS

---

## 4. MANAJEMEN DATA 3 LAPISAN

MEKAAR memiliki tiga lapisan data dengan aturan penghapusan yang berbeda.

### 4.1 Lapisan 1: Chat Biasa (Non-Guardian)

Percakapan sehari-hari dengan pengguna non-guardian.

| Aturan | Nilai |
|---|---|
| Auto-delete | ✅ Bebas: 24 jam / 7 hari / 30 hari / Mati (default) |
| Manual hapus | ✅ Bebas |
| Peringatan sebelum hapus | ❌ Tidak perlu |
| Default | Mati (pesan tersimpan normal) |

### 4.2 Lapisan 2: Chat Guardian

Percakapan dengan guardian — berisi riwayat komunikasi darurat.

| Aturan | Nilai |
|---|---|
| Auto-delete | ⚠️ Terbatas — hanya 7 hari atau 30 hari |
| Default | Mati (pesan tersimpan) |
| Minimal durasi | 7 hari (24 jam terlalu riskan untuk chat keamanan) |
| Peringatan | ✅ Wajib sebelum mengaktifkan |

**Teks peringatan:**

> *"Chat ini berisi riwayat komunikasi dengan guardian Anda. Menyalakan auto-delete dapat menghilangkan bukti percakapan keamanan yang penting. Log akses sistem tetap tersimpan di menu terpisah dan tidak terpengaruh. Lanjutkan?"*

### 4.3 Lapisan 3: Log Sistem

Catatan akses guardian, aktivitas SOS, penghapusan pesan, dan event keamanan.

| Aturan | Nilai |
|---|---|
| Auto-delete | ❌ Tidak bisa — permanen |
| Manual hapus | ⚠️ Bisa (per item) dengan peringatan |
| Peringatan | ✅ Wajib |
| Tercatat saat hapus? | ✅ Ya — log mencatat: *"Pengguna menghapus log akses [jenis] pada [waktu]"* |
| Ekspor | ✅ Bisa diekspor ke CSV/PDF |
| Terpengaruh auto-delete chat? | ❌ Tidak — sistem terpisah |

**Teks peringatan hapus log:**

> *"Ini adalah catatan aktivitas keamanan. Menghapusnya dapat menghilangkan bukti. Tindakan ini akan dicatat."*

**Yang termasuk Log Sistem:**

- ✅ *"SOS diaktifkan pada [waktu]"*
- ✅ *"Mode darurat berakhir pada [waktu]"*
- ✅ *"Guardian [B] mengakses lokasi pada [waktu] selama [durasi]"*
- ✅ *"Guardian [B] mengakses mikrofon pada [waktu] selama [durasi]"*
- ✅ *"A mengirim video ke guardian pada [waktu] selama [durasi]"*
- ✅ *"Pesan dihapus oleh [Pengguna] pada [waktu]"*
- ✅ *"Penghapusan log oleh pengguna pada [waktu]"*

### 4.4 Ringkasan 3 Lapisan

| Aturan | Chat Biasa | Chat Guardian | Log Sistem |
|---|---|---|---|
| Auto-delete | ✅ Bebas | ⚠️ 7/30 hari, default mati | ❌ Tidak bisa |
| Manual hapus | ✅ Bebas | ✅ Bisa (Tercatat di Log) | ⚠️ Bisa (tercatat) |
| Peringatan | ❌ Tidak | ✅ Wajib | ✅ Wajib |
| Default | Mati | Mati | Permanen |
| Edit Pesan | ✅ Bisa | ❌ Dilarang | — |

### 4.5 Enkripsi Ujung-ke-Ujung (E2EE)

Semua pesan, file media, dan streaming dienkripsi sehingga hanya pengirim dan penerima yang bisa membaca. Kunci enkripsi disimpan aman di dalam perangkat.

### 4.6 Penyimpanan Hasil Pelacakan

A dapat memilih cara penyimpanan untuk setiap komponen:

| Opsi | Penjelasan |
|---|---|
| **Streaming saja** | Data tidak disimpan. |
| **Simpan ke Server (terenkripsi E2EE)** | Guardian bisa lihat streaming ulang tetapi tidak bisa mengunduh. |
| **Simpan ke Drive Pribadi A** | File langsung masuk ke Google Drive/iCloud A. Tidak ada salinan di server. |
| **Simpan ke Drive A + Tautan Sementara** | Tautan terenkripsi ke B, berlaku maksimal 24 jam. Guardian tidak bisa mengunduh permanen. |

---

## 5. ALUR KERJA

### 5.1 Pemasangan dan Pengaturan Awal

1. Unduh dan pasang Mekaar.
2. Daftar/masuk dengan email/Google (via **Supabase Auth**).
3. Buat PIN 6 digit.
4. (Pilihan) Atur PIN pengaturan.
5. Baca peringatan etika yang muncul pertama kali.

### 5.2 Menambah Guardian (Add by Username/Email)

1. Pengaturan → Guardian → Tambah Guardian.
2. Masukkan email atau **username** calon guardian.
3. Pilih fitur yang akan aktif setelah SOS: Lokasi, Mikrofon.
4. Pilih cara penyimpanan.
5. Kirim undangan → penerima menyetujui → chat baru muncul.
6. Izin tidak aktif sampai A menekan SOS.
7. Izin kedaluwarsa 30 hari, perlu diperbarui.

### 5.3 Skenario Keadaan Darurat

1. A dalam situasi bahaya.
2. A tekan Tombol SOS (dari layar utama, layar PIN, atau widget).
3. Mode Darurat aktif.
4. GPS dan mikrofon (jika diizinkan) mulai streaming.
5. B mendapat notifikasi darurat dengan lokasi A (tautan peta OpenStreetMap).
6. (Opsional) A tekan *"Kirim Video ke Guardian"* — pilih kamera, timer, mulai.
7. A bisa kunci layar — video tetap jalan dengan notifikasi persisten.
8. Jika A tidak bergerak dan tidak sentuh layar >2 menit → video auto-end.
9. A bisa akhiri mode darurat kapan saja.
10. Semua akses terputus.
11. Log tercatat permanen di Supabase (tabel `security_logs`).

### 5.4 Skenario Perangkat Hilang

1. HP A hilang.
2. A login dari perangkat lain ke Mekaar (via Supabase Auth — sesi baru).
3. Masuk ke chat *"Ponsel Saya"*.
4. Lihat lokasi terakhir di peta (OpenStreetMap via Supabase koordinat tersimpan).
5. (Pilihan) Bunyikan alarm jarak jauh.
6. (Pilihan) Kirim pesan ke layar.
7. Mikrofon dan kamera tidak tersedia.

### 5.5 Skenario Pertukaran Posisi

1. A buka detail guardian B → Tukar Posisi.
2. Tentukan izin untuk kedua arah.
3. B menerima dan memasukkan PIN.
4. Sekarang A dan B bisa saling menjaga — dengan prinsip yang sama.

---

## 6. IMPLEMENTASI TEKNIS

### 6.1 Arsitektur Umum

```
┌──────────────────────────────────────────────────┐
│                 PERANGKAT A                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Flutter  │  │ Local DB │  │ Foreground    │  │
│  │ UI Layer │──│ SQLite   │  │ Service       │  │
│  └────┬─────┘  └──────────┘  │ (SOS/Video)   │  │
│       │                       └───────────────┘  │
│       │  Supabase Client SDK                    │
└───────┼──────────────────────────────────────────┘
        │ HTTPS + WebSocket (Realtime)
        ▼
┌──────────────────────────────────────────────────┐
│              SUPABASE CLOUD                      │
│  ┌────────────┐  ┌────────────┐  ┌───────────┐  │
│  │ PostgreSQL │  │  Storage   │  │ Edge      │  │
│  │ (RLS)     │  │  (Bucket)  │  │ Functions │  │
│  └────────────┘  └────────────┘  └───────────┘  │
│  ┌────────────┐  ┌────────────┐                  │
│  │  Auth (JWT)│  │  Realtime  │                  │
│  └────────────┘  └────────────┘                  │
└──────────────────────────────────────────────────┘
```

### 6.2 Supabase — Skema Database (PostgreSQL)

```sql
-- Profil pengguna
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id),
  username    TEXT UNIQUE,
  email       TEXT NOT NULL,
  pin_hash    TEXT NOT NULL,
  pin_locked_until TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Relasi guardian
CREATE TABLE guardians (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID NOT NULL REFERENCES profiles(id),
  guardian_id     UUID NOT NULL REFERENCES profiles(id),
  permissions     JSONB NOT NULL DEFAULT '{"gps": false, "mic": false}',
  storage_option  TEXT DEFAULT 'stream_only',
  status          TEXT DEFAULT 'pending', -- pending / active / expired
  created_at      TIMESTAMPTZ DEFAULT now(),
  expires_at      TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days'),
  UNIQUE(owner_id, guardian_id)
);

-- Chat rooms
CREATE TABLE chat_rooms (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_type   TEXT NOT NULL, -- 'normal' / 'guardian' / 'self_device'
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Pesan chat (Mendukung Reply, View-Once, dll)
CREATE TABLE messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id         UUID NOT NULL REFERENCES chat_rooms(id),
  sender_id       UUID NOT NULL REFERENCES profiles(id),
  content         TEXT,
  media_url       TEXT,
  msg_type        TEXT DEFAULT 'text', -- text / image / voice / video / system / location
  is_view_once    BOOLEAN DEFAULT FALSE,
  reply_to_id     UUID REFERENCES messages(id) NULL, -- Untuk fitur Quote/Reply
  is_deleted      BOOLEAN DEFAULT FALSE, -- Soft delete untuk Chat Guardian
  auto_delete_at  TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Sesi SOS
CREATE TABLE sos_sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  started_at  TIMESTAMPTZ NOT NULL,
  ended_at    TIMESTAMPTZ,
  status      TEXT DEFAULT 'active',
  gps_enabled BOOLEAN DEFAULT true,
  mic_enabled BOOLEAN DEFAULT false,
  video_enabled BOOLEAN DEFAULT false,
  ended_reason TEXT -- 'manual' / 'timer' / 'inactivity'
);

-- Lokasi real-time
CREATE TABLE location_pings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  UUID NOT NULL REFERENCES sos_sessions(id),
  latitude    DECIMAL(10,7) NOT NULL,
  longitude   DECIMAL(10,7) NOT NULL,
  timestamp   TIMESTAMPTZ DEFAULT now()
);

-- LOG SISTEM — PERMANEN
CREATE TABLE security_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  event_type  TEXT NOT NULL, -- 'sos_started', 'msg_deleted', 'log_deleted', etc
  details     JSONB,
  created_at  TIMESTAMPTZ DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);
```

### 6.3 Row Level Security (RLS)

Keamanan akses data diatur di level database. Contoh:
- `messages`: Peserta chat room saja yang bisa SELECT. UPDATE hanya untuk soft-delete `is_deleted = true`.
- `security_logs`: Hanya pemilik yang bisa SELECT. Tidak bisa di-hard delete, hanya soft-delete yang memicu trigger untuk mencatat ulang ke log itu sendiri.
- `location_pings`: Hanya bisa dibaca oleh Guardian jika tabel `sos_sessions` menyatakan status `active` untuk guardian tersebut.

### 6.4 Edge Functions & Realtime

- **Edge Functions (Deno):** `validate-access` (menolak akses jika SOS tidak aktif), `auto-delete-sweep` (cron job jam-an), `expire-guardians` (cron job harian), `export-logs`.
- **Realtime (WebSocket):** Digunakan untuk signaling WebRTC (audio/video stream P2P) dan mengirim koordinat GPS berkala. Media streaming **tidak** melewati server Supabase.

### 6.5 Peta — OpenStreetMap

- **Tampilan peta:** `flutter_map` dengan tile layer OSM.
- **Geocoding:** Nominatim API.
- **Tautan di notifikasi:** `https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map=17/{lat}/{lon}`
- *Keuntungan:* Gratis, tidak perlu API key, tidak ada tracking pihak ketiga, kompatibel offline.

### 6.6 Push Notifikasi

Menggunakan FCM (Android) dan APNs (iOS) yang di-integrasikan secara terbatas melalui Supabase Push. **Hanya** berfungsi sebagai delivery channel, bukan backend utama.

---

## 7. PANDUAN DESAIN UI/UX

**Style: Youth · Modern · Breathable**

### 7.1 Filosofi Visual
MEKAAR adalah aplikasi chat yang *normal* 95% waktu, tapi menjadi *alat penyelamat* 5% waktu. Desain tidak boleh terlihat menakutkan di hari biasa, tapi harus jelas dan cepat diakses saat darurat. *"Seperti jaket yang nyaman dipakai sehari-hari — bukan rompi anti peluru yang berat. Tapi saat hujan, jaket itu ternyata bisa menahan air."*

### 7.2 Color System
- **Accent (Soft Coral `#FF6B6B`):** Hangat, manusiawi. Bukan biru (terlalu umum) atau ungu (tren AI yang jenuh).
- **SOS Red (`#EF4444`):** **Hanya** muncul di Tombol SOS, notifikasi darurat, dan overlay darurat. Tidak pernah untuk elemen dekorasi (Menjaga *urgency integrity*).
- **Guardian Teal (`#2DD4BF`):** Menandakan status guardian aktif/standby.
- **Surface:** Dark mode utama (`#0A0A0F`, `#18181B`) dengan dukungan Light mode first-class.

### 7.3 Typography & Spacing
- **Font:** Plus Jakarta Sans (Humanis, geometris, tidak terlalu techy).
- **Spacing:** Grid 8px. Ruang putih yang *generous*. Tidak ada card yang menyentuh tepi layar atau saling bersentuhan tanpa jeda (Breathable).

### 7.4 Komponen Kunci
- **Tombol SOS (Normal):** 48x48px, coral tint lembut, *cukup jelas tapi tidak mendominasi* chat list.
- **Tombol SOS (Darurat Aktif):** Membesar menjadi 64x64px, merah penuh, *pulse* halus. Seluruh layar mendapat overlay merah sangat tipis (3-5% opacity).
- **Chat Bubbles:** Pengirim menggunakan coral tint, penerima menggunakan surface color. Pesan sistem di tengah tanpa bubble.
- **Non-SOS vs SOS Location:** Non-SOS menggunakan ikon coral + timer hitung mundur. SOS menggunakan ikon merah + badge "DARURAT".

### 7.5 Onboarding
Maksimal **3 langkah**: (1) Apa ini, (2) Siapa guardian kamu, (3) Buat PIN. Tidak ada slide fitur detail yang membosankan.

### 7.6 Motion
Purposeful, bukan decorative. Standar 200ms. Haptic feedback diaktifkan saat menekan SOS (*heavy impact*) dan saat inactivity auto-end terpicu.

---

## 8. ETIKA, HUKUM, DAN KEPATUHAN

### 8.1 Prinsip Etika

- **Inisiatif dari Dalam** — Tidak ada akses sensor tanpa tindakan sadar pemilik perangkat.
- **Persetujuan Sadar + Real-Time** — Izin awal + SOS sebagai pemicu.
- **Transparansi Total** — Setiap akses & penghapusan pesan tercatat permanen dan bisa diekspor.
- **Tidak Ada Fitur Pengintaian** — ❌ Aktivasi kamera jarak jauh, ❌ Auto-answer tanpa indikasi, ❌ Menyembunyikan indikator OS, ❌ *Send Without Notification*.
- **Izin Kedaluwarsa** — Otomatis 30 hari, perlu diperbarui.

### 8.2 Kepatuhan Hukum

- Mematuhi UU Perlindungan Data Pribadi.
- Mematuhi kebijakan Google Play/App Store tentang anti-stalkerware.
- Semua akses sensor memerlukan indikator OS yang tidak bisa disembunyikan.
- **Supabase** memungkinkan pemilihan region data (EU, US, APAC).
- **OpenStreetMap** tidak melacak pengguna akhir.

### 8.3 Perbandingan: Versi 2.1 vs Versi 3.0

| Fitur | Versi 2.1 | Versi 3.0 (Final) |
|---|---|---|
| Guardian akses sensor sepihak | ✅ Bisa | ❌ Hanya setelah SOS |
| Self-guardian: mikrofon/kamera | ✅ Ada | ❌ Dihapus total |
| Penghapusan log 90 hari | ✅ Otomatis | ❌ Permanen (termasuk log hapus pesan) |
| Edit pesan di Chat Guardian | ✅ Bisa | ❌ Dilarang (Hapus saja) |
| Send Without Notification | ✅ Bisa | ❌ Dihapus (Notifikasi wajib mutlak) |
| Fitur Chat Modern (Reply, dll) | ❌ Minimal | ✅ Lengkap dengan batasan etis |
| **Backend** | **Firebase** | **Supabase** |
| **Peta** | **Google Maps** | **OpenStreetMap** |

### 8.4 Peringatan dan Disclaimer

Teks peringatan muncul di: Pertama kali buka app, saat menambahkan guardian, saat mengaktifkan auto-delete chat guardian, saat menghapus log/pesan guardian, dan saat memulai video darurat.

> *"Mekaar adalah alat bantu keamanan personal. Semua akses ke sensor perangkat Anda hanya bisa dimulai oleh Anda sendiri melalui tombol SOS. Tidak ada pihak lain yang bisa mengaktifkan kamera, mikrofon, atau GPS perangkat Anda tanpa tindakan Anda. Gunakan dengan bijak dan bertanggung jawab."*

---

## 9. PENUTUP

### 9.1 Kesimpulan

MEKAAR 3.0 adalah aplikasi chat dengan fitur keamanan personal yang dibangun di atas prinsip **"Inisiatif dari Dalam"**. 

**Tiga pilar MEKAAR 3.0:**
1. **Fitur Darurat** — SOS di mana saja, GPS, audio, video darurat layar terkunci.
2. **Chat Modern & Etis** — Fitur lengkap (reply, view-once, pin) tanpa mengorbankan keamanan bukti.
3. **Manajemen Data 3 Lapisan** — Chat biasa bebas, chat guardian terbatas & tidak bisa diedit, log sistem permanen.

### 9.2 Rekomendasi Pengembangan

| Fase | Durasi | Fitur |
|---|---|---|
| Versi Awal | 3 bulan | Chat dasar + fitur modern (Reply, View-once, dll), SOS + PIN, GPS (OSM), Mode perangkat hilang |
| Versi Beta | 6 bulan | Audio/video streaming (WebRTC), E2EE, Video darurat layar terkunci, Auto-delete 3 lapisan, Switch guardian |
| Rilis 1.0 | 9 bulan | Cloud drive pribadi, Log permanen + ekspor, Cron job Supabase, Uji keamanan independen |

### 9.3 Kata Penutup

Mekaar berarti *"satu sama lain"*. Kami percaya bahwa teknologi keamanan seharusnya memperkuat ikatan saling percaya, bukan menciptakan kecurigaan. Dengan MEKAAR 3.0, menjaga orang terdekat berarti siap membantu saat diminta — bukan mengawasi tanpa sepengetahuan.

Aplikasi yang etis adalah aplikasi yang memberi kendali penuh kepada penggunanya, bukan kepada orang lain.

---
*Dokumen ini bersifat final untuk keperluan pengembangan.*
```