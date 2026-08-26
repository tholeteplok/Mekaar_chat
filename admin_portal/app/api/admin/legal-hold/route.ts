import { createClient } from "@/lib/supabase/server";

export async function POST(req: Request) {
  const supabase = await createClient();

  // 1. Verifikasi otentikasi user via getUser()
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  // 2. Verifikasi status admin (Defense in depth)
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();

  if (!profile?.is_admin) {
    return Response.json({ error: "Forbidden: Hanya Administrator yang berhak." }, { status: 403 });
  }

  const { targetUserId, active, caseRef } = await req.json();

  if (!targetUserId || typeof active !== "boolean") {
    return Response.json(
      { error: "targetUserId dan active (boolean) wajib diisi" },
      { status: 400 }
    );
  }

  // 3. Panggil RPC admin_set_legal_hold dengan p_admin_id eksplisit
  const { error } = await supabase.rpc("admin_set_legal_hold", {
    p_target_user_id: targetUserId,
    p_active: active,
    p_case_ref: caseRef || null,
    p_admin_id: user.id,
  });

  if (error) {
    console.error("[admin_set_legal_hold error]", error);
    const isKnownGuard = error.message.includes("FORBIDDEN");
    return Response.json(
      {
        error: isKnownGuard
          ? error.message
          : "Terjadi kesalahan pada server saat mengatur status Legal Hold.",
      },
      { status: isKnownGuard ? 403 : 500 }
    );
  }

  return Response.json({ success: true });
}
