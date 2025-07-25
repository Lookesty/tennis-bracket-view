-- Drop the existing trigger and function
DROP TRIGGER IF EXISTS handle_tournament_categories_trigger ON tennis_events;
DROP FUNCTION IF EXISTS handle_tournament_categories();

-- Recreate the function with the correct status type
CREATE OR REPLACE FUNCTION handle_tournament_categories()
RETURNS TRIGGER AS $$
BEGIN
    -- For new events or when categories are updated
    IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE' AND OLD.categories IS DISTINCT FROM NEW.categories) THEN
        -- Delete existing categories if this is an update
        IF (TG_OP = 'UPDATE') THEN
            DELETE FROM registration_categories WHERE tournament_id = NEW.id;
        END IF;

        -- Insert new categories with 'open' status
        INSERT INTO registration_categories (
            tournament_id,
            category,
            category_status,  -- This column is of type category_status
            max_entries,
            created_at,
            updated_at
        )
        SELECT 
            NEW.id,
            cat,
            'open'::category_status,  -- Changed from 'draft'::event_status to 'open'::category_status
            (cat->>'maxEntries')::INTEGER,
            NOW(),
            NOW()
        FROM jsonb_array_elements(NEW.categories) cat;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER handle_tournament_categories_trigger
    AFTER INSERT OR UPDATE OF categories ON tennis_events
    FOR EACH ROW
    EXECUTE FUNCTION handle_tournament_categories();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION handle_tournament_categories TO authenticated; 