-- Safe read-only provenance audit. ITA source names are not verified ATP IDs.
-- Seven college imports lack any school/DOB provenance on their stored player profile.
-- Michael Zheng has a Columbia University school match, but NCAA verification remains false.
-- No synthetic Gabriel Diallo promotion. No player/baseline mutations.
BEGIN READ ONLY;
SET LOCAL statement_timeout='10000ms';
WITH source AS (
 SELECT * FROM jsonb_to_recordset($curated$[{"rank":70,"stage_id":20073,"name":"Ethan Quinn","points":802,"atp_player_id":210319,"country":"USA","birth_date":"20040312","school":"University of Georgia","stage_data_source":"ITA Division I historical ranking · 07/03/2023"},{"rank":71,"stage_id":20093,"name":"Jacob Fearnley","points":787,"atp_player_id":207985,"country":"GBR","birth_date":"20010715","school":"Texas Christian University","stage_data_source":"ITA Division I historical ranking · 07/03/2023"},{"rank":90,"stage_id":20069,"name":"Eliot Spizzirri","points":680,"atp_player_id":208118,"country":"USA","birth_date":"20011223","school":"University of Texas","stage_data_source":"ITA Division I historical ranking · 07/03/2023"},{"rank":129,"stage_id":20126,"name":"Liam Draxl","points":476,"atp_player_id":208119,"country":"CAN","birth_date":"20011205","school":"University of Kentucky","stage_data_source":"ITA Division I historical ranking · 07/03/2023"},{"rank":146,"stage_id":20057,"name":"Colton Smith","points":424,"atp_player_id":212256,"country":"USA","birth_date":"20030305","school":"University of Arizona","stage_data_source":"ITA Division I historical ranking · 07/03/2023"},{"rank":167,"stage_id":20160,"name":"Nishesh Basavareddy","points":349,"atp_player_id":210460,"country":"USA","birth_date":"20050502","school":"Stanford University","stage_data_source":"ITA Division I historical ranking · 07/03/2023"},{"rank":192,"stage_id":5108,"name":"Michael Zheng","points":315,"atp_player_id":210116,"country":"USA","birth_date":"20040127","school":"Columbia University","stage_data_source":"ITA verified college player · Court Boss NCAA import"},{"rank":193,"stage_id":20034,"name":"Arthur Fery","points":313,"atp_player_id":209259,"country":"GBR","birth_date":"20020712","school":"Stanford University","stage_data_source":"ITA Division I historical ranking · 07/03/2023"}]$curated$::jsonb)
 AS x(rank integer,stage_id bigint,name text,points integer,
      atp_player_id bigint,country text,birth_date text,
      school text,stage_data_source text)
), stage AS (
 SELECT x.*,p.id actual_id,p.name actual_name,p.data_source actual_source,
 p.game_generated,p.ncaa_school,p.ncaa_verified,p.birth_date stored_birth,
 p.atp_source_id stored_atp_id,p.country stored_country,
 (p.id IS NOT NULL AND p.name=x.name AND p.data_source=x.stage_data_source
 AND p.game_generated=false AND p.atp_source_id IS NULL) AS stable_candidate,
 (p.ncaa_school=x.school AND p.ncaa_school IS NOT NULL) AS recorded_college_match
 FROM source x LEFT JOIN public.players p ON p.id=x.stage_id
), synthetic AS (
 SELECT count(*) generated_homonym_count FROM public.players p
 WHERE p.name='Gabriel Diallo' AND p.game_generated=true
   AND p.country='BEL' AND p.birth_date=DATE '2005-11-06'
)
SELECT jsonb_build_object(
 'scope','ISOLATED_STAGE_ONLY',
 'snapshot','2025-12-01',
 'source_rows', (SELECT count(*) FROM source),
 'stable_college_candidates',(SELECT count(*) FROM stage WHERE stable_candidate),
 'candidates_with_school_match',(SELECT count(*) FROM stage WHERE recorded_college_match),
 'candidates_without_independent_school_field',(SELECT count(*) FROM stage WHERE stable_candidate AND NOT recorded_college_match),
 'unmatched_candidates',(SELECT coalesce(jsonb_agg(jsonb_build_object('rank',rank,'name',name,'stage_id',stage_id)),'[]'::jsonb) FROM stage WHERE NOT stable_candidate),
 'synthetic_gabriel_diallo_collision',(SELECT generated_homonym_count FROM synthetic),
 'ATP_ranking_baseline_rows',(SELECT count(*) FROM public.atp_ranking_baseline_2025_12_01),
 'staging_source_cross_circuit_canonical_link_certified',false,
 'official_2025_ranking_certified',false,
 '2050_certified',false
) AS candidate_receipt;
COMMIT;
