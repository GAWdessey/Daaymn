import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const { signature } = await req.json();
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);

  if (!signature) {
    return new Response(JSON.stringify({ isVerified: false, message: "No signature provided." }), { status: 400 });
  }

  const { data, error } = await supabase
    .from("verified_signatures")
    .select("signature")
    .eq("signature", signature)
    .single();

  const isVerified = data != null && !error;

  return new Response(JSON.stringify({ isVerified }), {
    headers: { "Content-Type": "application/json" },
  });
});