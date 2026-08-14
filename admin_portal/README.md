# MEKAAR 3.0 Admin Moderation Portal (Next.js Blueprint)

## 📌 Deskripsi
Admin Portal ini adalah aplikasi web khusus internal (*Web-Based Internal Admin Portal*) untuk tim Moderasi & Safety MEKAAR 3.0 berbasis **Next.js 14+ (App Router)**, **TailwindCSS**, dan **Supabase SSR (`@supabase/ssr`)**.

---

## 🏗️ Struktur Proyek (App Router Blueprint)

```text
admin_portal/
├── app/
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx              # Page Login Admin dengan Supabase Auth + MFA
│   ├── dashboard/
│   │   ├── layout.tsx                # Sidebar Navigation & Protected Route Guard
│   │   ├── page.tsx                  # Overview Statistics & Active SOS Sessions Monitor
│   │   ├── reports/
│   │   │   └── page.tsx              # Antrean Pelaporan User Reports (Filter, Queue, Inspector)
│   │   ├── audit-logs/
│   │   │   └── page.tsx              # Immutable Admin Audit Logs Viewer
│   │   └── users/
│   │       └── page.tsx              # User Search, Suspension Manager & Legal Hold Controls
│   ├── api/
│   │   └── admin/
│   │       ├── suspend/route.ts      # API Endpoint Proxy ke RPC admin_suspend_user
│   │       └── legal-hold/route.ts   # API Endpoint Proxy untuk Legal Hold Flag
│   ├── layout.tsx
│   └── page.tsx
├── components/
│   ├── ui/                           # Button, Badge, Card, Dialog (Tailwind + Shadcn UI)
│   ├── report-inspector-modal.tsx    # Modal Detail Inspector Laporan & Mini Evidence Viewer
│   ├── sos-active-badge.tsx          # Badge Indikator Status Imunitas SOS Darurat (🟢/🔴)
│   └── audit-log-table.tsx           # Tabel Immutable Logs Read-only
├── lib/
│   ├── supabase/
│   │   ├── client.ts                 # Supabase Browser Client
│   │   └── server.ts                 # Supabase Server Client (SSR Cookie Handlers)
│   └── utils.ts
├── middleware.ts                     # Auth Guard Middleware (Redirect jika non-admin / non-authenticated)
├── package.json
└── tailwind.config.js
```

---

## 🔒 Protokol Keamanan & Supabase SSR Integration

1. **Role-Based Access Control (RBAC)**:
   Middleware (`middleware.ts`) mengecek klaim pengguna pada token Supabase JWT:
   ```typescript
   if (user.app_metadata.role !== 'admin') {
     return NextResponse.redirect(new URL('/login', request.url));
   }
   ```

2. **Perlindungan Invoce Stored Procedure**:
   Aksi pembekuan akun dipanggil melalui Server Action atau Next.js Route Handler dengan menyertakan Supabase Server Client untuk mengidentifikasi ID Admin:
   ```typescript
   // app/api/admin/suspend/route.ts
   import { createClient } from '@/lib/supabase/server';

   export async function POST(req: Request) {
     const supabase = createClient();
     const { targetUserId, reason } = await req.json();

     const { data, error } = await supabase.rpc('admin_suspend_user', {
       p_target_user_id: targetUserId,
       p_reason: reason,
     });

     if (error) {
       return Response.json({ error: error.message }, { status: 400 });
     }

     return Response.json({ success: true });
   }
   ```

---

## 🚀 Panduan Memulai Proyek Next.js Baru

Untuk mulai menjalankan portal ini di direktori `admin_portal`:

```bash
# 1. Inisialisasi Next.js 14 App Router
npx create-next-app@latest admin_portal --typescript --tailwind --app --no-src-dir --import-alias "@/*"

# 2. Masuk ke direktori & install Supabase SSR Dependencies
cd admin_portal
npm install @supabase/supabase-js @supabase/ssr lucide-react clsx tailwind-merge

# 3. Jalankan server lokal
npm run dev
```
