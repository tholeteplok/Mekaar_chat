# Keputusan Arsitektur: Dekomisi Fitur "Temukan Ponsel Saya" & "Bantu Temukan Ponsel"

**Tanggal:** 21 November 2026  
**Versi:** v2.6.4 (`25932c4`)  
**Status:** Disetujui & Diterapkan

---

## 1. Apa yang Dihapus

Pada rilis v2.6.4 (`25932c4`), seluruh antarmuka dan alur penguncian fitur *Find My Phone* dihapus dari aplikasi:
1. **Menu UI:**
   - Menu **"Temukan Ponsel Saya"** pada Pengaturan (`lib/features/settings/screens/settings_screen.dart`).
   - Seksi **"Pemulihan Perangkat" / "Bantu Temukan Ponsel"** pada Detail Guardian (`lib/features/guardian/screens/guardian_detail_screen.dart`).
2. **Layar, Sheet & Rute:**
   - `device_lost_screen.dart`, `device_lost_lock_screen.dart`, `guardian_find_phone_screen.dart`, dan `guardian_find_phone_sheet.dart`.
   - Rute `AppRoutes.deviceLost`, `AppRoutes.deviceLostLock`, dan `AppRoutes.guardianFindPhone`.
3. **Alur Kunci Startup & Notifikasi:**
   - Pengecekan `getDeviceLostState()` saat *cold start* di `SplashScreen` (`splash_screen.dart`).
   - Perintah `lock` di `DeviceCommandHandler` dan notifikasi persisten `devicelost:` di `NotificationService`.

---

## 2. Alasan Dekomisi

1. **Keterbatasan OS vs Layanan Bawaan Sistem Operasi:**
   Pelacakan dan penguncian perangkat hilang pada level aplikasi Flutter sangat bergantung pada kondisi aplikasi aktif di latar belakang (rentan terhadap *Doze Mode*, *force stop*, serta tidak memiliki hak *Device Admin/MDM*). Fitur bawaan OS (*Google Find My Device* / *Apple Find My*) jauh lebih andal.
2. **Risiko *False Lock* & *Abuse Vector*:**
   Status kunci perangkat berisiko mengunci pengguna di `DeviceLostLockScreen` saat startup bila sinkronisasi status tidak tepat, serta membuka potensi penyalahgunaan antar-kontak Guardian saat terjadi konflik.
3. **Fokus Produk:**
   Mempertajam posisi Mekaar Chat sebagai aplikasi *personal-safety chat* (SOS darurat, pemantauan Guardian saat bahaya/perjalanan, dan Vault) alih-alih aplikasi MDM/anti-theft.
4. **Performa Startup:**
   Menghapus query `getDeviceLostState()` di `SplashScreen` memangkas satu panggilan asinkron sebelum navigasi awal.

---

## 3. Apa yang Sengaja Dipertahankan (Jangan Dihapus)

Meski bernama `device_lost_*`, komponen berikut **tetap aktif digunakan oleh fitur inti lain**:
- **`DeviceLostRepository` (`lib/data/repositories/device_lost_repository.dart`)**:
  Metode `sendRemoteCommand(...)` digunakan oleh:
  - `SosViewerScreen` (`lib/features/guardian/screens/sos_viewer_screen.dart`) untuk membunyikan sirine darurat pada perangkat korban saat sesi SOS aktif (`commandType: 'alarm'`).
  - `ConnectedDevicesScreen` (`lib/features/settings/screens/connected_devices_screen.dart`) untuk mengeluarkan sesi perangkat lain secara jarak jauh (`commandType: 'logout'`).
- **`DeviceCommandHandler` (`lib/data/services/device_command_handler.dart`)**:
  Tetap memproses perintah `alarm`, `stop_alarm`, `locate`, dan `logout` yang masuk via FCM.
- **Migrasi Database Supabase (`device_commands` & RPC terkait)**:
  Tetap dipertahankan untuk kompatibilitas *remote command* SOS serta pengguna versi aplikasi sebelumnya.

---

## 4. Syarat Jika Fitur Ini Dihidupkan Kembali di Masa Depan

1. Menggunakan integrasi *OS-level* atau *high-priority* FCM yang teruji tahan terhadap pembatasan latar belakang Android/iOS.
2. Menerapkan otorisasi berlapis, *rate limiting*, dan mekanisme *cooldown* untuk mencegah penyalahgunaan penguncian/sirine oleh kontak.
3. Memiliki mekanisme pemulihan status kunci yang aman terhadap *false lock* saat startup.
