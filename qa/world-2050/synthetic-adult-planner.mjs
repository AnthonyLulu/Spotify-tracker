// Offline, deterministic planning only. No SQL, network, saves or player writes.
const normalize=value=>String(value||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
const hash=s=>{let h=2166136261;for(const c of s)h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0};
const gcd=(a,b)=>{while(b){[a,b]=[b,a%b]}return a};
const nameOK=x=>typeof x==='string'&&x.trim().length>=2&&x.trim().length<=34&&/\p{L}/u.test(x)&&!/[0-9@_/\\<>]/.test(x);
export function buildCountryNamePools(rows){
 if(!Array.isArray(rows))throw Error('Licensed names must be an array');
 const map=new Map();
 for(const r of rows){
  if(!r||!['CC0','MIT'].includes(r.license)||!/^[A-Z]{3}$/.test(r.country||'')||!['first','last'].includes(r.kind)||!nameOK(r.value))continue;
  if(!map.has(r.country))map.set(r.country,{country:r.country,first:new Map(),last:new Map()});
  const name=r.value.trim();map.get(r.country)[r.kind].set(normalize(name),name);
 }
 return [...map.values()].map(c=>({
  country:c.country,first:[...c.first.values()].sort(),last:[...c.last.values()].sort(),
  capacity:c.first.size*c.last.size
 })).filter(c=>c.first.length>=8&&c.last.length>=8).sort((a,b)=>a.country.localeCompare(b.country));
}
export function planSynthetic2025Adults({licensedNames=[],existingAdults,existingNames=[],targetAdults=27000,seed='COURT-BOSS-2025',maxAdditions=30000}={}){
 if(!Number.isSafeInteger(existingAdults)||existingAdults<0)throw Error('Invalid adult baseline');
 if(!Number.isSafeInteger(targetAdults)||targetAdults<24000||targetAdults>30000)throw Error('Invalid adult target');
 if(!Number.isSafeInteger(maxAdditions)||maxAdditions<1||maxAdditions>30000)throw Error('Invalid quota');
 if(!Array.isArray(existingNames))throw Error('Invalid original player name index');
 const pools=buildCountryNamePools(licensedNames);
 const needed=Math.max(0,targetAdults-existingAdults);
 if(needed>maxAdditions)throw Error('Seed additions exceed safety cap');
 if(needed&&!pools.length)throw Error('No eligible licensed country name pools');
 const used=new Set(existingNames.map(normalize));
 const states=pools.map(c=>{
  const total=c.capacity,offset=hash(seed+'|'+c.country+'|offset')%total;
  let step=(hash(seed+'|'+c.country+'|stride')%total)||1;
  while(gcd(step,total)!==1)step=(step%total)+1;
  return {...c,total,offset,step,cursor:0};
 });
 const players=[];
 while(players.length<needed){
  let progress=false;
  for(const c of states){
   if(players.length>=needed)break;
   while(c.cursor<c.total){
    const idx=(c.offset+c.cursor*c.step)%c.total;c.cursor++;
    const first=c.first[idx%c.first.length],last=c.last[Math.floor(idx/c.first.length)];
    const full=first+' '+last,key=normalize(full);
    if(used.has(key)||normalize(first)===normalize(last))continue;
    used.add(key);progress=true;
    const index=players.length+1,roll=hash(seed+'|'+c.country+'|'+index);
    const age=18+(roll%19),month=1+((roll>>>7)%11),day=1+((roll>>>14)%28);
    const year=2025-age,ability=35+((roll>>>3)%35),potential=Math.min(99,Math.max(ability+8,52+((roll>>>11)%44)));
    players.push({
      slug:'e2e-2025-'+String(index).padStart(5,'0')+'-'+c.country.toLowerCase(),
      name:full,name_norm:key,country:c.country,birth_date:year+'-'+String(month).padStart(2,'0')+'-'+String(day).padStart(2,'0'),
      age,is_real:false,game_generated:true,generated_year:2025,generated_name_version:6,
      current_ability:ability,potential,career_status:'active',career_focus:roll%11===0?'doubles':roll%9===0?'singles':'mixed',
      ranking:null,points:0,doubles_ranking:null,junior_ranking:null,
      injury_status:'Fit',data_source:'ISOLATED-2025-SYNTHETIC-V1',data_snapshot:'2025-12-01'
    });
    break;
   }
  }
  if(!progress)throw Error('Exhausted globally unique licensed name combinations at '+players.length+'/'+needed);
 }
 return {status:'PLAN_ONLY_NO_DB_WRITE',existingAdults,targetAdults,plannedAdditions:players.length,
   finalAdults:existingAdults+players.length,eligibleCountries:states.length,
   theoreticalCombinations:states.reduce((n,c)=>n+c.total,0),players};
}
