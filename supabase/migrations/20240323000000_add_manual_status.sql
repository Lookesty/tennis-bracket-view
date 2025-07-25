-- Add is_status_manual column to tennis_events table
ALTER TABLE tennis_events
ADD COLUMN is_status_manual BOOLEAN NOT NULL DEFAULT false;

-- Add last_auto_status column to store the last automatically determined status
ALTER TABLE tennis_events
ADD COLUMN last_auto_status tournament_status;

-- Update existing rows to have default values
UPDATE tennis_events
SET is_status_manual = false,
    last_auto_status = status
WHERE is_status_manual IS NULL; 