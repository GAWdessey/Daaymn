import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const TIER_BENEFITS = {
  'daaymn_sub_standard_monthly_p': { likes: 60, tier: 'Standard', reportTier: 'Basic' },
  'daaymn_sub_pro_monthly_p':      { likes: 120, tier: 'Pro', reportTier: 'Pro' },
  'daaymn_sub_deluxe_monthly_p':   { likes: 240, tier: 'Deluxe', reportTier: 'Deluxe' },
};

export async function grantSubscriptionBenefits(
  supabaseAdmin: SupabaseClient,
  userId: string,
  productId: string,
  expiryTimeMillis: string,
  transactionId: string, // The Google purchase token
  obfuscatedExternalAccountId?: string, // New optional parameter
) {
  const benefits = TIER_BENEFITS[productId];
  if (!benefits) {
    throw new Error(`Unknown subscription product ID: ${productId}`);
  }

  const { data: profile, error: fetchError } = await supabaseAdmin
    .from('profiles')
    .select('like_count')
    .eq('id', userId)
    .single();

  if (fetchError) {
    throw new Error(`Failed to fetch user profile (${userId}): ${fetchError.message}`);
  }

  const expiryISO = new Date(parseInt(expiryTimeMillis, 10)).toISOString();

  const updates: any = { // Use 'any' to allow for conditional properties
    subscription_tier: benefits.tier,
    subscription_expires_at: expiryISO,
    infinite_scroll_until: expiryISO,
    ghost_mode_until: expiryISO,
    like_count: (profile.like_count || 0) + benefits.likes,
    monthly_report_credit_tier: benefits.reportTier,
    has_claimed_monthly_report: false, // Always reset the report claim on new purchase or renewal
    store_transaction_id: transactionId, // Store the Google token as the transaction ID
  };

  // Only add the obfuscated ID if it's provided. This happens on initial purchase.
  if (obfuscatedExternalAccountId) {
    updates.obfuscated_external_account_id = obfuscatedExternalAccountId;
  }

  const { error: updateError } = await supabaseAdmin
    .from('profiles')
    .update(updates)
    .eq('id', userId);

  if (updateError) {
    throw new Error(`Failed to apply subscription benefits for user ${userId}: ${updateError.message}`);
  }

  console.log(`Successfully granted benefits for ${productId} to user ${userId}`);
}
