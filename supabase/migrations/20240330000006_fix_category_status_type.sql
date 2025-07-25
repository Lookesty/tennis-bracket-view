-- First, temporarily change the column to text to avoid type conflicts
ALTER TABLE registration_categories 
    ALTER COLUMN category_status TYPE text;

-- Make sure we have the correct category_status enum
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_status') THEN
        CREATE TYPE category_status AS ENUM (
            'open',
            'closed'
        );
    END IF;
END $$;

-- Update any existing values to match the new enum
UPDATE registration_categories
SET category_status = 'open'
WHERE category_status NOT IN ('open', 'closed');

-- Convert the column back to the correct enum type
ALTER TABLE registration_categories 
    ALTER COLUMN category_status TYPE category_status 
    USING category_status::category_status;

-- Set the default value
ALTER TABLE registration_categories 
    ALTER COLUMN category_status SET DEFAULT 'open'::category_status;

-- Add a comment for clarity
COMMENT ON COLUMN registration_categories.category_status IS 'Status of the category (open/closed) - independent of tournament status'; 