# 🎨 MEKAAR 3.0 — Design System

> **Youth · Playful · Modern** — Dokumen desain untuk aplikasi chat & keamanan personal MEKAAR.
> Terinspirasi dari referensi *"Fun Chatting App UI/UX"* (gaya VibeChat): kanvas gradien navy gelap, aksen elektrik, maskot blob, dan bubble yang membulat — diterjemahkan ke konteks MEKAAR yang punya dua sisi: **seru untuk ngobrol, sigap untuk melindungi**.

---

## 1. Visi & Filosofi Desain

MEKAAR punya kepribadian ganda yang harus terasa di setiap piksel:

| Sisi | Terasa seperti | Kapan muncul |
|---|---|---|
| **Playful** 🎉 | Nongkrong bareng bestie — ringan, colorful, penuh emoji | Chat harian, stories ring, media view-once |
| **Protective** 🛡️ | Teman yang selalu siaga — tegas, jelas, tidak panik | Mode SOS, Guardian, Security Logs, PIN |

**Kuncinya:** satu design system, dua *register* visual. Mode normal boleh se-playful mungkin; saat SOS aktif, dekorasi minggir — yang tersisa hanya kejelasan dan urgensi.

### Prinsip Desain

1. **Fun di permukaan, serius di fondasi.** Warna cerah dan maskot lucu di luar; keamanan berlapis yang tidak perlu terlihat menakutkan di dalam.
2. **Breathable.** Ruang napas adalah fitur. Tidak ada kartu yang berdempetan; setiap layar punya satu fokus utama.
3. **Color with meaning.** Kuning = aksi & ekspresi diri. Cyan = koneksi. Ungu = pesan masuk. Coral = bahaya/SOS. Teal = aman/terlindungi. Warna tidak pernah sekadar hiasan.
4. **Rounded & friendly.** Radius besar di mana-mana — tombol pill, bubble membulat, kartu mengambang. Tidak ada sudut tajam kecuali indikator urgensi.
5. **Emoji-native.** Emoji bukan stiker tempelan, tapi warga kelas satu di UI: status, badge, reaksi, dan micro-copy.
6. **Motion = personality.** Semua interaksi memakai spring yang memantul halus — aplikasi terasa hidup, tidak kaku.

---

## 2. Design Tokens — Warna

### 2.1 Kanvas (Dark-First)

Pengalaman utama MEKAAR adalah **dark mode gradien navy** — inilah yang membuat aksen elektrik "menyala".

| Token | Hex | Pemakaian |
|---|---|---|
| `canvas.top` | `#161839` | Gradien atas layar |
| `canvas.mid` | `#1E2A63` | Gradien tengah |
| `canvas.bottom` | `#2E63B8` | Gradien bawah (jangan pernah flat — selalu gradien vertikal halus) |
| `surface.card` | `#FFFFFF` | Kartu mengambang (chat list, sheet) di atas kanvas gelap |
| `surface.cardDark` | `#232A52` | Kartu sekunder yang tetap gelap (opsi, menu) |
| `surface.overlay` | `#0F1230` @ 70% | Scrim di belakang modal/bottom sheet |

### 2.2 Aksen Elektrik (Playful)

| Token | Hex | Pemakaian |
|---|---|---|
| `brand.yellow` ⚡ | `#FFD84D` | CTA utama, FAB, wordmark "Mek", bubble keluar, indikator aktif |
| `brand.cyan` 💧 | `#38BDF8` | Wordmark "aar", link, tombol outline (Log In), ikon mic, header seksi |
| `brand.purple` 🔮 | `#8B5CF6` | Bubble masuk (gradien ke `#A78BFA`), ring avatar, notif badge sekunder |
| `brand.pink` 🌸 | `#F472B6` | Reaksi, sticker aksen, ring avatar alternatif, maskot |
| `brand.lime` 🍀 | `#A3E635` | Status online, indikator sukses ringan |

### 2.3 Warna Semantik (Protective)

