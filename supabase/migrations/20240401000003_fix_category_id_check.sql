-- Drop existing function
DROP FUNCTION IF EXISTS handle_category_registration(uuid, uuid, text, text);

-- Recreate function with fixed category check
CREATE OR REPLACE FUNCTION handle_category_registration(
    registration_id uuid,
    tournament_id uuid,
    category_id text,
    passphrase text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
    player_info jsonb;
    existing_registration RECORD;
    is_doubles boolean;
    result jsonb;
BEGIN
    -- Get player info from registration
    SELECT tr.player_info INTO player_info
    FROM tournament_registrations_dev tr
    WHERE tr.id = registration_id;

    -- Check if this is a doubles category
    SELECT EXISTS (
        SELECT 1 
        FROM tennis_events te,
        jsonb_array_elements(te.categories::jsonb) cat
        WHERE te.id = tournament_id
        AND cat->>'type' ILIKE '%doubles%'
        AND (
            -- Check both ways: either the category_id matches directly
            -- or construct it from the category components
            category_id = LOWER(
                COALESCE(cat->>'gender', '') || '_' ||
                COALESCE(cat->>'type', '') || '_' ||
                COALESCE(cat->>'ageGroup', 'open')
            )
        )
    ) INTO is_doubles;

    -- Check if player already registered in this category
    SELECT cr.* INTO existing_registration
    FROM category_registrations cr
    WHERE cr.tournament_id = tournament_id
    AND cr.category_id = category_id
    AND (
        cr.player1_registration_id = registration_id
        OR cr.player2_registration_id = registration_id
    );

    IF FOUND THEN
        RAISE EXCEPTION 'Player already registered in this category';
    END IF;

    -- Handle singles registration
    IF NOT is_doubles THEN
        INSERT INTO category_registrations (
            tournament_id,
            category_id,
            player1_registration_id,
            status
        ) VALUES (
            tournament_id,
            category_id,
            registration_id,
            'pending'::category_registration_status
        )
        RETURNING jsonb_build_object(
            'status', status,
            'message', 'Singles registration created successfully',
            'category_type', 'singles'
        ) INTO result;

        RETURN result;
    END IF;

    -- Handle doubles registration
    IF passphrase IS NULL THEN
        RAISE EXCEPTION 'Passphrase is required for doubles categories';
    END IF;

    -- Check if passphrase exists
    SELECT cr.* INTO existing_registration
    FROM category_registrations cr
    WHERE cr.tournament_id = tournament_id
    AND cr.category_id = category_id
    AND cr.passphrase = passphrase;

    IF NOT FOUND THEN
        -- Create new entry as first player
        INSERT INTO category_registrations (
            tournament_id,
            category_id,
            passphrase,
            player1_registration_id,
            status
        ) VALUES (
            tournament_id,
            category_id,
            passphrase,
            registration_id,
            'pending_partner'::category_registration_status
        )
        RETURNING jsonb_build_object(
            'status', status,
            'message', 'First player registration created. Waiting for partner.',
            'category_type', 'doubles',
            'passphrase', passphrase
        ) INTO result;
    ELSIF existing_registration.player2_registration_id IS NOT NULL THEN
        RAISE EXCEPTION 'This passphrase has already been used by other players in this category';
    ELSE
        -- Update existing entry with second player
        UPDATE category_registrations
        SET player2_registration_id = registration_id,
            status = 'pending'::category_registration_status
        WHERE id = existing_registration.id
        RETURNING jsonb_build_object(
            'status', status,
            'message', 'Second player registration created successfully',
            'category_type', 'doubles',
            'passphrase', passphrase
        ) INTO result;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql; 