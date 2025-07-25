-- Drop existing tables and views that depend on the old structure
DROP VIEW IF EXISTS round_robin_standings;
DROP TABLE IF EXISTS round_robin_draws CASCADE;

-- Modify round_robin_groups to remove draw dependency
ALTER TABLE round_robin_groups
DROP CONSTRAINT IF EXISTS round_robin_groups_draw_fkey,
DROP CONSTRAINT IF EXISTS round_robin_groups_unique_group,
DROP COLUMN IF EXISTS draw_id,
ALTER COLUMN category_id TYPE text,
ADD COLUMN IF NOT EXISTS players UUID[] NOT NULL DEFAULT '{}',
ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'draft',
ADD CONSTRAINT round_robin_groups_unique_group UNIQUE (tournament_id, category_id, group_number);

-- Create function to validate group numbers are sequential
CREATE OR REPLACE FUNCTION validate_group_numbers()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if group numbers are sequential starting from 1
  IF EXISTS (
    SELECT 1
    FROM (
      SELECT 
        tournament_id,
        category_id,
        group_number,
        ROW_NUMBER() OVER (PARTITION BY tournament_id, category_id ORDER BY group_number) as expected_number
      FROM round_robin_groups
      WHERE tournament_id = NEW.tournament_id
      AND category_id = NEW.category_id
    ) sq
    WHERE group_number != expected_number
  ) THEN
    RAISE EXCEPTION 'Group numbers must be sequential starting from 1';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for group number validation
DROP TRIGGER IF EXISTS ensure_sequential_group_numbers ON round_robin_groups;
CREATE TRIGGER ensure_sequential_group_numbers
AFTER INSERT OR UPDATE ON round_robin_groups
FOR EACH ROW
EXECUTE FUNCTION validate_group_numbers();

-- Create function to handle player assignments to groups
CREATE OR REPLACE FUNCTION handle_player_group_assignment(
  p_tournament_id uuid,
  p_category_id text,
  p_group_number integer,
  p_player_id uuid
) RETURNS void AS $$
DECLARE
  v_existing_group_id uuid;
BEGIN
  -- First, remove the player from any existing groups in this category
  UPDATE round_robin_groups
  SET players = array_remove(players, p_player_id)
  WHERE tournament_id = p_tournament_id
  AND category_id = p_category_id;

  -- If group_number is null, we're just clearing the assignment
  IF p_group_number IS NOT NULL THEN
    -- Get existing group ID if any
    SELECT id INTO v_existing_group_id
    FROM round_robin_groups
    WHERE tournament_id = p_tournament_id
    AND category_id = p_category_id
    AND group_number = p_group_number;

    IF v_existing_group_id IS NOT NULL THEN
      -- Update existing group
      UPDATE round_robin_groups
      SET players = array_append(array_remove(players, p_player_id), p_player_id)
      WHERE id = v_existing_group_id;
    ELSE
      -- Create new group
      INSERT INTO round_robin_groups (
        tournament_id,
        category_id,
        group_number,
        players,
        status
      ) VALUES (
        p_tournament_id,
        p_category_id,
        p_group_number,
        ARRAY[p_player_id],
        'draft'
      );
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace the round_robin_standings view
CREATE OR REPLACE VIEW round_robin_standings AS
WITH match_results AS (
  SELECT 
    m.tournament_id,
    m.category_id,
    m.group_id,
    CASE 
      WHEN m.winner_registration_id = m.entry1_registration_id THEN m.entry1_registration_id
      ELSE m.entry2_registration_id
    END as registration_id,
    CASE 
      WHEN m.status = 'completed' THEN
        CASE 
          WHEN m.winner_registration_id = m.entry1_registration_id THEN m.winner_sets
          ELSE m.loser_sets
        END
      ELSE 0
    END as sets_won,
    CASE 
      WHEN m.status = 'completed' THEN
        CASE 
          WHEN m.winner_registration_id = m.entry1_registration_id THEN m.loser_sets
          ELSE m.winner_sets
        END
      ELSE 0
    END as sets_lost,
    CASE 
      WHEN m.status = 'completed' THEN
        CASE 
          WHEN m.winner_registration_id IS NOT NULL THEN 2
          ELSE 1
        END
      ELSE 0
    END as points
  FROM round_robin_matches m
  WHERE m.status = 'completed'
)
SELECT 
  r.tournament_id,
  r.category_id,
  r.group_id,
  cr.id as registration_id,
  COALESCE(SUM(r.points), 0) as total_points,
  COALESCE(SUM(r.sets_won), 0) as total_sets_won,
  COALESCE(SUM(r.sets_lost), 0) as total_sets_lost,
  COALESCE(SUM(r.sets_won) - SUM(r.sets_lost), 0) as set_difference
FROM round_robin_groups g
CROSS JOIN LATERAL unnest(g.players) as p(player_id)
JOIN category_registrations cr ON cr.player1_registration_id = p.player_id OR cr.player2_registration_id = p.player_id
LEFT JOIN match_results r ON r.registration_id = cr.id
GROUP BY r.tournament_id, r.category_id, r.group_id, cr.id
ORDER BY 
  total_points DESC,
  set_difference DESC,
  total_sets_won DESC;

-- Update RLS policies
DROP POLICY IF EXISTS "Enable read access for all users" ON round_robin_groups;
DROP POLICY IF EXISTS "Enable insert/update/delete for tournament organizers" ON round_robin_groups;

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

-- Add indexes for performance
DROP INDEX IF EXISTS idx_round_robin_groups_draw_id;
DROP INDEX IF EXISTS idx_round_robin_groups_draw_tournament;

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_tournament_category
ON round_robin_groups USING btree (tournament_id, category_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_tournament_id
ON round_robin_groups USING btree (tournament_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_category_id
ON round_robin_groups USING btree (category_id);

-- Add comment for clarity
COMMENT ON TABLE round_robin_groups IS 'Stores round robin tournament groups. Groups are created first, then players are assigned, and finally matches are generated.';
COMMENT ON COLUMN round_robin_groups.players IS 'Array of player UUIDs assigned to this group';
COMMENT ON COLUMN round_robin_groups.status IS 'Status of the group: draft (initial), active (matches created), or completed'; 