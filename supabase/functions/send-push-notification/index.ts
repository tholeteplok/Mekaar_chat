// send-push-notification — MEKAAR 3.0
//
// Supabase Edge Function yang dikirim oleh Database Webhooks (pg_net)
// saat ada INSERT di tabel messages atau calls.
//
// Function ini:
// 1. Menerima webhook payload dari pg_net (INSERT record)
// 2. Melookup FCM token penerima dari tabel profiles
// 3. Mengirim FCM push notification via Firebase Admin SDK
//
// ── Setup (wajib sebelum deploy) ──────────────────────────────────────────
// 1. Set Firebase service account credentials sebagai secret:
//      supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
//
//    Atau gunakan variabel individual:
//      supabase secrets set FIREBASE_PROJECT_ID=<project_id>
//      supabase secrets set FIREBASE_CLIENT_EMAIL=<client_email>
//      supabase secrets set FIREBASE_PRIVATE_KEY=<private_key>
//
// 2. Deploy function:
//      supabase functions deploy send-push-notification
//
// 3. Attach database triggers (via migration 38_push_notification_triggers.sql)
//
// Deploy:
//   supabase functions deploy send-push-notification

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { initializeApp, cert, type App } from "https://esm.sh/firebase-admin@12/app";
import { getMessaging } from "https://esm.sh/firebase-admin@12/messaging";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Firebase app singleton (di-initialize sekali per cold start)
let firebaseApp: App | null = null;

function getFirebaseApp(): App {
  if (firebaseApp) return firebaseApp;

  // Coba parse service account JSON lengkap dulu
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (serviceAccountJson) {
    const serviceAccount = JSON.parse(serviceAccountJson);
    firebaseApp = initializeApp({
      credential: cert(serviceAccount),
    });
    return firebaseApp;
  }

  // Fallback: gunakan variabel individual
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      "Firebase credentials belum dikonfigurasi. " +
        "Set FIREBASE_SERVICE_ACCOUNT atau FIREBASE_PROJECT_ID + " +
        "FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY sebagai " +
        "Supabase secret.",
    );
  }

  firebaseApp = initializeApp({
    credential: cert({ projectId, clientEmail, privateKey }),
  });
  return firebaseApp;
}

// ── Interface untuk webhook payload dari pg_net ──────────────────────────
interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: Record<string, unknown> | null;
  old_record: Record<string, unknown> | null;
}

interface MessageRecord {
  id: string;
  room_id: string;
  sender_id: string;
  content: string | null;
  msg_type: string;
  is_deleted: boolean;
  created_at: string;
}

interface CallRecord {
  id: string;
  room_id: string;
  caller_id: string;
  receiver_id: string;
  call_type: string;
  status: string;
  created_at: string;
}

// ── Helper: deteksi & bersihkan FCM token yang sudah tidak valid ──────────
// Token invalid (app di-uninstall / token di-revoke) akan terus gagal terkirim
// selamanya kalau tidak dibersihkan. Saat terdeteksi, kita kosongkan
// profiles.fcm_token supaya kegagalan permanen tidak menutupi kegagalan baru
// yang perlu diperhatikan.

