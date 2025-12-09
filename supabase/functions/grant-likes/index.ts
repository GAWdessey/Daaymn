import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const { user_id, num_likes } = await req.json();

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Retrieve the current likes_balance
    const { data: profile, error: fetchError } = await supabaseAdmin
      .from('profiles')
      .select('likes_balance')
      .eq('id', user_id)
      .single();

    if (fetchError) throw fetchError;

    const currentLikes = profile.likes_balance || 0;
    const newLikes = currentLikes + num_likes;

    // Update the likes_balance
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({ likes_balance: newLikes })
      .eq('id', user_id);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({ message: `Granted ${num_likes} likes to ${user_id}` }), { status: 200 });

  } catch (error) {
    console.error('[FUNCTIONS_ERROR] grant-likes:', error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
