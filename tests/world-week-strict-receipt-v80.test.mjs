import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../qa/world-2050/stage-world-week-strict-receipt-v80.sql',import.meta.url),'utf8');

test('receipt requires persisted real matches and identical point awards',()=>{
 assert.match(source,/world_tournament_matches/);
 assert.match(source,/world_ranking_points/);
 assert.match(source,/world_tournament_simulations/);
 assert.match(source,/actual_main IS DISTINCT FROM e\.actual_scored/);
 assert.match(source,/ranking_rows_added IS DISTINCT FROM e\.actual_points/);
 assert.match(source,/actual_point_rows=r\.expected_point_rows/);
 assert.match(source,/r\.committed_matches=r\.main_matches/);
});
test('outer green integrity guard never hides a red duplicate-rank audit',()=>{
 assert.match(source,/g\.audit->'base_integrity'->>'ok'/);
 assert.match(source,/duplicate_active_world_ranks/);
 assert.match(source,/coalesce\(\(g\.audit->'base_integrity'->>'duplicate_active_world_ranks'\)::int,-1\)=0/);
 assert.match(source,/nested_guard_ok/);
});
test('singles-only evidence cannot masquerade as a complete 2050 cross-circuit receipt',()=>{
 assert.match(source,/'scope','world_singles_only'/);
 assert.match(source,/'certifies_full_unified_week',false/);
 assert.match(source,/NOT EXISTS\(SELECT 1 FROM public\.career_state\)/);
});
test('receipt is private read-only invoker and has no game mutations',()=>{
 assert.match(source,/LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''/);
 assert.match(source,/REVOKE ALL ON FUNCTION .*\(text\)/);
 assert.doesNotMatch(source,/\b(?:INSERT INTO|UPDATE public\.|DELETE FROM|TRUNCATE|DROP TABLE|CREATE TABLE|GRANT EXECUTE)\b/i);
});
