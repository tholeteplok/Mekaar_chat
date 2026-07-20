# Log Cryptographic Signing — MEKAAR 3.0 (Blind Spot #5)
#
# Menandatangani ekspor Log Sistem memakai TANDA TANGAN DIGITAL ASIMETRIS
# (Ed25519), bukan sekadar hash SHA-256 tanpa kunci. Bedanya penting untuk
# nilai bukti hukum:
#   - Hash SHA-256 saja HANYA membuktikan integritas selama pemeriksa sudah
#     percaya angka hash itu berasal dari server yang jujur — siapa pun bisa
#     menghitung ulang SHA-256 atas dokumen apa pun, termasuk dokumen palsu.
#   - Tanda tangan Ed25519 dibuat dengan PRIVATE KEY yang hanya dipegang
#     server (disimpan sebagai secret, tidak pernah dikirim ke client), dan
#     bisa diverifikasi pihak KETIGA (mis. penyidik/pengadilan) memakai
#     PUBLIC KEY saja — tanpa perlu mempercayai server itu lagi saat
#     verifikasi. Ini yang disebut non-repudiation.
#
# ── Setup (wajib sebelum deploy) ──────────────────────────────────────────
# 1. Generate keypair Ed25519 sekali di mesin lokal (jangan di client app):
#      deno run -A -e '
#        import * as ed from "https://esm.sh/@noble/ed25519@2.1.0";
#        const priv = ed.utils.randomPrivateKey();
#        const pub = await ed.getPublicKeyAsync(priv);
#        console.log("PRIVATE (secret, simpan di Supabase secrets):",
#          Array.from(priv).map(b => b.toString(16).padStart(2,"0")).join(""));
#        console.log("PUBLIC (boleh dipublikasikan, untuk verifikasi):",
#          Array.from(pub).map(b => b.toString(16).padStart(2,"0")).join(""));
#      '
# 2. Simpan private key sebagai secret Edge Function (JANGAN commit ke repo):
#      supabase secrets set LOG_SIGNING_ED25519_PRIVATE_KEY=<hex_private_key>
# 3. Publikasikan public key di tempat yang bisa diakses pihak ketiga untuk
#    verifikasi independen (mis. halaman "Tentang" aplikasi / dokumen resmi),
#    terpisah dari respons fungsi ini.
#
# Deploy:
#   supabase functions deploy sign-logs
#
# Invoke dari Flutter:
#   await supabaseClient.functions.invoke('sign-logs', body: {'format': 'csv'});
#
# Verifikasi independen (di luar aplikasi, oleh siapa pun yang punya public
# key), contoh dengan @noble/ed25519:
#   const ok = await ed.verifyAsync(signatureHexToBytes, payloadUtf8Bytes, publicKeyBytes);

# Supabase Edge Function — Deno runtime
# Markdown di atas diabaikan oleh Deno; ini adalah file entry function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as ed from "https://esm.sh/@noble/ed25519@2.1.0";
import { sha512 } from "https://esm.sh/@noble/hashes@1.4.0/sha512";

// @noble/ed25519 v2 butuh implementasi SHA-512 di-inject manual di Deno
// (tidak seperti Node, Deno tidak menyediakannya secara default untuk lib ini).
ed.etc.sha512Sync = (...m: Uint8Array[]) =>
  sha512(ed.etc.concatBytes(...m));

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim().toLowerCase();
  if (!/^[0-9a-f]+$/.test(clean) || clean.length % 2 !== 0) {
    throw new Error("LOG_SIGNING_ED25519_PRIVATE_KEY tidak valid (hex)");
  }
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.substr(i * 2, 2), 16);
  }
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

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

    const privHex = Deno.env.get("LOG_SIGNING_ED25519_PRIVATE_KEY");
    if (!privHex) {
      // Fail closed: jangan pernah keluarkan dokumen yang diklaim
      // "ditandatangani" tanpa kunci penandatanganan yang benar terpasang.
      return new Response(
        JSON.stringify({
          error:
            "Server belum dikonfigurasi untuk penandatanganan log " +
            "(LOG_SIGNING_ED25519_PRIVATE_KEY belum diset).",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
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

    // Tanda tangan Ed25519 atas isi CSV + user id + timestamp penandatanganan.
    // user_id disertakan supaya tanda tangan terikat ke pemilik log (tidak
    // bisa dipindah-tempelkan ke ekspor milik pengguna lain).
    const signedAt = new Date().toISOString();
    const payload = `${csv}\n--USER--${user.id}\n--SIGNED_AT--${signedAt}`;
    const payloadBytes = new TextEncoder().encode(payload);

    const privateKey = hexToBytes(privHex);
    const publicKey = await ed.getPublicKeyAsync(privateKey);
    const signatureBytes = await ed.signAsync(payloadBytes, privateKey);

    return new Response(
      JSON.stringify({
        csv,
        signature: bytesToHex(signatureBytes),
        public_key: bytesToHex(publicKey),
        signed_at: signedAt,
        signed_user_id: user.id,
        algorithm: "Ed25519",
        statement:
          "Dokumen ini ditandatangani dengan tanda tangan digital Ed25519 " +
          "pada " + signedAt + " oleh server MEKAAR. Verifikasi keaslian " +
          "dapat dilakukan oleh pihak mana pun menggunakan 'public_key' " +
          "di atas terhadap payload gabungan CSV + user id + waktu tanda " +
          "tangan, tanpa perlu mempercayai server ini lagi. Public key " +
          "resmi juga dipublikasikan terpisah dari respons ini.",
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
