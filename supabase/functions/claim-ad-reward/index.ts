// --- START: CORRECTED SUPERBASE FUNCTION CODE ---
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ONE_HOUR_MS = 60 * 60 * 1000;
const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;

serve(async (req) => {
  // This is needed if you're deploying functions from a browser.
  // This is not required if you're deploying from the CLI.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { rewardType } = await req.json();

    if (!['like', 'scroll', 'ghost'].includes(rewardType)) {
      return new Response(JSON.stringify({ error: "Invalid reward type" }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "User not found" }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      });
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('like_count, last_ad_like_at, last_ad_scroll_at, last_ad_ghost_at')
      .eq('id', user.id)
      .single();

    if (profileError) throw profileError;

    const now = new Date();
    const lastClaimedAtField = `last_ad_${rewardType}_at`;
    const lastClaimedDate = profile[lastClaimedAtField] ? new Date(profile[lastClaimedAtField]) : null;

    if (lastClaimedDate && (now.getTime() - lastClaimedDate.getTime()) < TWENTY_FOUR_HOURS_MS) {
      return new Response(JSON.stringify({ error: "Reward already claimed within the last 24 hours" }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 429,
      });
    }

    const updates: { [key: string]: any } = {
      [lastClaimedAtField]: now.toISOString()
    };

    if (rewardType === 'like') {
      updates.like_count = (profile.like_count || 0) + 1;
    } else if (rewardType === 'scroll') {
      updates.infinite_scroll_until = new Date(now.getTime() + ONE_HOUR_MS).toISOString();
    } else if (rewardType === 'ghost') { // ***<- THE TYPO WAS HERE. IT IS NOW FIXED.***
      updates.ghost_mode_until = new Date(now.getTime() + ONE_HOUR_MS).toISOString();
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.id);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
// --- END: CORRECTED SUPERBASE FUNCTION CODE ---