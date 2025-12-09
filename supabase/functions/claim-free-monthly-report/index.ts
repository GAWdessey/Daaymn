import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';const calculateUserScore = async (supabase: any, userId: string): Promise<number | null> => {
  console.log(`Calculating score for user: ${userId}`);
  const { data, error } = await supabase.rpc('calculate_daaymn_score', { user_id_param: userId });
  if (error) {
    console.error(`Error from calculate_daaymn_score RPC for user ${userId}:`, error);
    return null;
  }
  // The RPC can also return null data without an error
  if (data == null) {
    console.error(`calculate_daaymn_score RPC returned null data for user ${userId}.`);
    return null;
  }
  return data;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      {
        global: { headers: { Authorization: req.headers.get('Authorization')! } },
      }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ message: 'Authentication required.' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('last_free_report_claimed_at')
      .eq('id', user.id)
      .single();

    if (profileError) {
      return new Response(JSON.stringify({ message: `Profile query failed: ${profileError.message}` }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const lastClaim = profile?.last_free_report_claimed_at;
    if (lastClaim) {
      const nextClaimDate = new Date(new Date(lastClaim).setMonth(new Date(lastClaim).getMonth() + 1));
      if (new Date() < nextClaimDate) {
        const friendlyDate = nextClaimDate.toLocaleString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        return new Response(JSON.stringify({ message: `Your next free report is available on ${friendlyDate}.` }), { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
    }

    // --- MORE ROBUST LOGIC ---
    const currentScore = await calculateUserScore(supabase, user.id);

    // If score calculation fails for any reason, return a clear 500 error.
    if (currentScore == null) {
      return new Response(JSON.stringify({ message: 'Could not calculate a valid score for your profile at this time.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }
    // --- END ROBUST LOGIC ---

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        last_free_report_claimed_at: new Date().toISOString(),
        last_claimed_score: currentScore
      })
      .eq('id', user.id);

    if (updateError) {
      return new Response(JSON.stringify({ message: `Failed to update profile: ${updateError.message}` }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ claimedScore: currentScore }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (e) {
    // This is a final catch-all for any other unexpected errors.
    return new Response(JSON.stringify({ message: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});