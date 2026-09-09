// supabase/functions/send-push/index.ts
//
// हे function Database Webhook द्वारे ट्रिगर होतं (messages table वर नवीन INSERT झाला की).
// काम: त्या conversation च्या बाकी सभासदांना (पाठवणारा सोडून, mute नसलेल्यांना) push notification पाठवणं.
//
// डिप्लॉय करण्याआधी सूचना README.md मध्ये आहेत — VAPID keys generate करणं आणि
// environment variables सेट करणं आवश्यक आहे.

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!;

webpush.setVapidDetails("mailto:admin@example.com", VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const msg = payload.record; // Database Webhook पेलोडमधला नवीन मेसेज रो

    if (!msg || !msg.conversation_id || !msg.sender_id) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    // पाठवणाऱ्याचं नाव आणि conversation चं नाव/type आणतो
    const { data: sender } = await supabase.from("profiles").select("username").eq("id", msg.sender_id).single();
    const { data: conv } = await supabase.from("conversations").select("type, name").eq("id", msg.conversation_id).single();

    // या conversation चे बाकी सभासद (पाठवणारा सोडून, mute नसलेले) शोधतो
    const { data: members } = await supabase
      .from("conversation_members")
      .select("user_id, muted")
      .eq("conversation_id", msg.conversation_id)
      .neq("user_id", msg.sender_id);

    const recipientIds = (members || []).filter((m) => !m.muted).map((m) => m.user_id);
    if (!recipientIds.length) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

    const { data: subs } = await supabase
      .from("push_subscriptions")
      .select("*")
      .in("user_id", recipientIds);

    const title = conv?.type === "direct" ? `@${sender?.username || "कोणीतरी"}` : (conv?.name || "नवीन मेसेज");
    const body = msg.media_type
      ? (msg.media_type === "image" ? "📷 फोटो" : msg.media_type === "audio" ? "🎤 Voice message" : "📎 फाईल")
      : (msg.content || "नवीन मेसेज");

    let sent = 0;
    for (const sub of subs || []) {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth_key } },
          JSON.stringify({ title, body, conversationId: msg.conversation_id })
        );
        sent++;
      } catch (err) {
        // subscription जुनी/invalid असेल तर काढून टाकतो
        if (err.statusCode === 410 || err.statusCode === 404) {
          await supabase.from("push_subscriptions").delete().eq("id", sub.id);
        }
      }
    }

    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
