import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  // This is needed to handle the preflight OPTION request from the browser.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Create a Supabase client with the user's authorization.
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    // 1. Get the current user from their auth token.
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      console.error('Auth Error:', userError?.message);
      return new Response(JSON.stringify({ error: 'Authentication failed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      });
    }

    // 2. Check if the user is a seed profile by querying the profiles table.
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('is_seed_profile')
      .eq('id', user.id)
      .single();

    if (profileError) {
      console.error('Profile fetch error:', profileError.message);
      return new Response(JSON.stringify({ error: 'Could not retrieve user profile' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    // 3. **CRITICAL SECURITY CHECK**
    // If the user is a seed profile, block them from casting a vote.
    if (profile.is_seed_profile) {
      return new Response(JSON.stringify({ error: 'Action not allowed for this profile type.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403, // 403 Forbidden is the correct status code here.
      });
    }

    // --- If the user is real, proceed with the original logic ---

    const { option_id } = await req.json();

    // Call the database function we created earlier.
    const { error } = await supabaseClient.rpc('cast_vote', {
      poll_option_id: option_id,
    });

    if (error) {
      console.error('RPC Error:', error.message);
      return new Response(JSON.stringify({ error: error.message }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    return new Response(JSON.stringify({ message: 'Vote processed' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (err) {
    // This will catch errors from req.json() if the body is invalid.
    console.error('Catch Error:', err.message);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