function isInvalidTokenError(e: unknown): boolean {
  const code = (e as { code?: string })?.code;
  return typeof code === "string" &&
    (code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-found");
}

interface DeviceTokenInfo {
  token: string;
  deviceId?: string;
}

async function getUserDeviceTokens(
  supabaseClient: ReturnType<typeof createClient>,
  profileId: string,
  targetDeviceId?: string | null,
): Promise<DeviceTokenInfo[]> {
  try {
    let query = supabaseClient
      .from("user_devices")
      .select("fcm_token, device_id")
      .eq("profile_id", profileId)
      .not("fcm_token", "is", null);

    if (targetDeviceId) {
      query = query.eq("device_id", targetDeviceId);
    }

    const { data: devices, error } = await query;
    if (!error && devices && devices.length > 0) {
      return devices.map((d: { fcm_token: string; device_id: string }) => ({
        token: d.fcm_token,
        deviceId: d.device_id,
      }));
    }
  } catch (e) {
    console.warn(`Query user_devices error (user ${profileId}):`, String(e));
  }

  // Fallback ke profiles.fcm_token
  if (!targetDeviceId) {
    const { data: profile } = await supabaseClient
      .from("profiles")
      .select("fcm_token")
      .eq("id", profileId)
      .single();

    if (profile?.fcm_token) {
      return [{ token: profile.fcm_token }];
    }
  }

  return [];
}

async function clearFcmToken(
  supabaseClient: ReturnType<typeof createClient>,
  profileId: string,
  deviceId?: string,
): Promise<void> {
  try {
    if (deviceId) {
      await supabaseClient
        .from("user_devices")
        .update({ fcm_token: null })
        .eq("profile_id", profileId)
        .eq("device_id", deviceId);
    } else {
      await supabaseClient
        .from("user_devices")
        .update({ fcm_token: null })
        .eq("profile_id", profileId);
    }
    await supabaseClient
      .from("profiles")
      .update({ fcm_token: null })
      .eq("id", profileId);
    console.warn(`FCM token untuk user ${profileId} (device ${deviceId ?? "all"}) dibersihkan (invalid).`);
  } catch (e) {
    console.warn(`Gagal membersihkan FCM token user ${profileId}:`, String(e));
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Webhook dari pg_net dikirim tanpa Authorization header,
    // jadi kita pakai service_role key untuk akses Supabase.
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Gunakan anon key + user's auth header jika ada,
    // atau service_role untuk webhook internal
    const authHeader = req.headers.get("Authorization");
    const apiKey = req.headers.get("apikey");

    let supabaseClient;
    if (authHeader && apiKey) {
      // Dipanggil dari client (authenticated)
      supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
    } else {
      // Dipanggil dari pg_net webhook (internal)
      supabaseClient = createClient(supabaseUrl, supabaseServiceKey);
    }

    const payload: WebhookPayload = await req.json();

    // Hanya proses INSERT
    if (payload.type !== "INSERT" || !payload.record) {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let pushPayload: {
      token: string;
      data: Record<string, string>;
      android?: { priority: string };
      apns?: { payload: Record<string, unknown> };
    } | null = null;

    // ── Handle Message INSERT ──
    if (payload.table === "messages") {
      const msg = payload.record as MessageRecord;

      // Skip system messages dan deleted messages
      if (msg.msg_type === "system" || msg.is_deleted) {
        return new Response(JSON.stringify({ ok: true, skipped: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Lookup penerima: semua peserta room kecuali pengirim
      const { data: participants, error: partErr } = await supabaseClient
        .from("room_participants")
        .select("profile_id, is_muted, muted_until")
        .eq("room_id", msg.room_id)
        .neq("profile_id", msg.sender_id);

      if (partErr || !participants || participants.length === 0) {
        return new Response(
          JSON.stringify({ ok: true, reason: "no_recipients" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Ambil nama pengirim
      const { data: senderProfile } = await supabaseClient
        .from("public_profiles")
        .select("display_name, username")
        .eq("id", msg.sender_id)
        .single();

      const senderName =
        senderProfile?.display_name ||
        senderProfile?.username ||
        "Seseorang";

      // Kirim push ke setiap penerima
      const messaging = getMessaging(getFirebaseApp());
      const results = [];

      for (const p of participants) {
        // Skip jika participant mute room ini
        if (p.is_muted) {
          const mutedUntil = p.muted_until;
          if (!mutedUntil || new Date(mutedUntil) > new Date()) {
            continue; // masih dalam periode mute
          }
          // mutedUntil sudah lewat — lanjut kirim (mute expired)
        }

        const deviceTokens = await getUserDeviceTokens(
          supabaseClient,
          p.profile_id,
        );
        if (deviceTokens.length === 0) continue;

        // Generate preview text berdasarkan tipe pesan
        let bodyText = msg.content || "";
        if (msg.msg_type === "image") bodyText = "📷 Gambar";
        else if (msg.msg_type === "voice") bodyText = "🎤 Pesan suara";
        else if (msg.msg_type === "video") bodyText = "🎬 Video";
        else if (msg.msg_type === "location") bodyText = "📍 Lokasi";

        // Batasi panjang body
        if (bodyText.length > 100) {
          bodyText = bodyText.substring(0, 97) + "...";
        }

        for (const dt of deviceTokens) {
          results.push(
            messaging.send({
              token: dt.token,
              data: {
                type: "message",
                roomId: msg.room_id,
                title: senderName,
                body: bodyText,
                senderName,
                messageId: msg.id,
              },
              android: {
                priority: "high",
              },
              apns: {
                payload: {
                  aps: {
                    badge: 1,
                    "content-available": 1,
                  },
                },
              },
            }).catch(async (e: unknown) => {
              console.warn(
                `FCM send failed for token (user ${p.profile_id}, device ${dt.deviceId ?? "unknown"}):`,
                String(e),
              );
              if (isInvalidTokenError(e)) {
                await clearFcmToken(supabaseClient, p.profile_id, dt.deviceId);
              }
              return null;
            }),
          );
        }
      }

      const sentCount = (await Promise.all(results)).filter(Boolean).length;
      return new Response(
        JSON.stringify({ ok: true, sent: sentCount, type: "message" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Handle Call INSERT ──
    if (payload.table === "calls") {
      const call = payload.record as CallRecord;

      // Hanya kirim push untuk status 'ringing'
      if (call.status !== "ringing") {
        return new Response(JSON.stringify({ ok: true, skipped: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Lookup FCM tokens penerima (semua device milik receiver)
      const receiverTokens = await getUserDeviceTokens(
        supabaseClient,
        call.receiver_id,
      );

      if (receiverTokens.length === 0) {
        return new Response(
          JSON.stringify({ ok: true, reason: "no_fcm_token" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Ambil nama caller
      const { data: callerProfile } = await supabaseClient
        .from("public_profiles")
        .select("display_name, username")
        .eq("id", call.caller_id)
        .single();

      const callerName =
        callerProfile?.display_name ||
        callerProfile?.username ||
        "Seseorang";

      const callLabel =
        call.call_type === "video" ? "Panggilan video masuk" : "Panggilan masuk";

      const messaging = getMessaging(getFirebaseApp());
      const callResults = [];

      for (const dt of receiverTokens) {
        callResults.push(
          messaging.send({
            token: dt.token,
            data: {
              type: "call",
              roomId: call.room_id,
              callId: call.id,
              callerId: call.caller_id,
              title: callLabel,
              body: callerName,
              callerName,
              callType: call.call_type,
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  "content-available": 1,
                },
              },
            },
          }).catch(async (e: unknown) => {
            console.warn(
              `FCM call send failed (receiver ${call.receiver_id}, device ${dt.deviceId ?? "unknown"}):`,
              String(e),
            );
            if (isInvalidTokenError(e)) {
              await clearFcmToken(supabaseClient, call.receiver_id, dt.deviceId);
            }
            return null;
          }),
        );
      }

      const sentCount = (await Promise.all(callResults)).filter(Boolean).length;

      return new Response(
        JSON.stringify({ ok: true, sent: sentCount, type: "call" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Handle SOS Session INSERT ──
    if (payload.table === "sos_sessions") {
      const record = payload.record as Record<string, unknown>;
      const userId = record.user_id as string;
      const status = record.status as string;
      const message = record.message as string | null;
      const sessionId = record.id as string;

      // Hanya kirim push untuk SOS aktif baru
      if (status !== "active") {
        return new Response(JSON.stringify({ ok: true, skipped: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Ambil nama korban
      const { data: victimProfile } = await supabaseClient
        .from("public_profiles")
        .select("display_name, username")
        .eq("id", userId)
        .single();

      const victimName =
        victimProfile?.display_name ||
        victimProfile?.username ||
        "Seseorang";

      // Cari semua guardian aktif
      const { data: guardianRelations } = await supabaseClient
        .from("guardians")
        .select("guardian_id")
        .eq("owner_id", userId)
        .eq("status", "active");

      if (!guardianRelations || guardianRelations.length === 0) {
        return new Response(
          JSON.stringify({ ok: true, reason: "no_guardians" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const messaging = getMessaging(getFirebaseApp());
      const results = [];

      for (const rel of guardianRelations) {
        const guardianTokens = await getUserDeviceTokens(
          supabaseClient,
          rel.guardian_id,
        );

        for (const dt of guardianTokens) {
          results.push(
            messaging.send({
              token: dt.token,
              // DATA-ONLY — no 'notification' key agar selalu lewat kode Dart
              data: {
                type: "sos",
                sessionId: sessionId,
                userId: userId,
                title: `🆘 DARURAT — ${victimName}`,
                body: message ?? "Butuh bantuan segera! Tap untuk melihat lokasi.",
                victimName: victimName,
              },
              android: {
                priority: "high",
              },
              apns: {
                payload: {
                  aps: {
                    "content-available": 1,
                    sound: "default",
                  },
                },
              },
            }).catch(async (e: unknown) => {
              console.warn(`FCM SOS send failed for guardian ${rel.guardian_id} (device ${dt.deviceId ?? "unknown"}):`, String(e));
              if (isInvalidTokenError(e)) {
                await clearFcmToken(supabaseClient, rel.guardian_id, dt.deviceId);
              }
              return null;
            }),
          );
        }
      }

      const sentCount = (await Promise.all(results)).filter(Boolean).length;
      return new Response(
        JSON.stringify({ ok: true, sent: sentCount, type: "sos" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Handle Device Command INSERT (Fase 2: Remote Commands) ──
    if (payload.table === "device_commands") {
      const cmd = payload.record as Record<string, unknown>;
      const targetProfileId = cmd.target_profile_id as string;
      const targetDeviceId = (cmd.target_device_id as string | null) || null;
      const commandType = cmd.command_type as string;
      const commandId = cmd.id as string;
      const cmdPayload = cmd.payload ? JSON.stringify(cmd.payload) : "{}";

      const targetTokens = await getUserDeviceTokens(
        supabaseClient,
        targetProfileId,
        targetDeviceId,
      );

      if (targetTokens.length === 0) {
        return new Response(
          JSON.stringify({ ok: true, reason: "no_fcm_token" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const messaging = getMessaging(getFirebaseApp());
      const results = [];

      for (const dt of targetTokens) {
        results.push(
          messaging.send({
            token: dt.token,
            // DATA-ONLY message untuk remote command
            data: {
              type: "device_command",
              commandId: commandId,
              commandType: commandType,
              payload: cmdPayload,
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  "content-available": 1,
                },
              },
            },
          }).catch(async (e: unknown) => {
            console.warn(
              `FCM device_command send failed (user ${targetProfileId}, device ${dt.deviceId ?? "unknown"}):`,
              String(e),
            );
            if (isInvalidTokenError(e)) {
              await clearFcmToken(supabaseClient, targetProfileId, dt.deviceId);
            }
            return null;
          }),
        );
      }

      const sentCount = (await Promise.all(results)).filter(Boolean).length;
      return new Response(
        JSON.stringify({ ok: true, sent: sentCount, type: "device_command" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Tabel lain, skip
    return new Response(JSON.stringify({ ok: true, skipped: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
