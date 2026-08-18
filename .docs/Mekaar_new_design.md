# 🎨 MEKAAR — Design System

> **Clean Core, Colorful Room, Focused SOS** — dokumen desain untuk aplikasi chat & keamanan personal MEKAAR.
> Versi ini adalah **koreksi arah**: banyak elemen di iterasi sebelumnya (gradien navy di semua layar, 4 tema waktu, maskot di mana-mana) sudah bergeser terlalu jauh dari niat awal. Dokumen ini menata ulang MEKAAR jadi tiga register yang jelas dan tidak saling bocor: **Core** yang tenang, **Chat Room** yang boleh riuh, dan **SOS** yang mengambil alih keduanya saat darurat.

---

## 1. Visi & Filosofi Desain

MEKAAR punya tiga "ruangan" dengan kepribadian berbeda, dan ketiganya **tidak boleh terasa sama**:

| Komponen | Terasa seperti | Cakupan |
|---|---|---|
| **Core** 🤍 | Aplikasi yang rapi dan bisa dipercaya — lega, minimalis, tenang | Splash, Onboarding, Login/PIN, Home/Active Chats (chrome-nya, bukan isi bubble), Guardian, Security Logs, Settings, semua sheet & dialog |
| **Chat Room** 🎨 | Ruang personal tiap obrolan — ekspresif, colorful, boleh rame | Isi layar chat: wallpaper, bubble, animasi reaksi — sesuai preset tema yang dipilih user per-chat |
| **SOS** 🚨 | Satu fokus, satu warna, tanpa distraksi — bukan "tegas" a la Core, tapi mode darurat murni | Layar SOS aktif, Panic Button, streaming darurat, Device Lost Mode — **mengambil alih tampilan** dari Core maupun Chat Room selama aktif |

**Kuncinya:** Core adalah *rumah* — netral dan konsisten di mana pun user berada di app. Chat Room adalah *kamar* — user bebas dekorasi sesuai selera lewat preset tema, dan setiap kamar boleh terlihat beda satu sama lain. SOS bukan bagian dari Core maupun Chat Room — ia adalah **lapisan override** yang menimpa keduanya: begitu SOS aktif, warna brand Core (`brand.blue`) dan preset Chat Room apa pun yang sedang dipakai sama-sama ditarik, digantikan sepenuhnya oleh palet SOS (lihat §9).

### Prinsip Desain

1. **Tiga batas tegas, satu arah override.** Warna/gradien ekspresif hanya boleh hidup di dalam layar Chat Room; Core selalu netral; SOS menimpa keduanya saat aktif. Override cuma jalan satu arah — SOS bisa menimpa Core & Chat Room, tapi Core/Chat Room tidak pernah "meminjam" warna SOS di luar konteks darurat.
2. **Breathable di Core.** Ruang napas adalah fitur utama Core: padding lega, satu fokus per layar, tanpa dekorasi yang tidak perlu.
3. **Netral bukan berarti hambar.** Core tetap punya identitas lewat warna brand (`brand.blue`) sebagai satu-satunya aksen dominan — dipakai konsisten untuk CTA, state aktif, dan link.
4. **Ekspresif itu pilihan, bukan default liar.** Chat Room boleh colorful, tapi tetap lewat preset yang sudah dirancang (bukan warna bebas tanpa kurasi) — lihat §10.
5. **Rounded & friendly, di Core maupun Chat Room.** Radius besar tetap dipakai di Core (kartu, tombol, input) maupun Chat Room (bubble) — ini elemen yang menyatukan keduanya sebagai satu produk. SOS sengaja terkecuali dari sebagian aturan ini demi urgensi (lihat §9).
6. **Warna semantik itu suci.** `sos.coral` = bahaya, `safe.teal` = terlindungi, `warn.amber` = peringatan — tidak pernah dipakai sebagai warna dekoratif di preset Chat Room manapun.

---

## 2. Design Tokens — Warna

### 2.1 Brand Core (sumber tunggal — dari brand guideline terbaru)

Empat warna ini adalah identitas resmi MEKAAR dan basis seluruh Core UI. Semua turunan warna Core (surface, text, state) diturunkan dari sini — jangan menambah warna brand baru di luar keempat ini.

