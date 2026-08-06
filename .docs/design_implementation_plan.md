# MEKAAR — Rencana Implementasi `design.md`

Lampiran teknis dari `design.md`. Dokumen itu berisi prinsip ("apa & kenapa"); dokumen ini berisi perintah kerja eksak ("langkah persis, di file mana, urutan apa"). Kerjakan **berurutan sesuai Fase** — jangan lompat fase, karena fase belakang bergantung pada fase depan sudah beres & terverifikasi.

Setelah setiap fase, jalankan langkah verifikasi yang tercantum. Kalau hasil verifikasi tidak sesuai ekspektasi, **berhenti dan laporkan** — jangan lanjut ke fase berikutnya dengan asumsi "nanti juga kebetulan beres".

---

## FASE 0 — Baseline (sebelum ubah apa pun)

```bash
flutter analyze > /tmp/baseline_analyze.txt
grep -rc "MekaarColors.softCoral" lib/features/ | awk -F: '{s+=$2} END {print s}'   # ekspektasi: 50
grep -rc "MekaarColors.sosCoral"  lib/features/ | awk -F: '{s+=$2} END {print s}'   # ekspektasi: 12
grep -rc "MekaarColors.sosRed"    lib/features/ | awk -F: '{s+=$2} END {print s}'   # ekspektasi: 78
grep -rc "MekaarColors.sosDeep"   lib/features/ | awk -F: '{s+=$2} END {print s}'   # ekspektasi: 0
grep -rc "MekaarColors.guardianTeal" lib/features/ | awk -F: '{s+=$2} END {print s}' # ekspektasi: 42
grep -rc "MekaarColors.safeTeal"  lib/features/ | awk -F: '{s+=$2} END {print s}'   # ekspektasi: 3
```
Simpan `/tmp/baseline_analyze.txt` — dipakai di Fase 6 untuk memastikan tidak ada error BARU yang muncul akibat perubahan (boleh saja error lama yang memang sudah ada sebelumnya, itu di luar cakupan kerjaan ini).

---

## FASE 1 — Token Baru (aditif, tidak menghapus apa pun, risiko nol)

### 1a. `lib/core/constants/colors.dart`
Tambahkan setelah baris `static const Color lime = Color(0xFFA3E635);`:
```dart
/// Warna primer resmi — SATU-SATUNYA warna untuk state terpilih/aktif dan
/// CTA utama. Jangan pakai purple/pink/yellow/lime untuk peran ini.
static const Color primary = cyan;
```

### 1b. `lib/core/constants/dimensions.dart`
Tambahkan di dalam `class MekaarSizes`:
```dart
/// Area sentuh minimum untuk elemen interaktif (WCAG 2.5.5 / Material
/// guideline). Berlaku terlepas dari ukuran ikon visualnya.
static const double minTapTarget = 44.0;
```

**Verifikasi Fase 1**: `flutter analyze` — harus tetap sama persis dengan baseline (murni penambahan, tidak boleh ada error baru).

---

## FASE 2 — Migrasi Nama Warna (hapus alias yang kalah)

Urutan wajib: **replace dulu, baru hapus definisi alias.** Jangan dibalik.

### 2a. Replace pemakaian alias ke nama kanonis
```bash
grep -rl "MekaarColors.sosCoral" lib/features/ | xargs sed -i 's/MekaarColors\.sosCoral/MekaarColors.softCoral/g'
grep -rl "MekaarColors.safeTeal" lib/features/ | xargs sed -i 's/MekaarColors\.safeTeal/MekaarColors.guardianTeal/g'
# sosDeep: 0 pemakaian di baseline, tidak perlu replace apa pun — langsung ke 2b.
```

### 2b. Verifikasi tidak ada sisa sebelum lanjut
```bash
grep -rc "MekaarColors.sosCoral\b" lib/features/ | awk -F: '{s+=$2} END {print s}'  # WAJIB 0
grep -rc "MekaarColors.safeTeal\b" lib/features/ | awk -F: '{s+=$2} END {print s}'  # WAJIB 0
```
Kalau bukan 0, cari sisanya manual (`grep -rn`) — mungkin ada pemakaian dalam bentuk lain (mis. dalam string interpolation atau alias import) yang tidak kena `sed`.

### 2c. Hapus definisi alias dari `lib/core/constants/colors.dart`
Hapus baris:
```dart
static const Color sosCoral = Color(0xFFFF5D5D);
static const Color sosDeep = Color(0xFFD92632);
static const Color safeTeal = Color(0xFF2DD4BF);
```
(Baris-baris ini ada di bagian "Protective Semantics" dekat awal file — jangan hapus `sosRed`/`softCoral`/`guardianTeal`, itu yang dipertahankan.)

