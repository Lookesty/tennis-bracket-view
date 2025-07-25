-- Drop the view if it exists
DROP VIEW IF EXISTS public.round_robin_standings;

-- Create view for round robin standings
CREATE VIEW round_robin_standings AS
WITH match_results AS (
  SELECT 
    m.tournament_id,
    m.category_id,
    m.group_id,
    cr_1.id AS registration_id,
    -- Get category configuration including scoring system
    (SELECT (c->>'roundRobinScoring')::jsonb
     FROM tennis_events e,
          jsonb_array_elements(e.categories::jsonb) as c
     WHERE e.id = m.tournament_id
     AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id) as scoring_config,
    -- Count matches
    COUNT(*) FILTER (WHERE m.status = 'completed' AND m.winner_registration_id = cr_1.id) AS completed_matches_won,
    COUNT(*) FILTER (WHERE m.status = 'completed' AND (m.entry1_registration_id = cr_1.id OR m.entry2_registration_id = cr_1.id) AND m.winner_registration_id <> cr_1.id) AS completed_matches_lost,
    COUNT(*) FILTER (WHERE m.status = 'walkover' AND m.winner_registration_id = cr_1.id) AS walkover_matches_won,
    COUNT(*) FILTER (WHERE m.status = 'walkover' AND (m.entry1_registration_id = cr_1.id OR m.entry2_registration_id = cr_1.id) AND m.winner_registration_id <> cr_1.id) AS walkover_matches_lost,
    -- Calculate sets won/lost (including walkovers)
    SUM(
      CASE 
        WHEN m.status = 'completed' THEN
          CASE 
            WHEN cr_1.id = m.entry1_registration_id THEN (
              SELECT COUNT(*)
              FROM jsonb_array_elements(m.score_details->'sets') as s
              WHERE (s->>0)::int > (s->>1)::int
            )
            ELSE (
              SELECT COUNT(*)
              FROM jsonb_array_elements(m.score_details->'sets') as s
              WHERE (s->>1)::int > (s->>0)::int
            )
          END
        WHEN m.status = 'walkover' AND m.winner_registration_id = cr_1.id THEN
          COALESCE((SELECT c->'scoring'->'numberOfSets'
           FROM tennis_events e,
                jsonb_array_elements(e.categories::jsonb) as c
           WHERE e.id = m.tournament_id
           AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id)::int, 2)
        WHEN m.status = 'walkover' AND m.winner_registration_id <> cr_1.id THEN 0
        ELSE 0
      END
    ) as sets_won,
    SUM(
      CASE 
        WHEN m.status = 'completed' THEN
          CASE 
            WHEN cr_1.id = m.entry1_registration_id THEN (
              SELECT COUNT(*)
              FROM jsonb_array_elements(m.score_details->'sets') as s
              WHERE (s->>0)::int < (s->>1)::int
            )
            ELSE (
              SELECT COUNT(*)
              FROM jsonb_array_elements(m.score_details->'sets') as s
              WHERE (s->>1)::int < (s->>0)::int
            )
          END
        WHEN m.status = 'walkover' AND m.winner_registration_id = cr_1.id THEN 0
        WHEN m.status = 'walkover' AND m.winner_registration_id <> cr_1.id THEN
          COALESCE((SELECT c->'scoring'->'numberOfSets'
           FROM tennis_events e,
                jsonb_array_elements(e.categories::jsonb) as c
           WHERE e.id = m.tournament_id
           AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id)::int, 2)
      ELSE 0
      END
    ) as sets_lost,
    -- Calculate games won/lost (only from completed matches, excluding tiebreaks)
    SUM(
      CASE WHEN m.status = 'completed' THEN
        CASE 
          WHEN cr_1.id = m.entry1_registration_id THEN (
            SELECT SUM(
              CASE 
                WHEN (sc.value->>'type')::text = 'tiebreak' THEN 0
                ELSE (s.value->>0)::int
              END)
            FROM jsonb_array_elements(m.score_details->'sets') WITH ORDINALITY as s(value, ordinality)
            CROSS JOIN LATERAL jsonb_array_elements((SELECT c->'scoring'->'setConfigs'
                                                   FROM tennis_events e,
                                                        jsonb_array_elements(e.categories::jsonb) as c
                                                   WHERE e.id = m.tournament_id
                                                   AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id)) WITH ORDINALITY as sc(value, idx)
            WHERE s.ordinality = sc.idx
          )
          ELSE (
            SELECT SUM(
              CASE 
                WHEN (sc.value->>'type')::text = 'tiebreak' THEN 0
                ELSE (s.value->>1)::int
              END)
            FROM jsonb_array_elements(m.score_details->'sets') WITH ORDINALITY as s(value, ordinality)
            CROSS JOIN LATERAL jsonb_array_elements((SELECT c->'scoring'->'setConfigs'
                                                   FROM tennis_events e,
                                                        jsonb_array_elements(e.categories::jsonb) as c
                                                   WHERE e.id = m.tournament_id
                                                   AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id)) WITH ORDINALITY as sc(value, idx)
            WHERE s.ordinality = sc.idx
          )
        END
      ELSE 0
      END
    ) as games_won,
    SUM(
      CASE WHEN m.status = 'completed' THEN
        CASE 
          WHEN cr_1.id = m.entry1_registration_id THEN (
            SELECT SUM(
              CASE 
                WHEN (sc.value->>'type')::text = 'tiebreak' THEN 0
                ELSE (s.value->>1)::int
              END)
            FROM jsonb_array_elements(m.score_details->'sets') WITH ORDINALITY as s(value, ordinality)
            CROSS JOIN LATERAL jsonb_array_elements((SELECT c->'scoring'->'setConfigs'
                                                   FROM tennis_events e,
                                                        jsonb_array_elements(e.categories::jsonb) as c
                                                   WHERE e.id = m.tournament_id
                                                   AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id)) WITH ORDINALITY as sc(value, idx)
            WHERE s.ordinality = sc.idx
          )
          ELSE (
            SELECT SUM(
              CASE 
                WHEN (sc.value->>'type')::text = 'tiebreak' THEN 0
                ELSE (s.value->>0)::int
              END)
            FROM jsonb_array_elements(m.score_details->'sets') WITH ORDINALITY as s(value, ordinality)
            CROSS JOIN LATERAL jsonb_array_elements((SELECT c->'scoring'->'setConfigs'
                                                   FROM tennis_events e,
                                                        jsonb_array_elements(e.categories::jsonb) as c
                                                   WHERE e.id = m.tournament_id
                                                   AND (c->>'gender')::text || '_' || (c->>'type')::text || '_' || COALESCE((c->>'ageGroup')::text, 'open') = m.category_id)) WITH ORDINALITY as sc(value, idx)
            WHERE s.ordinality = sc.idx
          )
        END
      ELSE 0
      END
    ) as games_lost,
    -- Count completed matches for average calculation
    COUNT(*) FILTER (WHERE m.status = 'completed') as completed_matches_count
  FROM round_robin_matches m
  JOIN category_registrations cr_1 ON m.entry1_registration_id = cr_1.id OR m.entry2_registration_id = cr_1.id
  WHERE m.status IN ('completed', 'walkover')
  GROUP BY m.tournament_id, m.category_id, m.group_id, cr_1.id
)
SELECT 
  g.tournament_id,
  g.category_id,
  g.id AS group_id,
  g.group_number,
  cr.id AS registration_id,
  p.first_name,
  p.last_name,
  mr.completed_matches_won + mr.walkover_matches_won AS matches_won,
  mr.completed_matches_lost + mr.walkover_matches_lost AS matches_lost,
  mr.sets_won AS total_sets_won,
  mr.sets_lost AS total_sets_lost,
  mr.games_won AS games_won,
  mr.games_lost AS games_lost,
  -- Calculate walkover games difference
  CASE 
    WHEN mr.completed_matches_count > 0 THEN
      ROUND(((mr.games_won - mr.games_lost)::decimal / mr.completed_matches_count) * mr.walkover_matches_won, 2)
    ELSE 0
  END AS walkover_games_difference,
  -- Add WGD column for display
  CASE 
    WHEN mr.completed_matches_count > 0 THEN
      ROUND(((mr.games_won - mr.games_lost)::decimal / mr.completed_matches_count) * mr.walkover_matches_won, 2)
    ELSE 0
  END AS WGD,
  -- Calculate total points based on scoring configuration
  COALESCE(
    CASE 
      WHEN (mr.scoring_config->>'type')::text = 'match_points' THEN
        -- Regular wins (including walkover wins) get win points
        ((mr.completed_matches_won + mr.walkover_matches_won) * (mr.scoring_config->'matchPoints'->>'win')::int) +
        -- Regular losses get loss points
        (mr.completed_matches_lost * (mr.scoring_config->'matchPoints'->>'loss')::int) +
        -- Walkover losses get walkover points
        (mr.walkover_matches_lost * (mr.scoring_config->'matchPoints'->>'walkover')::int)
      WHEN (mr.scoring_config->>'type')::text = 'set_points' THEN
        -- All sets won (including walkover sets) get points per set
        mr.sets_won * (mr.scoring_config->'setPoints'->>'perSetWon')::int
      ELSE
        -- Default scoring if no config (2 points for win including walkover, 1 for loss, 0 for walkover loss)
        ((mr.completed_matches_won + mr.walkover_matches_won) * 2) +
        (mr.completed_matches_lost * 1) +
        (mr.walkover_matches_lost * 0)
    END, 0) AS total_points,
  -- Calculate performance index
  COALESCE(
    CASE 
      WHEN (mr.scoring_config->>'type')::text = 'match_points' THEN
        -- Points + set difference/10 + games difference/100 + WGD/100
        ((mr.completed_matches_won + mr.walkover_matches_won) * (mr.scoring_config->'matchPoints'->>'win')::int) +
        (mr.completed_matches_lost * (mr.scoring_config->'matchPoints'->>'loss')::int) +
        (mr.walkover_matches_lost * (mr.scoring_config->'matchPoints'->>'walkover')::int) +
        ((mr.sets_won - mr.sets_lost)::decimal * 0.1) +
        ((mr.games_won - mr.games_lost)::decimal * 0.01) +
        (CASE 
          WHEN mr.completed_matches_count > 0 THEN
            (ROUND(((mr.games_won - mr.games_lost)::decimal / mr.completed_matches_count) * mr.walkover_matches_won, 2) * 0.01)
          ELSE 0
        END)
      WHEN (mr.scoring_config->>'type')::text = 'set_points' THEN
        -- Points + games difference/100 + WGD/100
        (mr.sets_won * (mr.scoring_config->'setPoints'->>'perSetWon')::int) +
        ((mr.games_won - mr.games_lost)::decimal * 0.01) +
        (CASE 
          WHEN mr.completed_matches_count > 0 THEN
            (ROUND(((mr.games_won - mr.games_lost)::decimal / mr.completed_matches_count) * mr.walkover_matches_won, 2) * 0.01)
          ELSE 0
        END)
      ELSE
        -- Default performance index if no config
        ((mr.completed_matches_won + mr.walkover_matches_won) * 2 + mr.completed_matches_lost) +
        ((mr.sets_won - mr.sets_lost)::decimal * 0.1) +
        ((mr.games_won - mr.games_lost)::decimal * 0.01) +
        (CASE 
          WHEN mr.completed_matches_count > 0 THEN
            (ROUND(((mr.games_won - mr.games_lost)::decimal / mr.completed_matches_count) * mr.walkover_matches_won, 2) * 0.01)
          ELSE 0
        END)
    END, 0) AS performance_index,
  (mr.sets_won - mr.sets_lost) AS set_difference
