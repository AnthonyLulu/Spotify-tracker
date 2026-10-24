import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const ref=JSON.parse(readFileSync(new URL('../court-boss/data/atp-singles-2025-12-01.json',import.meta.url),'utf8'));
const sql=readFileSync(new URL('../qa/world-2050/stage-atp-reference-seed-v94.sql',import.meta.url),'utf8');
const marker='$frozen_top200$';
const embedded=JSON.parse(sql.split(marker)[1]);
test('v94 frozen historical reference matches the committed 2025 snapshot',()=>{
 assert.equal(ref.snapshot,'2025-12-01');
 assert.equal(ref.rows.length,200);
 assert.deepEqual(embedded,ref.rows.map(({rank,name,points})=>({rank,name,points})));
 assert.equal(new Set(embedded.map(x=>x.rank)).size,200);
});
test('v94 cannot certify missing ATP profiles or modify live rankings',()=>{
 assert.ok(sql.includes('REPO_ATP_2025_PROVISIONAL_V94_NOT_CERTIFIED'));
 assert.ok(sql.includes('n_found<>191'));
 assert.ok(sql.includes('cb_e2e_checkpoint_20261010.players'));
 assert.ok(sql.includes('FROM public.career_state'));
 assert.ok(sql.includes("'certified',false"));
 assert.ok(!sql.includes('UPDATE public.players'));
});