**Verifikasi Fase 2**: `flutter analyze` — 0 error baru (khususnya pastikan tidak ada `undefined_identifier` untuk `sosCoral`/`sosDeep`/`safeTeal`).

---

## FASE 3 — Background: `flat` Parameter di `MekaarScaffold`/`MekaarCanvas`

### 3a. `lib/core/widgets/mekaar_canvas.dart`
Tambahkan parameter `flat` (default `true` — aman karena mayoritas layar memang harus Clean):
```dart
class MekaarCanvas extends ConsumerWidget {
  const MekaarCanvas({
    super.key,
    required this.child,
    this.forceDark = false,
    this.flat = true, // BARU
  });

  final Widget child;
  final bool forceDark;
  final bool flat; // BARU
  ...
```
Di method `build`, sebelum menghitung/menerapkan `gradient`:
```dart
if (flat) {
  // Mode Clean: background flat, ikuti Theme, TANPA gradient waktu.
  return Container(
    color: Theme.of(context).colorScheme.surface,
    child: child,
  );
}
// (kode gradient existing tetap di sini untuk flat == false)
```

### 3b. `lib/core/widgets/mekaar_scaffold.dart`
Teruskan parameter yang sama ke `MekaarCanvas`:
```dart
class MekaarScaffold extends StatelessWidget {
  const MekaarScaffold({
    super.key,
    required this.child, // (atau nama parameter aslinya — cek signature existing)
    this.forceDark = false,
    this.flat = true, // BARU
    // ...parameter lain yang sudah ada, jangan diubah
  });

  final bool flat; // BARU

  @override
  Widget build(BuildContext context) {
    // ...
    child: MekaarCanvas(forceDark: forceDark, flat: flat, child: mainScaffold),
    // ...
  }
}
```

### 3c. Set `flat` eksplisit di 29 pemanggil — daftar klasifikasi final

**`flat: false`** (Playful/Brand — PERTAHANKAN gradient, cuma 3 file ini):
```
lib/features/auth/screens/splash_screen.dart        → flat: false  (brand moment)
lib/features/auth/screens/onboarding_screen.dart    → flat: false  (brand moment)
lib/features/chat/screens/chat_screen.dart          → flat: false  (mode Playful, isi chat)
```

**`flat: true`** (Clean — SISANYA, 26 file):
```
lib/features/guardian/screens/guardian_detail_screen.dart
lib/features/guardian/screens/qr_invite_screen.dart
lib/features/guardian/screens/add_guardian_screen.dart
lib/features/guardian/screens/swap_guardian_screen.dart
lib/features/guardian/screens/qr_scan_screen.dart
lib/features/guardian/screens/guardian_list_screen.dart
lib/features/auth/screens/pin_screen.dart
lib/features/auth/screens/login_screen.dart
lib/features/auth/screens/two_factor_screen.dart
lib/features/auth/screens/set_username_screen.dart
lib/features/chat/screens/my_qr_screen.dart
lib/features/chat/screens/main_navigation_screen.dart
lib/features/chat/screens/contact_settings_screen.dart
lib/features/chat/screens/contact_qr_scan_screen.dart
lib/features/settings/screens/chat_theme_settings_screen.dart
lib/features/settings/screens/blocked_list_screen.dart
lib/features/settings/screens/profile_screen.dart
lib/features/settings/screens/trip_list_screen.dart
lib/features/settings/screens/security_logs_screen.dart
lib/features/settings/screens/two_factor_setup_screen.dart
lib/features/settings/screens/theme_settings_screen.dart
lib/features/settings/screens/add_trip_screen.dart
lib/features/settings/screens/sound_picker_screen.dart
lib/features/map/screens/location_picker_screen.dart
lib/features/sos/screens/device_lost_screen.dart
lib/features/sos/screens/sos_active_screen.dart
```
Untuk tiap file di atas, cari pemanggilan `MekaarScaffold(` dan tambahkan `flat: true,` sebagai argumen eksplisit — **eksplisit walau sama dengan default**, supaya jelas ini keputusan sadar, bukan kebetulan warisan default.

> ⚠️ **Kasus khusus — `theme_settings_screen.dart` & `chat_theme_settings_screen.dart`**: dua layar ini SEKARANG menjadikan gradient sebagai background PENUH LAYAR (termasuk saat preview "Halo, MEKAAR User!"). Setelah `flat: true` diterapkan, preview gradient itu HARUS dipindah jadi `Container` kecil ber-`borderRadius` (kartu preview mandiri di dalam layar, bukan background layar itu sendiri) supaya fitur "lihat preview warna suasana" tidak hilang — cuma dikontain, bukan dihapus. Cari widget preview card yang sudah ada (kemungkinan sudah berbentuk `Container` dengan `padding`, tinggal pastikan tidak lagi mewarisi gradient dari parent `Scaffold`, hanya dari `decoration` lokal miliknya sendiri).

