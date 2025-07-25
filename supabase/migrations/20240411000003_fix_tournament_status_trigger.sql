-- Function to update tournament status when matches change
CREATE OR REPLACE FUNCTION update_tournament_status_on_match_change()
RETURNS TRIGGER AS $$
DECLARE
    tournament_data jsonb;
    new_status event_status;
BEGIN
    -- Get the tournament data
    SELECT row_to_json(te)::jsonb INTO tournament_data
    FROM tennis_events te
    WHERE te.id = NEW.tournament_id;

    -- Determine new status
    new_status := determine_auto_status(tournament_data);

    -- Update tournament status if it has changed
    -- Compare event_status with event_status, not with text
    UPDATE tennis_events
    SET status = new_status
    WHERE id = NEW.tournament_id
    AND status != new_status;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql; 
 
 