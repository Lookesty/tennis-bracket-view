-- Add status column to round_robin_groups if it doesn't exist
ALTER TABLE round_robin_groups
ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'draft';

-- Add RLS policies for round_robin_groups if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'round_robin_groups' 
    AND policyname = 'Enable read access for all users'
  ) THEN
    CREATE POLICY "Enable read access for all users" ON round_robin_groups
      FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'round_robin_groups' 
    AND policyname = 'Enable insert/update/delete for tournament organizers'
  ) THEN
    -- First check if the user has access to modify the draw
    CREATE POLICY "Enable insert/update/delete for tournament organizers" ON round_robin_groups
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM round_robin_draws rd
          WHERE rd.id = round_robin_groups.draw_id
          AND rd.tournament_id = round_robin_groups.tournament_id
          AND EXISTS (
            SELECT 1 FROM tournament_organizers to
            WHERE to.tournament_id = rd.tournament_id
            AND to.user_id = auth.uid()
          )
        )
      );
  END IF;
END $$;

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

  -- Then, either update existing group or create new one
  INSERT INTO round_robin_groups (
    draw_id,
    tournament_id,
    category_id,
    group_number,
    players,
    status
  )
  VALUES (
    p_draw_id,
    p_tournament_id,
    p_category_id,
    p_group_number,
    ARRAY[p_player_id],
    'draft'
  )
  ON CONFLICT (draw_id, group_number)
  DO UPDATE SET
    players = array_append(array_remove(round_robin_groups.players, p_player_id), p_player_id);
END;
$$ LANGUAGE plpgsql; 