import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
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

    // Get the user's profile to verify their credit
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('subscription_expires_at, monthly_report_credit_tier, has_claimed_monthly_report')
      .eq('id', user.id)
      .single();

    if (profileError) throw profileError;

    // --- Validation Checks ---
    if (!profile.subscription_expires_at || new Date(profile.subscription_expires_at) < new Date()) {
      throw new Error('No active subscription found.');
    }
    if (profile.has_claimed_monthly_report) {
      throw new Error('Monthly report has already been claimed.');
    }
    if (!profile.monthly_report_credit_tier) {
      throw new Error('No report credit available for this subscription tier.');
    }

    // --- Mark the report as claimed ---
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({ has_claimed_monthly_report: true })
      .eq('id', user.id);

    if (updateError) throw updateError;

    // Return the tier of the report that was claimed
    return new Response(JSON.stringify({ claimedTier: profile.monthly_report_credit_tier }), {
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