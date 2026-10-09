import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const loadStart=edge.indexOf('if(path.endsWith("/api/load-slot")');
const loadEnd=edge.indexOf('if(path.endsWith("/api/delete-slot")',loadStart);
const load=edge.slice(loadStart,loadEnd);
const recoveryStart=edge.indexOf('// Durable crash recovery for interrupted loads.');
const recoveryEnd=edge.indexOf('if((\n    path.endsWith("/api/refresh-live-rankings")',recoveryStart);
const recovery=edge.slice(recoveryStart,recoveryEnd);

test('load records a durable safety snapshot before any destructive restore',()=>{
  assert.ok(loadStart>0&&loadEnd>loadStart);
  const captured=load.indexOf('const safetyDigest=await snapshotRollbackDigest(safetySnapshot)');
  const prepared=load.indexOf('cb_prepare_load_recovery_v33');
  const applying=load.indexOf('p_status:"applying"');
  const restore=load.indexOf('restored=await restoreManagedSaveSnapshot(slot.data.managed_snapshot)');
  assert.ok(captured>=0&&prepared>captured&&applying>prepared&&restore>applying);
  assert.match(load,/p_safety_snapshot:safetySnapshot/);
  assert.match(load,/p_safety_digest:safetyDigest/);
  assert.match(load,/p_legacy_snapshot:currentLegacy\.data\?\?null/);
  assert.match(load,/rollback_durable:true/);
});

test('interrupted load is recovered and digest checked before serving reads',()=>{
  assert.ok(recoveryStart>0&&recoveryEnd>recoveryStart);
  assert.match(recovery,/cb_get_load_recovery_v33/);
  assert.match(recovery,/cb_acquire_write_lock_v31/);
  assert.match(recovery,/await restoreManagedSaveSnapshot\(recovery\.safety_snapshot\)/);
  assert.match(recovery,/Crash recovery snapshot digest mismatch/);
  assert.match(recovery,/Crash recovery legacy digest mismatch/);
  assert.match(recovery,/cb_clear_load_recovery_v33/);
  assert.match(recovery,/recovery_pending:true/);
});

test('restored rows use authorized RPC to bypass fragile client bulk upserts',()=>{
  const restoreStart=edge.indexOf('async function restoreManagedSaveSnapshot(');
  const restoreEnd=edge.indexOf('async function ensureCareerBaselineTemplate()',restoreStart);
  const restore=edge.slice(restoreStart,restoreEnd);
  assert.match(restore,/cb_restore_snapshot_rows_v32/);
  assert.doesNotMatch(restore,/const q=onConflict\?db\.from\(table\)\.upsert/);
});
