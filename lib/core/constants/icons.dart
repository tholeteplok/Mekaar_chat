import 'package:solar_icons/solar_icons.dart';

/// MekaarIcons — sumber tunggal ikon brand MEKAAR.
/// Semua ikon berasal dari SolarIcons (Outline/Bold), tidak ada Material Icons.
/// Gunakan konstanta ini di seluruh aplikasi untuk konsistensi visual.
class MekaarIcons {
  MekaarIcons._();

  // ============ Status Chat & Obrolan ============
  /// Ikon perisai — untuk chat Guardian (E2EE + perlindungan)
  static const guardian = SolarIconsOutline.shieldKeyhole;

  /// Ikon grup — untuk chat grup
  static const group = SolarIconsOutline.usersGroupRounded;

  /// Ikon notifikasi mati — untuk chat yang di-mute
  static const muted = SolarIconsOutline.bellOff;

  /// Ikon gembok — untuk chat terenkripsi end-to-end
  static const encrypted = SolarIconsOutline.lock;

  /// Ikon dialog / pesan obrolan (navbar & list)
  static const dialog = SolarIconsOutline.dialog;
  static const dialogBold = SolarIconsBold.dialog;

  /// Ikon tambah / plus (FAB pesan baru & tombol tambah)
  static const plus = SolarIconsOutline.addCircle;
  static const plusBold = SolarIconsBold.addCircle;

  // ============ Navigasi & Aksi Dasar ============
  /// Panah kiri (kembali)
  static const back = SolarIconsOutline.altArrowLeft;

  /// Panah kanan (lanjut)
  static const forward = SolarIconsOutline.forward;

  /// Tutup / hapus
  static const close = SolarIconsOutline.closeCircle;

  /// Ceklis (konfirmasi, selesai)
  static const check = SolarIconsOutline.checkCircle;

  /// Ceklis ganda (sudah dibaca)
  static const doneAll = SolarIconsOutline.doubleAltArrowDown; // tidak ada doneAll, pakai doubleAltArrowDown sebagai pengganti (atau kita bisa pakai Bold, tapi kita pilih yang paling mendekati)
  // Ternyata tidak ada doneAll di Solar. Alternatif: gunakan checkCircle atau verifiedCheck. Untuk status "dibaca", pakai verifiedCheck.
  static const read = SolarIconsOutline.verifiedCheck;

  /// Arsip
  static const archive = SolarIconsOutline.archive;

  /// Hapus (tong sampah)
  static const delete = SolarIconsOutline.trashBinMinimalistic;

  /// Edit / tulis
  static const edit = SolarIconsOutline.penNewRound;

  /// Balas
  static const reply = SolarIconsOutline.reply;

  /// Salin
  static const copy = SolarIconsOutline.copy;

  /// Bagikan
  static const share = SolarIconsOutline.share;

  /// Info
  static const info = SolarIconsOutline.infoCircle;

  /// Peringatan (segitiga)
  static const warning = SolarIconsOutline.dangerTriangle;

  /// Peringatan (lingkaran)
  static const warningCircle = SolarIconsOutline.dangerCircle;

  /// Dilarang / blokir
  static const forbidden = SolarIconsOutline.forbiddenCircle;

  /// Cari
  static const search = SolarIconsOutline.magnifier;

  // ============ Media & Panggilan ============
  /// Video kamera
  static const videocam = SolarIconsOutline.videocamera;

  /// Video kamera mati
  static const videocamOff = SolarIconsOutline.videocamera; // tidak ada off, pakai yang sama? Atau kita cari alternatif. Nanti kita sesuaikan.

  /// Panggilan telepon
  static const phone = SolarIconsOutline.phoneRounded;

  /// Akhiri panggilan
  static const callEnd = SolarIconsOutline.endCall;

  /// Mikrofon
  static const mic = SolarIconsOutline.microphone;

  /// Mikrofon mati
  static const micOff = SolarIconsOutline.microphone; // tidak ada off, kita pakai yang sama? Nanti disesuaikan.

  /// Volume keras
  static const volumeUp = SolarIconsOutline.volumeLoud;

  /// Volume pelan
  static const volumeDown = SolarIconsOutline.volumeSmall;

  /// Putar
  static const play = SolarIconsOutline.play;

  /// Jeda
  static const pause = SolarIconsOutline.pause;

  /// Galeri
  static const gallery = SolarIconsOutline.gallery;

  /// Video library
  static const videoLibrary = SolarIconsOutline.videoLibrary;

  /// Gambar rusak (placeholder)
  static const brokenImage = SolarIconsOutline.galleryRemove; // alternatif

  // ============ Lokasi & Peta ============
  /// Lokasi (pin)
  static const location = SolarIconsOutline.mapPoint;

  /// Peta
  static const map = SolarIconsOutline.map;

  /// Arah / navigasi
  static const directions = SolarIconsOutline.compass;

