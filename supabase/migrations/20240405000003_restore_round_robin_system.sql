-- Restore the round_robin_draws and round_robin_groups system
-- First, drop existing tables and constraints
DROP VIEW IF EXISTS round_robin_standings;
DROP TABLE IF EXISTS round_robin_draws CASCADE;

-- Recreate round_robin_draws table with proper structure
CREATE TABLE IF NOT EXISTS public.round_robin_draws (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    tournament_id uuid NOT NULL,
    category_id text NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    group_size integer NOT NULL,
    number_of_groups integer NOT NULL,
    round_deadlines jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT round_robin_draws_pkey PRIMARY KEY (id),
    CONSTRAINT round_robin_draws_tournament_fkey FOREIGN KEY (tournament_id) 
        REFERENCES tennis_events(id) ON DELETE CASCADE,
    CONSTRAINT round_robin_draws_unique_category UNIQUE (tournament_id, category_id),
    CONSTRAINT check_group_size CHECK (group_size > 1),
    CONSTRAINT check_number_of_groups CHECK (number_of_groups > 0)
);

-- Add indexes for round_robin_draws
CREATE INDEX IF NOT EXISTS idx_round_robin_draws_tournament_id 
ON public.round_robin_draws USING btree (tournament_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_draws_category_id 
ON public.round_robin_draws USING btree (category_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_draws_status 
ON public.round_robin_draws USING btree (status);

-- Modify round_robin_groups to properly link with draws
ALTER TABLE round_robin_groups
DROP CONSTRAINT IF EXISTS round_robin_groups_unique_group,
ADD COLUMN IF NOT EXISTS draw_id uuid REFERENCES round_robin_draws(id) ON DELETE CASCADE,
ALTER COLUMN category_id TYPE text,
ADD COLUMN IF NOT EXISTS players UUID[] NOT NULL DEFAULT '{}',
ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'draft';

-- Add indexes for round_robin_groups
CREATE INDEX IF NOT EXISTS idx_round_robin_groups_draw_id 
ON public.round_robin_groups USING btree (draw_id);

CREATE INDEX IF NOT EXISTS idx_round_robin_groups_tournament_category
ON public.round_robin_groups USING btree (tournament_id, category_id);

-- Add new unique constraint that includes draw_id
ALTER TABLE round_robin_groups 
ADD CONSTRAINT round_robin_groups_unique_group 
UNIQUE (draw_id, group_number);

-- Create function to automatically create groups when draw is created
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
            draw_id,
            group_number,
            status
        ) VALUES (
            NEW.tournament_id,
            NEW.category_id,
            NEW.id,
            i,
            'draft'
        );
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to automatically create groups when draw is created
DROP TRIGGER IF EXISTS create_groups_on_draw_creation ON round_robin_draws;
CREATE TRIGGER create_groups_on_draw_creation
    AFTER INSERT ON round_robin_draws
    FOR EACH ROW
    EXECUTE FUNCTION create_round_robin_groups();

-- Create function to handle player assignments to groups
CREATE OR REPLACE FUNCTION handle_player_group_assignment(
    p_tournament_id uuid,
    p_category_id text,
    p_group_number integer,
    p_player_id uuid
) RETURNS void AS $$
DECLARE
    v_draw_id uuid;
    v_existing_group_id uuid;
BEGIN
    -- Get the draw ID for this category
    SELECT id INTO v_draw_id
    FROM round_robin_draws
    WHERE tournament_id = p_tournament_id
    AND category_id = p_category_id;

    -- If no draw exists, we can't assign players
    IF v_draw_id IS NULL THEN
        RAISE EXCEPTION 'No draw configuration found for this category. Please create groups first.';
    END IF;

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
        WHERE draw_id = v_draw_id
        AND group_number = p_group_number;

        IF v_existing_group_id IS NOT NULL THEN
            -- Update existing group
            UPDATE round_robin_groups
            SET players = array_append(array_remove(players, p_player_id), p_player_id)
            WHERE id = v_existing_group_id;
        ELSE
            -- This shouldn't happen if draw was created properly
            RAISE EXCEPTION 'Group % not found for this category', p_group_number;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
COMMENT ON COLUMN round_robin_draws.round_deadlines IS 'Array of deadlines for each round in the group';
COMMENT ON COLUMN round_robin_groups.draw_id IS 'Links to the draw configuration that created this group';

-- Create function to migrate existing orphaned groups to draws
CREATE OR REPLACE FUNCTION migrate_existing_groups_to_draws()
RETURNS void AS $$
DECLARE
    rec RECORD;
    v_draw_id uuid;
    v_group_count integer;
    v_avg_group_size integer;
BEGIN
    -- Find all unique tournament/category combinations that have groups but no draws
    FOR rec IN 
        SELECT DISTINCT g.tournament_id, g.category_id
        FROM round_robin_groups g
        LEFT JOIN round_robin_draws d ON d.tournament_id = g.tournament_id AND d.category_id = g.category_id
        WHERE d.id IS NULL AND g.draw_id IS NULL
    LOOP
        -- Count groups and calculate average group size for this category
        SELECT COUNT(*), COALESCE(AVG(array_length(players, 1)), 4)
        INTO v_group_count, v_avg_group_size
        FROM round_robin_groups
        WHERE tournament_id = rec.tournament_id AND category_id = rec.category_id;

        -- Create a draw for this category
        INSERT INTO round_robin_draws (
            tournament_id,
            category_id,
            status,
            group_size,
            number_of_groups
        ) VALUES (
            rec.tournament_id,
            rec.category_id,
            'draft',
            GREATEST(v_avg_group_size::integer, 3), -- Minimum group size of 3
            v_group_count
        ) RETURNING id INTO v_draw_id;

        -- Update existing groups to link to the new draw
        UPDATE round_robin_groups
        SET draw_id = v_draw_id
        WHERE tournament_id = rec.tournament_id
        AND category_id = rec.category_id
        AND draw_id IS NULL;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Run the migration function to fix any existing data
SELECT migrate_existing_groups_to_draws(); 