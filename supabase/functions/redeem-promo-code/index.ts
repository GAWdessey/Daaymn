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

  // Create a Supabase client with the user's authorization
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  );

  try {
    // Call the secure database function
    const { data, error } = await supabase.rpc('redeem_code_atomic', { p_code: code });

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
