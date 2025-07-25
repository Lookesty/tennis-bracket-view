-- Fix round_robin_matches table to properly link with restored system
-- First, add necessary columns and constraints
ALTER TABLE round_robin_matches
ADD COLUMN IF NOT EXISTS tournament_id uuid REFERENCES tennis_events(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS category_id text,
ADD COLUMN IF NOT EXISTS draw_id uuid REFERENCES round_robin_draws(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS match_number integer;

-- Update existing records with tournament_id and category_id from their groups
UPDATE round_robin_matches m
SET tournament_id = g.tournament_id,
    category_id = g.category_id,
    draw_id = g.draw_id
FROM round_robin_groups g
WHERE m.group_id = g.id;

-- Make the columns NOT NULL after populating them
ALTER TABLE round_robin_matches
ALTER COLUMN tournament_id SET NOT NULL,
ALTER COLUMN category_id SET NOT NULL,
ALTER COLUMN draw_id SET NOT NULL,
ALTER COLUMN match_number SET NOT NULL;

-- Add unique constraint for match numbers within a group
ALTER TABLE round_robin_matches
ADD CONSTRAINT round_robin_matches_group_match_unique 
UNIQUE (group_id, match_number);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_tournament_id
ON round_robin_matches(tournament_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_matches_category_id
ON round_robin_matches(category_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_matches_draw_id
ON round_robin_matches(draw_id);

-- Update the match generation function to handle the new structure
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
  v_tournament_id uuid;
  v_category_id text;
  v_draw_id uuid;
  i integer;
  j integer;
BEGIN
  -- Get group information
  SELECT 
    players,
    tournament_id,
    category_id,
    draw_id
  INTO 
    v_players,
    v_tournament_id,
    v_category_id,
    v_draw_id
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
          draw_id,
          entry1_registration_id,
          entry2_registration_id,
          match_number,
          status
        )
        SELECT 
          p_group_id,
          v_tournament_id,
          v_category_id,
          v_draw_id,
          cr1.id,
          cr2.id,
          v_match_number,
          'scheduled'
        FROM category_registrations cr1 
        JOIN category_registrations cr2 ON true
        WHERE 
          (cr1.player1_registration_id = v_player1 OR cr1.player2_registration_id = v_player1)
          AND cr1.tournament_id = v_tournament_id 
          AND cr1.category_id = v_category_id
          AND (cr2.player1_registration_id = v_player2 OR cr2.player2_registration_id = v_player2)
          AND cr2.tournament_id = v_tournament_id 
          AND cr2.category_id = v_category_id;
        
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
  v_draw_id uuid;
BEGIN
  -- Get the draw_id for this group
  SELECT draw_id INTO v_draw_id
  FROM round_robin_groups
  WHERE id = p_group_id;

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

    -- Check if all groups in the draw are complete
    IF NOT EXISTS (
      SELECT 1
      FROM round_robin_groups
      WHERE draw_id = v_draw_id
      AND status != 'completed'
    ) THEN
      -- Update draw status to completed
      UPDATE round_robin_draws
      SET status = 'completed'
      WHERE id = v_draw_id;
    END IF;

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

-- Drop existing policies before creating new ones
DROP POLICY IF EXISTS "Enable read access for all users" ON round_robin_matches;
DROP POLICY IF EXISTS "Enable insert/update/delete for tournament organizers" ON round_robin_matches;

-- Add RLS policies
ALTER TABLE round_robin_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON round_robin_matches
    FOR SELECT USING (true);

CREATE POLICY "Enable insert/update/delete for tournament organizers" ON round_robin_matches
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM tennis_events te
            WHERE te.id = round_robin_matches.tournament_id
            AND te.user_id = auth.uid()
        )
    );

-- Add comments for clarity
COMMENT ON TABLE round_robin_matches IS 'Stores matches for round robin tournament groups';
COMMENT ON COLUMN round_robin_matches.draw_id IS 'Links to the draw configuration that created this match';
COMMENT ON COLUMN round_robin_matches.group_id IS 'Links to the specific group this match belongs to';
COMMENT ON COLUMN round_robin_matches.match_number IS 'Sequential number of the match within the group';
COMMENT ON COLUMN round_robin_matches.status IS 'Status of the match: scheduled, in_progress, completed'; 