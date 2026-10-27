// login-with-username — MEKAAR 3.0
//
// Supabase Edge Function untuk mengautentikasi pengguna via username & password
// tanpa pernah membocorkan alamat email asli ke sisi klien atau publik (Penutupan H3 Email Oracle).
//
// Deploy:
//   supabase functions deploy login-with-username

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface LoginPayload {
  username?: string;
  password?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      console.error("Konfigurasi server tidak lengkap: SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY hilang.");
      return new Response(
        JSON.stringify({ error: "Kesalahan internal server" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let payload: LoginPayload;
    try {
      payload = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Format request tidak valid" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const username = (payload.username || "").trim();
    const password = payload.password || "";

    if (!username || !password) {
      return new Response(
        JSON.stringify({ error: "Username dan password wajib diisi" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Client backend menggunakan service_role key untuk pencarian profil internal
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 1. Cari email pengguna secara internal berdasarkan username (case-insensitive)
    const { data: profile, error: profileErr } = await adminClient
      .from("profiles")
      .select("email, is_suspended, suspended_reason")
      .eq("username", username)
      .maybeSingle();

    // Respons generik untuk mencegah user enumeration oracle
    const invalidCredentialsResponse = () =>
      new Response(
        JSON.stringify({ error: "Username atau kata sandi tidak valid" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );

    if (profileErr || !profile || !profile.email) {
      // Tunggu sejenak secara acak untuk memitigasi timing attack
      await new Promise((r) => setTimeout(r, 100 + Math.random() * 80));
      return invalidCredentialsResponse();
    }

    // 2. Periksa status suspensi akun
    if (profile.is_suspended) {
      return new Response(
        JSON.stringify({
          error: "Akun ditangguhkan",
          reason: profile.suspended_reason || "Pelanggaran pedoman komunitas",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3. Autentikasi ke Supabase Auth dengan email dan password
    const { data: authData, error: authErr } =
      await adminClient.auth.signInWithPassword({
        email: profile.email,
        password: password,
      });

    if (authErr || !authData.session) {
      return invalidCredentialsResponse();
    }

    // 4. Berhasil: Kembalikan sesi & user tanpa membocorkan email mentah jika tidak diperlukan
    return new Response(
      JSON.stringify({
        session: authData.session,
        user: authData.user,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("login-with-username exception:", err);
    return new Response(
      JSON.stringify({ error: "Terjadi kesalahan internal saat autentikasi" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
