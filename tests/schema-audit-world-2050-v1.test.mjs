import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {compareSchema,KINDS} from '../scripts/cb-schema-audit.mjs';

const base=()=>Object.fromEntries(KINDS.map(k=>[k,[]]));
const obj=(name,seed)=>({name,hash:seed.repeat(32)});

test('same complete schema names and definition hashes pass, but NOT a 2050 replay',()=>{
 const a=base();a.tables=[obj('public.players','a')];a.functions=[obj('public.advance_career_day_v26(...)','b')];
 const result=compareSchema(a,structuredClone(a));
 assert.equal(result.status,'PASS');
 assert.equal(result.actualWorldReplayCertified,false);
 assert.deepEqual(result.totals,{missing:0,changed:0,extra:0});
});

test('missing functions, changed definitions and extra stage objects all block certification',()=>{
 const p=base(),s=base();
 p.tables=[obj('public.players','a')];
 p.functions=[obj('public.advance_career_day_v26(...)','b'),obj('public.simulate_world_week(...)','c')];
 s.tables=[obj('public.players','d'),obj('public.unexpected','f')];
 s.functions=[obj('public.simulate_world_week(...)','c')];
 const r=compareSchema(p,s);
 assert.equal(r.status,'FAIL');
 assert.equal(r.totals.missing,1);
 assert.equal(r.totals.changed,1);
 assert.equal(r.totals.extra,1);
 assert.deepEqual(r.types.functions.missing,['public.advance_career_day_v26(...)']);
});

test('malformed or duplicate data fails closed',()=>{
 const p=base(),s=base();
 p.tables=[{name:'public.players',hash:'invalid'}];
 assert.throws(()=>compareSchema(p,s),/Missing definition hash/);
 p.tables=[obj('public.players','a'),obj('public.players','b')];
 assert.throws(()=>compareSchema(p,s),/Duplicate/);
});

test('CLI produces a private report and exits non-zero for an incomplete database',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'court-boss-audit-'));
 try{
  const p=base(),s=base();p.tables=[obj('public.players','a')];
  fs.writeFileSync(path.join(dir,'production.json'),JSON.stringify(p));
  fs.writeFileSync(path.join(dir,'isolated.json'),JSON.stringify(s));
  const cli=fileURLToPath(new URL('../scripts/cb-schema-audit.mjs',import.meta.url));
  const report=path.join(dir,'report.json');
  const x=spawnSync(process.execPath,[cli,path.join(dir,'production.json'),path.join(dir,'isolated.json'),report],{encoding:'utf8'});
  assert.equal(x.status,1);
  assert.equal(JSON.parse(fs.readFileSync(report,'utf8')).status,'FAIL');
  assert.equal(fs.statSync(report).mode&0o077,0);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});

test('export is structurally read-only and excludes private user rows from code',()=>{
 const sql=fs.readFileSync(new URL('../qa/world-2050/schema-inventory.sql',import.meta.url),'utf8');
 const shell=fs.readFileSync(new URL('../scripts/cb-export-schema-baseline.sh',import.meta.url),'utf8');
 assert.match(sql,/pg_get_functiondef/);
 assert.match(sql,/pg_get_indexdef/);
 assert.match(sql,/pg_get_triggerdef/);
 assert.match(shell,/--schema-only/);
 assert.match(shell,/umask 077/);
 assert.doesNotMatch(shell,/pg_dump.*--data-only/);
 assert.doesNotMatch(sql,/\b(?:INSERT|UPDATE|DELETE|COPY|TRUNCATE)\s+(?:INTO|FROM|TABLE)/i);
});
