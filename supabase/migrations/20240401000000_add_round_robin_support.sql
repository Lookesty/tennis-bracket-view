-- Add format to tennis_events table to distinguish between types at tournament level
ALTER TABLE tennis_events
ADD COLUMN format text NULL;

-- Update existing records to 'single_elimination' as that was the only format before
UPDATE tennis_events
SET format = 'single_elimination'
WHERE format IS NULL;

-- Now make the column NOT NULL and add the constraint
ALTER TABLE tennis_events
ALTER COLUMN format SET NOT NULL,
ADD CONSTRAINT valid_format CHECK (format IN ('single_elimination', 'round_robin'));

-- Add round robin scoring configuration columns
ALTER TABLE tennis_events
ADD COLUMN IF NOT EXISTS round_robin_scoring_type text CHECK (round_robin_scoring_type IN ('match_points', 'set_points')),
ADD COLUMN IF NOT EXISTS round_robin_match_points jsonb DEFAULT jsonb_build_object('win', 2, 'loss', 1, 'walkover', 0),
ADD COLUMN IF NOT EXISTS round_robin_set_points jsonb DEFAULT jsonb_build_object('perSetWon', 1, 'fixedSets', 3);

-- Create table for round robin draws
CREATE TABLE round_robin_draws (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL,
    category_id text NOT NULL,
    status draw_status NOT NULL DEFAULT 'draft',
    group_size integer NOT NULL,
    number_of_groups integer NOT NULL,
    seeded_players uuid[] NOT NULL DEFAULT '{}',
    scoring_format jsonb NOT NULL DEFAULT '{"format": "best_of_3", "tiebreak": true, "final_set_tiebreak": true}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT round_robin_draws_pkey PRIMARY KEY (id),
    CONSTRAINT round_robin_draws_tournament_fkey FOREIGN KEY (tournament_id) 
        REFERENCES tennis_events(id) ON DELETE CASCADE,
    CONSTRAINT round_robin_draws_unique_category 
        UNIQUE (tournament_id, category_id),
    CONSTRAINT check_scoring_format CHECK (
        (scoring_format ? 'format') AND
        (scoring_format ->> 'format' = ANY (ARRAY['best_of_3', 'best_of_5', 'pro_set'])) AND
        (scoring_format ? 'tiebreak') AND
        (scoring_format ? 'final_set_tiebreak')
    )
);

-- Modify tournament_registrations to use player_id properly
ALTER TABLE tournament_registrations 
ADD COLUMN IF NOT EXISTS player_id uuid REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS partner_id uuid REFERENCES profiles(id);

-- Migrate existing data
UPDATE tournament_registrations 
SET player_id = (player_info->>'id')::uuid
WHERE player_id IS NULL;

-- Create tables for round robin support
CREATE TABLE IF NOT EXISTS round_robin_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES tennis_events(id) ON DELETE CASCADE,
  category_id uuid NOT NULL,
  group_number integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(tournament_id, category_id, group_number)
);

CREATE TABLE IF NOT EXISTS round_robin_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES round_robin_groups(id) ON DELETE CASCADE,
  entry1_registration_id uuid NOT NULL REFERENCES category_registrations(id),
  entry2_registration_id uuid NOT NULL REFERENCES category_registrations(id),
  winner_registration_id uuid REFERENCES category_registrations(id),
  status match_status NOT NULL DEFAULT 'awaiting_date',
  scheduled_date timestamptz,
  completion_date timestamptz,
  score text,
  score_details jsonb,
  winner_sets integer,
  loser_sets integer,
  match_number integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(group_id, match_number)
);

CREATE TABLE IF NOT EXISTS round_robin_sets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES round_robin_matches(id) ON DELETE CASCADE,
  set_number integer NOT NULL,
  player1_score integer NOT NULL DEFAULT 0,
  player2_score integer NOT NULL DEFAULT 0,
  winner_registration_id uuid REFERENCES category_registrations(id),
  tiebreak_points text, -- Format: "7-5" or null if no tiebreak
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(match_id, set_number)
);

-- Drop the view first to avoid dependency issues
DROP VIEW IF EXISTS round_robin_standings;

-- Update round_robin_matches table to match tournament_matches structure
ALTER TABLE round_robin_matches 
  -- Drop existing foreign key constraints
  DROP CONSTRAINT IF EXISTS round_robin_matches_player1_fkey,
  DROP CONSTRAINT IF EXISTS round_robin_matches_player2_fkey,
  DROP CONSTRAINT IF EXISTS round_robin_matches_winner_fkey;

