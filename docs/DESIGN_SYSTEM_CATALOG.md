# 📘 MEKAAR 3.0 — Design System Catalog & Agent Governance

> **Buku Pegangan Utama Agen AI & Pengembang:**
> Dokumen ini adalah Single Source of Truth (SSOT) teknis yang mengatur implementasi antarmuka (UI) pada aplikasi MEKAAR 3.0.
> **ATURAN MUTLAK:** Tidak ada pembuatan widget UI ad-hoc atau hardcoded styling di `lib/features/`. Seluruh komponen dan token WAJIB merujuk ke pustaka sentral `lib/core/`.

---

## 1. Protokol Gatekeeper: Aturan Penambahan / Perubahan Fitur

Sebelum menulis satu baris kode pun di `lib/features/`, setiap pengembang dan agen AI **WAJIB** mengikuti alur kerja (*State Machine*) berikut:

```
[Permintaan Fitur Baru]
         │
         ▼
[1. Audit Komponen & Token] ──(Apakah komponen / warna yang dibutuhkan sudah ada?)
         │
    ┌────┴───────────────────────────┐
   Ya                               Tidak
    │                                │
    │                                ▼
    │                     [2. PROTOKOL DESAIN SISTEM]
    │                     a. Perbarui `docs/DESIGN_SYSTEM_CATALOG.md`.
    │                     b. Buat token baru di `lib/core/constants/` ATAU
    │                        perluas widget sentral di `lib/core/widgets/`.
    │                     c. Ajukan Implementation Plan & minta persetujuan user.
    │                     d. Eksekusi pembaruan sentral setelah disetujui.
    │                                │
    └────────────────────────────────┘
                     │
                     ▼
[3. Implementasi Fitur di `lib/features/`]
   * Hanya merangkai komponen sentral dari `lib/core/`.
   * Zero hardcoding (tanpa `Color(0x...)`, tanpa raw `Scaffold`, `AppBar`, `Card`, dsb).
                     │
                     ▼
[4. Verifikasi Mekanis]
   * Jalankan `flutter test test/architecture/design_system_guardrail_test.dart`
   * Jalankan `flutter analyze`
   * Jalankan `flutter test`
```

---

## 2. Tabel Substitusi Komponen (Do & Don't)

Dilarang keras menggunakan widget bawaan Flutter jika padanan sentralnya sudah tersedia.

