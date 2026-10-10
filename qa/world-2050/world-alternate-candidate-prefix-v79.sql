-- READ ONLY: compare ranked 500-candidate shortlist with full 2,000 pool.
-- This audits RAW candidate order only. It is NOT a substitute for full
-- AI-commitment + calendar + alternate-state equivalence.
-- Isolated staging snapshots on 2026-10-10: events 4, 928, 174.
WITH events(tournament_id) AS (
  VALUES (4::bigint),(928::bigint),(174::bigint)
),
small_pool AS MATERIALIZED (
  SELECT ev.tournament_id, c.player_id,c.effective_rank,p.current_ability,
         row_number() OVER(
           PARTITION BY ev.tournament_id
           ORDER BY c.effective_rank,p.current_ability DESC,c.player_id
         )::int AS rn
  FROM events ev
  CROSS JOIN LATERAL public.tournament_candidate_player_ids(ev.tournament_id,'direct',500) c
  JOIN public.players p ON p.id=c.player_id
),
full_pool AS MATERIALIZED (
  SELECT ev.tournament_id,c.player_id,c.effective_rank,p.current_ability,
         row_number() OVER(
           PARTITION BY ev.tournament_id
           ORDER BY c.effective_rank,p.current_ability DESC,c.player_id
         )::int AS rn
  FROM events ev
  CROSS JOIN LATERAL public.tournament_candidate_player_ids(ev.tournament_id,'direct',2000) c
  JOIN public.players p ON p.id=c.player_id
),
summary AS (
  SELECT ev.tournament_id,
    (SELECT count(*)::int FROM small_pool s WHERE s.tournament_id=ev.tournament_id) AS count_500,
    (SELECT count(*)::int FROM full_pool f WHERE f.tournament_id=ev.tournament_id) AS count_2000,
    (SELECT count(*)::int FROM small_pool s
      FULL JOIN full_pool f
        ON f.tournament_id=s.tournament_id AND f.rn=s.rn
      WHERE coalesce(s.tournament_id,f.tournament_id)=ev.tournament_id
        AND (s.rn<=128 OR f.rn<=128)
        AND (s.player_id IS DISTINCT FROM f.player_id
          OR s.effective_rank IS DISTINCT FROM f.effective_rank)
    ) AS top128_differences,
    (SELECT min(f.rn) FROM full_pool f
      LEFT JOIN small_pool s
        ON s.tournament_id=f.tournament_id AND s.player_id=f.player_id
      WHERE f.tournament_id=ev.tournament_id AND s.player_id IS NULL
    ) AS first_full_only_position
  FROM events ev
)
SELECT s.*,t.name,t.circuit,t.category,
  (s.count_500>=128 AND s.count_2000>=128
    AND s.top128_differences=0) AS raw_top128_prefix_verified,
  false AS final_alternate_list_certified,
  'Raw rank-prefix ONLY; cannot infer AI withdrawals, calendar or future ranking-history behavior'::text
    AS important_limitation
FROM summary s
JOIN public.tournaments t ON t.id=s.tournament_id
ORDER BY s.tournament_id;
