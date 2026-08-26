# 🛡️ MEKAAR — Review: Admin Moderation Portal (Next.js Blueprint)

> Blueprint-nya secara struktur App Router sudah rapi. Tapi saya cross-check ke backend yang **sudah dibangun** (`54_admin_moderation_schema.sql`, `55_audit_remediation.sql`) sebelum nulis review ini — dan ketemu satu ketidakcocokan fundamental antara blueprint dan backend yang harus dibetulkan dulu sebelum apa pun lain, karena tanpa itu portal-nya kemungkinan besar gak akan berfungsi sama sekali buat admin manapun.

---

## 🔴 Kritis #1 — RBAC check di middleware salah sumber data

Blueprint:
```js
if (user.app_metadata.role !== 'admin') { ... }
```

Backend yang sebenarnya (`55_audit_remediation.sql`, baris 121-127):
```sql
SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_admin_id;
IF COALESCE(v_is_admin, false) IS NOT TRUE THEN
  RAISE EXCEPTION 'FORBIDDEN: ...';
END IF;
```

Sumber kebenaran status admin di seluruh backend adalah kolom **`public.profiles.is_admin`** — bukan klaim `app_metadata.role` di JWT. Dua mekanisme ini gak ada hubungannya sama sekali. Kalau middleware dibangun persis sesuai blueprint:

- Kalau gak ada proses lain yang pernah nge-set `app_metadata.role = 'admin'` di Supabase Auth (dan gak ada indikasi itu ada di backend manapun yang saya cek) → **setiap admin asli akan selalu di-redirect ke `/login`**, portal-nya gak bisa dipakai siapa pun dari hari pertama.
- Kalau nanti ada yang "solusi cepat" nge-set `app_metadata.role` manual biar middleware lolos → sekarang ada **dua mekanisme admin yang gak sinkron** (JWT claim vs kolom DB). JWT itu di-cache sampai token refresh — jadi admin yang baru di-demote (`is_admin = false`) tetap lolos middleware sampai token-nya expired/refresh, walau RPC-nya sendiri tetap benar nolak (karena RPC query live ke `profiles.is_admin`). Bukan lubang privilege escalation fatal (RPC tetap jadi garis pertahanan terakhir yang benar), tapi tetap sumber bug & kebingungan yang gak perlu.

**Revisi — middleware harus baca sumber yang sama dengan RPC:**

```ts
// middleware.ts
import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function middleware(request: NextRequest) {
  const response = NextResponse.next({ request });
  const supabase = createServerClient(/* ...cookie handlers... */);

  // WAJIB getUser(), bukan getSession() — lihat Kritis #2
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Query LANGSUNG ke profiles.is_admin — sama persis sumber yang dipakai RPC,
  // bukan app_metadata.role yang gak pernah di-set di backend manapun
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single();

  if (!profile?.is_admin) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  return response;
}
```

Ini cuma proteksi UI (redirect halaman) — RPC tetap harus jadi penjaga sebenarnya (§ berikutnya), tapi minimal sekarang middleware gak pernah salah nolak admin asli atau salah meloloskan yang udah di-demote.

---

## 🔴 Kritis #2 — Middleware harus pakai `getUser()`, bukan `getSession()`

Blueprint gak nunjukin secara eksplisit method mana yang dipakai buat dapetin `user`. Ini titik yang paling sering salah di setup Next.js + Supabase SSR: `getSession()` baca JWT dari cookie **tanpa validasi ulang ke server Supabase Auth** — kalau ada cara cookie itu dimanipulasi/expired-tapi-belum-dibersihkan, `getSession()` bisa tetap ngasih data yang keliatan valid. `getUser()` selalu roundtrip verifikasi ke Supabase Auth server, jadi itu yang wajib dipakai di middleware & route handler manapun yang menentukan akses. Ini bukan saran, ini requirement keamanan dari dokumentasi Supabase sendiri untuk SSR — pastikan `lib/supabase/server.ts` dan semua pemanggilnya konsisten pakai `getUser()`.

---

## 🔴 Kritis #3 — API Route Handler harus verifikasi ulang, gak boleh cuma andalkan middleware