| Kebutuhan Antarmuka | ❌ DILARANG KERAS | ✅ WAJIB DIGUNAKAN | Path Impor Sentral |
|---|---|---|---|
| **Root Layar / Halaman** | `Scaffold(...)` | `MekaarScaffold(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_scaffold.dart';` |
| **Header Layar / Top Bar** | `AppBar(...)` | `CustomAppBar(...)` atau `MekaarTopBar(...)` | `import 'package:mekaar_chat/core/widgets/custom_app_bar.dart';`<br>`import 'package:mekaar_chat/core/widgets/mekaar_top_bar.dart';` |
| **Header Tab / Sub-seksi** | Header teks biasa | `MekaarTabHeader(...)` atau `MekaarSectionHeader(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_tab_header.dart';`<br>`import 'package:mekaar_chat/core/widgets/mekaar_section_header.dart';` |
| **Kartu / Kontainer Konten** | `Card(...)`, `Container(decoration: ...)` | `CustomCard(...)` | `import 'package:mekaar_chat/core/widgets/custom_card.dart';` |
| **Divider Kartu / Seksi** | `Divider(...)` mentah | `MekaarCardDivider(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_card_divider.dart';` |
| **Tile Info / Pengaturan** | `ListTile(...)` acak | `MekaarInfoTile(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_info_tile.dart';` |
| **Modal / Dialog Konfirmasi** | `AlertDialog(...)`, `showDialog(...)` | `MekaarDialog.showConfirmation(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_dialog.dart';` |
| **Lembar Bawah / Bottom Sheet** | `showModalBottomSheet(...)` | `MekaarBottomSheet.show(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_bottom_sheet.dart';` |
| **Notifikasi Snackbar / Toast** | `ScaffoldMessenger.showSnackBar(...)` | `MekaarSnackBar.show(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_snackbar.dart';` |
| **In-App Banner Notifikasi** | Banner overlay ad-hoc | `MekaarInAppNotificationBanner(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_in_app_notification_banner.dart';` |
| **Badge / Label Status** | Kontainer warna manual | `MekaarBadge(...)` atau `MekaarIconBadge(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_badge.dart';`<br>`import 'package:mekaar_chat/core/widgets/mekaar_icon_badge.dart';` |
| **Dot Indikator Belum Dibaca** | Titik merah/biru ad-hoc | `MekaarNotificationDot(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_notification_dot.dart';` |
| **Banner Peringatan / Info** | Kontainer peringatan ad-hoc | `MekaarBanner(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_banner.dart';` |
| **Live Safety / Trip Pill** | Pill floating buatan lokal | `MekaarLiveSafetyPill(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_live_safety_pill.dart';` |
| **Tombol Aksi Kritis / SOS** | Tombol standar tanpa proteksi | `HoldToConfirmButton(...)` atau `SOSButton(...)` | `import 'package:mekaar_chat/core/widgets/hold_to_confirm_button.dart';`<br>`import 'package:mekaar_chat/core/widgets/sos_button.dart';` |
| **Tombol Scroll ke Bawah** | Floating button ad-hoc | `ScrollToBottomButton(...)` | `import 'package:mekaar_chat/core/widgets/scroll_to_bottom_button.dart';` |
| **Avatar Pengguna / Kontak** | `CircleAvatar(...)` | `AvatarWidget(...)` | `import 'package:mekaar_chat/core/widgets/avatar.dart';` |
| **Field Pencarian** | `TextField` mentah dengan ikon search | `MekaarSearchField(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_search_field.dart';` |
| **Tombol Pencarian Header** | `IconButton` pencarian acak | `MekaarHeaderSearchButton(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_header_search_button.dart';` |
| **Segmented Switcher / Tab Pill** | TabBar biasa | `MekaarSlidingSegmentBar(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_sliding_segment_bar.dart';` |
| **Loading Skeleton** | `CircularProgressIndicator` acak | `MekaarSkeleton(...)` | `import 'package:mekaar_chat/core/widgets/skeletons.dart';` |
| **Empty / Error / Loading State**| Teks kosong manual di tengah layar | `MekaarStateView(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_state_view.dart';` |
| **Maskot / Ilustrasi Kontekstual**| Aset gambar acak | `MikaIllustration(...)` atau `MikaAnimated(...)` | `import 'package:mekaar_chat/core/widgets/mika_illustration.dart';` |

---

## 3. Kamus Design Tokens (Zero Hardcoding Policy)

### 3.1. Warna (`MekaarColors` & `AppColors`)
Path: `import 'package:mekaar_chat/core/constants/colors.dart';`

* **Brand Core (Sumber Tunggal):**
  * Biru Utama Brand: `AppColors.blue` / `MekaarColors.blue` (`#136CFC`).
  * Biru Tua Kanvas/Teks: `AppColors.darkBlue` (`#111E34`).
  * Hijau Terang Aksen: `AppColors.green` (`#2EF77A`).
  * Putih Kanvas Terang: `AppColors.lightBlue` (`#FAF9F6`).
* **Protective Semantics:**
  * Coral Peringatan / Bahaya: `MekaarColors.sosCoral` (`#FF5D5D`).
  * Merah Darurat Kritis: `MekaarColors.sosDeep` (`#D92632`).
  * Teal Aman / Terlindungi: `MekaarColors.safeTeal` (`#2DD4BF`).
  * Amber Perhatian: `MekaarColors.warnAmber` (`#FBBF24`).
* **Aksesibilitas Kontras (Accessible Contrast Inks):**
  * `MekaarColors.safeTealInk` (`#0C6B60`): Tinta gelap teal untuk teks dan ikon di atas permukaan putih/terang (karena `#2DD4BF` hanya ≈1.8:1 di atas putih).
  * `MekaarColors.textOnTeal` (`#04302A`): Tinta gelap untuk teks di atas latar permukaan teal (putih di atas teal ≈1.9:1).
  * `MekaarColors.successInk` (`#047857`): Tinta hijau kontras untuk teks status aktif/online di atas permukaan terang (`successTextOf(context)`).
  * `MekaarColors.readReceiptGreen` (`#25D366`): Status bukti baca (centang ganda pesan terbaca ala WhatsApp).
