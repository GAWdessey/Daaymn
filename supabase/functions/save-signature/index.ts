import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const { signature } = await req.json();
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);

  if (!signature) {
    return new Response("Missing signature", { status: 400 });
  }

  const { error } = await supabase.from("verified_signatures").insert({ signature });

  if (error) {
    return new Response(error.message, { status: 500 });
  }

  return new Response("Signature saved", { status: 200 });
});