| Token | Hex | RGB | Pemakaian |
|---|---|---|---|
| `brand.blue` | `#136CFC` | 19, 108, 252 | Warna primer tunggal — CTA, tombol utama, link, state aktif/terpilih, ring fokus. Satu-satunya warna "hidup" di Core UI. |
| `brand.darkBlue` | `#152641` | 21, 38, 65 | Canvas & surface gelap (dark mode), teks utama di atas latar terang |
| `brand.green` | `#C3F84A` | 195, 248, 74 | Aksen sukses/highlight sekunder — dipakai sangat sedikit (badge online, konfirmasi ringan). Bukan warna kedua yang bersaing dengan `brand.blue`. |
| `brand.lightBlue` | `#E8F4FC` | 232, 244, 252 | Surface & background terang (light mode), latar kartu sekunder di dark mode |

### 2.2 Warna Semantik (Protective — dipertahankan, tidak berubah)

| Token | Hex | Pemakaian |
|---|---|---|
| `sos.coral` 🚨 | `#FF5D5D` | Tombol SOS, banner darurat, semua affordance berbahaya |
| `sos.deep` | `#D92632` | Teks/aksen darurat di atas latar terang |
| `safe.teal` 🛡️ | `#2DD4BF` | Status Guardian aktif, "kamu terlindungi", log sukses |
| `warn.amber` | `#FBBF24` | Peringatan non-fatal (lockout PIN, izin tertunda) |

### 2.3 Netral & Teks (Core UI)

| Token | Light mode | Dark mode |
|---|---|---|
| `surface.canvas` | `brand.lightBlue` `#E8F4FC` | `brand.darkBlue` `#152641` |
| `surface.card` | `#FFFFFF` | `#1E304F` *(darkBlue + sedikit terang, bukan hitam pekat)* |
| `text.primary` | `brand.darkBlue` `#152641` | `#F4F9FF` |
| `text.secondary` | `#5C6B85` | `#9FB0C9` |
| `text.onBlue` | `#FFFFFF` | `#FFFFFF` |
| `border.subtle` | `#DCE7F5` | `#25395B` |

Tidak ada lagi gradien kanvas di Core UI. `surface.canvas` **flat**, bukan gradien — inilah wujud "clean, breathable, minimalist".

### 2.4 Aturan Kontras (Wajib)

- Teks di atas `brand.blue`: selalu putih (`text.onBlue`), kontras ≥ 4.5:1.
- `brand.green` tidak pernah dipasangkan dengan teks putih — selalu teks `brand.darkBlue` di atasnya.
- Warna semantik (SOS/safe/warn) tidak pernah transparan di atas latar Core.

---

## 3. Sistem Tema Core UI (Disederhanakan)

**Perubahan paling penting di dokumen ini:** 4 tema berbasis waktu (Pagi/Siang/Sore/Malam dengan palet & gradien masing-masing) **dihapus sepenuhnya**. Diganti dengan sistem 2 tema standar + 1 mode otomatis — pola yang sudah familiar di hampir semua aplikasi.

| Mode | Perilaku |
|---|---|
| **Light** | `surface.canvas` = `brand.lightBlue`, teks `brand.darkBlue`, tetap aktif sepanjang hari sampai user ganti manual |
| **Dark** | `surface.canvas` = `brand.darkBlue`, teks `#F4F9FF`, tetap aktif sepanjang hari sampai user ganti manual |
| **Auto** | Mengikuti jam device: **06.00–17.59 → Light**, **18.00–05.59 → Dark**. Hanya dua state (light/dark), tidak ada palet transisi Pagi/Sore/dst. |

- Tidak ada lagi gradien kanvas per-waktu (`canvasMorning`, `canvasAfternoon`, `canvasEvening` — semua **dihapus**). `canvasDark`/`canvasLight` versi flat dari `brand.darkBlue`/`brand.lightBlue` yang tersisa.
- Tidak ada lagi 4 opsi manual di Pengaturan Tema — hanya 3 pilihan: **Light / Dark / Otomatis**.
- Transisi mode (manual maupun saat Auto berpindah jam) pakai crossfade halus 200ms, bukan animasi gradien bergeser.
- Mode SOS tetap **override** di atas mode apa pun (lihat §9) — ini satu-satunya pengecualian warna di luar 3 mode di atas.

---

## 4. Tipografi

Tidak berubah dari fondasi sebelumnya — tetap dipertahankan di kedua ruangan untuk konsistensi produk.

| Peran | Font | Weight | Catatan |
|---|---|---|---|
| **Display / Wordmark** | Plus Jakarta Sans | 800 (ExtraBold) | Wordmark "Mekaar" satu warna `brand.blue`, tracking sedikit rapat (-2%) |
| **Heading** | Plus Jakarta Sans | 700 | Nama layar, judul sheet |
| **Body / Chat** | Plus Jakarta Sans | 400–500 | Isi pesan, nyaman dibaca lama |
| **Label / Caption** | Plus Jakarta Sans | 500–600 | Timestamp, badge, meta |