* **Kanvas & Permukaan Dinamis (Adaptif Dark / Light Mode & ForceDarkScope):**
  * `MekaarColors.surfaceOf(context)`: Permukaan kartu / kontainer (`cardLight` putih / `cardDark` `#1E304F`).
  * `MekaarColors.surface2Of(context)`: Permukaan sekunder bersarang (`#E8F4FC` / `#25395B`).
  * `MekaarColors.surface3Of(context)`: Permukaan tersier bersarang (`#DCE7F5` / `#1E304F`).
  * `MekaarColors.backgroundOf(context)`: Latar belakang layar (`#FAF9F6` / `#111E34`).
  * `MekaarColors.borderOf(context)`: Border adaptif (`borderLight` `#DCE7F5` / `borderDark` `#25395B`).
  * `MekaarColors.dividerOf(context)`: Pemisah adaptif.
  * `MekaarColors.isDarkContext(context)`: Helper pendeteksi mode gelap sistem atau subtree `ForceDarkScope` (layar darurat / SOS).
  * *Dilarang menggunakan pengecekan manual seperti `Theme.of(context).brightness == Brightness.dark`.*
* **Palet Taktis & Darurat (Stealth OLED):**
  * `stealthBg` (`#000000` - OLED Pure Black, zero glow), `stealthSurface` (`#0F172A`), `stealthCard` (`#1E293B`), `stealthText` (`#F8FAFC`).

### 3.2. Jarak, Margin, Padding & Radius (`MekaarSpacing`, `MekaarRadius`, `MekaarSizes`)
Path: `import 'package:mekaar_chat/core/constants/dimensions.dart';`

* **Spasi Baku (`MekaarSpacing`):**
  * `xxs` (2px), `xs` (4px), `sm` (8px), `md` (12px), `lg` (16px), `xl` (20px), `xxl` (24px), `xxxl` (32px), `section` (32px).
  * Insets Baku:
    * Layar: `MekaarSpacing.screen` (`EdgeInsets.symmetric(horizontal: 20)`).
    * Kartu: `MekaarSpacing.card` (`EdgeInsets.all(16)`).
    * Dialog: `MekaarSpacing.dialog` (`EdgeInsets.fromLTRB(20, 16, 20, 12)`).
* **Border Radius (`MekaarRadius`):**
  * `xxs` (2px) — Bar waveform, garis progres mikro.
  * `xs` (4px) — Progress bar, indikator status kecil.
  * `sm` (8px) — Chip dalam gelembung pesan, thumbnail balasan.
  * `sub` (10px) — Overlay badge media, durasi voice note.
  * `base` (12px) — Chip, badge standar.
  * `card` (16px) — Standar baku kartu Mekaar (tetap & presisi).
  * `md` (18px) — Bubble pesan obrolan, input bar komposer.
  * `lg` (24px) — Kartu daftar chat, bottom sheet container.
  * `xl` (32px) — Extra rounded container.
  * `pill` (999px) — Tombol aksi, FAB, search bar, avatar.
  * *Dilarang menulis angka acak seperti `BorderRadius.circular(15.5)`.*
* **Ukuran Elemen & Target Sentuh (`MekaarSizes`):**
  * `touchTargetMin` (48px) — Target sentuh minimal WCAG 2.2 SC 2.5.8 & Material Design 3 (48×48 dp).
  * `composerButton` (48px) — Target sentuh tombol aksi komposer pesan obrolan.
  * `avatarMd` (38px), `avatarLg` (48px).
  * `iconSm` (18px), `iconMd` (20px), `iconLg` (24px).
  * `iconBadge` (44px) — Kontainer ikon pada tile/list.
  * `fab` (60px) — Ukuran FAB sentral (biru solid).
  * `sos` (72px) — Tombol darurat utama SOS.

### 3.3. Tipografi (`MekaarTypography`)
Path: `import 'package:mekaar_chat/core/constants/typography.dart';`

