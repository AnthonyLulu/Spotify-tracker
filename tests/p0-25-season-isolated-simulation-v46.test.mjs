import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import crypto from "node:crypto";

// An ISOLATED deterministic reference harness, not a production database
// replay. The retirement baseline is a read-only snapshot of
// living_world_stress_test_v16(2026,2050) on 2026-10-10.
// It includes retiring players already present in the 2025 starting roster.
// Newly generated cohorts are then simulated separately.
const baselineRetirements=[
  2659,2704,2549,2362,2201,2151,2005,1729,1505,1213,
  1153,1091,971,961,1012,985,977,984,907,821,
  749,673,543,346,213
];
const adultFloor=24000;
const initialAdults=27325;
const cohortHazard=age=>age<33?0:({
  33:.025,34:.04,35:.07,36:.11,37:.16,38:.22,39:.30,
  40:.39,41:.51,42:.65,43:.80,44:.93
}[age]??1);

function simulateAdultPopulation(yearlyCapacity){
  let adults=initialAdults;
  const cohorts=[];
  const years=[];
  for(let year=2026;year<=2050;year++){
    let newgenRetired=0;
    for(const c of cohorts){
      const due=Math.round(c.remaining*cohortHazard(year-c.entryYear+18));
      assert.ok(due>=0&&due<=c.remaining);
      c.remaining-=due;
      newgenRetired+=due;
    }
    const originalRetired=baselineRetirements[year-2026];
    const retired=originalRetired+newgenRetired;
    // Fill toward the opening 2025 adult pool. Avoid infinite inflation.
    const requested=Math.max(retired,initialAdults-(adults-retired));
    const promoted=Math.min(yearlyCapacity,Math.max(0,requested));
    adults+=promoted-retired;
    cohorts.push({entryYear:year,remaining:promoted});
    years.push({year,adults,retired,originalRetired,newgenRetired,promoted});
    assert.ok(Number.isInteger(adults)&&adults>=0);
  }
  return {
    years,
    minimumAdults:Math.min(...years.map(x=>x.adults)),
    underFloor:years.filter(x=>x.adults<adultFloor).map(x=>x.year),
    peakNewgenRetirement:Math.max(...years.map(x=>x.newgenRetired)),
    maxAnnualPromotion:Math.max(...years.map(x=>x.promoted))
  };
}

test("2026-2050 reference cohort stress: 3,400 annual supply survives second-generation retirements",()=>{
  const data=simulateAdultPopulation(3400);
  assert.equal(data.years.length,25);
  assert.deepEqual(data.underFloor,[]);
  assert.equal(data.minimumAdults,initialAdults);
  assert.ok(data.peakNewgenRetirement>1800,"newgens must age and retire, not become immortal");
  assert.ok(data.maxAnnualPromotion<=3400);
  console.log("25-SEASON SUPPLY",JSON.stringify({
    capacity:3400,minimumAdults:data.minimumAdults,
    year2050:data.years.at(-1),peakNewgenRetirement:data.peakNewgenRetirement
  }));
});

test("supply stress distinguishes an unsafe low-volume generation pipeline",()=>{
  const cap2000=simulateAdultPopulation(2000);
  const cap1000=simulateAdultPopulation(1000);
  assert.equal(cap2000.minimumAdults,24694);
  assert.ok(cap2000.years.some(x=>x.promoted<x.retired),
    "a 2,000 cap cannot cover the initial retirement peak");
  assert.equal(cap1000.underFloor[0],2027);
  assert.ok(cap1000.minimumAdults<adultFloor);
  console.log("SUPPLY SENSITIVITY",JSON.stringify({
    cap2000Min:cap2000.minimumAdults,
    cap1000FirstBreach:cap1000.underFloor[0],
    cap1000Min:cap1000.minimumAdults
  }));
});

const stableDigest=value=>crypto.createHash("sha256")
  .update(JSON.stringify(value,(_k,v)=>v instanceof Set?[...v].sort():v))
  .digest("hex");
