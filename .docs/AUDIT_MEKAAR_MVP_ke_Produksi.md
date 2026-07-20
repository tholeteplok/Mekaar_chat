# Audit Mendalam MEKAAR Chat — Roadmap MVP → Produksi

**Repo yang diaudit:** `tholeteplok/Mekaar_chat`
**Status saat ini:** Pra-MVP / prototipe fungsional, jauh dari siap produksi
**Filosofi produk (acuan seluruh rekomendasi):** *"Inisiatif dari Dalam"* — tidak ada akses sensor tanpa tindakan sadar pemilik perangkat; anti-stalkerware; transparansi total; kesetaraan antar pengguna.

---

## 1. Ringkasan Eksekutif

MEKAAR adalah aplikasi chat berbasis Flutter + Supabase dengan lapisan keamanan personal (SOS, Guardian, PIN paksaan, E2EE, video darurat). Fondasi arsitektur dan **filosofi etikanya sudah kuat** — RLS granular, pemisahan izin guardian, evidence-preserving delete, dsb. Namun ada kesenjangan serius antara *klaim* fitur keamanan (E2EE, "tanda tangan kriptografis") dan *implementasi* aktualnya, ditambah beberapa risiko operasional yang **harus** ditutup sebelum aplikasi ini dipegang oleh pengguna sungguhan — apalagi mengingat target penggunanya berpotensi berada dalam situasi rentan.

Laporan ini disusun **bukan** sebagai daftar temuan datar, melainkan sebagai **roadmap bertingkat**: apa yang wajib selesai sebelum uji coba tertutup (closed beta) dengan data asli, apa yang wajib selesai sebelum rilis publik, dan apa yang bisa menyusul sebagai hardening pasca-peluncuran.

---

## 2. Peta Prioritas

| Level | Definisi | Boleh skip untuk MVP internal? |
|---|---|---|
| 🔴 **P0 — Blocker sebelum ada data pengguna asli** | Tanpa ini, mempertaruhkan keamanan/privasi pengguna uji coba sendiri sudah berisiko | ❌ Tidak |
| 🟠 **P1 — Blocker sebelum rilis publik/produksi** | Boleh ditunda selama closed beta terbatas & sadar risiko, tapi wajib selesai sebelum store listing publik | ⚠️ Hanya dengan disclaimer eksplisit ke tester |
| 🟡 **P2 — Hardening pasca-launch** | Meningkatkan ketahanan/skala, tidak menghalangi rilis awal | ✅ Boleh |
| 🟢 **P3 — Nice-to-have / fitur pertumbuhan** | Diferensiasi produk jangka menengah | ✅ Boleh |

---

## 3. 🔴 P0 — Wajib Sebelum Ada Data Pengguna Asli

Ini bukan soal "sebelum ke Play Store" — ini soal sebelum kalian sendiri memasukkan nomor HP, PIN, atau lokasi asli ke dalam sistem untuk uji coba, karena lubang-lubang ini langsung menyentuh data paling sensitif di aplikasi.

### 3.1 Perbaiki urutan/dokumentasi migrasi RLS
`02_rls_policies.sql` membuat tabel `profiles` bisa di-`SELECT *` oleh **siapa pun yang login** — termasuk `pin_hash`, `duress_pin_hash`, `duress_enabled`, `two_fa_secret`. Ini baru ditambal di `05_security_hardening.sql`, sementara README "Panduan Memulai" hanya eksplisit menyebut migrasi 1–3.
- **Tindakan**: gabungkan fix RLS langsung ke migrasi awal (jangan biarkan ada window insecure sama sekali), atau minimal ubah README agar tegas: *"WAJIB jalankan seluruh migrasi 01→26 secara berurutan sebelum aplikasi live — migrasi 05 menutup lubang RLS kritis."*
- **Kenapa P0**: kalau lupa satu langkah saja, seluruh hash PIN & status duress pengguna uji coba bocor ke siapa pun yang punya akun.

### 3.2 Hentikan silent fallback ke plaintext di E2EE
Di `chat_repository.dart`, kalau `E2eeService.encryptForRoom()` gagal (banyak jalur menuju `catch (_) {}` di `e2ee_service.dart`), pesan **otomatis terkirim sebagai plaintext** tanpa peringatan apa pun ke pengguna.
- **Tindakan**: ubah perilaku jadi *fail closed* — kalau enkripsi gagal, blokir pengiriman dan tampilkan status jelas ("Pesan belum bisa dienkripsi, coba lagi") — bukan fail open ke plaintext senyap.
- **Kenapa P0**: ini bertentangan langsung dengan klaim utama fitur privasi aplikasi; kalau dibiarkan sampai closed beta, chat "terenkripsi" bisa diam-diam tidak terenkripsi tanpa siapa pun sadar.