| Token | Hex | Pemakaian |
|---|---|---|
| `sos.coral` 🚨 | `#FF5D5D` | Tombol SOS, banner darurat, semua affordance berbahaya |
| `sos.deep` | `#D92632` | Gradien bawah mode SOS, teks darurat di atas putih |
| `safe.teal` 🛡️ | `#2DD4BF` | Status Guardian aktif, "kamu terlindungi", log sukses |
| `warn.amber` | `#FBBF24` | Peringatan non-fatal (lockout PIN, izin tertunda) |

### 2.4 Teks & Netral (di atas kanvas gelap)

| Token | Hex | Pemakaian |
|---|---|---|
| `text.primary` | `#F8FAFF` | Judul, nama kontak |
| `text.secondary` | `#A9B4D8` | Timestamp, preview pesan, caption |
| `text.onYellow` | `#2B2400` | Teks di atas tombol kuning (jangan putih!) |
| `text.onCard` | `#1B2145` | Teks di atas kartu putih |
| `text.onCardSub` | `#6B7599` | Sub-teks di atas kartu putih |

### 2.5 Aturan Kontras (Wajib)

- Teks di atas kanvas gradien: selalu `text.primary`/`text.secondary` — cek kontras di titik gradien **paling terang** (`#2E63B8`), bukan hanya yang paling gelap.
- Kuning `#FFD84D` hanya berpasangan dengan teks gelap `#2B2400`.
- Coral SOS di atas kanvas gelap selalu solid, tidak pernah transparan.

---

## 3. Tipografi

| Peran | Font | Weight | Catatan |
|---|---|---|---|
| **Display / Wordmark** | Plus Jakarta Sans | 800 (ExtraBold) | Wordmark "Mek**aar**": dua warna (kuning + cyan), tracking sedikit rapat (-2%) |
| **Heading** | Plus Jakarta Sans | 700 | Nama layar, judul sheet |
| **Body / Chat** | Plus Jakarta Sans | 400–500 | Isi pesan, nyaman dibaca lama |
| **Label / Caption** | Plus Jakarta Sans | 500–600 | Timestamp, badge, meta |

> Fallback: `Nunito` (lebih bulat, makin playful) atau `Poppins`. Hindari font serif dan font sistem default yang kaku.

### Skala Type

| Style | Size | Line-height | Pemakaian |
|---|---|---|---|
| `display` | 32 | 40 | Onboarding headline |
| `h1` | 24 | 32 | Judul layar |
| `h2` | 18 | 26 | Header seksi ("Active Chats") |
| `body` | 15 | 22 | Isi chat bubble |
| `label` | 13 | 18 | Nama kontak, label tombol |
| `caption` | 11.5 | 16 | Timestamp, badge kecil |

Micro-copy memakai bahasa gaul-sopan: *"Guess what?!"* boleh; *"Pesan Anda telah terkirim"* jangan. Contoh: `Ketik pesan...` → `Ketik yang seru... 💬`.

---

## 4. Ikon, Emoji & Maskot

### 4.1 Ikon
- Style: **rounded, stroke 2px, ujung membulat** (Lucide/Hugeicons Rounded).
- Ikon keamanan (PIN, log, SOS) boleh sama rounded-nya — aman tidak harus terlihat galak.

### 4.2 Emoji sebagai Sistem
- **Badge status** di samping nama: ✔️ terverifikasi, 👑 Guardian, 🟢 online (dot lime).
- **Reaksi pesan**: long-press bubble → emoji reaksi melayang (float-up + fade) dengan haptic ringan.
- **Empty states** selalu pakai emoji besar + maskot, bukan ilustrasi kosong abu-abu.

### 4.3 Maskot "Meka & Geng" 🫧
Tiga blob bulat (kuning `#FFD84D`, cyan `#38BDF8`, pink `#F472B6`) dengan wajah happy dan speech bubble — dipakai di:
- Onboarding & splash screen
- Empty state (belum ada chat, belum ada Guardian)
- Layar sukses ("Guardian ditambahkan! 🎉")
- **Tidak pernah** muncul di mode SOS atau Security Logs.

