-- Read-only rehearsal of a deterministic synthetic 2025 adult seed.
-- Does NOT insert players, change the 85 original fixtures or call game mutations.
-- Pairing is within-country; no copied real-player data.
WITH base AS (
 SELECT count(*) FILTER (
   WHERE career_status='active' AND
   coalesce(CASE WHEN birth_date IS NOT NULL
     THEN extract(year FROM age(date '2025-12-01',birth_date))::int END, age, 99)
   BETWEEN 18 AND 45
 )::int active_adults,
 count(*) FILTER(WHERE career_status='active')::int active_players
 FROM public.players
 WHERE coalesce(data_source,'') NOT ILIKE 'hidden duplicate merged into %'
), name_counts AS (
 SELECT country,
   count(DISTINCT value) FILTER(WHERE kind='first' AND length(trim(value)) BETWEEN 2 AND 28)::bigint firsts,
   count(DISTINCT value) FILTER(WHERE kind='last' AND length(trim(value)) BETWEEN 2 AND 34)::bigint lasts
 FROM cb_e2e_reconstruction_20261010.licensed_name_seed
 WHERE license IN ('CC0','MIT') AND country ~ '^[A-Z]{3}$'
 AND trim(value) !~ '[0-9@_/\\]'
 GROUP BY country
), eligible AS (
 SELECT *,firsts*lasts AS combinations FROM name_counts WHERE firsts>=8 AND lasts>=8
), thresholds AS (
 SELECT 24000 AS adult_floor,27000 AS preferred_adult_pool,
  25000 AS provisional_max_new_adults
), headroom AS (
 SELECT base.*, thresholds.*,
 greatest(0,adult_floor-base.active_adults) AS minimum_needed,
 greatest(0,preferred_adult_pool-base.active_adults) AS preferred_needed
 FROM base CROSS JOIN thresholds
)
SELECT jsonb_build_object(
 'environment','ISOLATED_ONLY',
 'mode','READ_ONLY_SYNTHETIC_SEED_FEASIBILITY',
 'adult_floor',adult_floor,
 'preferred_adult_pool',preferred_adult_pool,
 'existing_adults',active_adults,
 'existing_active_players',active_players,
 'minimum_new_adults',minimum_needed,
 'preferred_new_adults',preferred_needed,
 'seed_candidates_cap',provisional_max_new_adults,
 'licensed_name_rows',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.licensed_name_seed),
 'eligible_countries',(SELECT count(*) FROM eligible),
 'total_within_country_name_combinations',(SELECT coalesce(sum(combinations),0) FROM eligible),
 'country_with_fewest_combinations',(SELECT min(combinations) FROM eligible),
 'licensed_country_preview',(SELECT coalesce(jsonb_agg(jsonb_build_object('country',country,'firsts',firsts,'lasts',lasts,'combinations',combinations) ORDER BY combinations DESC),'[]'::jsonb) FROM (SELECT * FROM eligible ORDER BY combinations DESC LIMIT 12) top_country),
 'meets_minimum_name_capacity', (SELECT coalesce(sum(combinations),0) >= minimum_needed FROM eligible),
 'is_2050_certified',false,
 'production_rows_copied',false
) AS seed_plan FROM headroom;
