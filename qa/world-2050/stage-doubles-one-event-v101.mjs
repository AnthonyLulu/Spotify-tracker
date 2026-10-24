// P0: one EVENT-DATE at a time, atomic staged 2026 doubles verification.
// Fail closed: one unsimulated, ordinary men's doubles tournament on that day;
// zero user saves/careers; no running singles job; protected stage checkpoint.
// A failed preflight, absent champion, point ledger, or incomplete final rolls
// back the complete PostgreSQL transaction, including player-side effects.
import {pathToFileURL} from 'node:url';
import {assertDirectStageUrl,queryWithPsql} from './stage-psql-adapter-v99.mjs';

export function validDoublesEventDate(value){
 if(typeof value!=='string'||!/^2026-\d\d-\d\d$/.test(value))throw Error('Only 2026 stage dates');
 const d=new Date(value+'T00:00:00Z');
 if(!Number.isFinite(d.getTime())||d.toISOString().slice(0,10)!==value)throw Error('Invalid date');
 if(value<'2026-01-04'||value>'2026-12-31')throw Error('Out of 2026 range');
 return value;
}
export function doublesEventWindow(date){
 validDoublesEventDate(date);
 const d=new Date(date+'T00:00:00Z');
 d.setUTCDate(d.getUTCDate()-1);
 return {fromDate:d.toISOString().slice(0,10),toDate:date};
}
export function readDoublesEventSql(date){
 validDoublesEventDate(date);
 return `WITH candidates AS (
 SELECT t.id,t.name,t.circuit,t.category,
    coalesce(t.end_date,t.start_date) end_date,
    coalesce(t.doubles_draw_size,16) draw_size
 FROM public.tournaments t
 WHERE t.doubles=true AND coalesce(t.is_active,true)
   AND t.circuit IN ('ATP','Challenger','ITF')
   AND t.category NOT IN ('United Cup','Laver Cup','ATP Finals')
   AND coalesce(t.end_date,t.start_date)=DATE '${date}'
   AND NOT EXISTS(SELECT 1 FROM public.world_doubles_tournament_simulations s
                  WHERE s.tournament_id=t.id)
)
SELECT jsonb_build_object(
 'mode','STAGE_READ_ONLY',
 'event_date','${date}',
 'pending_events',(SELECT count(*) FROM candidates),
 'events',(SELECT coalesce(jsonb_agg(jsonb_build_object(
   'id',id,'name',name,'category',category,'draw',draw_size) ORDER BY id),'[]'::jsonb)
   FROM candidates),
 'running_world_jobs',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1
                       WHERE status<>'completed'),
 'user_saves',(SELECT count(*) FROM public.game_saves)+(SELECT count(*) FROM public.game_save_slots),
 'active_careers',(SELECT count(*) FROM public.career_state),
 'stage_checkpoint_present',to_regclass('cb_e2e_checkpoint_20261010.players') IS NOT NULL,
 '2050_certified',false
)::text`;
}
export function executeOneDoublesEventSql(date){
 const {fromDate,toDate}=doublesEventWindow(date);
 return `BEGIN;
SET LOCAL statement_timeout='65000ms';
SET LOCAL lock_timeout='1500ms';
DO $preflight$
DECLARE n integer;
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
 OR to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NULL THEN
  RAISE EXCEPTION 'Refuse doubles: protected isolated stage not present';
 END IF;
 IF EXISTS(SELECT 1 FROM public.career_state)
 OR EXISTS(SELECT 1 FROM public.game_saves)
 OR EXISTS(SELECT 1 FROM public.game_save_slots) THEN
  RAISE EXCEPTION 'Refuse doubles: staging saves or careers exist';
 END IF;
 IF EXISTS(SELECT 1 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1
           WHERE status<>'completed') THEN
  RAISE EXCEPTION 'Refuse doubles: singles world job still active';
 END IF;
 IF NOT pg_try_advisory_xact_lock(94832021) THEN
  RAISE EXCEPTION 'Refuse doubles: world writer busy';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1
   WHERE status='completed' AND to_date >= DATE '${toDate}') THEN
  RAISE EXCEPTION 'Refuse doubles: underlying singles checkpoint unverified';
 END IF;
 SELECT count(*) INTO n FROM public.tournaments t
 WHERE t.doubles=true AND coalesce(t.is_active,true)
 AND t.circuit IN ('ATP','Challenger','ITF')
 AND t.category NOT IN ('United Cup','Laver Cup','ATP Finals')
 AND coalesce(t.end_date,t.start_date)=DATE '${toDate}'
 AND NOT EXISTS(SELECT 1 FROM public.world_doubles_tournament_simulations s
                WHERE s.tournament_id=t.id);
 IF n<>1 THEN
  RAISE EXCEPTION 'Refuse doubles: requires exactly one pending tournament on this date, found %',n;
 END IF;
END $preflight$;
CREATE TEMP TABLE cb_p0_doubles_result ON COMMIT DROP AS
SELECT public.simulate_world_doubles_tournaments(DATE '${fromDate}',DATE '${toDate}') result;
DO $verify$
DECLARE n integer; v_t bigint; v_matches integer; v_points integer; v_winner bigint;
BEGIN
 SELECT id INTO v_t FROM public.tournaments t
 WHERE t.doubles AND coalesce(t.is_active,true)
 AND t.circuit IN ('ATP','Challenger','ITF')
 AND t.category NOT IN ('United Cup','Laver Cup','ATP Finals')
 AND coalesce(t.end_date,t.start_date)=DATE '${toDate}'
 AND EXISTS(SELECT 1 FROM public.world_doubles_tournament_simulations s WHERE s.tournament_id=t.id);
 IF v_t IS NULL THEN
  RAISE EXCEPTION 'Refuse doubles: no persisted simulation champion after engine call';
 END IF;
 SELECT count(*) INTO n FROM public.world_doubles_tournament_simulations WHERE tournament_id=v_t;
 IF n<>1 OR (SELECT coalesce((result->>'tournaments_simulated')::int,0) FROM cb_p0_doubles_result)<>1 THEN
  RAISE EXCEPTION 'Refuse doubles: unexpected number of committed simulations';
 END IF;
 SELECT winner_pair_id INTO v_winner FROM public.world_doubles_tournament_simulations WHERE tournament_id=v_t;
 IF v_winner IS NULL THEN RAISE EXCEPTION 'Refuse doubles: no winning pair'; END IF;
 SELECT count(*) INTO v_matches FROM public.world_doubles_tournament_matches
 WHERE tournament_id=v_t AND is_qualifying IS FALSE
 AND winner_pair_id IS NOT NULL AND coalesce(score,'')<>'';
 IF v_matches<3 THEN RAISE EXCEPTION 'Refuse doubles: missing scored matches'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.world_doubles_tournament_matches
   WHERE tournament_id=v_t AND round_code='F' AND winner_pair_id=v_winner
    AND coalesce(score,'')<>'') THEN
  RAISE EXCEPTION 'Refuse doubles: final score / champion mismatch';
 END IF;
 SELECT count(*) INTO v_points FROM public.world_doubles_ranking_points WHERE tournament_id=v_t AND points>0;
 IF v_points<2 THEN RAISE EXCEPTION 'Refuse doubles: ranking points missing'; END IF;
END $verify$;
SELECT jsonb_build_object(
 'ok',true,'scope','isolated_world_doubles_one_event',
 'event_date','${toDate}',
 'engine_result',(SELECT result FROM cb_p0_doubles_result),
 'tournaments_verified',(SELECT count(*) FROM public.world_doubles_tournament_simulations d
 JOIN public.tournaments t ON t.id=d.tournament_id
 WHERE coalesce(t.end_date,t.start_date)=DATE '${toDate}' AND t.circuit IN ('ATP','Challenger','ITF')),
 'finished_scored_matches',(SELECT count(*) FROM public.world_doubles_tournament_matches m
 JOIN public.tournaments t ON t.id=m.tournament_id
 WHERE coalesce(t.end_date,t.start_date)=DATE '${toDate}' AND t.circuit IN ('ATP','Challenger','ITF')
   AND m.is_qualifying IS FALSE AND m.winner_pair_id IS NOT NULL AND coalesce(m.score,'')<>''),
 'point_awards',(SELECT count(*) FROM public.world_doubles_ranking_points p
 JOIN public.tournaments t ON t.id=p.tournament_id
 WHERE coalesce(t.end_date,t.start_date)=DATE '${toDate}' AND t.circuit IN ('ATP','Challenger','ITF') AND p.points>0),
 'all_circuits_certified',false,'2050_certified',false
)::text;
COMMIT;`;
}
export function options(args){
 const out={execute:false,date:null};
 for(const v of args){
  if(v==='--execute')out.execute=true;
  else if(v.startsWith('--date='))out.date=v.slice(7);
  else throw Error('Unknown stage-only doubles option');
 }
 validDoublesEventDate(out.date);
 return out;
}
export async function runDoublesStage({date,execute=false,dsn,query=queryWithPsql}){
 assertDirectStageUrl(dsn);
 validDoublesEventDate(date);
 if(typeof query!=='function')throw Error('Missing SQL transport');
 return query({dsn,sql:execute?executeOneDoublesEventSql(date):readDoublesEventSql(date)});
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try {
  if(process.argv.includes('--help')){
    console.log('Usage: CB_E2E_DB_URL=<private-stage-TLS-DSN> node qa/world-2050/stage-doubles-one-event-v101.mjs --date=2026-01-31 [--execute]');
  }else{
    const o=options(process.argv.slice(2));
    const result=await runDoublesStage({...o,dsn:process.env.CB_E2E_DB_URL});
    console.log(JSON.stringify(result));
  }
 }catch(error){
  console.error('Isolated doubles operator halted:',error.message);
  process.exitCode=1;
 }
}