### 4.4 Avatar & Status Ring
- Avatar bulat dengan **gradien ring 3px** (rotasi: kuning→pink, cyan→ungu, dst. — tiap user dapat kombo konsisten dari hash ID-nya).
- Dot status: lime `online`, abu `offline`, coral `SOS aktif` (berdenyut).

---

## 5. Grid, Spacing, Radius, Elevation

- **Grid:** 8pt base. Spacing scale: `4, 8, 12, 16, 24, 32, 48`.
- **Padding layar:** 20px samping, 16px atas-bawah — breathable.
- **Jarak antar kartu:** minimal 12px. Tidak ada kartu dempet.

| Token | Nilai | Pemakaian |
|---|---|---|
| `radius.sm` | 12 | Chip, badge |
| `radius.md` | 18 | Bubble chat, input bar |
| `radius.lg` | 24 | Kartu chat list, sheet |
| `radius.pill` | 999 | Tombol, FAB, search bar, avatar |

- **Elevation:** kartu putih di atas kanvas gelap → `shadow: 0 12px 32px rgba(10, 12, 40, 0.35)`, tanpa border. Kartu terasa *mengambang*.
- **Touch target:** minimal 48×48 dp.

---

## 6. Komponen Inti

### 6.1 Tombol
| Varian | Spec |
|---|---|
| **Primary** | Pill, fill `brand.yellow`, teks `text.onYellow` 15px/700, tinggi 54px. Pressed: scale 0.97 + haptic ringan |
| **Secondary (outline)** | Pill, border 2px `brand.cyan`, teks cyan, fill transparan |
| **Destructive** | Pill, fill `sos.coral`, teks putih — hanya untuk aksi bahaya/hapus |
| **FAB** | Bulat 60px, fill kuning, ikon `+` gelap, shadow besar, posisi di atas bottom nav |

### 6.2 Chat List Card
- Kartu putih `radius.lg` mengambang di atas kanvas: avatar + ring, nama (label/700) + badge emoji, preview 1 baris (`text.onCardSub`), timestamp + unread pill kuning.
- Swipe kanan → aksi cepat (📌 pin, 🛡️ jadikan Guardian); swipe kiri → 🗑️ (konfirmasi sheet, bukan langsung hapus).

### 6.3 Message Bubble
| Arah | Style |
|---|---|
| **Keluar (aku)** | Fill `brand.yellow`, teks gelap, tail kanan-bawah |
| **Masuk** | Gradien ungu `#8B5CF6 → #A78BFA` (135°), teks putih, tail kiri-bawah |
| **View-once** | Thumbnail di-blur 24px + overlay ikon 👁️ + label *"Ketuk untuk lihat (1x)"*; setelah dibuka → blur permanen + caption *"Udah dilihat ✨"* |
| **Pesan sistem** | Pill abu transparan di tengah, caption — mis. *"Kamu menghapus pesan ini • tercatat di log"* |

### 6.4 Input Bar
- Pill putih `radius.pill`: ikon emoji kiri, placeholder `Ketik yang seru...`, ikon mic cyan kanan.
- Saat merekam voice note: bar berubah jadi waveform anim cyan + timer + slide-to-cancel.

### 6.5 Search Bar
- Pill putih di atas kanvas gelap, ikon 🔍, placeholder `Cari teman atau chat...`.

### 6.6 Bottom Navigation
- Bar gelap `surface.cardDark` `radius.lg` mengambang 12px di atas tepi bawah; item aktif = ikon kuning + pill indikator; label caption.

### 6.7 Sheet & Toast
- Bottom sheet putih `radius.lg` atas, drag-handle pill; scrim `surface.overlay`.
- Toast: pill gelap dengan emoji di depan — *"Terkirim! 🚀"*.

---

## 7. Desain per Fitur

### 7.1 Onboarding & Splash
- Logo wordmark **Mek** (kuning) + **aar** (cyan), maskot trio blob dengan speech bubble, tagline: *"Express Yourself. Stay Protected."*
- Page dots: aktif = pill kuning memanjang, non-aktif = outline.
- CTA: **Get Started!** (kuning) di atas **Log In** (outline cyan).

