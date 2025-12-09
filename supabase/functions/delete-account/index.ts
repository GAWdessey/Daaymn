// supabase/functions/delete-account/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

serve(async (req) => {
  const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const authHeader = req.headers.get("authorization")!;
    const accessToken = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userErr } = await supabaseAdmin.auth.getUser(accessToken);

    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Invalid user token" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    const userId = user.id;

    // 1. Delete user's files from storage (this is not handled by DB cascades)
    const { data: files, error: listError } = await supabaseAdmin.storage.from('profile-images').list(userId);
    if (listError) {
        console.error(`Could not list files for user ${userId}:`, listError.message);
    }
    if (files && files.length > 0) {
      const filePaths = files.map(file => `${userId}/${file.name}`);
      await supabaseAdmin.storage.from('profile-images').remove(filePaths);
    }

    // 2. Delete the user from auth.users. The ON DELETE CASCADE in your DB will handle the rest.
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteError) {
      // This will now only fail if there's a fundamental permissions issue
      // or a new, unhandled foreign key without a cascade.
      throw deleteError;
    }

    return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });

  } catch (e) {
    console.error("Error in delete-account function:", e.message);
    return new Response(JSON.stringify({ error: `Failed to delete account: ${e.message}` }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