-- Rename columns to match tournament_matches
ALTER TABLE round_robin_matches 
  RENAME COLUMN player1_registration_id TO entry1_registration_id;

ALTER TABLE round_robin_matches 
  RENAME COLUMN player2_registration_id TO entry2_registration_id;

-- Move sets/games tracking into score_details JSONB
ALTER TABLE round_robin_matches 
  DROP COLUMN sets_won,
  DROP COLUMN sets_lost,
  DROP COLUMN games_won,
  DROP COLUMN games_lost;

-- Add winner_sets and loser_sets to match tournament_matches
ALTER TABLE round_robin_matches
  ADD COLUMN winner_sets integer,
  ADD COLUMN loser_sets integer;

-- Add check constraint to match tournament_matches
ALTER TABLE round_robin_matches
  ADD CONSTRAINT check_winner_sets CHECK (winner_sets > loser_sets);

-- Add new deadline column to match tournament_matches
ALTER TABLE round_robin_matches
  ADD COLUMN new_deadline timestamp with time zone;

-- Update foreign key constraints to reference category_registrations
ALTER TABLE round_robin_matches
  ADD CONSTRAINT round_robin_matches_entry1_fkey 
    FOREIGN KEY (entry1_registration_id) 
    REFERENCES category_registrations(id) 
    ON DELETE RESTRICT,
  ADD CONSTRAINT round_robin_matches_entry2_fkey 
    FOREIGN KEY (entry2_registration_id) 
    REFERENCES category_registrations(id) 
    ON DELETE RESTRICT,
  ADD CONSTRAINT round_robin_matches_winner_fkey 
    FOREIGN KEY (winner_registration_id) 
    REFERENCES category_registrations(id) 
    ON DELETE RESTRICT;

-- Add unique constraint for matches within a group
ALTER TABLE round_robin_matches
  ADD CONSTRAINT round_robin_matches_group_entries_unique 
    UNIQUE (group_id, entry1_registration_id, entry2_registration_id);

-- Create view for round robin standings
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

-- Add triggers for updated_at columns
CREATE TRIGGER update_round_robin_draws_updated_at
    BEFORE UPDATE ON round_robin_draws
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_round_robin_groups_updated_at
    BEFORE UPDATE ON round_robin_groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_round_robin_matches_updated_at
    BEFORE UPDATE ON round_robin_matches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_round_robin_sets_updated_at
    BEFORE UPDATE ON round_robin_sets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add indexes for performance
CREATE INDEX idx_round_robin_draws_tournament_id ON round_robin_draws(tournament_id);
CREATE INDEX idx_round_robin_draws_category_id ON round_robin_draws(category_id);
CREATE INDEX idx_round_robin_draws_status ON round_robin_draws(status);

CREATE INDEX idx_round_robin_groups_draw_id ON round_robin_groups(draw_id);
CREATE INDEX idx_round_robin_groups_tournament_id ON round_robin_groups(tournament_id);
CREATE INDEX idx_round_robin_groups_category_id ON round_robin_groups(category_id);

CREATE INDEX idx_round_robin_matches_group_id ON round_robin_matches(group_id);
CREATE INDEX idx_round_robin_matches_draw_id ON round_robin_matches(draw_id);
CREATE INDEX idx_round_robin_matches_tournament_id ON round_robin_matches(tournament_id);
CREATE INDEX idx_round_robin_matches_category_id ON round_robin_matches(category_id);
CREATE INDEX idx_round_robin_matches_status ON round_robin_matches(status);

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_tournament_id ON round_robin_groups(tournament_id);
CREATE INDEX IF NOT EXISTS idx_round_robin_groups_category_id ON round_robin_groups(category_id);
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_group_id ON round_robin_matches(group_id);
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_player1_registration_id ON round_robin_matches(player1_registration_id);
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_player2_registration_id ON round_robin_matches(player2_registration_id);
CREATE INDEX IF NOT EXISTS idx_round_robin_matches_status ON round_robin_matches(status);
CREATE INDEX IF NOT EXISTS idx_tournament_registrations_player_id ON tournament_registrations(player_id);
CREATE INDEX IF NOT EXISTS idx_tournament_registrations_partner_id ON tournament_registrations(partner_id); 