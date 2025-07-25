-- Add group_id column to round_robin_draws
ALTER TABLE round_robin_draws
ADD COLUMN group_id UUID REFERENCES round_robin_groups(id) ON DELETE CASCADE;

-- Add unique constraint to ensure one draw per group
ALTER TABLE round_robin_draws
ADD CONSTRAINT round_robin_draws_group_unique UNIQUE (group_id);

-- Update unique constraint to include group_id
ALTER TABLE round_robin_draws
DROP CONSTRAINT IF EXISTS round_robin_draws_unique_category,
ADD CONSTRAINT round_robin_draws_unique_category UNIQUE (tournament_id, category_id, group_id);

-- Add index for group_id lookups
CREATE INDEX idx_round_robin_draws_group_id ON round_robin_draws(group_id); 