-- Snapshot of the live database schema (supabase db dump --linked), taken
-- 2026-10-08 so tables, functions, grants and RLS policies can be reviewed.
-- Not a migration: nothing applies this file. Refresh it with
--   supabase db dump --linked -f supabase/schema/live-schema.sql




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."report_reason" AS ENUM (
    'spam',
    'inappropriate_profile',
    'unwanted_contact',
    'impersonation',
    'other'
);


ALTER TYPE "public"."report_reason" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."accept_like"("p_other_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$DECLARE
  current_likes int;
BEGIN
  -- Get the current user's like count securely
  SELECT like_count INTO current_likes FROM public.profiles WHERE id = auth.uid();

  -- Enforce the business rule: must have at least 1 like to spend.
  IF current_likes < 1 THEN
    RAISE EXCEPTION 'insufficient likes';
  END IF;

  -- If check passes, spend the like and create the mutual like (match).
  UPDATE public.profiles
  SET like_count = like_count - 1
  WHERE id = auth.uid();

  INSERT INTO public.likes(user_id, liked_user_id)
  VALUES (auth.uid(), p_other_user_id)
  ON CONFLICT (user_id, liked_user_id) DO NOTHING;
END;$$;


ALTER FUNCTION "public"."accept_like"("p_other_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_likes"("quantity" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- NOTE: In a real production app, this is where you would add logic
  -- to verify an in-app purchase receipt from Google Play or the App Store
  -- before proceeding to grant the likes.

  UPDATE public.profiles
  SET like_count = like_count + quantity
  WHERE id = auth.uid(); -- auth.uid() securely gets the ID of the calling user
END;
$$;


ALTER FUNCTION "public"."add_likes"("quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cast_vote"("poll_option_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
DECLARE
  selected_poll_id uuid;
BEGIN
  SELECT poll_id INTO selected_poll_id
  FROM public.poll_options
  WHERE id = poll_option_id;

  INSERT INTO public.poll_votes (poll_id, option_id, user_id)
  VALUES (selected_poll_id, poll_option_id, auth.uid());

  UPDATE public.poll_options
  SET votes = votes + 1
  WHERE id = poll_option_id;

EXCEPTION
  WHEN unique_violation THEN
    NULL;
END;
$$;


ALTER FUNCTION "public"."cast_vote"("poll_option_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_free_monthly_report"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
DECLARE
  user_id_input uuid;
  last_claim timestamptz;
  next_claim_allowed_at timestamptz;
BEGIN
  user_id_input := auth.uid();

  SELECT last_free_report_claimed_at INTO last_claim
  FROM public.profiles
  WHERE id = user_id_input;

  IF last_claim IS NOT NULL THEN
    next_claim_allowed_at := last_claim + interval '1 month';
    IF now() < next_claim_allowed_at THEN
      RAISE EXCEPTION 'You can claim your next free report on %.', to_char(next_claim_allowed_at, 'Month DD, YYYY');
    END IF;
  END IF;

  UPDATE public.profiles
  SET last_free_report_claimed_at = now()
  WHERE id = user_id_input;

  RETURN jsonb_build_object('claimedTier', 'basic');
END;
$$;


ALTER FUNCTION "public"."claim_free_monthly_report"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_like_and_remove_dislike"("p_liked_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$BEGIN
  -- Create the new like, ignoring if it already exists
  INSERT INTO public.likes(user_id, liked_user_id)
  VALUES (auth.uid(), p_liked_user_id)
  ON CONFLICT (user_id, liked_user_id) DO NOTHING;

  -- Clean up any previous dislike the user may have had for this profile
  DELETE FROM public.dislikes
  WHERE user_id = auth.uid() AND disliked_user_id = p_liked_user_id;
END;$$;


ALTER FUNCTION "public"."create_like_and_remove_dislike"("p_liked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_like_and_update_otm_counter"("p_liked_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_current_level int;
  v_new_level int;
BEGIN
  -- Find the current counter level for the user
  SELECT COALESCE(MAX(super_like_level), 0)
  INTO v_current_level
  FROM public.likes
  WHERE user_id = v_user_id;

  -- Calculate the new level, resetting at 5
  IF v_current_level >= 5 THEN
    v_new_level := 0;
  ELSE
    v_new_level := v_current_level + 1;
  END IF;

  -- Insert the new like with the new level
  INSERT INTO public.likes (user_id, liked_user_id, super_like_level)
  VALUES (v_user_id, p_liked_user_id, v_new_level);

  -- Return true if the new level is 5, indicating an OTM is earned
  RETURN v_new_level = 5;
END;
$$;


ALTER FUNCTION "public"."create_like_and_update_otm_counter"("p_liked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."debug_reset_ad_timestamps"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE public.profiles
  SET
    last_ad_like_at = NULL,
    last_ad_scroll_at = NULL,
    last_ad_ghost_at = NULL
  WHERE id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."debug_reset_ad_timestamps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_like_on_new_like"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public.profiles
  SET like_count = like_count - 1
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."decrement_like_on_new_like"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_report_credit"("user_id_in" "uuid", "tier_in" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  current_credits jsonb;
  new_credits jsonb;
  current_count int;
BEGIN
  SELECT one_time_report_credits INTO current_credits FROM public.profiles WHERE id = user_id_in;
  current_count := COALESCE((current_credits->>tier_in)::int, 0);

  IF current_count <= 0 THEN
    RETURN FALSE;
  END IF;

  new_credits := jsonb_set(
    current_credits,
    ARRAY[tier_in],
    to_jsonb(current_count - 1)
  );
  UPDATE public.profiles
  SET one_time_report_credits = new_credits
  WHERE id = user_id_in;

  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."decrement_report_credit"("user_id_in" "uuid", "tier_in" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_user_like_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Check if the user has likes to spend before decrementing
  IF (SELECT like_count FROM public.profiles WHERE id = NEW.user_id) > 0 THEN
    UPDATE public.profiles
    SET like_count = like_count - 1
    WHERE id = NEW.user_id;
  ELSE
    -- Optionally, you could raise an exception here to prevent the like,
    -- but for now we'll just prevent the count from going negative.
    -- This matches the client-side check.
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."decrement_user_like_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_user_like_count"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  UPDATE public.profiles
  SET like_count = like_count - 1
  WHERE id = p_user_id;
$$;


ALTER FUNCTION "public"."decrement_user_like_count"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_otm"("message_id_to_delete" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM public.messages
  WHERE
    id = message_id_to_delete AND
    receiver_id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."delete_otm"("message_id_to_delete" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  user_id uuid;
  user_images text[];
begin
  -- Get the user ID from the currently authenticated user
  select auth.uid() into user_id;

  -- Get all image URLs from the user's profile
  select image_urls into user_images from public.profiles where id = user_id;

  -- Delete all images from storage
  if array_length(user_images, 1) > 0 then
    perform storage.delete_objects('profile-images', user_images);
  end if;

  -- Delete the user's profile
  delete from public.profiles where id = user_id;

  -- Delete the user from the auth schema
  perform auth.admin_delete_user(user_id);
end;
$$;


ALTER FUNCTION "public"."delete_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_account"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  user_id_to_delete uuid;
begin
  -- Get the current user's ID
  select auth.uid() into user_id_to_delete;

  -- Delete storage metadata (removes DB rows; Supabase storage handles actual files)
  delete from storage.objects
  where bucket_id = 'profile-images'
    and owner = user_id_to_delete;

  -- Delete profile data
  delete from public.profiles where id = user_id_to_delete;

  -- Delete auth user
  delete from auth.users where id = user_id_to_delete;
end;
$$;


ALTER FUNCTION "public"."delete_user_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_blocked_users"() RETURNS TABLE("blocked_user_id" "uuid")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT blocked_user_id 
  FROM user_blocks 
  WHERE user_id = auth.uid()
  UNION
  SELECT user_id
  FROM user_blocks
  WHERE blocked_user_id = auth.uid();
$$;


ALTER FUNCTION "public"."get_blocked_users"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") RETURNS TABLE("blocked_users" "uuid")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$  SELECT blocked_user_id FROM public.blocks WHERE user_id = p_user_id
  UNION
  SELECT user_id FROM public.blocks WHERE blocked_user_id = p_user_id;
$$;


ALTER FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_last_months_winning_poll"() RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
decLare
  last_month_poll_id uuid;
  winning_option jsonb;
begin
  -- 1. Find the poll_id for the most recent poll that ended before the current month
  select id into last_month_poll_id
  from public.polls
  where end_date < date_trunc('month', now())
  order by end_date desc
  limit 1;

  if last_month_poll_id is null then
    return null;
  end if;

  -- 2. Find the winning option for that poll
  select to_jsonb(t.*) into winning_option
  from (
    select * from public.poll_options
    where poll_id = last_month_poll_id
    order by votes desc
    limit 1
  ) t;

  return winning_option;
end;
$$;


ALTER FUNCTION "public"."get_last_months_winning_poll"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_matches_count"("p_user_id" "text") RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
    match_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO match_count
    FROM
        likes l1
    INNER JOIN
        likes l2 ON l1.user_id = l2.liked_user_id AND l1.liked_user_id = l2.user_id
    WHERE
        l1.user_id = p_user_id;

    RETURN match_count;
END;
$$;


ALTER FUNCTION "public"."get_matches_count"("p_user_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_matches_with_no_messages_count"("p_user_id" "text") RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
    ghosted_matches_count INTEGER;
BEGIN
    WITH matches AS (
        SELECT l2.user_id as matched_user_id
        FROM likes l1
        JOIN likes l2 ON l1.user_id = l2.liked_user_id AND l1.liked_user_id = l2.user_id
        WHERE l1.user_id = p_user_id
    )
    SELECT COUNT(*)
    INTO ghosted_matches_count
    FROM matches
    WHERE NOT EXISTS (
        SELECT 1
        FROM messages
        WHERE sender_id = p_user_id AND receiver_id = matches.matched_user_id
    );

    RETURN ghosted_matches_count;
END;
$$;


ALTER FUNCTION "public"."get_matches_with_no_messages_count"("p_user_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_notification_counts"() RETURNS TABLE("p_your_likes_count" integer, "p_liked_you_count" integer, "p_messages_count" integer)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  current_user_id uuid := auth.uid();
BEGIN
  RETURN QUERY
  WITH my_likes AS (
    SELECT liked_user_id FROM likes WHERE user_id = current_user_id
  ),
  my_dislikes AS (
    SELECT disliked_user_id FROM dislikes WHERE user_id = current_user_id
  ),
  my_blocks AS (
    SELECT blocked_id FROM blocks WHERE blocker_id = current_user_id
  )
  SELECT
    (SELECT count(*)::int FROM likes WHERE user_id = current_user_id),
    (
      SELECT count(*)::int FROM likes
      WHERE
        liked_user_id = current_user_id
        AND user_id NOT IN (SELECT liked_user_id FROM my_likes)
        AND user_id NOT IN (SELECT disliked_user_id FROM my_dislikes)
        AND user_id NOT IN (SELECT blocked_id FROM my_blocks)
    ),
    (SELECT count(*)::int FROM messages WHERE receiver_id = current_user_id AND is_read = false);
END;
$$;


ALTER FUNCTION "public"."get_notification_counts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_random_daaymn_idiology"() RETURNS TABLE("headline" "text", "body" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
    SELECT headline, body
    FROM public.daaymn_idiology
    ORDER BY random()
    LIMIT 1;
$$;


ALTER FUNCTION "public"."get_random_daaymn_idiology"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_server_timestamp"() RETURNS timestamp with time zone
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
  SELECT now();
$$;


ALTER FUNCTION "public"."get_server_timestamp"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "receiver_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "is_read" boolean DEFAULT false,
    "audio_url" "text",
    "audio_duration" integer,
    "is_one_time_message" boolean DEFAULT false,
    "is_otm" boolean DEFAULT false,
    "message_type" "text" DEFAULT 'text'::"text"
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unblocked_otms"("p_user_id" "uuid") RETURNS SETOF "public"."messages"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$BEGIN
  RETURN QUERY
    SELECT m.*
    FROM public.messages m
    WHERE
      m.receiver_id = p_user_id AND
      m.is_otm = true AND
      NOT EXISTS (
        SELECT 1
        FROM public.blocks b
        WHERE b.blocker_id = p_user_id AND b.blocked_id = m.sender_id
      );
END;$$;


ALTER FUNCTION "public"."get_unblocked_otms"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_likes"("user_id" "uuid", "num_likes" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  PERFORM set_config('search_path', 'pg_catalog, public', true);

  UPDATE public.profiles
  SET like_count = COALESCE(like_count, 0) + num_likes
  WHERE id = user_id;
END;
$$;


ALTER FUNCTION "public"."grant_likes"("user_id" "uuid", "num_likes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_block"("p_blocker_id" "uuid", "p_blocked_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$BEGIN
    -- 1. Add the block record
    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (p_blocker_id, p_blocked_id)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- 2. Remove any likes between the two users
    DELETE FROM public.likes
    WHERE (user_id = p_blocker_id AND liked_user_id = p_blocked_id)
       OR (user_id = p_blocked_id AND liked_user_id = p_blocker_id);

    -- 3. Delete the entire message history between them
    DELETE FROM public.messages
    WHERE (sender_id = p_blocker_id AND receiver_id = p_blocked_id)
       OR (sender_id = p_blocked_id AND receiver_id = p_blocker_id);
END;$$;


ALTER FUNCTION "public"."handle_block"("p_blocker_id" "uuid", "p_blocked_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_expired_like"("p_user_id" "uuid", "p_liked_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete the like
  DELETE FROM public.likes
  WHERE user_id = p_user_id AND liked_user_id = p_liked_user_id;

  -- Delete the corresponding notification
  DELETE FROM public.notifications
  WHERE notifier_id = p_user_id AND user_id = p_liked_user_id AND type = 'new_like';
END;
$$;


ALTER FUNCTION "public"."handle_expired_like"("p_user_id" "uuid", "p_liked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_like"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://rrbsjmfwahaerkfhpegv.supabase.co/functions/v1/new-like',
    body := jsonb_build_object('record', NEW),
    headers := jsonb_build_object('Content-Type', 'application/json')
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_like"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_message"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://rrbsjmfwahaerkfhpegv.supabase.co/functions/v1/new-message',
    body := jsonb_build_object('record', NEW),
    headers := jsonb_build_object('Content-Type', 'application/json')
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_profile_upsert"("profile_data" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
DECLARE
  user_id uuid := auth.uid();
  existing_is_verified boolean;
  final_is_verified boolean;
  return_profile jsonb;
BEGIN
  SELECT is_verified INTO existing_is_verified FROM public.profiles WHERE id = user_id;

  IF existing_is_verified IS NOT NULL THEN
    final_is_verified := existing_is_verified;
  ELSE
    final_is_verified := FALSE;
  END IF;

  INSERT INTO public.profiles (
    id,
    name,
    age,
    image_urls,
    best_photo_index,
    gender,
    pronouns,
    ethnicity,
    bio_topics,
    dominant_hand,
    device_preference,
    work,
    religion,
    height_cm,
    weight_kg,
    interested_in,
    metric_system,
    updated_at,
    is_verified
  )
  VALUES (
    user_id,
    profile_data->>'name',
    NULLIF(profile_data->>'age','')::integer,
    (CASE WHEN profile_data ? 'image_urls' THEN ARRAY(SELECT * FROM jsonb_array_elements_text(profile_data->'image_urls')) ELSE NULL END),
    NULLIF(profile_data->>'best_photo_index','')::integer,
    profile_data->>'gender',
    profile_data->>'pronouns',
    profile_data->>'ethnicity',
    profile_data->'bio_topics',
    profile_data->'dominant_hand',
    profile_data->'device_preference',
    profile_data->'work',
    profile_data->'religion',
    profile_data->'height_cm',
    profile_data->'weight_kg',
    (CASE WHEN profile_data ? 'interested_in' THEN ARRAY(SELECT * FROM jsonb_array_elements_text(profile_data->'interested_in')) ELSE NULL END),
    profile_data->>'metric_system',
    now(),
    final_is_verified
  )
  ON CONFLICT (id)
  DO UPDATE SET
    name = EXCLUDED.name,
    age = EXCLUDED.age,
    image_urls = EXCLUDED.image_urls,
    best_photo_index = EXCLUDED.best_photo_index,
    gender = EXCLUDED.gender,
    pronouns = EXCLUDED.pronouns,
    ethnicity = EXCLUDED.ethnicity,
    bio_topics = EXCLUDED.bio_topics,
    dominant_hand = EXCLUDED.dominant_hand,
    device_preference = EXCLUDED.device_preference,
    work = EXCLUDED.work,
    religion = EXCLUDED.religion,
    height_cm = EXCLUDED.height_cm,
    weight_kg = EXCLUDED.weight_kg,
    interested_in = EXCLUDED.interested_in,
    metric_system = EXCLUDED.metric_system,
    updated_at = EXCLUDED.updated_at,
    is_verified = public.profiles.is_verified;

  SELECT to_jsonb(p) INTO return_profile FROM public.profiles p WHERE p.id = user_id;
  RETURN return_profile;
END;
$$;


ALTER FUNCTION "public"."handle_profile_upsert"("profile_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_message_history"("p_user1_id" "uuid", "p_user2_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.messages
    WHERE (sender_id = p_user1_id AND receiver_id = p_user2_id)
       OR (sender_id = p_user2_id AND receiver_id = p_user1_id)
  );
$$;


ALTER FUNCTION "public"."has_message_history"("p_user1_id" "uuid", "p_user2_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_dislike"("p_disliked_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.dislikes (user_id, disliked_user_id, dislike_count)
  VALUES (auth.uid(), p_disliked_user_id, 1)
  ON CONFLICT (user_id, disliked_user_id)
  DO UPDATE SET
    dislike_count = public.dislikes.dislike_count + 1,
    updated_at = NOW()
  WHERE
    public.dislikes.user_id = auth.uid() AND
    public.dislikes.disliked_user_id = p_disliked_user_id AND
    public.dislikes.dislike_count < 10;
END;
$$;


ALTER FUNCTION "public"."increment_dislike"("p_disliked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_dislike"("p_user_id" "uuid", "p_disliked_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.dislikes (user_id, disliked_user_id, dislike_count)
  VALUES (p_user_id, p_disliked_user_id, 1)
  ON CONFLICT (user_id, disliked_user_id)
  DO UPDATE SET
    dislike_count = LEAST(public.dislikes.dislike_count + 1, 10);
END;
$$;


ALTER FUNCTION "public"."increment_dislike"("p_user_id" "uuid", "p_disliked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_report_credit"("user_id_in" "uuid", "tier_in" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  current_credits jsonb;
  new_credits jsonb;
  current_count int;
BEGIN
  SELECT one_time_report_credits INTO current_credits FROM public.profiles WHERE id = user_id_in;
  current_count := COALESCE((current_credits->>tier_in)::int, 0);
  new_credits := jsonb_set(
    COALESCE(current_credits, '{}'::jsonb),
    ARRAY[tier_in],
    to_jsonb(current_count + 1)
  );
  UPDATE public.profiles
  SET one_time_report_credits = new_credits
  WHERE id = user_id_in;
END;
$$;


ALTER FUNCTION "public"."increment_report_credit"("user_id_in" "uuid", "tier_in" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_super_like"("p_liked_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  current_likes int;
  new_level int;
BEGIN
  -- Get the current user's like count securely
  SELECT like_count INTO current_likes FROM public.profiles WHERE id = auth.uid();

  -- Enforce the business rule: must have at least 1 like to spend.
  IF current_likes < 1 THEN
    RAISE EXCEPTION 'insufficient likes';
  END IF;

  -- If check passes, proceed with the transaction
  UPDATE public.profiles
  SET like_count = like_count - 1
  WHERE id = auth.uid();

  UPDATE public.likes
  SET super_like_level = super_like_level + 1
  WHERE user_id = auth.uid() AND liked_user_id = p_liked_user_id
  RETURNING super_like_level INTO new_level;

  RETURN new_level;
END;
$$;


ALTER FUNCTION "public"."increment_super_like"("p_liked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."nuke_connection"("p_user_a_id" "uuid", "p_user_b_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
    -- 1. Delete all messages between the two users.
    DELETE FROM public.messages
    WHERE (sender_id = p_user_a_id AND receiver_id = p_user_b_id)
       OR (sender_id = p_user_b_id AND receiver_id = p_user_a_id);

    -- 2. Delete any "like" records between them. This unmatches them.
    DELETE FROM public.likes
    WHERE (user_id = p_user_a_id AND liked_user_id = p_user_b_id)
       OR (user_id = p_user_b_id AND liked_user_id = p_user_a_id);

    -- 3. Add a block record from the blocker to the blocked.
    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (p_user_a_id, p_user_b_id)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- 4. Add 10 dislikes from each user to the other to ensure they never see each other again.
    INSERT INTO public.dislikes (user_id, disliked_user_id, dislike_count)
    VALUES
        (p_user_a_id, p_user_b_id, 10),
        (p_user_b_id, p_user_a_id, 10)
    ON CONFLICT (user_id, disliked_user_id)
    DO UPDATE SET dislike_count = dislikes.dislike_count + 10;

END;
$$;


ALTER FUNCTION "public"."nuke_connection"("p_user_a_id" "uuid", "p_user_b_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."on_new_like"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
begin
  perform
    net.http_post(
      url := 'https://rrbsjmfwahaerkfhpegv.supabase.co/functions/v1/new-like',
      body := json_build_object('record', new)::jsonb,  -- CORRECTED: Cast to jsonb
      headers := '{"Content-Type": "application/json"}'::jsonb   -- CORRECTED: Cast to jsonb
    );
  return new;
end;
$$;


ALTER FUNCTION "public"."on_new_like"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purchase_likes"("p_likes_to_add" integer, "p_price_paid_cents" integer, "p_currency" "text", "p_store_receipt_id" "text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
    new_total_likes integer;
BEGIN
    -- 1. Log the transaction
    INSERT INTO public.purchases (user_id, likes_purchased, price_paid_cents, currency, store_receipt_id)
    VALUES (auth.uid(), p_likes_to_add, p_price_paid_cents, p_currency, p_store_receipt_id);

    -- 2. Add the likes to the user's profile and get the new total
    UPDATE public.profiles
    SET like_count = like_count + p_likes_to_add
    WHERE id = auth.uid()
    RETURNING like_count INTO new_total_likes;

    -- 3. Return the new total like count so the app can display it
    RETURN new_total_likes;
END;
$$;


ALTER FUNCTION "public"."purchase_likes"("p_likes_to_add" integer, "p_price_paid_cents" integer, "p_currency" "text", "p_store_receipt_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."redeem_code_atomic"("p_code" "text") RETURNS TABLE("product_id" "text", "error_message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_promo_record RECORD;
BEGIN
    -- Find the promo code and lock the row for update to prevent race conditions
    SELECT * INTO v_promo_record
    FROM public.promo_codes
    WHERE code = p_code
    FOR UPDATE;

    -- Check if code exists
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL, 'Promo code not found.';
        RETURN;
    END IF;

    -- Check if active
    IF NOT v_promo_record.is_active THEN
        RETURN QUERY SELECT NULL, 'This promo code is not active.';
        RETURN;
    END IF;

    -- Check expiry
    IF v_promo_record.expires_at IS NOT NULL AND v_promo_record.expires_at < NOW() THEN
        RETURN QUERY SELECT NULL, 'This promo code has expired.';
        RETURN;
    END IF;

    -- Check usage limit
    IF v_promo_record.max_uses IS NOT NULL AND v_promo_record.times_used >= v_promo_record.max_uses THEN
        RETURN QUERY SELECT NULL, 'This promo code has reached its usage limit.';
        RETURN;
    END IF;

    -- If all checks pass, increment the usage count
    UPDATE public.promo_codes
    SET times_used = times_used + 1
    WHERE id = v_promo_record.id;

    -- Return the product_id and a NULL error message
    RETURN QUERY SELECT v_promo_record.product_id, NULL;

END;
$$;


ALTER FUNCTION "public"."redeem_code_atomic"("p_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reject_otm_and_like"("p_message_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
DECLARE
  v_sender_id UUID;
  v_receiver_id UUID;
BEGIN
  -- Get the sender and receiver from the message to be deleted
  SELECT sender_id, receiver_id
  INTO v_sender_id, v_receiver_id
  FROM public.messages
  WHERE id = p_message_id;

  -- Security Check: only the receiver can reject the message.
  IF v_receiver_id != auth.uid() THEN
    RAISE EXCEPTION 'authorization failed: you are not the recipient of this message';
  END IF;

  -- 1. Delete the OTM from the messages table
  DELETE FROM public.messages
  WHERE id = p_message_id;

  -- 2. Delete the corresponding 'like' record that initiated the OTM.
  DELETE FROM public.likes
  WHERE
    user_id = v_sender_id AND
    liked_user_id = v_receiver_id;

END;
$$;


ALTER FUNCTION "public"."reject_otm_and_like"("p_message_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reject_otm_and_like"("p_message_id" "uuid", "p_rejecter_id" "uuid", "p_sender_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
    -- 1. Delete the specific One-Time-Message
    DELETE FROM public.messages
    WHERE id = p_message_id AND is_otm = true;

    -- 2. Add a dislike from the rejecter to the sender
    INSERT INTO public.dislikes (user_id, disliked_user_id)
    VALUES (p_rejecter_id, p_sender_id)
    ON CONFLICT (user_id, disliked_user_id) DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."reject_otm_and_like"("p_message_id" "uuid", "p_rejecter_id" "uuid", "p_sender_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."request_daily_like"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  last_grant_time timestamptz;
  current_likes int;
  time_since_last_grant interval;
BEGIN
  -- Get the current user's profile info securely
  SELECT
    like_count,
    last_like_granted_at
  INTO
    current_likes,
    last_grant_time
  FROM public.profiles
  WHERE id = auth.uid();

  -- Business Rule 1: Don't grant a like if the user already has the max amount.
  IF current_likes >= 6 THEN
    -- Do nothing, user is already at the cap.
    RETURN;
  END IF;

  -- Business Rule 2: Ensure at least 20 hours have passed since the last grant.
  -- The client-side timer is just a guide; the server is the source of truth.
  IF last_grant_time IS NOT NULL THEN
    time_since_last_grant := now() - last_grant_time;
    IF time_since_last_grant < interval '20 hours' THEN
      -- Do nothing, it has not been long enough.
      RETURN;
    END IF;
  END IF;

  -- If all checks pass, grant one like and update the timestamp.
  UPDATE public.profiles
  SET
    like_count = like_count + 1,
    last_like_granted_at = now()
  WHERE id = auth.uid();

END;
$$;


ALTER FUNCTION "public"."request_daily_like"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_super_like"("p_liked_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  UPDATE public.likes
  SET
    super_like_level = 0
  WHERE
    user_id = auth.uid() AND
    liked_user_id = p_liked_user_id;
END;
$$;


ALTER FUNCTION "public"."reset_super_like"("p_liked_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."roll_monthly_poll"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  ended_poll public.polls%rowtype;
  win public.poll_options%rowtype;
  new_poll_id uuid;
  pool_item public.poll_option_pool%rowtype;
  mon_start timestamptz := date_trunc('month', now());
  mon_end   timestamptz := date_trunc('month', now()) + interval '1 month' - interval '1 second';
begin
  if exists (select 1 from public.polls where start_date = mon_start) then
    return;  -- this month's poll already exists
  end if;

  select * into ended_poll from public.polls where end_date < now() order by end_date desc limit 1;

  new_poll_id := gen_random_uuid();
  insert into public.polls (id, title, start_date, end_date)
  values (new_poll_id, to_char(now(),'FMMonth YYYY') || ' Community Poll', mon_start, mon_end);

  if ended_poll.id is null then
    for pool_item in select * from public.poll_option_pool where used_at is null order by position limit 3 loop
      insert into public.poll_options (poll_id, title, subtitle, votes) values (new_poll_id, pool_item.title, pool_item.subtitle, 0);
      update public.poll_option_pool set used_at = now() where id = pool_item.id;
    end loop;
    return;
  end if;

  select * into win from public.poll_options where poll_id = ended_poll.id order by votes desc limit 1;

  if win.id is not null and win.votes > 10 then
    insert into public.poll_winners (poll_id, title, subtitle, votes) values (ended_poll.id, win.title, win.subtitle, win.votes);
    insert into public.poll_options (poll_id, title, subtitle, votes)
      select new_poll_id, title, subtitle, 0 from public.poll_options where poll_id = ended_poll.id and id <> win.id;
    select * into pool_item from public.poll_option_pool where used_at is null order by position limit 1;
    if pool_item.id is not null then
      insert into public.poll_options (poll_id, title, subtitle, votes) values (new_poll_id, pool_item.title, pool_item.subtitle, 0);
      update public.poll_option_pool set used_at = now() where id = pool_item.id;
    else
      insert into public.poll_options (poll_id, title, subtitle, votes) values (new_poll_id, win.title, win.subtitle, 0);
    end if;
  else
    insert into public.poll_options (poll_id, title, subtitle, votes)
      select new_poll_id, title, subtitle, 0 from public.poll_options where poll_id = ended_poll.id;
  end if;
end;
$$;


ALTER FUNCTION "public"."roll_monthly_poll"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_otm"("p_receiver_id" "uuid", "p_message" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  INSERT INTO public.messages (sender_id, receiver_id, content, is_one_time_message)
  VALUES (v_user_id, p_receiver_id, p_message, true);
END;
$$;


ALTER FUNCTION "public"."send_otm"("p_receiver_id" "uuid", "p_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unmatch_and_delete_conversation"("user_id1" "uuid", "user_id2" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  -- Delete the likes between the two users
  DELETE FROM likes
  WHERE (user_id = user_id1 AND liked_user_id = user_id2)
     OR (user_id = user_id2 AND liked_user_id = user_id1);

  -- Delete the messages between the two users
  DELETE FROM messages
  WHERE (sender_id = user_id1 AND receiver_id = user_id2)
     OR (sender_id = user_id2 AND receiver_id = user_id1);
END;
$$;


ALTER FUNCTION "public"."unmatch_and_delete_conversation"("user_id1" "uuid", "user_id2" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unmatch_users"("p_user_one_id" "uuid", "p_user_two_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
    -- 1. Remove the likes between the two users
    DELETE FROM public.likes
    WHERE (user_id = p_user_one_id AND liked_user_id = p_user_two_id)
       OR (user_id = p_user_two_id AND liked_user_id = p_user_one_id);

    -- 2. Delete the entire message history between them
    DELETE FROM public.messages
    WHERE (sender_id = p_user_one_id AND receiver_id = p_user_two_id)
       OR (sender_id = p_user_two_id AND receiver_id = p_user_one_id);

    -- 3. Add dislikes for both users to prevent them from seeing each other again
    INSERT INTO public.dislikes (user_id, disliked_user_id)
    VALUES (p_user_one_id, p_user_two_id)
    ON CONFLICT (user_id, disliked_user_id) DO NOTHING;

    INSERT INTO public.dislikes (user_id, disliked_user_id)
    VALUES (p_user_two_id, p_user_one_id)
    ON CONFLICT (user_id, disliked_user_id) DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."unmatch_users"("p_user_one_id" "uuid", "p_user_two_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_last_seen"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    UPDATE public.profiles
    SET last_seen = NOW()
    WHERE id = auth.uid();
  END IF;
END;
$$;


ALTER FUNCTION "public"."update_last_seen"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blocks" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "blocker_id" "uuid" NOT NULL,
    "blocked_id" "uuid" NOT NULL
);


ALTER TABLE "public"."blocks" OWNER TO "postgres";


ALTER TABLE "public"."blocks" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."blocks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."daaymn_idiology" (
    "id" integer NOT NULL,
    "headline" "text" NOT NULL,
    "body" "text" NOT NULL
);


ALTER TABLE "public"."daaymn_idiology" OWNER TO "postgres";


COMMENT ON TABLE "public"."daaymn_idiology" IS 'Stores the core brand philosophy phrases for use in the app.';



CREATE SEQUENCE IF NOT EXISTS "public"."daaymn_idiology_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."daaymn_idiology_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."daaymn_idiology_id_seq" OWNED BY "public"."daaymn_idiology"."id";



CREATE TABLE IF NOT EXISTS "public"."dislikes" (
    "user_id" "uuid" NOT NULL,
    "disliked_user_id" "uuid" NOT NULL,
    "dislike_count" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."dislikes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."google_purchases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "product_id" "text" NOT NULL,
    "token" "text" NOT NULL,
    "consumed_at" timestamp with time zone,
    "verification_response" "jsonb",
    "consume_response" "jsonb",
    "inserted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."google_purchases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."likes" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "liked_user_id" "uuid" NOT NULL,
    "super_like_level" integer DEFAULT 0
);


ALTER TABLE "public"."likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."likes_bought" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "likes_purchased" integer NOT NULL,
    "price_paid_cents" integer,
    "currency" "text",
    "store_receipt_id" "text",
    CONSTRAINT "likes_bought_likes_purchased_check" CHECK (("likes_purchased" > 0))
);


ALTER TABLE "public"."likes_bought" OWNER TO "postgres";


ALTER TABLE "public"."likes_bought" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."likes_bought_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."likes" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."likes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."messages" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."messages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."poll_option_pool" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "subtitle" "text" NOT NULL,
    "position" integer NOT NULL,
    "used_at" timestamp with time zone
);


ALTER TABLE "public"."poll_option_pool" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."poll_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "poll_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "subtitle" "text",
    "votes" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."poll_options" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."poll_votes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "poll_id" "uuid" NOT NULL,
    "option_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."poll_votes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."poll_winners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "poll_id" "uuid",
    "title" "text",
    "subtitle" "text",
    "votes" integer,
    "won_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."poll_winners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."polls" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."polls" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."preregistrations" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" "text"
);


ALTER TABLE "public"."preregistrations" OWNER TO "postgres";


COMMENT ON TABLE "public"."preregistrations" IS 'Emails for pre-launch';



ALTER TABLE "public"."preregistrations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."preregistrations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."problem_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."problem_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."processed_orders" (
    "order_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."processed_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text" NOT NULL,
    "age" integer NOT NULL,
    "image_urls" "text"[],
    "gender" "text",
    "pronouns" "text",
    "ethnicity" "text",
    "location" "extensions"."geography"(Point,4326),
    "work" "jsonb",
    "religion" "jsonb",
    "height_cm" "jsonb",
    "weight_kg" "jsonb",
    "fcm_token" "text",
    "like_count" integer DEFAULT 6,
    "best_photo_index" integer,
    "dominant_hand" "jsonb",
    "device_preference" "jsonb",
    "updated_at" timestamp with time zone,
    "public_key" "text",
    "interested_in" "text"[],
    "bio_topics" "jsonb" DEFAULT '{}'::"jsonb",
    "city" "text",
    "last_like_granted_at" timestamp with time zone,
    "is_verified" boolean DEFAULT false NOT NULL,
    "last_seen" timestamp with time zone,
    "metric_system" "text",
    "is_ghost_mode_enabled" boolean DEFAULT false,
    "infinite_scroll_until" timestamp with time zone,
    "ghost_mode_until" timestamp with time zone,
    "last_ad_like_at" timestamp with time zone,
    "last_ad_scroll_at" timestamp with time zone,
    "last_ad_ghost_at" timestamp with time zone,
    "subscription_tier" "text",
    "subscription_expires_at" timestamp with time zone,
    "store_transaction_id" "text",
    "monthly_report_credit_tier" "text",
    "has_claimed_monthly_report" boolean DEFAULT false,
    "one_time_report_credits" "jsonb" DEFAULT '{}'::"jsonb",
    "last_free_report_claimed_at" timestamp with time zone,
    "last_claimed_score" double precision,
    "purchased_ghost_mode_until" timestamp with time zone,
    "purchased_infinite_scroll_until" timestamp with time zone,
    "obfuscated_external_account_id" "text",
    "is_seed_profile" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'Stores public user profile information.';



COMMENT ON COLUMN "public"."profiles"."location" IS 'Stores user location for matching. Requires PostGIS.';



COMMENT ON COLUMN "public"."profiles"."work" IS 'Stores work information as {"value": "string", "show": boolean}';



CREATE TABLE IF NOT EXISTS "public"."promo_codes" (
    "id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "product_id" "text" NOT NULL,
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "times_used" integer DEFAULT 0 NOT NULL,
    "max_uses" integer
);


ALTER TABLE "public"."promo_codes" OWNER TO "postgres";


COMMENT ON TABLE "public"."promo_codes" IS 'Stores promo codes that can be redeemed by users for in-app items.';



COMMENT ON COLUMN "public"."promo_codes"."times_used" IS 'The number of times this promo code has been redeemed.';



COMMENT ON COLUMN "public"."promo_codes"."max_uses" IS 'The maximum number of times this code can be used. NULL means infinite.';



ALTER TABLE "public"."promo_codes" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."promo_codes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."purchases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "likes_purchased" integer NOT NULL,
    "price_paid_cents" integer NOT NULL,
    "currency" character varying(3) NOT NULL,
    "store_receipt_id" "text"
);


ALTER TABLE "public"."purchases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reports" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reported_id" "uuid" NOT NULL,
    "reasons" "text"[],
    "custom_reason" "text",
    "notes" "text"
);


ALTER TABLE "public"."reports" OWNER TO "postgres";


ALTER TABLE "public"."reports" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."reports_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."typing_status" (
    "chat_room_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."typing_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_blocks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "blocked_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "no_self_block" CHECK (("user_id" <> "blocked_user_id"))
);


ALTER TABLE "public"."user_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."verified_reports" (
    "id" "text" NOT NULL,
    "user_id" "uuid",
    "user_name" "text",
    "score" real,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."verified_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."verified_signatures" (
    "id" bigint NOT NULL,
    "signature" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."verified_signatures" OWNER TO "postgres";


ALTER TABLE "public"."verified_signatures" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."verified_signatures_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."daaymn_idiology" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."daaymn_idiology_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_unique_relation" UNIQUE ("blocker_id", "blocked_id");



ALTER TABLE ONLY "public"."daaymn_idiology"
    ADD CONSTRAINT "daaymn_idiology_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dislikes"
    ADD CONSTRAINT "dislikes_pkey" PRIMARY KEY ("user_id", "disliked_user_id");



ALTER TABLE ONLY "public"."google_purchases"
    ADD CONSTRAINT "google_purchases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."google_purchases"
    ADD CONSTRAINT "google_purchases_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."likes_bought"
    ADD CONSTRAINT "likes_bought_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_user_id_liked_user_id_key" UNIQUE ("user_id", "liked_user_id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."poll_votes"
    ADD CONSTRAINT "one_vote_per_user_per_poll" UNIQUE ("user_id", "poll_id");



ALTER TABLE ONLY "public"."poll_option_pool"
    ADD CONSTRAINT "poll_option_pool_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."poll_options"
    ADD CONSTRAINT "poll_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."poll_votes"
    ADD CONSTRAINT "poll_votes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."poll_winners"
    ADD CONSTRAINT "poll_winners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."polls"
    ADD CONSTRAINT "polls_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."preregistrations"
    ADD CONSTRAINT "preregistrations_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."preregistrations"
    ADD CONSTRAINT "preregistrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."problem_reports"
    ADD CONSTRAINT "problem_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."processed_orders"
    ADD CONSTRAINT "processed_orders_pkey" PRIMARY KEY ("order_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."promo_codes"
    ADD CONSTRAINT "promo_codes_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."promo_codes"
    ADD CONSTRAINT "promo_codes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchases"
    ADD CONSTRAINT "purchases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."typing_status"
    ADD CONSTRAINT "typing_status_pkey" PRIMARY KEY ("chat_room_id", "user_id");



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_user_id_blocked_user_id_key" UNIQUE ("user_id", "blocked_user_id");



ALTER TABLE ONLY "public"."verified_reports"
    ADD CONSTRAINT "verified_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verified_signatures"
    ADD CONSTRAINT "verified_signatures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verified_signatures"
    ADD CONSTRAINT "verified_signatures_signature_key" UNIQUE ("signature");



CREATE INDEX "idx_blocks_blocked_id" ON "public"."blocks" USING "btree" ("blocked_id");



CREATE INDEX "idx_dislikes_disliked_user_id" ON "public"."dislikes" USING "btree" ("disliked_user_id");



CREATE INDEX "idx_google_purchases_token" ON "public"."google_purchases" USING "btree" ("token");



CREATE INDEX "idx_google_purchases_user" ON "public"."google_purchases" USING "btree" ("user_id");



CREATE INDEX "idx_likes_bought_user_id" ON "public"."likes_bought" USING "btree" ("user_id");



CREATE INDEX "idx_likes_liked_user_id" ON "public"."likes" USING "btree" ("liked_user_id");



CREATE INDEX "idx_messages_receiver_id" ON "public"."messages" USING "btree" ("receiver_id");



CREATE INDEX "idx_messages_sender_id" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "idx_profiles_obfuscated_id" ON "public"."profiles" USING "btree" ("obfuscated_external_account_id");



CREATE INDEX "idx_purchases_user_id" ON "public"."purchases" USING "btree" ("user_id");



CREATE INDEX "idx_reports_reported_id" ON "public"."reports" USING "btree" ("reported_id");



CREATE INDEX "idx_reports_reporter_id" ON "public"."reports" USING "btree" ("reporter_id");



CREATE INDEX "idx_user_blocks_blocked_user_id" ON "public"."user_blocks" USING "btree" ("blocked_user_id");



CREATE OR REPLACE TRIGGER "new_like_webhook" AFTER INSERT ON "public"."likes" FOR EACH ROW EXECUTE FUNCTION "public"."on_new_like"();



CREATE OR REPLACE TRIGGER "on_new_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_message"();



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dislikes"
    ADD CONSTRAINT "dislikes_disliked_user_id_fkey" FOREIGN KEY ("disliked_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dislikes"
    ADD CONSTRAINT "dislikes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."likes_bought"
    ADD CONSTRAINT "likes_bought_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_liked_user_id_fkey" FOREIGN KEY ("liked_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_receiver_id_fkey" FOREIGN KEY ("receiver_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."poll_options"
    ADD CONSTRAINT "poll_options_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "public"."polls"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."poll_votes"
    ADD CONSTRAINT "poll_votes_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "public"."poll_options"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."poll_votes"
    ADD CONSTRAINT "poll_votes_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "public"."polls"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."poll_votes"
    ADD CONSTRAINT "poll_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purchases"
    ADD CONSTRAINT "purchases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reported_id_fkey" FOREIGN KEY ("reported_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_blocked_user_id_fkey" FOREIGN KEY ("blocked_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_blocks"
    ADD CONSTRAINT "user_blocks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verified_reports"
    ADD CONSTRAINT "verified_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Allow anonymous inserts" ON "public"."preregistrations" FOR INSERT TO "anon" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to view profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow public read access" ON "public"."verified_reports" FOR SELECT USING (true);



CREATE POLICY "Allow public read access to poll options" ON "public"."poll_options" FOR SELECT USING (true);



CREATE POLICY "Allow public read access to polls" ON "public"."polls" FOR SELECT USING (true);



CREATE POLICY "Allow users to cast their own vote" ON "public"."poll_votes" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Allow users to create their own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Allow users to delete their own dislikes" ON "public"."dislikes" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Allow users to insert their own dislikes" ON "public"."dislikes" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Allow users to insert their own likes" ON "public"."likes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Allow users to insert their own reports" ON "public"."verified_reports" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Allow users to read their own votes" ON "public"."poll_votes" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Allow users to see their own dislikes" ON "public"."dislikes" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Allow users to send messages" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "sender_id"));



CREATE POLICY "Allow users to update their own dislike count" ON "public"."dislikes" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Allow users to update their own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Allow users to update their received messages" ON "public"."messages" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "receiver_id"));



CREATE POLICY "Allow users to upsert their own typing status" ON "public"."typing_status" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Allow users to view their own likes" ON "public"."likes" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (( SELECT "auth"."uid"() AS "uid") = "liked_user_id")));



CREATE POLICY "Authenticated users can view typing status" ON "public"."typing_status" FOR SELECT USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "Consolidated: users can view their own messages" ON "public"."messages" FOR SELECT USING (((( SELECT "auth"."uid"() AS "uid") = "sender_id") OR (( SELECT "auth"."uid"() AS "uid") = "receiver_id")));



CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Public read" ON "public"."typing_status" FOR SELECT USING (true);



CREATE POLICY "Users can block others" ON "public"."blocks" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "blocker_id"));



CREATE POLICY "Users can create blocks" ON "public"."user_blocks" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own blocks" ON "public"."user_blocks" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can see their own blocks" ON "public"."blocks" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "blocker_id"));



CREATE POLICY "Users can submit reports" ON "public"."reports" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "reporter_id"));



CREATE POLICY "Users can unblock people" ON "public"."blocks" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "blocker_id"));



CREATE POLICY "Users can update their own profile." ON "public"."profiles" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can view their own blocks" ON "public"."user_blocks" FOR SELECT USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (( SELECT "auth"."uid"() AS "uid") = "blocked_user_id")));



CREATE POLICY "Users can view their own purchases" ON "public"."likes_bought" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."blocks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daaymn_idiology" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dislikes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."google_purchases" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "insert own report" ON "public"."problem_reports" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."likes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."likes_bought" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."poll_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."poll_votes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."polls" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."preregistrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."problem_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."processed_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."promo_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."typing_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_blocks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."verified_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."verified_signatures" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."blocks";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."dislikes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."likes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."poll_options";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."profiles";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."typing_status";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































GRANT ALL ON FUNCTION "public"."accept_like"("p_other_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_like"("p_other_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_like"("p_other_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_likes"("quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_likes"("quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_likes"("quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cast_vote"("poll_option_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cast_vote"("poll_option_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cast_vote"("poll_option_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."claim_free_monthly_report"() TO "anon";
GRANT ALL ON FUNCTION "public"."claim_free_monthly_report"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_free_monthly_report"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_like_and_remove_dislike"("p_liked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_like_and_remove_dislike"("p_liked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_like_and_remove_dislike"("p_liked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_like_and_update_otm_counter"("p_liked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_like_and_update_otm_counter"("p_liked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_like_and_update_otm_counter"("p_liked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."debug_reset_ad_timestamps"() TO "anon";
GRANT ALL ON FUNCTION "public"."debug_reset_ad_timestamps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."debug_reset_ad_timestamps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_like_on_new_like"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_like_on_new_like"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_like_on_new_like"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_report_credit"("user_id_in" "uuid", "tier_in" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_report_credit"("user_id_in" "uuid", "tier_in" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_report_credit"("user_id_in" "uuid", "tier_in" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_user_like_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_user_like_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_user_like_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_user_like_count"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_user_like_count"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_user_like_count"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_otm"("message_id_to_delete" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."delete_otm"("message_id_to_delete" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_otm"("message_id_to_delete" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_blocked_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_blocked_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_blocked_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_blocked_users"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_last_months_winning_poll"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_last_months_winning_poll"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_last_months_winning_poll"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_matches_count"("p_user_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_matches_count"("p_user_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_matches_count"("p_user_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_matches_with_no_messages_count"("p_user_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_matches_with_no_messages_count"("p_user_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_matches_with_no_messages_count"("p_user_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_notification_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_notification_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_notification_counts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_random_daaymn_idiology"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_random_daaymn_idiology"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_random_daaymn_idiology"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_server_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_server_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_server_timestamp"() TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unblocked_otms"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_unblocked_otms"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unblocked_otms"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."grant_likes"("user_id" "uuid", "num_likes" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."grant_likes"("user_id" "uuid", "num_likes" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."grant_likes"("user_id" "uuid", "num_likes" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_block"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_block"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_block"("p_blocker_id" "uuid", "p_blocked_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_expired_like"("p_user_id" "uuid", "p_liked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_expired_like"("p_user_id" "uuid", "p_liked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_expired_like"("p_user_id" "uuid", "p_liked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_like"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_like"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_like"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_profile_upsert"("profile_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_profile_upsert"("profile_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_profile_upsert"("profile_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."has_message_history"("p_user1_id" "uuid", "p_user2_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."has_message_history"("p_user1_id" "uuid", "p_user2_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_message_history"("p_user1_id" "uuid", "p_user2_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_dislike"("p_disliked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_dislike"("p_disliked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_dislike"("p_disliked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_dislike"("p_user_id" "uuid", "p_disliked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_dislike"("p_user_id" "uuid", "p_disliked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_dislike"("p_user_id" "uuid", "p_disliked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_report_credit"("user_id_in" "uuid", "tier_in" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_report_credit"("user_id_in" "uuid", "tier_in" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_report_credit"("user_id_in" "uuid", "tier_in" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_super_like"("p_liked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_super_like"("p_liked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_super_like"("p_liked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."nuke_connection"("p_user_a_id" "uuid", "p_user_b_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."nuke_connection"("p_user_a_id" "uuid", "p_user_b_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."nuke_connection"("p_user_a_id" "uuid", "p_user_b_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."on_new_like"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_new_like"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_new_like"() TO "service_role";



GRANT ALL ON FUNCTION "public"."purchase_likes"("p_likes_to_add" integer, "p_price_paid_cents" integer, "p_currency" "text", "p_store_receipt_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."purchase_likes"("p_likes_to_add" integer, "p_price_paid_cents" integer, "p_currency" "text", "p_store_receipt_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."purchase_likes"("p_likes_to_add" integer, "p_price_paid_cents" integer, "p_currency" "text", "p_store_receipt_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."redeem_code_atomic"("p_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."redeem_code_atomic"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."redeem_code_atomic"("p_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."reject_otm_and_like"("p_message_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."reject_otm_and_like"("p_message_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."reject_otm_and_like"("p_message_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."reject_otm_and_like"("p_message_id" "uuid", "p_rejecter_id" "uuid", "p_sender_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reject_otm_and_like"("p_message_id" "uuid", "p_rejecter_id" "uuid", "p_sender_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reject_otm_and_like"("p_message_id" "uuid", "p_rejecter_id" "uuid", "p_sender_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."request_daily_like"() TO "anon";
GRANT ALL ON FUNCTION "public"."request_daily_like"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_daily_like"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_super_like"("p_liked_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_super_like"("p_liked_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_super_like"("p_liked_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."roll_monthly_poll"() TO "anon";
GRANT ALL ON FUNCTION "public"."roll_monthly_poll"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."roll_monthly_poll"() TO "service_role";



GRANT ALL ON FUNCTION "public"."send_otm"("p_receiver_id" "uuid", "p_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."send_otm"("p_receiver_id" "uuid", "p_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_otm"("p_receiver_id" "uuid", "p_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."unmatch_and_delete_conversation"("user_id1" "uuid", "user_id2" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."unmatch_and_delete_conversation"("user_id1" "uuid", "user_id2" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unmatch_and_delete_conversation"("user_id1" "uuid", "user_id2" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unmatch_users"("p_user_one_id" "uuid", "p_user_two_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."unmatch_users"("p_user_one_id" "uuid", "p_user_two_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unmatch_users"("p_user_one_id" "uuid", "p_user_two_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_last_seen"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_last_seen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_last_seen"() TO "service_role";























































































GRANT ALL ON TABLE "public"."blocks" TO "anon";
GRANT ALL ON TABLE "public"."blocks" TO "authenticated";
GRANT ALL ON TABLE "public"."blocks" TO "service_role";



GRANT ALL ON SEQUENCE "public"."blocks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."blocks_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."blocks_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."daaymn_idiology" TO "anon";
GRANT ALL ON TABLE "public"."daaymn_idiology" TO "authenticated";
GRANT ALL ON TABLE "public"."daaymn_idiology" TO "service_role";



GRANT ALL ON SEQUENCE "public"."daaymn_idiology_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."daaymn_idiology_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."daaymn_idiology_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."dislikes" TO "anon";
GRANT ALL ON TABLE "public"."dislikes" TO "authenticated";
GRANT ALL ON TABLE "public"."dislikes" TO "service_role";



GRANT ALL ON TABLE "public"."google_purchases" TO "anon";
GRANT ALL ON TABLE "public"."google_purchases" TO "authenticated";
GRANT ALL ON TABLE "public"."google_purchases" TO "service_role";



GRANT ALL ON TABLE "public"."likes" TO "anon";
GRANT ALL ON TABLE "public"."likes" TO "authenticated";
GRANT ALL ON TABLE "public"."likes" TO "service_role";



GRANT ALL ON TABLE "public"."likes_bought" TO "anon";
GRANT ALL ON TABLE "public"."likes_bought" TO "authenticated";
GRANT ALL ON TABLE "public"."likes_bought" TO "service_role";



GRANT ALL ON SEQUENCE "public"."likes_bought_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."likes_bought_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."likes_bought_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."likes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."likes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."likes_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."messages_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."messages_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."messages_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."poll_option_pool" TO "anon";
GRANT ALL ON TABLE "public"."poll_option_pool" TO "authenticated";
GRANT ALL ON TABLE "public"."poll_option_pool" TO "service_role";



GRANT ALL ON TABLE "public"."poll_options" TO "anon";
GRANT ALL ON TABLE "public"."poll_options" TO "authenticated";
GRANT ALL ON TABLE "public"."poll_options" TO "service_role";



GRANT ALL ON TABLE "public"."poll_votes" TO "anon";
GRANT ALL ON TABLE "public"."poll_votes" TO "authenticated";
GRANT ALL ON TABLE "public"."poll_votes" TO "service_role";



GRANT ALL ON TABLE "public"."poll_winners" TO "anon";
GRANT ALL ON TABLE "public"."poll_winners" TO "authenticated";
GRANT ALL ON TABLE "public"."poll_winners" TO "service_role";



GRANT ALL ON TABLE "public"."polls" TO "anon";
GRANT ALL ON TABLE "public"."polls" TO "authenticated";
GRANT ALL ON TABLE "public"."polls" TO "service_role";



GRANT ALL ON TABLE "public"."preregistrations" TO "anon";
GRANT ALL ON TABLE "public"."preregistrations" TO "authenticated";
GRANT ALL ON TABLE "public"."preregistrations" TO "service_role";



GRANT ALL ON SEQUENCE "public"."preregistrations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."preregistrations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."preregistrations_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."problem_reports" TO "anon";
GRANT ALL ON TABLE "public"."problem_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."problem_reports" TO "service_role";



GRANT ALL ON TABLE "public"."processed_orders" TO "anon";
GRANT ALL ON TABLE "public"."processed_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."processed_orders" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."promo_codes" TO "anon";
GRANT ALL ON TABLE "public"."promo_codes" TO "authenticated";
GRANT ALL ON TABLE "public"."promo_codes" TO "service_role";



GRANT ALL ON SEQUENCE "public"."promo_codes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."promo_codes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."promo_codes_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."purchases" TO "anon";
GRANT ALL ON TABLE "public"."purchases" TO "authenticated";
GRANT ALL ON TABLE "public"."purchases" TO "service_role";



GRANT ALL ON TABLE "public"."reports" TO "anon";
GRANT ALL ON TABLE "public"."reports" TO "authenticated";
GRANT ALL ON TABLE "public"."reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."reports_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."typing_status" TO "anon";
GRANT ALL ON TABLE "public"."typing_status" TO "authenticated";
GRANT ALL ON TABLE "public"."typing_status" TO "service_role";



GRANT ALL ON TABLE "public"."user_blocks" TO "anon";
GRANT ALL ON TABLE "public"."user_blocks" TO "authenticated";
GRANT ALL ON TABLE "public"."user_blocks" TO "service_role";



GRANT ALL ON TABLE "public"."verified_reports" TO "anon";
GRANT ALL ON TABLE "public"."verified_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."verified_reports" TO "service_role";



GRANT ALL ON TABLE "public"."verified_signatures" TO "anon";
GRANT ALL ON TABLE "public"."verified_signatures" TO "authenticated";
GRANT ALL ON TABLE "public"."verified_signatures" TO "service_role";



GRANT ALL ON SEQUENCE "public"."verified_signatures_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."verified_signatures_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."verified_signatures_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































