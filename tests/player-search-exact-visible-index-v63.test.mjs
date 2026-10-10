import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010040500_player_search_exact_visibility_index_v63.sql',import.meta.url),'utf8');
const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const scrubbed=sql.replace(/--[^\n]*/g,'').trim();

test('browse index exactly matches the production hidden-duplicate predicate',()=>{
 assert.match(scrubbed,/CREATE INDEX IF NOT EXISTS idx_players_search_visible_exact_v63/);
 assert.match(scrubbed,/ON public\.players \(potential DESC,current_ability DESC,id\)/);
 assert.match(scrubbed,/data_source IS NULL OR data_source NOT ILIKE '%hidden duplicate merged into%'/);
 assert.match(edge,/data_source\.not\.ilike\.\*hidden duplicate merged into\*/);
});

test('an index cannot change saved games or the set of visible player profiles',()=>{
 assert.doesNotMatch(scrubbed,/\b(?:INSERT|UPDATE|DELETE|TRUNCATE|DROP|GRANT|REVOKE)\b/i);
 assert.doesNotMatch(scrubbed,/public\.game_saves|public\.game_save_slots/);
 assert.equal((scrubbed.match(/CREATE INDEX/g)||[]).length,1);
});
