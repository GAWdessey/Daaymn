import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.2'

// --- Product Definitions ---
const PRODUCT_IDS = {
  LIKE_1: 'daaymn_like_1_p',
  LIKE_10: 'daaymn_like_10_p',
  LIKE_20: 'daaymn_like_20_p',
  REPORT_BASIC: 'daaymn_report_basic_p',
  REPORT_PRO: 'daaymn_report_pro_p',
  REPORT_DELUXE: 'daaymn_report_deluxe_p',
};

const LIKES_MAP = {
  [PRODUCT_IDS.LIKE_1]: 1,
  [PRODUCT_IDS.LIKE_10]: 10,
  [PRODUCT_IDS.LIKE_20]: 20,
};

const REPORT_TIER_MAP = {
    [PRODUCT_IDS.REPORT_BASIC]: 'basic',
    [PRODUCT_IDS.REPORT_PRO]: 'pro',
    [PRODUCT_IDS.REPORT_DELUXE]: 'deluxe',
}

serve(async (req) => {
  const { productId } = await req.json();

  if (!productId) {
    return new Response(
      JSON.stringify({ error: 'Product ID is required.' }),
      { headers: { "Content-Type": "application/json" }, status: 400 },
    );
  }

  // Initialize Supabase client
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  );

  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return new Response(
      JSON.stringify({ error: 'User not authenticated.' }),
      { headers: { "Content-Type": "application/json" }, status: 401 },
    );
  }

  try {
    const likesToAdd = LIKES_MAP[productId];
    const reportTier = REPORT_TIER_MAP[productId];

    if (likesToAdd) {
      const { error } = await supabase.rpc('grant_likes', { 
        user_id: user.id, 
        num_likes: likesToAdd
      });
      if (error) throw new Error(`Failed to grant likes: ${error.message}`);
    } else if (reportTier) {
      const { error } = await supabase.rpc('increment_report_credit', { 
        user_id_in: user.id, 
        tier_in: reportTier 
      });
      if (error) throw new Error(`Failed to grant report credit: ${error.message}`);
    } else {
      // Handle other promo types here if needed in the future
      console.warn(`No action defined for promo product ID: ${productId}`);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" }, status: 200 },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Failed to grant promo item.', details: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 500 },
    );
  }
})