`middleware.ts` matcher config gampang salah scope (misal cuma meng-cover `/dashboard/*` tapi lupa `/api/admin/*`). Kalau itu terjadi, `app/api/admin/suspend/route.ts` bisa diakses langsung (curl/fetch dengan cookie yang dicuri) tanpa pernah lewat middleware sama sekali. Route handler **wajib** verifikasi admin sendiri, independen dari middleware — defense in depth, bukan cuma optimisasi:

```ts
// app/api/admin/suspend/route.ts
import { createClient } from '@/lib/supabase/server';

export async function POST(req: Request) {
  const supabase = await createClient();

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Verifikasi admin di level route handler juga — jangan asumsi middleware sudah cukup
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single();

  if (!profile?.is_admin) {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  const { targetUserId, reason } = await req.json();

  // p_admin_id WAJIB dikirim eksplisit, jangan andalkan auth.uid() implisit di RPC —
  // lihat Kritis #4 kenapa ini penting
  const { error } = await supabase.rpc('admin_suspend_user', {
    p_target_user_id: targetUserId,
    p_reason: reason,
    p_admin_id: user.id,
  });

  if (error) {
    console.error('[admin_suspend_user]', error); // log lengkap cuma di server
    // Jangan kirim error.message mentah ke client (lihat Sedang #6) —
    // kecuali untuk error yang memang didesain user-facing (SUSPEND_BLOCKED, FORBIDDEN)
    const isKnownGuard = error.message.includes('SUSPEND_BLOCKED') || error.message.includes('FORBIDDEN');
    return Response.json(
      { error: isKnownGuard ? error.message : 'Terjadi kesalahan, coba lagi.' },
      { status: isKnownGuard ? 409 : 500 },
    );
  }

  return Response.json({ success: true });
}
```

RPC `admin_suspend_user` sendiri **sudah benar** — sudah ada guard admin (baris 120-127) dan guard imunitas SOS (baris 129-135) di level database, jadi ini genuinely defense-in-depth berlapis, bukan satu-satunya gerbang. Kerja bagus di sisi SQL-nya.

---

## 🔴 Kritis #4 — `p_admin_id` wajib dikirim eksplisit, jangan andalkan `auth.uid()` implisit

RPC-nya sudah mendukung `p_admin_id uuid DEFAULT NULL` dengan `COALESCE(p_admin_id, auth.uid())` — tapi contoh kode di blueprint **tidak mengirim parameter ini sama sekali**:

```ts
// Blueprint asli — TIDAK mengirim p_admin_id
const { data, error } = await supabase.rpc('admin_suspend_user', {
  p_target_user_id: targetUserId,
  p_reason: reason,
});
```

