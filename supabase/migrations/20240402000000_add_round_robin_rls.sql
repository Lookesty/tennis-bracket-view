-- Enable RLS on the tables
ALTER TABLE round_robin_draws ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_robin_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_robin_matches ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for round_robin_draws
CREATE POLICY "Enable read access for all users" ON round_robin_draws
  FOR SELECT USING (true);

CREATE POLICY "Enable insert/update/delete for tournament organizers" ON round_robin_draws
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tennis_events te
      WHERE te.id = round_robin_draws.tournament_id
      AND te.user_id = auth.uid()
    )
  );

-- Add RLS policies for round_robin_groups
CREATE POLICY "Enable read access for all users" ON round_robin_groups
  FOR SELECT USING (true);

CREATE POLICY "Enable insert/update/delete for tournament organizers" ON round_robin_groups
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tennis_events te
      WHERE te.id = round_robin_groups.tournament_id
      AND te.user_id = auth.uid()
    )
  );

-- Add RLS policies for round_robin_matches
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

-- Create function to handle group assignments
CREATE OR REPLACE FUNCTION handle_group_assignment(
  p_draw_id uuid,
  p_tournament_id uuid,
  p_category_id text,
  p_group_number integer,
  p_player_id uuid
) RETURNS void AS $$
DECLARE
  v_draw_exists boolean;
  v_existing_group_id uuid;
BEGIN
  -- Check if the draw exists and is in draft status
  SELECT EXISTS (
    SELECT 1 FROM round_robin_draws
    WHERE id = p_draw_id
    AND tournament_id = p_tournament_id
    AND category_id = p_category_id
    AND status = 'draft'
  ) INTO v_draw_exists;

  IF NOT v_draw_exists THEN
    RAISE EXCEPTION 'Draw not found or not in draft status';
  END IF;

  -- First, remove the player from any existing groups in this draw
  UPDATE round_robin_groups
  SET players = array_remove(players, p_player_id)
  WHERE draw_id = p_draw_id;

  -- If group_number is null, we're just clearing the assignment
  IF p_group_number IS NOT NULL THEN
    -- Get existing group ID if any
    SELECT id INTO v_existing_group_id
    FROM round_robin_groups
    WHERE draw_id = p_draw_id
    AND group_number = p_group_number;

    IF v_existing_group_id IS NOT NULL THEN
      -- Update existing group
      UPDATE round_robin_groups
      SET players = array_append(array_remove(players, p_player_id), p_player_id)
      WHERE id = v_existing_group_id;
    ELSE
      -- Create new group
      INSERT INTO round_robin_groups (
        draw_id,
        tournament_id,
        category_id,
        group_number,
        players
      ) VALUES (
        p_draw_id,
        p_tournament_id,
        p_category_id,
        p_group_number,
        ARRAY[p_player_id]
      );
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 