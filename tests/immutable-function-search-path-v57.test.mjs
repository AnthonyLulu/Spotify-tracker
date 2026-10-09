import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync(new URL('../supabase/migrations/20261010015500_immutable_helpers_search_path_v57.sql',import.meta.url),'utf8');
test('set safe immutable-function search path without rewriting gameplay',()=>{
  assert.match(migration,/ALTER FUNCTION public\.atp_historical_rank_category\(text,text,text\)/);
  assert.match(migration,/ALTER FUNCTION public\.atp500_bonus_swing_v18\(date,date\)/);
  assert.equal((migration.match(/SET search_path = pg_catalog/g)||[]).length,2);
  assert.doesNotMatch(migration,/\b(?:DROP|DELETE|UPDATE|INSERT|TRUNCATE|CREATE OR REPLACE)\b/i);
});
