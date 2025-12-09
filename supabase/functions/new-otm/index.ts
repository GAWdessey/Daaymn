
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";
import { sendFcm } from "../_shared/fcm.ts";

// Initialize Supabase admin client using the non-reserved secret names
const supabaseAdmin = createClient(
  Deno.env.get("DAAYMN_SUPABASE_URL") ?? "",
  Deno.env.get("DAAYMN_SERVICE_ROLE_KEY") ?? ""
);

serve(async (req) => {
  try {
    // The trigger sends the raw record as the JSON body.
    // This is the line I got wrong before.
    const otm = await req.json();

    if (!otm || !otm.receiver_id || !otm.sender_id) {
      console.warn("Invalid OTM payload received:", otm);
      return new Response(JSON.stringify({ message: "Invalid payload" }), {
        headers: { "Content-Type": "application/json" },
        status: 400,
      });
    }

    console.log(`Processing OTM from ${otm.sender_id} to ${otm.receiver_id}`);

    // Get sender's name
    const { data: senderProfile, error: senderError } = await supabaseAdmin
      .from("profiles")
      .select("name")
      .eq("id", otm.sender_id)
      .single();

    if (senderError) throw new Error(`Sender profile not found: ${senderError.message}`);
    if (!senderProfile) throw new Error("Sender profile not found");

    // Get receiver's FCM tokens
    const { data: tokens, error: tokensError } = await supabaseAdmin
      .from("fcm_tokens")
      .select("token")
      .eq("user_id", otm.receiver_id);

    if (tokensError) throw new Error(`Error fetching FCM tokens: ${tokensError.message}`);

    if (tokens && tokens.length > 0) {
      const fcmTokens = tokens.map((t) => t.token);
      const notificationPayload = {
        notification: {
          title: `New One-Time Message from ${senderProfile.name}!`,
          body: "Someone spent their Daaymn likes to message you. Check it out!",
        },
        data: {
          type: "otm",
          sender_id: otm.sender_id,
        },
      };

      console.log(`Sending OTM notification to ${fcmTokens.length} devices.`);
      await sendFcm(fcmTokens, notificationPayload);
      console.log("FCM notification sent successfully.");
    } else {
      console.log(`No FCM tokens found for user ${otm.receiver_id}.`);
    }

    return new Response(JSON.stringify({ message: "Notification processed." }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (e) {
    console.error("CRITICAL ERROR in new-otm function:", e.message);
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
