# 📘 MEKAAR 3.0 — Design System Catalog & Agent Governance

> **Buku Pegangan Utama Agen AI & Pengembang:**
> Dokumen ini adalah Single Source of Truth (SSOT) teknis yang mengatur implementasi antarmuka (UI) pada aplikasi MEKAAR 3.0.
> **ATURAN MUTLAK:** Tidak ada pembuatan widget UI ad-hoc atau hardcoded styling di `lib/features/`. Seluruh komponen dan token WAJIB merujuk ke pustaka sentral `lib/core/`.

---

## 1. Protokol Gatekeeper: Aturan Penambahan / Perubahan Fitur

Sebelum menulis satu baris kode pun di `lib/features/`, setiap agen **WAJIB** mengikuti alur kerja (*State Machine*) berikut:

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
    │                     a. Buka & update spesifikasi di `.docs/design.md`.
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
   * Zero hardcoding (tanpa `Color(0x...)`, tanpa `AppBar(`, tanpa `Card(`).
                     │
                     ▼
[4. Verifikasi Mekanis]
   * Jalankan `flutter test test/architecture/design_system_guardrail_test.dart`
   * Jalankan `flutter analyze`
   * Jalankan `flutter test`
```

---

## 2. Tabel Substitusi Komponen (Do & Don't)

Agen dilarang keras menggunakan widget bawaan Flutter jika padanan sentralnya sudah tersedia.

| Kebutuhan Antarmuka | ❌ DILARANG KERAS | ✅ WAJIB DIGUNAKAN | Path Impor Sentral |
|---|---|---|---|
| **Root Layar / Halaman** | `Scaffold(...)` | `MekaarScaffold(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_scaffold.dart';` |
| **Header Layar / Top Bar** | `AppBar(...)` | `CustomAppBar(...)` atau `MekaarTopBar(...)` | `import 'package:mekaar_chat/core/widgets/custom_app_bar.dart';`<br>`import 'package:mekaar_chat/core/widgets/mekaar_top_bar.dart';` |
| **Kartu / Kontainer Konten** | `Card(...)`, `Container(decoration: ...)` | `CustomCard(...)` | `import 'package:mekaar_chat/core/widgets/custom_card.dart';` |
| **Modal / Dialog Konfirmasi** | `AlertDialog(...)`, `showDialog(...)` | `MekaarDialog.showConfirmation(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_dialog.dart';` |
| **Lembar Bawah / Bottom Sheet** | `showModalBottomSheet(...)` | `MekaarBottomSheet.show(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_bottom_sheet.dart';` |
| **Notifikasi Snackbar / Toast** | `ScaffoldMessenger.showSnackBar(...)` | `MekaarSnackBar.show(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_snackbar.dart';` |
| **Header Tab / Sub-seksi** | Header teks biasa | `MekaarTabHeader(...)` atau `MekaarSectionHeader(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_tab_header.dart';`<br>`import 'package:mekaar_chat/core/widgets/mekaar_section_header.dart';` |
| **Badge / Label Status** | Kontainer warna-warni manual | `MekaarBadge(...)` atau `MekaarIconBadge(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_badge.dart';`<br>`import 'package:mekaar_chat/core/widgets/mekaar_icon_badge.dart';` |
| **Banner Peringatan / Info** | Kontainer peringatan ad-hoc | `MekaarBanner(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_banner.dart';` |
| **Tombol Aksi Kritis / SOS** | Tombol standar tanpa proteksi | `HoldToConfirmButton(...)` atau `SOSButton(...)` | `import 'package:mekaar_chat/core/widgets/hold_to_confirm_button.dart';`<br>`import 'package:mekaar_chat/core/widgets/sos_button.dart';` |
| **Avatar Pengguna / Kontak** | `CircleAvatar(...)` | `AvatarWidget(...)` | `import 'package:mekaar_chat/core/widgets/avatar.dart';` |
| **Field Pencarian** | `TextField` mentah dengan icon search | `MekaarSearchField(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_search_field.dart';` |
| **Segmented Switcher / Tab Pill** | TabBar biasa | `MekaarSlidingSegmentBar(...)` | `import 'package:mekaar_chat/core/widgets/mekaar_sliding_segment_bar.dart';` |
| **Loading Skeleton** | `CircularProgressIndicator` acak | `MekaarSkeleton(...)` | `import 'package:mekaar_chat/core/widgets/skeletons.dart';` |

---

## 3. Kamus Design Tokens (Zero Hardcoding Policy)

### 3.1. Warna (`MekaarColors`)
Path: `import 'package:mekaar_chat/core/constants/colors.dart';`

* **Kanvas & Permukaan Dinamis (Adaptif Terhadap Dark / Light Mode):**
  * Gunakan helper dinamis: `MekaarColors.surfaceOf(context)`, `MekaarColors.surface2Of(context)`, `MekaarColors.backgroundOf(context)`.
  * Dilarang menggunakan pengecekan manual seperti `Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white`.
* **Aksen Brand:**
  * Kuning CTA / FAB: `MekaarColors.yellow` (`#FFD84D`)
  * Cyan Koneksi: `MekaarColors.cyan` (`#38BDF8`)
  * Biru Utama Brand: `MekaarColors.primary` (`#2E63B8`)
  * Teal Aman / Terlindungi: `MekaarColors.teal` (`#2DD4BF`)
  * Coral Peringatan / Bahaya: `MekaarColors.coral` (`#FB7185`)
  * Ungu Interaksi: `MekaarColors.purple` (`#A78BFA`)

### 3.2. Jarak, Margin, Padding & Radius (`MekaarDimensions`)
Path: `import 'package:mekaar_chat/core/constants/dimensions.dart';`

* **Border Radius:**
  * `MekaarRadius.xs` (4px), `MekaarRadius.sm` (8px), `MekaarRadius.md` (12px), `MekaarRadius.lg` (16px), `MekaarRadius.xl` (20px), `MekaarRadius.full` (999px untuk pills/kapsul).
  * Dilarang menulis angka acak seperti `BorderRadius.circular(15.5)`.
* **Spasi / Spacing:**
  * `MekaarDimensions.spaceXS` (4px), `MekaarDimensions.spaceSM` (8px), `MekaarDimensions.spaceMD` (12px), `MekaarDimensions.spaceLG` (16px), `MekaarDimensions.spaceXL` (20px), `MekaarDimensions.spaceXXL` (24px).
  * Padding Standar Layar: `MekaarDimensions.screenPaddingHorizontal` (16px).

### 3.3. Tipografi (`MekaarTypography`)
Path: `import 'package:mekaar_chat/core/constants/typography.dart';`

* Dilarang membuat `TextStyle(fontSize: 17, fontWeight: ...)` secara mandiri.
* Gunakan hirarki teks terstandarisasi:
  * Judul Besar / Display: `MekaarTypography.displayLarge`, `MekaarTypography.displayMedium`
  * Header Layar / Tab: `MekaarTypography.titleLarge`, `MekaarTypography.titleMedium`
  * Body Text: `MekaarTypography.bodyLarge`, `MekaarTypography.bodyMedium`, `MekaarTypography.bodySmall`
  * Caption / Label Timestamp: `MekaarTypography.caption`, `MekaarTypography.labelSmall`

### 3.4. Animasi & Transisi (`MekaarMotion`)
Path: `import 'package:mekaar_chat/core/constants/motion.dart';`

* Interaksi MEKAAR menganut prinsip *spring bouncy* yang hidup, bukan transisi kaku.
* Gunakan token durasi: `MekaarMotion.durationFast`, `MekaarMotion.durationNormal`, `MekaarMotion.durationSlow`.
* Gunakan kurva gerak: `MekaarMotion.springCurve`, `MekaarMotion.emphasizedCurve`.

---

## 4. Panduan Ekstensi Komponen Sentral

Jika sebuah fitur baru membutuhkan tampilan yang belum didukung oleh komponen yang ada:
1. **DILARANG:** Menambahkan logic visual langsung di file `lib/features/.../xxx_screen.dart`.
2. **WAJIB:** Buka komponen sentral yang bersangkutan di `lib/core/widgets/` (misalnya `custom_card.dart` atau `custom_app_bar.dart`).
3. Tambahkan parameter opsional atau varian enum baru yang terabstraksi bersih.
4. Buat / perbarui unit test di `test/` untuk menguji varian baru tersebut.
5. Jalankan `flutter analyze` dan pastikan 0 error.
6. Baru impor dan gunakan varian baru tersebut di layar fitur Anda.
