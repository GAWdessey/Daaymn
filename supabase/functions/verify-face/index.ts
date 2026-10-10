import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { CompareFacesCommand, RekognitionClient } from 'npm:@aws-sdk/client-rekognition@3'
import { corsHeaders } from '../_shared/cors.ts'

// Decides whether the caller's selfie matches one of their own profile photos
// and is the only thing that sets profiles.is_verified (the guard trigger
// ignores is_verified from the app).
const SIMILARITY_THRESHOLD = 90
const MAX_ATTEMPTS_PER_DAY = 5
const MAX_PHOTOS_COMPARED = 6
const MAX_IMAGE_BYTES = 5 * 1024 * 1024 // Rekognition's limit for raw bytes
const BUCKET = 'profile-images'

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status,
  })
}

// Only the caller's own uploads count: a public profile-images URL whose
// path starts with their user id.
function ownStoragePath(url: string, userId: string): string | null {
  const marker = `/storage/v1/object/public/${BUCKET}/`
  const i = url.indexOf(marker)
  if (i === -1) return null
  const path = decodeURIComponent(url.slice(i + marker.length).split('?')[0])
  return path.startsWith(`${userId}/`) && !path.includes('..') ? path : null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { data: { user } } = await createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    ).auth.getUser()
    if (!user) return json({ error: 'Authentication required' }, 401)

    const awsKeyId = Deno.env.get('AWS_ACCESS_KEY_ID')
    const awsSecret = Deno.env.get('AWS_SECRET_ACCESS_KEY')
    if (!awsKeyId || !awsSecret) {
      console.error('verify-face: AWS credentials are not set')
      return json({ error: 'Verification is not available right now. Please try again later.' }, 503)
    }

    const { selfie } = await req.json()
    if (typeof selfie !== 'string' || selfie.length === 0) {
      return json({ error: 'No selfie was sent.' }, 400)
    }
    const selfieBytes = Uint8Array.from(atob(selfie), (c) => c.charCodeAt(0))
    if (selfieBytes.length > MAX_IMAGE_BYTES) {
      return json({ error: 'That selfie is too large. Please try again.' }, 413)
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Each attempt costs a Rekognition call per photo, so cap them
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    const { count, error: countError } = await supabaseAdmin
      .from('face_verification_attempts')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', since)
    if (countError) throw countError
    if ((count ?? 0) >= MAX_ATTEMPTS_PER_DAY) {
      return json({ error: 'Too many verification attempts today. Please try again tomorrow.' }, 429)
    }

    // Every Rekognition call is billed, so stop at the monthly cap in app_config
    // (none set means none allowed)
    const { data: capRow, error: capError } = await supabaseAdmin
      .from('app_config')
      .select('value')
      .eq('key', 'face_compare_monthly_cap')
      .maybeSingle()
    if (capError) throw capError
    const monthlyCap = Number(capRow?.value ?? 0)
    const now = new Date()
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString()
    const { data: monthRows, error: monthError } = await supabaseAdmin
      .from('face_verification_attempts')
      .select('compare_calls')
      .gt('compare_calls', 0)
      .gte('created_at', monthStart)
    if (monthError) throw monthError
    let callsLeft = monthlyCap - (monthRows ?? []).reduce((sum, r) => sum + r.compare_calls, 0)
    if (callsLeft <= 0) {
      console.error('verify-face: monthly compare cap reached', monthlyCap)
      return json({ error: 'Verification is not available right now. Please try again later.' }, 503)
    }

    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('image_urls')
      .eq('id', user.id)
      .single()
    if (profileError) throw profileError

    const paths = ((profile.image_urls ?? []) as string[])
      .map((url) => ownStoragePath(url, user.id))
      .filter((p): p is string => p !== null)
      .slice(0, MAX_PHOTOS_COMPARED)
    if (paths.length === 0) {
      return json({ error: 'You must have at least one profile picture uploaded.' }, 400)
    }

    const rekognition = new RekognitionClient({
      region: Deno.env.get('AWS_REGION') ?? 'eu-west-1',
      credentials: { accessKeyId: awsKeyId, secretAccessKey: awsSecret },
    })

    let bestSimilarity = 0
    let selfieHasFace = true
    let compareCalls = 0
    let capReached = false
    for (const path of paths) {
      if (callsLeft <= 0) {
        capReached = true
        break
      }
      const { data: blob, error: downloadError } = await supabaseAdmin.storage.from(BUCKET).download(path)
      if (downloadError || !blob) continue
      const photoBytes = new Uint8Array(await blob.arrayBuffer())
      if (photoBytes.length > MAX_IMAGE_BYTES) continue

      compareCalls++
      callsLeft--
      try {
        const result = await rekognition.send(new CompareFacesCommand({
          SourceImage: { Bytes: selfieBytes },
          TargetImage: { Bytes: photoBytes },
          SimilarityThreshold: 0,
          QualityFilter: 'AUTO',
        }))
        for (const match of result.FaceMatches ?? []) {
          bestSimilarity = Math.max(bestSimilarity, match.Similarity ?? 0)
        }
      } catch (err) {
        const e = err as Error
        // No face in the selfie fails every comparison the same way
        if (e.name === 'InvalidParameterException') {
          selfieHasFace = false
          break
        }
        // An unreadable profile photo: try the next one
        console.error('verify-face compare:', e.name, e.message)
        continue
      }
      if (bestSimilarity >= SIMILARITY_THRESHOLD) break
    }

    const verified = bestSimilarity >= SIMILARITY_THRESHOLD
    await supabaseAdmin.from('face_verification_attempts').insert({
      user_id: user.id,
      verified,
      similarity: bestSimilarity,
      compare_calls: compareCalls,
    })

    if (!verified && capReached) {
      return json({ error: 'Verification is not available right now. Please try again later.' }, 503)
    }

    if (verified) {
      const { error: updateError } = await supabaseAdmin
        .from('profiles')
        .update({ is_verified: true })
        .eq('id', user.id)
      if (updateError) throw updateError
      return json({ verified: true })
    }

    return json({
      verified: false,
      reason: selfieHasFace
        ? 'Your selfie doesn\'t match your profile photos.'
        : 'Could not detect a face in your selfie.',
    })
  } catch (err) {
    console.error('verify-face:', err)
    return json({ error: 'An error occurred during verification.' }, 500)
  }
})