const clone=value=>structuredClone(value);
function runManagedClock(){
  const DAY=86400000;
  const start=Date.parse("2025-12-01T00:00:00Z");
  const end=Date.parse("2051-01-01T00:00:00Z");
  const players=[
    {id:51,fatigue:20,elo:2050,matches:0,training:0,daysRecovered:new Set(),matchEffects:new Set()},
    {id:82,fatigue:15,elo:1750,matches:0,training:0,daysRecovered:new Set(),matchEffects:new Set()}
  ];
  let days=0,matches=0,skippedDuplicateEffects=0,checkpoints=0;
  const rng={state:0xC0FFEE};
  const random=()=>{rng.state=(Math.imul(1664525,rng.state)+1013904223)>>>0;return rng.state/2**32;};

  for(let millis=start;millis<end;millis+=DAY){
    const date=new Date(millis).toISOString().slice(0,10);
    days++;
    for(const player of players){
      const scheduled=days%5===player.id%5;
      const before=player.fatigue;
      const effectId=player.id+"|"+date+"|match";
      if(scheduled){
        // Offline reference: a match consumes its own load, not training load.
        const applyEffect=()=>{
          if(player.matchEffects.has(effectId))return "already_applied";
          player.matchEffects.add(effectId);
          player.fatigue=Math.min(100,player.fatigue+7+Math.floor(random()*15));
          player.matches++;
          matches++;
          return "applied";
        };
        assert.equal(applyEffect(),"applied");
        const afterFirst=stableDigest([player.fatigue,player.matches]);
        assert.equal(applyEffect(),"already_applied");
        assert.equal(stableDigest([player.fatigue,player.matches]),afterFirst);
        skippedDuplicateEffects++;
      }else{
        player.training++;
        // Training is not a match, and can't consume match fatigue twice.
        player.fatigue=Math.min(100,player.fatigue+2);
      }
      const recover=()=>{
        if(player.daysRecovered.has(date))return "already_applied";
        player.daysRecovered.add(date);
        player.fatigue=Math.max(0,player.fatigue-5);
        return "applied";
      };
      assert.equal(recover(),"applied");
      const recovered=player.fatigue;
      assert.equal(recover(),"already_applied");
      assert.equal(player.fatigue,recovered);
      assert.ok(player.fatigue>=0&&player.fatigue<=100);
      assert.ok(Math.abs(player.fatigue-before)<=25);
    }
    if(days%97===0){
      // Simulate closing and reopening the game without advancing the day.
      const previous=players.map(clone);
      const snapshot=previous.map(p=>({
        id:p.id,fatigue:p.fatigue,matches:p.matches,
        training:p.training,effects:[...p.matchEffects],
        recovery:[...p.daysRecovered]
      }));
      const serialized=JSON.stringify(snapshot);
      const reload=JSON.parse(serialized);
      for(let i=0;i<players.length;i++){
        assert.equal(reload[i].fatigue,players[i].fatigue);
        assert.equal(reload[i].matches,players[i].matches);
        assert.equal(reload[i].effects.length,players[i].matchEffects.size);
        assert.equal(reload[i].recovery.length,players[i].daysRecovered.size);
      }
      checkpoints++;
    }
  }
  return {days,matches,skippedDuplicateEffects,checkpoints,
    players:players.map(p=>({id:p.id,played:p.matches,training:p.training,recoveredDays:p.daysRecovered.size}))};
}

test("daily sandbox 2025-2050: matches, recoveries and reloads never double-apply",()=>{
  const result=runManagedClock();
  assert.ok(result.days>9100);
  assert.ok(result.matches>3500);
  assert.equal(result.skippedDuplicateEffects,result.matches);
  assert.ok(result.checkpoints>90);
  assert.ok(result.players.every(p=>p.recoveredDays===result.days));
  console.log("DAILY 25-YEAR SANDBOX",JSON.stringify(result));
});

test("save/load fault injection flags an incomplete rollback instead of claiming success",()=>{
  const before={date:"2028-05-17",day:903,elo:1888,fatigue:27,
    matchLedger:["final|s1"],recoveryLedger:["s1|post_match"],cash:19000};
  const safety=clone(before);
  const digest=stableDigest(safety);
  const mutated=clone(before);
  mutated.elo+=18;mutated.matchLedger.push("final|s2");mutated.cash-=500;
  // A failed load is recovered from a durable checkpoint.
  const restored=clone(safety);
  assert.equal(stableDigest(restored),digest);
  // Inject a partial recovery. A mismatched digest MUST NOT be called success.
  const badRestore=clone(safety);badRestore.recoveryLedger.push("s2|post_match");
  assert.notEqual(stableDigest(badRestore),digest);
  const reported={rollback_verified:stableDigest(badRestore)===digest};
  assert.equal(reported.rollback_verified,false);

  // Source gates: the production route must actually store, replay and verify
  // its durable journal. The synthetic fault injection above is not an E2E test.
  const edge=fs.readFileSync(new URL("../supabase/functions/court-boss/index.ts",import.meta.url),"utf8");
  assert.match(edge,/cb_prepare_load_recovery_v33/);
  assert.match(edge,/cb_get_load_recovery_v33/);
  assert.match(edge,/Crash recovery snapshot digest mismatch/);
  assert.match(edge,/rollbackRecovered=rollbackDigest===safetyDigest&&legacyRollbackDigest===legacySafetyDigest/);
});
