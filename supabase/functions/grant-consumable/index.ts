
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const { productId } = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response("User not found", { status: 401 });
    }

    // Determine the number of likes to add, including bonus
    let likesToAdd = 0;
    switch (productId) {
      case "daaymn_like_1_d":
        likesToAdd = 1;
        break;
      case "daaymn_like_10_d":
        likesToAdd = 11; // 10 + 1 bonus
        break;
      case "daaymn_like_20_d":
        likesToAdd = 22; // 20 + 2 bonus
        break;
      default:
        return new Response(`Invalid consumable product ID: ${productId}`, { status: 400 });
    }

    // Fetch the user's current profile
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('like_count')
      .eq('id', user.id)
      .single();

    if (profileError) {
      throw new Error(`Failed to fetch profile: ${profileError.message}`);
    }

    // Calculate the new balance and update the profile
    const newLikeCount = (profile.like_count || 0) + likesToAdd;
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ like_count: newLikeCount })
      .eq('id', user.id);

    if (updateError) {
      throw new Error(`Failed to update like count: ${updateError.message}`);
    }

    return new Response(JSON.stringify({ success: true, likesAdded: likesToAdd }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error(`[FUNCTIONS_ERROR] grant-consumable: ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
