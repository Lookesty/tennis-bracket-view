-- Add awaiting_date to match_status enum
ALTER TYPE public.match_status ADD VALUE IF NOT EXISTS 'awaiting_date' BEFORE 'scheduled'; 
 
 