### 3.3 Luruskan klaim "tanda tangan kriptografis" pada log bukti hukum
`supabase/functions/sign-logs/index.ts` cuma menghitung SHA-256 biasa (tanpa kunci rahasia) lalu menyebutnya *"ditandatangani secara kriptografis... tidak dapat diubah tanpa merusak tanda tangan"*. Ini secara teknis salah — hash tanpa kunci bisa dihitung ulang oleh siapa saja, termasuk untuk memalsukan versi lain.
- **Tindakan jangka pendek (P0)**: ubah copy/UI agar tidak mengklaim "signature"/non-repudiation — sebut saja "checksum integritas" sampai implementasi sebenarnya siap.
- **Tindakan sebenarnya (boleh masuk P1)**: ganti ke tanda tangan asimetris (Ed25519) dengan private key di server, sediakan public key untuk verifikasi independen oleh pihak ketiga (mis. kepolisian/pengadilan).
- **Kenapa P0 (minimal untuk copy-nya)**: fitur ini eksplisit ditujukan sebagai bukti hukum bagi pengguna dalam situasi berbahaya — klaim palsu tentang kekuatan bukti bisa berakibat fatal secara hukum maupun kepercayaan.

### 3.4 Ganti TURN server publik sebelum uji SOS video/audio sungguhan
`webrtc_signaling_service.dart` memakai kredensial TURN gratis publik (`openrelay.metered.ca`) — tidak ada SLA, availability tidak terjamin.
- **Tindakan**: siapkan TURN privat (self-hosted `coturn`, atau layanan terkelola seperti Twilio/Cloudflare Calls) minimal untuk lingkungan testing.
- **Kenapa P0**: fitur intinya adalah *video/audio darurat* — kalau relay publik down atau di-throttle tepat saat dibutuhkan, itu kegagalan pada fitur paling kritis di aplikasi.

---

## 4. 🟠 P1 — Wajib Sebelum Rilis Produksi/Publik

Boleh berjalan selama closed beta internal dengan tester yang sadar risiko, tapi **tidak boleh** dibawa ke Play Store/App Store publik.

| # | Temuan | Tindakan |
|---|---|---|
| 4.1 | Backup private key E2EE hanya dilindungi PIN 6 digit via PBKDF2-SHA256 100k iterasi — ruang kunci kecil (1 juta kombinasi), rentan brute-force offline jika blob `e2ee_key_backup` pernah bocor | Naikkan ke Argon2id dengan parameter setara PIN app; pertimbangkan mewajibkan passphrase lebih panjang khusus untuk backup, terpisah dari PIN unlock harian |
| 4.2 | Tidak ada verifikasi identitas kunci publik E2EE (trust-on-first-use murni, server bisa secara teknis mengganti kunci publik seseorang) | Tambahkan fitur verifikasi manual (safety number/fingerprint) yang bisa dicocokkan dua pihak secara offline (QR, mis. digabung dengan fitur QR invite yang sudah ada) |
| 4.3 | Tidak ada forward secrecy — kompromi satu private key identity membuka seluruh histori chat room itu | Dokumentasikan sebagai batasan resmi di UI ("Percakapan dienkripsi, tapi bukan enkripsi tingkat Signal") sampai ada resource untuk implementasi ratcheting; jangan overclaim di marketing |
| 4.4 | Signaling channel WebRTC (`room_call:$roomId`) tidak diverifikasi keanggotaan lewat RLS/Realtime Authorization Supabase | Aktifkan Supabase Realtime Authorization (private channel + RLS policy) supaya hanya partisipan room/guardian sah yang bisa subscribe |
| 4.5 | Pola `catch (_) {}` dipakai 62 kali, termasuk di jalur kritikal (enkripsi, penyimpanan PIN, publish kunci) — kegagalan diam-diam adalah pola dominan | Audit ulang setiap `catch (_) {}` di jalur SOS/enkripsi/logging: minimal catat ke `security_logs` atau tampilkan state error ke UI, jangan ditelan begitu saja |
| 4.6 | Belum ada uji keamanan independen/pentest (disebutkan sendiri di roadmap dokumen desain sebagai target Rilis 1.0) | Lakukan pentest eksternal fokus ke: RLS bypass, WebRTC signaling, alur SOS/duress, sebelum listing publik |
| 4.7 | Rate limiting baru ada di `resolve_login_email`; endpoint lain (login, verifikasi PIN, verifikasi 2FA) belum terlihat ada rate limit eksplisit di level RPC/DB | Tambahkan rate limiting di semua endpoint autentikasi sensitif, bukan hanya satu fungsi |
| 4.8 | Data residency belum eksplisit dikonfirmasi (dokumen desain menyebut Supabase bisa pilih region EU/US/APAC, tapi belum ada bukti implementasi region tertentu untuk kepatuhan UU PDP) | Tetapkan & dokumentasikan region Supabase yang dipakai, selaras UU PDP Indonesia |

