import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const ref=JSON.parse(readFileSync(new URL('../qa/world-2050/atp-2025-ita-crosswalk-v97.json',import.meta.url)));
const deep=JSON.parse(readFileSync(new URL('../court-boss/data/atp-singles-deep-2025-12-01.json',import.meta.url)));
const frozen=JSON.parse(readFileSync(new URL('../court-boss/data/atp-singles-2025-12-01.json',import.meta.url)));
const sql=readFileSync(new URL('../qa/world-2050/atp-2025-ita-crosswalk-stage-audit-v97.sql',import.meta.url),'utf8');
test('8 curated ATP/ITA candidates match frozen rankings and source identifiers',()=>{
 assert.equal(ref.snapshot,'2025-12-01');
 assert.equal(ref.scope,'isolated_stage_only');
 assert.equal(ref.curated.length,8);
 assert.equal(new Set(ref.curated.map(x=>x.stage_id)).size,8);
 assert.equal(new Set(ref.curated.map(x=>x.atp_player_id)).size,8);
 for(const c of ref.curated){
  const historical=frozen.rows.find(x=>x.rank===c.rank);
  const deepRow=deep.rows.find(x=>x.rank===c.rank);
  assert.ok(historical&&deepRow);
  assert.equal(c.name,historical.name);
  assert.equal(c.points,historical.points);
  assert.equal(c.atp_player_id,deepRow.player_id);
  assert.equal(c.country,deepRow.country);
  assert.equal(c.birth_date,deepRow.birth_date);
  assert.equal(c.certified,false);
  assert.ok(c.official_evidence_url.startsWith('https://www.atptour.com/'));
 }
});
test('synthetic Gabriel Diallo is blocked, not fused with ATP Canadian',()=>{
 const b=ref.blocked[0];
 assert.equal(ref.blocked.length,1);
 assert.equal(b.name,'Gabriel Diallo');
 assert.equal(b.rank,41);
 assert.equal(b.atp_player_id,209113);
 assert.equal(b.real_country,'CAN');
 assert.equal(b.synthetic_country,'BEL');
 assert.notEqual(b.real_birth_date,b.synthetic_birth_date.replaceAll('-',''));
});
test('cross-circuit stage audit never updates ATP, NCAA or world-rank tables',()=>{
 assert.match(sql,/BEGIN READ ONLY;/);
 assert.match(sql,/game_generated=false AND p.atp_source_id IS NULL/);
 assert.match(sql,/staging_source_cross_circuit_canonical_link_certified',false/);
 assert.match(sql,/'2050_certified',false/);
 assert.doesNotMatch(sql,/\b(?:insert|update|delete|truncate|alter)\s+(?:into\s+)?(?:public|cb_e2e_reconstruction_20261010)\./i);
});
