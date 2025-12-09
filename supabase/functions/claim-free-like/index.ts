import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const twentyFourHoursInMs = 24 * 60 * 60 * 1000;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Use the service role key to securely update user data
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Get the user from the request's authorization header
    const { data: { user } } = await createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    ).auth.getUser();

    if (!user) throw new Error('Authentication required');

    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('like_count, last_ad_like_at')
      .eq('id', user.id)
      .single();

    if (profileError) throw profileError;

    const now = new Date();
    const lastClaimed = profile.last_ad_like_at ? new Date(profile.last_ad_like_at) : null;

    // Check if the user has claimed this reward in the last 24 hours
    if (lastClaimed && (now.getTime() - lastClaimed.getTime()) < twentyFourHoursInMs) {
        return new Response(JSON.stringify({ error: 'You can only claim one free like per day.' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 429, // Too Many Requests
        });
    }

    // Grant the like and update the timestamp
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        like_count: (profile.like_count || 0) + 1,
        last_ad_like_at: now.toUTCString(),
      })
      .eq('id', user.id);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({ message: 'One free like has been added to your account.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})