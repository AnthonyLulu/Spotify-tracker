-- Court Boss v46: read-only calibration of simulated singles and doubles.
-- Run after actual matches have been played; never treats an empty database as a pass.
-- The favorite's expected win probability is compared with observed outcomes.
-- A warning only activates above 200 samples in a given probability band.
WITH completed AS (
 SELECT 'singles'::text AS circuit,
        m.player_a_win_probability::double precision AS p_a,
        CASE WHEN m.winner_id=m.player_a_id THEN 1.0 ELSE 0.0 END AS a_won
 FROM public.world_tournament_matches m
 WHERE m.player_a_id IS NOT NULL AND m.player_b_id IS NOT NULL
   AND m.player_a_id<>m.player_b_id
   AND m.winner_id IN (m.player_a_id,m.player_b_id)
   AND m.player_a_win_probability BETWEEN 0.0 AND 1.0
 UNION ALL
 SELECT 'doubles'::text,
        m.pair_a_win_probability::double precision,
        CASE WHEN m.winner_pair_id=m.pair_a_id THEN 1.0 ELSE 0.0 END
 FROM public.world_doubles_tournament_matches m
 WHERE m.pair_a_id IS NOT NULL AND m.pair_b_id IS NOT NULL
   AND m.pair_a_id<>m.pair_b_id
   AND m.winner_pair_id IN (m.pair_a_id,m.pair_b_id)
   AND m.pair_a_win_probability BETWEEN 0.0 AND 1.0
), measured AS (
 SELECT circuit,
        CASE WHEN GREATEST(p_a,1.0-p_a)<0.60 THEN '50-59%'
             WHEN GREATEST(p_a,1.0-p_a)<0.75 THEN '60-74%'
             WHEN GREATEST(p_a,1.0-p_a)<0.90 THEN '75-89%'
             ELSE '90-100%' END AS favorite_band,
        GREATEST(p_a,1.0-p_a) AS expected_favorite,
        CASE WHEN p_a>=0.5 THEN a_won ELSE 1.0-a_won END AS favorite_won,
        POWER(a_won-p_a,2.0) AS squared_error
 FROM completed
), grouped AS (
 SELECT circuit,favorite_band,COUNT(*)::integer AS samples,
        ROUND(AVG(expected_favorite)::numeric,4) AS expected_win_rate,
        ROUND(AVG(favorite_won)::numeric,4) AS actual_win_rate,
        ROUND(AVG(squared_error)::numeric,4) AS brier_score,
        ROUND(ABS(AVG(expected_favorite)-AVG(favorite_won))::numeric,4) AS calibration_error
 FROM measured GROUP BY circuit,favorite_band
)
SELECT jsonb_build_object(
 'model','CB-MATCH-CALIBRATION-v46',
 'status',CASE WHEN (SELECT COUNT(*) FROM measured)>=200 THEN 'sampled' ELSE 'insufficient_data' END,
 'matches', (SELECT COUNT(*) FROM measured),
 'requires',200,
 'groups',COALESCE((
   SELECT jsonb_agg(jsonb_build_object(
     'circuit',circuit,'band',favorite_band,'samples',samples,
     'expected_favorite_win_rate',expected_win_rate,
     'observed_favorite_win_rate',actual_win_rate,
     'brier_score',brier_score,
     'calibration_error',calibration_error,
     'warning',samples>=200 AND calibration_error>0.08
   ) ORDER BY circuit,favorite_band) FROM grouped
 ),'[]'::jsonb)
) AS report;