* Font Primer UI: `Plus Jakarta Sans`.
* Font Brand & Hero: `Baloo 2`.
* *Dilarang membuat `TextStyle(fontSize: ..., fontWeight: ...)` mentah.*
* **Hirarki Teks Terstandarisasi:**
  * **Brand & Wordmark:**
    * `MekaarTypography.wordmark` (Baloo 2, 38px, w700, #136CFC).
    * `MekaarTypography.brandDisplay(...)` & `brandHeading(...)`.
    * `MekaarTypography.profileInitial(...)` (Baloo 2 untuk avatar inisial).
  * **Display (Judul Halaman):**
    * `MekaarTypography.displayXL` (Baloo 2, 36px, w800).
    * `MekaarTypography.displayLG` (Baloo 2, 32px, w800).
    * `MekaarTypography.tabHeader` (32px, w800, putih).
  * **Heading (Sub-judul & Seksi):**
    * `MekaarTypography.headingLG` (Baloo 2, 24px, w700).
    * `MekaarTypography.headingMD` (Plus Jakarta Sans, 20px, w700).
    * `MekaarTypography.headingSM` (Plus Jakarta Sans, 18px, w700).
    * `MekaarTypography.sectionHeader` (14.5px, w700, letterSpacing: -0.2).
  * **Body (Konten Obrolan & UI):**
    * `MekaarTypography.bodyLG` (18px, w400, height: 1.6).
    * `MekaarTypography.bodyMD` (16px, w400, height: 1.5).
    * `MekaarTypography.bodySM` (14px, w400, height: 1.4).
  * **Label, Badge & Caption:**
    * `MekaarTypography.labelLG` (14px, w600).
    * `MekaarTypography.labelMD` (11px, w600, letterSpacing: 0.2).
    * `MekaarTypography.labelSM` (11px, w700, letterSpacing: 0.2).
    * `MekaarTypography.caption` (11px, w700, tabular figures untuk timestamp).
    * `MekaarTypography.badge` (11px, w800, putih).

### 3.4. Animasi, Durasi & Kurva Gerak (`MekaarMotion`)
Path: `import 'package:mekaar_chat/core/constants/motion.dart';`

* MEKAAR menganut prinsip gerakan interaktif responsif dengan penghormatan penuh terhadap preferensi aksesibilitas pengguna.
* **Token Durasi:**
  * `micro` (120ms), `fast` (150ms), `normal` (250ms), `pop` (280ms), `counter` (300ms), `slow` (400ms), `playful` (500ms), `cinematic` (800ms), `idle` (1500ms).
  * Indikator Berulang: `loop` (1000ms).
  * Staggered List: `staggerStep` (40ms), `staggerMax` (240ms).
* **Token Kurva Gerak:**
  * `standard`: `Curves.easeOutCubic`.
  * `emphasized`: `Curves.easeInOutCubic`.
  * `bounce`: `Curves.easeOutBack`.
* **Aksesibilitas (Reduce Motion Policy):**
  * Semua animasi dan transisi WAJIB menghormati preferensi sistem dengan ekstensi `BuildContext`:
    * `context.reduceMotion`: Mengembalikan `true` bila pengguna mematikan animasi di pengaturan sistem OS.
    * `context.motion(d)`: Mengembalikan `Duration.zero` bila reduce motion aktif, atau durasi normal `d` jika tidak aktif.

---

## 4. Panduan Ekstensi Komponen Sentral & Guardrail Testing

Jika sebuah fitur baru membutuhkan tampilan yang belum didukung oleh komponen yang ada:
1. **DILARANG:** Menambahkan logic visual ad-hoc langsung di file `lib/features/.../xxx_screen.dart`.
2. **WAJIB:** Buka komponen sentral yang bersangkutan di `lib/core/widgets/` (misalnya `custom_card.dart` atau `custom_app_bar.dart`).
3. Tambahkan parameter opsional atau varian enum baru yang terabstraksi bersih.
4. Buat / perbarui unit test di `test/` untuk menguji varian baru tersebut.
5. Jalankan `flutter test test/architecture/design_system_guardrail_test.dart` untuk memastikan tidak ada pelanggaran arsitektur baru.
6. Jalankan `flutter analyze` dan pastikan 0 error/warning.
7. Baru impor dan gunakan varian baru tersebut di layar fitur Anda.
