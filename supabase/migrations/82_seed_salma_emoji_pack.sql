-- =============================================================
-- 82_seed_salma_emoji_pack.sql
-- Toko Emoji MEKAAR — pendaftaran katalog & 25 item pack "Salma".
--
-- CARA UNGGAH ASET STORAGE:
-- Unggah 25 file .png beserta _cover.png dari folder
-- `assets/.temp_emoji/salma/` (atau direktori unduhan) ke bucket Supabase Storage:
--   Bucket: "emoji-packs"
--   Folder: "salma/"
--   Path contoh: salma/salma_wave.png, salma/_cover.png
-- =============================================================

-- ── 1. Daftarkan Pack Salma di katalog emoji_packs ──
insert into emoji_packs (slug, name, description, cover_url, item_count, total_bytes, sort_order, is_active)
values (
  'salma',
  'Salma',
  'Sahabat setia MEKAAR — ceria, hangat, dan penuh ekspresi.',
  'salma/_cover.png',
  25,
  1438769,
  1,
  true
)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  cover_url = excluded.cover_url,
  item_count = excluded.item_count,
  total_bytes = excluded.total_bytes,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active;

-- ── 2. Daftarkan 25 Item Emoji Salma di emoji_pack_items ──
with pack as (
  select id from emoji_packs where slug = 'salma' limit 1
)
insert into emoji_pack_items (pack_id, shortcode, file_url, bytes, sort_order)
select
  pack.id,
  item.shortcode,
  'salma/' || item.shortcode || '.png',
  item.bytes,
  item.sort_order
from pack,
(values
  ('salma_wave', 59820, 0),
  ('salma_santai', 52459, 1),
  ('salma_love', 59938, 2),
  ('salma_senang', 56681, 3),
  ('salma_kaget', 59295, 4),
  ('salma_marah', 54205, 5),
  ('salma_panik', 62214, 6),
  ('salma_tidur', 51890, 7),
  ('salma_melet', 52027, 8),
  ('salma_tanya', 51967, 9),
  ('salma_sedih', 61557, 10),
  ('salma_mewek', 60234, 11),
  ('salma_semangat', 59242, 12),
  ('salma_pout', 53756, 13),
  ('salma_terharu', 66606, 14),
  ('salma_hore', 70931, 15),
  ('salma_keren', 55413, 16),
  ('salma_ok', 60130, 17),
  ('salma_tangan_ok', 64188, 18),
  ('salma_pesta', 64553, 19),
  ('salma_salam', 55902, 20),
  ('salma_canggung', 50368, 21),
  ('salma_bingung', 51343, 22),
  ('salma_mata_hati', 59568, 23),
  ('salma_huft', 47467, 24)
) as item(shortcode, bytes, sort_order)
on conflict (pack_id, shortcode) do update set
  file_url = excluded.file_url,
  bytes = excluded.bytes,
  sort_order = excluded.sort_order;
