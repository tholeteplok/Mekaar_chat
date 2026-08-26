# MEKAAR 3.0 Admin Moderation Portal (Next.js Blueprint & Security Specification)

## 📌 Deskripsi
Admin Portal ini adalah aplikasi web internal (*Web-Based Internal Admin Portal*) untuk tim Moderasi, Safety, & Legal Compliance MEKAAR 3.0. Portal ini dibangun menggunakan **Next.js 14+ (App Router)**, **TypeScript**, **TailwindCSS**, **Shadcn UI**, dan **Supabase SSR (`@supabase/ssr`)**.

Dokumen ini merupakan **Single Source of Truth (SSOT)** mutlak untuk arsitektur, standar keamanan, kontrak API database, dan implementasi frontend admin portal.

---

## 🏗️ Arsitektur Direktori (Next.js 14 App Router)

```text
admin_portal/
├── app/
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx              # Halaman Login Admin (Supabase Auth + MFA)
│   ├── dashboard/
│   │   ├── layout.tsx                # Sidebar Navigation & Protected Route Layout Guard
│   │   ├── page.tsx                  # Metrik Statistik & Real-time Active SOS Sessions Monitor
│   │   ├── reports/
│   │   │   └── page.tsx              # Antrean Pelaporan User (Filter, Status Queue, Evidence Viewer)
│   │   ├── audit-logs/
│   │   │   └── page.tsx              # Immutable Admin Audit Logs Viewer (Read-only)
│   │   └── users/
│   │       └── page.tsx              # Pencarian User, Manajemen Suspensi & Kontrol Legal Hold
│   ├── api/
│   │   └── admin/
│   │       ├── suspend/route.ts      # Proxy terproteksi ke RPC admin_suspend_user
│   │       └── legal-hold/route.ts   # Proxy terproteksi ke RPC admin_set_legal_hold
│   ├── layout.tsx                    # Root Layout (Theme Provider, Toaster)
│   └── page.tsx                      # Root Page (Redirect otomatis ke /dashboard atau /login)
├── components/
│   ├── ui/                           # Button, Badge, Card, Dialog, Table, Tabs (Shadcn UI)
│   ├── report-inspector-modal.tsx    # Modal Detail Laporan & XSS-Safe Evidence Viewer
│   ├── sos-active-badge.tsx          # Badge Indikator Status Imunitas SOS Aktif (🟢/🔴)
│   ├── audit-log-table.tsx           # Tabel Immutable Logs Read-only
│   └── user-action-dialogs.tsx       # Dialog Konfirmasi Suspend & Toggle Legal Hold
├── lib/
│   ├── supabase/
│   │   ├── client.ts                 # Supabase Browser Client (createBrowserClient)
│   │   └── server.ts                 # Supabase Server Client (createServerClient dengan cookie store)
│   └── utils.ts                      # Utility functions (cn, formatters)
├── middleware.ts                     # Auth & RBAC Guard (Memverifikasi public.profiles.is_admin)
├── .env.local.example                # Template Variabel Lingkungan
├── package.json
├── tsconfig.json
└── tailwind.config.js
```

---

## 🔒 Protokol Keamanan & Integritas Data (Wajib Dipatuhi)

### 1. Role-Based Access Control (RBAC) Berbasis Database
* **Sumber Kebenaran**: Kolom `public.profiles.is_admin` pada PostgreSQL Supabase.
* **Larangan**: **DILARANG** mengandalkan klaim JWT `user.app_metadata.role` karena tidak disinkronkan secara otomatis dan dapat menyebabkan *privilege desynchronization* atau penolakan login admin yang sah.

### 2. Validasi Sesi SSR yang Aman (`getUser()`)
* Di dalam `middleware.ts`, Server Actions, dan Route Handlers, **WAJIB** menggunakan `supabase.auth.getUser()`.
* **Larangan**: **DILARANG** menggunakan `getSession()` untuk otorisasi di server, karena `getSession()` hanya membaca payload cookie lokal tanpa verifikasi integritas ke server Supabase Auth.

```typescript
// middleware.ts
import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const isAuthPage = request.nextUrl.pathname.startsWith('/login');
  const isDashboardPage = request.nextUrl.pathname.startsWith('/dashboard');
  const isApiAdminPage = request.nextUrl.pathname.startsWith('/api/admin');

  // 1. Verifikasi User ke Server Auth
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    if (isDashboardPage || isApiAdminPage) {
      return NextResponse.redirect(new URL('/login', request.url));
    }
    return response;
  }

  // 2. Query Status Admin Langsung ke public.profiles
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single();

  const isAdmin = profile?.is_admin === true;

  if (!isAdmin) {
    if (isDashboardPage || isApiAdminPage) {
      return NextResponse.redirect(new URL('/login?error=unauthorized', request.url));
    }
  } else if (isAuthPage) {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }

  return response;
}

export const config = {
  matcher: ['/dashboard/:path*', '/api/admin/:path*', '/login'],
};
```

