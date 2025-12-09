import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4'
import { getAuthToken } from '../_shared/fcm.ts'

const FIREBASE_PROJECT_ID = 'daaymn-notifications'
const NOTIFICATION_CHANNEL_ID = 'daaymn_channel'

serve(async (req) => {
  try {
    const { record } = await req.json()

    console.log('New match record:', record);

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: block } = await supabaseAdmin
      .from('blocks')
      .select('blocker_id')
      .or(`(blocker_id.eq.${record.user_id_1},blocked_id.eq.${record.user_id_2}),(blocker_id.eq.${record.user_id_2},blocked_id.eq.${record.user_id_1})`)
      .limit(1);

    if (block && block.length > 0) {
      console.log('Match notification blocked:', { user1: record.user_id_1, user2: record.user_id_2 });
      return new Response(JSON.stringify({ success: true, message: 'Match notification blocked' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    const [{ data: user1 }, { data: user2 }] = await Promise.all([
      supabaseAdmin.from('profiles').select('id, name, fcm_token').eq('id', record.user_id_1).single(),
      supabaseAdmin.from('profiles').select('id, name, fcm_token').eq('id', record.user_id_2).single(),
    ])

    if (!user1 || !user2) {
      console.error("Couldn't find one or both users for the match.", { user_id_1: record.user_id_1, user_id_2: record.user_id_2 });
      return new Response(JSON.stringify({ success: false, error: "User not found" }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    const notifications = [];
    const accessToken = await getAuthToken();

    const createPayload = (recipientToken, otherUserName, otherUserId) => ({
      token: recipientToken,
      notification: {
        title: 'You have a new match!',
        body: `You matched with ${otherUserName}. Go say hi!`,
      },
      data: {
        'initial_route': '/matches',
        'other_user_id': otherUserId,
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: NOTIFICATION_CHANNEL_ID,
        },
      },
    });

    if (user1.fcm_token) {
      notifications.push(createPayload(user1.fcm_token, user2.name, user2.id));
    } else {
        console.log(`User ${user1.id} has no FCM token.`);
    }

    if (user2.fcm_token) {
      notifications.push(createPayload(user2.fcm_token, user1.name, user1.id));
    } else {
        console.log(`User ${user2.id} has no FCM token.`);
    }

    if (notifications.length > 0) {
      const sendPromises = notifications.map(async (notif) => {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ message: notif }),
        });

        if (!res.ok) {
            const errorBody = await res.text();
            console.error(`FCM send failed for token ${notif.token}: ${res.status}`, errorBody);
        } else {
            console.log(`FCM message sent successfully to token ${notif.token}`);
        }

        return res;
      });
      
      await Promise.all(sendPromises);
    }

  } catch (e) {
    console.error('Error sending match notification:', e.stack || e.message);
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  });
});