-- Drop the existing view first
DROP VIEW IF EXISTS round_robin_matches_with_names;

-- Create round robin matches view with player names for both entries
CREATE VIEW round_robin_matches_with_names AS
SELECT
  m.id,
  m.tournament_id,
  m.group_id,
  m.round_number,
  m.match_number,
  m.entry1_registration_id,
  m.entry2_registration_id,
  -- Entry 1 player info
  p1.first_name AS entry1_first_name,
  p1.last_name AS entry1_last_name,
  p1_partner.first_name AS entry1_partner_first_name,
  p1_partner.last_name AS entry1_partner_last_name,
  -- Entry 2 player info
  p2.first_name AS entry2_first_name,
  p2.last_name AS entry2_last_name,
  p2_partner.first_name AS entry2_partner_first_name,
  p2_partner.last_name AS entry2_partner_last_name,
  -- Match details
  m.status,
  m.winner_registration_id,
  m.score,
  m.score_details,
  m.completion_date,
  m.deadline,
  m.scheduled_date,
  -- Group info
  g.group_number,
  g.category_id
FROM round_robin_matches m
LEFT JOIN round_robin_groups g ON m.group_id = g.id
-- Entry 1 joins
LEFT JOIN category_registrations cr1 ON cr1.id = m.entry1_registration_id
LEFT JOIN tournament_registrations_dev tr1 ON cr1.player1_registration_id = tr1.id
LEFT JOIN profiles p1 ON tr1.player_id = p1.id
LEFT JOIN tournament_registrations_dev tr1_partner ON cr1.player2_registration_id = tr1_partner.id
LEFT JOIN profiles p1_partner ON tr1_partner.player_id = p1_partner.id
-- Entry 2 joins
LEFT JOIN category_registrations cr2 ON cr2.id = m.entry2_registration_id
LEFT JOIN tournament_registrations_dev tr2 ON cr2.player1_registration_id = tr2.id
LEFT JOIN profiles p2 ON tr2.player_id = p2.id
LEFT JOIN tournament_registrations_dev tr2_partner ON cr2.player2_registration_id = tr2_partner.id
LEFT JOIN profiles p2_partner ON tr2_partner.player_id = p2_partner.id; 