### 7.2 Home — Active Chats
- Atas: search bar → stories row (avatar + gradien ring + emoji badge) → header `Active Chats` (cyan, h2).
- Daftar: kartu putih mengambang, jarak 12px.
- FAB kuning `+` untuk chat baru.

### 7.3 Chat Room
- Header: back arrow, avatar + ring, nama + badge emoji (✔️/👑), ikon call & video.
- Bubble sesuai §6.3; reaksi emoji melayang saat long-press; haptic `selectionClick` tiap reaksi.
- Hapus pesan penuh: konfirmasi sheet → toast *"Pesan dihapus ✨"* + entri log otomatis (lihat §7.6).

### 7.4 Guardian Mode 🛡️
- Aksen utama `safe.teal`: banner *"Kamu saling menjaga dengan Mama"* + sisa durasi 30 hari sebagai progress pill.
- Role swap: kartu dua arah dengan animasi flip; butuh persetujuan dua pihak (state `pending` = chip amber).
- Izin dijelaskan dalam bahasa manusia: *"Mama cuma bisa lihat lokasi kalau kamu tekan SOS. Janji. 🤝"*

### 7.5 SOS Mode 🚨 — *Mode Shift*
Saat SOS aktif, **seluruh tema berpindah register**:
- Kanvas → gradien coral gelap (`#D92632 → #7F1D2B`), aksen kuning/cyan ditarik, hanya coral + putih.
- **Breathing Panic Button:** pill coral 72px, pulsasi `scale 1.0 ↔ 1.08` 1200ms + ring ripple keluar; haptic berat berulang saat ditekan-tahan 2 detik.
- Peta OSM full-bleed dengan pin denyut; status streaming audio/video dalam chip putih tegas.
- Watchdog inactivity (2 menit): banner amber *"Stream dijeda — tidak ada gerakan"* + countdown.
- Tidak ada maskot, tidak ada emoji dekoratif, tidak ada animasi playful. Urgensi = kejelasan.

### 7.6 Security Logs 📋
- Gaya **"receipt feed"**: kartu putih monospace-caption, tiap entri punya ikon semantik (🗑️ hapus, 🚨 SOS, 📍 GPS, 🎤 mic) + timestamp presisi.
- Entri "log dihapus" tetap muncul sebagai entri baru ber-chip amber *"penghapusan tercatat"* — transparansi adalah fitur, tunjukkan dengan bangga.
- Tidak ada warna playful di sini; teal untuk aksi aman, coral untuk SOS.

### 7.7 PIN Lock 🔒
- 6 dot besar (bukan kotak), terisi kuning saat digit masuk; numpad custom bulat dengan haptic tiap tap.
- Salah: shake + dot jadi coral; 5× salah → layar lockout amber dengan countdown 30 menit dan maskot sedih (satu-satunya tempat maskot boleh "sedih").
- Auto-lock: blur seluruh layar saat app ke background (app-switcher privacy).

### 7.8 Device Lost Mode 📱
- Peta + tombol aksi besar vertikal: **Bunyikan Alarm** (kuning), **Kunci & Tampilkan Pesan** (cyan), **Lihat Lokasi Terakhir** (outline).
- Pesan kustom di layar kunci perangkat hilang: kartu putih sederhana + tombol "Hubungi pemilik".

---

## 8. Motion & Haptics

| Interaksi | Spec |
|---|---|
| Transisi layar | `easeOutCubic` 250–300ms, fade + slide 16px |
| Kartu/bubble masuk | Spring `damping 14, stiffness 180`, stagger 40ms |
| Tombol press | Scale → 0.97, 120ms |
| FAB | Rotation 45° saat menu expand |
| Typing indicator | 3 dot bounce, loop 900ms |
| Breathing SOS | Scale 1.0↔1.08 + ripple, loop 1200ms |
| Reaksi emoji | Float-up 24px + fade, 600ms |

