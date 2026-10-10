import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
const from=app.indexOf('async function loadStaffWorld(){');
const to=app.indexOf('const rankPageSize=',from);
const sectionStart=app.indexOf('function staffWorldSection(){');
const sectionEnd=app.indexOf('\n\nfunction ',sectionStart+5);
assert.ok(from>=0&&to>from&&sectionStart>=0&&sectionEnd>sectionStart);

const make=()=>{
  const warnings=[];
  const ctx={
    URLSearchParams,staffWorldOffset:0,staffWorldLoading:false,staffWorldData:null,
    staffWorldFilters:{q:'',role:'',country:'',former:'Tous',status:'Tous'},
    console:{warn:(...args)=>warnings.push(args)},esc:s=>String(s),fmt:n=>String(n),flags:{}
  };
  vm.runInNewContext(app.slice(from,to),ctx);
  vm.runInNewContext(app.slice(sectionStart,sectionEnd),ctx);
  return {ctx,warnings};
};
test('staff market failure is visible and cannot prevent existing staff workspace from opening',async()=>{
  const {ctx,warnings}=make();
  ctx.get=async()=>{throw new Error('upstream HTTP 500')};
  await ctx.loadStaffWorld();
  assert.equal(ctx.staffWorldLoading,false);
  assert.match(ctx.staffWorldData.error,/HTTP 500/);
  assert.equal(ctx.staffWorldData.total,0);
  assert.ok(warnings.length);
  const ui=ctx.staffWorldSection();
  assert.match(ui,/Catalogue staff momentanément indisponible/);
  assert.match(ui,/Ton équipe et tes contrats restent consultables/);
  assert.match(ui,/Réessayer le catalogue/);
  assert.doesNotMatch(ui,/0 profils/);
});
test('staff market successful retries recover proper catalog data',async()=>{
  const {ctx}=make();
  ctx.get=async()=>{throw new Error('timeout')};
  await ctx.loadStaffWorld();
  const catalog={rows:[{id:7,name:'Coach Test'}],roles:[],countries:[],total:1};
  ctx.get=async()=>catalog;
  await ctx.loadStaffWorld();
  assert.equal(ctx.staffWorldData.total,1);
  assert.equal(ctx.staffWorldData.rows[0].name,'Coach Test');
  assert.equal(ctx.staffWorldLoading,false);
});
