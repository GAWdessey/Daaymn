import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  // This is needed for browser security.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Get the 'id' from the request body.
    const { id } = await req.json()
    if (!id) {
      throw new Error("Missing 'id' in request body")
    }

    // 2. Create a special Supabase client with admin rights to bypass RLS.
    // This is secure because it uses environment variables only available on the server.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. Query the 'verified_reports' table for the matching ID.
    const { data, error } = await supabaseAdmin
      .from('verified_reports')
      .select('user_name, score') // We only need the name and score.
      .eq('id', id)
      .single() // Expect only one result.

    // If the query returns an error (like no rows found), throw an error.
    if (error) {
      throw error
    }

    // 4. If we found the data, return it to the webpage.
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    // 5. If anything fails, return a 404 "Not Found" error.
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 404,
    })
  }
})
