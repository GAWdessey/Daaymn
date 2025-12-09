import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const twentyFourHoursInMs = 24 * 60 * 60 * 1000;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );
    const { data: { user } } = await createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    ).auth.getUser();

    if (!user) throw new Error('Authentication required');

    const { data: profile, error: profileError } = await supabaseAdmin
        .from('profiles')
        .select('last_ad_scroll_at')
        .eq('id', user.id)
        .single();

    if (profileError) throw profileError;

    const now = new Date();
    const lastClaimed = profile.last_ad_scroll_at ? new Date(profile.last_ad_scroll_at) : null;

    if (lastClaimed && (now.getTime() - lastClaimed.getTime()) < twentyFourHoursInMs) {
        return new Response(JSON.stringify({ error: 'You can only claim this reward once per day.' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 429,
        });
    }

    const expirationTime = new Date(Date.now() + 60 * 60 * 1000).toISOString();

    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        infinite_scroll_until: expirationTime,
        last_ad_scroll_at: now.toUTCString(),
      })
      .eq('id', user.id);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({ message: 'Infinite scroll activated for one hour.' }), {
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