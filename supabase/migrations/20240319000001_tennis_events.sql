-- Create the tennis_events table
CREATE TABLE public.tennis_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  status_updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  name TEXT NOT NULL,
  venue TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  deadline DATE NOT NULL,
  open_to TEXT NULL,
  entry_fee NUMERIC NULL DEFAULT 0,
  event_type TEXT NULL,
  mode TEXT NULL,
  format TEXT NULL,
  scheduling TEXT NULL,
  categories JSONB NULL,
  max_categories INTEGER NULL DEFAULT 2,
  status public.event_status NULL DEFAULT 'draft'::event_status,
  user_id UUID NULL,
  registration_config JSONB NULL DEFAULT jsonb_build_object(
    'type', 'hybrid',
    'launch_date', NULL,
    'launched_at', NULL,
    'waiting_list', jsonb_build_object('active', false, 'enabled', false)
  ),
  registration_enabled BOOLEAN NULL DEFAULT false,
  registration_launched_at TIMESTAMP WITH TIME ZONE NULL,
  registration_type public.registration_type NOT NULL DEFAULT 'hybrid'::registration_type,
  registration_closed_at TIMESTAMP WITH TIME ZONE NULL,
  all_registrations_processed BOOLEAN NULL DEFAULT false,
  warning_days INTEGER NOT NULL DEFAULT 3,
  draws_submitted_at TIMESTAMP WITH TIME ZONE NULL,
  started_at TIMESTAMP WITH TIME ZONE NULL,
  
  CONSTRAINT tennis_events_pkey PRIMARY KEY (id),
  CONSTRAINT tennis_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT check_warning_days CHECK (warning_days > 0)
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tennis_events_user ON public.tennis_events USING btree (user_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_tennis_events_status ON public.tennis_events USING btree (status) TABLESPACE pg_default;

-- Create triggers
CREATE TRIGGER handle_tournament_categories_trigger
  AFTER INSERT OR UPDATE OF categories
  ON tennis_events
  FOR EACH ROW
  EXECUTE FUNCTION handle_tournament_categories();

CREATE TRIGGER registration_status_trigger
  BEFORE UPDATE
  ON tennis_events
  FOR EACH ROW
  EXECUTE FUNCTION handle_registration_status();

CREATE TRIGGER set_tournament_status_from_auto_trigger
  BEFORE INSERT OR UPDATE
  ON tennis_events
  FOR EACH ROW
  EXECUTE FUNCTION set_tournament_status_from_auto();

CREATE TRIGGER update_tennis_events_updated_at
  BEFORE UPDATE
  ON tennis_events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column(); 