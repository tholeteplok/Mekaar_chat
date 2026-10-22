-- ==============================================================================
-- Migration: 97_user_contacts_vault_flag.sql
-- Description:
-- 1. Tambahkan kolom is_vaulted BOOLEAN NOT NULL DEFAULT FALSE ke public.user_contacts.
-- 2. Perbarui public.user_contacts_view agar menyertakan kolom is_vaulted.
-- 3. Tambahkan RPC set_contact_vault_status untuk memperbarui status vault kontak.
-- ==============================================================================

-- 1. Tambahkan kolom is_vaulted ke tabel user_contacts
ALTER TABLE public.user_contacts
ADD COLUMN IF NOT EXISTS is_vaulted BOOLEAN NOT NULL DEFAULT FALSE;

-- Buat indeks untuk query berbasis user_id dan is_vaulted
CREATE INDEX IF NOT EXISTS idx_user_contacts_user_vaulted 
ON public.user_contacts(user_id, is_vaulted);

-- 2. Perbarui user_contacts_view
CREATE OR REPLACE VIEW public.user_contacts_view
WITH (security_barrier = true)
AS
SELECT
  c.id,
  c.user_id,
  c.contact_user_id,
  c.alias_name,
  c.is_vaulted,
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

-- 3. RPC set_contact_vault_status untuk memperbarui status vault kontak
CREATE OR REPLACE FUNCTION public.set_contact_vault_status(
  p_contact_user_id UUID,
  p_is_vaulted BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.user_contacts
  SET is_vaulted = p_is_vaulted,
      updated_at = now()
  WHERE user_id = v_uid
    AND contact_user_id = p_contact_user_id;

  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_contact_vault_status(UUID, BOOLEAN) TO authenticated;
