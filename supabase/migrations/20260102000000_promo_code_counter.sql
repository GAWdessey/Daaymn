-- First, drop the old columns no longer needed
ALTER TABLE public.promo_codes
DROP COLUMN is_used,
DROP COLUMN used_at;

-- Then, add the new columns for tracking usage
ALTER TABLE public.promo_codes
ADD COLUMN times_used INT NOT NULL DEFAULT 0,
ADD COLUMN max_uses INT; -- NULL means infinite uses

COMMENT ON COLUMN public.promo_codes.times_used IS 'The number of times this promo code has been redeemed.';
COMMENT ON COLUMN public.promo_codes.max_uses IS 'The maximum number of times this code can be used. NULL means infinite.';


-- Create a secure, atomic function to redeem a code
CREATE OR REPLACE FUNCTION redeem_code_atomic(p_code TEXT)
RETURNS TABLE (product_id TEXT, error_message TEXT)
SECURITY DEFINER
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
$$ LANGUAGE plpgsql;
