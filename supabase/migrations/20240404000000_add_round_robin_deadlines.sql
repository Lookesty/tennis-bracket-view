-- Add round_deadlines column to round_robin_draws
ALTER TABLE round_robin_draws
ADD COLUMN round_deadlines jsonb;

-- Add comment for clarity
COMMENT ON COLUMN round_robin_draws.round_deadlines IS 'Array of deadlines for each round in the group, calculated linearly between tournament start and end dates'; 