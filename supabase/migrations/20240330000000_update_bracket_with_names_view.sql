-- Update bracket_with_names view to include scheduled_date
CREATE OR REPLACE VIEW public.bracket_with_names AS
SELECT
  m.id,
  m.tournament_id,
  m.category_id,
  m.round_number,
  m.match_number,
  CASE
    WHEN m.round_number = 1 THEN m.entry1_registration_id
    ELSE (
      SELECT
        tournament_matches.winner_registration_id
      FROM
        tournament_matches
      WHERE
        tournament_matches.tournament_id = m.tournament_id
        AND tournament_matches.category_id = m.category_id
        AND tournament_matches.round_number = (m.round_number - 1)
        AND tournament_matches.match_number = (m.match_number * 2 - 1)
    )
  END AS entry1_registration_id,
  CASE
    WHEN m.round_number = 1 THEN m.entry2_registration_id
    ELSE (
      SELECT
        tournament_matches.winner_registration_id
      FROM
        tournament_matches
      WHERE
        tournament_matches.tournament_id = m.tournament_id
        AND tournament_matches.category_id = m.category_id
        AND tournament_matches.round_number = (m.round_number - 1)
        AND tournament_matches.match_number = (m.match_number * 2)
    )
  END AS entry2_registration_id,
  p1.first_name AS entry1_first_name,
  p1.last_name AS entry1_last_name,
  p2.first_name AS entry2_first_name,
  p2.last_name AS entry2_last_name,
  m.status,
  m.winner_registration_id,
  m.score,
  m.score_details,
  m.completion_date,
  m.deadline,
  m.scheduled_date
FROM
  tournament_matches m
  LEFT JOIN category_registrations cr1 ON cr1.id = CASE
    WHEN m.round_number = 1 THEN m.entry1_registration_id
    ELSE (
      SELECT
        tournament_matches.winner_registration_id
      FROM
        tournament_matches
      WHERE
        tournament_matches.tournament_id = m.tournament_id
        AND tournament_matches.category_id = m.category_id
        AND tournament_matches.round_number = (m.round_number - 1)
        AND tournament_matches.match_number = (m.match_number * 2 - 1)
    )
  END
  LEFT JOIN tournament_registrations_dev trd1 ON cr1.player1_registration_id = trd1.id
  LEFT JOIN profiles p1 ON trd1.player_id = p1.id
  LEFT JOIN category_registrations cr2 ON cr2.id = CASE
    WHEN m.round_number = 1 THEN m.entry2_registration_id
    ELSE (
      SELECT
        tournament_matches.winner_registration_id
      FROM
        tournament_matches
      WHERE
        tournament_matches.tournament_id = m.tournament_id
        AND tournament_matches.category_id = m.category_id
        AND tournament_matches.round_number = (m.round_number - 1)
        AND tournament_matches.match_number = (m.match_number * 2)
    )
  END
  LEFT JOIN tournament_registrations_dev trd2 ON cr2.player1_registration_id = trd2.id
  LEFT JOIN profiles p2 ON trd2.player_id = p2.id; 