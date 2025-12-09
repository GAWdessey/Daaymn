-- Seed Poll Data for Previous Month
DO $$
DECLARE
    last_month_poll_id UUID := gen_random_uuid();
BEGIN
    -- Create a poll for last month
    INSERT INTO public.polls (id, title, start_date, end_date)
    VALUES (
        last_month_poll_id,
        'January Community Poll',
        date_trunc('month', now()) - interval '1 month',
        date_trunc('month', now()) - interval '1 second'
    );

    -- Insert options for last month's poll, with the winner having the most votes
    INSERT INTO public.poll_options (poll_id, title, subtitle, votes)
    VALUES
        (last_month_poll_id, 'Add read receipts to the messages', 'See when your messages have been read.', 150),
        (last_month_poll_id, 'New profile photo filters', 'Add some fun new filters for profile pictures.', 75),
        (last_month_poll_id, 'More profile badges', 'Introduce new badges for achievements.', 50);
END;
$$;

-- Seed Poll Data for Current Month
DO $$
DECLARE
    current_month_poll_id UUID := gen_random_uuid();
BEGIN
    -- Create a poll for the current month
    INSERT INTO public.polls (id, title, start_date, end_date)
    VALUES (
        current_month_poll_id,
        'February Community Poll',
        date_trunc('month', now()),
        date_trunc('month', now()) + interval '1 month' - interval '1 second'
    );

    -- Insert options for the current month's poll
    INSERT INTO public.poll_options (poll_id, title, subtitle, votes)
    VALUES
        (current_month_poll_id, 'More detailed user profiles', 'Add more fields to user profiles, like education and hobbies.', 0),
        (current_month_poll_id, 'New icebreaker games', 'Add fun games to help start conversations.', 0),
        (current_month_poll_id, 'Gift: 5 likes for every user', 'A free gift of 5 likes for all users.', 0);
END;
$$;