import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const start=edge.indexOf('if(kind==="junior"){',edge.indexOf('if(path.endsWith("/api/rankings")'));
const end=edge.indexOf('\n\n\n    let orderCol=',start);
assert.ok(start>=0&&end>start,'junior ranking handler must exist');
// Execute the real handler body with mocked database queries. Only remove a
// TypeScript type annotation so Node can evaluate the production branch.
const block=edge.slice(start,end).replace('(p:any)=>','(p)=>');

const execute=async({pageError=null,auxError=null}={})=>{
  const reads=[];
  const makeQuery=(table)=>{
    let rankType='';
    const q={
      select(){return q;},
      eq(field,value){if(field==='rank_type')rankType=value;return q;},
      ilike(){return q;},
      order(){return q;},
      range(){return q;},
      then(resolve,reject){
        reads.push({table,rankType});
        const sample={id:123,name:'Junior Example',rank_type:'official',display_rank:1,junior_points:100,junior_game_points:10,age:16};
        const result=table==='junior_display_pool_view'
          ?{data:pageError?null:[sample],count:pageError?null:1,error:pageError&&{message:pageError}}
          :{count:rankType==='official'?31:rankType==='verified_nr'?3:1200,
            error:rankType===auxError?{message:'statement timeout'}:null};
        return Promise.resolve(result).then(resolve,reject);
      }
    };
    return q;
  };
  const db={from:makeQuery};
  const context={db,kind:'junior',q:'',country:'',offset:0,limit:10,
    normalizeName:v=>v,ageAt:(_date,_baseline,age)=>age,
    AGE_REFERENCE_DATE:'2025-12-01',
    h:(body,status=200)=>({body,status})};
  const response=await vm.runInNewContext('(async()=>{'+block+'})()',context);
  return {response,reads};
};

test('junior rankings survive timeout on optional pool count',async()=>{
  const {response,reads}=await execute({auxError:'simulated'});
  assert.equal(response.status,200);
  assert.equal(response.body.rows.length,1);
  assert.equal(response.body.rows[0].junior_points,110);
  assert.equal(response.body.metadataPartial,true);
  assert.equal(response.body.generatedCount,null);
  assert.equal(response.body.officialRealCount,34);
  assert.equal(response.body.generatedReserve,null);
  assert.equal(reads.length,4,'no full players reserve count may run');
  assert.ok(reads.every(x=>x.table!=='players'));
});

test('junior ranking counts remain correct when all queries succeed',async()=>{
  const {response}=await execute();
  assert.equal(response.status,200);
  assert.equal(response.body.count,1);
  assert.equal(response.body.metadataPartial,false);
  assert.equal(response.body.officialRankedCount,31);
  assert.equal(response.body.verifiedUnrankedCount,3);
  assert.equal(response.body.officialRealCount,34);
  assert.equal(response.body.generatedCount,1200);
});

test('failure of leaderboard itself is a retryable 503, not fake empty ranking',async()=>{
  const {response}=await execute({pageError:'statement timeout'});
  assert.equal(response.status,503);
  assert.equal(response.body.code,'junior_ranking_page_unavailable');
  assert.equal(response.body.retryable,true);
  assert.ok(!response.body.rows);
});

test('junior UI explains partial counts instead of displaying fake zeroes',()=>{
  const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
  assert.match(app,/rankMeta\?\.metadataPartial\?"statistiques du vivier temporairement partielles"/);
});