### Skala Type

| Style | Size | Line-height | Pemakaian |
|---|---|---|---|
| `display` | 32 | 40 | Onboarding headline |
| `h1` | 24 | 32 | Judul layar |
| `h2` | 18 | 26 | Header seksi |
| `body` | 15 | 22 | Isi chat bubble, teks Core |
| `label` | 13 | 18 | Nama kontak, label tombol |
| `caption` | 11.5 | 16 | Timestamp, badge kecil |

Micro-copy Core UI: singkat dan jelas, tidak perlu maksa gaul (*"Masukkan PIN kamu"*, bukan *"Yuk masukin PIN-nya!"*). Micro-copy **di dalam Chat Room** boleh lebih santai mengikuti preset yang aktif.

---

## 5. Ikon & Emoji

- **Style ikon (Core UI):** rounded, stroke 2px, ujung membulat (SolarIcons) — konsisten di semua layar Core, termasuk ikon keamanan (PIN, log, SOS).
- **Emoji:** dipakai fungsional di kedua ruangan (badge status ✔️/👑, dot online) — tapi **maskot ilustrasi** (karakter kadal MEKAAR) dibatasi ketat berdasarkan **state**, bukan lokasi layar:
  - **Muncul** saat: Splash, Onboarding, dan **setiap empty state** — baik di Core UI (mis. "Belum Ada Rute Perjalanan", "Belum ada chat Guardian") maupun di dalam Chat Room (mis. "Belum Ada Pesan"). Patokannya: tidak ada konten untuk ditampilkan → maskot mengisi kekosongan itu supaya terasa ramah, bukan hampa.
  - **Tidak muncul** saat: layar chrome yang sudah berisi konten (Settings/Pengaturan, list yang terisi), SOS, Security Logs, PIN Lock (kecuali pose "sedih" khusus saat lockout, lihat §8.3).
  - **Pose disesuaikan konteks emosional**, bukan satu pose generik untuk semua: melambai+confetti untuk sambutan (Splash/Onboarding), memeluk pin lokasi untuk empty state fitur lokasi, tidur di atas speech-bubble untuk empty state "belum ada aktivitas" (chat kosong, Guardian kosong), sedih untuk lockout PIN. Tambah pose baru sesuai kebutuhan fitur, tapi tetap satu karakter yang sama secara konsisten.
- **Avatar & Status Ring:** avatar bulat, ring tipis 2–3px pakai `brand.blue` untuk state aktif/dipilih; dot status: `brand.green` online, abu offline, `sos.coral` SOS aktif (berdenyut).

---

## 6. Grid, Spacing, Radius, Elevation

- **Grid:** 8pt base. Spacing scale: `4, 8, 12, 16, 24, 32, 48`.
- **Padding layar:** 20px samping, 16px atas-bawah — breathable, konsisten di semua layar Core.
- **Jarak antar kartu:** minimal 12px. Tidak ada kartu dempet.

| Token | Nilai | Pemakaian |
|---|---|---|
| `radius.sm` | 12 | Chip, badge |
| `radius.md` | 18 | Input bar, kartu kecil |
| `radius.lg` | 24 | Kartu list, sheet |
| `radius.pill` | 999 | Tombol, FAB, search bar, avatar |

- **Elevation Core:** shadow lembut & tipis (`0 4px 16px rgba(21, 38, 65, 0.06)`), bukan shadow besar ala kartu "mengambang di atas gradien" — karena kanvas sekarang flat, shadow berat jadi berlebihan.
- **Touch target:** minimal 44×44 dp.

---

## 7. Komponen Inti — Core UI

### 7.1 Tombol

| Varian | Spec |
|---|---|
| **Primary** | Pill, fill `brand.blue`, teks `text.onBlue` 15px/700, tinggi 52px. Pressed: scale 0.97 |
| **Secondary (outline)** | Pill, border 1.5px `brand.blue`, teks `brand.blue`, fill transparan |
| **Destructive** | Pill, fill `sos.coral`, teks putih — hanya aksi bahaya/hapus |
| **FAB** | Bulat 56px, fill `brand.blue`, ikon putih, shadow lembut, posisi di atas bottom nav |

### 7.2 Home — Active Chats

