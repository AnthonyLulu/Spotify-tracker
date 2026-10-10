import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../qa/world-2050/stage-world-rank-seed-v50.sql',import.meta.url),'utf8');

test('stage 2025 seed fails closed before rank allocation if user data or archive could be touched',()=>{
 assert.match(sql,/ISOLATED E2E ONLY/);
 assert.match(sql,/NOT add this file to supabase\/migrations/);
 assert.match(sql,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(sql,/SELECT count\(\*\) FROM public\.game_saves/);
 assert.match(sql,/SELECT count\(\*\) FROM public\.career_state/);
 assert.match(sql,/Unsafe stage rank seed preflight/);
 assert.doesNotMatch(sql,/\bTRUNCATE\s+TABLE\b|\bDROP\s+TABLE\b/i);
});

test('all ranks are unique, stable, and allocated behind archived ranks',()=>{
 assert.match(sql,/5375 \+ rank_offset AS assigned_rank/);
 assert.match(sql,/row_number\(\) over/);
 assert.match(sql,/assigned_rank\)<>5376/);
 assert.match(sql,/assigned_rank\)<>31831/);
 assert.match(sql,/UNIQUE\(assigned_rank\)/);
 assert.match(sql,/PRIMARY KEY\(player_id\)/);
 assert.match(sql,/source_ranking ASC NULLS LAST/);
});

test('supplemental imported ATP ranking is a preserved reference, not a repeated rank mirror',()=>{
 assert.match(sql,/atp_reference_rank/);
 assert.match(sql,/ranking_current=CASE WHEN b\.data_source='ISOLATED-ATP-2025-12-01-CC-BY-NC-SA-4\.0'/);
 assert.match(sql,/THEN false ELSE p\.ranking_current/);
 assert.doesNotMatch(sql,/SET\s+ranking\s*=/i);
});

test('the batch writer is deliberately manual, bounded, and not exposed to browser roles',()=>{
 assert.match(sql,/p_limit<1 OR p_limit>1500/);
 assert.match(sql,/ORDER BY plan\.assigned_rank LIMIT p_limit/);
 assert.match(sql,/WHERE p\.id=b\.player_id AND p\.game_world_rank IS NULL/);
 assert.match(sql,/REVOKE ALL ON FUNCTION.*FROM PUBLIC,anon,authenticated/);
 assert.doesNotMatch(sql,/^SELECT cb_e2e_reconstruction_20261010\.apply_world_rank_seed_batch_v1\(/m);
});
