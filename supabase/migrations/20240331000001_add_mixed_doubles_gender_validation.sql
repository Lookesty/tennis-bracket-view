-- Drop existing function
DROP FUNCTION IF EXISTS link_doubles_partners_by_passphrase;

-- Function to link partners using passphrase
CREATE OR REPLACE FUNCTION link_doubles_partners_by_passphrase(
    p_registration_id uuid,
    p_tournament_id uuid,
    p_category jsonb,
    p_passphrase text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_partner_registration_id uuid;
    v_existing_passphrase record;
    v_category_key text;
    v_partner_category_reg record;
    v_current_player_gender text;
    v_partner_player_gender text;
    v_is_mixed_doubles boolean;
BEGIN
    -- Generate the category key based on whether p_category is a string or object
    IF jsonb_typeof(p_category) = 'string' THEN
        v_category_key := p_category#>>'{}';  -- Extract the string value from JSONB
        v_is_mixed_doubles := v_category_key ILIKE '%mixed%';
    ELSE
        v_category_key := (p_category->>'gender') || '_' || (p_category->>'type') || '_' || COALESCE(p_category->>'ageGroup', '');
        v_is_mixed_doubles := (p_category->>'gender') = 'mixed';
    END IF;

    -- Check if passphrase exists for this tournament and category
    SELECT * INTO v_existing_passphrase
    FROM partner_passphrases
    WHERE tournament_id = p_tournament_id 
    AND category = v_category_key 
    AND passphrase = p_passphrase
    AND registration_ids[1] != p_registration_id;  -- Don't match with self

    IF NOT FOUND THEN
        -- First partner registering with this passphrase
        INSERT INTO partner_passphrases (tournament_id, category, passphrase, registration_ids)
        VALUES (p_tournament_id, v_category_key, p_passphrase, ARRAY[p_registration_id]);
        
        -- Keep registration status as pending while waiting for partner
        UPDATE registration_categories
        SET status = 'pending'
        WHERE registration_id = p_registration_id
        AND category @> p_category
        AND category <@ p_category;

        RETURN jsonb_build_object(
            'status', 'waiting_for_partner',
            'category', v_category_key
        );
    END IF;

    -- Check if this passphrase already has two partners
    IF array_length(v_existing_passphrase.registration_ids, 1) >= 2 THEN
        RAISE EXCEPTION 'This passphrase has already been used by two partners';
    END IF;

    -- Check if this registration is already linked
    IF p_registration_id = ANY(v_existing_passphrase.registration_ids) THEN
        RAISE EXCEPTION 'You are already registered with this passphrase';
    END IF;

    -- Get the partner's registration ID
    SELECT registration_ids[1] INTO v_partner_registration_id
    FROM partner_passphrases
    WHERE id = v_existing_passphrase.id;

    -- Get the partner's category registration
    SELECT * INTO v_partner_category_reg
    FROM registration_categories
    WHERE registration_id = v_partner_registration_id
    AND category @> p_category
    AND category <@ p_category;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Partner registration not found for this category';
    END IF;

    -- For mixed doubles, verify that partners are of opposite genders
    IF v_is_mixed_doubles THEN
        -- Get current player's gender
        SELECT LOWER(player_info->>'gender') INTO v_current_player_gender
        FROM tournament_registrations_dev
        WHERE id = p_registration_id;

        -- Get partner's gender
        SELECT LOWER(player_info->>'gender') INTO v_partner_player_gender
        FROM tournament_registrations_dev
        WHERE id = v_partner_registration_id;

        -- Check if genders are the same
        IF v_current_player_gender = v_partner_player_gender THEN
            RAISE EXCEPTION 'Mixed doubles partners must be of opposite genders';
        END IF;
    END IF;

    -- Update passphrase record with second registration
    UPDATE partner_passphrases
    SET registration_ids = array_append(registration_ids, p_registration_id)
    WHERE id = v_existing_passphrase.id;

    -- Keep both registrations in pending status until approved by admin
    UPDATE registration_categories
    SET status = 'pending'
    WHERE (registration_id = p_registration_id OR registration_id = v_partner_registration_id)
    AND category @> p_category
    AND category <@ p_category;

    -- Link both registrations
    UPDATE tournament_registrations_dev
    SET partner_links = COALESCE(partner_links, '{}'::jsonb) || 
        jsonb_build_object(v_category_key, p_registration_id)
    WHERE id = v_partner_registration_id;

    UPDATE tournament_registrations_dev
    SET partner_links = COALESCE(partner_links, '{}'::jsonb) || 
        jsonb_build_object(v_category_key, v_partner_registration_id)
    WHERE id = p_registration_id;

    RETURN jsonb_build_object(
        'status', 'partner_linked',
        'category', v_category_key,
        'partner_id', v_partner_registration_id
    );
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION link_doubles_partners_by_passphrase TO authenticated; 