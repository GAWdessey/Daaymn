import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type ClaimResult = 'claimed' | 'already_claimed' | 'claimed_by_other';

// Records a purchase token (per billing period for subscriptions) in
// purchase_tokens. Only a 'claimed' result may grant benefits; the primary key
// makes a replayed token come back as already claimed.
export async function claimPurchaseToken(
  supabaseAdmin: SupabaseClient,
  purchaseToken: string,
  period: string,
  userId: string,
  productId: string,
): Promise<ClaimResult> {
  const { error } = await supabaseAdmin
    .from('purchase_tokens')
    .insert({ purchase_token: purchaseToken, period, user_id: userId, product_id: productId });

  if (!error) return 'claimed';
  if (error.code !== '23505') {
    throw new Error(`Failed to record purchase token: ${error.message}`);
  }

  const { data: existing, error: fetchError } = await supabaseAdmin
    .from('purchase_tokens')
    .select('user_id')
    .eq('purchase_token', purchaseToken)
    .eq('period', period)
    .single();
  if (fetchError) throw new Error(`Failed to read purchase token: ${fetchError.message}`);

  return existing.user_id === userId ? 'already_claimed' : 'claimed_by_other';
}

// Undoes a claim when granting failed, so the purchase can be retried.
export async function releasePurchaseToken(
  supabaseAdmin: SupabaseClient,
  purchaseToken: string,
  period: string,
) {
  const { error } = await supabaseAdmin
    .from('purchase_tokens')
    .delete()
    .eq('purchase_token', purchaseToken)
    .eq('period', period);
  if (error) console.error(`Failed to release purchase token: ${error.message}`);
}
