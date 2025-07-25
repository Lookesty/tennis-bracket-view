-- First, drop existing tables that depend on tennis_events
DROP TABLE IF EXISTS tournament_draws CASCADE;
DROP TABLE IF EXISTS tournament_info_sections CASCADE;
DROP TABLE IF EXISTS tournament_registration_config CASCADE;
DROP TABLE IF EXISTS registration_categories CASCADE;
DROP TABLE IF EXISTS doubles_partnerships CASCADE;
DROP TABLE IF EXISTS category_entries CASCADE;

-- Drop the tennis_events table and its enum types
DROP TABLE IF EXISTS tennis_events CASCADE;
DROP TYPE IF EXISTS tournament_status CASCADE;
DROP TYPE IF EXISTS registration_type CASCADE;

-- Create new enum for tournament status with standard naming
CREATE TYPE event_status AS ENUM (
    'draft',
    'setup_complete',
    'registration_open',
    'registration_closed',
    'draws_complete',
    'live',
    'completed',
    'cancelled'
);

-- Create the new tennis_events table with a cleaner structure
CREATE TABLE tennis_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Basic event info
    name TEXT NOT NULL,
    venue TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    deadline DATE NOT NULL,
    open_to TEXT,
    entry_fee NUMERIC DEFAULT 0,
    
    -- Event configuration
    event_type TEXT,
    mode TEXT,
    format TEXT,
    scheduling TEXT,
    categories JSONB,
    max_categories INTEGER DEFAULT 2,
    
    -- Status and ownership
    status event_status DEFAULT 'draft',
    user_id UUID REFERENCES auth.users(id),
    
    -- Registration configuration
    registration_config JSONB DEFAULT jsonb_build_object(
        'type', 'online_form',
        'launch_date', null,
        'launched_at', null,
        'waiting_list', jsonb_build_object(
            'active', false,
            'enabled', false
        )
    )
);

-- Add updated_at trigger
CREATE TRIGGER update_tennis_events_updated_at
    BEFORE UPDATE ON tennis_events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add indexes for better query performance
CREATE INDEX idx_tennis_events_user ON tennis_events(user_id);
CREATE INDEX idx_tennis_events_status ON tennis_events(status);

-- Grant access to authenticated users
GRANT ALL ON tennis_events TO authenticated;

-- Recreate essential dependent tables
CREATE TABLE registration_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES tennis_events(id) ON DELETE CASCADE,
    category JSONB NOT NULL,
    max_entries INTEGER,
    category_status event_status DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for registration_categories
CREATE INDEX idx_registration_categories_tournament ON registration_categories(tournament_id);

-- Grant access to authenticated users
GRANT ALL ON registration_categories TO authenticated; 