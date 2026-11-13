# Laporan Audit Desain Antarmuka Pengguna dan Arsitektur Sistem Desain Enterprise Mekaar Chat

## Ringkasan Eksekutif dan Evaluasi Kematangan Sistem Desain

Transformasi aplikasi perpesanan terenkripsi dari produk konsumen menuju standar perangkat lunak *enterprise* global menuntut disiplin sistem desain (*design system*) yang melampaui sekadar estetika visual permukaan. Dalam ekosistem komunikasi kritis yang menggabungkan enkripsi *end-to-end* (E2EE), perlindungan darurat (*SOS & Guardian Tracking*), serta brankas data lokal seperti yang diimplementasikan pada repositori [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat), arsitektur antarmuka pengguna memikul fungsi ganda: menjaga kejelasan kognitif dalam situasi bertekanan tinggi sekaligus menjamin aksesibilitas universal di berbagai kondisi pencahayaan dan perangkat keras. Evaluasi komprehensif terhadap struktur kode sumber Flutter di direktori `lib/core/` dan `lib/features/` menunjukkan bahwa [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat) telah memiliki fondasi modularisasi awal melalui pemisahan konstanta warna pada [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), skala dimensi pada [`lib/core/constants/dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart), struktur tipografi pada [`lib/core/constants/typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart), serta manajemen tiga mode tampilan (*Light*, *Dark*, dan *Stealth OLED*) pada [`lib/core/constants/themes.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart).

Meskipun fondasi struktural tersebut telah terbentuk, perbandingan terukur terhadap standar industri perpesanan *enterprise* dunia—termasuk [Material Design 3](https://m3.material.io/foundations/design-tokens), [Apple Human Interface Guidelines (HIG)](https://developer.apple.com/design/human-interface-guidelines), spesifikasi [W3C Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/2025.10/format/), serta standar aksesibilitas [W3C Web Content Accessibility Guidelines (WCAG) 2.2](https://www.w3.org/TR/WCAG22/) dan [W3C Guidance on Applying WCAG 2.2 to Mobile Applications](https://www.w3.org/TR/wcag2mobile-22/)—mengungkapkan sejumlah celah sistemik yang menghambat kesiapan tingkat *enterprise*. Celah utama tersebut meliputi pencampuran antara token primitif dan token semantik, kebocoran nilai *hardcoded* (*magic numbers* dan warna statis) pada komponen gelembung pesan seperti [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) dan [`lib/core/widgets/chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart), penurunan rasio kontras akibat manipulasi *alpha channel* dinamis (`withValues(alpha: 0.72)` dan `Colors.white54`), hingga ketiadaan atribut semantik pembaca layar (`Semantics`) serta area sentuh (*touch target*) yang berada di bawah batas aman ergonomis.

