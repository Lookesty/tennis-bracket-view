-- Drop existing functions before recreating them
DROP FUNCTION IF EXISTS generate_round_robin_matches(uuid);

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
          round_number,
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
          v_current_round,
          'awaiting_date'
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

-- Update any existing matches that are 'scheduled' to 'awaiting_date'
UPDATE round_robin_matches
SET status = 'awaiting_date'
WHERE status = 'scheduled'; 
 
 