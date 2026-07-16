# Rencana Implementasi: Polish UI/UX MEKAAR 3.0

**Referensi visual:** "Fun and Chatting app UI/UX design" (Pinterest, by Khamb Jot / UX UI Design) — chat app bergaya *playful/youth*: karakter emotif, chat bubble ekspresif, warna cerah, layout breathable.

**Arah yang disepakati:**
- Cakupan: **polish menyeluruh** (chat, auth, guardian, sos, map, settings).
- Vibe: **playful tapi tetap tepercaya** — tambah keceriaan (aksen, ilustrasi, animasi halus) untuk layer chat & sosial, tetapi pertahankan kesan aman/serius untuk **SOS & Guardian**.
- Output: dokumen rencana ini dulu, sebelum eksekusi kode.

---

## 0. Prinsip Desain (guardrail)

1. **Dua "mood" jelas.** Chat/sosial = playful, warm, animatif. SOS/Guardian/Security = tenang, tegas, minim distraksi (keamanan tidak boleh terasa main-main).
2. **Semua style lewat design system.** Dilarang `TextStyle`/warna/spacing/radius hardcoded — wajib `MekaarTypography`, `MekaarColors`, `MekaarSpacing`, `MekaarRadius`, `MekaarSizes`.
3. **Motion punya makna.** Animasi memandu perhatian & memberi feedback, bukan dekorasi. Durasi pendek (150–300ms), kurva alami (`easeOutCubic`).
4. **Haptic konsisten** untuk aksi penting (kirim, reaksi, SOS, error).
5. **Aksesibilitas dijaga.** Kontras cukup, target sentuh ≥ 44px, `Semantics` untuk kontrol utama, hormati `reduce motion` bila memungkinkan.
6. **Dark mode paritas** — setiap perubahan light harus diverifikasi di dark theme.

---

## Tahap 1 — Audit & Perkuat Fondasi Design System

> Tujuan: hilangkan inkonsistensi sebelum menambah polish, supaya polish konsisten otomatis.

### 1.1 Bersihkan style hardcoded
- Ganti semua `TextStyle(...)` inline dengan konstanta `MekaarTypography`.
  - Titik yang sudah teridentifikasi: `features/chat/widgets/chat_list_tile.dart` (nama, jam, last message, badge), badan `core/widgets/chat_bubble.dart` (teks pesan, timestamp, label, voice, view-once), `chat_composer.dart` (hint, label attachment).
- Ganti angka `borderRadius`/`padding`/`SizedBox` magic number dengan `MekaarRadius` / `MekaarSpacing`.
- Audit menyeluruh: cari `TextStyle(`, `BorderRadius.circular(<angka>`, `EdgeInsets.all(<angka>` di seluruh `lib/` dan konversi.

### 1.2 Lengkapi token yang kurang (playful-ready)
- **Elevation/shadow token** terpusat (mis. `MekaarShadows.card`, `.floating`, `.bubble`) — saat ini shadow ditulis inline (`chat_bubble`).
- **Durasi & kurva animasi** terpusat (`MekaarMotion.fast/normal/slow`, kurva default) agar seragam.
- **Gradient token** untuk aksen playful (mis. coral→peach untuk header chat, teal untuk guardian) — dipakai selektif, bukan di area SOS.
- Opsional: warna aksen sekunder cerah tambahan (mis. lilac/kuning) untuk variasi avatar & reaksi, tetap harmonis dengan Coral/Teal.

### 1.3 Standarisasi komponen dasar
- Review `custom_card.dart`, `custom_app_bar.dart`, `avatar.dart`, `mekaar_dialog.dart`, `mekaar_search_field.dart` agar semua menaati token & punya state (pressed/hover/disabled) yang konsisten.
- Buat komponen reusable baru bila belum ada: `MekaarButton` (primary/secondary/danger), `MekaarBottomSheet` wrapper (drag handle + radius konsisten — saat ini bottom sheet dibuat manual berulang di `chat_bubble` & `chat_composer`), `MekaarEmptyState`, `MekaarChip`/badge.

**Kriteria selesai Tahap 1:** `flutter analyze` bersih; tidak ada style hardcoded di file yang disentuh; token motion/shadow/gradient tersedia.

---

## Tahap 2 — Motion & Microinteraction (kerangka)

> Fondasi animasi yang dipakai ulang di semua fitur.

