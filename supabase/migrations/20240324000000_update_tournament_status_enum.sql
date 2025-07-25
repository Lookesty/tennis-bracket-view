-- First, create a backup of existing statuses (as text to avoid enum dependency)
CREATE TABLE temp_tennis_events AS 
SELECT id, status::text as status, last_auto_status::text as last_auto_status 
FROM tennis_events;

-- Drop existing foreign key constraints that might reference the enum
ALTER TABLE tennis_events DROP COLUMN IF EXISTS last_auto_status;

-- Update the tournament_status enum
ALTER TYPE tournament_status RENAME TO tournament_status_old;
CREATE TYPE tournament_status AS ENUM (
    'draft',
    'setup_complete',
    'ready_for_registration',  -- New status: All setup is complete, ready to launch registration
    'waiting_list_open',       -- New status: Collecting interest/waiting list
    'registration_open',
    'registration_closed',
    'draws_complete',
    'live',
    'completed',
    'cancelled'
);

-- First remove the default value
ALTER TABLE tennis_events ALTER COLUMN status DROP DEFAULT;

-- Then cast the column to the new type
ALTER TABLE tennis_events 
    ALTER COLUMN status TYPE tournament_status 
    USING status::text::tournament_status;

-- Add back the default value with proper casting
ALTER TABLE tennis_events ALTER COLUMN status SET DEFAULT 'draft'::tournament_status;

-- Add back the last_auto_status column
ALTER TABLE tennis_events
    ADD COLUMN last_auto_status tournament_status;

-- Update last_auto_status from backup
UPDATE tennis_events e
SET last_auto_status = t.last_auto_status::tournament_status
FROM temp_tennis_events t
WHERE e.id = t.id
AND t.last_auto_status IS NOT NULL;

-- Drop the temporary table
DROP TABLE temp_tennis_events;

-- Now we can safely drop the old enum
DROP TYPE tournament_status_old;

-- Now update the statuses based on configuration state
WITH configured_events AS (
    SELECT DISTINCT e.id
    FROM tennis_events e
    INNER JOIN tournament_info_sections tis ON tis.tournament_id = e.id
    INNER JOIN tournament_registration_config_dev trc ON trc.tournament_id = e.id
    WHERE e.status = 'setup_complete'
)
UPDATE tennis_events
SET status = 'ready_for_registration'::tournament_status
WHERE id IN (SELECT id FROM configured_events); 