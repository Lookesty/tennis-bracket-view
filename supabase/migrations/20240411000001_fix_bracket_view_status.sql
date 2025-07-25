-- Drop and recreate bracket_with_names view to fix status casting
DROP VIEW IF EXISTS public.bracket_with_names;

-- Recreate the view with support for both singles and doubles matches and proper status casting
CREATE VIEW public.bracket_with_names AS
WITH match_winners AS (
  -- Pre-calculate winners for better performance and readability
  SELECT 
    m.tournament_id,
    m.category_id,
    m.round_number - 1 as prev_round,
    m.match_number * 2 - 1 as prev_match1,
    m.match_number * 2 as prev_match2,
    winner_registration_id as winner1_id
  FROM tournament_matches m
  WHERE round_number > 1
)
SELECT
  m.id,
  m.tournament_id,
  m.category_id,
  m.round_number,
  m.match_number,
  -- Get entry1's registration ID (either direct or from previous match winner)
  CASE 
    WHEN m.round_number = 1 THEN m.entry1_registration_id
    ELSE (
      SELECT winner_registration_id
      FROM tournament_matches prev
      WHERE prev.tournament_id = m.tournament_id
        AND prev.category_id = m.category_id
        AND prev.round_number = m.round_number - 1
        AND prev.match_number = m.match_number * 2 - 1
    )
  END AS entry1_registration_id,
  -- Get entry2's registration ID (either direct or from previous match winner)
  CASE 
    WHEN m.round_number = 1 THEN m.entry2_registration_id
    ELSE (
      SELECT winner_registration_id
      FROM tournament_matches prev
      WHERE prev.tournament_id = m.tournament_id
        AND prev.category_id = m.category_id
        AND prev.round_number = m.round_number - 1
        AND prev.match_number = m.match_number * 2
    )
  END AS entry2_registration_id,
  -- Player 1 info (always shown)
  p1.first_name AS entry1_first_name,
  p1.last_name AS entry1_last_name,
  -- Player 1's partner (only for doubles)
  CASE WHEN m.category_id ILIKE '%doubles%' THEN p1p.first_name ELSE NULL END AS entry1_partner_first_name,
  CASE WHEN m.category_id ILIKE '%doubles%' THEN p1p.last_name ELSE NULL END AS entry1_partner_last_name,
  -- Player 2 info (always shown)
  p2.first_name AS entry2_first_name,
  p2.last_name AS entry2_last_name,
  -- Player 2's partner (only for doubles)
  CASE WHEN m.category_id ILIKE '%doubles%' THEN p2p.first_name ELSE NULL END AS entry2_partner_first_name,
  CASE WHEN m.category_id ILIKE '%doubles%' THEN p2p.last_name ELSE NULL END AS entry2_partner_last_name,
  -- Match details
  m.status::match_status as status,
  m.winner_registration_id,
  m.score,
  m.score_details,
  m.completion_date,
  m.deadline,
  m.scheduled_date
FROM tournament_matches m
-- Join for entry1's registration and profile
LEFT JOIN category_registrations cr1 ON cr1.id = 
  CASE 
    WHEN m.round_number = 1 THEN m.entry1_registration_id
    ELSE (
      SELECT winner_registration_id
      FROM tournament_matches
      WHERE tournament_id = m.tournament_id
        AND category_id = m.category_id
        AND round_number = m.round_number - 1
        AND match_number = m.match_number * 2 - 1
    )
  END
LEFT JOIN tournament_registrations_dev tr1 ON tr1.id = cr1.player1_registration_id
LEFT JOIN profiles p1 ON p1.id = tr1.player_id
-- For doubles: Join to get entry1's partner
LEFT JOIN tournament_registrations_dev tr1p ON tr1p.id = cr1.player2_registration_id
LEFT JOIN profiles p1p ON p1p.id = tr1p.player_id
-- Join for entry2's registration and profile
LEFT JOIN category_registrations cr2 ON cr2.id = 
  CASE 
    WHEN m.round_number = 1 THEN m.entry2_registration_id
    ELSE (
      SELECT winner_registration_id
      FROM tournament_matches
      WHERE tournament_id = m.tournament_id
        AND category_id = m.category_id
        AND round_number = m.round_number - 1
        AND match_number = m.match_number * 2
    )
  END
LEFT JOIN tournament_registrations_dev tr2 ON tr2.id = cr2.player1_registration_id
LEFT JOIN profiles p2 ON p2.id = tr2.player_id
-- For doubles: Join to get entry2's partner
LEFT JOIN tournament_registrations_dev tr2p ON tr2p.id = cr2.player2_registration_id
LEFT JOIN profiles p2p ON p2p.id = tr2p.player_id; 
 
 