---

## 5. 🟡 P2 — Hardening Pasca-Launch

Tidak menghalangi rilis, tapi masuk backlog segera setelah stabil:

- Load testing untuk realtime channel (chat + location ping + WebRTC) di skenario SOS massal/serentak.
- Monitoring & alerting untuk kegagalan pengiriman notifikasi SOS ke guardian (ini jalur paling kritis — kalau notifikasi gagal terkirim, efeknya fatal).
- Automated testing (unit/widget/integration) — belum terlihat ada test suite berarti untuk alur SOS/guardian/E2EE di codebase saat ini.
- Key rotation policy untuk `e2ee_public_key` (saat ini publish sekali dan disimpan permanen tanpa mekanisme rotasi terjadwal).
- Battery/background execution testing di Android/iOS untuk streaming lokasi & audio saat SOS aktif (OS sering membunuh background process — ini bisa jadi kegagalan diam-diam paling berbahaya di real world).

---

## 6. Usulan Fitur Unik — Selaras Filosofi "Inisiatif dari Dalam"

Semua usulan di bawah sengaja **tidak** menambah kemampuan pengawasan sepihak — semuanya tetap dipicu sadar oleh pemilik akun, transparan, dan setara. Ini penting: aplikasi ini secara eksplisit memposisikan diri sebagai *anti-stalkerware*, jadi diferensiasi fiturnya sebaiknya memperkuat itu, bukan menggerogotinya.

### 🛡️ 6.1 "Kata Sandi Aman" (Safe Word) di dalam Chat Biasa
Frasa rahasia yang disepakati pengguna dengan Guardian-nya. Kalau frasa itu diketik di chat *biasa* (bukan tombol SOS), sistem diam-diam memicu Mode Darurat tanpa membuka layar SOS yang mencolok — berguna saat pengguna tidak bisa/berani menyentuh tombol SOS secara terang-terangan (mis. sedang diawasi langsung oleh pelaku). Tetap sesuai filosofi karena **pemicunya tetap tindakan sadar si pemilik akun sendiri**, hanya bentuknya yang disamarkan.

### 🤝 6.2 "Check-in Terjadwal" (Konsensual, Bukan Pelacakan Pasif)
Pengguna bisa mengatur "Saya akan check-in tiap 2 jam saat perjalanan malam ini." Kalau checkpoint terlewat tanpa konfirmasi, Guardian dapat notifikasi *"[Nama] belum check-in — mungkin ingin dihubungi"*. Beda dari SOS (bukan darurat pasti) dan beda dari pelacakan terus-menerus (bukan akses lokasi permanen) — ini murni **kontrak waktu terbatas yang disetujui dari awal**, konsisten dengan prinsip "izin kedaluwarsa" yang sudah ada di sistem Guardian.

### 📖 6.3 "Jurnal Aman" Tanpa Sinkronisasi ke Guardian
Ruang catatan pribadi terenkripsi lokal (bukan di server, atau di server tapi E2EE murni tanpa backup ke siapa pun) untuk mendokumentasikan insiden/perasaan dari waktu ke waktu — dengan opsi ekspor manual sebagai bukti tambahan di luar Log Sistem. Ini melengkapi "Log Bukti Hukum" yang sudah ada (yang mencatat *aksi sistem*) dengan ruang untuk *narasi manusia*, yang sering kali sama pentingnya secara hukum. Kuncinya: **tidak pernah otomatis terbagi ke siapa pun**, murni milik pengguna.

