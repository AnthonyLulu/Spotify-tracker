import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const start=edge.indexOf('if(kind==="junior"){',edge.indexOf('if(path.endsWith("/api/rankings")'));
const end=edge.indexOf('\n\n\n    let orderCol=',start);
assert.ok(start>=0&&end>start,'junior ranking handler must exist');
// Evaluate the production handler using a fake read-only Supabase query layer.
// The TypeScript-only annotations are stripped for Node's JavaScript runtime.
const block=edge.slice(start,end).replaceAll('(p:any)=>','(p)=>').replaceAll('(r:any)=>','(r)=>');

const execute=async({pageError=null,auxError=null,queryReject=null}={})=>{
  const reads=[];
  const makeQuery=(table)=>{
    let rankType='';
    const q={
      select(){return q;},
      eq(field,value){if(field==='rank_type')rankType=value;return q;},
      ilike(){return q;},order(){return q;},range(){return q;},
      gte(){return q;},lte(){return q;},or(){return q;},
      then(resolve,reject){
        reads.push({table,rankType});
        if(table===queryReject||rankType===queryReject)
          return Promise.reject(new Error('upstream reset')).then(resolve,reject);
        const sample={id:123,name:'Junior Example',rank_type:'official',display_rank:1,junior_points:100,junior_game_points:10,age:16};
        const result=table==='junior_display_pool_view'
          ?{data:pageError?null:[sample],count:pageError?null:1,error:pageError&&{message:pageError}}
          :{count:table==='players'?4000:rankType==='official'?31:rankType==='verified_nr'?3:1200,
            error:table===auxError||rankType===auxError?{message:'statement timeout'}:null};
        return Promise.resolve(result).then(resolve,reject);
      }
    };
    return q;
  };
  const context={db:{from:makeQuery},kind:'junior',q:'',country:'',offset:0,limit:10,
    normalizeName:v=>v,ageAt:(_date,_baseline,age)=>age,
    AGE_REFERENCE_DATE:'2025-12-01',
    h:(body,status=200)=>({body,status})};
  const response=await vm.runInNewContext('(async()=>{'+block+'})()',context);
  return {response,reads};
};

test('junior ranking survives timeout of optional pool count',async()=>{
  const {response,reads}=await execute({auxError:'simulated'});
  assert.equal(response.status,200);
  assert.equal(response.body.rows.length,1);
  assert.equal(response.body.rows[0].junior_points,110);
  assert.equal(response.body.metadataPartial,true);
  assert.equal(response.body.generatedCount,null);
  assert.equal(response.body.officialRealCount,34);
  assert.equal(response.body.generatedReserve,null);
  assert.equal(reads.length,5);
  assert.equal(reads.filter(x=>x.table==='players').length,1);
});

test('junior ranking survives rejected database Promise',async()=>{
  const {response}=await execute({queryReject:'players'});
  assert.equal(response.status,200);
  assert.equal(response.body.metadataPartial,true);
  assert.equal(response.body.generatedReserve,null);
  assert.equal(response.body.rows.length,1);
});

test('normal junior counts are preserved and reserve is explicitly estimated',async()=>{
  const {response}=await execute();
  assert.equal(response.status,200);
  assert.equal(response.body.count,1);
  assert.equal(response.body.metadataPartial,false);
  assert.equal(response.body.officialRankedCount,31);
  assert.equal(response.body.verifiedUnrankedCount,3);
  assert.equal(response.body.officialRealCount,34);
  assert.equal(response.body.generatedCount,1200);
  assert.equal(response.body.generatedReserveEstimated,true);
  assert.equal(response.body.generatedReserve,2800);
});

test('missing ranking page is surfaced as error and never a fake empty table',async()=>{
  const {response}=await execute({pageError:'statement timeout'});
  assert.equal(response.status,500);
  assert.equal(response.body.error,'statement timeout');
  assert.ok(!response.body.rows);
});

test('junior UI explains partial counts instead of displaying fake zeroes',()=>{
  const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
  assert.match(app,/rankMeta\?\.metadataPartial\?"Statistiques du vivier momentanément indisponibles"/);
});
