import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { reportTier } = await req.json();
    if (!reportTier || !['basic', 'pro', 'deluxe'].includes(reportTier)) {
      throw new Error('A valid reportTier (basic, pro, deluxe) is required.');
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: { user } } = await createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    ).auth.getUser();

    if (!user) throw new Error('Authentication required');

    // Get the current profile to safely update the JSONB credits
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('one_time_report_credits')
      .eq('id', user.id)
      .single();

    if (profileError) throw profileError;

    // Safely increment the credit for the purchased tier
    const credits = profile.one_time_report_credits || {};
    credits[reportTier] = (credits[reportTier] || 0) + 1;

    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({ one_time_report_credits: credits })
      .eq('id', user.id);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({ message: `Report credit '${reportTier}' granted successfully.` }), {
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