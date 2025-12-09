import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4'
import { getAuthToken } from '../_shared/fcm.ts'

const FIREBASE_PROJECT_ID = 'daaymn-notifications'
const NOTIFICATION_CHANNEL_ID = 'daaymn_channel'

serve(async (req) => {
  try {
    const { record } = await req.json();

    // Use the service role key for admin-level access
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Verify the sender is not blocked and the recipient exists
    const {
      data: recipient,
      error: recipientError
    } = await supabaseAdmin.from('profiles').select('id, fcm_token').eq('id', record.receiver_id).single();
    
    if (recipientError || !recipient) {
        console.error('Recipient not found or error:', recipientError?.message);
        // Fail silently to the client, but log it.
        return new Response(JSON.stringify({ success: true }), { status: 200 }); 
    }

    const {
      data: sender,
      error: senderError
    } = await supabaseAdmin.from('profiles').select('id, name').eq('id', record.sender_id).single();

    if (senderError || !sender) {
        console.error('Sender not found or error:', senderError?.message);
        return new Response(JSON.stringify({ success: true }), { status: 200 });
    }

    // Check if either user has blocked the other
    const { data: block } = await supabaseAdmin
      .from('blocks')
      .select('blocker_id')
      .or(`(blocker_id.eq.${record.receiver_id},blocked_id.eq.${record.sender_id}),(blocker_id.eq.${record.sender_id},blocked_id.eq.${record.receiver_id})`)
      .limit(1);

    if (block && block.length > 0) {
      console.log('Message blocked:', { sender: record.sender_id, receiver: record.receiver_id });
      return new Response(JSON.stringify({ success: true, message: 'Message blocked' }), { status: 200 });
    }

    // If recipient has a token, send the notification
    if (recipient.fcm_token) {
        const accessToken = await getAuthToken();

        // The body here is generic because it will be decrypted on the device if the app is in the foreground
        const body = 'You have a new message';

        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: recipient.fcm_token,
              notification: {
                title: `New message from ${sender.name}`,
                body: body,
              },
              data: {
                'initial_route': '/chat',
                'other_user_id': record.sender_id,
                'content': record.content, // Pass the encrypted content for foreground decryption
              },
              android: {
                priority: 'high',
                notification: {
                    channel_id: NOTIFICATION_CHANNEL_ID,
                },
              },
            },
          }),
        });

        if (res.ok) {
          console.log(`FCM message sent successfully to token ${recipient.fcm_token}`);
        } else {
          const errorBody = await res.text();
          console.error(`FCM send failed: ${res.status}`, errorBody);
        }
    } else {
        console.log(`Recipient ${recipient.id} does not have an FCM token.`);
    }

  } catch (e) {
    console.error('Internal Server Error:', e.stack || e.message);
  }

  // Always return a success response to the client to avoid retry loops.
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  });
});