**Verifikasi Fase 3**:
```bash
grep -c "MekaarScaffold(" lib/features/**/*.dart | awk -F: '$2>0' | wc -l   # harus tetap 29 file
grep -rL "flat:" $(grep -rl "MekaarScaffold(" lib/features/)               # harus KOSONG (semua sudah eksplisit)
```
`flutter analyze` — 0 error baru. Lalu **verifikasi visual manual** (jalankan app): buka salah satu layar Settings, pastikan background flat/netral; buka Chat, pastikan gradient/preset masih jalan seperti biasa; buka Splash, pastikan masih gradient hangat.

---

## FASE 4 — Migrasi Ikon (`Icons.*` Material → SolarIcons)

28 pemakaian di 12 file. Tabel di bawah beri usulan padanan SolarIcons — **verifikasi nama exact identifier-nya lewat autocomplete IDE/dokumentasi package `solar_icons`** sebelum apply, karena penamaan persis tiap ikon perlu dicocokkan ke versi package yang terpasang (`pubspec.yaml`).

| File:Baris | Icon Material Sekarang | Usulan SolarIcons |
|---|---|---|
| `chat/widgets/chat_list_tile.dart:83` | `Icons.shield_outlined` | `SolarIconsOutline.shield` |
| `chat/widgets/chat_list_tile.dart:90` | `Icons.groups_outlined` | `SolarIconsOutline.usersGroupRounded` |
| `chat/widgets/chat_list_tile.dart:97` | `Icons.notifications_off` | `SolarIconsOutline.bellOff` |
| `chat/widgets/chat_list_tile.dart:104` | `Icons.lock_outline` | `SolarIconsOutline.lockKeyhole` |
| `chat/widgets/chat_list_tile.dart:165` | `Icons.notifications_off` | `SolarIconsOutline.bellOff` |
| `chat/widgets/chat_list_tile.dart:173` | `Icons.archive` | `SolarIconsBold.archive` |
| `chat/widgets/chat_list_tile.dart:186` | `Icons.delete` | `SolarIconsBold.trashBinTrash` |
| `chat/screens/chat_screen.dart:585` | `Icons.check` | `SolarIconsBold.checkCircle` |
| `chat/screens/chat_list_screen.dart:75` | `Icons.security` | `SolarIconsOutline.shieldCheck` |
| `chat/screens/call_screen.dart:590` | `Icons.error_outline` | `SolarIconsOutline.dangerTriangle` |
| `chat/screens/call_screen.dart:636` | `Icons.volume_up`/`volume_down` | `SolarIconsOutline.volumeLoud`/`volumeSmall` |
| `chat/screens/call_screen.dart:643` | `Icons.videocam`/`videocam_off` | `SolarIconsOutline.videocamera`/`videocameraRecordOff` |
| `chat/screens/call_screen.dart:649` | `Icons.mic_off`/`mic` | `SolarIconsOutline.microphone`/`microphoneOff` |
| `chat/screens/call_screen.dart:655` | `Icons.call_end` | `SolarIconsBold.phoneCallingRounded` (cek varian "end call" spesifik kalau ada) |
| `chat/screens/create_group_select_members_screen.dart:132` | `Icons.close` | `SolarIconsOutline.closeCircle` |
| `chat/widgets/chat_composer.dart:683` | `Icons.sentiment_satisfied_alt_outlined` | `SolarIconsOutline.emojiFunnyCircle` |
| `settings/screens/chat_theme_settings_screen.dart:57` | `Icons.error_outline` | `SolarIconsOutline.dangerTriangle` |
| `settings/screens/duress_pin_screen.dart:180` | `Icons.delete_outline` | `SolarIconsOutline.trashBinMinimalistic` |
| `settings/screens/add_trip_screen.dart:325` | `Icons.bookmark_added` | `SolarIconsBold.bookmark` |
| `settings/screens/add_trip_screen.dart:335` | `Icons.check_circle` | `SolarIconsBold.checkCircle` |
| `settings/screens/settings_screen.dart:361` | `Icons.check` | `SolarIconsBold.checkCircle` |
| `map/screens/location_map_screen.dart:72` | `Icons.location_on` | `SolarIconsBold.mapPoint` |
| `map/screens/location_map_screen.dart:107` | `Icons.location_pin` | `SolarIconsBold.mapPoint` |
| `map/screens/location_map_screen.dart:128` | `Icons.copy_all_outlined` | `SolarIconsOutline.copy` |
| `map/screens/location_map_screen.dart:152` | `Icons.directions_outlined` | `SolarIconsOutline.routing` |
| `sos/screens/video_emergency_screen.dart:284` | `Icons.circle` (indikator rekam, 8px) | **Kecualikan** — ini titik indikator polos bukan ikon simbolik, boleh tetap `Container` lingkaran biasa, bukan icon font |
| `sos/screens/sos_active_screen.dart:304` | `Icons.videocam_outlined` | `SolarIconsOutline.videocamera` |
| `auth/screens/login_screen.dart:349` | `Icons.g_mobiledata` (logo Google) | **Kecualikan** — logo pihak ketiga, bukan bagian sistem ikon internal, biarkan apa adanya atau ganti aset logo resmi Google kalau tersedia |