### 🔄 6.4 "Mode Latihan" (Drill Mode) untuk SOS
Simulasi penuh alur SOS (notifikasi ke Guardian, GPS, dst.) tapi ditandai jelas sebagai "LATIHAN" di semua sisi (termasuk ke Guardian) supaya kedua pihak familiar dan percaya diri dengan alur sebelum keadaan asli terjadi. Ini pola umum di pelatihan keselamatan (drill kebakaran) yang belum ada padanannya di aplikasi personal-safety manapun yang saya tahu — cocok jadi diferensiator sekaligus benar-benar meningkatkan kesiapan pengguna.

### 🧑‍🤝‍🧑 6.5 "Lingkaran Guardian" Multi-Orang dengan Peran Berjenjang
Saat ini satu relasi Guardian tampak 1:1. Filosofi "Mekaar" (saling) cocok diperluas: satu pengguna bisa punya beberapa Guardian dengan tingkat izin berbeda (mis. "Sahabat" hanya notifikasi + chat, "Orang tua" juga GPS), dan SOS mem-broadcast ke semua sekaligus, bukan cuma satu. Tetap konsisten prinsip karena **pengaturan izin tetap dikontrol penuh oleh pemilik akun per-Guardian**, bukan eskalasi otomatis.

### 🔔 6.6 "Bukti Diterima" (Acknowledgement) dari Guardian
Saat SOS dipicu, pengguna sering tidak tahu apakah Guardian-nya benar-benar melihat notifikasinya atau sedang tidur/HP mati. Tambahkan indikator eksplisit "✅ [Nama Guardian] telah melihat notifikasi darurat" begitu Guardian membuka notifikasi — meningkatkan rasa aman pengguna tanpa menambah data yang dikumpulkan tentang siapa pun (ini status baca timbal balik yang setara, sesuatu yang sudah lazim di chat biasa, hanya diperluas ke konteks darurat).

### 🗂️ 6.7 Direktori Sumber Daya Bantuan Lokal (Bukan Fitur Teknis, Tapi Sesuai Misi)
Halaman statis/terkurasi berisi kontak layanan bantuan resmi Indonesia (mis. hotline KemenPPPA, Layanan Sahabat Perempuan dan Anak/SAPA 129, kepolisian setempat) yang bisa diakses langsung dari layar SOS. Tidak menyentuh data sensitif sama sekali, biaya implementasi rendah, tapi selaras kuat dengan misi produk dan bisa jadi nilai tambah nyata di luar aspek teknis semata.

---

## 7. Checklist Ringkas (untuk tracking)

```
P0 — Sebelum ada data pengguna asli
[ ] Migrasi RLS 05 wajib & terdokumentasi tegas (atau digabung ke migrasi awal)
[ ] E2EE fail-closed, hentikan silent fallback plaintext
[ ] Copy "sign-logs" diluruskan (bukan "tanda tangan" sampai benar-benar signature)
[ ] TURN server privat untuk testing SOS video/audio

P1 — Sebelum rilis publik
[ ] Perkuat KDF backup E2EE (Argon2id)
[ ] Verifikasi fingerprint kunci publik E2EE
[ ] Dokumentasikan batasan forward secrecy
[ ] Supabase Realtime Authorization untuk WebRTC signaling channel
[ ] Audit ulang seluruh catch (_) {} di jalur kritikal
[ ] Pentest independen
[ ] Rate limiting menyeluruh di endpoint auth
[ ] Konfirmasi & dokumentasikan region data Supabase

P2 — Hardening pasca-launch
[ ] Load test realtime + WebRTC saat SOS massal
[ ] Monitoring kegagalan notifikasi SOS
[ ] Test suite otomatis untuk alur kritikal
[ ] Kebijakan rotasi kunci E2EE
[ ] Uji background execution Android/iOS untuk streaming saat SOS
```

---

## 8. Penutup

Fondasi filosofis MEKAAR — *"Inisiatif dari Dalam"*, anti-stalkerware, transparansi total — sudah jadi kompas yang jelas dan konsisten diterapkan di sebagian besar desain sistem (RLS guardian yang tidak bisa eskalasi sendiri, evidence-preserving delete, indikator OS wajib tampil). Pekerjaan yang tersisa bukan tentang mengubah arah, melainkan **menutup kesenjangan antara apa yang diklaim dan apa yang benar-benar diimplementasikan** — terutama di area E2EE dan bukti hukum, karena dua hal itulah yang paling dipercaya oleh pengguna dalam situasi taruhannya tinggi.