- Header: judul layar (h1, `text.primary`) + baris status/aksi di kanan — badge status keamanan (mis. "Aegis E2EE", pill `safe.teal` tipis), ikon shield/privasi, dan **ikon cari** (bukan pill search bar penuh). Search tetap tersedia tapi sebagai *entry point* ikon 44×44dp yang membuka layar/overlay pencarian — bukan input field yang selalu terbuka di badan layar. Ini konsisten dengan prinsip breathable: chrome atas tetap ringkas, ruang di bawahnya murni untuk daftar chat.
- Filter/tab (mis. Semua / Guardian / Arsip): segmented pill `radius.pill`, tab aktif fill `brand.darkBlue` teks putih, tab non-aktif teks `text.secondary` tanpa fill — mengambang di atas track abu tipis.
- Daftar: kartu `surface.card` `radius.lg`, jarak 12px, avatar + ring, nama + badge, preview 1 baris `text.secondary` (ikon lock kecil untuk indikasi E2EE), timestamp + unread pill `brand.blue`.
- **Penting:** preview chat di list ini tetap netral Core (tidak menampilkan warna preset Chat Room masing-masing kontak) — konsistensi list lebih penting daripada preview personalisasi.
- FAB ganda di pojok kanan-bawah: FAB utama (chat baru) `brand.blue`; FAB **SOS** terpisah di kiri-bawah, selalu merah (`sos.coral`) dengan glow lembut — satu-satunya elemen yang boleh "menyala" di luar mode SOS aktif, karena aksesnya harus instan dari mana pun di Home.

### 7.3 Input Bar (Core chrome, dipakai juga sebagai bar di atas Chat Room)

- Pill `surface.card`, border `border.subtle`, ikon `text.secondary`, placeholder netral.
- Bar ini **selalu Core-style** meski berada di layar Chat Room yang lagi pakai preset colorful — supaya area ketik tetap familiar & bisa dibaca terlepas dari preset tema aktif.
- Search mengikuti pola ikon di §7.2: dipicu dari ikon di header, bukan pill input yang permanen mengambil ruang di badan layar.

### 7.4 Bottom Navigation

- Bar `surface.card` `radius.lg` mengambang 12px di atas tepi bawah, shadow lembut; item aktif = ikon `brand.blue` + label; item non-aktif = `text.secondary`.

### 7.5 Sheet & Toast

- Bottom sheet `surface.card` `radius.lg` atas, drag-handle pill; scrim gelap 40% transparan.
- Toast: pill `brand.darkBlue`, teks putih, singkat — *"Terkirim"*, *"Pesan dihapus"*.

---

## 8. Guardian & Security Logs (Core)

Bagian dari Core — tegas dan jujur, tapi tetap netral, tidak mengambil alih layar seperti SOS.

### 8.1 Guardian Mode 🛡️
- Aksen `safe.teal`: banner status Guardian + sisa durasi 30 hari sebagai progress pill.
- Role swap: kartu dua arah, butuh persetujuan dua pihak (state `pending` = chip `warn.amber`).
- Izin dijelaskan jelas dan jujur, tanpa perlu bahasa berlebihan.

### 8.2 Security Logs 📋
- Gaya "receipt feed": kartu `surface.card`, tiap entri ikon semantik (🗑️ hapus, 🚨 SOS, 📍 GPS, 🎤 mic) + timestamp presisi.
- Entri "log dihapus" tetap muncul sebagai entri baru dengan chip `warn.amber` — transparansi adalah fitur.
- Tidak ada warna playful di sini; `safe.teal` untuk aksi aman, `sos.coral` untuk SOS.

### 8.3 PIN Lock 🔒
- 6 dot besar, terisi `brand.blue` saat digit masuk; numpad custom bulat, haptic tiap tap.
- Salah: shake + dot jadi `sos.coral`; 5× salah → layar lockout `warn.amber` dengan countdown 30 menit.
- Auto-lock: blur seluruh layar saat app ke background.

---

## 9. SOS Mode — Register Ketiga 🚨

SOS **bukan** varian tegas dari Core — ia komponen terpisah dengan aturan sendiri, dan satu-satunya tempat di seluruh app di mana satu warna boleh mengambil alih total, menimpa Core maupun preset Chat Room yang sedang aktif.

