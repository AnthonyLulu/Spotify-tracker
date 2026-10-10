import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const sql=fs.readFileSync(new URL('../qa/world-2050/stage-world-alternate-optimized-v74.sql',import.meta.url),'utf8');
const old=fs.readFileSync(new URL('../qa/world-2050/stage-world-alternate-original-v74.sql',import.meta.url),'utf8');

// Pure deterministic reference for acceptance ordering, independent of SQL
// runtime. The stage E2E test must still compare actual saved DB rows.
function original(candidates,slots,target,existing){
 const eligible=candidates.filter(p=>p.managed||(p.ai===true&&p.calendar===false))
   .sort((a,b)=>a.rank-b.rank||b.ability-a.ability||a.id-b.id);
 return eligible.map((p,i)=>({...p,order:i+1-slots}))
   .filter(p=>p.order>0&&!existing.has(p.id)).slice(0,target).map(p=>[p.id,p.order]);
}
function shortCircuit(candidates,slots,target,existing){
 const ordered=[...candidates].sort((a,b)=>a.rank-b.rank||b.ability-a.ability||a.id-b.id);
 let eligibleOrder=0;const out=[];
 for(const p of ordered){
  if(!p.managed&&(p.ai!==true||p.calendar!==false))continue;
  eligibleOrder++;
  if(eligibleOrder<=slots||existing.has(p.id))continue;
  out.push([p.id,eligibleOrder-slots]);
  if(out.length===target)break;
 }
 return out;
}
test('optimized SQL processes in identical frozen rank, ability and player ID order',()=>{
 assert.match(sql,/order by min\(effective_rank\),max\(current_ability\) desc,player_id/);
 assert.match(sql,/public\.tournament_candidate_player_ids\(t\.id,'direct',2000\)/);
 assert.match(sql,/v_eligible_order:=v_eligible_order\+1/);
 assert.match(sql,/v_eligible_order-st\.direct_slots/);
 assert.match(sql,/exit when v_inserted>=v_target/);
 assert.match(sql,/ai_player_commits_to_tournament\(rec\.player_id,t\.id\)/);
 assert.match(sql,/player_tournament_calendar_conflict\(rec\.player_id,t\.id,'direct'\)/);
 assert.match(sql,/on conflict\(tournament_id,player_id\) do nothing/);
});
test('baseline is archived for exact stage rollback',()=>{
 assert.match(old,/CREATE OR REPLACE FUNCTION public\.materialize_next_world_tournament_alternates/);
 assert.match(old,/with candidate_source as/);
 assert.match(old,/limit greatest\(1,least\(coalesce\(p_limit,24\),128\)\)/);
});
test('progressive scan gives the exact same alternate list for disqualified candidates',()=>{
 const pool=Array.from({length:500},(_,i)=>({
  id:i+1,rank:i+1,ability:((i*11)%40)+40,managed:false,
  ai:i%4!==0,calendar:i%9===0
 }));
 for(const slots of [0,16,32,64])for(const target of [1,8,24,64,128]){
  assert.deepEqual(shortCircuit(pool,slots,target,new Set()),original(pool,slots,target,new Set()));
 }
});
test('already present accepted/withdrawn IDs preserve alternate-order holes',()=>{
 const pool=Array.from({length:120},(_,i)=>({
  id:i+1,rank:i+1,ability:60,managed:false,ai:i%3!==1,calendar:i%7===0
 }));
 const existing=new Set([11,13,26,45,64,92]);
 assert.deepEqual(shortCircuit(pool,10,25,existing),original(pool,10,25,existing));
});
test('managed explicitly entered player and exact tie-break ordering stay unchanged',()=>{
 const pool=[
  {id:7,rank:8,ability:80,managed:false,ai:true,calendar:false},
  {id:8,rank:8,ability:90,managed:false,ai:false,calendar:false},
  {id:9,rank:8,ability:90,managed:true,ai:false,calendar:true},
  {id:10,rank:10,ability:90,managed:false,ai:true,calendar:false},
  {id:11,rank:11,ability:80,managed:false,ai:true,calendar:true}
 ];
 assert.deepEqual(shortCircuit(pool,1,3,new Set()),original(pool,1,3,new Set()));
});
test('null and unknown eligibility are not treated as accepted',()=>{
 const pool=[
  {id:1,rank:1,ability:80,managed:false,ai:null,calendar:false},
  {id:2,rank:2,ability:80,managed:false,ai:true,calendar:null},
  {id:3,rank:3,ability:80,managed:false,ai:true,calendar:false}
 ];
 assert.deepEqual(shortCircuit(pool,0,3,new Set()),[[3,1]]);
 assert.deepEqual(shortCircuit(pool,0,3,new Set()),original(pool,0,3,new Set()));
});
