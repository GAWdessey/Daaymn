import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { google } from 'npm:googleapis@105';
import { grantSubscriptionBenefits } from '../_shared/grant-benefits.ts';

function getServiceAccountKey() {
  const keyJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_KEY');
  if (!keyJson) throw new Error("Missing env var: GOOGLE_SERVICE_ACCOUNT_KEY");
  try {
    return JSON.parse(keyJson);
  } catch (error) {
    throw new Error("Failed to parse GOOGLE_SERVICE_ACCOUNT_KEY JSON: " + error.message);
  }
}

serve(async (req) => {
  console.log("--- New RTDN Request Received ---");

  try {
    const url = new URL(req.url);
    const providedToken = url.searchParams.get('token');
    const expectedToken = Deno.env.get('WEBHOOK_TOKEN');

    if (!providedToken || providedToken !== expectedToken) {
      console.error("Unauthorized: Missing or incorrect webhook token.");
      return new Response('Unauthorized.', { status: 401 });
    }
    console.log("Webhook token validated successfully.");

    const body = await req.json();
    const decodedData = JSON.parse(atob(body.message.data));

    if (!decodedData.subscriptionNotification) {
        console.log("Ignoring non-subscription notification.");
        return new Response('Ignoring non-subscription notification.', { status: 200 });
    }

    const notification = decodedData.subscriptionNotification;
    console.log("Decoded notification:", notification);

    const notificationType = notification.notificationType;
    // We care about: 2 (RENEWED), 4 (CANCELED), 12 (REVOKED), 13 (EXPIRED)
    if (notificationType !== 2 && notificationType !== 4 && notificationType !== 12 && notificationType !== 13) {
      console.log(`Ignoring irrelevant notification type: ${notificationType}`);
      return new Response('Ignoring notification type.', { status: 200 });
    }

    const productId = notification.subscriptionId;
    const purchaseToken = notification.purchaseToken;

    const serviceAccountKey = getServiceAccountKey();
    const packageName = Deno.env.get('ANDROID_PACKAGE_NAME');
    if (!packageName) throw new Error("Missing env var: ANDROID_PACKAGE_NAME");

    const jwt = new google.auth.JWT(
      serviceAccountKey.client_email,
      null,
      serviceAccountKey.private_key,
      ['https://www.googleapis.com/auth/androidpublisher']
    );

    const androidPublisher = google.androidpublisher({ version: 'v3', auth: jwt });

    console.log("Verifying subscription with Google using purchase token...");
    const verification = await androidPublisher.purchases.subscriptions.get({
      packageName: packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });
    console.log("Received verification data from Google:", verification.data);
    
    const obfuscatedId = verification.data.obfuscatedExternalAccountId;

    if (!obfuscatedId) {
      console.error('Could not find obfuscatedExternalAccountId in Google\'s response. Cannot find user.');
      return new Response('User identifier missing from Google verification, but acknowledging to prevent retries.', { status: 200 });
    }
    console.log(`Found Obfuscated ID from Google API: ${obfuscatedId}`);

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    console.log(`Searching for user profile with obfuscated_external_account_id: ${obfuscatedId}`);
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('obfuscated_external_account_id', obfuscatedId)
      .single();

    if (profileError || !profile) {
      console.error(`Could not find user for obfuscated ID: ${obfuscatedId}. Error: ${profileError?.message}`);
      return new Response(`User not found for obfuscated ID, but acknowledging message to prevent retries.`, { status: 200 });
    }

    const userId = profile.id;
    console.log(`Found User ID: ${userId}`);

    const expiryTimeMillis = verification.data.expiryTimeMillis;
    if (!expiryTimeMillis) {
        console.log(`Subscription has no expiry time, treating as inactive for user ${userId}.`);
        return new Response('Subscription has no expiry time, acknowledging to prevent retries.', { status: 200 });
    }
    const expiryDate = new Date(parseInt(expiryTimeMillis, 10));
    console.log(`Expiry time from Google is ${expiryTimeMillis}, which is: ${expiryDate.toISOString()}`);

    if (notificationType !== 2) {
        console.log(`Notification type ${notificationType} does not grant benefits. Acknowledging to stop retries.`);
        return new Response('Non-granting notification type handled.', { status: 200 });
    }

    if (parseInt(expiryTimeMillis, 10) <= Date.now()) {
      console.warn(`Renewal notification for an already expired subscription for user ${userId}. Expiry: ${expiryDate.toISOString()}, Now: ${new Date().toISOString()}`);
      return new Response('Subscription is not active, acknowledging to prevent retries.', { status: 200 });
    }

    console.log(`Granting subscription benefits to user ${userId}...`);
    await grantSubscriptionBenefits(
      supabaseAdmin,
      userId,
      productId,
      expiryTimeMillis,
      purchaseToken
    );

    console.log(`--- Successfully processed RTDN for user ${userId} ---`);
    return new Response('Notification processed successfully.', { status: 200 });

  } catch (error) {
    console.error('!!! FATAL ERROR processing RTDN:', error.message);
    return new Response(JSON.stringify({ error: `Internal Server Error: ${error.message}` }), { status: 200 });
  }
});