- **Entrance animation** untuk list (chat list, guardian list, logs): fade + slide-up bertahap (staggered) saat pertama muncul.
- **Bubble chat masuk**: animasi scale/fade lembut saat pesan baru datang.
- **Button press feedback**: scale-down ringan + haptic pada tombol utama (send, SOS, action sheet).
- **Page transition** konsisten via `AppRoutes` (shared axis / fade-through), bukan default MaterialPageRoute polos.
- **Skeleton loading** pakai `shimmer` (sudah ada di deps) untuk chat list & pesan saat memuat, gantikan spinner biasa.
- Sediakan util reusable (mis. `AnimatedAppear`, `PressableScale`) agar dipakai lintas fitur.

**Kriteria selesai:** util animasi reusable ada; minimal chat list + bubble memakainya; tidak ada jank saat scroll.

---

## Tahap 3 — Fitur Chat (paling dekat referensi, prioritas tertinggi)

### 3.1 Chat List (`chat_list_screen`, `chat_list_tile`)
- Header playful: judul besar (`displayLG`), greeting/nama, aksen gradient halus.
- Tile: pakai typography token, avatar dengan ring warna (online/guardian), badge unread animatif (pop saat bertambah).
- **Empty state ilustratif** (karakter emotif ala referensi) + CTA "Mulai obrolan".
- Search field konsisten (`mekaar_search_field`) dengan animasi expand.
- Skeleton shimmer saat loading.

### 3.2 Chat Room (`chat_screen`, `chat_bubble`)
- Bubble lebih ekspresif: tail lembut, spacing napas, grouping pesan berurutan dari pengirim sama (hemat ruang, lebih rapi).
- **Typing indicator** animatif (tiga titik memantul).
- Reaksi emoji: animasi pop saat ditambah; reaction picker lebih hidup (scale-in per emoji).
- Perbaiki **voice note player** yang masih placeholder (`_VoiceBubblePlayer` hanya toggle UI) → integrasi `audioplayers` nyata + waveform yang mencerminkan progress.
- Read receipt & timestamp: rapikan hierarki visual, pakai token.
- Reply preview & view-once: perhalus transisi & warna.
- Date separator ("Hari ini", "Kemarin") bergaya chip lembut.

### 3.3 Composer (`chat_composer`)
- Tombol kirim: animasi morph (mic ⇄ send tergantung ada teks), press feedback + haptic.
- Attachment sheet & live-location sheet: migrasi ke `MekaarBottomSheet` reusable.
- Indikator view-once & upload progress diperhalus.

**Kriteria selesai:** chat terasa hidup & playful; voice note benar-benar berfungsi; semua style via token; verifikasi light+dark.

---

## Tahap 4 — Auth & Onboarding (kesan pertama)

- **Splash** (`splash_screen`): animasi logo/brand halus.
- **Onboarding** (`onboarding_screen`): ilustrasi/karakter emotif per slide, indikator halaman animatif, transisi mulus — tempat paling pas untuk vibe playful.
- **Login/Register** (`login_screen`): field & tombol pakai token, validasi inline ramah (pesan Indonesia), microinteraction fokus.
- **PIN** (`pin_screen`): dot PIN animatif (isi/pop), shake animation saat salah, feedback lockout jelas — **tetap tenang/tegas** (ini keamanan, bukan area playful berlebihan).

**Kriteria selesai:** onboarding memikat; PIN jelas & aman-terasa; tanpa hardcoded style.

---

## Tahap 5 — Guardian & Map (mood tepercaya)

- **Guardian list/detail/add/swap**: kartu status hubungan yang jelas (aktif, sisa durasi 30 hari), aksen **teal** konsisten, empty state ramah tapi tidak kekanak-kanakan.
- Alur undangan & swap: langkah lebih jelas, konfirmasi dua arah dengan visual status.
- **Map** (`location_map_screen`, `guardian_tracking_screen`): marker & kartu info OSM yang rapi, badge "LIVE" konsisten dengan bubble lokasi, kontrol peta enak dijangkau.
- **Batasi animasi** di area ini — fungsional & tenang lebih penting daripada playful.

**Kriteria selesai:** status guardian selalu terbaca jelas; peta rapi & informatif.

---

## Tahap 6 — SOS & Emergency (paling serius)

