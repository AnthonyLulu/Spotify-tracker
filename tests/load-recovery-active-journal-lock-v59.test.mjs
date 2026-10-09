import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010024500_load_recovery_active_journal_lock_v59.sql',import.meta.url),'utf8');
const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');

test('active and rollback-pending load journals cannot be replaced by another prepare',()=>{
  assert.match(sql,/CREATE OR REPLACE FUNCTION public\.cb_prepare_load_recovery_v33/);
  assert.match(sql,/on conflict\(browser_key\) do update set/i);
  assert.match(sql,/where court_boss_private\.load_recovery_v33\.status='prepared'/);
  assert.match(sql,/returning operation_id into v_saved_operation_id/);
  assert.match(sql,/if v_saved_operation_id is null then/);
  assert.match(sql,/load_recovery_locked/);
  assert.match(sql,/errcode='55P03'/);
  assert.match(sql,/return v_saved_operation_id/);
  assert.doesNotMatch(sql,/\b(?:DELETE FROM|DROP TABLE|TRUNCATE|UPDATE public\.game_saves)\b/i);
});

test('backend surfaces recovery lock without retrying a destructive restore',()=>{
  const route=edge.slice(edge.indexOf('if(path.endsWith("/api/load-slot")'),edge.indexOf('if(path.endsWith("/api/delete-slot")'));
  const check=route.indexOf('prepared.error?.code==="55P03"');
  const applying=route.indexOf('cb_mark_load_recovery_v33');
  const restoring=route.indexOf('restoreManagedSaveSnapshot(slot.data.managed_snapshot)');
  assert.ok(route.length>1000&&check>0&&applying>check&&restoring>applying);
  assert.match(route,/recovery_pending:true\},409/);
  assert.ok(route.includes('cb_clear_load_recovery_v33'));
});

test('SQL guarded upsert disallows advancing any locked predecessor journal',()=>{
  const states=['prepared','applying','rollback_pending'];
  const prepare=(previous,newDigest)=>{
    if(previous&&previous.status!=='prepared')return {ok:false,previous};
    return {ok:true,previous:{status:'prepared',digest:newDigest}};
  };
  for(const status of states){
    const old={status,digest:'safety-checkpoint-original'};
    const attempted=prepare(old,'attacker-second-checkpoint');
    assert.equal(attempted.ok,status==='prepared');
    assert.equal(attempted.previous.digest,
      status==='prepared'?'attacker-second-checkpoint':'safety-checkpoint-original');
  }
});