- **Trigger:** Panic Button bisa diakses instan dari Home (FAB merah, §7.2) maupun PIN Lock (§8.3) — tidak perlu masuk ke menu apa pun dulu.
- **Override total:** begitu aktif, kanvas → `sos.coral`/`sos.deep` solid (bukan gradien majemuk), aksen `brand.blue` Core ditarik, preset Chat Room apa pun (jika user sedang di dalam chat) ikut ditimpa — hanya coral + putih yang tersisa di layar.
- **Panic Button:** pill coral 72px, pulsasi `scale 1.0 ↔ 1.08` 1200ms + ring ripple; haptic berat saat ditekan-tahan 2 detik.
- **Peta & streaming:** peta OSM full-bleed dengan pin denyut; status streaming audio/video dalam chip putih tegas.
- **Watchdog inactivity** (2 menit): banner `warn.amber` + countdown.
- **Device Lost Mode** ikut register ini: peta + tombol aksi vertikal besar (Bunyikan Alarm, Kunci & Tampilkan Pesan, Lihat Lokasi Terakhir) — tetap palet coral+putih, bukan palet Core.
- **Tidak ada** emoji dekoratif, tidak ada maskot, tidak ada animasi playful, tidak ada radius/rounded playful yang berlebihan. Urgensi = kejelasan, bukan kehangatan.
- Begitu SOS diakhiri, transisi kembali ke Core/Chat Room pakai crossfade yang sama seperti pergantian mode (§3) — tidak ada animasi dramatis saat "keluar" dari darurat.

---

## 10. Chat Room — Sistem Preset (Tetap Ekspresif)

Ini wilayah di mana MEKAAR boleh colorful. **Semua preset lama dipertahankan** — hanya satu yang diganti.

### 10.1 Preset yang dipertahankan

`neonDreams`, `comicPopArt`, `neumorphism`, `glassmorphism`, `pixelGarden`, `candyPop`, `retroWave`, `monoVibe`, `solarpunk`, `fireflyNight`, `diary`, `custom` — spesifikasi visual tiap preset (wallpaper, bubble style, palet bubble) **tidak berubah** dari implementasi yang sudah ada. Dokumen ini tidak mendefinisikan ulang detail visual masing-masing preset tersebut.

### 10.2 Preset yang diganti: `dynamicTime` → `mekaar` (Clean Theme)

Preset lama `dynamicTime` (wallpaper & bubble yang berubah warna otomatis ikut 4 palet waktu) **dihapus**, karena bergantung pada sistem tema waktu yang sudah tidak ada (§3). Sebagai gantinya, preset baru **`mekaar`** — tema bawaan/default Chat Room yang selaras dengan wajah baru Core UI:

| Elemen | Spec |
|---|---|
| Wallpaper | Solid `surface.canvas` (ikut mode Light/Dark aktif — bukan lagi 4 waktu) |
| Bubble keluar | Fill `brand.blue`, teks putih |
| Bubble masuk | Fill `surface.card` (light) / `#25395B` (dark), teks `text.primary`, border tipis `border.subtle` |
| Aksen | `brand.green` dipakai sangat tipis untuk status/reaksi ringan — bukan warna bubble |
| Gaya bubble | `modernPill` (radius besar, konsisten dengan §6) |

- `mekaar` menjadi **preset default** untuk chat baru (menggantikan posisi `dynamicTime` sebelumnya sebagai default).
- `mekaar` adalah satu-satunya preset yang secara sadar mengikuti mode Light/Dark Core UI — 11 preset lainnya tetap independen dari mode Core (identitas visual sendiri, seperti sebelumnya).
- Alias kompatibilitas lama (`neonCyberpunk`, `isometric3d`, `retroY2K`, `swissMinimalist`) tetap dipertahankan untuk data existing user, tidak perlu migrasi paksa.

---

## 11. Motion & Haptics

| Interaksi | Spec |
|---|---|
| Transisi layar (Core) | `easeOutCubic` 200–250ms, fade + slide 12px |
| Ganti mode Light/Dark/Auto | Crossfade 200ms, tanpa animasi gradien bergeser |
| Kartu/bubble masuk | Spring `damping 14, stiffness 180`, stagger 40ms |
| Tombol press | Scale → 0.97, 120ms |
| Breathing SOS | Scale 1.0↔1.08 + ripple, loop 1200ms |
| Reaksi emoji (Chat Room) | Float-up 24px + fade, 600ms |

- **Haptics:** `lightImpact` (tap, reaksi), `selectionClick` (toggle), `heavyImpact` + pola berulang (SOS). Selalu sediakan toggle "Kurangi Haptic".
- Hormati **Reduce Motion**: semua spring diganti fade 150ms; denyut SOS diganti opacity pulse (tetap terlihat).

