CREATE OR REPLACE FUNCTION handle_expired_like(p_user_id UUID, p_liked_user_id UUID)
RETURNS void AS $$
BEGIN
  -- Delete the like
  DELETE FROM public.likes
  WHERE user_id = p_user_id AND liked_user_id = p_liked_user_id;

  -- Delete the corresponding notification
  DELETE FROM public.notifications
  WHERE notifier_id = p_user_id AND user_id = p_liked_user_id AND type = 'new_like';
END;
$$ LANGUAGE plpgsql;