-- Modify round_robin_matches table to remove draw dependency
ALTER TABLE round_robin_matches
DROP CONSTRAINT IF EXISTS round_robin_matches_draw_fkey,
DROP COLUMN IF EXISTS draw_id;

-- Drop existing functions before recreating them
DROP FUNCTION IF EXISTS generate_round_robin_matches(uuid);
DROP FUNCTION IF EXISTS check_group_complete(uuid);
DROP FUNCTION IF EXISTS check_group_completion_trigger();

-- Create function to generate round robin matches for a group
CREATE OR REPLACE FUNCTION generate_round_robin_matches(
  p_group_id uuid
) RETURNS void AS $$
DECLARE
  v_players uuid[];
  v_player1 uuid;
  v_player2 uuid;
  v_match_number integer := 1;
  v_player_count integer;
  v_total_rounds integer;
  v_current_round integer;
  i integer;
  j integer;
BEGIN
  -- Get players array from the group
  SELECT players INTO v_players
  FROM round_robin_groups
  WHERE id = p_group_id;
  
  -- Calculate number of players and rounds
  v_player_count := array_length(v_players, 1);
  
  -- If odd number of players, add a "bye" player
  IF v_player_count % 2 = 1 THEN
    v_players := array_append(v_players, NULL);
    v_player_count := v_player_count + 1;
  END IF;
  
  v_total_rounds := v_player_count - 1;
  
  -- Generate matches using round-robin algorithm
  FOR v_current_round IN 1..v_total_rounds LOOP
    FOR i IN 1..(v_player_count/2) LOOP
      v_player1 := v_players[i];
      v_player2 := v_players[v_player_count - i + 1];
      
      -- Only create match if neither player is a "bye"
      IF v_player1 IS NOT NULL AND v_player2 IS NOT NULL THEN
        INSERT INTO round_robin_matches (
          group_id,
          tournament_id,
          category_id,
          entry1_registration_id,
          entry2_registration_id,
          match_number,
          status
        )
        SELECT 
          p_group_id,
          g.tournament_id,
          g.category_id,
          cr1.id,
          cr2.id,
          v_match_number,
          'scheduled'
        FROM round_robin_groups g
        JOIN category_registrations cr1 
          ON (cr1.player1_registration_id = v_player1 OR cr1.player2_registration_id = v_player1)
          AND cr1.tournament_id = g.tournament_id 
          AND cr1.category_id = g.category_id
        JOIN category_registrations cr2 
          ON (cr2.player1_registration_id = v_player2 OR cr2.player2_registration_id = v_player2)
          AND cr2.tournament_id = g.tournament_id 
          AND cr2.category_id = g.category_id
        WHERE g.id = p_group_id;
        
        v_match_number := v_match_number + 1;
      END IF;
    END LOOP;
    
    -- Rotate players (keeping first player fixed)
    v_players := array_append(
      array_prepend(
        v_players[1],
        v_players[3:v_player_count]
      ),
      v_players[2]
    );
  END LOOP;
  
  -- Update group status to active
  UPDATE round_robin_groups
  SET status = 'active'
  WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to check if a group is complete
CREATE OR REPLACE FUNCTION check_group_complete(
  p_group_id uuid
) RETURNS boolean AS $$
DECLARE
  v_all_matches_complete boolean;
BEGIN
  -- Check if all matches in the group are completed
  SELECT bool_and(status = 'completed')
  INTO v_all_matches_complete
  FROM round_robin_matches
  WHERE group_id = p_group_id;
  
  -- If all matches are complete, update group status
  IF v_all_matches_complete THEN
    UPDATE round_robin_groups
    SET status = 'completed'
    WHERE id = p_group_id;
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to check group completion after match updates
CREATE OR REPLACE FUNCTION check_group_completion_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' THEN
    PERFORM check_group_complete(NEW.group_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS check_group_completion ON round_robin_matches;

CREATE TRIGGER check_group_completion
AFTER UPDATE OF status ON round_robin_matches
FOR EACH ROW
WHEN (NEW.status = 'completed')
EXECUTE FUNCTION check_group_completion_trigger();

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_group_id
ON round_robin_matches(group_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_matches_tournament_category
ON round_robin_matches(tournament_id, category_id);

-- Add comments for clarity
COMMENT ON FUNCTION generate_round_robin_matches IS 'Generates round robin matches for a group using the round-robin tournament algorithm';
COMMENT ON FUNCTION check_group_complete IS 'Checks if all matches in a group are complete and updates group status accordingly'; 