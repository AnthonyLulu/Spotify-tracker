-- Read-only acceptance probe. Run against a staging database after applying
-- the v48 migration, before deciding on a production deployment.
-- A matchup must not become more/less likely merely by swapping A and B.
-- Court speed is unitless (~0.58 to 1.30), NEVER a percentage such as 50.
WITH pairings AS (
 SELECT * FROM (VALUES
   (1::bigint,3::bigint,'hard'::text,1.000::numeric,3),
   (1,3,'clay',0.764,5),
   (1,3,'grass',1.110,5),
   (1,12,'hard',0.923,5),
   (3,12,'clay',0.764,5)
 ) t(a,b,surface,court_speed,best_of)
),
compared AS (
 SELECT f.*,
 (public.player_matchup_probability_v4(a,b,surface,DATE '2025-12-01',court_speed,best_of)->>'player_a_probability')::numeric AS p_ab,
 (public.player_matchup_probability_v4(b,a,surface,DATE '2025-12-01',court_speed,best_of)->>'player_a_probability')::numeric AS p_ba
 FROM pairings f
)
SELECT a,b,surface,best_of,p_ab,p_ba,
  round(abs(p_ab+p_ba-1),4) AS absolute_order_bias,
  abs(p_ab+p_ba-1)<=0.003 AS passes_order_invariance
FROM compared
ORDER BY a,b,surface;