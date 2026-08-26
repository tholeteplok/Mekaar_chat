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

  const { targetUserId, reason } = await req.json();

  if (!targetUserId || !reason) {
    return Response.json(
      { error: "targetUserId dan reason wajib diisi" },
      { status: 400 }
    );
  }

  // 3. Panggil RPC dengan p_admin_id eksplisit (menjamin audit trail)
  const { error } = await supabase.rpc("admin_suspend_user", {
    p_target_user_id: targetUserId,
    p_reason: reason,
    p_admin_id: user.id,
  });

  if (error) {
    console.error("[admin_suspend_user error]", error);
    const isKnownGuard =
      error.message.includes("SUSPEND_BLOCKED") ||
      error.message.includes("FORBIDDEN");
    return Response.json(
      {
        error: isKnownGuard
          ? error.message
          : "Terjadi kesalahan pada server saat memproses pembekuan akun.",
      },
      { status: isKnownGuard ? 409 : 500 }
    );
  }

  return Response.json({ success: true });
}
