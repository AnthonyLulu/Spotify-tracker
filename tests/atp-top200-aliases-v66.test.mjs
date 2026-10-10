import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const aliases=JSON.parse(fs.readFileSync(new URL('../qa/world-2050/atp-top200-verified-aliases-v66.json',import.meta.url),'utf8'));
const frozen=JSON.parse(fs.readFileSync(new URL('../court-boss/data/atp-singles-2025-12-01.json',import.meta.url),'utf8'));
const sql=fs.readFileSync(new URL('../qa/world-2050/atp-top200-reference-gate-2025-v66.sql',import.meta.url),'utf8');
test('both non-standard professional names are already present under verified ATP records',()=>{
 assert.equal(aliases.aliases.length,2);
 assert.equal(new Set(aliases.aliases.map(x=>x.stage_player_id)).size,2);
 for(const alias of aliases.aliases){
   const row=frozen.rows.find(x=>x.rank===alias.rank);
   assert.equal(row?.name,alias.reference_name);
   assert.equal(row?.points,alias.points);
   assert.match(sql,new RegExp(String(alias.stage_player_id)));
   assert.match(sql,new RegExp(alias.stored_name));
 }
});
test('alias acceptance requires exact ATP import, rank, points and country, never a generated homonym',()=>{
 assert.match(sql,/a\.stage_id=p\.id/);
 assert.match(sql,/a\.country=p\.country/);
 assert.match(sql,/a\.points=p\.points/);
 assert.match(sql,/p\.ranking=f\.rank/);
 assert.match(sql,/p\.data_source='ISOLATED-ATP-2025-12-01-CC-BY-NC-SA-4\.0'/);
 assert.match(sql,/generated_homonym_risk=0/);
 assert.match(sql,/p\.per_event_entries>0/);
 assert.doesNotMatch(sql,/^\s*(?:UPDATE\s+|DELETE\s+FROM\s+|INSERT\s+INTO\s+|TRUNCATE\s+|DROP\s+)/im);
});