  // ============ Keamanan & Privasi ============
  /// Perisai (umum)
  static const shield = SolarIconsOutline.shield;

  /// Verifikasi (centang di perisai)
  static const verified = SolarIconsOutline.verifiedCheck;

  /// Mata (tampilkan)
  static const eye = SolarIconsOutline.eye;

  /// Mata tertutup (sembunyikan)
  static const eyeOff = SolarIconsOutline.eyeClosed;

  // ============ Lainnya ============
  /// Jam / waktu
  static const timer = SolarIconsOutline.clockCircle;

  /// Buku penanda
  static const bookmark = SolarIconsOutline.bookmark;

  /// Notifikasi (bel)
  static const notification = SolarIconsOutline.bell;

  /// Emoticon senyum
  static const smile = SolarIconsOutline.smileCircle;

  /// Data seluler (G)
  static const mobileData = SolarIconsOutline.globus; // alternatif

  /// Lingkaran (dot indikator)
  static const circle = SolarIconsOutline.recordCircle; // atau recordCircle1

  /// Pin (peniti)
  static const pin = SolarIconsOutline.pin;

  /// Blokir (stop)
  static const block = SolarIconsOutline.forbiddenCircle;

  /// Hapus selamanya
  static const deleteForever = SolarIconsOutline.trashBinMinimalistic; // sama

  /// Edit catatan
  static const editNote = SolarIconsOutline.penNewRound;

  static const bookmarkAdded = SolarIconsOutline.bookmark;

  /// Error outline
  static const errorOutline = SolarIconsOutline.dangerCircle;

  /// Sentiment satisfied
  static const sentimentSatisfied = SolarIconsOutline.smileCircle;

  /// Lock outline
  static const lockOutline = SolarIconsOutline.lock;

  /// Groups outline
  static const groupsOutline = SolarIconsOutline.usersGroupRounded;

  /// Shield outline
  static const shieldOutline = SolarIconsOutline.shield;

  /// Notifications off
  static const notificationsOff = SolarIconsOutline.bellOff;

  /// Security
  static const security = SolarIconsOutline.shield;

  /// Location pin
  static const locationPin = SolarIconsOutline.mapPoint;

  /// Copy all outlined
  static const copyAllOutlined = SolarIconsOutline.copy;

  /// Directions outlined
  static const directionsOutlined = SolarIconsOutline.compass;

  /// Check circle
  static const checkCircle = SolarIconsOutline.checkCircle;

  /// Info outline
  static const infoOutline = SolarIconsOutline.infoCircle;

  /// Video cam outlined
  static const videocamOutlined = SolarIconsOutline.videocamera;

  /// Video cam off
  static const videocamOffOutlined = SolarIconsOutline.videocamera; // alternatif

  /// Play circle outline
  static const playCircleOutline = SolarIconsOutline.play;

  /// Play circle filled
  static const playCircleFilled = SolarIconsOutline.play;

  /// Pause circle filled
  static const pauseCircleFilled = SolarIconsOutline.pause;

  /// Warning amber rounded
  static const warningAmberRounded = SolarIconsOutline.dangerTriangle;

  /// Verified user rounded
  static const verifiedUserRounded = SolarIconsOutline.verifiedCheck;

  /// Map outlined
  static const mapOutlined = SolarIconsOutline.map;

  /// Timer outlined
  static const timerOutlined = SolarIconsOutline.clockCircle;

  /// Delete outlined
  static const deleteOutlined = SolarIconsOutline.trashBinMinimalistic;

  /// Delete forever
  static const deleteForeverOutlined = SolarIconsOutline.trashBinMinimalistic;

  /// Check (small)
  static const checkSmall = SolarIconsOutline.checkCircle;

  /// Visibility off
  static const visibilityOff = SolarIconsOutline.eyeClosed;

  /// Arrow back ios new
  static const arrowBackIosNew = SolarIconsOutline.altArrowLeft;

  /// G mobiledata
  static const gMobiledata = SolarIconsOutline.globus;

  /// Volume up
  static const volumeUpSmall = SolarIconsOutline.volumeLoud;

  /// Volume down
  static const volumeDownSmall = SolarIconsOutline.volumeSmall;

  /// Mic off
  static const micOffSmall = SolarIconsOutline.microphone; // alternatif

  /// Mic
  static const micSmall = SolarIconsOutline.microphone;

  /// Call end
  static const callEndSmall = SolarIconsOutline.endCall;

  /// Videocam
  static const videocamSmall = SolarIconsOutline.videocamera;

  /// Videocam off
  static const videocamOffSmall = SolarIconsOutline.videocamera;

  /// Broken image
  static const brokenImageSmall = SolarIconsOutline.galleryRemove;

  /// Visibility off (small)
  static const visibilityOffSmall = SolarIconsOutline.eyeClosed;

  /// Circle (small)
  static const circleSmall = SolarIconsOutline.recordCircle;
}
