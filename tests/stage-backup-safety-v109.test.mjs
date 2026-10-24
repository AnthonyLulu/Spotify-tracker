import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const p=new URL('../scripts/cb-stage-independent-backup-verify.sh',import.meta.url);
const sh=readFileSync(p,'utf8');
test('backup fails closed unless source is isolated stage and target is local scratch',()=>{
 assert.match(sh,/sozrygjxjotozrsenred/);
 assert.match(sh,/CB_E2E_RESTORE_TEST_DB_URL/);
 assert.match(sh,/cb_e2e_restore_/);
 assert.match(sh,/Restore must target a local test database/);
 assert.match(sh,/Refuse to overwrite non-empty scratch database/);
 assert.match(sh,/game_saves/);
 assert.match(sh,/game_save_slots/);
 assert.match(sh,/career_state/);
});
test('backup requires encrypted artifact and verifies restoration, without stage mutations',()=>{
 for(const token of ['--role-only','--schema "$schemas"','--data-only','--use-copy','--single-transaction','AGE_IDENTITY_FILE','age -r','age -d','sha256sum','RESTORED_COUNTS.json','checkpoint_players','frozen_synthetic_players','frozen_synthetic_attributes','initial_rank_assignments','historical_atp_reference','historical_atp_bridge']) {
  assert.ok(sh.includes(token), 'Missing '+token);
 }
 assert.doesNotMatch(sh,/psql\s+"\$CB_E2E_DB_URL"[^\n]*\s-f\s+"\$tmp\//);
 assert.doesNotMatch(sh,/supabase\s+db\s+(?:reset|push)/);
 assert.doesNotMatch(sh,/\b(?:DROP DATABASE|DELETE FROM public\.|TRUNCATE public\.)\b/i);
});

import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
test('backup shell script parses under Bash before any owner credentials are supplied',()=>{
 const r=spawnSync('bash',['-n',fileURLToPath(p)],{encoding:'utf8'});
 assert.equal(r.status,0,r.stderr);
});
