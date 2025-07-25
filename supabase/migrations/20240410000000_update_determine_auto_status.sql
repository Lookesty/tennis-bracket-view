-- Drop the existing function
DROP FUNCTION IF EXISTS determine_auto_status;

-- Recreate the function with format-specific checks
CREATE OR REPLACE FUNCTION determine_auto_status(event_data jsonb)
RETURNS event_status AS $$
DECLARE
    has_basic_info BOOLEAN;
    has_rules_config BOOLEAN;
    has_registration_config BOOLEAN;
    registration_is_launched BOOLEAN;
    registration_is_closed BOOLEAN;
    draws_submitted BOOLEAN;
    draws_started BOOLEAN;
    past_deadline BOOLEAN;
    all_matches_completed BOOLEAN;
    tournament_format TEXT;
BEGIN
    -- Check basic info
    has_basic_info := (
        event_data->>'name' IS NOT NULL AND
        event_data->>'venue' IS NOT NULL AND
        event_data->>'start_date' IS NOT NULL AND
        event_data->>'end_date' IS NOT NULL
    );

    -- Check configuration
    has_rules_config := event_data->>'rules_config_id' IS NOT NULL;
    has_registration_config := event_data->>'registration_config_id' IS NOT NULL;
    
    -- Check registration status
    registration_is_launched := event_data->>'registration_launched_at' IS NOT NULL;
    registration_is_closed := event_data->>'registration_closed_at' IS NOT NULL;
    
    -- Check if past deadline
    past_deadline := CASE 
        WHEN event_data->>'deadline' IS NOT NULL THEN
            (event_data->>'deadline')::TIMESTAMPTZ < CURRENT_TIMESTAMP
        ELSE 
            FALSE
    END;

    -- Check draws status
    draws_submitted := event_data->>'draws_submitted_at' IS NOT NULL;
    
    -- Get tournament format
    tournament_format := event_data->>'format';

    -- Check draws started based on format
    IF tournament_format = 'round_robin' THEN
        draws_started := EXISTS (
            SELECT 1 
            FROM round_robin_matches 
            WHERE tournament_id = (event_data->>'id')::UUID
            LIMIT 1
        );

        -- Check if all round robin matches are completed or walkover
        SELECT CASE 
            WHEN COUNT(*) = 0 THEN FALSE -- No matches yet
            WHEN COUNT(*) = COUNT(CASE WHEN status IN ('completed', 'walkover') THEN 1 END) THEN TRUE
            ELSE FALSE
        END INTO all_matches_completed
        FROM round_robin_matches
        WHERE tournament_id = (event_data->>'id')::UUID;
    ELSE
        -- Single elimination or other formats
        draws_started := EXISTS (
            SELECT 1 
            FROM tournament_matches 
            WHERE tournament_id = (event_data->>'id')::UUID
            LIMIT 1
        );

        -- Check if all tournament matches are completed or walkover
        SELECT CASE 
            WHEN COUNT(*) = 0 THEN FALSE -- No matches yet
            WHEN COUNT(*) = COUNT(CASE WHEN status IN ('completed', 'walkover') THEN 1 END) THEN TRUE
            ELSE FALSE
        END INTO all_matches_completed
        FROM tournament_matches
        WHERE tournament_id = (event_data->>'id')::UUID;
    END IF;

    -- Determine status based on conditions (order matters: furthest status first)
    IF all_matches_completed AND draws_submitted THEN
        RETURN 'completed'::event_status;
    ELSIF draws_submitted AND draws_started AND (
        -- Check appropriate table based on format
        CASE 
            WHEN tournament_format = 'round_robin' THEN
                EXISTS (
                    SELECT 1 
                    FROM round_robin_matches 
                    WHERE tournament_id = (event_data->>'id')::UUID 
                    AND status IN ('completed', 'walkover', 'scheduled', 'awaiting_date')
                    LIMIT 1
                )
            ELSE
                EXISTS (
                    SELECT 1 
                    FROM tournament_matches 
                    WHERE tournament_id = (event_data->>'id')::UUID 
                    AND status IN ('completed', 'walkover', 'scheduled', 'awaiting_date')
                    LIMIT 1
                )
        END
    ) THEN
        RETURN 'live'::event_status;
    ELSIF draws_submitted THEN
        RETURN 'draws_complete'::event_status;
    ELSIF registration_is_closed OR past_deadline THEN
        RETURN 'registration_closed'::event_status;
    ELSIF registration_is_launched THEN
        RETURN 'registration_open'::event_status;
    ELSIF has_basic_info AND has_rules_config AND has_registration_config THEN
        RETURN 'setup_complete'::event_status;
    ELSE
        RETURN 'draft'::event_status;
    END IF;
END;
$$ LANGUAGE plpgsql; 
 
 