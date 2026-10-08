import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.2'

serve(async (req) => {
  const { code } = await req.json();

  if (!code) {
    return new Response(
      JSON.stringify({ error: 'Promo code is required.' }),
      { headers: { "Content-Type": "application/json" }, status: 400 },
    );
  }

  // The user's client only identifies the caller; the redemption itself runs as
  // the service role, since redeem_promo_code isn't callable by clients.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  );
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return new Response(
      JSON.stringify({ error: 'User not authenticated.' }),
      { headers: { "Content-Type": "application/json" }, status: 401 },
    );
  }

  try {
    // Counts the use and records a redemption grant-promo-item can claim
    const { data, error } = await supabaseAdmin.rpc('redeem_promo_code', { p_code: code, p_user_id: user.id });

    if (error) {
      // The RPC function itself threw an unexpected error
      throw new Error(error.message);
    }

    // The RPC function returns an array with one object.
    const result = data[0];

    if (result.error_message) {
      // The function returned a controlled error (e.g., code expired, not found)
      return new Response(
        JSON.stringify({ error: result.error_message }),
        { headers: { "Content-Type": "application/json" }, status: 400 },
      );
    }

    // Success! Return the product ID to the client
    return new Response(
      JSON.stringify({ productId: result.product_id }),
      { headers: { "Content-Type": "application/json" }, status: 200 },
    );

  } catch (error) {
    // This catches unexpected errors from the RPC call itself
    return new Response(
      JSON.stringify({ error: 'An unexpected error occurred while redeeming the code.', details: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 500 },
    );
  }
});
