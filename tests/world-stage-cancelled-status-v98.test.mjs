import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const src=readFileSync(new URL('../qa/world-2050/stage-deactivate-cancelled-itf-v98.sql',import.meta.url),'utf8');
test('cancelled ITF status reset is restricted to the isolated 2026-2050 fixture set',()=>{
 assert.match(src,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(src,/cb_e2e_reconstruction_20261010\.world_week_jobs_v1/);
 assert.match(src,/t\.circuit='ITF'/);
 assert.match(src,/date '2026-01-01' AND date '2050-12-31'/);
 assert.match(src,/cancelled\|canceled\|postponed/);
 assert.match(src,/IF n<>375/);
 assert.match(src,/game_saves/);
 assert.match(src,/game_save_slots/);
});
test('fixture state backup makes narrow mutation reversible and leaves simulated effects intact',()=>{
 assert.match(src,/itf_cancelled_original_status_v98/);
 assert.match(src,/original_is_active boolean NOT NULL/);
 assert.match(src,/UPDATE public\.tournaments t SET is_active=false/);
 assert.match(src,/WHERE t\.is_active=true AND t\.id IN/);
 assert.match(src,/ROLLBACK|COMMIT/);
 assert.doesNotMatch(src,/\bDELETE\s+FROM\s+public\./i);
 assert.doesNotMatch(src,/\bTRUNCATE\s+(?:TABLE\s+)?public\./i);
 assert.doesNotMatch(src,/\bUPDATE\s+public\.(?:world_ranking_points|players|world_tournament_matches|career_state)/i);
});
