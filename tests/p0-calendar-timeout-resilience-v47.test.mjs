import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const start=edge.indexOf('if(path.endsWith("/api/tournaments")&&req.method==="GET")');
const end=edge.indexOf('if(path.endsWith("/api/tournament-entry-status")',start);
assert.ok(start>0&&end>start,'tournament list route missing');
const body=edge.slice(start,end)
 .replaceAll('(x:any)=>','(x)=>')
 .replaceAll('(t:any)=>','(t)=>')
 .replaceAll('rows:any[]','rows')
 .replaceAll('tbcRows:any[]','tbcRows');

async function invoke({mainTimeout=false,acceptTimeout=false,managedId=51}={}){
  let countMode=null;
  const qb=(table)=>{
    let query={
      select(cols,opts){if(table==='tournaments')countMode=opts?.count;return query},
      eq(){return query},gte(){return query},lt(){return query},
      ilike(){return query},in(){return query},order(){return query},range(){return query},
      maybeSingle(){return Promise.resolve(
        table==='career_state'?{data:{managed_player_id:51},error:null}
        :table==='academy_roster'?{data:null,error:null}
        :{data:null,error:null}
      )},
      then(resolve,reject){
        let result;
        switch(table){
          case 'tournaments':
            result=mainTimeout?{data:null,count:null,error:{message:'canceling statement due to statement timeout'}}
              :{data:[{id:121,name:'Brisbane International',start_date:'2026-01-04'}],count:123,error:null};
            break;
          case 'world_tournament_acceptance_entries':
            result=acceptTimeout?{data:null,error:{message:'statement timeout'}}:
              {data:[{tournament_id:121,status:'accepted',acceptance_order:1}],error:null};
            break;
          case 'world_qualifying_acceptance_entries':
            result={data:[],error:null};break;
          case 'tournament_tbc_events':
            result={data:[],error:null};break;
          default: throw Error('unexpected DB table '+table);
        }
        return Promise.resolve(result).then(resolve,reject);
      }
    };
    return query;
  };
  const ctx={
    path:'/api/tournaments',
    req:{method:'GET'},
    u:{searchParams:new URLSearchParams('offset=0&limit=32&player_id='+managedId+'&from=2025-12-01')},
    db:{from:qb},
    n:(x,fallback,min,max)=>Math.max(min,Math.min(max,Number(x)||fallback)),
    h:(json,status=200)=>({json,status})
  };
  const response=await vm.runInNewContext('(async()=>{'+body+'})()',ctx);
  return {response,countMode};
}

test('calendar uses inexpensive planned counts and loads real accepted status',async()=>{
  const {response,countMode}=await invoke();
  assert.equal(countMode,'planned');
  assert.equal(response.status,200);
  assert.equal(response.json.rows.length,1);
  assert.equal(response.json.rows[0].managed_acceptance_main.status,'accepted');
  assert.equal(response.json.acceptance_metadata_partial,false);
  assert.equal(response.json.calendar_count_is_estimate,true);
});

test('calendar remains browseable if a secondary acceptance query times out',async()=>{
  const {response}=await invoke({acceptTimeout:true});
  assert.equal(response.status,200);
  assert.equal(response.json.rows.length,1);
  assert.equal(response.json.acceptance_metadata_partial,true);
  assert.equal(response.json.rows[0].managed_acceptance_main,undefined);
  assert.equal(response.json.rows[0].name,'Brisbane International');
});

test('primary tournament-list timeout yields explicit retryable 503',async()=>{
  const {response}=await invoke({mainTimeout:true});
  assert.equal(response.status,503);
  assert.equal(response.json.retryable,true);
});

test('roster authorization stays enforced during resilience fallback',async()=>{
  const {response}=await invoke({managedId:999});
  assert.equal(response.status,403);
});

test('mobile UI warns whenever actual entry data is incomplete',()=>{
  const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
  assert.match(app,/tourAcceptancePartial=acceptancePartial/);
  assert.match(app,/Aucun statut n’est considéré comme confirmé/);
  assert.match(app,/tourCountEstimate\?"≈ ":/);
});