- **Haptics:** `lightImpact` (tap, reaksi), `selectionClick` (toggle), `heavyImpact` + pola berulang (SOS). Selalu sediakan toggle "Kurangi Haptic".
- Hormati **Reduce Motion**: semua spring diganti fade 150ms; denyut SOS diganti opacity pulse (tetap terlihat!).

---

## 9. Light Mode

Kanvas light = `#F4F7FF → #E3ECFF` (tetap gradien, tetap breathable). Kartu tetap putih dengan shadow lebih lembut; bubble masuk tetap gradien ungu (identitas!), bubble keluar tetap kuning. Teks `text.primary` → `#1B2145`. Mode SOS tidak berubah — coral bekerja di kedua tema.

---

## 10. Aksesibilitas

- Kontras minimal **4.5:1** untuk body text; cek di titik gradien paling terang.
- Dynamic type sampai 130% tanpa memotong bubble.
- Semua aksi warna-semantik punya label teks/ikon (jangan mengandalkan warna saja — mis. SOS selalu ada label "SOS").
- TalkBack/VoiceOver: urutan fokus logis; reaksi emoji terbaca ("Reaksi 😂 dari Kai").

---

## 11. Implementasi Flutter (mapping cepat)

Struktur sudah sesuai `lib/core/constants/`:

```dart
// lib/core/constants/app_colors.dart
abstract class AppColors {
  // Canvas
  static const canvasTop = Color(0xFF161839);
  static const canvasMid = Color(0xFF1E2A63);
  static const canvasBottom = Color(0xFF2E63B8);

  // Playful accents
  static const yellow = Color(0xFFFFD84D);
  static const cyan = Color(0xFF38BDF8);
  static const purple = Color(0xFF8B5CF6);
  static const purpleLight = Color(0xFFA78BFA);
  static const pink = Color(0xFFF472B6);
  static const lime = Color(0xFFA3E635);

  // Protective
  static const sosCoral = Color(0xFFFF5D5D);
  static const sosDeep = Color(0xFFD92632);
  static const safeTeal = Color(0xFF2DD4BF);
  static const warnAmber = Color(0xFFFBBF24);

  // Text & surfaces
  static const textPrimary = Color(0xFFF8FAFF);
  static const textSecondary = Color(0xFFA9B4D8);
  static const textOnYellow = Color(0xFF2B2400);
  static const card = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF232A52);
}
```

```dart
// Kanvas: selalu gradien, jangan pernah flat
const canvasGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.canvasTop, AppColors.canvasMid, AppColors.canvasBottom],
);

// Bubble masuk
const incomingBubbleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.purple, AppColors.purpleLight],
);
```

- Mode SOS diimplementasikan sebagai **theme override** (bukan warna hardcode): satu `SosTheme` yang di-wrap via Riverpod `StateNotifierProvider` saat SOS aktif.
- Font: tambahkan `plus_jakarta_sans` via `google_fonts` atau bundling aset di `pubspec.yaml`.

---

## 12. Do & Don't

| ✅ Do | ❌ Don't |
|---|---|
| Kanvas gradien navy yang bikin aksen menyala | Background flat atau putih polos |
| Satu warna aksen dominan per layar | Semua warna elektrik tampil bersamaan |
| Emoji & maskot untuk momen fun | Maskot/emoji di SOS & Security Logs |
| Kartu putih mengambang dengan shadow lembut | Kartu border tipis ala enterprise |
| Micro-copy gaul-sopan ("Ketik yang seru...") | Bahasa formal kaku ("Silakan mengisi kolom berikut") |
| Mode SOS tegas, minimalis, urgensi jelas | SOS tetap playful "biar konsisten" |
| Haptic halus di tiap interaksi kunci | Animasi panjang yang menghalangi aksi darurat |
| Hapus data → konfirmasi + toast + log | Hapus diam-diam tanpa jejak |

---

*Dokumen ini adalah single source of truth untuk bahasa visual MEKAAR 3.0. Kalau ragu: playful untuk hari biasa, tegas untuk hari darurat.* 🫧🛡️
