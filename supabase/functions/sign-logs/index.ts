# Log Cryptographic Signing — MEKAAR 3.0 (Blind Spot #5)
#
# Menandatangani ekspor Log Sistem secara kriptografis (SHA-256) di sisi server
# sehingga berkas bukti hukum tidak dapat diubah tanpa merusak tanda tangan.
#
# Deploy (membutuhkan Supabase CLI + project terhubung):
#   supabase functions deploy sign-logs
#
# Invoke dari Flutter:
#   await supabaseClient.functions.invoke('sign-logs', body: {'format': 'csv'});

# Supabase Edge Function — Deno runtime
# Markdown di atas diabaikan oleh Deno; ini adalah file entry function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.200.0/crypto/mod.ts";
import { encodeHex } from "https://deno.land/std@0.200.0/encoding/hex.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
    } = await supabaseClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Ambil log milik user (soft-delete diabaikan)
    const { data: logs, error } = await supabaseClient
      .from("security_logs")
      .select("id, event_type, details, created_at")
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .order("created_at", { ascending: false });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const rows = (logs as Array<Record<string, unknown>>) ?? [];
    const csvHeader = "ID,Event Type,Details,Created At";
    const csvLines = rows.map((row) => {
      const details = row.details
        ? JSON.stringify(row.details).replace(/,/g, ";")
        : "";
      return `${row.id},${row.event_type},"${details}",${row.created_at}`;
    });
    const csv = [csvHeader, ...csvLines].join("\n");

    // SHA-256 signature atas isi CSV + timestamp penandatanganan
    const signedAt = new Date().toISOString();
    const payload = `${csv}\n--SIGNED_AT--${signedAt}`;
    const hashBuffer = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(payload),
    );
    const signature = encodeHex(hashBuffer);

    return new Response(
      JSON.stringify({
        csv,
        signature,
        signed_at: signedAt,
        algorithm: "SHA-256",
        statement:
          "Dokumen ini ditandatangani secara kriptografis pada " +
          signedAt +
          " dan tidak dapat diubah tanpa merusak tanda tangan ini.",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
