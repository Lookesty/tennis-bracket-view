-- Add round_number column to round_robin_matches table
ALTER TABLE round_robin_matches 
ADD COLUMN round_number integer NOT NULL DEFAULT 1;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_round_number 
ON round_robin_matches USING btree (round_number);

-- Add composite index for group and round queries
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_group_round 
ON round_robin_matches USING btree (group_id, round_number); 