- **SOS button** (`sos_button`): pulsasi & haptic sudah jadi ciri khas — pertahankan, rapikan agar konsisten dengan token, pastikan tetap dominan & tidak "lucu".
- **SOS active** (`sos_active_screen`): hierarki informasi kritis jelas (status, timer, aksi hentikan), kontras tinggi, tanpa distraksi playful.
- **Video emergency** (`video_emergency_screen`) & **device lost** (`device_lost_screen`): kontrol besar & jelas, state loading/gagal koneksi WebRTC yang informatif.
- Countdown/inactivity watchdog (auto-close 2 menit): indikator visual yang tegas.

**Kriteria selesai:** area darurat terasa serius, cepat dipahami, minim salah tekan.

---

## Tahap 7 — Settings & Security Logs

- **Settings** (`settings_screen`, `profile_screen`): grup rapi, toggle & tile konsisten, avatar profil dengan edit affordance.
- Toggle tema (light/dark) bila belum ada, dengan transisi halus.
- **Security logs** (`security_logs_screen`): timeline event yang mudah dibaca (ikon per tipe: hapus pesan, SOS, akses GPS/mic), empty state, filter/tanggal — pertahankan kesan "bukti hukum" (rapi, kredibel).

---

## Tahap 8 — Aksesibilitas, QA & Konsistensi Akhir

- Audit kontras warna (light & dark) untuk teks & ikon.
- `Semantics` untuk kontrol utama (SOS, kirim, navigasi).
- Target sentuh ≥ 44px; cek pada layar kecil.
- Uji manual alur kunci: kirim pesan, reaksi, view-once, PIN, SOS trigger, guardian add/swap.
- Jalankan `flutter analyze` + `flutter test` (unit, widget, webrtc_signaling).
- Verifikasi tidak ada regresi fungsional (terutama SOS/WebRTC/PIN yang sensitif).

---

## Urutan Eksekusi yang Disarankan

1. **Tahap 1 (Fondasi)** → wajib pertama; semua tahap lain bergantung padanya.
2. **Tahap 2 (Motion kerangka)** → sediakan util reusable.
3. **Tahap 3 (Chat)** → dampak visual terbesar, paling dekat referensi.
4. **Tahap 4 (Auth/Onboarding)** → kesan pertama.
5. **Tahap 5 (Guardian/Map)** & **Tahap 6 (SOS)** → area tepercaya, hati-hati.
6. **Tahap 7 (Settings/Logs)**.
7. **Tahap 8 (QA final)**.

Tiap tahap: kerjakan → `flutter analyze` → cek light+dark → lanjut.

---

## Risiko & Catatan

- **Jangan over-animate area keamanan.** SOS/Guardian/Logs harus tetap kredibel; playful hanya untuk chat/sosial/onboarding.
- **Voice note player saat ini palsu** — perbaikannya menyentuh logika (`audioplayers`), bukan murni UI; uji di device nyata.
- **WebRTC & PIN sensitif** — perubahan UI di sana harus dijaga agar tidak mengubah perilaku.
- **`.env` + Supabase wajib** untuk menjalankan app saat verifikasi manual (lihat `AGENTS.md`).
- **Aset ilustrasi/karakter** perlu disiapkan (SVG via `flutter_svg` yang sudah ada) — sumber aset perlu diputuskan sebelum Tahap 3/4.
- Perubahan `.env`/tema butuh full restart (dotenv tidak hot-reload).

---

## Keputusan yang Masih Perlu Ditentukan (sebelum eksekusi)

1. Sumber aset ilustrasi/karakter emotif (buat sendiri, ikon pack, atau library)?
2. Apakah menambah maskot/karakter brand khas MEKAAR, atau cukup ilustrasi generik ramah?
3. Prioritas: kejar semua tahap, atau rilis bertahap mulai dari Chat (Tahap 1→3) dulu?

---

## Narasi Copywriting: ""Safety Without Surveillance"" (Tambahan)

Posisikan MEKAAR sebagai **Aplikasi Kawan Setara (Peer Trust)**, bukan aplikasi
orang tua mengawasi anak. Remaja resisten jika merasa diawasi, tapi akan pakai
jika merasa diperkuat oleh teman/saudaranya.

**Panduan kata:**
- Hindari: **Monitor**, **Awasi**, **Pantau**.
- Gunakan: **Watch Over**, **Look Out For**, **Menjaga**, **Saling menjaga**, **Mengawal**.
- Frame guardian sebagai ""kawan yang mengawal"", bukan ""pengawas"".
- Di semua CTA dan empty-state, tonjolkan kesetaraan & persetujuan eksplisit
  (setiap akses guardian selalu tercatat & bisa dilihat di Log Sistem).
