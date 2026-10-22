-- ==============================================================================
-- Migration: 99_user_contacts_vault_slots.sql
-- Description:
-- 1. Tambahkan kolom vault_slot (1, 2, atau 3) ke tabel user_contacts (default 1).
-- 2. Perbarui public.user_contacts_view agar menyertakan kolom vault_slot.
-- 3. Perbarui RPC set_contact_vault_status untuk mendukung parameter vault_slot.
-- 4. Tambahkan RPC delete_vault_slot untuk mengeluarkan seluruh kontak dalam slot tertentu.
-- ==============================================================================

-- 1. Tambahkan kolom vault_slot ke tabel user_contacts
ALTER TABLE public.user_contacts
ADD COLUMN IF NOT EXISTS vault_slot SMALLINT NOT NULL DEFAULT 1 CHECK (vault_slot BETWEEN 1 AND 3);

-- Buat indeks untuk percepatan query berdasarkan user_id, is_vaulted, dan vault_slot
CREATE INDEX IF NOT EXISTS idx_user_contacts_vault_slot 
ON public.user_contacts(user_id, is_vaulted, vault_slot);

-- 2. Perbarui user_contacts_view
-- Wajib DROP VIEW terlebih dahulu agar PostgreSQL mengizinkan perubahan struktur kolom view
DROP VIEW IF EXISTS public.user_contacts_view;

CREATE OR REPLACE VIEW public.user_contacts_view
WITH (security_barrier = true)
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

-- 3. Perbarui RPC set_contact_vault_status untuk menyertakan p_vault_slot
CREATE OR REPLACE FUNCTION public.set_contact_vault_status(
  p_contact_user_id UUID,
  p_is_vaulted BOOLEAN,
  p_vault_slot SMALLINT DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_slot SMALLINT := COALESCE(p_vault_slot, 1);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_slot < 1 OR v_slot > 3 THEN
    v_slot := 1;
  END IF;

  UPDATE public.user_contacts
  SET is_vaulted = p_is_vaulted,
      vault_slot = v_slot,
      updated_at = now()
  WHERE user_id = v_uid
    AND contact_user_id = p_contact_user_id;

  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_contact_vault_status(UUID, BOOLEAN, SMALLINT) TO authenticated;

-- 4. Tambahkan RPC delete_vault_slot untuk mengeluarkan seluruh kontak dari slot tertentu
CREATE OR REPLACE FUNCTION public.delete_vault_slot(
  p_vault_slot SMALLINT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_count INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Keluarkan seluruh kontak yang berada di slot p_vault_slot
  UPDATE public.user_contacts
  SET is_vaulted = FALSE,
      vault_slot = 1,
      updated_at = now()
  WHERE user_id = v_uid
    AND vault_slot = p_vault_slot
    AND is_vaulted = TRUE;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_vault_slot(SMALLINT) TO authenticated;
