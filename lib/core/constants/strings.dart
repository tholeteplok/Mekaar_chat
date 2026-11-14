// lib/core/constants/strings.dart
//
// Sistem Copywriting Terpusat Mekaar Chat (Enterprise UX Writing & Honest Threat Modeling).
// Mengacu pada prinsip "Security by Default, Quiet by Design" (Signal, WhatsApp, Apple iMessage):
// 1. Menggunakan bahasa sehari-hari yang ramah, jelas, dan mudah dipahami (tanpa jargon algoritma
//    kriptografi teknis dan tanpa klaim keamanan berlebihan seperti "100% Aman" atau "Aegis Protocol").
// 2. Menyertakan batasan praktis secara jujur agar tidak menimbulkan rasa aman semu.
// 3. Menggunakan penamaan netral/tersamar (Plausible Deniability) pada fitur anti-pemaksaan fisik.

abstract final class MekaarCopy {
  // ===========================================================================
  // 1. IDENTITAS APLIKASI & ONBOARDING (TENANG, RAMAH, & MUDAH DIPAHAMI)
  // ===========================================================================
  static const String appName = 'Mekaar';
  static const String appTagline =
      'Ngobrol lebih tenang, pribadi sejak awal.';
  static const String onboardingSubtitle =
      'Pesan dan panggilan selalu dikunci secara otomatis di perangkat Anda. '
      'Hanya Anda dan lawan bicara yang dapat membacanya.';

  // ===========================================================================
  // 2. DAFTAR OBROLAN & PRATINJAU PESAN (CHAT LIST)
  // ===========================================================================
  static const String chatListTitle = 'Pesan';
  static const String searchChatsHint = 'Cari pesan atau kontak...';

  // Digunakan HANYA ketika pengguna mengaktifkan opsi "Sembunyikan Pratinjau di Daftar"
  // atau pada notifikasi layar kunci OS (tanpa ikon gembok yang menimbulkan kecemasan).
  static const String hiddenPreviewFallback = 'Pesan baru';
  static const String emptyChatPreview = 'Ketuk untuk memulai percakapan';

  // Pratinjau lampiran media yang ramah pemindaian (scannable)
  static const String mediaPhotoPreview = 'Foto';
  static const String mediaVideoPreview = 'Video';
  static const String mediaDocumentPreview = 'Dokumen';
  static const String mediaLocationPreview = 'Lokasi';
  static const String mediaViewOncePreview = 'Media sekali lihat';
  static String mediaVoicePreview(String duration) => 'Pesan suara ($duration)';

  // ===========================================================================
  // 3. RUANG OBROLAN & CATATAN ENKRIPSI (QUIET BY DESIGN)
  // ===========================================================================
  // Ditampilkan satu kali di bagian paling atas riwayat obrolan (bukan sticky banner
  // dan bukan di setiap gelembung pesan).
  static const String e2eeThreadNoticeBody =
      'Pesan dan panggilan di obrolan ini bersifat pribadi. '
      'Tidak seorang pun di luar obrolan ini dapat membaca atau mendengarkannya. ';
  static const String e2eeThreadNoticeAction = 'Pelajari atau verifikasi.';
  static const String e2eeThreadSemanticsLabel =
      'Pesan dan panggilan bersifat pribadi. Ketuk untuk memverifikasi kode keamanan.';

  static const String e2eeInitializingBanner =
      'Menyiapkan ruang obrolan...';
  static const String reconnectingBanner = 'Menghubungkan kembali...';
  static const String callEncryptedSubtitle = 'Panggilan pribadi';

  // ===========================================================================
  // 4. VERIFIKASI KUNCI & PERUBAHAN PERANGKAT (BEBAS JARGON TEKNIS)
  // ===========================================================================
  static const String verifySecurityCodeTitle = 'Cocokkan Kode Keamanan';
  static String verifySecurityCodeDescription(String contactName) =>
      'Untuk memastikan Anda terhubung langsung dengan $contactName, bandingkan '
      'angka di bawah ini atau pindai kode QR di layar ponselnya.';

  static String safetyNumberChangedNotice(String contactName) =>
      'Kode keamanan dengan $contactName telah diperbarui. Hal ini wajar terjadi '
      'jika $contactName baru saja mengganti ponsel atau memasang ulang Mekaar. '
      'Ketuk untuk mencocokkan kode.';

