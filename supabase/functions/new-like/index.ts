import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4'
import { getAuthToken } from '../_shared/fcm.ts'

const FIREBASE_PROJECT_ID = 'daaymn-notifications'
const NOTIFICATION_CHANNEL_ID = 'daaymn_channel'

serve(async (req) => {
  try {
    const { record: newLike } = await req.json()
    console.log('New like received:', newLike)

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Check for blocking between the two users with the CORRECTED syntax.
    const { data: block, error: blockError } = await supabaseAdmin
      .from('blocks')
      .select('blocker_id')
      .or(
        `and(blocker_id.eq.${newLike.user_id},blocked_id.eq.${newLike.liked_user_id}),and(blocker_id.eq.${newLike.liked_user_id},blocked_id.eq.${newLike.user_id})`
      )
      .limit(1)

    if (blockError) {
      console.error('Error checking for blocks:', blockError.message)
      return new Response(JSON.stringify({ success: false, error: blockError.message }), { status: 500 })
    }
    if (block && block.length > 0) {
      console.log('Notification blocked due to a block record between users.')
      return new Response(JSON.stringify({ success: true, message: 'Like is blocked' }), { status: 200 })
    }

    // 2. Fetch profiles for both users involved.
    const { data: profiles, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id, name, fcm_token')
      .in('id', [newLike.user_id, newLike.liked_user_id])

    if (profileError) {
      console.error('Error fetching profiles:', profileError.message)
      return new Response(JSON.stringify({ success: false, error: profileError.message }), { status: 500 })
    }
    if (!profiles || profiles.length < 2) {
      console.error('Could not find one or both user profiles.')
      return new Response(JSON.stringify({ success: false, error: 'User profiles not found' }), { status: 404 })
    }

    const userA = profiles.find(p => p.id === newLike.user_id)
    const userB = profiles.find(p => p.id === newLike.liked_user_id)

    // 3. Check for a mutual match.
    const { data: mutualLike, error: mutualLikeError } = await supabaseAdmin
      .from('likes')
      .select('id')
      .eq('user_id', newLike.liked_user_id)
      .eq('liked_user_id', newLike.user_id)
      .limit(1)

    if (mutualLikeError) {
      console.error('Error checking for mutual like:', mutualLikeError.message)
    }

    const accessToken = await getAuthToken()
    const notifications = []
    const isMatch = mutualLike && mutualLike.length > 0

    if (isMatch) {
      // It's a MATCH! Notify both users.
      console.log(`Match detected between ${userA!.name} and ${userB!.name}`)
      if (userA!.fcm_token) {
        notifications.push({
          token: userA!.fcm_token,
          notification: {
            title: `It's a Match!`,
            body: `You and ${userB!.name} have liked each other.`,
          },
          data: { initial_route: '/matches', other_user_id: userB!.id },
          android: { priority: 'high', notification: { channel_id: NOTIFICATION_CHANNEL_ID } },
        })
      }
      if (userB!.fcm_token) {
        notifications.push({
          token: userB!.fcm_token,
          notification: {
            title: `It's a Match!`,
            body: `You and ${userA!.name} have liked each other.`,
          },
          data: { initial_route: '/matches', other_user_id: userA!.id },
          android: { priority: 'high', notification: { channel_id: NOTIFICATION_CHANNEL_ID } },
        })
      }
    } else {
      // It's a one-way LIKE. Notify only the liked user.
      console.log(`${userA!.name} liked ${userB!.name}. Sending one-way notification.`)
      if (userB!.fcm_token) {
        notifications.push({
          token: userB!.fcm_token,
          notification: {
            title: 'You have a new like!',
            body: `${userA!.name} liked your profile.`,
          },
          data: { initial_route: '/likes' },
          android: { priority: 'high', notification: { channel_id: NOTIFICATION_CHANNEL_ID } },
        })
      }
    }

    // 4. Send notifications.
    if (notifications.length > 0) {
      for (const notif of notifications) {
        console.log(`Sending notification to token: ${notif.token}`)
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ message: notif }),
        })
        if (!res.ok) {
          const errorBody = await res.text()
          console.error(`FCM send failed for token ${notif.token}: ${res.status}`, errorBody)
        } else {
          console.log(`FCM message sent successfully to token ${notif.token}`)
        }
      }
    } else {
      console.log('No notifications to send.')
    }

    return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' }, status: 200 })
  } catch (e) {
    console.error('CRITICAL: Unhandled error in new-like function:', e.stack || e.message)
    return new Response(JSON.stringify({ success: false, error: e.message }), { status: 500 })
  }
})