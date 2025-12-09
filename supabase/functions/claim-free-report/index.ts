
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // This is boilerplate for CORS and handles OPTIONS requests.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create a Supabase client with the service role key to perform admin actions.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      {
        global: { headers: { Authorization: req.headers.get('Authorization')! } },
      }
    )

    // Get the user from the authorization header.
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ message: 'Authentication required.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Fetch the user's profile to check the last claim timestamp.
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('last_free_report_claimed_at')
      .eq('id', user.id)
      .single()

    if (profileError) {
      return new Response(
        JSON.stringify({ message: `Profile query failed: ${profileError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if the user is within the 30-day cooldown period.
    const lastClaim = profile?.last_free_report_claimed_at
    if (lastClaim) {
      const nextClaimDate = new Date(new Date(lastClaim).setMonth(new Date(lastClaim).getMonth() + 1))
      if (new Date() < nextClaimDate) {
        const friendlyDate = nextClaimDate.toLocaleString('en-US', {
          month: 'long',
          day: 'numeric',
          year: 'numeric',
        })
        return new Response(
          JSON.stringify({ message: `Your next free report is available on ${friendlyDate}.` }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // If all checks pass, ONLY update the timestamp. Do not calculate or return a score.
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ last_free_report_claimed_at: new Date().toISOString() })
      .eq('id', user.id)

    if (updateError) {
      return new Response(
        JSON.stringify({ message: `Failed to update claim timestamp: ${updateError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return a simple success message. The app will now do the score calculation.
    return new Response(JSON.stringify({ message: 'Claim successful. Your score can now be calculated.' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ message: e.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