  static const String keyVerifiedBadgeLabel = 'Kontak telah dicocokkan';
  static const String privacyAssuranceNote =
      'Pesan dikunci langsung di ponsel Anda sebelum dikirim dan hanya terbuka '
      'di ponsel penerima—bahkan server Mekaar tidak dapat membacanya.';

  static const String keyRestoreSheetTitle = 'Pulihkan Riwayat Obrolan';
  static const String keyRestoreSheetBody =
      'Masukkan kode cadangan Anda untuk membuka kembali riwayat pesan '
      'dari perangkat sebelumnya.';

  // ===========================================================================
  // 5. PENGATURAN PRIVASI RUANG OBROLAN (BAHASA SEHARI-HARI & JUJUR)
  // ===========================================================================
  static const String roomPrivacySheetTitle = 'Privasi Obrolan';

  // Menggantikan klaim "Proteksi Layar / Cegah Tangkapan Layar" yang memberi rasa aman semu
  static const String limitScreenshotsTitle = 'Batasi Tangkapan Layar';
  static const String limitScreenshotsSubtitle =
      'Menonaktifkan fitur screenshot di ponsel ini. Ingat bahwa orang lain tetap '
      'bisa memotret layar menggunakan HP atau kamera lain.';

  // Menggantikan istilah hiperbolis "Burn on Exit"
  static const String clearOnCloseTitle = 'Bersihkan Saat Keluar';
  static const String clearOnCloseSubtitle =
      'Hapus riwayat pesan dari ponsel ini secara otomatis setiap kali Anda '
      'menutup ruang obrolan.';

  static const String disappearingMessagesTitle = 'Pesan Menghilang';
  static const String disappearingMessagesSubtitle =
      'Hapus pesan baru secara otomatis setelah waktu yang ditentukan sejak pesan dibaca.';

  static const String scheduledCleanupTitle = 'Pembersihan Berkala';
  static const String scheduledCleanupSubtitle =
      'Jadwalkan penghapusan rutin untuk seluruh foto, suara, dan pesan di ruang ini.';

  static const String viewOnceHelperText =
      'Foto atau video ini akan langsung terhapus dari obrolan setelah dibuka satu kali.';

  // ===========================================================================
  // 6. PENGATURAN KEAMANAN & PENAMAAN TERSAMAR (PLAUSIBLE DENIABILITY)
  // ===========================================================================
  static const String securitySectionHeader = 'Keamanan & Akses';
  static const String encryptionInfoTileTitle = 'Privasi Pesan & Panggilan';
  static const String encryptionInfoTileSubtitle =
      'Semua obrolan dikunci otomatis untuk Anda dan penerima';

  static const String appPinLockTitle = 'PIN Kunci Aplikasi';
  static const String appPinLockSubtitle =
      'Minta kode PIN saat membuka aplikasi Mekaar';

  // Nama tersamar untuk Decoy PIN (membuka ruang kerja/profil kedua yang bersih)
  static const String secondaryWorkspacePinTitle = 'PIN Ruang Kedua';
  static const String secondaryWorkspacePinSubtitle =
      'Atur kode akses terpisah untuk membuka tampilan profil kedua';

  // Nama tersamar untuk Duress PIN (menyembunyikan/mereset data lokal saat terdesak)
  static const String quickResetPinTitle = 'Kode Reset Cepat';
  static const String quickResetPinSubtitle =
      'Menyembunyikan riwayat obrolan lokal secara otomatis saat kode ini dimasukkan';

  // ===========================================================================
  // 7. LAYAR BUKA KUNCI PIN & KESELAMATAN PERJALANAN (GUARDIAN / DARURAT)
  // ===========================================================================
  static const String unlockPinScreenTitle = 'Masukkan PIN Mekaar';
  static const String unlockPinForgotAction = 'Lupa PIN?';
  static const String discreetEmergencyAction = 'Bantuan Darurat (Tahan 2 dtk)';

  static const String guardianHubTitle = 'Pendamping Perjalanan';
  static const String guardianHubSubtitle =
      'Bagikan rute dan kabar perjalanan secara langsung kepada keluarga atau teman dekat.';
}