FROM round_robin_groups g
JOIN category_registrations cr ON cr.id = ANY (g.players)
JOIN tournament_registrations_dev tr ON tr.id = cr.player1_registration_id
JOIN profiles p ON p.id = tr.player_id
LEFT JOIN match_results mr ON mr.tournament_id = g.tournament_id 
  AND mr.category_id = g.category_id 
  AND mr.group_id = g.id 
  AND mr.registration_id = cr.id
ORDER BY 
  g.tournament_id, 
  g.category_id, 
  g.group_number, 
  total_points DESC, 
  performance_index DESC; 
-- Create a view for round robin standings
CREATE VIEW public.round_robin_standings AS
WITH match_stats AS (
  SELECT 
    cr.id as registration_id,
    COUNT(CASE WHEN m.status = 'completed' AND m.winner_registration_id = cr.id THEN 1 END) as matches_won,
    COUNT(CASE WHEN m.status = 'completed' AND m.winner_registration_id != cr.id THEN 1 END) as matches_lost,
    COALESCE(SUM(CASE 
      WHEN m.status = 'completed' AND m.winner_registration_id = cr.id THEN m.winner_sets
      WHEN m.status = 'completed' THEN m.loser_sets
      ELSE 0
    END), 0) as total_sets_won,
    COALESCE(SUM(CASE 
      WHEN m.status = 'completed' AND m.winner_registration_id = cr.id THEN m.loser_sets
      WHEN m.status = 'completed' THEN m.winner_sets
      ELSE 0
    END), 0) as total_sets_lost,
    COALESCE(SUM(CASE 
      WHEN m.status = 'completed' AND m.winner_registration_id = cr.id THEN 2
      WHEN m.status = 'completed' THEN 1
      ELSE 0
    END), 0) as total_points
  FROM round_robin_matches m
  JOIN category_registrations cr ON 
    (cr.id = m.entry1_registration_id OR cr.id = m.entry2_registration_id)
  WHERE m.status = 'completed'
  GROUP BY cr.id
)
SELECT DISTINCT
  g.category_id,
  g.id as group_id,
  g.tournament_id,
  g.group_number,
  cr.id as registration_id,
  p.first_name,
  p.last_name,
  p.gender,
  rc.category->>'name' as category_name,
  COALESCE(ms.matches_won, 0) as matches_won,
  COALESCE(ms.matches_lost, 0) as matches_lost,
  COALESCE(ms.total_sets_won, 0) as total_sets_won,
  COALESCE(ms.total_sets_lost, 0) as total_sets_lost,
  0 as games_won, -- Placeholder as we don't track games yet
  0 as games_lost, -- Placeholder as we don't track games yet
  COALESCE(ms.total_points, 0) as total_points,
  COALESCE(ms.total_points, 0) as performance_index, -- Using total_points as performance_index for now
  (COALESCE(ms.total_sets_won, 0) - COALESCE(ms.total_sets_lost, 0)) as set_difference
FROM round_robin_groups g
CROSS JOIN LATERAL unnest(g.players) as player_list(player_id)
JOIN tournament_registrations_dev tr ON tr.id = player_list.player_id
JOIN profiles p ON p.id = tr.player_id
JOIN category_registrations cr ON 
  cr.tournament_id = g.tournament_id AND
  cr.category_id = g.category_id AND
  (cr.player1_registration_id = tr.id OR cr.player2_registration_id = tr.id)
JOIN registration_categories rc ON 
  rc.tournament_id = g.tournament_id AND
  rc.category->>'id' = g.category_id
LEFT JOIN match_stats ms ON ms.registration_id = cr.id
ORDER BY 
  g.group_number, 
  COALESCE(ms.total_points, 0) DESC, 
  (COALESCE(ms.total_sets_won, 0) - COALESCE(ms.total_sets_lost, 0)) DESC,
  COALESCE(ms.total_sets_won, 0) DESC;

-- Grant permissions
GRANT SELECT ON public.round_robin_standings TO authenticated;
GRANT SELECT ON public.round_robin_standings TO service_role; 