### 3. Defense-in-Depth pada API Route Handlers
Setiap Route Handler (`app/api/admin/*`) wajib melakukan verifikasi independen terhadap status admin dan menyuplai `p_admin_id` eksplisit ke RPC database.

```typescript
// app/api/admin/suspend/route.ts
import { createClient } from '@/lib/supabase/server';

export async function POST(req: Request) {
  const supabase = await createClient();

  // 1. Verifikasi otentikasi
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // 2. Verifikasi status admin (Defense in depth)
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single();

  if (!profile?.is_admin) {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  const { targetUserId, reason } = await req.json();

  if (!targetUserId || !reason) {
    return Response.json({ error: 'targetUserId dan reason wajib diisi' }, { status: 400 });
  }

  // 3. Panggil RPC dengan p_admin_id eksplisit (menjamin audit trail)
  const { error } = await supabase.rpc('admin_suspend_user', {
    p_target_user_id: targetUserId,
    p_reason: reason,
    p_admin_id: user.id,
  });

  if (error) {
    console.error('[admin_suspend_user error]', error);
    const isKnownGuard = error.message.includes('SUSPEND_BLOCKED') || error.message.includes('FORBIDDEN');
    return Response.json(
      { error: isKnownGuard ? error.message : 'Terjadi kesalahan sistem, silakan coba lagi.' },
      { status: isKnownGuard ? 409 : 500 }
    );
  }

  return Response.json({ success: true });
}
```

### 4. Pencegahan Stored XSS pada Evidence Viewer
* Pada arsitektur End-to-End Encryption (E2EE) MEKAAR 3.0, `evidence_snapshot` adalah plaintext yang dikirimkan secara sukarela oleh klien pelapor.
* Karena teks ini berada di bawah kendali pengguna (potensi payload berbahaya), komponen `report-inspector-modal.tsx` **DILARANG KERAS** menggunakan `dangerouslySetInnerHTML`.
* Tampilkan *evidence* sebagai teks ter-escape secara default via JSX `{report.evidence_snapshot}` atau gunakan sanitasi allowlist ketat (DOMPurify) jika membutuhkan rich formatting.

---

## 🗄️ Kontrak Database & Stored Procedures

Admin Portal mengonsumsi skema database PostgreSQL Supabase yang diatur dalam migrasi:

### 1. RPC `admin_suspend_user`
* **Signature**: `admin_suspend_user(p_target_user_id uuid, p_reason text, p_admin_id uuid)`
* **Guard**: 
  - Memverifikasi `profiles.is_admin = true` untuk pemanggil.
  - Memeriksa imunitas sesi SOS aktif target (`sos_sessions.status = 'active'`). Melempar error `SUSPEND_BLOCKED` jika target sedang dalam bahaya.
* **Audit**: Otomatis mencatat aksi ke tabel immutable `public.admin_audit_logs` dengan tipe `SUSPEND`.

### 2. RPC `admin_set_legal_hold`
* **Signature**: `admin_set_legal_hold(p_target_user_id uuid, p_active boolean, p_case_ref text, p_admin_id uuid)`
* **Fungsi**: Mengaktifkan atau menonaktifkan status perlindungan retensi data hukum (`profiles.legal_hold_active`).
* **Enforcement**: Saat `legal_hold_active = true`, seluruh fungsi penghapusan data (`purge_expired_messages`, `execute_room_burn_on_exit`, `delete_message_for_everyone`) diblokir untuk akun tersebut demi menjaga integritas barang bukti investigasi.
* **Audit**: Otomatis mencatat aksi ke tabel `public.admin_audit_logs` dengan tipe `ENABLE_LEGAL_HOLD` atau `DISABLE_LEGAL_HOLD`.

### 3. Tabel `public.admin_audit_logs` (Immutable)
* Bersifat *append-only* yang dilindungi oleh Database Rule `ON UPDATE DO INSTEAD NOTHING` dan `ON DELETE DO INSTEAD NOTHING`.
* Kolom: `id`, `admin_id`, `action_type`, `target_user_id`, `reason`, `ip_address`, `metadata`, `created_at`.

---

## ⚙️ Variabel Lingkungan (`.env.local`)

Buat file `.env.local` di dalam folder `admin_portal/`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://<your-project-id>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOi...
```

---

## 🚀 Panduan Memulai Proyek

```bash
# 1. Masuk ke direktori admin_portal
cd admin_portal

# 2. Inisialisasi dependensi
npm install

# 3. Jalankan server pengembangan
npm run dev
```
Akses portal melalui browser di `http://localhost:3000`.
