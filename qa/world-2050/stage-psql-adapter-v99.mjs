// P0 isolated Court Boss 2026 world-singles PostgreSQL adapter.
// Only the known free E2E test project is permitted. NEVER use production here.
// This file provides real SQL calls; it does not create schedules or auto-run.
import {spawnSync} from 'node:child_process';

const STAGE_HOST='db.sozrygjxjotozrsenred.supabase.co';
const JOB=/^WORLD-SINGLES:(2026-\d{2}-\d{2}):(2026-\d{2}-\d{2})$/;

export function assertDirectStageUrl(value){
  if(typeof value!=='string'||!value.trim())throw Error('Missing CB_E2E_DB_URL');
  let url;
  try{url=new URL(value);}catch{throw Error('Invalid staging database URL');}
  if(!['postgres:','postgresql:'].includes(url.protocol)
    ||url.hostname.toLowerCase()!==STAGE_HOST
    ||!url.username||!url.password){
    throw Error('Refusing non-isolated or unauthenticated database URL');
  }
  const ssl=url.searchParams.get('sslmode');
  if(ssl!==null&&!['require','verify-full','verify-ca'].includes(ssl)){
    throw Error('Staging PostgreSQL connection must use TLS');
  }
  return value;
}

function verifiedKey(key){
  const m=typeof key==='string'?key.match(JOB):null;
  if(!m)throw Error('Invalid 2026 isolated singles world job key');
  return key;
}
function verifiedDay(day){
  if(typeof day!=='string'||!/^2026-\d{2}-\d{2}$/.test(day)
    ||Number.isNaN(Date.parse(day+'T00:00:00Z'))
    ||new Date(day+'T00:00:00Z').toISOString().slice(0,10)!==day){
    throw Error('Invalid 2026 calendar date');
  }
  return day;
}

// No connection string or password is passed in command-line args or logs.
// Each query is a separate transaction, as required by the v85 resume protocol.
export function queryWithPsql({dsn,sql,timeoutMs=90000}){
  assertDirectStageUrl(dsn);
  const result=spawnSync('psql',
    ['-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-c',sql],
    {encoding:'utf8',timeout:timeoutMs,maxBuffer:1024*1024,
     env:{...process.env,PGDATABASE:dsn,PGCONNECT_TIMEOUT:'8',PGSSLMODE:'require',
          PGOPTIONS:'-c statement_timeout=75000'}});
  if(result.error||result.status!==0){
    throw Error('Staging query failed or timed out; inspect persisted week state before any retry');
  }
  const out=(result.stdout||'').trim();
  if(!out||out.split('\n').length!==1){
    throw Error('Ambiguous staging query response; no blind replay allowed');
  }
  try{return JSON.parse(out);}
  catch{throw Error('Staging query returned invalid JSON');}
}

export function createStagePsqlAdapter({dsn,query=queryWithPsql}={}){
  assertDirectStageUrl(dsn);
  if(typeof query!=='function')throw Error('Missing PostgreSQL query transport');
  const sql=(statement)=>query({dsn,sql:statement});
  return {
    async assertStageIsolated(){
      const r=sql(`SELECT pg_catalog.jsonb_build_object(
        'ok', to_regclass('cb_e2e_checkpoint_20261010.players') IS NOT NULL
          AND to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NOT NULL
          AND NOT EXISTS(SELECT 1 FROM public.game_saves)
          AND NOT EXISTS(SELECT 1 FROM public.game_save_slots)
          AND NOT EXISTS(SELECT 1 FROM public.career_state),
        'environment','isolated_staging',
        'user_saves',(SELECT count(*) FROM public.game_saves)+(SELECT count(*) FROM public.game_save_slots),
        'active_careers',(SELECT count(*) FROM public.career_state)
      )::text`);
      if(r?.ok!==true)throw Error('Isolated-stage database preflight failed');
      return r;
    },
    async getWeekStatus({key}){
      verifiedKey(key);
      return sql(`SELECT coalesce(
        (SELECT pg_catalog.to_jsonb(j) FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
          WHERE j.job_key='${key}'), 'null'::jsonb)::text`);
    },
    async beginWeek({fromDate,toDate,key}){
      verifiedDay(fromDate);verifiedDay(toDate);verifiedKey(key);
      if(key!==`WORLD-SINGLES:${fromDate}:${toDate}`)throw Error('World week key/date mismatch');
      return sql(`SELECT cb_e2e_reconstruction_20261010.begin_world_week_v2(
        DATE '${fromDate}',DATE '${toDate}')::text`);
    },
    async stepWeek({key}){
      verifiedKey(key);
      return sql(`SELECT cb_e2e_reconstruction_20261010.step_world_week_v2('${key}')::text`);
    },
    async readWeekReceipt({key}){
      verifiedKey(key);
      return sql(`SELECT cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v80('${key}')::text`);
    }
  };
}