| Dimensi Audit Desain UI | Berkas Utama di Repositori | Temuan Kritis pada Implementasi Saat Ini | Tolok Ukur Industri Enterprise | Skor Kematangan (1–5) | Prioritas Remediasi |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Arsitektur Design Tokens** | [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), [`dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart), [`themes.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart) | Koeksistensi kelas ganda (`AppColors` dan `MekaarColors`), resolusi tema berbasis metode statis `Of(BuildContext)` alih-alih `ThemeExtension`, dan belum adanya lapisan *component tokens*. | Arsitektur 3-lapis ([Material Design 3 Tokens](https://m3.material.io/foundations/design-tokens) & [W3C DTCG 2025.10](https://www.designtokens.org/tr/2025.10/format/)): *Reference*, *System/Semantic*, dan *Component Tokens*. | 2.8 / 5.0 | Tinggi (P0) |
| **Konsistensi Visual & Tata Letak** | [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), [`chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart), [`chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart) | Banyak nilai *hardcoded* (`BorderRadius.circular(10)`, `fontSize: 12`, `Colors.white54`, `EdgeInsets.symmetric(horizontal: 1)`) dan bayangan (`Colors.black.withOpacity`) yang merusak estetika *flat minimalist*. | Kepatuhan 100% pada token terpusat tanpa *magic numbers* seperti pada [Signal Android](https://github.com/signalapp/signal-android) dan [Slack Block Kit](https://docs.slack.dev/block-kit/). | 2.5 / 5.0 | Tinggi (P0) |
| **Kontras Warna & Keterbacaan** | [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), [chat\_theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/chat_theme_settings_screen.dart) | Fungsi `textMutedOf(context)` menurunkan opasitas ke 72% sehingga rasio kontras jatuh ke `2.95:1` (Light) dan `3.86:1` (Dark); preset bubble Emerald (`#10B981`) dan Orange (`#F97316`) gagal kontras teks putih. | Rasio kontras minimal `4.5:1` untuk teks normal dan `3.0:1` untuk komponen non-teks sesuai [WCAG 2.2 SC 1.4.3 & 1.4.11](https://www.w3.org/TR/WCAG22/). | 2.2 / 5.0 | Kritis (P0) |
| **Sistem Tipografi & Hierarki Informasi** | [`typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart), [`pubspec.yaml`](https://github.com/tholeteplok/Mekaar_chat/blob/main/pubspec.yaml) | Kombinasi 4 keluarga font (`PlusJakartaSans`, `Baloo2`, `SpaceGrotesk`, `Acidic`) menciptakan disonansi nada antara karakter *playful* dan aplikasi keamanan *enterprise*; ukuran *body* terlalu besar (`16pt`–`18pt`) berbanding *label* ekstrem kecil (`11pt`). | Maksimal 2 keluarga font (UI Sans + Monospace teknis) dan skala modular yang mendukung *Dynamic Type* ([Apple HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography)). | 2.7 / 5.0 | Tinggi (P1) |
| **Ergonomi Sentuh & Aksesibilitas** | [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), [reactions\_strip.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/reactions_strip.dart), [`chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart) | Area sentuh tombol putar suara hanya `32x32` dp dan tombol aksi lampiran `40x40` dp; ketiadaan pembungkus `Semantics` dan alternatif satu ketukan untuk aksi geser rekam suara. | Target sentuh minimal `48x48` dp ([Material Design 3 Accessibility](https://m3.material.io/foundations/designing)), `44x44` pt ([Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)), dan kepatuhan [WCAG 2.2 SC 2.5.7 & 2.5.8](https://www.w3.org/TR/WCAG22/). | 2.0 / 5.0 | Kritis (P0) |
| **Kepadatan Informasi & Komponen Perpesanan** | [`chat_screen.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/screens/chat_screen.dart), [`chat_list_tile.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_list_tile.dart), [themed\_bubble\_container.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/themed_bubble_container.dart) | Ukuran kontainer media statis (`220x180` px) berisiko terpotong pada layar sempit/lipat; *composer* dan *bubble* belum memiliki pengelompokan rapat (*tight grouping*) untuk pesan beruntun dari pengirim yang sama. | *Adaptive layout* dan pengelompokan pesan vertikal dinamis ala [Signal iOS](https://github.com/signalapp/Signal-iOS) dan [Telegram Android](https://telegram.org/blog/crafting-android-design-and-more). | 3.2 / 5.0 | Sedang (P1) |

Secara keseluruhan, indeks kematangan desain antarmuka [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat) saat ini berada pada angka **2.57 dari 5.00** (Tahap *Emerging Modularity*). Arsitektur visual telah melampaui tahap pembuatan prototipe ad-hoc berkat hadirnya dukungan *Stealth OLED Mode* dan pemisahan direktori `lib/core/constants/`, namun belum mencapai tahap *Systematic Enterprise Governance* (skor $\ge 4.5$) karena ketergantungan pada metode pembantu imperatif dan pelanggaran kontras warna di sejumlah titik krusial.

## Audit Mendalam Arsitektur Design Tokens

Dalam rekayasa sistem desain modern yang mengacu pada [W3C Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/2025.10/format/) dan [Material Design 3 Design Tokens](https://m3.material.io/foundations/design-tokens), token desain wajib diorganisasikan ke dalam tiga taksonomi berlapis: **Reference Tokens** (nilai primitif statis seperti kode hex atau piksel murni), **System/Semantic Tokens** (peran kontekstual yang berubah mengikuti tema seperti `color.surface.elevated` atau `color.text.muted`), dan **Component Tokens** (spesifikasi terikat komponen seperti `chatBubble.outgoing.background` atau `voicePlayer.waveform.inactive`). Pemisahan tiga lapis ini memastikan bahwa perubahan rebranding atau penyesuaian kontras pada satu tema tidak merusak komponen di tema lain.

Pemeriksaan terhadap [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), [`lib/core/constants/dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart), [`lib/core/constants/typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart), dan [`lib/core/constants/themes.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart) menunjukkan adanya tiga anomali arsitektural pada lapisan token [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat).

### Fragmentasi Penamaan dan Duplikasi Kelas Warna

Di dalam [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), terdapat dua kelas warna yang hidup berdampingan: `AppColors` dan `MekaarColors`. Keberadaan dua titik masuk (*entry point*) untuk nilai warna menyebabkan pengembang di berbagai modul fitur (`lib/features/chat/`, `lib/features/guardian/`, `lib/features/sos/`, dan `lib/features/settings/`) memanggil konstanta secara tidak seragam. Sebagian berkas memanggil `AppColors.primaryBlue` atau `AppColors.cardDark`, sementara berkas lain memanggil `MekaarColors.primary` atau metode pembantu `MekaarColors.cardOf(context)`. Selain itu, penamaan token di dalam `colors.dart` mencampuradukkan nama deskriptif kromatik (*primitive naming* seperti `blue`, `darkBlue`, `cyan`, `yellow`, `purple`, `pink`, `charcoal`) dengan nama fungsional (*semantic naming* seperti `sosCoral`, `safeTeal`, `warningAmber`, `stealthSurface`). Ketika sebuah komponen UI memanggil token bernama `MekaarColors.blue` secara langsung, komponen tersebut mengunci dirinya pada nilai kromatik `#136CFC` dan kehilangan kemampuan beradaptasi saat pengguna beralih ke mode *Stealth OLED* atau memilih tema obrolan kustom di [lib/features/settings/screens/chat\_theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/chat_theme_settings_screen.dart).

### Resolusi Tema Imperatif versus ThemeExtension Deklaratif

Alih-alih mengintegrasikan seluruh token semantik ke dalam pohon widget Flutter melalui mekanisme standar `ThemeExtension<T>` pada [`lib/core/constants/themes.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart), [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart) mengandalkan fungsi pembantu statis berbasis konteks: `textPrimaryOf(BuildContext c)`, `textMutedOf(BuildContext c)`, `surfaceOf(BuildContext c)`, `cardOf(BuildContext c)`, dan `borderOf(BuildContext c)`. Pendekatan imperatif ini menimbulkan tiga kelemahan teknis pada skala *enterprise*:

1. **Inspeksi Kondisional Berulang**: Setiap kali fungsi `*Of(context)` dipanggil di dalam metode `build()`, kode harus mengevaluasi ulang status tema aktif (apakah *Light*, *Dark*, atau *Stealth*) secara manual.
2. **Ketiadaan Interpolasi Animasi Tema (`lerp`)**: Berbeda dengan `ThemeExtension` milik Flutter yang menyediakan metode `lerp(ThemeExtension<T>? other, double t)` untuk mentransisikan warna secara mulus (*smooth cross-fade*) ketika pengguna mengganti mode tampilan di [lib/features/settings/screens/theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/theme_settings_screen.dart), fungsi statis menyebabkan perubahan warna terjadi secara patah (*hard snap*).
3. **Manipulasi Opasitas Runtime yang Merusak Kontras**: Di dalam `textMutedOf(BuildContext c)`, kode melakukan operasi `textSecondaryLight.withValues(alpha: 0.72)` pada mode terang dan `textSecondaryDark.withValues(alpha: 0.72)` pada mode gelap, sedangkan pada mode *Stealth* mengembalikan warna solid `stealthTextMuted` (`#94A3B8`). Perbedaan perilaku antara warna semi-transparan di mode *Light/Dark* dan warna solid di mode *Stealth* menciptakan ketidakkonsistenan visual ketika teks dirender di atas permukaan berlapis (*nested cards* atau *chat bubbles*).

| Kategori Token | Implementasi Saat Ini di `Mekaar_chat` | Nilai Saat Ini di Kode Sumber | Masalah Arsitektural & Konsistensi | Rekomendasi Struktur Token Standar W3C DTCG / M3 |
| :--- | :--- | :--- | :--- | :--- |
| **Warna Utama & Aksen** | `AppColors` / `MekaarColors` di [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart) | `blue: #136CFC`, `accentLime: #C3F84A`, `cyan: #38BDF8`, `purple: #8B5CF6`, `pink: #F472B6` | Nama token merujuk pada rona warna fisik (*hue*), bukan peran semantik; `accentLime` (`#C3F84A`) terlalu terang untuk latar teks putih. | Pisahkan menjadi `MekaarPrimitives.blue500` (`#136CFC`) dan `MekaarColorTokens.brandPrimary`, `brandAccent`, `onBrandPrimary` (`#FFFFFF`), `onBrandAccent` (`#011E34`). |
| **Warna Permukaan (Surface)** | `surfaceOf(c)`, `cardOf(c)` di [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart) | Light: `#FAF9F6` / `#FFFFFF`; Dark: `#111E34` / `#1E304F`; Stealth: `#000000` / `#0F172A` / `#1E293B` | Mode *Light* dan *Dark* hanya memiliki 2 tingkat elevasi permukaan (Canvas & Card), sedangkan *Stealth* memiliki 3 tingkat (`stealthBg`, `stealthSurface`, `stealthCard`). | Standarisasi 4 tingkat permukaan di semua mode sesuai [Material Design 3 Color System](https://m3.material.io/styles/color/system/overview): `surfaceCanvas`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`. |
| **Warna Teks & Ikon** | `textPrimaryOf(c)`, `textMutedOf(c)` di [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart) | Light: `#011E34` & `#5C6B85` (alpha 0.72); Dark: `#F4F9FF` & `#9FB0C9` (alpha 0.72); Stealth: `#F8FAFC` & `#94A3B8` | Konstanta `textMuted` (`#6B7599`) berstatus *deprecated* tetapi masih ada di kode; pengurangan *alpha* 72% menyebabkan kegagalan kontras WCAG AA. | Hapus seluruh modifikasi `.withValues(alpha: 0.72)` pada token teks; gunakan nilai hex solid yang telah teruji rasio kontrasnya (`textPrimary`, `textSecondary`, `textTertiary`, `textDisabled`). |
| **Warna Semantik Keamanan** | `sosCoral`, `sosDeepRed`, `safeTeal`, `warningAmber` di [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart) | `#FF5D5D`, `#D92632`, `#2DD4BF`, `#FBBF24`; Stealth memiliki set terpisah: `#22C55E`, `#F59E0B`, `#EF4444` | Terdapat dua set warna status yang berbeda antara mode reguler dan mode *Stealth* tanpa pemetaan token yang menyatu untuk latar, border, dan teks di atasnya. | Buat kelompok token semantik utuh per status (`statusDangerBg`, `statusDangerBorder`, `statusDangerText`, `statusSafe*`, `statusWarning*`, `statusEncrypted*`). |
| **Skala Jarak (Spacing)** | `MekaarSpacing` di [`dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart) | `xs: 4`, `sm: 8`, `md: 12`, `lg: 16`, `xl: 20`, `xxl: 24`, `section: 32` | Tidak memiliki langkah `2px` (`xxs`) untuk celah mikro antar elemen di dalam gelembung pesan (sehingga pengembang melakukan *hardcode* `1px`–`2px`) dan tidak ada langkah `40px`/`48px`. | Lengkapi skala grid 4pt dengan `xxs: 2.0` (khusus sub-grid mikro seperti *waveform*/badge), `xs: 4.0`, `sm: 8.0`, `md: 12.0`, `lg: 16.0`, `xl: 20.0`, `xxl: 24.0`, `xxxl: 32.0`, `section: 48.0`. |
| **Radius Sudut (Shape)** | `MekaarRadius` di [`dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart) | `sm: 12`, `card: 16`, `md: 18`, `lg: 24`, `xl: 32`, `pill: 999` | Tidak terdapat radius kecil di bawah `12px` (`xs: 4px` atau `sm: 8px`) untuk elemen internal seperti *progress bar*, *thumbnail* kutipan balasan, atau *chip* reaksi di dalam gelembung. | Restrukturisasi skala radius: `xs: 4.0`, `sm: 8.0`, `md: 12.0`, `lg: 16.0`, `messageBubble: 18.0`, `xl: 24.0`, `xxl: 32.0`, `full: 999.0`. |

### Celah pada Skala Dimensi dan Ukuran Komponen

Pada [`lib/core/constants/dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart), kelas `MekaarRadius` menetapkan nilai terkecil `sm: 12px`. Dalam praktik desain antarmuka perpesanan *enterprise* seperti [Slack](https://docs.slack.dev/concepts/designing-with-block-kit) dan [Signal](https://github.com/signalapp/signal-android), komponen yang bersarang di dalam kontainer lain (*nested elements*—seperti kotak kutipan balasan pesan, bilah gelombang audio, atau pratinjau dokumen di [lib/core/widgets/bubbles/file\_bubble\_card.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/file_bubble_card.dart)) harus memiliki radius sudut yang lebih kecil daripada kontainer induknya mengikuti rumus geometris konsentris $R_{\text{inner}} = \max(0, R_{\text{outer}} - \text{Padding})$. Apabila gelembung pesan memiliki radius luar `MekaarRadius.md` (`18px`) dan *padding* internal `8px`–`10px`, maka elemen di dalamnya membutuhkan radius `8px` atau `10px`, sementara batang *waveform* audio membutuhkan radius `2px`–`4px`. Karena `MekaarRadius` tidak menyediakan token di bawah `12px`, pengembang terpaksa menulis `BorderRadius.circular(10)` dan `BorderRadius.circular(2)` secara manual di [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart).

Demikian pula pada kelas `MekaarSizes` di [`lib/core/constants/dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart), ukuran kontainer media obrolan ditetapkan secara kaku sebesar `220px` lebar kali `180px` tinggi. Pada perangkat layar lipat (*foldable devices*), layar kecil dengan pengaturan perbesaran tampilan (*display zoom*), atau tampilan *split-screen* *enterprise*, ukuran piksel logis statis berisiko melampaui proporsi lebar gelembung pesan yang ideal (maksimal 72%–75% dari lebar layar aktif) atau memotong aspek rasio asli media pada [lib/core/widgets/bubbles/image\_bubble.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/image_bubble.dart) dan [lib/core/widgets/bubbles/video\_bubble.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/video_bubble.dart).

## Evaluasi Konsistensi Implementasi dan Kebocoran Nilai Hardcoded

Sistem desain hanya efektif apabila seluruh lapisan presentasi mematuhi *Single Source of Truth* (SSOT) yang didefinisikan pada modul konstanta. Audit statis pada berkas-berkas di dalam [lib/core/widgets/](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/tree/main/lib/core/widgets) dan [`lib/features/`](https://github.com/tholeteplok/Mekaar_chat/tree/main/lib/features) menunjukkan fenomena *token bypass*—yakni penulisan nilai warna, ukuran teks, jarak tepi, dan opasitas secara langsung di dalam pohon widget.

### Kebocoran Nilai Hardcoded pada Komponen Gelembung dan Pemutar Media

Contoh paling nyata dari pengabaian sistem token terlihat pada [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), [`lib/core/widgets/chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart), dan [`lib/features/chat/screens/chat_screen.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/screens/chat_screen.dart). Di dalam `VoiceBubblePlayer`, warna latar *overlay* durasi menggunakan `Colors.black.withValues(alpha: 0.75)`, warna teks/ikon durasi menggunakan `Colors.white54`, serta status aktif menggunakan `Colors.white`. Lebih jauh lagi, variasi warna elemen dihitung di tempat menggunakan `widget.textColor.withValues(alpha: 0.35)` untuk batang gelombang suara yang belum diputar dan `widget.textColor.withValues(alpha: 0.8)` untuk elemen sekunder. Untuk dimensi dan tipografi, komponen yang sama menggunakan `BorderRadius.circular(10)`, `BorderRadius.circular(2)`, `EdgeInsets.symmetric(horizontal: 1)`, `SizedBox(width: 8)`, `SizedBox(width: 32, height: 32)`, `Icon(..., size: 32)`, `size: 20`, serta `TextStyle(color: Colors.white54, fontSize: 12)` tanpa merujuk pada `MekaarRadius`, `MekaarSpacing`, `MekaarSizes`, maupun `MekaarTypography`.

| Berkas & Komponen | Elemen UI yang Terdampak | Nilai Hardcoded di Kode Sumber | Token Eksisting yang Seharusnya Digunakan | Token Baru yang Perlu Ditambahkan |
| :--- | :--- | :--- | :--- | :--- |
| [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) (`VoiceBubblePlayer`) | Latar *overlay* & teks durasi | `Colors.black.withValues(alpha: 0.75)`, `Colors.white54`, `fontSize: 12` | `MekaarTypography.caption` (`11pt`) atau `MekaarTypography.bodySmall` (`14pt`) | `MekaarComponentTokens.mediaOverlayBg` & `mediaOverlayText` (`#FFFFFF` solid) |
| [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) (`VoiceBubblePlayer`) | Batang *waveform* & kontainer | `BorderRadius.circular(2)`, `BorderRadius.circular(10)`, `EdgeInsets.symmetric(horizontal: 1)` | — (Belum tersedia di `MekaarRadius` dan `MekaarSpacing`) | `MekaarRadius.xxs` (`2.0`), `MekaarRadius.sm` (`8.0`), `MekaarSpacing.xxs` (`2.0`) |
| [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) (`VoiceBubblePlayer`) | Tombol Play/Pause & spasi | `SizedBox(width: 32, height: 32)`, `Icon(..., size: 32)`, `SizedBox(width: 8)` | `MekaarSpacing.sm` (`8.0`), `MekaarSizes.iconBadge` (`44.0`) | `MekaarSizes.touchTargetMin` (`48.0`) dengan *icon size* `24.0` |
| [`chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart) (`ChatBubble`) | Dekorasi bayangan, warna status, & *padding* | `Colors.black.withOpacity(...)`, `Colors.white`, `Colors.red`, `EdgeInsets.only(...)` | `MekaarRadius.md` (`18.0`), `MekaarColors.sosDeepRed` | `MekaarComponentTokens.bubbleIncomingSurface`, `bubbleOutgoingSurface`, tanpa *drop shadow* |
| [`chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart) (`ChatComposer`) | Radius bilah input & ukuran tombol kiri | `BorderRadius.circular(24.0)`–`28.0`, container tombol `40x40` px, ikon `24.0` px | `MekaarRadius.lg` (`24.0`) atau `MekaarRadius.pill` (`999`), `MekaarSizes.composerButton` (`42.0`) | Standarisasi seluruh tombol aksi composer ke `MekaarSizes.touchTargetMin` (`48.0`) |
| [`chat_list_tile.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_list_tile.dart) (`ChatListTile`) | Ukuran teks nama (`15–16sp`), *subtitle* (`13–14sp`), *timestamp* (`11–12sp`) | `TextStyle` manual dengan `fontSize: 15.0`, `13.0`, `12.0` | `MekaarTypography.bodyMedium` (`16pt`), `MekaarTypography.bodySmall` (`14pt`), `MekaarTypography.caption` (`11pt`) | `MekaarTypography.chatListTitle` (`16pt SemiBold`) & `chatListSubtitle` (`14pt Regular`) |

### Inkonsistensi Paradigma Visual: Flat Minimalism versus Efek Bayangan dan Opasitas

Karakter visual utama yang dibangun oleh [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart) adalah pendekatan permukaan berlapis yang tegas menggunakan batas tepi tipis (*1px crisp border*: `#DCE7F5` pada mode terang, `#25395B` pada mode gelap, dan `#334155` pada mode *Stealth*). Pendekatan *flat surface with subtle border* ini sangat selaras dengan tren antarmuka *enterprise* modern (seperti [Slack](https://docs.slack.dev/block-kit/) dan [Linear](https://m3.material.io/foundations/design-tokens)) karena meningkatkan ketajaman batas antarkomponen tanpa membebani kinerja *raster thread* GPU melalui perhitungan *blur* bayangan (`BoxShadow`).

Namun, pada [`lib/core/widgets/chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart) dan [`lib/features/chat/screens/chat_screen.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/screens/chat_screen.dart), masih ditemukan penggunaan dekorasi bayangan `Colors.black.withOpacity(...)` pada gelembung pesan dan elemen melayang. Pada mode *Dark* (`#111E34`) dan mode *Stealth OLED* (`#000000`), bayangan hitam tidak menghasilkan persepsi kedalaman (*depth*) sama sekali, melainkan menciptakan efek halo kotor di sekitar sudut gelembung. Sebaliknya, pada mode *Light* (`#FAF9F6`), pencampuran antara batas tepi biru muda (`#DCE7F5`) dan bayangan hitam menurunkan kebersihan estetika *flat minimalist*. Standar industri seperti [Material Design 3](https://m3.material.io/styles/color/system/overview) dan [Apple HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials) merekomendasikan pemisahan elevasi melalui gradasi luminansi permukaan (*surface tonal elevation*) dan garis batas `1dp` berkontras terukur, bukan dengan menumpuk *drop shadow* gelap pada setiap gelembung pesan.

## Analisis Kontras Warna dan Kepatuhan Aksesibilitas Visual

Dalam standar [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/), kriteria keberhasilan **SC 1.4.3 Contrast (Minimum) (Level AA)** mewajibkan rasio kontras luminansi relatif minimal **4.5:1** untuk teks berukuran normal (di bawah `18pt` reguler atau di bawah `14pt` tebal) dan minimal **3.0:1** untuk teks berukuran besar ($\ge 18\text{pt}$ reguler atau $\ge 14\text{pt}$ tebal). Untuk aplikasi *enterprise* dengan tingkat keterbacaan tinggi di bawah sinar matahari langsung maupun di ruangan gelap, kriteria **SC 1.4.6 Contrast (Enhanced) (Level AAA)** menetapkan ambang **7.0:1** untuk teks normal. Selain itu, kriteria **SC 1.4.11 Non-text Contrast (Level AA)** mewajibkan kontras minimal **3.0:1** untuk komponen antarmuka aktif (seperti batas kotak input, indikator fokus, gelombang audio aktif, dan ikon status pengiriman pesan).

Perhitungan rasio kontras dilakukan menggunakan rumus luminansi relatif standar W3C:

$$L = 0.2126 \times R_{\text{lin}} + 0.7152 \times G_{\text{lin}} + 0.0722 \times B_{\text{lin}}$$

$$\text{Contrast Ratio} = \frac{L_{\text{lighter}} + 0.05}{L_{\text{darker}} + 0.05}$$

Pengujian matematis terhadap seluruh pasangan warna latar dan teks pada [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), dan [lib/features/settings/screens/chat\_theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/chat_theme_settings_screen.dart) menunjukkan bahwa meskipun warna teks utama (`textPrimary`) lulus pada tingkat AAA di ketiga mode, warna teks sekunder/redup (`textMutedOf`), warna aksen darurat (`sosCoral`), dan beberapa preset tema gelembung pesan mengalami kegagalan kritis terhadap standar [WCAG 2.2 Level AA](https://www.w3.org/TR/WCAG22/).

| Mode / Konteks Komponen | Warna Latar (Background) | Warna Teks / Elemen (Foreground) | Rasio Kontras Terhitung | Status WCAG 2.2 AA (4.5:1) | Status WCAG 2.2 AAA (7.0:1) | Analisis Dampak & Solusi Kode |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **Light Mode – Teks Utama di Canvas** | `#FAF9F6` ($L = 0.947$) | `#011E34` (`textPrimaryLight`, $L = 0.011$) | **16.34 : 1** | Lulus | Lulus | Sangat tajam dan nyaman dibaca untuk percakapan panjang. |
| **Light Mode – Teks Muted (`textMutedOf`)** | `#FAF9F6` ($L = 0.947$) | `#5C6B85` dengan `alpha: 0.72` (Efektif `#8893A5`, $L = 0.288$) | **2.95 : 1** | **Gagal** | Gagal | Tanpa pengurangan *alpha* (`#5C6B85` solid, $L = 0.145$), kontrasnya mencapai **5.12 : 1** (Lulus AA). Hapus `.withValues(alpha: 0.72)`. |
| **Dark Mode – Teks Utama di Card** | `#1E304F` (`cardDark`, $L = 0.030$) | `#F4F9FF` (`textPrimaryDark`, $L = 0.936$) | **12.39 : 1** | Lulus | Lulus | Kontras sangat baik pada permukaan kartu mode gelap. |
| **Dark Mode – Teks Muted (`textMutedOf`) di Card** | `#1E304F` (`cardDark`, $L = 0.030$) | `#9FB0C9` dengan `alpha: 0.72` (Efektif `#7B8CA7`, $L = 0.257$) | **3.86 : 1** | **Gagal** | Gagal | Tanpa pengurangan *alpha* (`#9FB0C9` solid, $L = 0.426$), kontras di atas `#1E304F` adalah **5.98 : 1** (Lulus AA). Hapus `.withValues(alpha: 0.72)`. |
| **Stealth OLED – Teks Utama** | `#000000` (`stealthBg`, $L = 0.000$) | `#F8FAFC` (`stealthText`, $L = 0.955$) | **20.10 : 1** | Lulus | Lulus | Kontras sangat tinggi; di layar OLED gelap gulita berisiko menimbulkan *halation* (efek pendaran pada mata astigmatisme) jika digunakan pada blok teks besar. |
| **Stealth OLED – Teks Muted di Card** | `#1E293B` (`stealthCard`, $L = 0.023$) | `#94A3B8` (`stealthTextMuted`, $L = 0.359$) | **5.61 : 1** | Lulus | Gagal | Lulus AA dengan baik karena menggunakan warna solid `#94A3B8` tanpa pemotongan *alpha*. |
| **Bubble Outgoing Utama (`Primary Blue`)** | `#136CFC` (`blue`, $L = 0.179$) | `#FFFFFF` (`Colors.white`, $L = 1.000$) | **4.59 : 1** | Lulus (Batas Minimal) | Gagal | Berada tepat di atas ambang 4.5:1; untuk ketajaman *enterprise* yang lebih kokoh, gelapkan sedikit ke `#0F5FE0` (**5.28 : 1**). |
| **Voice Bubble – Durasi & Metadata** | `#136CFC` (`blue`, $L = 0.179$) | `Colors.white54` (Efektif `#92BBFE`, $L = 0.487$) | **2.35 : 1** | **Gagal Kritis** | Gagal | Teks `11pt`–`12pt` dengan kontras `2.35:1` sangat sulit dibaca. Ganti dengan `#E2EEFF` (`alpha: 0.90` atau solid, kontras **3.95:1**–**4.59:1**). |
| **Voice Bubble – Waveform Belum Diputar** | `#136CFC` (`blue`, $L = 0.179$) | `textColor.withValues(alpha: 0.35)` (Efektif `#669FFD`, $L = 0.348$) | **1.74 : 1** | **Gagal (SC 1.4.11)** | Gagal | Gagal memenuhi kontras non-teks `3.0:1` ([WCAG 2.2 SC 1.4.11](https://www.w3.org/TR/WCAG22/)). Gunakan minimal `#B8D4FE` atau pola dua warna kontras. |
| **Indikator Darurat – SOS Coral** | `#FF5D5D` (`sosCoral`, $L = 0.299$) | `#FFFFFF` (`Colors.white`, $L = 1.000$) | **3.01 : 1** | **Gagal (Teks Normal)** | Gagal | Tombol/banner SOS dengan teks putih di atas `#FF5D5D` gagal AA untuk teks $< 14\text{pt}$ Bold. Gunakan `sosDeepRed` (`#D92632`, kontras **4.91 : 1**) untuk latar tombol/banner darurat. |
| **Aksen Lime Green & Warning Amber** | `#C3F84A` ($L = 0.793$) / `#FBBF24` ($L = 0.575$) | `#FFFFFF` ($L = 1.000$) vs `#011E34` ($L = 0.011$) | **1.25 : 1** (Putih) / **13.82 : 1** (Gelap) | **Gagal (Putih)** / Lulus (Gelap) | Gagal (Putih) / Lulus (Gelap) | Wajib mengunci pasangan token `onAccentLime` dan `onWarningAmber` ke warna gelap `#011E34`, bukan `#FFFFFF`. |
| **Preset Tema Bubble – Emerald & Sunset Orange** | `#10B981` ($L = 0.352$) / `#F97316` ($L = 0.317$) | `#FFFFFF` (`Colors.white`, $L = 1.000$) | **2.61 : 1** (Emerald) / **2.86 : 1** (Orange) | **Gagal Kritis** | Gagal | Teks pesan putih pada gelembung Emerald dan Sunset Orange di [chat\_theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/chat_theme_settings_screen.dart) sangat menyilaukan. Gelapkan ke `#047857` (**5.15:1**) dan `#C2410C` (**5.83:1**). |

### Akar Masalah Kontras: Degradasi Opasitas Bertingkat

Temuan paling krusial dari matriks di atas adalah bahwa warna dasar yang dipilih di dalam [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart)—yaitu `textSecondaryLight` (`#5C6B85`) dan `textSecondaryDark` (`#9FB0C9`)—sebenarnya **sudah memenuhi standar WCAG 2.2 AA** apabila dirender sebagai warna solid (`5.12:1` di atas `#FAF9F6` dan `5.98:1` di atas `#1E304F`). Kegagalan kontras justru dipicu oleh logika di dalam fungsi `textMutedOf(BuildContext c)` yang memanggil `.withValues(alpha: 0.72)`. Ketika warna abu-abu kebiruan tersebut diturunkan opasitasnya menjadi 72%, warna tersebut bercampur dengan luminansi latar di belakangnya dan kehilangan daya bedanya hingga jatuh ke angka `2.95:1` pada mode terang dan `3.86:1` pada mode gelap.

Masalah ini semakin memburuk pada elemen-elemen yang menerapkan pemotongan opasitas kedua di tingkat komponen, seperti pada [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) (`withValues(alpha: 0.35)`) dan batas pemisah kartu (`borderLight: #DCE7F5` di atas `#FAF9F6` yang hanya memiliki rasio kontras `1.15:1`, jauh di bawah syarat `3.0:1` [WCAG 2.2 SC 1.4.11](https://www.w3.org/TR/WCAG22/) untuk batas komponen input aktif seperti [`lib/features/chat/widgets/chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart)). Untuk komponen input aktif (kotak pencarian dan *chat composer*), batas tepi pada mode terang perlu diperkuat ke minimal `#8CA2C0` (kontras `2.5:1`–`3.0:1`) saat kondisi normal dan `#136CFC` (`2px`) saat kondisi fokus.

## Audit Sistem Tipografi, Skala Modular, dan Keterbacaan

Tipografi pada aplikasi perpesanan merupakan tulang punggung antarmuka karena lebih dari 85% interaksi pengguna berpusat pada pemindaian daftar percakapan, pembacaan untaian pesan, dan verifikasi cap waktu (*timestamps*) maupun indikator enkripsi. Pemeriksaan pada [`lib/core/constants/typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart) dan [`pubspec.yaml`](https://github.com/tholeteplok/Mekaar_chat/blob/main/pubspec.yaml) menunjukkan empat aspek tipografi yang memerlukan penataan ulang agar sejajar dengan standar [Material Design 3 Typography](https://m3.material.io/styles/typography/type-scale-tokens) dan [Apple HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography).

### Disonansi Empat Keluarga Font dan Beban Bundel Aset

Saat ini, [`pubspec.yaml`](https://github.com/tholeteplok/Mekaar_chat/blob/main/pubspec.yaml) dan [`lib/core/constants/typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart) memuat empat keluarga huruf sekaligus:
1. **`PlusJakartaSans`**: Digunakan sebagai font antarmuka utama (Regular 400, Medium 500, SemiBold 600, Bold 700, ExtraBold 800).
2. **`Baloo2`**: Digunakan pada `Heading Large` (`24pt Bold`) dan elemen bernuansa kasual/*playful*.
3. **`SpaceGrotesk`**: Digunakan untuk kode, token keamanan, dan data teknis.
4. **`Acidic`**: Digunakan sebagai aksen dekoratif khusus.

Dalam standar produk *enterprise* global (seperti [Signal](https://github.com/signalapp/signal-desktop), [Slack](https://docs.slack.dev/concepts/app-design), atau aplikasi keamanan siber korporat), konsistensi otoritas visual dijaga dengan membatasi sistem tipografi maksimal pada **dua keluarga huruf**: satu *Neo-Grotesque / Humanist Sans-Serif* dengan keterbacaan tinggi (`PlusJakartaSans`) untuk seluruh hierarki UI (mulai dari *Display*, *Heading*, *Body*, hingga *Caption*), serta satu huruf *Monospace / Technical Sans* (`SpaceGrotesk` atau `JetBrains Mono`) khusus untuk sidik jari kunci kriptografi E2EE (`X25519`), PIN keamanan di [lib/features/auth/screens/pin\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/auth/screens/pin_screen.dart), penghitung waktu darurat di [lib/features/sos/screens/sos\_active\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/sos/screens/sos_active_screen.dart), dan log audit di [lib/features/settings/screens/security\_logs\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/security_logs_screen.dart). Penggunaan `Baloo2` (yang memiliki ujung membulat bergaya komik/anak-anak) dan `Acidic` di dalam aplikasi yang menangani keamanan E2EE serta darurat SOS mengaburkan citra keandalan dan keseriusan sistem keamanan.

### Ketimpangan Skala Ukuran Teks (Body vs. Label/Caption)

Analisis terhadap kurva ukuran huruf pada [`lib/core/constants/typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart) memperlihatkan ketimpangan proporsi pada bagian tengah dan bawah skala:

| Nama Gaya di `typography.dart` | Ukuran & Bobot Saat Ini | Line Height & Letter Spacing Saat Ini | Masalah Ergonomi & Keterbacaan | Standar Enterprise (M3 / Apple HIG / Signal) |
| :--- | :--- | :--- | :--- | :--- |
| `displayLarge` & `displayMedium` | `32pt` & `28pt`, ExtraBold (800) | `letterSpacing: -0.5` | Proporsional untuk layar *onboarding* atau angka PIN besar. | `32sp` / `28sp`, Bold (700) atau ExtraBold (800), `height: 1.2`. |
| `headingLarge` | `24pt`, Bold (700), Font `Baloo2` | Default | Pergantian mendadak ke font `Baloo2` merusak kohesi visual dengan `headingMedium` (`PlusJakartaSans`). | Gunakan `PlusJakartaSans`, `22sp`–`24sp`, Bold (700), `letterSpacing: -0.3`, `height: 1.25`. |
| `headingMedium` & `headingSmall` | `20pt` & `18pt`, Bold (700) | Default | Sesuai untuk judul AppBar dan *bottom sheet*. | `20sp` & `18sp`, SemiBold (600) atau Bold (700), `height: 1.3`. |
| `sectionHeader` | `14.5pt`, Bold (700) | `letterSpacing: -0.2` | Ukuran pecahan `14.5pt` tidak lazim pada grid piksel utuh; `letterSpacing` negatif pada huruf sub-header kecil mengurangi keterbacaan. | Genapkan ke `14sp` SemiBold (600) atau `12sp` Bold Uppercase dengan `letterSpacing: +0.5`. |
| `bodyLarge` & `bodyMedium` | `18pt` (`height: 1.6`) & `16pt` (`height: 1.5`), Regular (400) | Default | Ukuran `18pt` terlalu besar untuk teks obrolan standar dan mengurangi kepadatan pesan di layar; `height: 1.6` membuat gelembung pesan terlalu renggang secara vertikal. | `bodyLarge`: `16sp` (`height: 1.45`), `bodyMedium` (Standar Bubble Chat): `15sp` (`height: 1.40`), `bodySmall`: `13.5sp`–`14sp` (`height: 1.38`). |
| `labelMedium`, `labelSmall`, `caption`, `badge` | Semua menumpuk di `11pt` (SemiBold 600, Bold 700, ExtraBold 800) | `letterSpacing: 0.2`, `height: 1.2` / `1.0` | Empat token berbeda memiliki ukuran identik (`11pt`) tanpa pembeda skala; `11pt` Bold/ExtraBold pada layar kerapatan rendah mengalami penggumpalan piksel (*ink trapping*). | Pisahkan menjadi `labelMedium`: `12sp` Medium (500), `caption`: `12sp` Regular (400) dengan `tabularFigures`, `badge`: `11sp` SemiBold (600). |

Selain ketimpangan antara `bodySmall` (`14pt`) yang langsung melompat turun ke `11pt` pada `labelMedium` (tanpa keberadaan ukuran `12pt` atau `13pt` di dalam `MekaarTypography`), itulah sebabnya pengembang pada [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) dan [`lib/features/chat/widgets/chat_list_tile.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_list_tile.dart) menulis `fontSize: 12` dan `fontSize: 13` secara *hardcoded*. Menambahkan ukuran `12sp` dan `13sp` ke dalam `MekaarTypography` serta mengaktifkan fitur OpenType `FontFeature.tabularFigures()` pada seluruh gaya cap waktu (*timestamp*), durasi audio, dan penghitung pesan belum dibaca akan mencegah lebar teks bergoyang (*layout jitter*) saat angka detik bergerak.

## Ergonomi Interaksi, Target Sentuh, dan Aksesibilitas Pembaca Layar

Standar aksesibilitas perangkat bergerak global—yakni [WCAG 2.2 SC 2.5.8 Target Size (Minimum)](https://www.w3.org/TR/WCAG22/) (minimal `24x24` CSS px tanpa pengecualian jarak), [Material Design 3 Accessibility Guidelines](https://m3.material.io/foundations/designing) (minimal **`48x48` dp**), dan [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) (minimal **`44x44` pt**)—menetapkan bahwa setiap elemen interaktif harus memiliki area ketuk (*hit-test box*) yang cukup luas agar dapat dioperasikan dengan satu ibu jari atau oleh pengguna dengan keterbatasan motorik halus. Dalam konteks [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat) yang memiliki modul darurat [lib/features/sos/](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/tree/main/lib/features/sos) dan pelacakan keamanan [`lib/features/guardian/`](https://github.com/tholeteplok/Mekaar_chat/tree/main/lib/features/guardian), kegagalan ketukan akibat area sentuh yang sempit merupakan risiko fungsional yang serius.

### Audit Area Sentuh (Touch Targets) dan Gestur Tunggal

Pemeriksaan kode pada komponen interaktif utama memperlihatkan sejumlah pelanggaran batas minimal area sentuh dan gestur:

1. **Tombol Putar/Jeda pada `VoiceBubblePlayer` ([`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart))**: Menggunakan `GestureDetector` yang membungkus `SizedBox(width: 32, height: 32)`. Luas area sentuh `32x32` dp hanya mencakup **44,4%** dari luas area sentuh minimal standar Android (`48x48` dp = $2.304\text{ dp}^2$ vs $1.024\text{ dp}^2$). Ketika pengguna mencoba mengetuk tombol putar di dalam gelembung pesan, ketukan yang meleset beberapa milimeter akan memicu aksi gelembung pesan induk atau tidak merespons sama sekali.
2. **Tombol Lampiran dan Emoji pada `ChatComposer` ([`lib/features/chat/widgets/chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart))**: Kontainer tombol aksi kiri berukuran `40x40` dp, sedangkan konstanta `MekaarSizes.composerButton` di [`lib/core/constants/dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart) bernilai `42px`. Keduanya masih berada di bawah standar `48x48` dp.
3. **Alternatif Gestur Geser untuk Perekaman Suara ([WCAG 2.2 SC 2.5.7 Dragging Movements](https://www.w3.org/TR/WCAG22/))**: Di dalam [`lib/features/chat/widgets/chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart), perekaman pesan suara mengandalkan gestur tahan-dan-geser horizontal (`_recordingSwipeOffset >= _recordingSwipeThreshold` sejauh `120.0` px) untuk membatalkan perekaman. Kriteria baru **WCAG 2.2 SC 2.5.7 (Dragging Movements - Level AA)** mewajibkan setiap fungsi yang bergantung pada gerakan menyeret (*dragging/swiping*) untuk menyediakan alternatif penunjuk tunggal (*single-pointer tap*), seperti mode ketuk-sekali untuk mengunci perekaman (*tap-to-lock*) disertai tombol eksplisit **Batal** (ikon tempat sampah) dan **Kirim** yang dapat diketuk tanpa harus menahan jari di layar. Implementasi serupa juga berlaku untuk [lib/features/chat/widgets/chat\_swipe\_action\_wrapper.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_swipe_action_wrapper.dart), yang harus selalu memiliki padanan aksi **Balas** di dalam [lib/core/widgets/bubbles/message\_context\_menu.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/message_context_menu.dart).

### Ketiadaan Pohon Semantik (Screen Reader Accessibility)

Pada aplikasi *enterprise*, kepatuhan terhadap pembaca layar (Android TalkBack dan iOS VoiceOver) sesuai [WCAG 2.2 SC 4.1.2 Name, Role, Value](https://www.w3.org/TR/WCAG22/) adalah syarat mutlak pengadaan korporat. Komponen kustom yang dibangun menggunakan `GestureDetector` atau `CustomPaint`—seperti [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), [lib/core/widgets/bubbles/themed\_bubble\_painter.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/themed_bubble_painter.dart), [lib/core/widgets/bubbles/read\_receipt\_icon.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/read_receipt_icon.dart), [lib/features/chat/widgets/nearby\_friends\_canvas.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/nearby_friends_canvas.dart), dan [lib/features/chat/widgets/nearby\_orbital\_canvas.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/nearby_orbital_canvas.dart)—tidak mengekspos peran (`button: true`, `slider: true`), label kontekstual (`label`), maupun nilai progres (`value`) ke pohon semantik Flutter. Akibatnya, pengguna TalkBack/VoiceOver tidak dapat mengetahui apakah sebuah pesan telah terbaca (`ReadReceiptIcon`), berapa durasi pesan suara yang sedang diputar, atau bagaimana berinteraksi dengan kanvas radar teman di sekitar.

## Benchmarking Komponen Perpesanan Terhadap Standar Industri Dunia

Untuk memposisikan [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat) sejajar dengan pemimpin global di ranah perpesanan aman dan kolaborasi *enterprise*—yaitu [Signal](https://github.com/signalapp/signal-android), [Slack](https://docs.slack.dev/block-kit/), dan [Telegram](https://core.telegram.org/bots/webapps)—evaluasi dilakukan pada lima komponen antarmuka inti perpesanan.

| Komponen UI | Implementasi `Mekaar_chat` Saat Ini | Praktik Terbaik Industri ([Signal](https://github.com/signalapp/signal-android), [Slack](https://docs.slack.dev/block-kit/), [Telegram](https://core.telegram.org/bots/webapps)) | Rekomendasi Peningkatan Desain Enterprise |
| :--- | :--- | :--- | :--- |
| **Gelembung Pesan (`ChatBubble` & `ThemedBubbleContainer`)** | Radius seragam `18px` (`MekaarRadius.md`) dengan ekor asimetris di [`chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart); setiap pesan berdiri sendiri dengan margin dan avatar penuh. | Pengelompokan pesan beruntun (*message clustering*): pesan dari pengirim yang sama dalam rentang `< 2` menit memiliki jarak vertikal rapat (`2dp`–`4dp`), radius sudut dalam mengecil (`4dp`–`6dp`), dan avatar hanya muncul pada pesan terakhir dalam kelompok. | Tambahkan properti `isFirstInGroup` dan `isLastInGroup` pada [`chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart) dan [chat\_message\_list\_view.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_message_list_view.dart) untuk merapatkan ritme vertikal hingga 30%. |
| **Pemutar Pesan Suara (`VoiceBubblePlayer`)** | Kontrol Play/Pause `32x32` dp, *waveform* dengan opasitas `0.35`, teks `Colors.white54` `12pt` di [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart). | Tombol utama `44x44` dp–`48x48` dp berkontras penuh, *scrubbing* gelombang audio interaktif dengan umpan balik *haptic*, badge kecepatan putar (`1x`, `1.5x`, `2x`) berbentuk *pill* kontras tinggi, serta pemutaran beruntun otomatis. | Perbesar *hit box* tombol ke `48x48` dp, ganti `Colors.white54` dengan token `onBubbleSecondary` berkontras $\ge 4.5:1$, dan bungkus *waveform* dengan widget `Semantics(slider: true)`. |
| **Bilah Input Pesan (`ChatComposer`)** | Kotak *pill* (`24px`–`28px`), tombol kiri `40x40` px, rekam suara *hold-and-swipe* (`120px` threshold) di [`chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart). | Transisi tinggi baris input yang mulus (`minLines: 1`, `maxLines: 5`–`6`) dengan menjaga perataan tombol aksi di bagian **bawah** (`CrossAxisAlignment.end`), disertai kunci rekam suara *slide-up-to-lock* dan mode tinjau audio sebelum kirim. | Pastikan perataan tombol composer menggunakan `CrossAxisAlignment.end` saat teks multi-baris, tingkatkan area ketuk tombol ke `48x48` dp, dan tambahkan UI *locked recording state*. |
| **Daftar Ruang Obrolan (`ChatListTile`)** | Avatar `48px`–`52px`, nama `15–16sp`, *subtitle* `13–14sp` (`maxLines: 1`) dengan `textMutedOf(context)` di [`chat_list_tile.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_list_tile.dart). | Hierarki visual 3 titik: indikator pesan belum dibaca mengubah bobot font *subtitle* menjadi `Medium/SemiBold` dengan warna `textPrimary`, menampilkan ikon status pengiriman/tipe media di depan *subtitle*, dan menjaga kesejajaran baseline antara judul dan *timestamp*. | Saat `unreadCount > 0`, ubah gaya *subtitle* dari `textMuted` menjadi `textPrimary` dengan bobot `FontWeight.w500` agar pengguna dapat memindai pesan baru bahkan tanpa melihat warna badge (mendukung pengguna buta warna sesuai [WCAG 2.2 SC 1.4.1](https://www.w3.org/TR/WCAG22/)). |
| **Indikator E2EE, Vault, & Darurat SOS** | Chip E2EE di [e2ee\_security\_chip.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/e2ee_security_chip.dart), banner brankas di [private\_vault\_active\_banner.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/private_vault_active_banner.dart), dan banner SOS di [emergency\_active\_banner.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/sos/widgets/emergency_active_banner.dart). | Hirarki interupsi bertingkat (*tiered banner hierarchy*): status keamanan pasif (E2EE aktif) ditampilkan secara tenang di sub-judul AppBar agar tidak memakan ruang vertikal, sedangkan peringatan darurat aktif (SOS / Kunci E2EE berubah) menggunakan banner kontras tinggi dengan aksi jelas. | Gabungkan status E2EE normal ke dalam baris sub-header [chat\_app\_bar.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_app_bar.dart) (ikon gembok `14dp` + label terverifikasi), dan cadangkan banner penuh di bawah AppBar hanya untuk status darurat (`SOS`), *Pinned Message*, atau pemulihan kunci ([chat\_e2ee\_restore\_sheet.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_e2ee_restore_sheet.dart)). |

### Optimalisasi Mode Stealth OLED untuk Pengalaman Enterprise Malam Hari

Keunggulan kompetitif yang sangat menonjol pada [`lib/core/constants/themes.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart) adalah hadirnya tema ketiganya, yakni **Stealth Mode (OLED)** yang memanfaatkan latar hitam murni `#000000` dengan permukaan kartu `#0F172A` dan `#1E293B`. Namun, pada layar OLED modern, penggunaan teks putih hampir murni (`#F8FAFC`, kontras `20.10:1`) di atas latar `#000000` sering menimbulkan dua efek samping visual:
1. **Halation (Astigmatism Blur)**: Kontras ekstrem di atas `18:1` pada mode gelap menyebabkan huruf putih tampak berpendar atau berbayang bagi sekitar 30%–40% populasi pengguna yang memiliki astigmatisme ringan.
2. **OLED Black Smearing**: Saat pengguna menggulir daftar pesan di [lib/features/chat/widgets/chat\_message\_list\_view.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_message_list_view.dart), piksel OLED yang mati total (`#000000`) membutuhkan waktu beberapa milidetik untuk menyala kembali menjadi warna kartu `#1E293B`, menciptakan jejak bayangan ungu/hitam (*smearing*).

Untuk menyempurnakan *Stealth Mode* ke tingkat *enterprise*, warna teks utama pada mode *Stealth* sebaiknya diturunkan sedikit luminansinya dari `#F8FAFC` menjadi `#E2E8F0` (Slate 200, rasio kontras **16.9:1**—tetap jauh di atas ambang AAA `7.0:1` namun bebas efek silau), dan setiap gelembung pesan di atas latar `#000000` wajib mempertahankan garis tepi `1px` `stealthCardBorder` (`#334155`, rasio kontras non-teks `1.70:1` atau ditingkatkan ke `#475569` dengan rasio **2.75:1**–**3.0:1**) untuk meredam ilusi *black smearing* saat pengguliran cepat.

## Spesifikasi Teknis Remediasi dan Peta Jalan Implementasi

Agar temuan audit ini dapat dieksekusi langsung ke dalam basis kode [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat) tanpa mengganggu logika bisnis maupun lapisan enkripsi lokal, berikut adalah spesifikasi teknis perubahan kode (*refactoring blueprint*) beserta peta jalan implementasi bertahap.

### 1. Spesifikasi Refactoring `ThemeExtension` untuk Token Semantik (`colors.dart` & `themes.dart`)

Gantikan pola fungsi statis `MekaarColors.*Of(context)` dan unifikasikan `AppColors` serta `MekaarColors` ke dalam arsitektur dua lapis: kelas primitif `MekaarPalette` (privat/internal) dan ekstensi tema `MekaarColorTokens extends ThemeExtension<MekaarColorTokens>` yang menghilangkan seluruh pemotongan opasitas `.withValues(alpha: 0.72)` pada teks:

```dart
import 'package:flutter/material.dart';

/// Lapisan 1: Reference / Primitive Tokens (Hanya dirujuk oleh definisi tema)
abstract final class MekaarPalette {
  // Brand & Core Primitives
  static const Color blue600 = Color(0xFF0F5FE0); // Kontras 5.28:1 dengan putih (menggantikan #136CFC untuk bubble)
  static const Color blue500 = Color(0xFF136CFC);
  static const Color navy950 = Color(0xFF011E34);
  static const Color navy900 = Color(0xFF111E34);
  static const Color navy800 = Color(0xFF1E304F);
  static const Color navy700 = Color(0xFF25395B);

  // Neutral & Surface Primitives
  static const Color ivory50 = Color(0xFFFAF9F6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF5C6B85); // Solid: 5.12:1 di atas ivory50
  static const Color slate400 = Color(0xFF94A3B8); // Solid: 5.61:1 di atas slate800
  static const Color slate300 = Color(0xFF9FB0C9); // Solid: 5.98:1 di atas navy800
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color ice50 = Color(0xFFF4F9FF);

  // Semantic Status Primitives (WCAG 2.2 AA Verified)
  static const Color lime400 = Color(0xFFC3F84A);
  static const Color red700 = Color(0xFFD92632); // 4.91:1 dengan teks putih
  static const Color red400 = Color(0xFFFF5D5D); // Khusus aksen/ikon di latar gelap
  static const Color emerald700 = Color(0xFF047857); // 5.15:1 dengan teks putih
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color orange700 = Color(0xFFC2410C); // 5.83:1 dengan teks putih
  static const Color amber400 = Color(0xFFFBBF24);
}

/// Lapisan 2 & 3: Semantic & Component Tokens berbasis ThemeExtension
@immutable
class MekaarColorTokens extends ThemeExtension<MekaarColorTokens> {
  final Color surfaceCanvas;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color borderSubtle;
  final Color borderInteractive;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color bubbleOutgoingBg;
  final Color bubbleOutgoingText;
  final Color bubbleOutgoingMeta;
  final Color bubbleIncomingBg;
  final Color bubbleIncomingText;
  final Color bubbleIncomingMeta;
  final Color statusDangerBg;
  final Color statusDangerText;

  const MekaarColorTokens({
    required this.surfaceCanvas,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.borderSubtle,
    required this.borderInteractive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.bubbleOutgoingBg,
    required this.bubbleOutgoingText,
    required this.bubbleOutgoingMeta,
    required this.bubbleIncomingBg,
    required this.bubbleIncomingText,
    required this.bubbleIncomingMeta,
    required this.statusDangerBg,
    required this.statusDangerText,
  });

  static const light = MekaarColorTokens(
    surfaceCanvas: MekaarPalette.ivory50,
    surfaceCard: MekaarPalette.white,
    surfaceElevated: MekaarPalette.white,
    borderSubtle: Color(0xFFDCE7F5),
    borderInteractive: Color(0xFF8CA2C0), // Memenuhi kontras batas input aktif
    textPrimary: MekaarPalette.navy950,   // 16.34:1 (AAA)
    textSecondary: MekaarPalette.slate500, // 5.12:1 (AA Solid, tanpa alpha 0.72)
    textMuted: MekaarPalette.slate500,     // 5.12:1 (AA Solid)
    bubbleOutgoingBg: MekaarPalette.blue600, // 5.28:1 dengan putih
    bubbleOutgoingText: MekaarPalette.white,
    bubbleOutgoingMeta: Color(0xFFE2EEFF), // > 4.5:1 di atas blue600
    bubbleIncomingBg: MekaarPalette.white,
    bubbleIncomingText: MekaarPalette.navy950,
    bubbleIncomingMeta: MekaarPalette.slate500,
    statusDangerBg: MekaarPalette.red700,  // 4.91:1 (AA)
    statusDangerText: MekaarPalette.white,
  );

  static const dark = MekaarColorTokens(
    surfaceCanvas: MekaarPalette.navy900,
    surfaceCard: MekaarPalette.navy800,
    surfaceElevated: MekaarPalette.navy700,
    borderSubtle: MekaarPalette.navy700,
    borderInteractive: MekaarPalette.slate400,
    textPrimary: MekaarPalette.ice50,      // 12.39:1 (AAA)
    textSecondary: MekaarPalette.slate300, // 5.98:1 (AA Solid, tanpa alpha 0.72)
    textMuted: MekaarPalette.slate300,     // 5.98:1 (AA Solid)
    bubbleOutgoingBg: MekaarPalette.blue600,
    bubbleOutgoingText: MekaarPalette.white,
    bubbleOutgoingMeta: Color(0xFFE2EEFF),
    bubbleIncomingBg: MekaarPalette.navy800,
    bubbleIncomingText: MekaarPalette.ice50,
    bubbleIncomingMeta: MekaarPalette.slate300,
    statusDangerBg: MekaarPalette.red700,
    statusDangerText: MekaarPalette.white,
  );

  static const stealth = MekaarColorTokens(
    surfaceCanvas: MekaarPalette.black,
    surfaceCard: MekaarPalette.slate900,
    surfaceElevated: MekaarPalette.slate800,
    borderSubtle: MekaarPalette.slate700,
    borderInteractive: MekaarPalette.slate600,
    textPrimary: MekaarPalette.slate200,   // 16.90:1 (Bebas silau halation OLED)
    textSecondary: MekaarPalette.slate400, // 5.61:1 (AA)
    textMuted: MekaarPalette.slate400,     // 5.61:1 (AA)
    bubbleOutgoingBg: MekaarPalette.slate700,
    bubbleOutgoingText: MekaarPalette.slate200,
    bubbleOutgoingMeta: MekaarPalette.slate300,
    bubbleIncomingBg: MekaarPalette.slate900,
    bubbleIncomingText: MekaarPalette.slate200,
    bubbleIncomingMeta: MekaarPalette.slate400,
    statusDangerBg: MekaarPalette.red700,
    statusDangerText: MekaarPalette.white,
  );

  @override
  MekaarColorTokens copyWith({
    Color? surfaceCanvas,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? borderSubtle,
    Color? borderInteractive,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? bubbleOutgoingBg,
    Color? bubbleOutgoingText,
    Color? bubbleOutgoingMeta,
    Color? bubbleIncomingBg,
    Color? bubbleIncomingText,
    Color? bubbleIncomingMeta,
    Color? statusDangerBg,
    Color? statusDangerText,
  }) {
    return MekaarColorTokens(
      surfaceCanvas: surfaceCanvas ?? this.surfaceCanvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderInteractive: borderInteractive ?? this.borderInteractive,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      bubbleOutgoingBg: bubbleOutgoingBg ?? this.bubbleOutgoingBg,
      bubbleOutgoingText: bubbleOutgoingText ?? this.bubbleOutgoingText,
      bubbleOutgoingMeta: bubbleOutgoingMeta ?? this.bubbleOutgoingMeta,
      bubbleIncomingBg: bubbleIncomingBg ?? this.bubbleIncomingBg,
      bubbleIncomingText: bubbleIncomingText ?? this.bubbleIncomingText,
      bubbleIncomingMeta: bubbleIncomingMeta ?? this.bubbleIncomingMeta,
      statusDangerBg: statusDangerBg ?? this.statusDangerBg,
      statusDangerText: statusDangerText ?? this.statusDangerText,
    );
  }

  @override
  MekaarColorTokens lerp(ThemeExtension<MekaarColorTokens>? other, double t) {
    if (other is! MekaarColorTokens) return this;
    return MekaarColorTokens(
      surfaceCanvas: Color.lerp(surfaceCanvas, other.surfaceCanvas, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderInteractive: Color.lerp(borderInteractive, other.borderInteractive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      bubbleOutgoingBg: Color.lerp(bubbleOutgoingBg, other.bubbleOutgoingBg, t)!,
      bubbleOutgoingText: Color.lerp(bubbleOutgoingText, other.bubbleOutgoingText, t)!,
      bubbleOutgoingMeta: Color.lerp(bubbleOutgoingMeta, other.bubbleOutgoingMeta, t)!,
      bubbleIncomingBg: Color.lerp(bubbleIncomingBg, other.bubbleIncomingBg, t)!,
      bubbleIncomingText: Color.lerp(bubbleIncomingText, other.bubbleIncomingText, t)!,
      bubbleIncomingMeta: Color.lerp(bubbleIncomingMeta, other.bubbleIncomingMeta, t)!,
      statusDangerBg: Color.lerp(statusDangerBg, other.statusDangerBg, t)!,
      statusDangerText: Color.lerp(statusDangerText, other.statusDangerText, t)!,
    );
  }
}
```

### 2. Spesifikasi Perbaikan Aksesibilitas dan Token pada `VoiceBubblePlayer` (`voice_bubble_player.dart`)

Untuk memperbaiki pelanggaran area sentuh (`32x32` dp), kontras teks (`Colors.white54`), dan ketiadaan label pembaca layar pada [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), terapkan pola pembungkus `Semantics` dengan area ketuk minimal `MekaarSizes.touchTargetMin` (`48.0` dp):

```dart
Semantics(
  button: true,
  label: _isPlaying ? 'Jeda pesan suara' : 'Putar pesan suara',
  value: _formattedDuration,
  child: Tooltip(
    message: _isPlaying ? 'Jeda' : 'Putar',
    child: InkWell(
      onTap: _togglePlayPause,
      borderRadius: BorderRadius.circular(MekaarRadius.pill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MekaarSizes.touchTargetMin, // 48.0 dp (WCAG 2.2 / M3)
          minHeight: MekaarSizes.touchTargetMin, // 48.0 dp
        ),
        child: Center(
          child: Container(
            width: 36.0, // Ukuran visual tetap ringkas
            height: 36.0,
            decoration: BoxDecoration(
              color: bubbleMetaColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: MekaarSizes.iconMd, // 20.0 dp
              color: bubbleTextColor,   // Kontras >= 4.5:1
            ),
          ),
        ),
      ),
    ),
  ),
)
```

### 3. Peta Jalan Eksekusi Berprioritas (Remediation Roadmap)

| Fase Eksekusi | Cakupan Berkas di Repositori | Tindakan Teknis Spesifik | Indikator Keberhasilan Terukur (KPI) |
| :--- | :--- | :--- | :--- |
| **Fase 1: Perbaikan Kritis Kontras & Aksesibilitas (Minggu 1)** | [`colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), [`voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart), [chat\_theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/chat_theme_settings_screen.dart) | 1. Hapus `.withValues(alpha: 0.72)` pada `textMutedOf(context)` sehingga kembali menggunakan `#5C6B85` dan `#9FB0C9` solid.<br>2. Ganti latar tombol/banner darurat dari `sosCoral` (`#FF5D5D`) ke `sosDeepRed` (`#D92632`).<br>3. Gelapkan preset gelembung Emerald ke `#047857` dan Sunset Orange ke `#C2410C`.<br>4. Perbesar *hit box* tombol `VoiceBubblePlayer` dan `ChatComposer` ke `48x48` dp serta tambahkan `Semantics`. | 100% komponen teks mencapai rasio kontras $\ge 4.5:1$ ([WCAG 2.2 SC 1.4.3](https://www.w3.org/TR/WCAG22/)) dan 100% tombol interaktif mencapai area sentuh $\ge 48\times48$ dp. |
| **Fase 2: Konsolidasi Arsitektur Token & Pembersihan Hardcode (Minggu 2)** | [`themes.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart), [`dimensions.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart), [`chat_bubble.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart), [`chat_screen.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/screens/chat_screen.dart) | 1. Migrasikan `AppColors` dan `MekaarColors` ke `MekaarColorTokens` berbasis `ThemeExtension`.<br>2. Tambahkan `MekaarRadius.xxs` (`2.0`), `xs` (`4.0`), `sm` (`8.0`) dan `MekaarSpacing.xxs` (`2.0`).<br>3. Hapus seluruh `Colors.black.withOpacity(...)` (*drop shadows*) pada gelembung pesan untuk menegakkan estetika *flat minimalist* dengan border `1px`. | 0 pemanggilan `Color(0x...)`, `Colors.white54`, atau `BorderRadius.circular(angka)` secara langsung di luar berkas `lib/core/constants/`. |
| **Fase 3: Rasionalisasi Tipografi & Ergonomi Perpesanan (Minggu 3)** | [`typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart), [`pubspec.yaml`](https://github.com/tholeteplok/Mekaar_chat/blob/main/pubspec.yaml), [`chat_list_tile.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_list_tile.dart), [`chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart) | 1. Hapus dependensi font `Baloo2` dan `Acidic`; standarisasi `PlusJakartaSans` untuk seluruh UI dan `SpaceGrotesk` untuk data kriptografi/monospasi.<br>2. Sesuaikan ukuran `bodyMedium` ke `15sp` (`height: 1.4`) dan tambahkan `FontFeature.tabularFigures()` pada `caption`.<br>3. Terapkan *message clustering* untuk pesan beruntun serta alternatif ketukan tunggal (*tap-to-lock*) pada perekam suara. | Pengurangan ukuran bundel aset font sebesar ~40%, peningkatan kepadatan pesan layar sebesar ~20%, dan kepatuhan penuh terhadap [WCAG 2.2 SC 2.5.7](https://www.w3.org/TR/WCAG22/). |

## Kesimpulan dan Rekomendasi Strategis

Secara struktural, [Mekaar_chat](https://github.com/tholeteplok/Mekaar_chat) telah memiliki diferensiasi produk yang kuat melalui penggabungan fitur perpesanan terenkripsi, brankas lokal, pelacakan keamanan *Guardian/SOS*, serta dukungan *Stealth OLED Mode*. Agar kualitas desain antarmukanya setara dengan arsitektur keamanan kriptografinya dan memenuhi standar industri aplikasi perpesanan *enterprise* global, tim pengembang perlu segera beralih dari penggunaan warna semi-transparan (`withValues(alpha: ...)`) dan nilai dimensi *hardcoded* menuju sistem token semantik berbasis `ThemeExtension` yang terverifikasi secara matematis.

Langkah paling berdampak tinggi yang dapat diselesaikan dalam satu siklus *sprint* adalah menghapus pemotongan opasitas 72% pada `MekaarColors.textMutedOf(context)` di [`lib/core/constants/colors.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart), mengganti warna latar status darurat dan preset gelembung pesan yang gagal uji kontras WCAG 2.2 AA, menyederhanakan keluarga huruf di [`lib/core/constants/typography.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart) menjadi pasangan `PlusJakartaSans` dan `SpaceGrotesk`, serta memperluas area sentuh seluruh tombol di dalam [`lib/core/widgets/bubbles/voice_bubble_player.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart) dan [`lib/features/chat/widgets/chat_composer.dart`](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart) menjadi minimal `48x48` dp disertai atribut `Semantics`. Penegakan aturan *linter* khusus atau *custom test* pada CI/CD untuk melarang penggunaan `Colors.*` dan `TextStyle` manual di luar direktori `lib/core/constants/` akan menjaga konsistensi sistem desain tersebut secara berkelanjutan seiring bertambahnya fitur baru.

## Referensi

1. **Repositori Kode Sumber Utama Mekaar Chat**: [tholeteplok/Mekaar_chat Repository](https://github.com/tholeteplok/Mekaar_chat)
2. **Konstanta Sistem Warna Mekaar Chat**: [lib/core/constants/colors.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/colors.dart)
3. **Konstanta Dimensi, Spasi, dan Radius Mekaar Chat**: [lib/core/constants/dimensions.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/dimensions.dart)
4. **Konstanta Sistem Tipografi Mekaar Chat**: [lib/core/constants/typography.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/typography.dart)
5. **Konfigurasi Tema Light, Dark, dan Stealth OLED Mekaar Chat**: [lib/core/constants/themes.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/constants/themes.dart)
6. **Komponen Gelembung Pesan Utama Mekaar Chat**: [lib/core/widgets/chat_bubble.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/chat_bubble.dart)
7. **Komponen Pemutar Pesan Suara Mekaar Chat**: [lib/core/widgets/bubbles/voice_bubble_player.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/voice_bubble_player.dart)
8. **Komponen Kontainer Tema Gelembung Mekaar Chat**: [lib/core/widgets/bubbles/themed\_bubble\_container.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/core/widgets/bubbles/themed_bubble_container.dart)
9. **Komponen Bilah Input Pesan Mekaar Chat**: [lib/features/chat/widgets/chat_composer.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_composer.dart)
10. **Komponen Item Daftar Obrolan Mekaar Chat**: [lib/features/chat/widgets/chat_list_tile.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/widgets/chat_list_tile.dart)
11. **Layar Ruang Obrolan Utama Mekaar Chat**: [lib/features/chat/screens/chat_screen.dart](https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/chat/screens/chat_screen.dart)
12. **Layar Pengaturan Tema Gelembung Obrolan Mekaar Chat**: [lib/features/settings/screens/chat\_theme\_settings\_screen.dart](https://www.google.com/search?q=https://github.com/tholeteplok/Mekaar_chat/blob/main/lib/features/settings/screens/chat_theme_settings_screen.dart)
13. **W3C Web Content Accessibility Guidelines (WCAG) 2.2**: [W3C Recommendation WCAG 2.2](https://www.w3.org/TR/WCAG22/)
14. **W3C Guidance on Applying WCAG 2.2 to Mobile Applications**: [W3C Mobile Accessibility Guidance (WCAG2Mobile 2.2)](https://www.w3.org/TR/wcag2mobile-22/)
15. **W3C Design Tokens Community Group (DTCG) Specification**: [Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/2025.10/format/)
16. **Google Material Design 3 – Design Tokens Foundation**: [Material Design 3 Design Tokens](https://m3.material.io/foundations/design-tokens)
17. **Google Material Design 3 – Color System & Accessibility**: [Material Design 3 Color System Overview](https://m3.material.io/styles/color/system/overview)
18. **Google Material Design 3 – Typography Scale Tokens**: [Material Design 3 Type Scale Tokens](https://m3.material.io/styles/typography/type-scale-tokens)
19. **Apple Human Interface Guidelines – Typography & Dynamic Type**: [Apple Developer Documentation: Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
20. **Apple Human Interface Guidelines – Accessibility & Touch Targets**: [Apple Developer Documentation: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
21. **Signal Private Messenger – Android Client Architecture**: [signalapp/Signal-Android on GitHub](https://github.com/signalapp/signal-android)
22. **Signal Private Messenger – iOS Client Architecture**: [signalapp/Signal-iOS on GitHub](https://github.com/signalapp/Signal-iOS)
23. **Slack Enterprise UI Framework – Block Kit Design Guidelines**: [Slack Developer Docs: Designing with Block Kit](https://docs.slack.dev/concepts/designing-with-block-kit)
24. **Telegram Messenger – Design & Interface Guidelines**: [Telegram Mini Apps & Interface Guidelines](https://core.telegram.org/bots/webapps)
