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
    UPDATE tennis_events
    SET status = new_status
    WHERE id = NEW.tournament_id
    AND status != new_status::text;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for both match tables
DROP TRIGGER IF EXISTS update_status_on_tournament_match ON tournament_matches;
CREATE TRIGGER update_status_on_tournament_match
    AFTER UPDATE OF status ON tournament_matches
    FOR EACH ROW
    WHEN (NEW.status IN ('completed', 'walkover'))
    EXECUTE FUNCTION update_tournament_status_on_match_change();

DROP TRIGGER IF EXISTS update_status_on_round_robin_match ON round_robin_matches;
CREATE TRIGGER update_status_on_round_robin_match
    AFTER UPDATE OF status ON round_robin_matches
    FOR EACH ROW
    WHEN (NEW.status IN ('completed', 'walkover'))
    EXECUTE FUNCTION update_tournament_status_on_match_change(); 
 
 