---

## 12. Aksesibilitas

- Kontras minimal **4.5:1** untuk body text di Core UI, cek di kedua mode (Light & Dark).
- Dynamic type sampai 130% tanpa memotong bubble atau kartu.
- Semua aksi warna-semantik punya label teks/ikon (jangan mengandalkan warna saja — SOS selalu ada label "SOS").
- TalkBack/VoiceOver: urutan fokus logis; reaksi emoji terbaca ("Reaksi 😂 dari Kai").
- `tooltip` wajib di setiap `IconButton` tanpa label teks.

---

## 13. Implementasi Flutter (mapping cepat)

```dart
// lib/core/constants/colors.dart
abstract class AppColors {
  // Brand core — sumber tunggal
  static const blue = Color(0xFF136CFC);
  static const darkBlue = Color(0xFF152641);
  static const green = Color(0xFFC3F84A);
  static const lightBlue = Color(0xFFE8F4FC);

  // Protective (tidak berubah)
  static const sosCoral = Color(0xFFFF5D5D);
  static const sosDeep = Color(0xFFD92632);
  static const safeTeal = Color(0xFF2DD4BF);
  static const warnAmber = Color(0xFFFBBF24);

  // Text & surface
  static const textOnBlue = Colors.white;
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF1E304F);
}
```

- **Hapus** `TimePalette` (morning/afternoon/evening/night), `time_theme_helper.dart`, `theme_resolver.dart` versi 4-palet, dan gradien `canvasMorning`/`canvasAfternoon`/`canvasEvening` dari `colors.dart` (§3).
- **Ganti** dengan `ThemeMode` standar Flutter (`light`/`dark`/`system`) — mode "Otomatis" dihitung sendiri lewat cutoff jam 06.00/18.00, **bukan** `ThemeMode.system` bawaan OS (karena requirement-nya spesifik jam, bukan preferensi sistem).
- **Chat Room** tetap pakai `ChatThemePreset` enum yang sudah ada di `chat_theme_model.dart`; cukup:
  - hapus/nonaktifkan `ChatThemePreset.dynamicTime` dan `WallpaperType.dynamicTime`,
  - tambahkan `ChatThemePreset.mekaar` sesuai spec §10.2,
  - ubah default `ChatThemePreference()` dari `preset: ChatThemePreset.dynamicTime` → `preset: ChatThemePreset.mekaar`.
- **SOS** diimplementasikan sebagai komponen terpisah dari Core: satu `SosTheme` yang di-wrap via Riverpod `StateNotifierProvider` saat SOS aktif, menimpa `ThemeData` Core dan `ChatThemePreference` Chat Room manapun yang sedang aktif — bukan variasi `ThemeMode` maupun `ChatThemePreset` biasa. Struktur ini sudah sesuai `lib/features/sos/`; dokumen §9 adalah spec visualnya.

---

## 14. Do & Don't

| ✅ Do | ❌ Don't |
|---|---|
| Core UI flat, netral, satu aksen (`brand.blue`) | Gradien kanvas di layar Core mana pun |
| 3 pilihan tema: Light / Dark / Otomatis (jam) | 4 palet waktu (Pagi/Siang/Sore/Malam) |
| Chat Room bebas colorful lewat preset yang dikurasi | Warna bebas tanpa preset di Chat Room |
| Preset `mekaar` sebagai default yang senada dengan Core | Preset default yang berubah warna otomatis ikut jam (`dynamicTime`) |
| Maskot muncul di state kosong (Core maupun Chat Room), pose sesuai konteks | Maskot di layar chrome berisi konten (Settings), SOS, atau Security Logs |
| Warna semantik (SOS/safe/warn) khusus fungsi, tidak dekoratif | Coral/teal/amber dipakai sebagai warna preset Chat Room |
| Shadow lembut & tipis di atas kanvas flat | Shadow berat ala "kartu mengambang di atas gradien" |
| SOS menimpa total Core & Chat Room saat aktif — satu palet, satu fokus | SOS ikut warna preset Chat Room atau mode Light/Dark yang sedang aktif |
| Guardian & Security Logs tetap netral Core meski kontennya serius | Guardian/Security Logs dibuat semenimpa SOS — keduanya bukan mode darurat |

---

*Dokumen ini adalah single source of truth untuk bahasa visual MEKAAR — versi konsolidasi setelah koreksi arah. Core UI tenang dan bisa dipercaya; Chat Room adalah tempat ekspresi ada.* 🤍🎨
