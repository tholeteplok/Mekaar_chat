-- =============================================================
-- 82_seed_salma_emoji_pack.sql
-- Toko Emoji MEKAAR — pendaftaran katalog & 25 item pack "Salma".
--
-- CARA UNGGAH ASET STORAGE:
-- Unggah 25 file .png beserta _cover.png dari folder
-- `assets/.temp_emoji/salma/` ke bucket Supabase Storage:
--   Bucket: "emoji-packs"
--   Folder: "salma/"
--   Path contoh: salma/salma_wave.png, salma/_cover.png
-- =============================================================

-- ── 1. Daftarkan Pack Salma di katalog emoji_packs ──
insert into emoji_packs (slug, name, description, cover_url, item_count, sort_order, is_active)
values (
  'salma',
  'Salma',
  'Sahabat setia MEKAAR — ceria, hangat, dan penuh ekspresi.',
  'https://REPLACE-DISETUJUI.supabase.co/storage/v1/object/public/emoji-packs/salma/_cover.png',
  25,
  1,
  true
)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  cover_url = excluded.cover_url,
  item_count = excluded.item_count,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active;

-- ── 2. Daftarkan 25 Item Emoji Salma di emoji_pack_items ──
with pack as (
  select id from emoji_packs where slug = 'salma' limit 1
)
insert into emoji_pack_items (pack_id, shortcode, file_url, sort_order)
select
  pack.id,
  item.shortcode,
  'https://REPLACE-DISETUJUI.supabase.co/storage/v1/object/public/emoji-packs/salma/' || item.shortcode || '.png',
  item.sort_order
from pack,
(values
  ('salma_wave', 0),
  ('salma_santai', 1),
  ('salma_love', 2),
  ('salma_senang', 3),
  ('salma_kaget', 4),
  ('salma_marah', 5),
  ('salma_panik', 6),
  ('salma_tidur', 7),
  ('salma_melet', 8),
  ('salma_tanya', 9),
  ('salma_sedih', 10),
  ('salma_mewek', 11),
  ('salma_semangat', 12),
  ('salma_pout', 13),
  ('salma_terharu', 14),
  ('salma_hore', 15),
  ('salma_keren', 16),
  ('salma_ok', 17),
  ('salma_tangan_ok', 18),
  ('salma_pesta', 19),
  ('salma_salam', 20),
  ('salma_canggung', 21),
  ('salma_bingung', 22),
  ('salma_mata_hati', 23),
  ('salma_huft', 24)
) as item(shortcode, sort_order)
on conflict (pack_id, shortcode) do update set
  file_url = excluded.file_url,
  sort_order = excluded.sort_order;