**Kerjakan file per file** (bukan sekaligus 12 file), commit/verifikasi tiap file kelar:
1. Tambahkan/pastikan `import 'package:solar_icons/solar_icons.dart';` ada di file.
2. Replace tiap `Icons.xxx` sesuai tabel.
3. `flutter analyze` file tersebut — pastikan identifier SolarIcons yang dipakai benar-benar ada (kalau tidak ketemu, cek daftar identifier valid via autocomplete, JANGAN menebak nama).

**Verifikasi Fase 4**:
```bash
grep -rn "Icons\.[a-zA-Z_]*" lib/features/ | grep -v "SolarIcons"
# Ekspektasi akhir: HANYA tersisa 2 baris (video_emergency_screen.dart:284 dan login_screen.dart:349 — dua pengecualian di atas)
```

---

## FASE 5 — Aksesibilitas: `tooltip` di `IconButton`

```bash
grep -rn "IconButton(" lib/features/ > /tmp/iconbuttons.txt
wc -l /tmp/iconbuttons.txt
```
Untuk tiap hasil, cek 5 baris setelahnya — kalau belum ada parameter `tooltip:`, tambahkan dengan teks singkat yang menjelaskan aksi tombolnya (dalam Bahasa Indonesia, konsisten dengan copy app). Prioritaskan urutan berikut (jangan acak):
1. `lib/features/auth/screens/pin_screen.dart`
2. `lib/features/sos/screens/sos_active_screen.dart`, `lib/features/sos/screens/device_lost_screen.dart`
3. `lib/features/chat/screens/call_screen.dart`
4. Sisanya, urutan bebas.

**Verifikasi Fase 5**: `flutter analyze` 0 error baru. Tidak ada cara otomatis memverifikasi kelengkapan tooltip secara sempurna — lakukan review manual per file yang disentuh.

---

## FASE 6 — Verifikasi Akhir Menyeluruh

```bash
flutter analyze > /tmp/final_analyze.txt
diff /tmp/baseline_analyze.txt /tmp/final_analyze.txt
# Baris yang MUNCUL di final tapi tidak ada di baseline = error baru, WAJIB 0.
# Baris yang HILANG dari baseline (mis. warning lama yang kebetulan ikut hilang) tidak masalah.

flutter test   # kalau ada test suite, pastikan tidak ada yang regresi
```
Lalu jalankan app dan cek manual satu-satu (checklist singkat):
- [ ] Splash & Onboarding: masih gradient hangat seperti sebelumnya
- [ ] Login/PIN: background flat, bukan gradient
- [ ] Chat: gradient/preset tema masih berfungsi normal, tidak ada regresi
- [ ] Salah satu layar Settings: background flat
- [ ] `chat_list_tile.dart`: ikon status (guardian/grup/mute/lock) sudah SolarIcons, terlihat konsisten dengan ikon lain di app bar
- [ ] Layar Tema Chat: preview warna suasana masih bisa dilihat (sekarang dalam kartu terkontain, bukan background penuh)

---

## Catatan untuk Model yang Mengeksekusi

- Jangan gabungkan beberapa Fase dalam satu commit/patch besar — commit per Fase, supaya kalau ada yang salah, rollback-nya presisi ke satu Fase saja.
- Kalau nama identifier SolarIcons di Fase 4 tidak ditemukan persis seperti yang diusulkan, JANGAN improvisasi nama baru sembarangan — cari padanan terdekat yang benar-benar ada di package, dan catat penggantian yang berbeda dari tabel ini supaya bisa direview manusia belakangan.
- Fase 3 adalah yang paling berisiko visual (bisa merusak tampilan chat kalau `chat_screen.dart` salah masuk daftar `flat: true`) — kalau ragu, jalankan Fase 3 dan langsung screenshot manual sebelum lanjut ke Fase 4.
