
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { google } from "npm:googleapis@105";
import { corsHeaders } from "../_shared/cors.ts";
import { grantSubscriptionBenefits } from "../_shared/grant-benefits.ts";

// --- Environment Variable Validation ---
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const GOOGLE_SERVICE_ACCOUNT_KEY_JSON = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_KEY');
const ANDROID_PACKAGE_NAME = Deno.env.get('ANDROID_PACKAGE_NAME');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !GOOGLE_SERVICE_ACCOUNT_KEY_JSON || !ANDROID_PACKAGE_NAME) {
  throw new Error("Missing one or more required environment variables.");
}

// --- Product Definitions ---
const PRODUCT_IDS = {
  LIKE_1: 'daaymn_like_1_p',
  LIKE_10: 'daaymn_like_10_p',
  LIKE_20: 'daaymn_like_20_p',
  UNLOCK_VISIBILITY: 'daaymn_unlock_visibility_d',
  UNLOCK_SCROLLING: 'daaymn_unlock_scrolling_d',
  REPORT_BASIC: 'daaymn_report_basic_p',
  REPORT_PRO: 'daaymn_report_pro_p',
  REPORT_DELUXE: 'daaymn_report_deluxe_p',
  SUB_STANDARD: 'daaymn_sub_standard_monthly_p',
  SUB_PRO: 'daaymn_sub_pro_monthly_p',
  SUB_DELUXE: 'daaymn_sub_deluxe_monthly_p',
};

const LIKES_MAP = {
  [PRODUCT_IDS.LIKE_1]: 1,
  [PRODUCT_IDS.LIKE_10]: 11,
  [PRODUCT_IDS.LIKE_20]: 22,
};

const REPORT_TIER_MAP = {
    [PRODUCT_IDS.REPORT_BASIC]: 'basic',
    [PRODUCT_IDS.REPORT_PRO]: 'pro',
    [PRODUCT_IDS.REPORT_DELUXE]: 'deluxe',
}

const ONE_TIME_REPORT_IDS = new Set(Object.keys(REPORT_TIER_MAP));

const SUBSCRIPTION_IDS = new Set([
  PRODUCT_IDS.SUB_STANDARD,
  PRODUCT_IDS.SUB_PRO,
  PRODUCT_IDS.SUB_DELUXE,
]);

function getServiceAccountKey() {
  try {
    const key = JSON.parse(GOOGLE_SERVICE_ACCOUNT_KEY_JSON!);
    key.private_key = key.private_key.replace(/\\n/g, '\n');
    return key;
  } catch (error) {
    throw new Error("Failed to parse GOOGLE_SERVICE_ACCOUNT_KEY JSON: " + error.message);
  }
}

const serviceAccountKey = getServiceAccountKey();
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('Verifying Google purchase...');
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      console.error('Missing or invalid Authorization header');
      return new Response(JSON.stringify({ error: 'Missing Authorization' }), { status: 401, headers: corsHeaders });
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      console.error('Authentication failed:', userError);
      return new Response(JSON.stringify({ error: 'Authentication failed' }), { status: 401, headers: corsHeaders });
    }

    const { productId, token: purchaseToken } = await req.json();
    console.log(`Received verification request for productId: ${productId}, user: ${user.id}`);
    if (!productId || !purchaseToken) {
      console.error('Missing productId or purchaseToken in request body');
      return new Response(JSON.stringify({ error: 'Missing productId or token' }), { status: 400, headers: corsHeaders });
    }

    const jwt = new google.auth.JWT(serviceAccountKey.client_email, undefined, serviceAccountKey.private_key, ['https://www.googleapis.com/auth/androidpublisher']);
    const androidPublisher = google.androidpublisher({ version: 'v3', auth: jwt });

    let isValid = false;
    const isSubscription = SUBSCRIPTION_IDS.has(productId);
    console.log(`Product ID: ${productId}, Is Subscription: ${isSubscription}`);

    if (isSubscription) {
      console.log('Verifying subscription...');
      const verification = await androidPublisher.purchases.subscriptions.get({ packageName: ANDROID_PACKAGE_NAME, subscriptionId: productId, token: purchaseToken });
      console.log('Google API subscription response:', verification);
      const expiryTimeMillis = verification.data.expiryTimeMillis;
      if (verification.status === 200 && expiryTimeMillis && parseInt(expiryTimeMillis, 10) > Date.now()) {
        isValid = true;
        console.log('Subscription is valid.');
        if (verification.data.acknowledgementState !== 1) {
          console.log('Acknowledging subscription...');
          await androidPublisher.purchases.subscriptions.acknowledge({ packageName: ANDROID_PACKAGE_NAME, subscriptionId: productId, token: purchaseToken });
        }
        await grantSubscriptionBenefits(supabaseAdmin, user.id, productId, expiryTimeMillis!, purchaseToken);
      } else {
        console.error('Subscription verification failed:', verification);
      }
    } else { // One-time product
      console.log('Verifying one-time product...');
      const verification = await androidPublisher.purchases.products.get({ packageName: ANDROID_PACKAGE_NAME, productId: productId, token: purchaseToken });
      console.log('Google API product response:', verification);
      if (verification.status === 200 && verification.data.purchaseState === 0) {
        isValid = true;
        console.log('One-time product is valid.');
        if (verification.data.acknowledgementState !== 1) {
          console.log('Acknowledging one-time product...');
          await androidPublisher.purchases.products.acknowledge({ packageName: ANDROID_PACKAGE_NAME, token: purchaseToken, productId: productId });
        }

        // --- Granting Benefits for One-Time Products ---
        const likesToAdd = LIKES_MAP[productId];
        const reportTier = REPORT_TIER_MAP[productId];
        console.log(`Likes to add: ${likesToAdd}, Report tier: ${reportTier}`);

        if (likesToAdd) {
          console.log(`Granting ${likesToAdd} likes to user ${user.id}`);
          const { error: rpcError } = await supabaseAdmin.rpc('grant_likes', { user_id: user.id, num_likes: likesToAdd });
          if (rpcError) throw rpcError;
        } else if (reportTier) {
          console.log(`Incrementing report credit for user ${user.id} with tier ${reportTier}`);
          const { error: rpcError } = await supabaseAdmin.rpc('increment_report_credit', { user_id_in: user.id, tier_in: reportTier });
          if (rpcError) throw new Error(`Failed to grant report credit: ${rpcError.message}`);
        } else {
           const updates: { [key: string]: string } = {};
           const unlockExpiry = new Date(Date.now() + (365 * 10 * 24 * 60 * 60 * 1000));
           if (productId === PRODUCT_IDS.UNLOCK_VISIBILITY) {
             updates.ghost_mode_until = unlockExpiry.toISOString();
           } else if (productId === PRODUCT_IDS.UNLOCK_SCROLLING) {
             updates.infinite_scroll_until = unlockExpiry.toISOString();
           }
           if (Object.keys(updates).length > 0) {
            console.log(`Updating profile for user ${user.id} with:`, updates);
             const { error: updateError } = await supabaseAdmin.from('profiles').update(updates).eq('id', user.id);
             if (updateError) throw updateError;
           }
        }
      } else {
        console.error('One-time product verification failed:', verification);
      }
    }

    if (!isValid) {
      console.error('Purchase could not be verified.');
      return new Response(JSON.stringify({ error: 'Purchase could not be verified' }), { status: 400, headers: corsHeaders });
    }

    console.log('Purchase verified successfully.');
    return new Response(JSON.stringify({ message: `Purchase verified: ${productId}` }), { status: 200, headers: corsHeaders });

  } catch (error) {
    console.error('An unexpected error occurred:', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
  }
});
