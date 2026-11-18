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

  // Aksi Header & Brankas Berkas
  static const String vaultTitle = 'Brankas Berkas';
  static const String vaultVerifyTitle = 'Buka Brankas Berkas';
  static const String vaultVerifySubtitle =
      'Masukkan PIN untuk mengakses berkas rahasia';

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

  // ===========================================================================
  // 8. PENGATURAN UTAMA (SETTINGS HUB & IA BARU)
  // ===========================================================================
  static const String settingsTitle = 'Pengaturan';

  // Header Seksi
  static const String settingsPrivacySection = 'Privasi';
  static const String settingsSecuritySection = 'Keamanan';
  static const String settingsSafetySection = 'Keselamatan & Guardian';
  static const String settingsNotificationSection = 'Notifikasi & Suara';
  static const String settingsDisplaySection = 'Tampilan';
  static const String settingsAboutSection = 'Tentang & Bantuan';

  // Seksi Privasi
  static const String lastSeenTitle = 'Terakhir Dilihat & Online';
  static const String readReceiptsTitle = 'Bukti Baca Pesan';
  static const String chatInvitationsTitle = 'Undangan Chat';
  static const String nearbyFriendsTitle = 'Teman Sekitar';
  static const String nearbyFriendsEnableTitle = 'Aktifkan Teman Sekitar';
  static const String nearbyFriendsPreviewTitle = 'Preview di Tab Kontak';
  static const String nearbyFriendsContactsOnlyTitle = 'Hanya Kontak Saya';
  static const String nearbyFriendsEveryoneTitle = 'Semua Pengguna di Sekitar';
  static const String blockedListTitle = 'Daftar Blokir';
  static const String relayCallsTitle = 'Sembunyikan Alamat IP Panggilan';
  static const String relayCallsSubtitle =
      'Alihkan panggilan via server relay Mekaar';

  // Seksi Keamanan
  static const String pinManagementTitle = 'Manajemen PIN Keamanan';
  static const String pinManagementDecoyTitle = 'PIN Keamanan';
  static const String pinManagementSubtitle =
      'PIN utama, PIN tamu & kode darurat';
  static const String autoLockTitle = 'Kunci Otomatis';
  static const String twoStepVerificationTitle = 'Verifikasi 2 Langkah';
  static const String twoStepDisableDialogTitle =
      'Matikan Verifikasi 2 Langkah';
  static const String connectedDevicesTitle = 'Perangkat Terhubung';
  static const String blockScreenshotsTitle = 'Blokir Tangkapan Layar';
  static const String blockScreenshotsSubtitle =
      'Cegah tangkapan layar di seluruh aplikasi';

  // Seksi Keselamatan & Guardian
  static const String sosFeatureTitle = 'Fitur Darurat SOS';
  static const String sosFeatureSubtitle =
      'Aktifkan sirene, rekaman, dan sinyal darurat ke guardian';
  static const String sosDisableDialogTitle =
      'Nonaktifkan Fitur Darurat SOS?';
  static const String sosLogsTitle = 'Riwayat SOS';
  static const String sosLogsInactiveSubtitle = 'Fitur SOS nonaktif';
  static const String sosDrillTitle = 'Latihan SOS';
  static const String sosDrillSubtitle =
      'Simulasi alur darurat tanpa sinyal nyata';
  static const String guardianAlarmTitle = 'Izin Alarm Guardian';
  static const String guardianAlarmSubtitle =
      'Izinkan suara alarm untuk peringatan guardian';
  static const String tripsTitle = 'Check-In & Perjalanan';
  static const String findMyPhoneTitle = 'Temukan Ponsel Saya';
  static const String safetyWizardTitle = 'Lengkapi Proteksi SOS';
  static const String safetyWizardSubtitle =
      'Fitur SOS telah aktif. Selesaikan konfigurasi agar perlindungan maksimal.';

  // Seksi Notifikasi & Suara
  static const String notificationSoundsTitle = 'Nada Notifikasi';
  static const String stealthChatPreviewTitle = 'Sembunyikan Cuplikan Pesan';
  static const String stealthChatPreviewSubtitle =
      'Sembunyikan preview teks terakhir pada daftar obrolan publik';
  static const String notificationMaskingTitle = 'Samarkan Notifikasi Darurat';
  static const String notificationMaskingSubtitle =
      'Samarkan rincian nama pengirim & pesan saat darurat';
  static const String hapticsTitle = 'Getaran';

  // Seksi Tampilan
  static const String themeSettingsTitle = 'Tema & Mode Gelap';
  static const String chatThemeTitle = 'Tema Ruang Obrolan';
  static const String chatThemeSubtitle =
      'Gelembung, warna, font & wallpaper obrolan';

  // Seksi Informasi & Akun
  static const String aboutTitle = 'Tentang Mekaar';
  static const String logoutTitle = 'Keluar';
  static const String logoutSubtitle = 'Sesi login dan PIN lokal akan dihapus.';
  static const String logoutConfirmTitle = 'Keluar dari Akun?';
  static const String logoutConfirmMessage =
      'Sesi masuk dan PIN keamanan lokal di perangkat ini akan dihapus. '
      'Anda harus masuk kembali dengan kata sandi.';
  static const String logoutConfirmAction = 'Keluar';
}
