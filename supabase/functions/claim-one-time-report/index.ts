
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing required environment variables.");
}

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Authenticate the user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing Authorization' }), { status: 401, headers: corsHeaders });
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Authentication failed' }), { status: 401, headers: corsHeaders });
    }

    // 2. Get the report tier from the request body
    const { tier } = await req.json();
    if (!tier) {
      return new Response(JSON.stringify({ error: 'Request must include a report tier' }), { status: 400, headers: corsHeaders });
    }

    // 3. Call the database function to use one credit
    const { data: decrementSuccess, error: decrementError } = await supabaseAdmin.rpc('decrement_report_credit', {
      user_id_in: user.id,
      tier_in: tier,
    });

    if (decrementError) {
        throw new Error(`Failed to decrement credits: ${decrementError.message}`);
    }
    
    if (!decrementSuccess) {
      return new Response(JSON.stringify({ error: 'No report credits available for this tier.' }), { status: 400, headers: corsHeaders });
    }

    // 4. Success! Return the tier that was claimed.
    // The app will use this to generate the report view.
    return new Response(JSON.stringify({ claimedTier: tier }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
  }
});
