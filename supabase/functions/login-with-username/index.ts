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
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
      console.error(
        "Konfigurasi server tidak lengkap: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, atau SUPABASE_ANON_KEY hilang.",
      );
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

    // 1. Client backend menggunakan service_role key HANYA untuk pencarian profil internal
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 2. Client autentikasi publik (anon key) untuk autentikasi kredensial pengguna via GoTrue
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 3. Cari email pengguna secara internal berdasarkan username (case-insensitive)
    const { data: profile, error: profileErr } = await adminClient
      .from("profiles")
      .select("email, is_suspended, suspended_reason")
      .ilike("username", username)
      .maybeSingle();

    if (profileErr) {
      console.error("adminClient profile lookup error:", profileErr);
    }

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

    // 4. Periksa status suspensi akun
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

    // 5. Autentikasi ke Supabase Auth dengan email dan password via authClient (anon key)
    const { data: authData, error: authErr } =
      await authClient.auth.signInWithPassword({
        email: profile.email,
        password: password,
      });

    if (authErr) {
      console.warn("GoTrue signInWithPassword rejection:", authErr.message);
      return invalidCredentialsResponse();
    }

    if (!authData.session) {
      console.warn("GoTrue did not return a session for user");
      return invalidCredentialsResponse();
    }

    // 6. Berhasil: Kembalikan sesi & user tanpa membocorkan email mentah ke publik
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
