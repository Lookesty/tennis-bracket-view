-- Create round_robin_draws table to store category-level draw configuration
CREATE TABLE public.round_robin_draws (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL,
    category_id text NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    group_size integer NOT NULL,
    number_of_groups integer NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT round_robin_draws_pkey PRIMARY KEY (id),
    CONSTRAINT round_robin_draws_tournament_fkey FOREIGN KEY (tournament_id) 
        REFERENCES tennis_events(id) ON DELETE CASCADE,
    CONSTRAINT round_robin_draws_unique_category UNIQUE (tournament_id, category_id),
    CONSTRAINT check_group_size CHECK (group_size > 1),
    CONSTRAINT check_number_of_groups CHECK (number_of_groups > 0)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_round_robin_draws_tournament_id 
ON public.round_robin_draws USING btree (tournament_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_draws_category_id 
ON public.round_robin_draws USING btree (category_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_draws_status 
ON public.round_robin_draws USING btree (status);

-- Add updated_at trigger
CREATE TRIGGER update_round_robin_draws_updated_at 
    BEFORE UPDATE ON round_robin_draws
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add function to create groups when draw is created
CREATE OR REPLACE FUNCTION create_round_robin_groups()
RETURNS TRIGGER AS $$
DECLARE
    i integer;
BEGIN
    -- Create the specified number of groups
    FOR i IN 1..NEW.number_of_groups LOOP
        INSERT INTO round_robin_groups (
            tournament_id,
            category_id,
            group_number,
            status
        ) VALUES (
            NEW.tournament_id,
            NEW.category_id,
            i,
            'draft'
        );
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to automatically create groups when draw is created
CREATE TRIGGER create_groups_on_draw_creation
    AFTER INSERT ON round_robin_draws
    FOR EACH ROW
    EXECUTE FUNCTION create_round_robin_groups();

-- Add RLS policies
ALTER TABLE round_robin_draws ENABLE ROW LEVEL SECURITY;

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

-- Add comments for clarity
COMMENT ON TABLE round_robin_draws IS 'Stores round robin draw configuration and status for each category';
COMMENT ON COLUMN round_robin_draws.group_size IS 'Number of players required in each group';
COMMENT ON COLUMN round_robin_draws.number_of_groups IS 'Number of groups to create for this draw';
COMMENT ON COLUMN round_robin_draws.status IS 'Status of the draw: draft, active, or completed'; 