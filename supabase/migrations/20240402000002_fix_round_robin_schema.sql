-- Drop existing constraints and columns that create circular dependency
ALTER TABLE round_robin_draws
DROP CONSTRAINT IF EXISTS round_robin_draws_group_unique,
DROP CONSTRAINT IF EXISTS round_robin_draws_unique_category,
DROP CONSTRAINT IF EXISTS round_robin_draws_group_id_fkey,
DROP COLUMN IF EXISTS group_id;

-- Add new constraint to allow multiple draws per category
ALTER TABLE round_robin_draws
ADD CONSTRAINT round_robin_draws_category_group_unique 
UNIQUE (tournament_id, category_id, number_of_groups);

-- Update round_robin_groups to reference draw_id properly
ALTER TABLE round_robin_groups
ALTER COLUMN category_id TYPE text,
DROP CONSTRAINT IF EXISTS round_robin_groups_unique_group,
ADD CONSTRAINT round_robin_groups_unique_group 
UNIQUE (draw_id, group_number);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_round_robin_draws_tournament_category 
ON round_robin_draws(tournament_id, category_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_draw_tournament 
ON round_robin_groups(draw_id, tournament_id);

-- Create function to validate group assignments
CREATE OR REPLACE FUNCTION validate_group_assignment()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if the draw exists and is in draft status
  IF NOT EXISTS (
    SELECT 1 FROM round_robin_draws
    WHERE id = NEW.draw_id
    AND tournament_id = NEW.tournament_id
    AND category_id = NEW.category_id
    AND status = 'draft'
  ) THEN
    RAISE EXCEPTION 'Draw not found or not in draft status';
  END IF;

  -- Ensure group number is valid
  IF NEW.group_number <= 0 THEN
    RAISE EXCEPTION 'Group number must be positive';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for group assignment validation
DROP TRIGGER IF EXISTS validate_group_assignment_trigger ON round_robin_groups;
CREATE TRIGGER validate_group_assignment_trigger
BEFORE INSERT OR UPDATE ON round_robin_groups
FOR EACH ROW
EXECUTE FUNCTION validate_group_assignment(); 