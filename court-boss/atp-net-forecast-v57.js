// Court Boss 2026: ATP 52-week net points forecast from ALREADY-FETCHED ranking-ledger.
// Projection only: assumes no new tournament results, sanctions, or withdrawals.
// Implements the same counting/replacement ordering as atp_player_breakdown SQL.
// Pure calculations, no API requests, no mutation of the live ledger or game save.
function cbAtpDayAfter(date){
  if(!/^\\d{4}-\\d{2}-\\d{2}$/.test(String(date||'')))return null;
  const d=new Date(String(date)+'T12:00:00Z');
  if(!Number.isFinite(d.getTime())||d.toISOString().slice(0,10)!==date)return null;
  d.setUTCDate(d.getUTCDate()+1);
  return d.toISOString().slice(0,10);
}
function cbAtpNetCountAt(pool,atDate){
  const active=pool.filter(e=>String(e.earned_date)<=atDate && String(e.drop_date)>=atDate);
  const mandatory=active.filter(e=>e.rank_category==='Grand Slam'||e.rank_category==='M1000');
  const optional=active.filter(e=>!['Grand Slam','M1000','Finals','Reconciliation'].includes(e.rank_category));
  const optionalSlots=Math.max(0,18-mandatory.length);
  const replacementCapacity=Math.max(0,Math.min(3,optional.length-optionalSlots));
  const optionalReplace=optional.filter(e=>e.rank_category==='ATP500'||e.rank_category==='ATP250');
  const mCandidates=active.filter(e=>e.rank_category==='M1000' &&
    optionalReplace.some(o=>o.earned_date>e.earned_date && o.points>e.points));
  mCandidates.sort((a,b)=>a.points-b.points||a.earned_date.localeCompare(b.earned_date)||a.event_key.localeCompare(b.event_key));
  const replacedMasters=mCandidates.slice(0,replacementCapacity);
  const replaceOptions=optionalReplace
    .filter(o=>replacedMasters.some(m=>o.earned_date>m.earned_date&&o.points>m.points))
    .sort((a,b)=>b.points-a.points||b.earned_date.localeCompare(a.earned_date)||a.event_key.localeCompare(b.event_key))
    .slice(0,replacedMasters.length);
  const replaceKeys=new Set(replaceOptions.map(e=>e.event_key));
  const masterKeys=new Set(replacedMasters.map(e=>e.event_key));
  const bestOptional=optional.filter(e=>!replaceKeys.has(e.event_key))
    .sort((a,b)=>b.points-a.points||b.earned_date.localeCompare(a.earned_date)||a.event_key.localeCompare(b.event_key))
    .slice(0,optionalSlots);
  const bestKeys=new Set(bestOptional.map(e=>e.event_key));
  const counting=active.filter(e=>e.rank_category==='Grand Slam'||e.rank_category==='Finals'||e.rank_category==='Reconciliation' ||
    (e.rank_category==='M1000'&&!masterKeys.has(e.event_key)) ||
    replaceKeys.has(e.event_key)||bestKeys.has(e.event_key));
  return {total:counting.reduce((sum,e)=>sum+e.points,0),counting};
}
function cbAtpNetForecast(ledger,cutoffDate){
  if(!ledger||!Array.isArray(ledger.counting)||!Array.isArray(ledger.non_counting)||
     !/^\\d{4}-\\d{2}-\\d{2}$/.test(String(ledger.date||''))||
     !/^\\d{4}-\\d{2}-\\d{2}$/.test(String(cutoffDate||''))||
     cutoffDate<=ledger.date)return {ok:false,reason:'insufficient_data'};
  const all=[...ledger.counting,...ledger.non_counting];
  const keys=new Set();
  const pool=[];
  for(const e of all){
    const key=String(e.event_key||''),points=Number(e.points);
    const earned=String(e.earned_date||''),drop=String(e.drop_date||e.expiry_date||'');
    if(!key||keys.has(key)||!/^\\d{4}-\\d{2}-\\d{2}$/.test(earned)||
       !/^\\d{4}-\\d{2}-\\d{2}$/.test(drop)||!Number.isFinite(points))
      return {ok:false,reason:'incomplete_or_duplicate_event'};
    keys.add(key);
    pool.push({...e,event_key:key,points,earned_date:earned,drop_date:drop});
  }
  const before=cbAtpNetCountAt(pool,ledger.date),after=cbAtpNetCountAt(pool,cutoffDate);
  const officialTotal=Number(ledger.total);
  // In particular, don't present an estimate if it disagrees with the actual SQL baseline.
  if(!Number.isFinite(officialTotal)||before.total!==officialTotal)
    return {ok:false,reason:'not_calibrated',computed_before:before.total,api_total:officialTotal};
  const gone=before.counting.filter(e=>e.points>0&&e.drop_date>=ledger.date&&e.drop_date<cutoffDate);
  const gross=gone.reduce((sum,e)=>sum+e.points,0),net=after.total-before.total;
  return {ok:true,date:ledger.date,cutoff_date:cutoffDate,
    points_before:before.total,points_after:after.total,
    expired_counted_points:gross,net_change_points:net,
    other_effects_points:net+gross,
    estimated:pool.some(e=>e.estimated===true||e.rank_category==='Reconciliation'),
    assumptions:'Known results only; no new matches, sanctions or entries'};
}
