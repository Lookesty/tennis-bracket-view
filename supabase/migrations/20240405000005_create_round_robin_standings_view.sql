-- Create view for round robin standings with player names
DROP VIEW IF EXISTS round_robin_standings;

CREATE OR REPLACE VIEW round_robin_standings AS
WITH match_results AS (
  SELECT 
    m.tournament_id,
    m.category_id,
    m.group_id,
    m.draw_id,
    CASE 
      WHEN m.winner_registration_id = m.entry1_registration_id THEN m.entry1_registration_id
      ELSE m.entry2_registration_id
    END as registration_id,
    CASE 
      WHEN m.status = 'completed' THEN
        CASE 
          WHEN m.winner_registration_id = m.entry1_registration_id THEN m.winner_sets
          ELSE m.loser_sets
        END
      ELSE 0
    END as sets_won,
    CASE 
      WHEN m.status = 'completed' THEN
        CASE 
          WHEN m.winner_registration_id = m.entry1_registration_id THEN m.loser_sets
          ELSE m.winner_sets
        END
      ELSE 0
    END as sets_lost,
    CASE 
      WHEN m.status = 'completed' THEN
        CASE 
          WHEN m.winner_registration_id IS NOT NULL THEN 2
          ELSE 1
        END
      ELSE 0
    END as points
  FROM round_robin_matches m
  WHERE m.status = 'completed'
)
SELECT 
  r.tournament_id,
  r.category_id,
  r.group_id,
  r.draw_id,
  cr.id as registration_id,
  p.first_name,
  p.last_name,
  COALESCE(SUM(r.points), 0) as total_points,
  COALESCE(SUM(r.sets_won), 0) as total_sets_won,
  COALESCE(SUM(r.sets_lost), 0) as total_sets_lost,
  COALESCE(SUM(r.sets_won) - SUM(r.sets_lost), 0) as set_difference,
  g.group_number,
  g.status as group_status,
  d.status as draw_status
FROM round_robin_groups g
CROSS JOIN LATERAL unnest(g.players) as player_id_list(player_id)
JOIN category_registrations cr 
  ON (cr.player1_registration_id = player_id_list.player_id OR cr.player2_registration_id = player_id_list.player_id)
  AND cr.tournament_id = g.tournament_id 
  AND cr.category_id = g.category_id
JOIN profiles p ON p.id = player_id_list.player_id
LEFT JOIN match_results r 
  ON r.registration_id = cr.id
  AND r.group_id = g.id
JOIN round_robin_draws d ON d.id = g.draw_id
GROUP BY 
  r.tournament_id, 
  r.category_id, 
  r.group_id,
  r.draw_id,
  cr.id,
  p.first_name,
  p.last_name,
  g.group_number,
  g.status,
  d.status
ORDER BY 
  g.group_number,
  total_points DESC,
  set_difference DESC,
  total_sets_won DESC;

-- Add comment for clarity
COMMENT ON VIEW round_robin_standings IS 'Shows standings for round robin groups with player names and match statistics'; 