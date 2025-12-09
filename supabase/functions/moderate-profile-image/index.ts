import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Main function to handle the request
serve(async (req) => {
  try {
    // 1. Get image details from the request body (Storage hook payload)
    const payload = await req.json();
    const name = payload.record.name;
    const owner = payload.record.owner; // This is how you get the owner from a storage hook
    const bucketId = payload.record.bucket_id;

    // Only act on the 'profile-images' bucket
    if (bucketId !== "profile-images") {
      return new Response(JSON.stringify({ message: "Not a profile image, skipping." }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Get secrets
    const sightengineApiUser = Deno.env.get("SIGHTENGINE_API_USER");
    const sightengineApiSecret = Deno.env.get("SIGHTENGINE_API_SECRET");

    if (!sightengineApiUser || !sightengineApiSecret) {
      throw new Error("Sightengine API credentials are not set in secrets.");
    }

    // 3. Create Supabase admin client and get public URL for the image
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: publicUrlData } = supabaseAdmin.storage
      .from(bucketId)
      .getPublicUrl(name);
      
    const publicURL = publicUrlData.publicUrl;

    if (!publicURL) {
        throw new Error(`Could not get public URL for image: ${name}`);
    }

    // 4. Call the Sightengine API
    const models = "nudity-2.0,wad,offensive";
    const encodedUrl = encodeURIComponent(publicURL);
    const apiUrl = `https://api.sightengine.com/1.0/check.json?models=${models}&url=${encodedUrl}&api_user=${sightengineApiUser}&api_secret=${sightengineApiSecret}`;

    const sightengineResponse = await fetch(apiUrl);

    if (!sightengineResponse.ok) {
      const errorBody = await sightengineResponse.json();
      throw new Error(`Sightengine API request failed: ${JSON.stringify(errorBody)}`);
    }

    const data = await sightengineResponse.json();

    // 5. Check for inappropriate content
    const nudity = data.nudity || {};
    const isAdult = nudity.sexual_activity > 0.5 || nudity.sexual_display > 0.5 || nudity.erotica > 0.5;
    const isWeapon = data.weapon > 0.5;
    const isAlcoholOrDrugs = data.alcohol > 0.8 || data.drugs > 0.8;
    const isOffensive = (data.offensive || {}).prob > 0.7;

    const isFlagged = isAdult || isWeapon || isAlcoholOrDrugs || isOffensive;

    if (isFlagged) {
      // If inappropriate, delete the image from storage
      await supabaseAdmin.storage.from(bucketId).remove([name]);
      
      // And create a report for auditing purposes
      const rejectionDetails = `sexual_activity: ${nudity.sexual_activity}, sexual_display: ${nudity.sexual_display}, weapon: ${data.weapon}, alcohol: ${data.alcohol}, drugs: ${data.drugs}, offensive: ${(data.offensive || {}).prob}`;
      const notes = `REJECTED_FILE:${name}; AUTOMATED MODERATION: ${rejectionDetails}`;

      let reason = "inappropriate_content";
      if (isAdult) reason = "adult_content";
      else if (isWeapon) reason = "violent_content";
      else if (isOffensive) reason = "offensive_content";

      await supabaseAdmin.from("reports").insert({
        reporter_id: owner, // The user themselves is the "reporter"
        reported_id: owner,
        reasons: [reason],
        notes: notes.substring(0, 500), // Ensure notes fit in DB
      });

      return new Response(JSON.stringify({ message: "Inappropriate image detected and removed." }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 6. If the image is clean, return a success response
    return new Response(JSON.stringify({ message: "Image is clean." }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Error in moderation function:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    });
  }
});
