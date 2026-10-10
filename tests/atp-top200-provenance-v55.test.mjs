import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../qa/world-2050/atp-top200-reference-gate-2025-v55.sql',import.meta.url),'utf8');
const snap=JSON.parse(fs.readFileSync(new URL('../court-boss/data/atp-singles-2025-12-01.json',import.meta.url),'utf8'));
const match=sql.match(/\$frozen_top200\$(\[[\s\S]*?\])\$frozen_top200\$/);
test('the read-only QA gate uses exactly the frozen 2025 Top200 reference',()=>{
 assert.ok(match);
 const rows=JSON.parse(match[1]);
 assert.equal(rows.length,200);
 assert.equal(snap.snapshot,'2025-12-01');
 for(let i=0;i<rows.length;i++){
  assert.equal(rows[i].rank,snap.rows[i].rank);
  assert.equal(rows[i].name,snap.rows[i].name);
  assert.equal(rows[i].points,snap.rows[i].points);
 }
 assert.equal(rows[0].name,'Carlos Alcaraz');
 assert.equal(rows[1].name,'Jannik Sinner');
 assert.equal(rows[1].rank,2);
});
test('name-only and generated matches never silently certify a world',()=>{
 assert.match(sql,/generated_homonym_risk/);
 assert.match(sql,/name_only_nonimported/);
 assert.match(sql,/in_game_rank_mismatch=0/);
 assert.match(sql,/p\.per_event_entries>0/);
 assert.match(sql,/p\.synthetic_reconciliation_rows=0/);
 assert.match(sql,/c\.direct_atp_profile_match=200/);
 assert.doesNotMatch(sql,/['"]certified['"],\s*false/);
});
test('audit never rewrites identities, world ranks, history or user saves',()=>{
 assert.match(sql,/Stage-only READ-ONLY/);
 assert.doesNotMatch(sql,/^\s*(?:UPDATE|INSERT\s+INTO|DELETE\s+FROM|TRUNCATE|DROP|ALTER|CREATE\s+TABLE)\b/im);
});
