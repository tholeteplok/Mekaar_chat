-- =============================================================
-- 80_custom_emoji.sql
-- Toko Emoji MEKAAR — katalog pack custom emoji.
--
-- DESAIN PENTING (E2EE):
-- Pesan hanya membawa shortcode ":slug:" di dalam kolom `content`
-- yang terenkripsi. URL aset TIDAK PERNAH masuk pesan; client
-- menyelesaikannya dari katalog ini yang di-fetch terpisah.
-- Dengan demikian server tidak mendapat metadata emoji apa pun
-- dari isi percakapan.
--
-- ASET BINER:
-- Migrasi SQL tidak dapat mengunggah file binary. Unggah aset
-- WebP/PNG statis 96px ke bucket "emoji-packs" via Dashboard
-- (Storage > emoji-packs > Upload), pola path:
--   {pack_slug}/{shortcode}.webp
-- Setelah itu jalankan INSERT seed item di bagian bawah file ini,
-- atau sesuaikan path sesuai unggahan nyata.
--
-- INSTALL DI CLIENT:
-- "Pasang" berarti client mengunduh seluruh file item pack ke
-- direktori dokumen aplikasi ({docs}/emoji_packs/{slug}/).
-- "Hapus" menghapus direktori tsb untuk hemat penyimpanan.
-- =============================================================

-- ── Bucket aset ──
insert into storage.buckets (id, name, public)
values ('emoji-packs', 'emoji-packs', true)
on conflict (id) do nothing;

-- Kebijakan: semua authenticated boleh MEMBACA aset (lazy-load penerima).
-- Sengaja TIDAK ada policy INSERT/UPDATE/DELETE untuk client:
-- pengelolaan aset hanya via Dashboard / service key (kurasi admin).
create policy "emoji packs read for authenticated"
on storage.objects for select to authenticated
using (bucket_id = 'emoji-packs');

-- ── Katalog pack ──
create table if not exists emoji_packs (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  description text,
  cover_url text,
  item_count int not null default 0,
  total_bytes bigint not null default 0,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table emoji_packs is
  'Katalog pack custom emoji (kurasi admin). item_count & total_bytes denormalisasi untuk UI toko.';

alter table emoji_packs enable row level security;

create policy "emoji packs readable by authenticated"
on emoji_packs for select to authenticated
using (is_active = true);

-- ── Item per pack ──
create table if not exists emoji_pack_items (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references emoji_packs(id) on delete cascade,
  shortcode text not null check (shortcode ~ '^[a-z0-9_]{2,32}$'),
  file_url text not null,
  bytes int not null default 0,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (pack_id, shortcode)
);

comment on column emoji_pack_items.shortcode is
  'Token tanpa titik dua, lowercase [a-z0-9_]. Dipakai sebagai :shortcode: di dalam content terenkripsi.';

alter table emoji_pack_items enable row level security;

create policy "emoji items readable by authenticated"
on emoji_pack_items for select to authenticated
using (true);

-- ── Seed contoh: pack "Mika" ──
-- Jalankan SETELAH aset diunggah ke bucket dengan pola path di atas.
insert into emoji_packs (slug, name, description, cover_url, sort_order)
values (
  'mika',
  'Mika',
  'Maskot MEKAAR — sapaan, semangat, dan rasa aman.',
  'https://REPLACE-DISETUJUI.supabase.co/storage/v1/object/public/emoji-packs/mika/_cover.webp',
  0
)
on conflict (slug) do nothing;
