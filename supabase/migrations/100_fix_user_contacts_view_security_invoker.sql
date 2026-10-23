-- ============================================================================
-- MEKAAR 3.0 Migration 100: Fix user_contacts_view security invoker
-- Menutup celah bypass RLS pada view kontak sesuai rekomendasi P0-1
-- ============================================================================

DROP VIEW IF EXISTS public.user_contacts_view;

CREATE VIEW public.user_contacts_view
WITH (security_invoker = true, security_barrier = true)
AS
SELECT
  c.id,
  c.user_id,
  c.contact_user_id,
  c.alias_name,
  c.is_vaulted,
  c.vault_slot,
  c.created_at,
  p.username,
  p.full_name,
  p.display_name,
  p.avatar_url,
  p.bio,
  EXISTS (
    SELECT 1 FROM public.guardians g
    WHERE (g.owner_id = c.user_id AND g.guardian_id = c.contact_user_id AND g.status = 'active')
       OR (g.guardian_id = c.user_id AND g.owner_id = c.contact_user_id AND g.status = 'active')
  ) AS is_guardian
FROM public.user_contacts c
JOIN public.public_profiles p ON p.id = c.contact_user_id;

GRANT SELECT ON public.user_contacts_view TO authenticated;
