import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../qa/world-2050/install-single-event-doubles-v102.sql',import.meta.url),'utf8');
test('a private isolated-only one-event clone preserves the original source fingerprint',()=>{
 assert.match(sql,/md5\(source_function\)<>'c24ae419a0cee59fffe2fc57a8c1c7ae'/);
 assert.match(sql,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(sql,/FROM public\.game_saves/);
 assert.match(sql,/FROM public\.game_save_slots/);
 assert.match(sql,/FROM public\.career_state/);
 assert.match(sql,/where id=p_tournament_id and doubles=true/);
 assert.match(sql,/REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010\.simulate_world_doubles_one_event_v102/);
 assert.match(sql,/replace\(definition,'SECURITY DEFINER','SECURITY INVOKER'\)/);
});
test('source and production doubles function are never replaced or granted to public',()=>{
 assert.match(sql,/CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010\.simulate_world_doubles_one_event_v102/);
 assert.doesNotMatch(sql,/EXECUTE 'GRANT/i);
 assert.match(sql,/'production_function_untouched',true/);
 assert.match(sql,/'2050_certified',false/);
});
