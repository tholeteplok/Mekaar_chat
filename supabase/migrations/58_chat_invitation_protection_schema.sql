-- ============================================================================
-- MEKAAR 3.0 Migration 58: Chat & Call Invitation Protection Schema
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS chat_invitation_mode text DEFAULT 'approved_only' CHECK (chat_invitation_mode IN ('everyone', 'approved_only'));

CREATE TABLE IF NOT EXISTS public.chat_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitation_note text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  via_qr_code boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.chat_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_requests_select_participant ON public.chat_requests;
CREATE POLICY chat_requests_select_participant ON public.chat_requests
  FOR SELECT TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS chat_requests_insert_sender ON public.chat_requests;
CREATE POLICY chat_requests_insert_sender ON public.chat_requests
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS chat_requests_update_receiver ON public.chat_requests;
CREATE POLICY chat_requests_update_receiver ON public.chat_requests
  FOR UPDATE TO authenticated
  USING (auth.uid() = receiver_id OR auth.uid() = sender_id);