Selama `createClient()` di server.ts pakai cookie-based SSR client (session admin sendiri, bukan `service_role`), `auth.uid()` di dalam RPC otomatis resolve ke admin yang login — jadi kebetulan tetap benar **selama itu**. Tapi ini rapuh: begitu ada yang "optimasi" ganti ke `service_role` client (misal biar bisa bypass RLS untuk fitur lain), `auth.uid()` jadi `NULL` di dalam RPC, `v_admin_id` jadi `NULL`, dan `INSERT INTO admin_audit_logs` gagal kena `NOT NULL` constraint pada kolom `admin_id` — suspend gagal total, atau lebih buruk kalau constraint itu somehow dilewati, log audit kehilangan atribusi siapa yang melakukan aksi. Untuk sistem yang tujuannya justru **immutable audit trail**, jangan pernah gantungin atribusi admin ke resolusi implisit yang tergantung jenis client dipakai — selalu `getUser()` dulu, kirim `user.id` eksplisit sebagai `p_admin_id`, apa pun jenis client-nya (lihat contoh kode di Kritis #3).

---

## 🔴 Kritis #5 — Legal Hold flag ada di schema, tapi **tidak pernah dicek di jalur penghapusan data manapun**

Ini yang paling penting dari seluruh review ini. `54_admin_moderation_schema.sql` nambahin `legal_hold_active`/`legal_hold_case_ref` ke `profiles` — tapi saya grep **seluruh** folder migrations:

```
$ grep -rln "legal_hold" supabase/migrations
supabase/migrations/54_admin_moderation_schema.sql   <- cuma di sini, satu-satunya
```

Dan cek eksplisit ke migration yang benar-benar menghapus data (`17_auto_delete.sql`, `44_fix_disappearing_and_lint_hardening.sql`, `65_scheduled_room_wipe.sql`, `66_burn_on_exit.sql`):

```
$ grep -c "legal_hold" 17_auto_delete.sql 44_fix_disappearing_and_lint_hardening.sql \
                        65_scheduled_room_wipe.sql 66_burn_on_exit.sql
0  0  0  0
```

**Nol.** Kolom `legal_hold_active` cuma duduk di tabel, gak pernah dicek oleh disappearing messages, scheduled room wipe, atau burn-on-exit. Artinya: kalau admin nyalain Legal Hold buat user yang lagi diinvestigasi, **pesan mereka tetap terhapus otomatis seperti biasa** sesuai TTL/burn-on-exit yang aktif — flag-nya kosmetik, gak melindungi apa pun. Ini bukan cuma bug fitur, ini masalah hukum — kalau "Legal Hold" dipakai buat justify ke tim legal/compliance bahwa data sudah diamankan, padahal secara teknis gak ada enforcement, itu klaim yang gak benar.

**Juga belum ada RPC buat nge-set flag ini** — `app/api/admin/legal-hold/route.ts` di blueprint gak ada fungsi backend buat dipanggil. Perlu:

1. **RPC baru** `admin_set_legal_hold(p_target_user_id, p_active, p_case_ref, p_admin_id)` — pola sama persis kayak `admin_suspend_user` (admin guard + audit log insert dengan `action_type IN ('ENABLE_LEGAL_HOLD', 'DISABLE_LEGAL_HOLD')`, yang enum-nya sudah disiapkan dari migration 54).
2. **Tambahkan guard `legal_hold_active` di SETIAP jalur penghapusan** — minimal di `17_auto_delete.sql`, `44_fix_disappearing_and_lint_hardening.sql`, `65_scheduled_room_wipe.sql`, `66_burn_on_exit.sql`. Pola umumnya:
   ```sql
   -- Di dalam fungsi/trigger penghapusan, tambahkan sebelum DELETE:
   AND NOT EXISTS (
     SELECT 1 FROM public.profiles
     WHERE id = <owner_user_id> AND legal_hold_active = true
   )
   ```
3. Ini butuh audit terpisah ke tiap-tiap migration itu satu-satu — saya sarankan jangan digabung ke kerjaan portal Next.js ini, tapi jadi prasyarat yang harus selesai duluan, karena tanpa ini fitur Legal Hold di portal cuma UI kosong yang berbahaya (ngasih rasa aman palsu).

---

## 🟡 Sedang #6 — Jangan kirim `error.message` mentah ke client

```ts
if (error) {
  return Response.json({ error: error.message }, { status: 400 });
}
```

Error Postgres/PostgREST mentah bisa bocorin nama tabel/kolom/constraint internal ke response JSON yang keliatan di Network tab browser. Untuk portal internal risikonya lebih rendah dari public API, tapi tetap best practice: log detail di server (`console.error`/Sentry), kirim ke client cuma pesan yang memang didesain user-facing (contoh: `SUSPEND_BLOCKED`, `FORBIDDEN` dari RPC — itu sengaja dibuat buat dibaca admin) atau pesan generik untuk error lain. Contoh kode sudah disertakan di Kritis #3.

---

## 🟡 Sedang #7 — Evidence Viewer: sudah didesain benar secara arsitektur, tapi rawan stored XSS

Kabar baik dulu: cara `submit_user_report` di backend didesain sudah **benar** buat sistem E2EE — `evidence_snapshot` diisi oleh klien pelapor sendiri (yang secara sah sudah bisa lihat plaintext karena dia partisipan room), bukan lewat dekripsi sisi server. Ini penting dan sebaiknya didokumentasikan eksplisit di README portal — supaya jelas kenapa "Aegis E2EE" tetap konsisten walau ada fitur moderasi (dekripsi gak pernah kejadian di server, evidence itu submission sukarela dari pelapor).

Tapi karena `evidence_snapshot` adalah **teks yang dikontrol user pelapor**, dan bisa aja pelapor itu justru pelaku yang lagi coba nyerang admin: kalau `report-inspector-modal.tsx` merender field ini pakai `dangerouslySetInnerHTML` (godaan umum buat "biar formatting bagus"), itu jadi stored XSS yang nyasar ke sesi admin — dampaknya jauh lebih parah dari XSS biasa karena target-nya akun dengan akses suspend/legal-hold/lihat evidence semua orang. **Render sebagai plain text** (React/JSX escape otomatis kalau gak pakai `dangerouslySetInnerHTML`), kalau butuh rich formatting pakai sanitizer allowlist ketat (DOMPurify), jangan raw HTML.

---

## 🟡 Sedang #8 — Role admin masih biner, pertimbangkan tingkatan

`profiles.is_admin` cuma boolean — semua admin punya akses yang sama: suspend, legal hold, lihat evidence (termasuk data lokasi SOS yang sangat sensitif). Untuk app safety-focused, worth dipertimbangkan tingkatan (moderator biasa vs yang bisa approve legal hold vs yang bisa lihat data SOS/lokasi) — tapi ini keputusan produk/org, bukan sesuatu yang harus diputuskan sebelum MVP portal ini jalan. Cukup dicatat sebagai arah lanjutan, bukan blocker.

---

## 🟢 Sudah Bagus (Jangan Diubah)

- **`admin_audit_logs` immutable via `CREATE RULE ... DO INSTEAD NOTHING`** — ini pilihan yang lebih kuat dari sekadar mengandalkan absennya RLS policy UPDATE/DELETE, karena rule ini tetap berlaku bahkan untuk `service_role` yang secara default bypass RLS. Solid.
- **Guard imunitas SOS di `admin_suspend_user`** — sudah level database (`RAISE EXCEPTION`), bukan sekadar badge UI yang bisa diabaikan. Satu catatan kecil buat didiskusikan ke tim (bukan bug, tapi edge case kebijakan): karena SOS sekarang bisa ditrigger user sendiri, ada kemungkinan teoretis orang yang lagi diinvestigasi trigger SOS palsu buat dapat imunitas sesaat. Bukan sesuatu yang perlu diblokir dari sisi kode — cukup jadi catatan kebijakan buat tim Trust & Safety kalau pola ini kejadian di lapangan.
- **`REVOKE ALL ... FROM PUBLIC` + `GRANT EXECUTE ... TO authenticated`** di migration 55 — persis pola yang seharusnya, dan ini juga sekaligus konfirmasi kenapa Nearby Friends RPC gagal total kemarin (lupa baris ini). Kalau bikin RPC admin baru (legal hold), ikuti pola ini persis.
- **Validasi `message_id` cocok dengan `sender_id`** di `submit_user_report` — mencegah fabrikasi bukti nempel ke pesan orang lain yang gak relevan.

---

## Ringkasan Prioritas

| # | Temuan | Blocker MVP? |
|---|---|---|
| 1 | Middleware baca `app_metadata.role`, backend pakai `profiles.is_admin` | 🔴 Ya — portal gak akan bisa dipakai admin manapun tanpa ini |
| 2 | Middleware harus `getUser()`, bukan `getSession()` | 🔴 Ya |
| 3 | Route handler wajib verifikasi admin sendiri, gak cuma andalkan middleware | 🔴 Ya |
| 4 | `p_admin_id` wajib dikirim eksplisit dari `getUser()`, jangan implisit | 🔴 Ya |
| 5 | Legal Hold gak di-enforce di jalur penghapusan mana pun + RPC-nya belum ada | 🔴 Ya, kalau fitur Legal Hold mau benar-benar dipakai (bukan cuma UI) |
| 6 | Jangan expose `error.message` mentah | 🟡 Tidak, tapi cepat & murah dibetulkan sekalian |
| 7 | Evidence viewer rawan stored XSS kalau pakai `dangerouslySetInnerHTML` | 🟡 Tidak blocker MVP, tapi wajib jadi review item sebelum ship |
| 8 | Role admin masih biner | 🟢 Arah lanjutan, bukan blocker |
