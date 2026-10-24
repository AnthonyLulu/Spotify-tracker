import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../qa/world-2050/install-private-doubles-eligibility-prefilter-v103.sql',import.meta.url),'utf8');
test('stage candidate prefilter is derived only from pinned original sources',()=>{
 assert.match(sql,/fe2cd96f4e47940c0bf7a08fc06ab21f/);
 assert.match(sql,/ffbbc55adec78b6912beffc762e333a2/);
 assert.match(sql,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(sql,/selector_old constant text := 'from public\.world_doubles_partnerships w'/);
 assert.match(sql,/selector_new constant text/);
 assert.match(sql,/limit greatest\(64,least\(p_candidate_cap,400\)\)/);
 assert.match(sql,/DEFAULT 256/);
});
test('private pilot cannot replace original selection, alter credentials or claim green 2050',()=>{
 assert.match(sql,/CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010\.select_itf_doubles_prefilter_v103/);
 assert.match(sql,/CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010\.simulate_world_doubles_one_event_prefilter_v103/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/prosecdef=false/);
 assert.match(sql,/'original_selector_modified',false/);
 assert.match(sql,/'original_match_engine_modified',false/);
 assert.match(sql,/'full_draw_accuracy_certified',false/);
 assert.match(sql,/'2050_certified',false/);
});
