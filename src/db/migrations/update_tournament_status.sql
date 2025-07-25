-- First, create the enum types if they don't exist
DO $$ BEGIN
    CREATE TYPE tournament_status AS ENUM (
        'draft',
        'setup_complete',
        'reg_open',
        'reg_closed',
        'draws_complete',
        'live',
        'completed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE registration_type AS ENUM (
        'online_form',
        'manual_only',
        'hybrid'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Alter the status column to use the new enum type
ALTER TABLE tennis_events 
    ALTER COLUMN status TYPE tournament_status 
    USING status::tournament_status;

-- Add registration_type column if it doesn't exist
DO $$ BEGIN
    ALTER TABLE tennis_events 
    ADD COLUMN registration_type registration_type DEFAULT 'online_form';
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

-- Set default value for status if not already set
ALTER TABLE tennis_events 
    ALTER COLUMN status SET DEFAULT 'draft'::tournament_status; 