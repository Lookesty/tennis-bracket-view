-- Create round_robin_groups table
CREATE TABLE IF NOT EXISTS round_robin_groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tournament_id UUID NOT NULL REFERENCES tennis_events(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES tournament_categories(id) ON DELETE CASCADE,
  group_number INTEGER NOT NULL,
  players UUID[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tournament_id, category_id, group_number)
);

-- Add RLS policies
ALTER TABLE round_robin_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON round_robin_groups
  FOR SELECT USING (true);

CREATE POLICY "Enable insert/update/delete for tournament organizers" ON round_robin_groups
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tennis_events te
      WHERE te.id = round_robin_groups.tournament_id
      AND te.created_by = auth.uid()
    )
  );

-- Add updated_at trigger
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON round_robin_groups
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at(); 