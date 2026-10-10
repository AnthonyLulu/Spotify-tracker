#!/usr/bin/env node
// Read-only structural comparison. Input manifests contain object names and hashes,
// never player rows, saved games, private tokens or function source.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export const KINDS=['tables','views','functions','indexes','triggers'];

function indexByName(rows,kind){
 if(!Array.isArray(rows))throw new Error(kind+' must be an array');
 const result=new Map();
 for(const row of rows){
  if(!row||typeof row.name!=='string'||!row.name.trim())throw new Error('Invalid '+kind+' name');
  if(typeof row.hash!=='string'||!/^[a-f0-9]{32}$/i.test(row.hash))throw new Error('Missing definition hash for '+row.name);
  if(result.has(row.name))throw new Error('Duplicate '+kind+' entry '+row.name);
  result.set(row.name,row.hash.toLowerCase());
 }
 return result;
}

export function compareSchema(production,isolated){
 const report={status:'PASS',actualWorldReplayCertified:false,types:{},totals:{missing:0,changed:0,extra:0}};
 for(const kind of KINDS){
  const prod=indexByName(production?.[kind],kind);
  const test=indexByName(isolated?.[kind],kind);
  const missing=[...prod.keys()].filter(n=>!test.has(n)).sort();
  const changed=[...prod.keys()].filter(n=>test.has(n)&&prod.get(n)!==test.get(n)).sort();
  const extra=[...test.keys()].filter(n=>!prod.has(n)).sort();
  report.types[kind]={production:prod.size,isolated:test.size,missing,changed,extra};
  report.totals.missing+=missing.length;
  report.totals.changed+=changed.length;
  report.totals.extra+=extra.length;
 }
 if(report.totals.missing||report.totals.changed||report.totals.extra)report.status='FAIL';
 return report;
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const [productionPath,isolatedPath,reportPath]=process.argv.slice(2);
 if(!productionPath||!isolatedPath){
  console.error('Usage: node scripts/cb-schema-audit.mjs <production-manifest.json> <isolated-manifest.json> [report.json]');
  process.exit(2);
 }
 try{
  const p=JSON.parse(fs.readFileSync(productionPath,'utf8'));
  const s=JSON.parse(fs.readFileSync(isolatedPath,'utf8'));
  const result=compareSchema(p,s);
  if(reportPath)fs.writeFileSync(reportPath,JSON.stringify(result,null,2)+'\n',{mode:0o600});
  const overview=Object.fromEntries(KINDS.map(k=>[k,{
    production:result.types[k].production,
    isolated:result.types[k].isolated,
    missing:result.types[k].missing.length,
    changed:result.types[k].changed.length,
    extra:result.types[k].extra.length
  }]));
  console.log(JSON.stringify({status:result.status,totals:result.totals,overview},null,2));
  process.exitCode=result.status==='PASS'?0:1;
 }catch(err){
  console.error('Schema audit could not run: '+err.message);
  process.exitCode=2;
 }
}
