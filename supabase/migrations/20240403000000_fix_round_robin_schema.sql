-- First drop the RLS policies that depend on draw_id
DROP POLICY IF EXISTS "Players can view groups in published draws" ON round_robin_groups;

-- Create new RLS policy that doesn't depend on draw_id
CREATE POLICY "Players can view tournament groups" ON round_robin_groups
  FOR SELECT
  USING (
    tournament_id IN (
      SELECT id FROM tennis_events 
      WHERE registration_closed_at IS NOT NULL
    )
  );

-- Now drop the existing constraints and triggers
ALTER TABLE round_robin_groups
DROP CONSTRAINT IF EXISTS round_robin_groups_draw_fkey,
DROP CONSTRAINT IF EXISTS round_robin_groups_unique_group;

-- Simplify the round_robin_groups table
ALTER TABLE round_robin_groups
DROP COLUMN IF EXISTS draw_id,
DROP COLUMN IF EXISTS status;

-- Add new unique constraint for group numbers within a tournament category
ALTER TABLE round_robin_groups
ADD CONSTRAINT round_robin_groups_unique_group 
UNIQUE (tournament_id, category_id, group_number);

-- Drop the round_robin_draws table as it's no longer needed at this stage
DROP TABLE IF EXISTS round_robin_draws;

-- Update indexes
DROP INDEX IF EXISTS idx_round_robin_groups_draw_id;
DROP INDEX IF EXISTS idx_round_robin_groups_draw_tournament;

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_tournament_category
ON public.round_robin_groups USING btree (tournament_id, category_id);

-- Add trigger to validate group numbers are sequential within a category
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

CREATE TRIGGER ensure_sequential_group_numbers
AFTER INSERT OR UPDATE ON round_robin_groups
FOR EACH ROW
EXECUTE FUNCTION validate_group_numbers(); 