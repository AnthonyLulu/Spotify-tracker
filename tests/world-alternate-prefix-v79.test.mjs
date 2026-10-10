import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../qa/world-2050/world-alternate-candidate-prefix-v79.sql',import.meta.url),'utf8');

test('candidate comparisons use identical rank, ability, id tie breaker',()=>{
 assert.match(sql,/ROW_NUMBER\(\)|row_number\(\)/);
 assert.match(sql,/ORDER BY c\.effective_rank,p\.current_ability DESC,c\.player_id/);
 assert.match(sql,/tournament_candidate_player_ids\(ev\.tournament_id,'direct',500\)/);
 assert.match(sql,/tournament_candidate_player_ids\(ev\.tournament_id,'direct',2000\)/);
 assert.match(sql,/player_id IS DISTINCT FROM f\.player_id/);
 assert.match(sql,/effective_rank IS DISTINCT FROM f\.effective_rank/);
});
test('prefix is a raw-candidate gate, never a substitute for AI alternate results',()=>{
 assert.match(sql,/raw_top128_prefix_verified/);
 assert.match(sql,/false AS final_alternate_list_certified/);
 assert.match(sql,/count_500>=128 AND s\.count_2000>=128/);
 assert.match(sql,/top128_differences=0/);
});
test('the stage gate is strictly read-only',()=>{
 assert.match(sql,/READ ONLY/);
 assert.doesNotMatch(sql,/\b(?:INSERT|UPDATE|DELETE|MERGE|DROP|CREATE|ALTER|TRUNCATE|CALL|DO)\s+(?:INTO|FROM|TABLE|OR|FUNCTION|PROCEDURE|SCHEMA|ROLE|DATABASE|\$)/i);
});
