const API='https://qrsvliliezbiedmaewml.supabase.co/functions/v1/court-boss';
const app=document.getElementById('app'),overlay=document.getElementById('overlay');
const country2={
 AFG:'AF',ALB:'AL',ALG:'DZ',AND:'AD',AGO:'AO',ANG:'AO',AHO:'CW',ANT:'CW',ARG:'AR',ARM:'AM',ARU:'AW',AUS:'AU',AUT:'AT',AZE:'AZ',
 BAH:'BS',BAR:'BB',BDI:'BI',BEL:'BE',BEN:'BJ',BER:'BM',BHR:'BH',BIH:'BA',BIZ:'BZ',BLR:'BY',BOL:'BO',BOT:'BW',BRA:'BR',BRN:'BH',BUL:'BG',
 CAL:'NC',CAM:'KH',CAN:'CA',CHI:'CL',CHL:'CL',CHN:'CN',CIV:'CI',CMR:'CM',COD:'CD',COG:'CG',CGO:'CG',COL:'CO',CRC:'CR',CRO:'HR',CUB:'CU',CUW:'CW',CYP:'CY',CZE:'CZ',
 DEN:'DK',DOM:'DO',ECU:'EC',EGY:'EG',ESA:'SV',ESP:'ES',EST:'EE',ETH:'ET',
 FIJ:'FJ',FIN:'FI',FRA:'FR',GAB:'GA',GAM:'GM',GBR:'GB',GEO:'GE',GER:'DE',GHA:'GH',GRE:'GR',GRN:'GD',GTM:'GT',GUA:'GT',GUD:'GP',GUI:'GN',GUM:'GU',GUY:'GY',
 HAI:'HT',HKG:'HK',HON:'HN',HUN:'HU',INA:'ID',IND:'IN',IRI:'IR',IRL:'IE',IRQ:'IQ',ISL:'IS',ISR:'IL',ITA:'IT',
 JAM:'JM',JOR:'JO',JPN:'JP',KAZ:'KZ',KEN:'KE',KGZ:'KG',KOR:'KR',KSA:'SA',KUW:'KW',
 LAO:'LA',LAT:'LV',LBA:'LY',LBN:'LB',LIB:'LB',LIE:'LI',LTU:'LT',LUX:'LU',
 MAD:'MG',MDG:'MG',MAR:'MA',MAS:'MY',MDA:'MD',MEX:'MX',MKD:'MK',MLI:'ML',MLT:'MT',MNE:'ME',MON:'MC',MOZ:'MZ',MRI:'MU',MYA:'MM',
 NAM:'NA',NCA:'NI',NIC:'NI',NED:'NL',NEP:'NP',NPL:'NP',NGA:'NG',NGR:'NG',NMI:'MP',NOR:'NO',NZL:'NZ',
 PAK:'PK',PAN:'PA',PAR:'PY',PRY:'PY',PER:'PE',PHI:'PH',PNG:'PG',POL:'PL',POR:'PT',PUR:'PR',QAT:'QA',
 REU:'RE',ROU:'RO',RSA:'ZA',RUS:'RU',RWA:'RW',SEN:'SN',SGP:'SG',SIN:'SG',SLO:'SI',SRB:'RS',SRI:'LK',SUD:'SD',SUI:'CH',SUR:'SR',SVK:'SK',SWE:'SE',SWZ:'SZ',SYR:'SY',
 TGO:'TG',TOG:'TG',THA:'TH',TJK:'TJ',TKM:'TM',TPE:'TW',TTO:'TT',TUN:'TN',TUR:'TR',
 UAE:'AE',UGA:'UG',UKR:'UA',URU:'UY',USA:'US',UZB:'UZ',TWN:'TW',BRU:'BN',OMA:'OM',PLE:'PS',MGL:'MN',VAN:'VU',VEN:'VE',VIE:'VN',YEM:'YE',ZAM:'ZM',ZIM:'ZW',
 ASA:'AS',BUR:'BF',CAF:'CF',CPV:'CV',HAW:'US',ISV:'VI',LCA:'LC',LES:'LS',NIG:'NE',SCG:'RS',SEY:'SC',SLE:'SL',SMR:'SM',TRI:'TT',VIN:'VC',URS:'RU',YUG:'RS',TCH:'CZ',FRG:'DE',GDR:'DE',KOS:'XK',SAM:'WS',SOL:'SB',FSM:'FM',MHL:'MH',NRU:'NR',TGA:'TO',TUV:'TV',CHA:'TD',COM:'KM',DJI:'DJ',EQG:'GQ',ERI:'ER',GNB:'GW',LBR:'LR',MAW:'MW',SOM:'SO',SSD:'SS',TAN:'TZ'
};
const emojiFlag=code=>{
 const raw=String(code||'').toUpperCase();
 if(raw==='ITF')return '🌐';
 if(raw==='UNK'||!raw)return '🌐';
 const iso=country2[raw]||(raw.length===2?raw:'');
 if(!/^[A-Z]{2}$/.test(iso))return '🏳️';
 return [...iso].map(c=>String.fromCodePoint(127397+c.charCodeAt(0))).join('');
};
const flags=new Proxy({},{
 get(_target,key){return emojiFlag(String(key||''))}
});
function countryTheme(code){
 const c=String(code||'').toUpperCase();
 const fixed={
  SRB:['#c6363c','#244aa5'],FRA:['#244aa5','#e63946'],ESP:['#aa151b','#f1bf00'],
  ITA:['#16864b','#d33d3d'],USA:['#1d4f91','#b22234'],GBR:['#21468b','#cf142b'],
  GER:['#272727','#d6a700'],SUI:['#d52b1e','#f7f7f7'],AUT:['#d81e35','#f4f4f4'],
  AUS:['#0b6b46','#f1c40f'],CAN:['#d52b1e','#f3f3f3'],ARG:['#64b5e8','#f3f3f3'],
  BRA:['#169b62','#ffdf00'],CZE:['#3155a6','#d51d36'],POL:['#dc143c','#f6f6f6'],
  NED:['#e86a17','#21468b'],BEL:['#202020','#f0c808'],GRE:['#2d5da8','#f5f5f5'],
  JPN:['#f4f4f4','#bc002d'],CHN:['#de2910','#ffde00'],KOR:['#f3f3f3','#2457a5'],
  SWE:['#1769aa','#f5cc18'],NOR:['#ba0c2f','#173b6c'],DEN:['#c60c30','#f5f5f5'],
  RUS:['#f5f5f5','#1c57a7'],UKR:['#1e75bb','#ffd700'],CRO:['#d91e36','#21468b']
 };
 if(fixed[c])return {a:fixed[c][0],b:fixed[c][1]};
 let h=0;for(const ch of c)h=(h*31+ch.charCodeAt(0))%360;
 return {a:`hsl(${h} 55% 34%)`,b:`hsl(${(h+42)%360} 58% 24%)`};
}
const saveKey=(()=>{let k=localStorage.getItem('courtBossSaveKey');if(!k){k=crypto.randomUUID();localStorage.setItem('courtBossSaveKey',k)}return k})();
let accessKey=(localStorage.getItem('courtBossAccessKey')||'').trim();
function courtBossAccessKey(){
  if(!accessKey)accessKey=(prompt('Code d’accès Court Boss')||'').trim();
  return accessKey;
}
const fmt=n=>new Intl.NumberFormat('fr-FR').format(Math.round(Number(n)||0));
const euro=n=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(Number(n)||0);
const df=s=>s?new Date(s+'T12:00:00').toLocaleDateString('fr-FR',{day:'2-digit',month:'short',year:'numeric'}):'—';
const RANKING_SNAPSHOT='2025-12-01';
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const get=async(path,opts={},retried=false)=>{const key=courtBossAccessKey();const r=await fetch(API+path,{...opts,headers:{'X-Save-Key':saveKey,'X-Court-Boss-Key':key,...(opts.headers||{})}});const body=await r.json().catch(()=>({error:'Réponse serveur illisible'}));if(r.status===401&&!retried){localStorage.removeItem('courtBossAccessKey');accessKey='';return get(path,opts,true)}if(r.status===401)throw new Error('Code d’accès Court Boss incorrect.');if(!r.ok)throw new Error(body.error||'Erreur serveur '+r.status);if(key)localStorage.setItem('courtBossAccessKey',key);return body;};
let boot=null,route='home',rankKind='singles',rankOffset=0,rankRows=[],rankCount=0,rankMeta={},rankQuery='',rankCountry='',nextGenAge=21,countryRows=[],historyData=null,historyCountry='',historyContinent='',tourOffset=0,tourRows=[],tourTbc=[],tourCount=0,tourFilters={circuit:'Tous',category:'Toutes',surface:'Toutes',source:'Tous',month:'',q:''},tourShowPast=false,management=null,worldStats=null,rankingLedger=null,seasonSummary=null,scheduleAdvice=null,simulating=false;
let competitionRows=[],competitionCount=0,competitionOffset=0,competitionLoading=false,competitionFilters={q:'',circuit:'Tous',category:'Toutes',surface:'Toutes',country:'',source:'Tous',prestige:'Tous',history:'Tous',holder:'Tous'};
let doublesHubRows=[],juniorDoublesHubRows=[],doublesRaceRows=[],doublesHubLoading=false;
let tmCalFilters={week:'Toutes',country:'Tous',status:'Tous',eligibility:'Tous',environment:'Tous',entry:'Tous',holder:'Tous'};
let ncaaView='singles',ncaaDoublesRows=[],ncaaDoublesMeta={};
let liveAutoTimer=null,liveAutoBusy=false,liveAutoSpeed=1;
let dbRows=[],dbCount=0,dbOffset=0,dbQuery='',dbCountry='',dbCircuit='Tous réels',dbLoaded=false,dbLoading=false;
let staffWorldData=null,staffWorldLoading=false,staffWorldOffset=0,staffWorldFilters={q:'',role:'',country:'',former:'Tous',status:'Tous'};
let local={date:'2025-12-01',week:1,training:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'],entries:[],shortlist:[],career:null,feed:[],scoutingBoost:0,partnerId:null,davisRoles:{},fantasy:[],tactics:{aggression:58,risk:52,net:28,returnPos:'Neutre'}};
local.doublesEntries=local.doublesEntries||[];local.doublesEntryMeta=local.doublesEntryMeta||{};
try{Object.assign(local,JSON.parse(localStorage.getItem('cbLocal')||'{}'))}catch{}
function persist(){localStorage.setItem('cbLocal',JSON.stringify(local));const key=courtBossAccessKey();fetch(API+'/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Save-Key':saveKey,'X-Court-Boss-Key':key},body:JSON.stringify(local)}).catch(()=>{})}
function surfaceClass(s){const v=String(s||'');return v==='Terre'?'surface-clay':v==='Gazon'?'surface-grass':/intérieur/i.test(v)?'surface-indoor':'surface-hard'}
function surfaceLabel(t){
 if(typeof t==='string')return t;
 const base=String(t?.surface||'Dur');
 return base==='Dur'?((t?.indoor===true||String(t?.environment||'Outdoor')==='Indoor')?'Dur intérieur':'Dur extérieur'):base;
}
function circuitClass(c){return c==='Challenger'?'tag-challenger':c==='ITF'?'tag-itf':c==='NCAA'?'tag-ncaa':c==='Junior'?'tag-junior':c==='Federation'?'tag-fed':'tag-atp'}
function rankValue(p,k){return k==='doubles'?p.doubles_ranking:k==='junior_doubles'?p.junior_doubles_ranking:k==='race'?p.race_ranking:k==='doubles_race'?p.doubles_race_ranking:k==='junior_race'?p.junior_race_ranking:k==='junior_doubles_race'?p.junior_doubles_race_ranking:k==='nextgen'?p.nextgen_ranking:k==='itf'?p.itf_ranking:k==='junior'?p.junior_ranking:k==='ncaa'?p.ncaa_rank:(p.official_ranking??(p.ranking_current?p.ranking:null)??p.game_world_rank??p.world_rank??p.ranking)}
function rankCell(p,k){
 const v=rankValue(p,k);
 return v==null?'<span class="muted">NR</span>':'#'+fmt(v);
}
function rankPoints(p,k){return k==='doubles'?p.doubles_points:k==='junior_doubles'?p.junior_doubles_points:k==='race'?p.race_points:k==='doubles_race'?p.doubles_race_points:k==='junior_race'?p.junior_race_points:k==='junior_doubles_race'?p.junior_doubles_race_points:k==='nextgen'?p.nextgen_points:k==='junior'?(Number(p.junior_points||0)+Number(p.junior_game_points||0)):k==='ncaa'?null:p.points}
function rankSnapshot(p,k){
 return k==='doubles'?p.doubles_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_doubles'?p.junior_doubles_snapshot_date||RANKING_SNAPSHOT:
        k==='doubles_race'?p.doubles_race_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_race'?p.junior_race_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_doubles_race'?p.junior_doubles_race_snapshot_date||RANKING_SNAPSHOT:
        k==='race'?p.race_snapshot_date||RANKING_SNAPSHOT:
        k==='nextgen'?p.nextgen_snapshot_date||RANKING_SNAPSHOT:
        k==='junior'?p.junior_snapshot_date||RANKING_SNAPSHOT:
        k==='ncaa'?p.ncaa_snapshot_date:
        p.ranking_snapshot_date||p.data_snapshot||RANKING_SNAPSHOT
}
function ageAtSnapshot(birth,snapshot){
 if(!birth)return null;
 const b=new Date(birth+'T12:00:00'),d=new Date((snapshot||'2025-12-01')+'T12:00:00');
 let a=d.getFullYear()-b.getFullYear();
 if(d.getMonth()<b.getMonth()||(d.getMonth()===b.getMonth()&&d.getDate()<b.getDate()))a--;
 return a;
}
function displayAge(p,at=RANKING_SNAPSHOT){
 if(!p)return null;
 if(p.birth_date)return ageAtSnapshot(p.birth_date,at);
 if(p.age==null)return null;
 const snap=p.age_snapshot_date||p.data_snapshot||null;
 if(!snap)return Number(p.age);
 const y=Number(String(at).slice(0,4)),sy=Number(String(snap).slice(0,4));
 return Number(p.age)+(Number.isFinite(y)&&Number.isFinite(sy)?y-sy:0);
}
function rankAge(p,k){return p?.is_team?'—':(displayAge(p,RANKING_SNAPSHOT)??'—')}
function ageLabel(p,withUnit=true){
 const age=displayAge(p,RANKING_SNAPSHOT);
 if(age==null)return withUnit?'âge N/V':'N/V';
 const est=/estim/i.test(String(p.age_source||''))||(!p.birth_date&&String(p.age_snapshot_date||'').slice(0,4)!==String(RANKING_SNAPSHOT).slice(0,4));
 return (est?'≈':'')+age+(withUnit?' ans':'');
}


function officialAtpPhotoUrl(p){
 const code=String(p?.atp_code||'').trim().toLowerCase();
 return /^[a-z0-9]{4}$/.test(code)
   ?'https://www.atptour.com/-/media/alias/player-gladiator-headshot/'+encodeURIComponent(code)
   :'';
}
function playerPhotoCandidates(p){
 const out=[];
 const add=(url,source)=>{
   const u=String(url||'').trim();
   if(!u||out.some(x=>x.url===u))return;
   out.push({url:u,source});
 };
 if(p?.is_real)add(officialAtpPhotoUrl(p),'ATP');
 add(p?.itf_photo_url,'ITF');
 const wiki=String(p?.wiki_photo_url||'').trim()
   ||(/wiki|commons/i.test(String(p?.photo_source||''))?String(p?.photo_url||'').trim():'');
 add(wiki,'Wikipedia/Wikimedia');
 if(p?.photo_url&&!/wiki|commons/i.test(String(p?.photo_source||'')))add(p.photo_url,p.photo_source_label||p.photo_source||'Photo joueur');
 return out;
}
function playerPhotoSourceLabel(p){
 return playerPhotoCandidates(p)[0]?.source||'';
}
window.cbPhotoFallback=img=>{
 if(!img)return;
 const fallbacks=String(img.dataset?.fallbacks||'').split('|').filter(Boolean);
 const idx=Number(img.dataset?.fallbackIndex||0);
 if(idx<fallbacks.length){
   img.dataset.fallbackIndex=String(idx+1);
   try{img.src=decodeURIComponent(fallbacks[idx])}catch{img.src=fallbacks[idx]}
   return;
 }
 img.style.display='none';
 const blank=img.nextElementSibling;
 if(blank)blank.style.display='flex';
};
function playerPhotoMarkup(p){
 const candidates=playerPhotoCandidates(p);
 const blank=(visible=false)=>`<div aria-label="Aucune photo officielle disponible" title="Aucune photo officielle disponible" style="display:${visible?'flex':'none'};width:100%;height:100%;align-items:center;justify-content:center;background:linear-gradient(160deg,#10251c,#09150f)"><span style="display:block;width:42px;height:52px;border:2px solid rgba(225,238,231,.18);border-radius:24px 24px 14px 14px;position:relative"></span></div>`;
 if(!candidates.length)return blank(true);
 const primary=candidates[0].url;
 const fallbacks=candidates.slice(1).map(x=>encodeURIComponent(x.url)).join('|');
 return `<img src="${esc(primary)}" data-fallbacks="${esc(fallbacks)}" data-fallback-index="0" alt="${esc(p?.name||'Joueur')}" loading="lazy" decoding="async" style="width:100%;height:100%;object-fit:cover;object-position:center 10%" onerror="cbPhotoFallback(this)">${blank(false)}`;
}

function attrClass(v){return v>=18?'a-elite':v>=15?'a-good':v<=8?'a-low':'a-mid'}
function header(){
 const cr=local.career||boot?.career||{};
 return `<header class="topbar"><div class="logo">COURT <b>BOSS</b></div><span class="top-date">${df(local.date||cr.career_date)}</span><div class="grow"></div><button class="ghost icon-btn" onclick="openGlobalSearch()" aria-label="Recherche">⌕</button><button class="ghost" onclick="nav('inbox')">Boîte <span class="badge">${boot?.inbox?.filter(x=>!x.is_read).length||0}</span></button><button class="primary" ${simulating?'disabled':''} onclick="simulateWeek()">${simulating?'Simulation…':'+ 1 semaine'}</button></header>`
}
function navBar(){
 const x=[['home','Accueil'],['rankings','Classements'],['calendar','Calendrier'],['academy','Académie'],['more','Plus']];
 return `<nav class="bottom-nav">${x.map(i=>`<button class="${route===i[0]?'active':''}" onclick="nav('${i[0]}')">${i[1]}</button>`).join('')}</nav>`
}
function managerStrip(){
 const c=career(),fin=boot?.finance||{},doublesOnly=String(c.career_focus||'mixed')==='doubles_only';
 return `<div class="manager-strip">
  <div class="manager-cell"><span>Semaine</span><b>${local.week||1}</b></div>
  <div class="manager-cell"><span>${doublesOnly?'Double':'ATP'}</span><b>#${fmt(doublesOnly?c.doubles_rank||0:c.singles_rank||0)}</b></div>
  <div class="manager-cell"><span>Budget</span><b>${euro(c.budget??fin.balance??0)}</b></div>
  <div class="manager-cell wide"><span>Date carrière</span><b>${df(local.date||c.career_date)}</b></div>
  <button class="manager-world" onclick="nav('world')">Monde ▸</button>
 </div>`
}
function shell(body){app.innerHTML=`<div class="app-shell">${header()}${managerStrip()}<main class="page">${body}</main>${navBar()}</div>`}
function loading(t='Chargement du monde tennis…'){shell(`<div class="loader">${t}</div>`)}
window.nav=async r=>{
 route=r;
 window.scrollTo({top:0,behavior:'smooth'});
 try{
  if(r==='rankings'&&!rankRows.length){
   loading('Chargement du classement…');
   await loadRankings();
  }
  if(r==='calendar'&&!tourRows.length){
   loading('Chargement du calendrier…');
   await loadTournaments();
  }
  if(r==='world'&&!worldStats){
   loading('Chargement du monde tennis…');
   worldStats=await get('/api/world');
  }
  if(r==='players'&&!countryRows.length)await loadCountries();
  if(r==='history'&&!historyData){
   loading('Chargement de l’histoire du tennis…');
   await loadHistory();
  }
  if(r==='competitions'&&!competitionRows.length){
   loading('Chargement des compétitions…');
   await loadCompetitions();
  }
  if(r==='staff'&&!staffWorldData){
   loading('Chargement de la base mondiale du staff…');
   await loadStaffWorld();
  }
 }catch(e){
  console.warn('Court Boss route load failed',r,e);
  shell(`<div class="card"><h2>Chargement impossible</h2><p class="muted">${esc(e.message)}</p><div class="row"><button class="primary" onclick="nav('${esc(r)}')">Réessayer</button><button class="ghost" onclick="nav('home')">Accueil</button></div></div>`);
  return;
 }
 await render();
}
async function init(){
 loading();
 try{
   boot=await get('/api/bootstrap');
   if(boot.save&&typeof boot.save==='object') Object.assign(local,boot.save);
   local.career={...(local.career||{}),...(boot.career||{})};
   local.date=boot.career?.career_date||local.date||RANKING_SNAPSHOT;
   local.week=boot.career?.week??local.week??1;
   if(String(local.career?.career_focus||'mixed')==='doubles_only'){
     rankKind='doubles';
     tmCalFilters.entry='Double';
     local.entries=[];
     local.entryMeta={};
     if(!Array.isArray(local.training)||!local.training.length){
       local.training=['Double','Service','Retour','Double','Match play','Récupération','Repos'];
     }
   }
   localStorage.setItem('cbLocal',JSON.stringify(local));

   // Render immediately after the small bootstrap. Heavy world/ranking/calendar data
   // is now lazy-loaded by route instead of hammering Postgres at startup.
   render();

   Promise.allSettled([
     loadManagement(),
     loadRankingLedger(),
     loadSeasonSummary(),
     loadScheduleAdvice(),
     loadCountries()
   ]).then(()=>{if(route==='home'||route==='more')render()});
 }catch(e){
   shell(`<div class="card"><h2>Connexion au monde impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="location.reload()">Réessayer</button></div>`);
 }
}
async function loadManagement(){try{management=await get('/api/management')}catch{management={contracts:[],college:[],shortlist:[]}}}
async function loadStaffWorld(){
 if(staffWorldLoading)return;
 staffWorldLoading=true;
 try{
  const p=new URLSearchParams({offset:String(staffWorldOffset),limit:'50'});
  const f=staffWorldFilters||{};
  if(f.q)p.set('q',f.q);
  if(f.role)p.set('role',f.role);
  if(f.country)p.set('country',f.country);
  if(f.former)p.set('former',f.former);
  if(f.status)p.set('status',f.status);
  staffWorldData=await get('/api/staff-world?'+p.toString());
 }finally{staffWorldLoading=false}
}
async function loadRankings(){
 const q=rankQuery?'&q='+encodeURIComponent(rankQuery):'';
 const u=rankKind==='nextgen'?'&u='+nextGenAge:'';
 const c=rankCountry?'&country='+encodeURIComponent(rankCountry):'';
 const d=await get(`/api/rankings?kind=${rankKind}&offset=${rankOffset}&limit=100${q}${u}${c}`);
 rankRows=d.rows;rankCount=d.count;rankMeta=d;
 if(rankKind==='ncaa'){
  try{
   const nd=await get('/api/ncaa-doubles?offset=0&limit=100'+(rankQuery?'&q='+encodeURIComponent(rankQuery):''));
   ncaaDoublesRows=nd.rows||[];ncaaDoublesMeta=nd;
  }catch(e){ncaaDoublesRows=[];ncaaDoublesMeta={error:e.message}}
 }
}
async function loadCountries(){
 try{const d=await get('/api/countries');countryRows=d.rows||[]}catch{countryRows=[]}
}
async function loadPlayerDatabase(){
 if(dbLoading)return;
 dbLoading=true;
 try{
  const p=new URLSearchParams({offset:String(dbOffset),limit:'100',circuit:dbCircuit||'Tous'});
  if(dbQuery)p.set('q',dbQuery);
  if(dbCountry)p.set('country',dbCountry);
  const d=await get('/api/search-players?'+p.toString());
  dbRows=d.rows||[];dbCount=d.count||0;dbLoaded=true;
 }finally{dbLoading=false}
}

async function loadHistory(){
 const p=new URLSearchParams({limit:'300'});
 if(historyCountry)p.set('country',historyCountry);
 if(historyContinent)p.set('continent',historyContinent);
 try{historyData=await get('/api/history-hub?'+p.toString())}catch(e){historyData={rows:[],countryBest:[],continentBest:[],methodology:e.message,coverage:{players:0,countries:0}}}
}
async function loadTournaments(){
 const buildParams=(circuitOverride="")=>{
  const p=new URLSearchParams({offset:circuitOverride?"0":String(tourOffset),limit:"150"});
  if(!tourFilters.month)p.set("from","2025-12-01");
  if(circuitOverride)p.set("circuit",circuitOverride);
  Object.entries(tourFilters).forEach(([k,v])=>{
   if(!v||v==="Tous"||v==="Toutes"||(circuitOverride&&k==="circuit"))return;
   if(k==="source"&&v==="Fictif"&&(circuitOverride==="Junior"||(!circuitOverride&&tourFilters.circuit==="Junior"))){
    p.set("source","Simulation");
   }else{
    p.set(k,String(v));
   }
  });
  return p;
 };

 const base=await get("/api/tournaments?"+buildParams().toString());
 let rows=base.rows||[];
 let tbc=[...(base.tbc||[])];

 const overview=!tourFilters.circuit||tourFilters.circuit==="Tous";
 if(tourOffset===0&&overview){
  const priorityCircuits=["ATP","Junior","NCAA","Federation"];
  const extra=await Promise.all(priorityCircuits.map(async circuit=>{
   try{return await get("/api/tournaments?"+buildParams(circuit).toString())}
   catch{return {rows:[],tbc:[]}}
  }));
  extra.forEach(x=>{
   rows.push(...(x.rows||[]));
   tbc.push(...(x.tbc||[]));
  });
 }

 const byId=new Map();
 rows.forEach(t=>byId.set(Number(t.id),t));
 tourRows=[...byId.values()].sort((a,b)=>
  String(a.start_date||"").localeCompare(String(b.start_date||""))||
  Number(Boolean(b.is_verified))-Number(Boolean(a.is_verified))||
  String(a.name||"").localeCompare(String(b.name||""))
 );
 const tbcKey=x=>[x.id||"",x.name||"",x.start_date||"",x.circuit||""].join("|");
 tourTbc=[...new Map(tbc.map(x=>[tbcKey(x),x])).values()];
 tourCount=base.count||tourRows.length;
}
async function loadCompetitions(){
 competitionLoading=true;
 try{
  const p=new URLSearchParams({offset:String(competitionOffset),limit:'100'});
  Object.entries(competitionFilters).forEach(([k,v])=>{if(v&&v!=='Tous'&&v!=='Toutes')p.set(k,v)});
  const d=await get('/api/competitions?'+p.toString());
  competitionRows=d.rows||[];competitionCount=d.count||0;
 }finally{competitionLoading=false}
}

async function loadRankingLedger(){try{rankingLedger=await get('/api/ranking-ledger?date='+(local.date||RANKING_SNAPSHOT))}catch(e){rankingLedger={total:((local.career&&local.career.points)||34),active:[],expired:[]}}}
async function loadSeasonSummary(){try{seasonSummary=await get('/api/season-summary')}catch(e){seasonSummary={stats:{tournaments:0,titles:0,finals:0,prize:0,matches:0,wins:0},singles:[],doubles:[],singles_points:[],doubles_points:[]}}}
async function loadScheduleAdvice(){try{scheduleAdvice=await get('/api/schedule-advice')}catch(e){scheduleAdvice={recommended:[]}}}
async function loadDoublesHub(){
 if(doublesHubLoading)return;
 doublesHubLoading=true;
 try{
  const [r,j,t]=await Promise.all([
    get('/api/rankings?kind=doubles&offset=0&limit=200'),
    get('/api/rankings?kind=junior_doubles&offset=0&limit=200'),
    get('/api/doubles-race')
  ]);
  doublesHubRows=r.rows||[];
  juniorDoublesHubRows=j.rows||[];
  doublesRaceRows=(t.rows||[]).map(x=>({
    ...x,
    rank:x.doubles_race_ranking??x.rank,
    points:x.doubles_race_points??x.points,
    snapshot_date:x.doubles_race_snapshot_date??x.snapshot_date
  }));
 }catch(e){console.warn('Double hub',e)}
 finally{doublesHubLoading=false;if(route==='doubles')render()}
}

function career(){
 const c={...(boot?.career||{}),...(local.career||{})};
 c.singles_rank=c.singles_rank??742;c.doubles_rank=c.doubles_rank??1284;c.points=c.points??34;c.player_name=c.player_name||'Anthony';c.country=c.country||'FRA';
 return c;
}
function home(){
 const c=career(),doublesOnly=String(c.career_focus||'mixed')==='doubles_only';
 const next=doublesOnly
  ?((scheduleAdvice?.recommended||[]).find(t=>t.doubles)||boot.upcoming?.find(t=>t.doubles)||boot.upcoming?.[0])
  :boot.upcoming?.[0];
 const academy=boot.academy||{},fin=boot.finance||{};
 const msgs=[...(local.feed||[]),...(boot.news||[]).map(x=>x.body)].slice(0,6);
 const quickActions=doublesOnly
  ?[['calendar','Calendrier double','Inscrire la paire'],['competitions','Compétitions','Palmarès & records'],['training','Entraînement','Plan double de la semaine'],['doubles','Hub Double','Partenaire, Race & tournois'],['scouting','Scouting','Chercher des talents'],['contracts','Contrats','Staff & joueurs'],['medical','Médical','Fatigue & blessures'],['davis','Fédération','Coupe Davis'],['world','Monde','Base mondiale & circuits'],['season','Saison','Bilan & points 52 semaines'],['myplayer','Mon joueur','Orientation & progression']]
  :[['calendar','Calendrier','Inscrire le joueur'],['competitions','Compétitions','Palmarès & records'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Chercher des talents'],['match','Match Center','Analyser les matchs'],['tactics','Tactique','Plan de match'],['contracts','Contrats','Staff & joueurs'],['medical','Médical','Fatigue & blessures'],['davis','Fédération','Coupe Davis'],['world','Monde','Base mondiale & circuits'],['season','Saison','Bilan & points 52 semaines']];
 return `<div class="section-head"><div><div class="eyebrow">Carrière · semaine ${local.week}</div><h1>Centre de management</h1><div class="muted">Le monde avance même quand tu ne joues pas.</div></div><span class="pill">ATP · classement réf. ${df(RANKING_SNAPSHOT)}</span></div>
 <section class="hero">
  <div class="card click" onclick="nav('myplayer')">
   <div class="row between"><div><div class="eyebrow">Joueur géré</div><div class="hero-name">${flags[c.country]||'🏳️'} ${esc(c.player_name)}</div><div class="muted">ATP #${fmt(c.singles_rank)} · Double ${careerDoublesRankText(c)} · ${careerFocusLabel(c.career_focus||'mixed')}</div><div class="row" style="margin-top:6px;gap:6px;flex-wrap:wrap"><span class="badge ${doublesOnly?'good':''}">${doublesOnly?'Circuit principal · Double':'Objectif · '+careerFocusLabel(c.career_focus||'mixed')}</span>${doublesOnly?'<span class="badge">Points simple en extinction naturelle</span>':''}</div></div><div class="progress-ring" style="--p:${c.form||72}"><b>${c.form||72}</b></div></div>
   <div class="kpi-strip" style="margin-top:14px">
    ${[['Forme',c.form||72],['Fitness',c.fitness||91],['Moral',c.morale||78],['Fatigue',c.fatigue||18]].map(x=>`<div class="kpi"><span class="muted mini">${x[0]}</span><b>${x[1]}</b><div class="bar"><i style="width:${x[1]}%"></i></div></div>`).join('')}
   </div>
  </div>
  <div class="card click" onclick="nav('finance')"><div class="eyebrow">Académie</div><h2>${esc(academy.name||'Court Boss Academy')}</h2><div class="statline"><div class="statbox"><span class="muted mini">Budget</span><b>${euro(c.budget??academy.budget??14800)}</b></div><div class="statbox"><span class="muted mini">Board</span><b>${academy.board_confidence||76}%</b></div></div><p class="muted mini" style="margin-top:10px">${esc(academy.philosophy||'Développement complet du joueur')}</p></div>
 </section>
 <div class="quick-grid" style="margin-top:12px">
  ${quickActions.map(x=>`<div class="quick" onclick="nav('${x[0]}')"><span class="muted mini">${x[1]}</span><strong>${x[2]}</strong></div>`).join('')}
 </div>
 <section class="grid g2" style="margin-top:12px">
  <div class="card click" onclick="openTournament(${next?.id||0})"><div class="eyebrow">Prochain événement</div>${next?`<h2>${esc(next.name)}</h2><div class="row"><span class="badge ${circuitClass(next.circuit)}">${esc(next.category||next.level)}</span><span class="badge ${surfaceClass(next.surface)}">${esc(surfaceLabel(next))}</span></div><p class="muted">${esc(next.city||'')} · ${df(next.start_date)}</p>`:'<div class="empty">Aucun événement</div>'}</div>
  <div class="card"><div class="row between"><h2>Fil manager</h2><button class="ghost" onclick="nav('inbox')">Tout voir</button></div>${msgs.map(m=>`<div class="news-item">${esc(m)}</div>`).join('')}</div>
 </section>
 <section class="grid g2" style="margin-top:12px">
  <div class="card"><div class="row between"><h2>Objectifs du board</h2><span class="pill">${academy.board_confidence||76}% confiance</span></div>${(boot.board||[]).map(o=>`<div class="list-item"><div class="row between"><b>${esc(o.objective)}</b><span class="mini muted">${o.progress}%</span></div><div class="bar"><i style="width:${o.progress}%"></i></div><div class="mini muted" style="margin-top:5px">${esc(o.target_value||'')} · ${df(o.deadline)}</div></div>`).join('')}</div>
  <div class="card"><div class="row between"><h2>Top mondial</h2><button class="ghost" onclick="nav('rankings')">Classement complet</button></div>${(boot.topPlayers||[]).slice(0,8).map(p=>`<div class="list-item row between click" onclick="openPlayer(${p.id})"><span><b>#${p.ranking}</b> ${flags[p.country]||'🏳️'} ${esc(p.name)}</span><b>${fmt(p.points)}</b></div>`).join('')}</div>
 </section>`
}
function rankings(){
 const kinds=[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['doubles_race','Race Double'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['junior_race','Race Junior'],['junior_doubles','Junior Double'],['junior_doubles_race','Race Junior Dbl'],['itf','ITF WTT'],['ncaa','NCAA / ITA']];
 if(rankKind==='ncaa')return ncaaRanking();
 const startRow=rankCount?rankOffset+1:0,endRow=Math.min(rankOffset+rankRows.length,rankCount);
 const first=rankRows[0]||{},snap=rankSnapshot(first,rankKind);
 const label=rankKind==='singles'?'ATP Ranking':rankKind==='doubles'?'ATP Doubles':rankKind==='doubles_race'?'ATP Doubles Race':rankKind==='junior_doubles'?'Court Boss Junior Doubles':rankKind==='junior_doubles_race'?'Junior Double Race':rankKind==='race'?'ATP Race':rankKind==='junior_race'?'ITF Junior Finals Race':rankKind==='nextgen'?'Next Gen Race U21':rankKind==='junior'?'ITF Juniors':'ITF World Tennis Tour';
 const reference=rankKind==='singles'
   ?'Classement monde Court Boss jusqu’au rang 30 000. Le rang ATP officiel reste identifié séparément quand il est disponible · snapshot '+df(snap||RANKING_SNAPSHOT)+'.'
   :rankKind==='doubles'
     ?'Classement ATP Double officiel Live-Tennis · Top 1000 au '+df(snap||RANKING_SNAPSHOT)+' · '+fmt(worldStats?.indexedDoubles||rankCount)+' profils indexés pour le scouting.'
     :rankKind==='doubles_race'
       ?'Race par équipes vers le Nitto ATP Finals · Top 8 qualifié · '+df(snap||RANKING_SNAPSHOT)
     :rankKind==='race'
       ?'ATP Race · base 01 déc. 2025 · '+df(snap||RANKING_SNAPSHOT)
     :rankKind==='junior_race'
       ?'Qualification ITF World Tennis Tour Junior Finals · Top 8 · points sur 12 mois · '+df(snap||RANKING_SNAPSHOT)
     :rankKind==='junior_doubles_race'
       ?'Course par paires vers le Court Boss Junior Doubles Finals · Top 8 · '+df(snap||RANKING_SNAPSHOT)
       :rankKind==='nextgen'
         ?'ATP Next Gen Race · base 01 déc. 2025 · '+df(snap||RANKING_SNAPSHOT)+' · âge au 01/12/2025'
       :rankKind==='junior'
         ?'ITF Juniors · snapshot '+df(snap||RANKING_SNAPSHOT)
       :rankKind==='junior_doubles'
         ?'Court Boss Junior Double · classement simulé séparé · snapshot '+df(snap||RANKING_SNAPSHOT)
         :'ITF World Tennis Tour · snapshot '+df(snap||RANKING_SNAPSHOT);
 const pill=rankKind==='ncaa'?(snap?df(snap):'NCAA'):df(snap||RANKING_SNAPSHOT);
 return `<div class="section-head"><div><div class="eyebrow">Base mondiale</div><h1>Classements</h1><div class="muted">Ranking, Race, Double et Next Gen sont séparés. Le classement ATP de départ correspond au snapshot officiel du 1er décembre 2025, puis la simulation de ta carrière fait évoluer ce monde.</div></div><span class="pill">${pill}</span></div>
 <div class="tabs rank-tabs">${kinds.map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}<button class="deep-db-tab" onclick="dbCircuit='Tous réels';dbOffset=0;dbLoaded=false;nav('players')">Monde ${fmt(worldStats?.worldRankingCapacity||30000)}</button></div>
 ${rankKind==='nextgen'? `<div class="age-filter"><span class="muted mini">Âge au 01/12/2025</span>${[18,19,20,21].map(a=>`<button class="${nextGenAge===a?'active':''}" onclick="setNextGenAge(${a})">U${a}</button>`).join('')}</div>`:''}
 ${rankKind==='junior'? `<div class="notice mini" style="margin-bottom:12px"><b>Vivier junior Court Boss</b> · <b>classement #1 à #2000 piloté par les points</b> · ${fmt(rankMeta?.officialRealCount||0)} vrais vérifiés + ${fmt(rankMeta?.generatedCount||0)} newgens. <div class="row" style="margin-top:8px;gap:6px;flex-wrap:wrap"><span class="badge">GC 1000</span><span class="badge">J500 500</span><span class="badge">J300 300</span><span class="badge">J200 200</span><span class="badge">J100 100</span><span class="badge">J60 60</span><span class="badge">J30 30</span></div></div>`:''} ${rankKind==='junior_doubles'? `<div class="notice mini" style="margin-bottom:12px"><b>Circuit Junior Double</b> · classement séparé #1 à #2000. <div class="row" style="margin-top:8px;gap:6px;flex-wrap:wrap"><span class="badge">GC 750</span><span class="badge">J500 375</span><span class="badge">J300 225</span><span class="badge">J200 150</span><span class="badge">J100 75</span><span class="badge">J60 45</span><span class="badge">J30 25</span></div></div>`:''} ${rankKind==='doubles_race'? `<div class="notice mini" style="margin-bottom:12px"><b>Race Double ATP</b> · <b>${fmt(rankCount)} paires classées</b> · Top ${rankMeta?.qualificationPlaces||8} → Nitto ATP Finals. Top publié conservé, puis classement estimé Court Boss pour les paires suivantes.</div>`:''}
 ${rankKind==='junior_race'? `<div class="notice mini" style="margin-bottom:12px"><b>Race Junior</b> · <b>${fmt(rankCount)} joueurs classés</b> · Top ${rankMeta?.qualificationPlaces||8} → ITF World Tennis Tour Junior Finals · #9 remplaçant · suite estimée quand la Race officielle n’est pas publiée. Vainqueur Finals : 1000 pts.</div>`:''}
 ${rankKind==='junior_doubles_race'? `<div class="notice mini" style="margin-bottom:12px"><b>Race Junior Double</b> · <b>${fmt(rankCount)} paires classées</b> · Top ${rankMeta?.qualificationPlaces||8} → Court Boss Junior Doubles Finals · #9 remplaçant. Classement de paires simulé/estimé au-delà des données disponibles.</div>`:''} ${rankKind==='singles'? `<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Classement carrière simulé</div><div class="hero-name" style="font-size:25px">ATP #${career().singles_rank}</div><div class="muted">${fmt(career().points)} points actifs · base initiale ${df(RANKING_SNAPSHOT)}</div></div><div style="text-align:right"><div class="muted mini">Prochaine expiration</div><b>${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?df(rankingLedger.active[0].expiry_date):'—'}</b><div class="muted mini">${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?'-'+rankingLedger.active[0].points+' pts':''}</div></div></div></div>`:''}
 <div class="card">
  <div class="rank-tools fm-rank-tools"><input class="input" value="${esc(rankQuery)}" placeholder="Rechercher dans les 30 000 joueurs…" onkeydown="if(event.key==='Enter')searchRanking(this.value)"><select class="select" onchange="setRankCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${rankCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select><div class="rank-jump"><input class="input" id="rankJump" type="number" min="1" max="${Math.max(rankCount,1)}" placeholder="Aller au rang"><button class="soft-btn" onclick="jumpRanking()">Aller</button></div></div>
  <div class="notice mini" style="margin-top:10px"><b>${label}</b> · ${reference}. Les valeurs de simulation restent séparées des snapshots historiques.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>${rankKind==='singles'?'# ATP / Monde':'#'}</th>${rankKind==='singles'?'<th>Meilleur carrière</th><th>+/−</th>':''}<th>${rankRows[0]?.is_team?'Paire':'Joueur'}</th><th>Âge 01/12/25</th><th>Pays</th><th>Pts</th><th>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?'Finals':rankKind==='nextgen'?'ATP':'Niv.'}</th><th>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?'Statut':rankKind==='nextgen'?'Statut':'Pot.'}</th></tr></thead><tbody>
  ${rankRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${rankCell(p,rankKind)}</td>${rankKind==='singles'?`<td>${(p.career_high_rank??p.best_rank_2025)?'#'+fmt(p.career_high_rank??p.best_rank_2025):'—'}</td><td>${p.ranking_change==null?'<span class="muted">—</span>':p.ranking_change>0?'<span class="rank-up">▲ '+p.ranking_change+'</span>':p.ranking_change<0?'<span class="rank-down">▼ '+Math.abs(p.ranking_change)+'</span>':'<span class="muted">=</span>'}</td>`:''}<td><b>${esc(p.name)}</b> ${p.game_generated?'<span class="badge">Newgen</span>':''}${rankKind==='junior'&&p.junior_rank_type==='official'?'<span class="badge good">ITF vérifié</span>':rankKind==='junior'&&p.junior_rank_type==='verified_nr'?'<span class="badge">ITF · NR</span>':''}${p.ncaa_current?'<span class="badge tag-ncaa">NCAA</span>':p.ncaa_status==='Alumni'?'<span class="badge tag-ncaa">NCAA Alumni</span>':''}${rankKind==='doubles'?(p.doubles_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Index DB</span>'):''}${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?(p.official_qualification?'<span class="badge good">Rang officiel · pts estimés</span>':/estimated|estimate|estimé/i.test(String(p.source||''))?'<span class="badge">Estimé</span>':/simulated|Court Boss/i.test(String(p.source||''))?'<span class="badge">Simulé</span>':'<span class="badge good">Officiel</span>'):''}<div class="muted micro">${rankKind==='singles'?(p.official_ranking?'ATP officiel #'+fmt(p.official_ranking):p.game_generated?'Joueur généré Court Boss':'Base historique / scouting'):rankKind==='junior'?(p.junior_rank_type==='official'?'Rang jeu #'+fmt(p.junior_ranking)+' · ITF source #'+fmt(p.junior_official_ranking)+(rankSnapshot(p,rankKind)?' · au '+df(rankSnapshot(p,rankKind)):''):p.junior_rank_type==='verified_nr'?'Rang jeu #'+fmt(p.junior_ranking)+' · ITF vérifié, rang estimé':'Rang jeu #'+fmt(p.junior_ranking)+' · Newgen simulé · 13–17 ans'):(rankSnapshot(p,rankKind)?'au '+df(rankSnapshot(p,rankKind)):'')}${p.ncaa_current&&p.ncaa_school?' · '+esc(p.ncaa_school):p.ncaa_status==='Alumni'&&p.ncaa_last_school?' · ex-'+esc(p.ncaa_last_school):''}</div></td><td>${rankAge(p,rankKind)}</td><td>${flags[p.country]||'🏳️'} ${esc(p.country)}</td><td><b>${rankPoints(p,rankKind)==null?'—':fmt(rankPoints(p,rankKind))}</b></td><td>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?'Top '+fmt(rankMeta?.qualificationPlaces||8):rankKind==='nextgen'?(p.ranking?'#'+fmt(p.ranking):'—'):(p.current_ability??'—')+'/100'}</td><td>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?(p.finals_status==='qualified'?'<span class="badge good">Qualifié</span>':p.finals_status==='alternate'?'<span class="badge warn">Remplaçant</span>':'<span class="badge">En course</span>'):rankKind==='nextgen'?(p.nextgen_status==='withdrawn'?'<span class="badge bad">Retiré</span>':p.nextgen_status==='alternate'?'<span class="badge warn">Remplaçant</span>':p.nextgen_status==='qualified'?'<span class="badge good">Qualifié</span>':p.potential+'/100'):(p.potential??'—')+'/100'}</td></tr>`).join('')}
  </tbody></table></div>
  <div class="pagination"><button ${rankOffset===0?'disabled':''} onclick="rankPage(-1)">←</button><span class="muted mini">lignes ${fmt(startRow)}–${fmt(endRow)} / ${fmt(rankCount)}</span><button ${rankOffset+100>=rankCount?'disabled':''} onclick="rankPage(1)">→</button></div>
 </div>`
}
window.jumpRanking=async()=>{
 const target=clamp(Number(document.getElementById('rankJump')?.value||1),1,Math.max(1,rankCount));
 rankQuery='';rankOffset=Math.max(0,Math.min(Math.max(0,rankCount-100),target-1));
 await loadRankings();render();
}
function ncaaRanking(){
 const rows=rankRows||[],startRow=rankCount?rankOffset+1:0,endRow=Math.min(rankOffset+rows.length,rankCount);
 const doubleRows=ncaaDoublesRows||[];
 const modeTabs=`<div class="tabs rank-tabs" style="margin:12px 0"><button class="${ncaaView==='singles'?'active':''}" onclick="setNcaaView('singles')">Simple · Top ${fmt(rankMeta?.officialCapacity||125)}</button><button class="${ncaaView==='doubles'?'active':''}" onclick="setNcaaView('doubles')">Double · Top ${fmt(ncaaDoublesMeta?.officialCapacity||90)}</button></div>`;
 const singlesTable=`
  <div class="notice mini" style="margin-top:10px"><b>NCAA / ITA + UTR au 01/12/2025</b> · ${fmt(rankMeta?.verifiedCurrentRanks||0)} rangs ITA vérifiés disponibles. L’UTR reste séparé : <b>~</b> = estimation Court Boss quand aucune valeur UTR sourcée n’est disponible.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th># ITA</th><th>Joueur</th><th>Âge 01/12/25</th><th>Université</th><th>Division</th><th>UTR</th><th>ATP</th><th>Statut</th></tr></thead><tbody>
   ${rows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${p.ncaa_rank?'#'+fmt(p.ncaa_rank):'—'}</td><td><b>${esc(p.name)}</b><div class="muted micro">${flags[p.country]||'🏳️'} ${esc(p.country||'')}</div></td><td>${rankAge(p,'ncaa')}</td><td><b>${esc(p.ncaa_school||'—')}</b></td><td>${esc(p.ncaa_division||'NCAA')}</td><td>${p.utr_rating!=null?'<b>'+(p.utr_verified?'':'~')+Number(p.utr_rating).toFixed(2)+'</b><div class="muted micro">'+(p.utr_verified?'UTR vérifié':'UTR estimé Court Boss')+'</div>':'—'}</td><td>${p.ranking_current&&p.ranking?'#'+fmt(p.ranking):'—'}</td><td><span class="badge ${(p.ncaa_current||p.ncaa_current_verified)?'good':''}">${(p.ncaa_current||p.ncaa_current_verified)?'NCAA actif':p.ncaa_status==='Alumni'?'NCAA Alumni':esc(p.ncaa_status||'NCAA historique')}</span></td></tr>`).join('')}
  </tbody></table></div>
  ${rows.length?'' : '<div class="empty">Aucun profil NCAA pour ce filtre.</div>'}
  <div class="pagination"><button ${rankOffset===0?'disabled':''} onclick="rankPage(-1)">←</button><span class="muted mini">lignes ${fmt(startRow)}–${fmt(endRow)} / ${fmt(rankCount)}</span><button ${rankOffset+100>=rankCount?'disabled':''} onclick="rankPage(1)">→</button></div>`;
 const doublesTable=`
  <div class="notice mini" style="margin-top:10px"><b>NCAA Double au 01/12/2025</b> · ${fmt(ncaaDoublesMeta?.count||doubleRows.length)} paire(s) vérifiée(s) disponible(s) au cutoff.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>#</th><th>Paire</th><th>Université</th><th>Référence</th></tr></thead><tbody>
   ${doubleRows.map(x=>`<tr><td class="rank-num">#${fmt(x.ita_rank)}</td><td><b><span class="click" onclick="openPlayer(${x.player_one_id})">${esc(x.player_one_name)}</span> / <span class="click" onclick="openPlayer(${x.player_two_id})">${esc(x.player_two_name)}</span></b></td><td>${esc(x.school||'—')}</td><td><span class="badge good">ITA officiel</span></td></tr>`).join('')}
  </tbody></table></div>
  ${doubleRows.length?'' : '<div class="empty">Aucune paire NCAA pour ce filtre.</div>'}`;
 return `<div class="section-head"><div><div class="eyebrow">NCAA / ITA</div><h1>Joueurs universitaires</h1><div class="muted">Base NCAA figée au 01/12/2025 : rangs, rosters historiques, alumni et transferts disponibles avant le cutoff.</div></div><span class="pill">${fmt(rankCount)} profils NCAA</span></div>
 <div class="tabs rank-tabs">${[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['doubles_race','Race Double'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['junior_race','Race Junior'],['junior_doubles','Junior Double'],['junior_doubles_race','Race Junior Dbl'],['itf','ITF WTT'],['ncaa','NCAA / ITA']].map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}<button class="deep-db-tab" onclick="dbCircuit='Tous réels';dbOffset=0;dbLoaded=false;nav('players')">Monde ${fmt(worldStats?.worldRankingCapacity||30000)}</button></div>
 ${modeTabs}
 <div class="card">
  <div class="rank-tools fm-rank-tools"><input class="input" value="${esc(rankQuery)}" placeholder="${ncaaView==='doubles'?'Rechercher joueur ou université NCAA…':'Rechercher un joueur NCAA…'}" onkeydown="if(event.key==='Enter')searchRanking(this.value)">${ncaaView==='singles'? `<select class="select" onchange="setRankCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${rankCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.ncaa_players||0)} NCAA</option>`).join('')}</select><div class="rank-jump"><input class="input" id="rankJump" type="number" min="1" max="${Math.max(rankCount,1)}" placeholder="Aller au rang"><button class="soft-btn" onclick="jumpRanking()">Aller</button></div>`:''}</div>
  ${ncaaView==='doubles'?doublesTable:singlesTable}
 </div>`;
}
window.setNcaaView=async v=>{ncaaView=v==='doubles'?'doubles':'singles';rankOffset=0;render()}
window.setRankKind=async k=>{rankKind=k;rankOffset=0;rankQuery='';await loadRankings();render()}
window.setNextGenAge=async a=>{nextGenAge=clamp(Number(a)||21,18,21);rankOffset=0;rankQuery='';await loadRankings();render()}
window.searchRanking=async q=>{rankQuery=q.trim();rankOffset=0;await loadRankings();render()}
window.setRankCountry=async c=>{rankCountry=String(c||'').toUpperCase();rankOffset=0;await loadRankings();render()}
window.rankPage=async d=>{rankOffset=Math.max(0,rankOffset+d*100);await loadRankings();render();window.scrollTo(0,0)}
window.jumpRank=async()=>{const n=clamp(Number(document.getElementById('rankJump')?.value||1),1,Math.max(1,rankCount));rankOffset=Math.floor((n-1)/100)*100;await loadRankings();render();window.scrollTo(0,0)}

function calWeekStart(date){
 const d=new Date(String(date||"2025-12-01")+"T12:00:00"),day=(d.getDay()+6)%7;
 d.setDate(d.getDate()-day);return d.toISOString().slice(0,10);
}
function calWeekEnd(date){const d=new Date(calWeekStart(date)+"T12:00:00");d.setDate(d.getDate()+6);return d.toISOString().slice(0,10)}
function calGameWeek(date){return Math.floor((new Date(calWeekStart(date)+"T12:00:00")-new Date("2025-12-01T12:00:00"))/604800000)+1}
function calShortDate(date){return new Date(String(date)+"T12:00:00").toLocaleDateString("fr-FR",{day:"2-digit",month:"short"}).replace(".","")}
function activeDoublesPartner(){
 const m=(management?.partnerships||[]).map(x=>x.partner||x.player_b).find(p=>Number(p?.id)===Number(local.partnerId))
   ||(management?.partnerships||[]).map(x=>x.partner||x.player_b).find(Boolean);
 return m||doublesHubRows.find(p=>Number(p.id)===Number(local.partnerId))||null;
}
function tournamentStatus(t){
 const now=String(local.date||"2025-12-01"),start=String(t.start_date||""),end=String(t.end_date||t.start_date||""),deadline=String(t.singles_entry_deadline||t.deadline||"");
 if(end&&end<now)return {label:"Terminé",cls:""};
 if(start&&start<=now&&end>=now)return {label:"En cours",cls:"good"};
 if(deadline&&now>deadline&&now<start)return {label:"Inscriptions closes",cls:"bad"};
 if(deadline&&now<=deadline)return {label:"Inscriptions ouvertes",cls:"good"};
 return {label:"À venir",cls:"warn"};
}
function tmCuts(t){return {direct:Number(t.direct_cut??t.projected_direct_cut??0)||null,qual:Number(t.qual_cut??t.projected_qual_cut??0)||null,projected:t.direct_cut==null&&t.projected_direct_cut!=null}}
function singlesEligibility(t){
 const c=career(),rank=Number(c.singles_rank||99999),age=Number(c.age||99),cuts=tmCuts(t);
 if(String(c.career_focus||'mixed')==='doubles_only')return {label:"Double exclusivement",cls:"bad",can:false,phase:"career_focus"};
 if(String(t.circuit)==="Federation")return {label:"Sélection nationale",cls:"info",can:false};
 if(String(t.circuit)==="NCAA"){
  const mode=String(t.registration_mode||"");
  const label=mode==="ncaa_individual_selection"?"Qualifié NCAA/ITA"
    :mode==="conference_selection"?"Sélection conférence"
    :mode==="school_nomination"?"Nomination université / ITA"
    :mode==="school_selection"?"Roster / lineup université"
    :"Parcours NCAA/ITA";
  return {label,cls:"info",can:false};
 }
 if(String(t.circuit)==="Junior"){
  if(age>18)return {label:"Non éligible U18",cls:"bad",can:false};
  const jr=Number(c.junior_rank||c.junior_ranking||99999);
  if(cuts.direct&&jr<=cuts.direct)return {label:"Tableau direct junior",cls:"good",can:true};
  if(cuts.qual&&jr<=cuts.qual)return {label:"Qualifs junior",cls:"warn",can:true};
  return {label:"Alternate junior",cls:"",can:true};
 }
 if(String(t.circuit)==="ATP"&&rank>500)return {label:"WC / alternate seulement",cls:"bad",can:false};
 if(cuts.direct&&rank<=cuts.direct)return {label:"Tableau direct",cls:"good",can:true};
 if(cuts.qual&&rank<=cuts.qual)return {label:"Qualifications",cls:"warn",can:true};
 if(String(t.circuit)==="ITF")return {label:"Alternate / WTN",cls:"",can:true};
 return {label:"Alternate / hors cut",cls:"",can:true};
}
function doublesEligibility(t){
 const partner=activeDoublesPartner(),c=career(),myRank=Number(c.doubles_rank||99999),partnerRank=Number(partner?.doubles_ranking||99999);
 const now=String(local.date||"2025-12-01"),advance=String(t.doubles_entry_deadline||""),onsite=String(t.doubles_onsite_deadline||"");
 if(String(c.career_focus||'mixed')==='singles_only')return {label:"Simple exclusivement",cls:"bad",can:false,phase:"career_focus"};
 if(!t.doubles)return {label:"Pas de double",cls:"",can:false,phase:"none"};
 if(String(t.circuit)==="NCAA")return {label:"Via lineup NCAA",cls:"info",can:false,phase:"selection"};
 if(String(t.circuit)==="Federation")return {label:"Par sélection",cls:"info",can:false,phase:"selection"};
 if(!partner)return {label:"Partenaire requis",cls:"warn",can:false,phase:"partner"};
 if(onsite&&now>onsite)return {label:"Double clos",cls:"bad",can:false,phase:"closed"};
 const method=String(t.doubles_entry_method||"");
 if(method==="onsite_only")return {label:"Sign-in sur site"+(onsite?" · "+df(onsite):""),cls:"warn",can:true,phase:"onsite"};
 if(advance&&now>advance&&(!onsite||now<=onsite))return {label:"On-site sign-in"+(onsite?" · "+df(onsite):""),cls:"warn",can:true,phase:"onsite"};
 if(String(t.entry_rule_code)==="ITF_M25"&&(myRank>=99999||partnerRank>=99999))return {label:"Sur site uniquement"+(onsite?" · "+df(onsite):""),cls:"warn",can:true,phase:"onsite"};
 const combined=(myRank>=99999||partnerRank>=99999)?null:myRank+partnerRank;
 return {label:(method.includes("advance")?"Advance entry · ":"")+(combined?"rang combiné "+fmt(combined):"équipe enregistrable"),cls:"good",can:true,phase:"advance"};
}
const MAJOR_TOURNAMENT_LOGOS=[
 {re:/Australian Open/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Australian_Open_Logo_2017.svg",label:"AO",cls:"logo-ao"},
 {re:/Roland[ -]?Garros/i,url:"https://static.cdnlogo.com/logos/r/52/roland-garros.svg",label:"RG",cls:"logo-rg"},
 {re:/Wimbledon/i,url:"https://static.cdnlogo.com/logos/w/73/wimbledon.svg",label:"WIM",cls:"logo-wim"},
 {re:/(^|\\b)US Open\\b|(^|\\b)Us Open\\b/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Usopen-header-logo.svg",label:"USO",cls:"logo-uso"}
];
const CURATED_TOURNAMENT_LOGOS=[
 {re:/Millennium Estoril Open|Estoril Open/i,url:"https://assets.stickpng.com/images/635644eea54eeda751217031.png",label:"EST"},
 {re:/Mifel Tennis Open|Los Cabos/i,url:"https://assets.stickpng.com/images/63565dd1636d1187068bf55b.png",label:"LCB"},
 {re:/Winston-Salem Open/i,url:"https://assets.stickpng.com/images/626698e22c88722059d5870e.png",label:"WSO"},
 {re:/Plava Laguna Croatia Open Umag|Croatia Open|Umag/i,url:"https://assets.stickpng.com/images/62665b7d1e92f9aac65b5bca.png",label:"UMAG"},
 {re:/BNP Paribas Fortis European Open|European Open/i,url:"https://assets.stickpng.com/images/635659ed636d1187068beaf7.png",label:"EURO"},
 // Current identities for which a clean transparent current asset is not
 // reliably available: render a tournament-specific dark wordmark instead of
 // an inaccurate old logo or a generic ATP 250 tile.
 {re:/BOSS Open/i,url:null,label:"BOSS OPEN"},
 {re:/Lynk & Co Hangzhou Open|Hangzhou Open/i,url:null,label:"HANGZHOU"},
 {re:/Grand Prix Auvergne-Rhone-Alpes|Grand Prix Auvergne-Rhône-Alpes/i,url:null,label:"GP AURA"},
 {re:/Almaty Open/i,url:null,label:"ALMATY"},
 {re:/Bank of China Hong Kong Tennis Open|Hong Kong Tennis Open/i,url:"https://static.hkmenstennisopen.com/wp-content/themes/hkto_2023/template/frontend/images/overview/2025/boc_hkto_logo_long.svg",label:"HKG"},
 {re:/Open Occitanie|Open Sud de France/i,url:"https://trouverlogo.fr/logos/open-occitanie.svg",label:"OCC"},
 {re:/ABN AMRO Open|ABN Amro World Tennis Tournament/i,url:"https://assets.stickpng.com/images/62ba413db3914fd78a171683.png",label:"RTM"},
 {re:/Abierto Mexicano Telcel|Abierto Mexicano de Tenis|Acapulco/i,url:"https://assets.stickpng.com/images/6266539d1e92f9aac65b5b98.png",label:"ACA"},
 {re:/Fayez Sarofim|U\\.S\\. Men'?s Clay Court|Houston/i,url:"https://assets.stickpng.com/images/626696c52c88722059d58707.png",label:"HOU"},
 {re:/Grand Prix Hassan II/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Grand_Prix_Hassan_II_logo.png",label:"MAR"},
 {re:/Tiriac Open|Țiriac Open/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Tiriac_Open.png",label:"BUC"},
 {re:/BNP Paribas Open|Indian Wells/i,url:"https://assets.stickpng.com/images/626658031e92f9aac65b5bb3.png",label:"IW"},
 {re:/Nexo Dallas Open|Dallas Open/i,url:"https://assets.stickpng.com/images/62665b9e1e92f9aac65b5bcb.png",label:"DAL"},
 {re:/Delray Beach Open/i,url:"https://assets.stickpng.com/images/62665c261e92f9aac65b5bd0.png",label:"DBO"},
 {re:/Dubai Duty Free Tennis Championships|Dubai Tennis Championships/i,url:"https://assets.stickpng.com/images/62665ca61e92f9aac65b5bd4.png",label:"DUB"},
 {re:/Bci Seguros Chile Open|Chile Open/i,url:"https://assets.stickpng.com/images/6266595e1e92f9aac65b5bbb.png",label:"CHI"},
 {re:/Gonet Geneva Open|Geneva Open/i,url:"https://assets.stickpng.com/images/62665d641e92f9aac65b5bd9.png",label:"GVA"},
 {re:/Bitpanda Hamburg Open|Hamburg (?:European )?Open/i,url:"https://assets.stickpng.com/images/62665eb81e92f9aac65b5bdd.png",label:"HAM"},
 {re:/Libema Open|Libéma Open/i,url:"https://assets.stickpng.com/images/62668a2f2c88722059d586d2.png",label:"LIB"},
 {re:/Mallorca Championships/i,url:"https://assets.stickpng.com/images/62668bb32c88722059d586da.png",label:"MAL"},
 {re:/EFG Swiss Open Gstaad|Swiss Open Gstaad/i,url:"https://assets.stickpng.com/images/626693472c88722059d586fb.png",label:"GST"},
 {re:/Nordea Open|B[aå]stad/i,url:"https://assets.stickpng.com/images/62668e752c88722059d586e7.png",label:"NOR"},
 {re:/Qatar ExxonMobil Open|Qatar Open/i,url:"https://assets.stickpng.com/images/6266906e2c88722059d586ee.png",label:"DOH"},
 {re:/Rio Open/i,url:"https://assets.stickpng.com/images/626691042c88722059d586f1.png",label:"RIO"},
 {re:/National Bank Open|Canada Masters|Toronto Masters|Montreal Masters/i,url:"https://assets.stickpng.com/images/62668e322c88722059d586e5.png",label:"CAN"},
 {re:/Cincinnati Open|Western & Southern Open/i,url:"https://en.wikipedia.org/wiki/Special:Redirect/file/Cincinnati_Open_logo.svg",label:"CIN"},
 {re:/Mubadala Citi DC Open|Citi DC Open|Citi Open|Washington Open/i,url:"https://assets.stickpng.com/images/62665a531e92f9aac65b5bc2.png",label:"WAS"},
 {re:/Kinoshita Group Japan Open|Japan Open|Tokyo Open/i,url:"https://assets.stickpng.com/images/626688682c88722059d586c7.png",label:"TOK"},
 {re:/Rolex Shanghai Masters|Shanghai Masters/i,url:"https://assets.stickpng.com/images/626692962c88722059d586f6.png",label:"SHA"},
 {re:/Rolex Paris Masters|Paris Masters/i,url:"https://assets.stickpng.com/images/626691792c88722059d586f4.png",label:"PAR"},
 {re:/Chengdu Open/i,url:"https://assets.stickpng.com/images/6356d0b733e1449e66ee5a2e.png",label:"CHE"},
 {re:/BNP Paribas Nordic Open|Stockholm Open/i,url:"https://assets.stickpng.com/images/6356fa1633e1449e66ee9f4c.png",label:"STO"},
 {re:/Kitzb[uü]hel|Generali Open/i,url:"https://assets.stickpng.com/images/626688b02c88722059d586c9.png",label:"KIT"},
 {re:/Barcelona Open Banc Sabadell|Barcelona Open/i,url:"https://assets.stickpng.com/images/63566131636d1187068c0368.png",label:"BCN"},
 {re:/BMW Open/i,url:"https://assets.stickpng.com/images/626657a81e92f9aac65b5bb0.png",label:"MUN"},
 {re:/Davis Cup/i,url:"https://assets.stickpng.com/images/62665bd01e92f9aac65b5bcd.png",label:"DAVIS"}
];

function tournamentLogoMeta(t={}){
 const name=String(t.name||t.tournament_name||"");
 const explicit=String(t.logo_url||"").trim();
 const major=MAJOR_TOURNAMENT_LOGOS.find(x=>x.re.test(name));
 const curated=CURATED_TOURNAMENT_LOGOS.find(x=>x.re.test(name));
 const category=String(t.category||t.level||"").trim();
 const circuit=String(t.circuit||"").trim();
 if(major)return {url:major.url,label:major.label,cls:"logo-official "+(major.cls||"")};
 if(curated)return {url:curated.url,label:curated.label,cls:"logo-official logo-curated"};
 if(explicit)return {url:explicit,label:String(category||circuit||"TOUR"),cls:"logo-official"};
 if(/Grand Chelem|Grand Slam/i.test(category))return {url:null,label:"GRAND SLAM",sub:"GS",cls:"logo-gs"};
 if(/Masters 1000/i.test(category))return {url:null,label:"ATP 1000",sub:"M1000",cls:"logo-atp"};
 if(/ATP 500|^500$/i.test(category))return {url:null,label:"ATP 500",sub:"500",cls:"logo-atp"};
 if(/ATP 250|^250$/i.test(category))return {url:null,label:"ATP 250",sub:"250",cls:"logo-atp"};
 if(/ATP Finals|Finals/i.test(category)&&circuit==="ATP")return {url:null,label:"ATP FINALS",sub:"FINALS",cls:"logo-finals"};
 if(/Challenger/i.test(category)||circuit==="Challenger")return {url:null,label:"ATP CH",sub:category.replace(/Challenger\\s*/i,"")||"CH",cls:"logo-challenger"};
 if(/Junior Grand Slam/i.test(category))return {url:null,label:"JUNIOR GS",sub:"JGS",cls:"logo-junior"};
 if(/^J\\d+/i.test(category)||circuit==="Junior")return {url:null,label:"ITF JUNIOR",sub:category||"J",cls:"logo-junior"};
 if(/^M\\d+|^W\\d+/i.test(category)||circuit==="ITF")return {url:null,label:"ITF",sub:category||"WTT",cls:"logo-itf"};
 if(circuit==="NCAA")return {url:null,label:"NCAA",sub:"COLLEGE",cls:"logo-ncaa"};
 if(circuit==="Federation"||/Davis/i.test(name+category))return {url:null,label:"DAVIS CUP",sub:"TEAM",cls:"logo-davis"};
 return {url:null,label:circuit||category||"TENNIS",sub:category&&category!==circuit?category:"TOUR",cls:"logo-generic"};
}
function tournamentLogoHtml(t,extraClass=""){
 const m=tournamentLogoMeta(t);
 const fallback="<span class='tm-tour-logo-fallback "+esc(m.cls)+" "+esc(extraClass)+"'><b>"+esc(m.label)+"</b><small>"+esc(m.sub||"")+"</small></span>";
 if(!m.url)return fallback;
 return "<span class='tm-tour-logo-shell "+esc(m.cls)+" "+esc(extraClass)+"'><img class='tm-tour-logo' src='"+esc(m.url)+"' alt='Logo "+esc(t.name||t.tournament_name||m.label)+"' loading='lazy' onerror=\"this.style.display='none';this.parentElement.nextElementSibling.style.display='grid'\"></span>"+fallback.replace("class='tm-tour-logo-fallback","style='display:none' class='tm-tour-logo-fallback");
}
function tournamentLogoByName(name,level="",extraClass=""){
 return tournamentLogoHtml({name,tournament_name:name,category:level,level,circuit:/Challenger/i.test(level)?"Challenger":/^M\d+|^W\d+|ITF/i.test(level)?"ITF":""},extraClass);
}
function slamLogoHtml(keyOrName,extraClass=""){
 const names={AO:"Australian Open",RG:"Roland-Garros",WIM:"Wimbledon",USO:"US Open"};
 return tournamentLogoByName(names[keyOrName]||keyOrName,"Grand Chelem",extraClass);
}
window.tournamentLogoHtml=tournamentLogoHtml;
window.tournamentLogoByName=tournamentLogoByName;
window.slamLogoHtml=slamLogoHtml;
function tournamentThumb(t){return tournamentLogoHtml(t,"tm-list-logo")}
function tournamentTmRow(t){
 const st=tournamentStatus(t),se=singlesEligibility(t),de=doublesEligibility(t),joined=(local.entries||[]).includes(t.id),dJoined=(local.doublesEntries||[]).includes(t.id);
 const deadline=t.singles_entry_deadline||t.deadline;
 const raceFinals=/^(ATP Finals|Junior Finals|Junior Double Finals)$/i.test(String(t.category||''));
 const sBtn=raceFinals&&t.singles?"<button class='ghost tm-entry-btn' disabled>Race S</button>":se.can?"<button class='"+(joined?"danger-btn":"soft-btn")+" tm-entry-btn' onclick='event.stopPropagation();toggleSinglesEntry("+t.id+")'>"+(joined?"S ✓":"S +")+"</button>":"<button class='ghost tm-entry-btn' disabled>S —</button>";
 const dBtn=raceFinals&&t.doubles?"<button class='ghost tm-entry-btn' disabled>Race D</button>":de.can?"<button class='"+(dJoined?"danger-btn":"soft-btn")+" tm-entry-btn' onclick='event.stopPropagation();toggleDoublesEntry("+t.id+")'>"+(dJoined?"D ✓":"D +")+"</button>":"<button class='ghost tm-entry-btn' disabled>D —</button>";
 return "<tr class='click "+(joined||dJoined?"tm-entered":"")+"' onclick='openTournament("+t.id+")'>"+
  "<td>"+tournamentThumb(t)+"</td>"+
  "<td><b>"+(flags[t.country]||"🏳️")+" "+esc(t.name)+"</b><div class='muted micro'>"+esc(t.city||"")+" · "+df(t.start_date)+"–"+df(t.end_date||t.start_date)+" · <span class='badge "+circuitClass(t.circuit)+"'>"+esc(t.category||t.circuit)+"</span>"+(t.is_verified?" <span class='badge good'>Officiel</span>":" <span class='badge warn'>Fictif</span>")+"</div></td>"+
  "<td><span class='"+surfaceClass(surfaceLabel(t))+"'>"+esc(surfaceLabel(t))+"</span></td>"+
  "<td><b>S "+(t.singles_draw_size||t.draw_size||"—")+"</b><div class='muted micro'>D "+(t.doubles?(t.doubles_draw_size||"—"):"—")+" · Q "+(t.qualifying_draw_size||"—")+"</div></td>"+
  "<td><b>"+(t.winner_points!=null?fmt(t.winner_points):"—")+"</b></td>"+
  "<td><b>"+(t.prize_money!=null?euro(t.prize_money):"—")+"</b></td>"+
  "<td>"+(t.defending_champion_name?("<div class='tm-holder' "+(t.defending_champion_player_id?"onclick='event.stopPropagation();openPlayer("+t.defending_champion_player_id+")'":"")+"><span>🏆 "+esc(t.defending_champion_name)+"</span><small>"+esc(String(t.defending_champion_year||""))+"</small></div>"):(t.defending_champion_source&&/première édition/i.test(t.defending_champion_source)?"<span class='muted mini'>Première édition</span>":"<span class='muted'>—</span>"))+"</td>"+
  "<td><span class='badge "+st.cls+"'>"+st.label+"</span><div class='muted micro "+se.cls+"'>"+esc(se.label)+(t.cut_is_projection&&t.projected_direct_cut?" · cut proj.":"")+"</div><div class='muted micro'>"+esc(de.label)+"</div></td>"+
  "<td><b>"+(deadline?df(deadline):"—")+"</b><div class='muted micro'>"+(t.doubles_entry_deadline?"D adv "+df(t.doubles_entry_deadline):"")+(t.doubles_onsite_deadline?" · site "+df(t.doubles_onsite_deadline):"")+"</div></td>"+
  "<td><div class='tm-entry-actions'>"+sBtn+dBtn+"<button class='ghost tm-entry-btn' onclick='event.stopPropagation();openTournament("+t.id+")'>›</button></div></td>"+
 "</tr>";
}
function tmCalendarRows(){
 const focus=String(career().career_focus||'mixed');
 const doublesOnly=focus==='doubles_only',singlesOnly=focus==='singles_only';
 return (tourRows||[]).filter(t=>{
  const st=tournamentStatus(t),se=singlesEligibility(t),de=doublesEligibility(t),wk=calWeekStart(t.start_date);
  if(doublesOnly&&!t.doubles)return false;
  if(singlesOnly&&!t.singles)return false;
  if(tmCalFilters.week!=="Toutes"&&wk!==tmCalFilters.week)return false;
  if(tmCalFilters.country!=="Tous"&&String(t.country)!==tmCalFilters.country)return false;
  if(tmCalFilters.status!=="Tous"&&st.label!==tmCalFilters.status)return false;
  if(tmCalFilters.environment==="Indoor"&&!t.indoor)return false;
  if(tmCalFilters.environment==="Outdoor"&&t.indoor)return false;
  if(tmCalFilters.entry==="Simple"&&!t.singles)return false;
  if(tmCalFilters.entry==="Double"&&!t.doubles)return false;
  if(tmCalFilters.entry==="Simple + Double"&&!(t.singles&&t.doubles))return false;
  if(tmCalFilters.holder==="Avec tenant"&&!t.defending_champion_name)return false;
  if(tmCalFilters.holder==="Sans tenant"&&t.defending_champion_name)return false;
  if(tmCalFilters.eligibility==="Éligible simple"&&!se.can)return false;
  if(tmCalFilters.eligibility==="Éligible double"&&!de.can)return false;
  if(tmCalFilters.eligibility==="Tableau direct"&&!/Tableau direct/.test(se.label))return false;
  if(tmCalFilters.eligibility==="Qualifications"&&!/Qualif/.test(se.label))return false;
  if(tmCalFilters.eligibility==="Alternate / WC"&&!/Alternate|WC/.test(se.label))return false;
  if(tmCalFilters.eligibility==="Sélection"&&!/Sélection|université|NCAA/.test(se.label))return false;
  return true;
 });
}
function renderTournamentWeeks(){
 const groups={};tmCalendarRows().forEach(t=>{const k=calWeekStart(t.start_date);(groups[k]??=[]).push(t)});
 return Object.entries(groups).sort((a,b)=>a[0].localeCompare(b[0])).map(([week,rows])=>{
  const current=calWeekStart(local.date||"2025-12-01")===week;
  return "<section class='tm-week "+(current?"current":"")+"'><div class='tm-week-head'><div><span class='tm-week-num'>S"+calGameWeek(week)+"</span><b>"+calShortDate(week)+" → "+calShortDate(calWeekEnd(week))+"</b>"+(current?" <span class='badge good'>Semaine actuelle</span>":"")+"</div><span class='muted mini'>"+rows.length+" tournoi"+(rows.length>1?"s":"")+"</span></div><div class='table-wrap'><table class='table tm-calendar-table'><thead><tr><th></th><th>Pays / tournoi</th><th>Surface</th><th>Tableaux</th><th>Pts</th><th>Prize money</th><th>Tenant</th><th>Statut / accès</th><th>Deadline</th><th>Actions</th></tr></thead><tbody>"+rows.map(tournamentTmRow).join("")+"</tbody></table></div></section>";
 }).join("");
}
window.tmCalendarFilter=(k,v)=>{tmCalFilters[k]=v;render()}
window.resetTmCalendarFilters=()=>{const f=String(career().career_focus||'mixed');tmCalFilters={week:'Toutes',country:'Tous',status:'Tous',eligibility:'Tous',environment:'Tous',entry:f==='doubles_only'?'Double':f==='singles_only'?'Simple':'Tous',holder:'Tous'};render()}

function calendar(){
 const cats=['Toutes','Grand Chelem','Masters 1000','ATP 500','ATP 250','ATP Finals','Next Gen Finals','United Cup','Laver Cup','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','Junior Grand Slam','J500','J300','J200','J100','J60','J30','Junior Finals','Junior Davis Cup','ITA Kickoff Weekend','ITA National Team Indoor Championship','ITA All-American Championships','ITA Division I Regionals','ITA Sectional Championships','ITA Conference Masters','NCAA DI Team Championship','NCAA DI Individual Championship','NCAA','Junior','Davis Cup'];
 const circs=['Tous','ATP','Challenger','ITF','NCAA','Junior','Federation'];
 const surfaces=['Toutes','Dur extérieur','Dur intérieur','Terre','Gazon','Moquette'];
 const officialCount=worldStats?.verifiedTournaments||0;
 const coverage=`ATP ${fmt(worldStats?.officialATP||0)} · CH ${fmt(worldStats?.officialChallenger||0)} · ITF ${fmt(worldStats?.officialITF||0)} · Junior ${fmt(worldStats?.officialJunior||0)} · NCAA ${fmt(worldStats?.officialNCAA||0)} · Davis ${fmt(worldStats?.officialFederation||0)}`;
 const partner=activeDoublesPartner(),singleEntries=(local.entries||[]).length,doubleEntries=(local.doublesEntries||[]).length;
 return `<div class="fm-page-head tm-calendar-head"><div><div class="eyebrow">Tournament registration · calendrier TM</div><h1>Calendrier mondial</h1><div class="muted">Départ de la base : <b>01/12/2025</b>. Vrais événements 2025-26, semaine par semaine, avec simple, double, qualifs et règles d’accès séparés.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(tourCount)} tournois</div><div class="fm-head-badge subtle">${fmt(officialCount)} officiels</div><div class="fm-head-badge subtle">S ${singleEntries} · D ${doubleEntries}</div></div></div>
 <div class="tm-calendar-tabs"><button class="${tourFilters.circuit==='Tous'?'active':''}" onclick="tourFilter('circuit','Tous')">Tous</button><button class="${tourFilters.circuit==='ATP'?'active':''}" onclick="tourFilter('circuit','ATP')">ATP</button><button class="${tourFilters.circuit==='Challenger'?'active':''}" onclick="tourFilter('circuit','Challenger')">Challenger</button><button class="${tourFilters.circuit==='ITF'?'active':''}" onclick="tourFilter('circuit','ITF')">ITF</button><button class="${tourFilters.circuit==='Junior'?'active':''}" onclick="tourFilter('circuit','Junior')">Junior</button><button class="${tourFilters.circuit==='NCAA'?'active':''}" onclick="tourFilter('circuit','NCAA')">NCAA</button><button class="${tourFilters.circuit==='Federation'?'active':''}" onclick="tourFilter('circuit','Federation')">Davis Cup</button><button onclick="showMyEntries()">Mes inscriptions</button></div>
 <div class="card tm-registration-summary"><div><span>Joueur</span><b>${esc(career().player_name)}</b><small>ATP #${fmt(career().singles_rank)} · Double ${careerDoublesRankText(career())} · ${careerFocusLabel(career().career_focus||'mixed')}</small></div><div><span>Partenaire double</span><b>${String(career().career_focus||'mixed')==='singles_only'?'Désactivé':partner?esc(partner.name):'Aucun'}</b><small>${String(career().career_focus||'mixed')==='singles_only'?'Carrière 100 % simple':partner?'Double #'+fmt(partner.doubles_ranking||0):'Choisir dans le hub Double'}</small></div><div><span>Date carrière</span><b>${df(local.date||'2025-12-01')}</b><small>Semaine ${calGameWeek(local.date||'2025-12-01')}</small></div><div><span>Couverture</span><b>${coverage}</b><small>Officiels + fictifs Challenger/ITF · filtrables</small></div></div>
 <div class="filters fm-calendar-filters"><input class="input" placeholder="Rechercher un tournoi…" value="${esc(tourFilters.q)}" onchange="tourFilter('q',this.value)"><select class="select" onchange="tourFilter('circuit',this.value)">${circs.map(x=>`<option ${x===tourFilters.circuit?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('category',this.value)">${cats.map(x=>`<option ${x===tourFilters.category?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('surface',this.value)">${surfaces.map(x=>`<option ${x===tourFilters.surface?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('source',this.value)"><option value="Tous" ${tourFilters.source==='Tous'?'selected':''}>Tous</option><option value="Officiel" ${tourFilters.source==='Officiel'?'selected':''}>Officiels</option><option value="Fictif" ${tourFilters.source==='Fictif'?'selected':''}>Fictifs Challenger/ITF</option></select><input class="input" type="month" min="2025-12" value="${tourFilters.month}" onchange="tourFilter('month',this.value)"></div>
 <div class="surface-legend"><span class="surface-hard">● Dur extérieur</span><span class="surface-indoor">● Dur intérieur</span><span class="surface-clay">● Terre battue</span><span class="surface-grass">● Gazon</span><span class="muted mini">Cut “proj.” = estimation Court Boss, pas une acceptance list officielle.</span></div>
 <div class="card tm-advanced-filters">
  <div class="row between"><div><div class="eyebrow">Filtres TM</div><b>Affiner le calendrier</b></div><button class="ghost" onclick="resetTmCalendarFilters()">Réinitialiser</button></div>
  <div class="tm-filter-grid">
   <select class="select" onchange="tmCalendarFilter('week',this.value)"><option>Toutes</option>${[...new Set((tourRows||[]).map(t=>calWeekStart(t.start_date)))].sort().map(w=>`<option value="${w}" ${tmCalFilters.week===w?'selected':''}>S${calGameWeek(w)} · ${calShortDate(w)}–${calShortDate(calWeekEnd(w))}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('country',this.value)"><option>Tous</option>${[...new Set((tourRows||[]).map(t=>t.country).filter(Boolean))].sort().map(x=>`<option ${tmCalFilters.country===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('status',this.value)">${['Tous','Inscriptions ouvertes','Inscriptions closes','À venir','En cours','Terminé'].map(x=>`<option ${tmCalFilters.status===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('eligibility',this.value)">${['Tous','Éligible simple','Éligible double','Tableau direct','Qualifications','Alternate / WC','Sélection'].map(x=>`<option ${tmCalFilters.eligibility===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('environment',this.value)">${['Tous','Indoor','Outdoor'].map(x=>`<option ${tmCalFilters.environment===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('entry',this.value)">${['Tous','Simple','Double','Simple + Double'].map(x=>`<option ${tmCalFilters.entry===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('holder',this.value)">${['Tous','Avec tenant','Sans tenant'].map(x=>`<option ${tmCalFilters.holder===x?'selected':''}>${x}</option>`).join('')}</select>
  </div>
 </div>
 <details class="card tm-calendar-advice"><summary class="row between click"><div><div class="eyebrow">Conseiller calendrier</div><b>Recommandations pour ton joueur</b></div><span class="badge">ouvrir</span></summary><div class="grid g3" style="margin-top:10px">${(scheduleAdvice?.recommended||[]).slice(0,6).map(t=>`<div class="card click" onclick="openTournament(${t.id})"><div class="row between"><div class="row" style="align-items:center;gap:8px">${tournamentThumb(t)}<div><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span><h3 style="margin:6px 0 0">${esc(t.name)}</h3></div></div><b>${t.recommendation_score}/100</b></div><div class="muted mini" style="margin-top:6px">${esc(t.city||'')} · ${df(t.start_date)} · ${esc(surfaceLabel(t))}</div></div>`).join('')||'<div class="empty">Aucune recommandation.</div>'}</div></details>
 <div class="tm-calendar-rulebar"><span><b>ATP Tour</b> : simple 28 j · qualifs 21 j · double 14 j</span><span><b>Finals</b> : qualification automatique via Race</span><span><b>Challenger</b> : double 7 j + sign-in</span><span><b>M25</b> : advance + sur site</span><span><b>M15</b> : double sur site</span><span><b>NCAA</b> : roster/lineup, pas d’inscription libre</span></div>
 <div class="tm-calendar-weeks">${renderTournamentWeeks()||'<div class="card empty">Aucun tournoi daté pour ces filtres.</div>'}</div>
 ${tourTbc.length?`<div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Date à confirmer</div><h2>Événements officiels TBC</h2></div></div><div class="stack">${tourTbc.map(t=>`<div class="card"><div class="row between"><div><span class="badge good">Officiel · TBC</span><h2 style="margin:8px 0 4px">${esc(t.name)}</h2><div class="muted">${esc(t.city||'TBC')} · date à confirmer · <span class="surface-indoor">${esc(surfaceLabel(t))}</span></div></div><span class="badge">${esc(t.category||'ATP')}</span></div></div>`).join('')}</div>`:''}
 <div class="pagination"><button ${tourOffset===0?'disabled':''} onclick="tourPage(-1)">←</button><span class="muted mini">${tourCount?fmt(tourOffset+1):0}–${fmt(Math.min(tourOffset+tourRows.length,tourCount))} / ${fmt(tourCount)}</span><button ${tourOffset+150>=tourCount?'disabled':''} onclick="tourPage(1)">→</button></div>`
}
function tournamentCard(t){
 const c=career(),isJunior=String(t.circuit)==='Junior',isFederation=String(t.circuit)==='Federation',isNcaa=String(t.circuit)==='NCAA';
 const singlesElig=isFederation?'Par sélection nationale':isNcaa?'Championnat universitaire':isJunior?'Circuit Junior ITF':t.direct_cut==null?'Règles spéciales':c.singles_rank<=t.direct_cut?'Tableau direct':c.singles_rank<=t.qual_cut?'Qualifications':'Alternate / hors cut';
 const joined=(local.entries||[]).includes(t.id);
 const target=isFederation?"nav('davis')":isNcaa?"nav('university')":'openTournament('+t.id+')';
 const doublesOnly=String(c.career_focus||'mixed')==='doubles_only',dJoined=(local.doublesEntries||[]).includes(t.id),dRule=doublesEligibility(t);
 const elig=doublesOnly?dRule.label:singlesElig;
 const action=isFederation?'<button class="soft-btn" onclick="event.stopPropagation();nav(\'davis\')">Voir la Coupe Davis</button>':isNcaa?'<button class="soft-btn" onclick="event.stopPropagation();nav(\'university\')">Voir NCAA</button>':doublesOnly?(t.doubles&&dRule.can?`<button class="${dJoined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleDoublesEntry(${t.id})">${dJoined?'Double ✓ · retirer':'Inscrire la paire'}</button>`:'<button class="ghost" disabled>Double indisponible</button>'):`<button class="${joined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleEntry(${t.id})">${joined?'Inscrit · retirer':'S’inscrire'}</button>`;
 return `<div class="card click" onclick="${target}"><div class="row between" style="gap:12px"><div class="row" style="align-items:center;min-width:0">${tournamentThumb(t)}<div><div class="row"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span>${t.is_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Monde simulé</span>'}</div><h2 style="margin:8px 0 4px">${flags[t.country]||'🏳️'} ${esc(t.name)}</h2><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} · <span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span>${t.venue?' · '+esc(t.venue):''}</div></div></div><div style="text-align:right"><span class="badge ${elig==='Tableau direct'?'good':elig==='Qualifications'?'warn':''}">${elig}</span><div style="margin-top:8px">${action}</div></div></div></div>`
}
window.showMyEntries=()=>{
  const ids=new Set([...(local.entries||[]),...(local.doublesEntries||[])]);
  const known=[...(tourRows||[]),...(boot?.upcoming||[]),...(scheduleAdvice?.recommended||[])];
  const rows=[...new Map(known.filter(t=>ids.has(t.id)).map(t=>[t.id,t])).values()].sort((a,b)=>String(a.start_date).localeCompare(String(b.start_date)));
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Planning manager</div><h1>Mes inscriptions</h1><div class="muted">Simple et double sont suivis séparément.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>${rows.length?rows.map(t=>`<div class="list-item row between"><div><b>${esc(t.name)}</b><div class="muted mini">${df(t.start_date)} · ${esc(t.category||t.circuit)} · ${esc(surfaceLabel(t))}</div></div><div>${(local.entries||[]).includes(t.id)?'<span class="badge good">Simple</span>':''} ${(local.doublesEntries||[]).includes(t.id)?'<span class="badge good">Double</span>':''}</div></div>`).join(''):'<div class="empty">Aucune inscription active.</div>'}</div></div>`;
}
window.tourFilter=async(k,v)=>{tourFilters[k]=v;if(k==='circuit'&&v==='Junior'&&tourFilters.source==='Tous')tourFilters.source='Officiel';tourOffset=0;await loadTournaments();render()}
window.toggleFullCalendar=async()=>{tourShowPast=!tourShowPast;tourOffset=0;await loadTournaments();render()}
window.tourPage=async d=>{tourOffset=Math.max(0,tourOffset+d*150);await loadTournaments();render();window.scrollTo(0,0)}
function datesOverlap(aStart,aEnd,bStart,bEnd){
 const a1=new Date((aStart||aEnd)+'T12:00:00'),a2=new Date((aEnd||aStart)+'T12:00:00'),b1=new Date((bStart||bEnd)+'T12:00:00'),b2=new Date((bEnd||bStart)+'T12:00:00');
 return a1<=b2&&b1<=a2;
}

function findTournamentById(id){return [...(tourRows||[]),...(boot?.upcoming||[]),...(scheduleAdvice?.recommended||[])].find(x=>Number(x.id)===Number(id))}
window.toggleSinglesEntry=id=>{
 if(String(career().career_focus||'mixed')==='doubles_only'){alert('Mode Double exclusivement : les inscriptions simple sont désactivées.');return}
 local.entries=local.entries||[];local.entryMeta=local.entryMeta||{};
 const exists=local.entries.includes(id);
 if(exists){local.entries=local.entries.filter(x=>x!==id);delete local.entryMeta[id];persist();render();return}
 const t=findTournamentById(id);if(!t)return;
 const elig=singlesEligibility(t);if(!elig.can){alert(elig.label);return}
 const deadline=t.singles_entry_deadline||t.deadline;
 if(deadline&&String(local.date||"2025-12-01")>String(deadline)){alert("Deadline simple dépassée : "+df(deadline));return}
 const conflict=Object.entries(local.entryMeta).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(t.start_date,t.end_date,e.start_date,e.end_date));
 if(conflict){alert("Conflit calendrier avec "+conflict[1].name+" ("+df(conflict[1].start_date)+").");return}
 const dConflict=Object.entries(local.doublesEntryMeta||{}).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(t.start_date,t.end_date,e.start_date,e.end_date));
 if(dConflict){alert("Tu es déjà engagé en double à "+dConflict[1].name+" cette semaine.");return}
 local.entryMeta[id]={name:t.name,start_date:t.start_date,end_date:t.end_date,country:t.country,circuit:t.circuit,category:t.category,status:elig.label};
 local.entries.push(id);persist();render();
}
window.toggleDoublesEntry=id=>{
 if(String(career().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : les inscriptions double sont désactivées.');return}
 local.doublesEntries=local.doublesEntries||[];local.doublesEntryMeta=local.doublesEntryMeta||{};
 const exists=local.doublesEntries.includes(id);
 if(exists){local.doublesEntries=local.doublesEntries.filter(x=>x!==id);delete local.doublesEntryMeta[id];persist();render();return}
 const t=findTournamentById(id);if(!t)return;
 const elig=doublesEligibility(t);if(!elig.can){alert(elig.label);return}
 const onsite=t.doubles_onsite_deadline||t.start_date;
 if(onsite&&String(local.date||"2025-12-01")>String(onsite)){
   alert("Inscriptions double closes : dernier sign-in "+df(onsite)+".");
   return;
 }
 const sConflict=Object.entries(local.entryMeta||{}).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(t.start_date,t.end_date,e.start_date,e.end_date));
 if(sConflict){alert("Tu es déjà engagé en simple à "+sConflict[1].name+" cette semaine.");return}
 const dConflict=Object.entries(local.doublesEntryMeta).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(t.start_date,t.end_date,e.start_date,e.end_date));
 if(dConflict){alert("Conflit double avec "+dConflict[1].name+".");return}
 const partner=activeDoublesPartner();
 local.doublesEntryMeta[id]={name:t.name,start_date:t.start_date,end_date:t.end_date,country:t.country,circuit:t.circuit,category:t.category,partner_id:partner?.id,partner_name:partner?.name,status:elig.label};
 local.doublesEntries.push(id);persist();render();
}
window.toggleEntry=window.toggleSinglesEntry;

function academy(){
 const a=boot.academy||{},c=career();
 const roster=management?.academyRoster||[];
 const focuses=['Équilibré','Service','Retour','Fond de court','Déplacements','Physique','Mental','Double'];
 return `<div class="section-head"><div><div class="eyebrow">Structure</div><h1>${esc(a.name||'Court Boss Academy')}</h1><div class="muted">Réputation ${a.reputation||48}/100 · Board ${a.board_confidence||76}% · ${roster.length} joueur(s) sous contrat</div></div><button class="primary" onclick="nav('board')">Voir le board</button></div>
 <div class="kpi-strip"><div class="kpi click" onclick="nav('finance')"><span class="muted mini">Budget</span><b>${euro(c.budget??a.budget)}</b></div><div class="kpi click" onclick="nav('scouting')"><span class="muted mini">Scouting</span><b>Niv. ${a.scouting_network||2}</b></div><div class="kpi click" onclick="nav('medical')"><span class="muted mini">Médical</span><b>Niv. ${a.medical_level||1}</b></div><div class="kpi"><span class="muted mini">Marketing</span><b>Niv. ${a.marketing||1}</b></div></div>
 <div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Effectif</div><h2>Joueurs sous contrat</h2></div><button class="ghost" onclick="nav('scouting')">Recruter</button></div>
 <div class="stack">${roster.map(r=>{const p=r.players||{};return `<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">${esc(r.squad_role||'Académie')}</div><h2>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</h2><div class="muted mini">ATP #${fmt(p.ranking||2001)} · CA ${p.current_ability||'—'} · PA ${p.potential||'—'} · ${p.age||'—'} ans</div></div><span class="badge ${p.injury_status==='Fit'?'good':'bad'}">${esc(p.injury_status||'Fit')}</span></div>
 <div class="grid g3" style="margin-top:10px"><div class="kpi"><span class="muted mini">Contrat</span><b style="font-size:13px">${df(r.contract_end)}</b></div><div class="kpi"><span class="muted mini">Coût / sem.</span><b>${euro(r.weekly_cost)}</b></div><div class="kpi"><span class="muted mini">Forme</span><b>${p.form||'—'}</b></div></div>
 <div class="row" style="margin-top:10px;flex-wrap:wrap"><select class="select" style="width:auto" onchange="setAcademyFocus(${r.id},this.value)">${focuses.map(x=>`<option ${x===r.development_focus?'selected':''}>${x}</option>`).join('')}</select><button class="soft-btn" onclick="renewAcademyPlayer(${r.id})">Renouveler +1 an</button>${r.squad_role!=='Joueur principal'?`<button class="danger-btn" onclick="releaseAcademyPlayer(${r.id},'${esc(p.name||'Joueur')}')">Libérer</button>`:''}</div></div>`}).join('')||'<div class="card empty">Aucun joueur sous contrat.</div>'}</div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><div class="row between"><h2>Prospects académie</h2><button class="ghost" onclick="nav('scouting')">Scouting</button></div>${(boot.youth||[]).map(y=>`<div class="list-item row between click" onclick="openYouth(${y.id})"><div><b>${flags[y.country]||'🏳️'} ${esc(y.name)}</b><div class="muted mini">${y.age} ans · ${esc(y.style||'')}</div></div><div style="text-align:right"><b>PA ${y.potential}</b><div class="muted mini">CA ${y.current_ability}</div><span class="badge ${y.status==='signed'?'good':''}">${y.status==='signed'?'Signé':'Prospect'}</span></div></div>`).join('')}</div>
  <div class="card"><h2>Installations</h2>${(boot.facilities||[]).map(f=>`<div class="list-item row between"><span>${esc(f.name)}</span><div class="row"><b>Niveau ${facilityLevel(f)}/5</b><button class="soft-btn" onclick="upgradeFacility(${f.id},'${esc(f.name)}',${f.level})">Améliorer</button></div></div>`).join('')}</div>
 </div>
 <div class="card" style="margin-top:12px"><h2>Objectifs du board</h2>${(boot.board||[]).map(o=>`<div class="list-item"><div class="row between"><b>${esc(o.objective)}</b><span>${o.progress}%</span></div><div class="bar"><i style="width:${o.progress}%"></i></div></div>`).join('')}</div>`
}

window.setAcademyFocus=async(id,focus)=>{try{await managerAction('academy_focus',id,{focus});await loadManagement();render()}catch(e){alert(e.message)}}
window.renewAcademyPlayer=async id=>{try{await managerAction('renew_academy_player',id);await loadManagement();render()}catch(e){alert(e.message)}}
window.releaseAcademyPlayer=async(id,name)=>{if(!confirm('Libérer '+name+' de l’académie ?'))return;try{await managerAction('release_academy_player',id);await loadManagement();render()}catch(e){alert(e.message)}}
function training(){
 const sessions=['Service','Retour','Coup droit','Revers','Déplacements','Endurance','Match play','Double','Récupération','Repos'];
 return `<div class="section-head"><div><div class="eyebrow">Performance</div><h1>Entraînement hebdomadaire</h1><div class="muted">La charge influe sur progression, forme, fatigue et risque médical.</div></div></div>
 <div class="card"><div class="stack">${local.training.map((x,i)=>`<div class="list-item row between"><div><b>Jour ${i+1}</b><div class="muted mini">${i<5?'Séance principale':'Week-end'}</div></div><select class="select" style="width:auto" onchange="setTraining(${i},this.value)">${sessions.map(s=>`<option ${s===x?'selected':''}>${s}</option>`).join('')}</select></div>`).join('')}</div></div>
 <div class="grid g3" style="margin-top:12px"><div class="card"><h3>Charge actuelle</h3><div class="big">${trainingLoad()}</div><div class="muted">/ 14 conseillé</div></div><div class="card"><h3>Risque fatigue</h3><div class="big">${career().fatigue||18}%</div></div><div class="card"><h3>Staff performance</h3><div class="big">${Math.round((boot.staff||[]).reduce((a,x)=>a+x.skill,0)/Math.max(1,(boot.staff||[]).length))}/20</div></div></div>`
}
function trainingLoad(){return local.training.reduce((a,s)=>a+(['Endurance','Match play','Déplacements'].includes(s)?3:['Service','Retour','Coup droit','Revers','Double'].includes(s)?2:s==='Récupération'?0:-1),0)}
window.setTraining=(i,v)=>{local.training[i]=v;persist();render()}
function scouting(){
 const shortlist=management?.shortlist||[];
 const reports=boot.scoutingReports||[];
 const missions=['U23 potentiel','Top 300 immédiat','Serveurs puissants','Spécialistes terre battue','Double & volée','NCAA / université'];
 const ownScouts=(boot.staff||[]).filter(s=>Number(s.profile?.scouting_rating||0)>0).sort((a,b)=>Number(b.profile?.scouting_rating||0)-Number(a.profile?.scouting_rating||0));
 return `<div class="section-head"><div><div class="eyebrow">Recrutement</div><h1>Scouting</h1><div class="muted">Missions régionales, recruteurs réels de ton staff, précision des rapports et shortlist.</div></div><button class="primary" onclick="nav('players')">Chercher joueur</button></div>
 <div class="grid g3">${(boot.scouting||[]).map(s=>{const sp=s.staff||null;const missionReports=reports.filter(r=>Number(r.assignment_id)===Number(s.id));return `<div class="card">
  <div class="row between"><div><div class="eyebrow">${esc(s.region)}</div><h2>${esc(sp?.name||s.scout_name||'Réseau scouting')}</h2><div class="muted mini">Scouting ${sp?.scouting_rating??'—'}/20 · réputation ${sp?.reputation??'—'}/20</div></div><span class="badge ${s.status==='completed'?'good':Number(s.progress)>=75?'warn':''}">${esc(s.status)}</span></div>
  <div class="list-item"><span class="muted mini">Mission</span><select class="select" onchange="changeScoutAssignment(${s.id},this.value,document.getElementById('scoutStaff_${s.id}')?.value)">${missions.map(m=>`<option ${m===s.focus?'selected':''}>${m}</option>`).join('')}</select></div>
  <div class="list-item"><span class="muted mini">Recruteur affecté</span><select id="scoutStaff_${s.id}" class="select" onchange="changeScoutAssignment(${s.id},document.querySelector('[data-scout-focus=\'${s.id}\']')?.value||'${esc(s.focus)}',this.value)">${ownScouts.map(x=>`<option value="${x.profile?.id||''}" ${Number(x.profile?.id)===Number(s.staff_profile_id)?'selected':''}>${esc(x.profile?.name||x.name||x.role)} · ${x.profile?.scouting_rating||0}/20</option>`).join('')}</select></div>
  <input data-scout-focus="${s.id}" type="hidden" value="${esc(s.focus||'')}">
  <div class="bar" style="margin-top:12px"><i style="width:${s.progress}%"></i></div>
  <div class="row between mini muted" style="margin-top:5px"><span>${s.progress}% · confiance ${s.confidence??50}%</span><span>${s.eta_date?'ETA '+df(s.eta_date):''}</span></div>
  <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge">Qualité ${s.report_quality??50}/100</span>${sp?.burnout>=60?`<span class="badge bad">Scout fatigué ${sp.burnout}/100</span>`:''}${missionReports.length?`<span class="badge good">${missionReports.length} rapport(s)</span>`:''}</div>
 </div>`}).join('')}</div>
 ${reports.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Rapports terminés</div><h2>Joueurs détectés</h2><div class="muted">Les fourchettes CA/PA dépendent du niveau du recruteur. Elles ne révèlent pas la valeur réelle exacte.</div></div><span class="pill">${reports.length} rapports</span></div>
 <div class="grid g2">${reports.slice(0,24).map(r=>{const p=r.player||{};return `<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><div><div class="eyebrow">${esc(r.recommendation||'Rapport')}</div><h2>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</h2><div class="muted mini">ATP/Monde #${fmt(p.game_world_rank||p.ranking||0)} · ${p.age??'—'} ans · ${esc(r.archetype_read||r.style_read||p.style||'')}</div></div><span class="badge ${Number(r.confidence)>=80?'good':Number(r.confidence)>=65?'warn':''}">${r.confidence}%</span></div><div class="kpi-strip" style="margin-top:9px"><div class="kpi"><span class="muted micro">Niveau</span><b>${starRatingHtml(r.estimated_current_stars??abilityStarValue((Number(r.estimated_ca_min)+Number(r.estimated_ca_max))/2))}</b><small class="muted micro">${r.estimated_ca_min}–${r.estimated_ca_max}</small></div><div class="kpi"><span class="muted micro">Potentiel</span><b>${starRatingHtml(r.estimated_potential_stars??abilityStarValue((Number(r.estimated_pa_min)+Number(r.estimated_pa_max))/2))}</b><small class="muted micro">${r.estimated_potential_star_min??'?'}–${r.estimated_potential_star_max??'?'} ★</small></div></div><div class="row" style="gap:5px;flex-wrap:wrap;margin-top:8px"><span class="badge">${esc(r.personality_read||'Personnalité ?')}</span><span class="badge">${esc(r.development_type_read||'Courbe ?')}</span><span class="badge">${esc(r.injury_risk_read||'Risque ?')}</span>${(r.strengths||[]).slice(0,4).map(x=>`<span class="badge good">${esc(x)}</span>`).join('')}${(r.weaknesses||[]).slice(0,3).map(x=>`<span class="badge bad">${esc(x)}</span>`).join('')}</div><div class="muted micro" style="margin-top:7px">${esc(r.trajectory_read||'')}</div></div>`}).join('')}</div>`:''}
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Shortlist</h2>${shortlist.length?shortlist.map(s=>`<div class="list-item row between click" onclick="openPlayer(${s.players?.id})"><div><b>${flags[s.players?.country]||'🏳️'} ${esc(s.players?.name||'Joueur')}</b><div class="muted mini">ATP #${s.players?.ranking||'—'} · potentiel ${(()=>{const r=reports.find(x=>Number(x.player_id)===Number(s.players?.id));return r?starRatingHtml(Number(r.estimated_potential_stars||0)):'? ★'})()}</div></div><span class="badge">${esc(s.priority||'Normal')}</span></div>`).join(''):'<div class="empty">Aucun joueur suivi. Ajoute-en depuis un profil.</div>'}</div>
  <div class="card"><h2>Prospects académie</h2><div class="table-wrap"><table class="table"><thead><tr><th>Joueur</th><th>Âge</th><th>PA</th></tr></thead><tbody>${(boot.youth||[]).map(y=>`<tr class="click" onclick="openYouth(${y.id})"><td><b>${esc(y.name)}</b></td><td>${y.age}</td><td class="a-good"><b>${y.potential}</b></td></tr>`).join('')}</tbody></table></div></div>
 </div>`
}
window.changeScoutAssignment=async(id,focus,scoutProfileId)=>{try{await managerAction('set_scouting_assignment',id,{focus,scout_profile_id:Number(scoutProfileId||0)||null});boot=await get('/api/bootstrap');render()}catch(e){alert(e.message)}}

function competitionPrestige(p){
 const n=Number(p||50);return Math.max(1,Math.min(5,Math.round(n/20)));
}
function competitionsPage(){
 const circuits=['Tous','ATP','Challenger','ITF','Junior','NCAA','Federation'];
 const cats=['Toutes','Grand Chelem','ATP Finals','Masters 1000','ATP 500','ATP 250','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','Junior Grand Slam','NCAA DI Team Championship','NCAA DI Individual Championship'];
 const surfaces=['Toutes','Dur extérieur','Dur intérieur','Terre','Gazon'];
 const start=competitionCount?competitionOffset+1:0,end=Math.min(competitionOffset+competitionRows.length,competitionCount);
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Competition database · FM style</div><h1>Compétitions</h1><div class="muted">Une fiche permanente par tournoi : prestige, tenant du titre, éditions, palmarès annuel, finalistes et records. Le Calendrier reste dédié aux inscriptions.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(competitionCount)} compétitions</div><div class="fm-head-badge subtle">Open Era</div><button class="soft-btn" onclick="nav('calendar')">Calendrier →</button></div></div>
  <div class="card fm-db-toolbar">
   <div class="fm-db-filters">
    <input class="input" value="${esc(competitionFilters.q)}" placeholder="Rechercher une compétition…" onkeydown="if(event.key==='Enter')setCompetitionFilter('q',this.value)">
    <select class="select" onchange="setCompetitionFilter('circuit',this.value)">${circuits.map(x=>`<option ${x===competitionFilters.circuit?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('category',this.value)">${cats.map(x=>`<option ${x===competitionFilters.category?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('surface',this.value)">${surfaces.map(x=>`<option ${x===competitionFilters.surface?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('country',this.value)"><option value="">Tous pays</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${competitionFilters.country===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('prestige',this.value)">${['Tous','5 étoiles','4+ étoiles','3+ étoiles'].map(x=>`<option ${x===competitionFilters.prestige?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('history',this.value)">${['Tous','Avec historique','Sans historique'].map(x=>`<option ${x===competitionFilters.history?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('holder',this.value)">${['Tous','Avec tenant','Sans tenant'].map(x=>`<option ${x===competitionFilters.holder?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('source',this.value)">${['Tous','Officiel','Fictif'].map(x=>`<option ${x===competitionFilters.source?'selected':''}>${x}</option>`).join('')}</select>
    <button class="primary" onclick="loadCompetitions().then(render)">Filtrer</button>
   </div>
  </div>
  <div class="card fm-panel" style="margin-top:12px">
   <div class="row between"><div><div class="eyebrow">Base compétitions</div><h2>${competitionFilters.circuit==='Tous'?'Toutes les compétitions':esc(competitionFilters.circuit)}</h2></div><span class="pill">${fmt(competitionCount)}</span></div>
   ${competitionLoading?'<div class="loader">Chargement des compétitions…</div>':`<div class="table-wrap"><table class="table fm-competition-table"><thead><tr><th></th><th>Compétition</th><th>Niveau</th><th>Surface</th><th>Prestige</th><th>Tenant</th><th>Historique</th><th>Prochaine édition</th></tr></thead><tbody>${competitionRows.map(t=>`<tr class="click" onclick="openCompetition(${t.id})"><td>${tournamentThumb(t)}</td><td><b>${flags[t.country]||'🏳️'} ${esc(t.name)}</b><div class="muted micro">${esc(t.city||'')} · ${t.is_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Fictif</span>'}</div></td><td><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.circuit)}</span></td><td><span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span></td><td><b class="competition-stars">${'★'.repeat(competitionPrestige(t.prestige))}${'☆'.repeat(5-competitionPrestige(t.prestige))}</b><div class="muted micro">${fmt(t.prestige||50)}/100</div></td><td>${t.defending_champion_name?`<b>${esc(t.defending_champion_name)}</b><div class="muted micro">${t.defending_champion_year||2025}</div>`:'<span class="muted">Aucun tenant connu</span>'}</td><td><b>${fmt(t.history_count||0)} finale(s)</b><div class="muted micro">${t.latest_history?'Dernier : '+esc(t.latest_history.winner_name):'À enrichir'}</div></td><td><b>${df(t.start_date)}</b><div class="muted micro">${esc(t.country||'')}</div></td></tr>`).join('')}</tbody></table></div>`}
   ${!competitionLoading&&!competitionRows.length?'<div class="empty">Aucune compétition avec ces filtres.</div>':''}
   <div class="pagination"><button ${competitionOffset===0?'disabled':''} onclick="competitionPage(-1)">←</button><span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(competitionCount)}</span><button ${competitionOffset+100>=competitionCount?'disabled':''} onclick="competitionPage(1)">→</button></div>
  </div>
 </div>`;
}
window.setCompetitionFilter=async(k,v)=>{competitionFilters[k]=v;competitionOffset=0;await loadCompetitions();render()}
window.competitionPage=async d=>{competitionOffset=Math.max(0,competitionOffset+d*100);await loadCompetitions();render();window.scrollTo(0,0)}
window.openCompetition=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement de la compétition…</div></div></div>';
 try{
  const d=await get('/api/competition?id='+id),t=d.tournament,h=d.history||[],records=d.records||[];
  const image=t.image_url||API+'/api/tournament-image?id='+t.id;
  const photoLabel=t.image_source_label||'Photo du tournoi';
  const holder=t.defending_champion_name||h[0]?.winner_name||null;
  const holderId=t.defending_champion_player_id||h[0]?.winner_player_id||null;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet competition-sheet">
   <div class="sheet-head"><div class="tm-title-with-logo">${tournamentLogoHtml(t,'tm-detail-logo')}<div><div class="eyebrow">Fiche compétition · ${esc(t.circuit||'Tour')}</div><h1>${flags[t.country]||'🏳️'} ${esc(t.name)}</h1><div class="muted">${esc(t.city||'')} · ${esc(t.category||'')} · ${esc(surfaceLabel(t))}</div></div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="competition-hero" style="margin-top:12px"><div class="competition-cover"><img src="${esc(image)}" alt="${esc(t.name)}" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'"><div class="tm-tour-fallback competition-fallback" style="display:none">${flags[t.country]||'🎾'}<small>${esc(t.city||'')}</small></div><span class="tm-photo-label">${esc(photoLabel)}</span></div><div class="competition-main"><div class="row between"><div><div class="eyebrow">Prestige</div><div class="competition-stars big-stars">${'★'.repeat(competitionPrestige(t.prestige))}${'☆'.repeat(5-competitionPrestige(t.prestige))}</div></div><span class="badge ${t.is_verified?'good':''}">${t.is_verified?'Compétition officielle':'Compétition fictive'}</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Tenant</span><b class="${holderId?'click':''}" ${holderId?`onclick="openPlayer(${holderId})"`:''}>${holder?esc(holder):'—'}</b></div><div class="kpi"><span class="muted mini">Points vainqueur</span><b>${t.winner_points!=null?fmt(t.winner_points):'—'}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${t.prize_money!=null?euro(t.prize_money):'—'}</b></div><div class="kpi"><span class="muted mini">Historique</span><b>${d.historyStart&&d.historyEnd?d.historyStart+'–'+d.historyEnd:'—'}</b></div></div></div></div>
   <div class="tabs" style="margin-top:12px"><button class="active" data-comp-tab="overview" onclick="competitionSection('overview')">Vue d'ensemble</button><button data-comp-tab="history" onclick="competitionSection('history')">Palmarès</button><button data-comp-tab="records" onclick="competitionSection('records')">Records</button><button data-comp-tab="editions" onclick="competitionSection('editions')">Éditions</button></div>
   <div id="competitionBody">
    <section data-comp-section="overview"><div class="grid g2"><div class="card"><h2>Identité</h2><div class="list-item row between"><span>Niveau</span><b>${esc(t.category||t.level||'—')}</b></div><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Lieu</span><b>${esc(t.city||'—')}, ${esc(t.country||'')}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.singles_draw_size||t.draw_size||'—'}</b></div><div class="list-item row between"><span>Double</span><b>${t.doubles?t.doubles_draw_size||'Oui':'Non'}</b></div></div><div class="card"><h2>Édition ${String(t.start_date||'').slice(0,4)}</h2><div class="list-item row between"><span>Dates</span><b>${df(t.start_date)} → ${df(t.end_date||t.start_date)}</b></div><div class="list-item row between"><span>Tenant simple</span><b>${holder?esc(holder):'—'}</b></div><div class="list-item row between"><span>Tenant double</span><b>${t.defending_doubles_champion_name?esc(t.defending_doubles_champion_name)+(t.defending_doubles_partner_name?' / '+esc(t.defending_doubles_partner_name):''):'—'}</b></div><div class="list-item row between"><span>Source</span><b>${t.source_url?'<a href="'+esc(t.source_url)+'" target="_blank" rel="noopener">Officielle ↗</a>':'Simulation Court Boss'}</b></div></div></div></section>
    <section data-comp-section="history" style="display:none"><div class="card"><div class="row between"><div><div class="eyebrow">Finales</div><h2>Palmarès année par année</h2></div><span class="pill">${h.length} éditions</span></div>${h.length?`<div class="table-wrap"><table class="table"><thead><tr><th>Année</th><th>Vainqueur</th><th>Finaliste</th><th>Score</th><th>Surface</th></tr></thead><tbody>${h.map(x=>`<tr><td class="rank-num">${x.season}</td><td class="${x.winner_player_id?'click':''}" ${x.winner_player_id?`onclick="openPlayer(${x.winner_player_id})"`:''}><b>${flags[x.winner_country]||''} ${esc(x.winner_name)}</b></td><td class="${x.runner_up_player_id?'click':''}" ${x.runner_up_player_id?`onclick="openPlayer(${x.runner_up_player_id})"`:''}>${flags[x.runner_up_country]||''} ${esc(x.runner_up_name)}</td><td>${esc(x.score||'—')}</td><td>${esc(x.surface||'—')}</td></tr>`).join('')}</tbody></table></div>`:'<div class="empty">Historique en cours d’import.</div>'}</div></section>
    <section data-comp-section="records" style="display:none"><div class="card"><div class="row between"><div><div class="eyebrow">Open Era</div><h2>Records de la compétition</h2></div><span class="badge">${records.length} joueurs</span></div><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Titres</th><th>Finales</th></tr></thead><tbody>${records.map((r,i)=>`<tr class="${r.player_id?'click':''}" ${r.player_id?`onclick="openPlayer(${r.player_id})"`:''}><td class="rank-num">${i+1}</td><td><b>${esc(r.name)}</b></td><td><b>${r.wins}</b></td><td>${r.finals}</td></tr>`).join('')}</tbody></table></div></div></section>
    <section data-comp-section="editions" style="display:none"><div class="card"><h2>Éditions Court Boss</h2>${(d.editions||[]).map(x=>`<div class="list-item row between click" onclick="openCompetition(${x.id})"><div><b>${String(x.start_date||'').slice(0,4)} · ${esc(x.name)}</b><div class="muted mini">${df(x.start_date)} · ${esc(x.city||'')} · ${esc(surfaceLabel(x))}</div></div><span class="badge ${x.is_verified?'good':''}">${x.is_verified?'Officiel':'Fictif'}</span></div>`).join('')||'<div class="empty">Une seule édition référencée.</div>'}</div></section>
   </div>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="card"><h2>Compétition indisponible</h2><p class="muted">${esc(e.message)}</p></div></div></div>`}
}
window.competitionSection=name=>{document.querySelectorAll('[data-comp-section]').forEach(x=>x.style.display=x.getAttribute('data-comp-section')===name?'block':'none');document.querySelectorAll('[data-comp-tab]').forEach(x=>x.classList.toggle('active',x.getAttribute('data-comp-tab')===name))}
function more(){
 const items=[['players','Base joueurs',fmt(worldStats?.searchableRealPlayers||22000)+' profils réels · classement monde jusqu’au #30000 + ITF + Juniors + NCAA + Double'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Réseau et prospects'],['staff','Staff','Coach, fitness, physio, agent'],['contracts','Contrats','Salaires et échéances'],['finance','Finances','Budget et dépenses'],['medical','Médical','Blessures, fatigue, récupération'],['match','Match Center','Historique et données match'],['tactics','Tactique','Plan de match & coaching'],['fantasy','Fantasy Court','Créer un tournoi personnalisé'],['doubles','Double','Partenaires et compatibilité'],['university','Universitaire','NCAA / ITA'],['davis','Coupe Davis','Choisir et gérer une fédération'],['board','Board','Objectifs et confiance'],['world','Monde','Circuits et profondeur'],['competitions','Compétitions','Fiches, palmarès et records des tournois'],['history','Histoire & nations','Légendes par pays et continent'],['myplayer','Mon joueur','Identité, style et carrière'],['inbox','Boîte de réception','Décisions et alertes']];
 return `<div class="section-head"><div><div class="eyebrow">Centre manager</div><h1>Tous les modules</h1></div></div><div class="grid g2">${items.map(x=>`<div class="card click" onclick="nav('${x[0]}')"><div class="eyebrow">${x[1]}</div><h2>${x[2]}</h2></div>`).join('')}</div>`
}
function playersPage(){
 if(!dbLoaded&&!dbLoading)setTimeout(()=>loadPlayerDatabase().then(()=>{if(route==='players')render()}).catch(()=>{}),0);
 const circuits=['Tous','Tous réels','ATP classés','ATP profond','ITF','Junior','Junior Double','NCAA','Double','Race','Next Gen'];
 const start=dbCount?dbOffset+1:0,end=Math.min(dbOffset+dbRows.length,dbCount);
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Scouting database · ${fmt(worldStats?.searchableRealPlayers||dbCount||20000)} profils réels</div><h1>Base joueurs mondiale</h1><div class="muted">Classement mondial jusqu’au #30000, puis recherche complète : ITF, NCAA, juniors, anciens joueurs et prospects réels.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(worldStats?.searchableRealPlayers||dbCount||20000)} joueurs</div><div class="fm-head-badge subtle">${fmt(worldStats?.realPlayersWithDob||0)} DOB sourcées</div><div class="fm-head-badge subtle">${fmt(worldStats?.estimatedAgeReal||0)} âges estimés</div></div></div>
  <div class="card fm-db-toolbar">
   <div class="fm-db-filters">
    <input id="dbSearch" class="input" value="${esc(dbQuery)}" placeholder="Nom du joueur…" onkeydown="if(event.key==='Enter')searchPlayerDatabase(this.value)">
    <select class="select" onchange="setDbCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${dbCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select>
    <select class="select" onchange="setDbCircuit(this.value)">${circuits.map(x=>`<option ${dbCircuit===x?'selected':''}>${x}</option>`).join('')}</select>
    <button class="primary" onclick="searchPlayerDatabase(document.getElementById('dbSearch').value)">Rechercher</button>
   </div>
   <div class="row" style="margin-top:9px;flex-wrap:wrap"><span class="badge good">ATP/ITF réels</span><span class="badge tag-ncaa">NCAA</span><span class="badge tag-junior">Junior</span><span class="badge">Double</span><span class="muted mini">Âge affiché partout : âge au 01/12/2025. Quand une donnée manque, Court Boss génère une valeur fictive stable (DOB jour/mois, taille, poids, main, revers, style) et la marque estimée. Les vraies données sourcées restent prioritaires.</span></div>
  </div>
  <div class="card fm-panel" style="margin-top:12px">
   <div class="row between"><div><div class="eyebrow">Résultats scouting</div><h2>${dbQuery?'Recherche : '+esc(dbQuery):dbCountry?'Nationalité '+esc(dbCountry):dbCircuit!=='Tous'?esc(dbCircuit):'Base complète'}</h2></div><span class="pill">${fmt(dbCount)} profils</span></div>
   ${dbLoading?'<div class="loader">Recherche dans la base…</div>':`<div class="table-wrap"><table class="table fm-db-table"><thead><tr><th>Joueur</th><th>Âge 01/12/25</th><th>Pays</th><th>ATP</th><th>Double</th><th>Junior Dbl</th><th>ITF</th><th>Revers</th><th>NCAA</th><th>Niveau</th><th>Potentiel</th></tr></thead><tbody>${dbRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td><b>${esc(p.name)}</b><div class="muted micro">${p.is_real?'Réel':'Newgen'}${p.style?' · '+esc(p.style):''}</div></td><td>${displayAge(p)==null?'<span class="muted">N/V</span>':`<span title="${esc(p.age_source||'')}">${esc(ageLabel(p,false))}</span>`}</td><td>${flags[p.country]||'🌐'} ${esc(p.country||'—')}</td><td>${p.ranking?'#'+fmt(p.ranking)+(p.ranking>2000?' <span class="muted micro">ATP profond</span>':''):'—'}</td><td>${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'—'}</td><td>${p.junior_doubles_ranking?'#'+fmt(p.junior_doubles_ranking):'—'}</td><td>${p.itf_ranking?'#'+fmt(p.itf_ranking):'—'}</td><td><span class="badge ${p.backhand_verified?'good':''}">${esc(p.backhand||'2 mains')}${p.backhand_verified?'':' · estimé'}</span></td><td>${p.ncaa_current?'<span class="badge tag-ncaa">'+(p.ncaa_rank?'#'+fmt(p.ncaa_rank):'NCAA actif')+'</span>':p.ncaa_verified?'<span class="badge">'+(p.ncaa_status==='Alumni'?'NCAA Alumni':'NCAA historique')+'</span>':'—'}</td><td>${(()=>{const own=Number(p.id)===Number(career().managed_player_id||0),r=(boot.scoutingReports||[]).find(x=>Number(x.player_id)===Number(p.id));return own?starRatingHtml(abilityStarValue(p.current_ability),'Niveau connu')+`<div class="muted micro">Connu</div>`:r?starRatingHtml(Number(r.estimated_current_stars||publicLevelStars(p)),'Rapport scout')+`<div class="muted micro">${r.estimated_ca_min}–${r.estimated_ca_max} · ${r.confidence}%</div>`:starRatingHtml(publicLevelStars(p),'Estimation publique')+`<div class="muted micro">Public</div>`})()}</td><td>${(()=>{const own=Number(p.id)===Number(career().managed_player_id||0),r=(boot.scoutingReports||[]).find(x=>Number(x.player_id)===Number(p.id));return own?starRatingHtml(abilityStarValue(p.potential),'Potentiel connu')+`<div class="muted micro">Dynamique</div>`:r?starRatingHtml(Number(r.estimated_potential_stars||0),'Potentiel scout')+`<div class="muted micro">${r.estimated_potential_star_min??'?'}–${r.estimated_potential_star_max??'?'} ★</div>`:'<span class="muted">À scout­er</span>'})()}</td></tr>`).join('')}</tbody></table></div>`}
   ${!dbLoading&&!dbRows.length?'<div class="empty">Aucun joueur trouvé avec ces filtres.</div>':''}
   <div class="pagination"><button ${dbOffset===0?'disabled':''} onclick="dbPage(-1)">←</button><span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(dbCount)}</span><button ${dbOffset+100>=dbCount?'disabled':''} onclick="dbPage(1)">→</button></div>
  </div>
 </div>`
}
window.searchPlayerDatabase=async q=>{dbQuery=String(q||'').trim();dbOffset=0;await loadPlayerDatabase();render()}
window.setDbCountry=async c=>{dbCountry=String(c||'').toUpperCase();dbOffset=0;await loadPlayerDatabase();render()}
window.setDbCircuit=async c=>{dbCircuit=String(c||'Tous');dbOffset=0;await loadPlayerDatabase();render()}
window.dbPage=async d=>{dbOffset=Math.max(0,dbOffset+d*100);await loadPlayerDatabase();render();window.scrollTo(0,0)}

function staffFormerLabel(p){
 if(!p)return '';
 if(p.former_player_status==='yes'){
   if(p.verified)return 'Ancien joueur pro · sourcé';
   if(String(p.source_label||'').includes('reconversion dynamique'))return 'Ancien joueur Court Boss reconverti';
   return 'Ancien joueur probable · base simulée';
 }
 if(p.former_player_status==='no')return 'Spécialiste staff';
 return 'Parcours joueur non confirmé';
}
function staffMetaBadges(p){
 if(!p)return '';
 const langs=Array.isArray(p.languages)?p.languages.slice(0,3):[];
 return `<div class="row" style="gap:6px;flex-wrap:wrap">
  ${p.staff_personality?`<span class="badge">${esc(p.staff_personality)}</span>`:''}
  ${p.coaching_style?`<span class="badge">${esc(p.coaching_style)}</span>`:''}
  ${p.preferred_surface?`<span class="badge">${esc(p.preferred_surface)}</span>`:''}
  ${p.workload!=null?`<span class="badge ${Number(p.workload)>=85?'bad':Number(p.workload)>=70?'warn':'good'}">Charge ${p.workload}/100</span>`:''}
  ${p.energy!=null?`<span class="badge ${Number(p.energy)<45?'bad':Number(p.energy)<65?'warn':'good'}">Énergie ${p.energy}/100</span>`:''}
  ${p.burnout!=null&&Number(p.burnout)>0?`<span class="badge ${Number(p.burnout)>=70?'bad':Number(p.burnout)>=45?'warn':''}">Burnout ${p.burnout}/100</span>`:''}
  ${p.travel_fatigue!=null&&Number(p.travel_fatigue)>0?`<span class="badge">Voyage ${p.travel_fatigue}/100</span>`:''}
  ${langs.map(x=>`<span class="badge">${esc(x)}</span>`).join('')}
 </div>`;
}
function staffRatingGrid(p){
 if(!p)return '';
 const rows=[
  ['Coach',p.coach_rating],['Technique',p.technical_rating],['Tactique',p.tactical_rating],['Mental',p.mental_rating],
  ['Physique',p.fitness_rating],['Médical',p.medical_rating],['Scouting',p.scouting_rating],['Jeunes',p.youth_rating],
  ['Motivation',p.motivation_rating],['Communication',p.communication_rating],['Adaptation',p.adaptability_rating],['Réputation',p.reputation],
  ['Ambition',p.ambition],['Loyauté',p.loyalty],['Discipline',p.discipline],['Pression',p.pressure_handling],
  ['Négociation',p.negotiation_rating],['Professionnalisme',p.professionalism],['Développement',p.development_rating],
  ['Coach double',p.doubles_coaching_rating],['Service',p.serve_coaching_rating],['Retour',p.return_coaching_rating]
 ].filter(x=>x[1]!=null);
 return `<div class="kpi-strip staff-rating-grid">${rows.map(x=>`<div class="kpi"><span class="muted micro">${esc(x[0])}</span><b>${x[1]}/20</b><div class="bar"><i style="width:${Number(x[1])*5}%"></i></div></div>`).join('')}</div>`;
}

function staffWorldSection(){
 const d=staffWorldData||null;
 const rows=d?.rows||[],roles=d?.roles||[],countries=d?.countries||[];
 if(!d)return `<div class="card loader" style="margin-top:14px">Chargement de la base mondiale du staff…</div>`;
 return `<div class="section-head" style="margin-top:22px"><div><div class="eyebrow">Base mondiale</div><h2>Staff mondial</h2><div class="muted mini">Base complète paginée : coachs, kinés, préparateurs, recruteurs, agents et anciens joueurs reconvertis.</div></div><span class="pill">${fmt(d.total||0)} profils</span></div>
 <div class="card staff-world-filter"><div class="row" style="gap:8px;flex-wrap:wrap">
  <input id="staffWorldQ" value="${esc(staffWorldFilters.q||'')}" placeholder="Nom, spécialité, style…" style="flex:1;min-width:200px">
  <select id="staffWorldRole"><option value="">Tous les rôles</option>${roles.map(x=>`<option value="${esc(x.role)}" ${staffWorldFilters.role===x.role?'selected':''}>${esc(x.role)} (${fmt(x.count)})</option>`).join('')}</select>
  <select id="staffWorldCountry"><option value="">Tous les pays</option>${countries.map(x=>`<option value="${esc(x.country)}" ${staffWorldFilters.country===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} (${fmt(x.count)})</option>`).join('')}</select>
  <select id="staffWorldFormer"><option value="Tous">Tous parcours</option><option value="Oui" ${staffWorldFilters.former==='Oui'?'selected':''}>Anciens joueurs</option><option value="Non" ${staffWorldFilters.former==='Non'?'selected':''}>Spécialistes staff</option></select>
  <select id="staffWorldStatus"><option value="Tous">Tous statuts</option><option value="available" ${staffWorldFilters.status==='available'?'selected':''}>Disponibles</option><option value="contracted" ${staffWorldFilters.status==='contracted'?'selected':''}>Sous contrat</option><option value="user_staff" ${staffWorldFilters.status==='user_staff'?'selected':''}>Ton staff</option></select>
  <button class="primary" onclick="applyStaffWorldFilters()">Rechercher</button>
 </div></div>
 <div class="grid g3" style="margin-top:10px">
  <div class="card"><div class="eyebrow">Agences majeures</div>${(d.agencies||[]).slice(0,5).map(x=>`<div class="list-item"><div class="row between"><b>${esc(x.name)}</b><span class="badge">${x.reputation}/20</span></div><div class="muted micro">${flags[x.country]||'🏳️'} ${esc(x.specialty||'')} · ${fmt(x.members)} membres · réseau ${x.network_strength}/20</div></div>`).join('')}</div>
  <div class="card"><div class="eyebrow">Académies de coachs</div>${(d.academies||[]).slice(0,5).map(x=>`<div class="list-item"><div class="row between"><b>${esc(x.name)}</b><span class="badge">${x.prestige}/20</span></div><div class="muted micro">${flags[x.country]||'🏳️'} ${esc(x.specialty||'')} · ${fmt(x.members)} membres</div></div>`).join('')}</div>
  <div class="card"><div class="eyebrow">Instituts de formation</div>${(d.training_centers||[]).slice(0,5).map(x=>`<div class="list-item"><div class="row between"><b>${esc(x.name)}</b><span class="badge">${x.reputation}/20</span></div><div class="muted micro">${esc(x.specialty||'')} · ${fmt(x.active_enrollments)}/${fmt(x.capacity)} places actives</div></div>`).join('')}</div>
 </div>
 <div class="grid g2" style="margin-top:10px">${rows.map(x=>`<div class="card">
   <div class="row between"><div class="click" onclick="openStaffProfile(${x.id})"><div class="eyebrow">${esc(x.primary_role)}</div><h2>${flags[x.nationality]||'🏳️'} ${esc(x.name)}</h2><div class="muted mini">${esc(x.specialty||'')} · réputation ${x.reputation}/20</div></div><div class="progress-ring" style="--p:${Number(x.managed_fit||0)}"><b>${x.managed_fit??'—'}</b></div></div>
   <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge">${esc(staffFormerLabel(x))}</span><span class="badge">${esc(x.market_status||'')}</span>${x.top_license?`<span class="badge">${esc(x.top_license)}</span>`:''}</div>
   <div class="row between muted mini" style="margin-top:8px"><span>${esc(x.coaching_style||x.staff_personality||'Profil complet')}</span><span>${x.current_clients||0}/${x.max_clients||1} client(s)</span></div>
   ${x.agency_name?`<div class="muted micro" style="margin-top:5px">Agence : ${esc(x.agency_name)}</div>`:''}
   ${x.academy_name?`<div class="muted micro">Formation : ${esc(x.academy_name)}</div>`:''}
   <div class="row" style="gap:7px;margin-top:9px;flex-wrap:wrap"><button class="ghost" onclick="openStaffProfile(${x.id})">Dossier</button>${x.market_status==='available'?`<button class="primary" onclick="approachStaffProfile(${x.id})">Approcher</button>`:'<button class="ghost" disabled>Sous contrat</button>'}</div>
  </div>`).join('')||'<div class="card empty">Aucun profil ne correspond à ces filtres.</div>'}</div>
 <div class="row between" style="margin-top:10px"><button class="ghost" ${staffWorldOffset<=0?'disabled':''} onclick="staffWorldPage(-1)">← Précédent</button><span class="muted mini">${fmt(staffWorldOffset+1)}–${fmt(Math.min(staffWorldOffset+50,d.total||0))} / ${fmt(d.total||0)}</span><button class="ghost" ${staffWorldOffset+50>=Number(d.total||0)?'disabled':''} onclick="staffWorldPage(1)">Suivant →</button></div>`;
}
function staffPage(){
 const cand=management?.candidates||[];
 const roles=[...new Set(cand.map(x=>String(x.role||'')).filter(Boolean))].sort();
 const rels=management?.ownStaffRelations||[],agent=management?.managedAgency||null,agencyNetwork=management?.agencyNetwork||[],staffLeaders=management?.staffLeaders||[];
 const activeTraining=(management?.userStaffTraining||[]).filter(x=>x.status==='active');
 const trainingByProfile=new Map(activeTraining.map(x=>[Number(x.staff_profile_id),x]));
 const avgConflict=rels.length?Math.round(rels.reduce((s,x)=>s+Number(x.conflict_score||0),0)/rels.length):0;
 const avgAffinity=rels.length?Math.round(rels.reduce((s,x)=>s+Number(x.affinity||0),0)/rels.length):75;
 const highConflicts=rels.filter(x=>Number(x.conflict_score||0)>=60);
 return `<div class="section-head"><div><div class="eyebrow">Équipe</div><h1>Staff</h1><div class="muted">Coachs, préparateurs, kinés, analystes et recruteurs avec attributs 1–20 façon FM.</div></div></div>
 <div class="grid g2" style="margin-bottom:12px">
  <div class="card"><div class="row between"><div><div class="eyebrow">Cohésion staff</div><h2>Vestiaire technique</h2></div><span class="badge ${avgConflict>=60?'bad':avgConflict>=35?'warn':'good'}">${100-avgConflict}/100</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Affinité moyenne</span><b>${avgAffinity}</b></div><div class="kpi"><span class="muted micro">Conflit moyen</span><b>${avgConflict}</b></div><div class="kpi"><span class="muted micro">Tensions fortes</span><b>${highConflicts.length}</b></div></div>${highConflicts.slice(0,4).map(x=>`<div class="list-item"><div class="row between"><span>${esc(x.staff_a?.name||'Staff')} ↔ ${esc(x.staff_b?.name||'Staff')}</span><span class="badge bad">${x.conflict_score}/100</span></div><div class="row between" style="margin-top:5px"><div class="muted micro">${esc(x.relation_type||'Tension')} · rivalité ${x.rivalry||0}</div><button class="soft-btn" onclick="mediateStaffConflict(${x.staff_a_id},${x.staff_b_id})">Médiation</button></div></div>`).join('')||'<div class="muted mini" style="margin-top:8px">Aucune tension majeure dans ton équipe.</div>'}</div>
  <div class="card"><div class="row between"><div><div class="eyebrow">Agent & réseau</div><h2>${esc(agent?.agent?.name||'Aucun agent actif')}</h2></div><span class="badge">${agent?'Confiance '+(agent.trust??'—')+'/100':'À recruter'}</span></div>${agent?`<div class="list-item row between"><span>Agence</span><b>${esc(agent.agency?.name||'—')}</b></div><div class="list-item row between"><span>Commission</span><b>${agent.commission_pct??'—'}%</b></div><div class="list-item row between"><span>Négociation</span><b>${agent.agent?.negotiation_rating??'—'}/20</b></div><button class="ghost" onclick="openStaffProfile(${agent.agent?.id})">Voir le dossier agent</button>`:'<div class="empty">Recrute un agent dans le marché du staff pour débloquer un vrai réseau de représentation.</div>'}</div>
 </div>
 ${staffLeaders.length?`<div class="card" style="margin-bottom:12px">
  <div class="row between"><div><div class="eyebrow">Monde du staff</div><h2>Réputation & palmarès</h2><div class="muted mini">Indice Court Boss basé sur palmarès, réputation, niveau des clients et expertise.</div></div><span class="badge">Top ${Math.min(20,staffLeaders.length)}</span></div>
  <div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>#</th><th>Staff</th><th>Rôle</th><th>Score</th><th>Titres</th><th>GC</th><th>Meilleur client</th></tr></thead><tbody>
   ${staffLeaders.slice(0,20).map((x,i)=>`<tr class="click" onclick="openStaffProfile(${x.staff_profile_id})"><td><b>${i+1}</b></td><td><b>${flags[x.nationality]||'🏳️'} ${esc(x.name)}</b><div class="muted micro">réputation ${x.reputation}/20</div></td><td>${esc(x.primary_role||'Staff')}</td><td><b>${fmt(x.world_staff_score||0)}</b></td><td>${fmt(x.titles_total||0)}</td><td>${fmt(x.grand_slams||0)}</td><td>${x.best_client_rank?'#'+fmt(x.best_client_rank):'—'}</td></tr>`).join('')}
  </tbody></table></div>
 </div>`:''}
 ${agencyNetwork.length?`<div class="card" style="margin-bottom:12px">
  <div class="row between"><div><div class="eyebrow">Représentation mondiale</div><h2>Réseaux d’agents</h2></div><span class="badge">${agencyNetwork.reduce((s,x)=>s+Number(x.clients||0),0).toLocaleString('fr-FR')} clients</span></div>
  <div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>Agence</th><th>Clients</th><th>Agents</th><th>Top client</th><th>Réseau</th></tr></thead><tbody>
   ${agencyNetwork.slice(0,8).map(x=>`<tr><td><b>${esc(x.name)}</b><div class="muted micro">${esc(x.country||'INT')} · ${esc(x.specialty||'')}</div></td><td>${fmt(x.clients||0)}</td><td>${fmt(x.agents||0)}</td><td>#${fmt(x.top_client_rank||0)}</td><td>${x.network_strength}/20</td></tr>`).join('')}
  </tbody></table></div>
 </div>`:''}
 ${(management?.ownStaffOffers||[]).length?`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Marché</div><h2>Approches sur ton staff</h2></div><span class="badge warn">${management.ownStaffOffers.length}</span></div>${management.ownStaffOffers.map(o=>`<div class="list-item"><div class="row between"><div><b>${esc(o.staff?.name||'Staff')}</b><div class="muted mini">${esc(o.staff?.primary_role||'')} · offre de ${esc(o.competitor?.name||'un joueur rival')}</div></div><div style="text-align:right"><b>${euro(o.offered_weekly)}/sem.</b><div class="muted micro">échéance ${df(o.deadline)}</div></div></div><div class="row" style="gap:8px;margin-top:7px"><button class="primary" onclick="matchStaffOffer(${o.id})">S’aligner</button><button class="ghost" onclick="releaseStaffOffer(${o.id})">Le laisser partir</button></div></div>`).join('')}</div>`:''}
 <div class="grid g2">${(boot.staff||[]).map(s=>{const p=s.profile||null,n=s.name||p?.name||s.role,course=p?.id?trainingByProfile.get(Number(p.id)):null;return `<div class="card click" onclick="openStaff(${s.id})"><div class="row between"><div><div class="eyebrow">${esc(s.role)}</div><h2>${esc(n)}</h2><div class="row" style="margin-top:5px;flex-wrap:wrap">${p?`<span class="badge">${esc(staffFormerLabel(p))}</span>`:''}${p?.verified?'<span class="badge good">Profil sourcé</span>':''}${course?`<span class="badge warn">Formation ${course.progress||0}%</span>`:''}</div></div><div class="progress-ring" style="--p:${s.skill*5}"><b>${s.skill}/20</b></div></div><p class="muted">${esc(p?.specialty||'Staff performance')} · ${euro(s.weekly_cost)}/sem.</p>${p?staffMetaBadges(p):''}${p?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge ${Number(p.workload||0)>=85?'warn':''}">Charge ${p.workload??0}/100</span><span class="badge ${Number(p.burnout||0)>=65?'bad':''}">Burnout ${p.burnout??0}/100</span><span class="badge">Énergie ${p.energy??100}/100</span>${p.operational_status==='rest'? `<span class="badge warn">Repos jusqu’au ${df(p.rest_until)}</span>`:''}</div>`:''}${course?`<div class="bar" style="margin-top:8px"><i style="width:${Number(course.progress||0)}%"></i></div><div class="muted micro" style="margin-top:4px">${esc(course.focus||'Formation')} · ${esc(course.center?.name||'Centre')} · fin prévue ${df(course.expected_end)}</div>`:''}</div>`}).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Marché du staff</div><h2>Candidats disponibles</h2><div class="muted mini">Entretien obligatoire avant signature. Les profils ont leurs exigences, leur réseau et parfois des offres concurrentes.</div></div></div>
 <div class="card staff-market-filter"><div class="row" style="gap:8px;flex-wrap:wrap"><input id="staffMarketSearch" placeholder="Rechercher un coach, kiné, recruteur…" oninput="filterStaffMarket()" style="flex:1;min-width:210px"><select id="staffMarketRole" onchange="filterStaffMarket()"><option value="">Tous les rôles</option>${roles.map(r=>`<option value="${esc(r)}">${esc(r)}</option>`).join('')}</select><span class="badge">${cand.length} profils visibles</span></div></div>
 <div class="grid g2" id="staffMarketGrid">${cand.map(x=>{
   const p=x.profile||null,available=x.status==='available',done=x.interview_status==='completed',rejected=x.interview_status==='rejected';
   return `<div class="card click staff-market-card" data-name="${esc(String(x.name||'').toLowerCase())}" data-role="${esc(String(x.role||''))}" onclick="openStaffCandidate(${x.id})">
    <div class="row between"><div><div class="eyebrow">${esc(x.role)}</div><h2>${esc(x.name)}</h2><div class="row" style="margin-top:5px;flex-wrap:wrap">${p?`<span class="badge">${esc(staffFormerLabel(p))}</span>`:''}${p?.former_player_id&&!p?.verified?'<span class="badge">Reconversion simulée</span>':''}${p?.nationality?`<span class="badge">${flags[p.nationality]||'🏳️'} ${esc(p.nationality)}</span>`:''}${Number(x.competing_offers||0)>0?`<span class="badge warn">${x.competing_offers} offre(s) concurrente(s)</span>`:''}</div></div><div class="progress-ring" style="--p:${x.skill*5}"><b>${x.skill}/20</b></div></div>
    <p class="muted">${esc(x.specialty||p?.specialty||'')} · ${euro(done?(x.requested_weekly||x.weekly_cost):x.weekly_cost)}/sem.</p>
    ${p?staffMetaBadges(p):''}
    <div class="row between" style="margin-top:7px"><span class="mini muted">Compatibilité</span><b>${x.managed_fit!=null?x.managed_fit+'/100':'—'}</b></div>
    <div class="row" style="gap:6px;flex-wrap:wrap;margin:7px 0">${done?`<span class="badge good">Intérêt ${x.interest??'—'}/100</span>`:rejected?'<span class="badge bad">Entretien refusé</span>':'<span class="badge">Entretien requis</span>'}</div>
    <div class="row between"><span class="mini muted">Prime ${euro(done?(x.requested_signing||x.signing_cost):x.signing_cost)}</span><div class="row" style="gap:6px">${available&&!done&&!rejected?`<button class="primary" onclick="event.stopPropagation();interviewStaff(${x.id})">Entretien</button>`:''}${available&&done?`<button class="primary" onclick="event.stopPropagation();hireStaff(${x.id})">Recruter</button>`:''}${rejected?'<button class="ghost" disabled>Refus</button>':''}${x.status==='hired'?'<button class="ghost" disabled>Recruté</button>':''}${!available&&x.status!=='hired'?'<button class="ghost" disabled>Indisponible</button>':''}</div></div>
   </div>`;
 }).join('')}</div>${staffWorldSection()}`
}
function contractsPage(){
 const rows=management?.contracts||[];
 return `<div class="section-head"><div><div class="eyebrow">Négociations</div><h1>Contrats</h1><div class="muted">Échéances, salaires et renouvellements.</div></div></div><div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>Personne</th><th>Rôle</th><th>Salaire/sem.</th><th>Fin</th><th>Statut</th><th></th></tr></thead><tbody>${rows.map(x=>{const active=x.status==='active';return `<tr><td class="click" onclick="openContract(${x.id})"><b>${esc(x.subject_name)}</b></td><td>${esc(x.role||x.subject_type)}</td><td>${euro(x.weekly_salary)}</td><td>${df(x.end_date)}</td><td><span class="badge ${active?'good':'muted'}">${esc(x.status)}</span></td><td>${active?`<button class="soft-btn" onclick="renewContract(${x.id})">+ 1 an</button>`:''}</td></tr>`}).join('')}</tbody></table></div></div>`
}
function financePage(){
 const cr=career(),f=boot.finance||{},offers=management?.sponsors||[];
 const accepted=offers.filter(x=>x.status==='accepted');
 const sponsorWeekly=accepted.reduce((sum,x)=>sum+Number(x.weekly_value||0),0);
 const staffWeekly=(boot.staff||[]).reduce((sum,x)=>sum+Number(x.weekly_cost||0),0);
 const playerWeekly=(management?.academyRoster||[]).reduce((sum,x)=>sum+Number(x.weekly_cost||0),0);
 return `<div class="section-head"><div><div class="eyebrow">Comptabilité</div><h1>Finances & sponsors</h1></div></div>
 <div class="kpi-strip"><div class="kpi"><span class="muted mini">Solde</span><b>${euro(cr.budget)}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${euro(f.prize_money)}</b></div><div class="kpi"><span class="muted mini">Sponsors / sem.</span><b>${euro(sponsorWeekly)}</b></div><div class="kpi"><span class="muted mini">Masse salariale</span><b>${euro(staffWeekly+playerWeekly)}</b></div><div class="kpi"><span class="muted mini">Commissions agent</span><b>${euro(f.agent_commission||0)}</b></div><div class="kpi"><span class="muted mini">Primes staff</span><b>${euro(f.staff_bonus||0)}</b></div></div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Offres commerciales</h2>${offers.map(x=>`<div class="list-item"><div class="row between"><div><b>${esc(x.brand)}</b><div class="muted mini">${euro(x.weekly_value)}/sem. · bonus ${euro(x.signing_bonus)} · ${x.duration_weeks} sem.</div></div><span class="badge ${x.status==='accepted'?'good':x.status==='locked'?'bad':''}">${esc(x.status)}</span></div><div class="muted mini" style="margin-top:5px">${esc(x.requirement||'')}</div>${x.status==='available'?`<button class="primary" style="margin-top:8px" onclick="acceptSponsor(${x.id})">Accepter</button>`:''}</div>`).join('')||'<div class="empty">Aucune offre.</div>'}</div>
  <div class="card"><h2>Projection hebdomadaire</h2><div class="list-item row between"><span>Revenus sponsors</span><b class="good">+${euro(sponsorWeekly)}</b></div><div class="list-item row between"><span>Staff</span><b class="bad">-${euro(staffWeekly)}</b></div><div class="list-item row between"><span>Joueurs académie</span><b class="bad">-${euro(playerWeekly)}</b></div><div class="list-item row between"><span>Net hebdomadaire</span><b class="${sponsorWeekly-staffWeekly-playerWeekly>=0?'good':'bad'}">${sponsorWeekly-staffWeekly-playerWeekly>=0?'+':''}${euro(sponsorWeekly-staffWeekly-playerWeekly)}</b></div><div class="list-item row between"><span>Voyage moyen</span><b class="bad">-${euro(Number(f.travel_cost||0)/4)}</b></div><div class="notice" style="margin-top:10px">Les sponsors signés alimentent le budget à chaque semaine simulée.</div></div>
 </div>
 <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Économie carrière</div><h2>Coûts de représentation & performance</h2></div><span class="badge">Évolutif</span></div><div class="list-item row between"><span>Voyages cumulés</span><b class="bad">-${euro(f.travel_cost||0)}</b></div><div class="list-item row between"><span>Commissions agent cumulées</span><b class="bad">-${euro(f.agent_commission||0)}</b></div><div class="list-item row between"><span>Primes de titres au staff</span><b class="bad">-${euro(f.staff_bonus||0)}</b></div><div class="muted mini" style="margin-top:8px">Les commissions suivent ton contrat d’agence. Les membres du staff qui exigent un bonus de performance touchent leur prime quand tu remportes un titre.</div></div>`
}
function injuryRisk(){
 const c=career(),load=trainingLoad();
 let r=12+(c.fatigue||18)*.45+(100-(c.fitness||91))*.35+Math.max(0,65-(c.form||72))*.2+Math.max(0,load-9)*4;
 if(local.injuryTreatment==='Prudent')r-=10;if(local.injuryTreatment==='Agressif')r+=8;
 return Math.round(clamp(r,2,95));
}
function medicalPage(){
 const c=career(),inj=boot.injuries||[],managed=boot.managedInjury||null,plan=boot.medicalPlan||{protocol:'Récupération active',physio_hours:2,weekly_cost:250};
 const risk=managed?Number(managed.aggravation_risk||0):clamp(Math.round((c.fatigue||18)*.75+(trainingLoad()*3)),0,100);
 const protocols=[
  ['Repos complet','Fatigue ↓↓↓ · retour accéléré · forme légèrement en baisse','0 € / semaine'],
  ['Physio intensive','Risque ↓↓↓ · retour le plus rapide · coût élevé','900 € / semaine'],
  ['Récupération active','Équilibre récupération / fitness','250 € / semaine'],
  ['Maintien de forme','Fitness préservée · risque de rechute plus élevé','120 € / semaine']
 ];
 return `<div class="section-head"><div><div class="eyebrow">Centre médical</div><h1>Condition & blessures</h1><div class="muted">Diagnostic, protocole, récupération et risque de rechute.</div></div><button class="primary" onclick="setMedicalProtocol('Récupération active')">Récupération active</button></div>
 <div class="grid g4"><div class="card"><h3>Fitness</h3><div class="big">${c.fitness||91}%</div><div class="bar"><i style="width:${c.fitness||91}%"></i></div></div><div class="card"><h3>Fatigue</h3><div class="big">${c.fatigue||18}%</div><div class="bar"><i style="width:${c.fatigue||18}%"></i></div></div><div class="card"><h3>Risque</h3><div class="big ${risk>65?'bad':risk>35?'warn':'good'}">${risk}%</div></div><div class="card"><h3>Statut</h3><div class="big" style="font-size:20px">${esc(c.injury_status||'Fit')}</div></div></div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Dossier du joueur géré</h2>${managed?`
    <div class="notice ${managed.severity==='Sévère'?'bad':''}"><b>${esc(managed.injury_type)}</b> · ${esc(managed.severity)}</div>
    <div class="list-item row between"><span>Début</span><b>${df(managed.started_at)}</b></div>
    <div class="list-item row between"><span>Retour estimé</span><b>${df(managed.expected_return)}</b></div>
    <div class="list-item row between"><span>Risque d’aggravation</span><b class="${Number(managed.aggravation_risk)>50?'bad':Number(managed.aggravation_risk)>25?'warn':'good'}">${managed.aggravation_risk}%</b></div>
    <div class="list-item row between"><span>Traitement actuel</span><b>${esc(managed.treatment||plan.protocol)}</b></div>
    <button class="soft-btn" style="margin-top:10px" onclick="openInjury(${managed.id})">Voir le dossier complet</button>
  `:`<div class="notice good"><b>Aucune blessure active.</b><br><span class="muted mini">Le plan médical agit quand même sur la fatigue et la prévention.</span></div>`}</div>
  <div class="card"><h2>Plan médical actuel</h2>
    <div class="list-item row between"><span>Protocole</span><b>${esc(plan.protocol)}</b></div>
    <div class="list-item row between"><span>Physio</span><b>${plan.physio_hours||0} h / semaine</b></div>
    <div class="list-item row between"><span>Coût</span><b>${euro(plan.weekly_cost||0)} / semaine</b></div>
    <div class="muted mini" style="margin-top:8px">${esc(plan.notes||'')}</div>
  </div>
 </div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Traitement</div><h2>Choisir le protocole</h2></div></div>
 <div class="grid g2">${protocols.map(x=>`<div class="card ${plan.protocol===x[0]?'selected-card':''}"><div class="row between"><div><h3>${x[0]}</h3><div class="muted mini">${x[1]}</div></div><span class="badge">${x[2]}</span></div><button class="${plan.protocol===x[0]?'ghost':'soft-btn'}" style="margin-top:10px" onclick="setMedicalProtocol('${x[0]}')">${plan.protocol===x[0]?'Actif':'Appliquer'}</button></div>`).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Monde</div><h2>Blessures connues</h2></div></div>
 <div class="card">${inj.length?inj.map(i=>`<div class="list-item click" onclick="openInjury(${i.id})"><div class="row between"><b>${esc(i.players?.name||'Joueur')} · ${esc(i.injury_type)}</b><span class="badge ${i.status==='Active'?'bad':'good'}">${esc(i.status)}</span></div><div class="muted mini">Sévérité ${esc(i.severity)} · retour ${df(i.expected_return)} · rechute ${i.aggravation_risk}%</div></div>`).join(''):'<div class="empty">Aucune blessure enregistrée.</div>'}</div>`
}
function pointLabel(a,b,side){
 if(a>=3&&b>=3){
  if(a===b)return '40';
  if(side==='A'&&a>b)return 'AV';
  if(side==='B'&&b>a)return 'AV';
  return '40';
 }
 return ['0','15','30','40'][side==='A'?Math.min(a,3):Math.min(b,3)];
}
function liveMatchPanel(){
 const s=local.liveMatch;
 const selectedSurface=local.matchSurface||'Dur';
 const selectedIndoor=!!local.matchIndoor;
 if(!s)return `<div class="card fm-match-launch"><div class="row between"><div><div class="eyebrow">Match engine</div><h2>Vue tactique mobile</h2><div class="muted">Vue tactique type manager : pions ronds mobiles, trajectoire de balle, momentum, score et coaching en direct.</div></div><span class="badge">Point par point</span></div>
  <div class="match-surface-pills">
   <button class="${selectedSurface==='Dur'&&!selectedIndoor?'active':''}" onclick="setMatchSurface('Dur',false)">Dur ext.</button>
   <button class="${selectedSurface==='Dur'&&selectedIndoor?'active':''}" onclick="setMatchSurface('Dur',true)">Dur int.</button>
   <button class="${selectedSurface==='Terre'?'active':''}" onclick="setMatchSurface('Terre',false)">Terre</button>
   <button class="${selectedSurface==='Gazon'?'active':''}" onclick="setMatchSurface('Gazon',false)">Gazon</button>
  </div>
  <button class="primary fm-start-match" onclick="startLiveMatch()">Lancer un match autour de mon classement</button>
 </div>`;

 const c=career(),opp=local.liveOpponent||{},lp=s.last_point||{},st=s.stats||{};
 const userName=c.player_name||'Joueur',oppName=opp.name||'Adversaire';
 const us=Number(s.user_sets||0),os=Number(s.opponent_sets||0),ug=Number(s.user_games||0),og=Number(s.opponent_games||0);
 const up=Number(s.user_points||0),op=Number(s.opponent_points||0);
 const done=s.status==='completed';
 const ux=clamp(Number(lp.user_x??(48+(Number(s.rally_no||0)%3)*6)),12,88);
 const uy=clamp(Number(lp.user_y??78),55,90);
 const ox=clamp(Number(lp.opp_x??(52-(Number(s.rally_no||0)%3)*6)),12,88);
 const oy=clamp(Number(lp.opp_y??22),10,45);
 const bx=clamp(Number(lp.ball_x??50),10,90),by=clamp(Number(lp.ball_y??50),8,92);
 const surface=String(s.surface||'Dur'),courtClass=surface==='Terre'?'clay':surface==='Gazon'?'grass':'hard';
 const indoor=/intérieur/i.test(surface);
 const uInit=esc(userName.split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase());
 const oInit=esc(oppName.split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase());
 const momentum=clamp(Number(s.momentum||50),10,90);
 const pointText=(a,b,side)=>pointLabel(a,b,side);
 const pctStat=(num,den)=>Number(den||0)>0?Math.round(Number(num||0)/Number(den)*100):0;
 const userFirstPct=pctStat(st.user_first_serves_in,st.user_first_serves);
 const oppFirstPct=pctStat(st.opp_first_serves_in,st.opp_first_serves);
 const pointEnding=String(lp.ending||lp.shot||'').replaceAll('_',' ');
 const pointServe=lp.serve_number?`${lp.serve_number}e balle · ${esc(lp.serve_direction||'')}`:'';
 const pointReturn=lp.return_depth?`retour ${esc(lp.return_depth)}`:'';
 return `<div class="card fm-live-match">
  <div class="fm-match-top">
   <div><div class="eyebrow">Live · ${esc(surface)}${indoor?' · indoor':''}</div><h2>${esc(userName)} vs ${esc(oppName)}</h2></div>
   <span class="badge ${done?'good':'warn'}">${done?'Terminé':'Set '+(s.set_no||1)}</span>
  </div>

  <div class="fm-scoreboard">
   <div class="fm-score-name">${s.serving_user?'● ':''}${esc(userName)} <small>${flags[c.country]||''}</small></div><b>${us}</b><b>${ug}</b><strong>${pointText(up,op,'A')}</strong>
   <div class="fm-score-name">${!s.serving_user?'● ':''}${esc(oppName)} <small>${flags[opp.country]||''}</small></div><b>${os}</b><b>${og}</b><strong>${pointText(up,op,'B')}</strong>
  </div>

  <div class="fm-court ${courtClass} ${indoor?'indoor':''}">
    <i class="fm-court-line baseline top"></i><i class="fm-court-line baseline bottom"></i>
    <i class="fm-court-line sideline left"></i><i class="fm-court-line sideline right"></i>
    <i class="fm-court-line service horizontal top"></i><i class="fm-court-line service horizontal bottom"></i>
    <i class="fm-court-line service vertical"></i><i class="fm-net"></i>
    <div class="fm-player-dot opponent" style="left:${ox}%;top:${oy}%"><span>${oInit}</span><small>${esc(oppName.split(' ').slice(-1)[0]||'ADV')}</small></div>
    <div class="fm-player-dot user" style="left:${ux}%;top:${uy}%"><span>${uInit}</span><small>${esc(userName.split(' ').slice(-1)[0]||'MOI')}</small></div>
    <i class="fm-ball" style="left:${bx}%;top:${by}%"></i>
    ${lp.shot?`<div class="fm-rally-call"><b>${esc(pointEnding)}</b> · ${Number(lp.rally||0)} coups${lp.rally_band?' · '+esc(lp.rally_band):''}${pointServe?' · '+pointServe:''}${pointReturn?' · '+pointReturn:''}${lp.at_net?' · filet':''}</div>`:''}
  </div>

  <div class="fm-momentum"><span>${esc(oppName)}</span><div><i style="left:${momentum}%"></i></div><span>${esc(userName)}</span></div>
  <div class="fm-match-stats">
   <div><span>Winners</span><b>${st.user_winners||0}–${st.opp_winners||0}</b></div>
   <div><span>Fautes</span><b>${st.user_errors||0}–${st.opp_errors||0}</b></div>
   <div><span>Aces</span><b>${st.user_aces||0}–${st.opp_aces||0}</b></div>
   <div><span>1res IN</span><b>${userFirstPct}%–${oppFirstPct}%</b></div>
   <div><span>DF</span><b>${st.user_double_faults||0}–${st.opp_double_faults||0}</b></div>
   <div><span>Non retournés</span><b>${st.user_unreturned_serves||0}–${st.opp_unreturned_serves||0}</b></div>
   <div><span>Filet</span><b>${st.user_net_points_won||0}/${st.user_net_points||0}</b></div>
   <div><span>Points</span><b>${s.rally_no||0}</b></div>
  </div>
  ${lp.model?`<div class="muted micro" style="margin-top:8px">Moteur : ${esc(lp.model)} · P(point) serveur ${lp.server_win_probability??'—'}% · Elo surface ${Math.round(Number(lp.server_surface_elo||0))} vs ${Math.round(Number(lp.returner_surface_elo||0))}</div>`:''}
  ${done?`<button class="ghost" style="width:100%;margin-top:10px" onclick="clearLiveMatch()">Nouveau match</button>`:`<div class="fm-live-toolbar">
   <button class="${liveAutoTimer?'danger-btn':'primary'}" onclick="toggleLiveAuto()">${liveAutoTimer?'Pause':'▶ Live'}</button>
   <button class="soft-btn ${liveAutoSpeed===1?'active':''}" onclick="setLiveSpeed(1)">1x</button>
   <button class="soft-btn ${liveAutoSpeed===2?'active':''}" onclick="setLiveSpeed(2)">2x</button>
   <button class="soft-btn ${liveAutoSpeed===4?'active':''}" onclick="setLiveSpeed(4)">4x</button>
  </div><div class="fm-sim-controls"><button class="primary" onclick="playLivePoint()">Point</button><button class="soft-btn" onclick="simulateLiveGame()">Jeu</button><button class="soft-btn" onclick="simulateLiveSet()">Set</button><button class="soft-btn" onclick="simulateLiveMatch()">Match</button></div>`}
 </div>`
}
function matchPage(){
 const t=local.tactics||{aggression:58,risk:52,net:28,returnPos:'Neutre'};
 const all=[...(local.practiceMatches||[]),...(boot.matches||[])],doublesOnly=String(career().career_focus||'mixed')==='doubles_only';
 return `<div class="section-head"><div><div class="eyebrow">Analyse & coaching</div><h1>Match Center</h1><div class="muted">Prépare le plan de jeu, coache point par point et analyse les tendances.</div></div><button class="ghost" ${doublesOnly?'disabled':''} onclick="simulatePracticeMatch()">Simulation rapide</button></div>
 ${doublesOnly?'<div class="notice good"><b>Carrière Double exclusivement</b> · les matchs simples sont coupés. Utilise le hub Double et les fiches tournoi pour jouer.</div>':liveMatchPanel()}
 <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Plan de jeu</h2>
 <div class="list-item"><div class="row between"><span>Agressivité</span><b>${t.aggression}%</b></div><input class="range" type="range" min="1" max="100" value="${t.aggression}" oninput="setTactic('aggression',this.value)"></div>
 <div class="list-item"><div class="row between"><span>Prise de risque</span><b>${t.risk}%</b></div><input class="range" type="range" min="1" max="100" value="${t.risk}" oninput="setTactic('risk',this.value)"></div>
 <div class="list-item"><div class="row between"><span>Montées au filet</span><b>${t.net}%</b></div><input class="range" type="range" min="1" max="100" value="${t.net}" oninput="setTactic('net',this.value)"></div>
 <div class="list-item row between"><span>Position retour</span><select class="select" style="width:auto" onchange="setTactic('returnPos',this.value)"><option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option><option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option></select></div></div>
 <div class="card"><h2>Lecture tactique</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Intensité</span><b>${Math.round((t.aggression+t.risk)/2)}</b></div><div class="kpi"><span class="muted mini">Jeu avant</span><b>${t.net}</b></div><div class="kpi"><span class="muted mini">Retour</span><b style="font-size:15px">${esc(t.returnPos)}</b></div></div><p class="muted mini" style="margin-top:10px">Les changements de tactique influencent les points suivants du match live et les simulations de tournoi.</p></div></div>
 <div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Historique</div><h2>Matchs analysés</h2></div></div>
 <div class="stack">${all.map((m,idx)=>`<div class="card click" onclick="openMatch(${idx})"><div class="row between"><div><div class="eyebrow">${esc(m.tournament_name||'Match entraînement')} · ${esc(m.round||'Exhibition')}</div><h2>${esc(m.player_a)} vs ${esc(m.player_b)}</h2><div class="muted">${df(m.match_date||local.date)} · <span class="${surfaceClass(m.surface||'Dur')}">${esc(m.surface||'Dur')}</span></div></div><div><div class="big">${esc(m.score||'—')}</div><span class="badge ${m.winner===(career().player_name||'Joueur')?'good':'bad'}">${m.winner===(career().player_name||'Joueur')?'Victoire':'Défaite'}</span></div></div><div class="kpi-strip" style="margin-top:12px">${Object.entries(m.match_data||{}).filter(([k,v])=>k!=='tactical_plan'&&typeof v!=='object').slice(0,4).map(([k,v])=>`<div class="kpi"><span class="muted mini">${esc(k.replaceAll('_',' '))}</span><b>${v}</b></div>`).join('')}</div></div>`).join('')||'<div class="card empty">Aucun match enregistré.</div>'}</div>`
}
window.setMatchSurface=(surface,indoor=false)=>{local.matchSurface=surface;local.matchIndoor=!!indoor;persist();render()}
window.startLiveMatch=async()=>{
 if(String(career().career_focus||'mixed')==='doubles_only'){alert('Carrière Double exclusivement : le Match Center simple est désactivé.');return}
 try{
  const surface=(local.matchSurface||'Dur')==='Dur'&&local.matchIndoor?'Dur intérieur':(local.matchSurface||'Dur');
  const d=await get('/api/live-match/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({surface,tactics:local.tactics||{}})});
  local.liveMatch=d.session;local.liveOpponent=d.opponent||null;persist();render();
 }catch(e){alert(e.message)}
}
window.playLivePoint=async()=>{
 if(!local.liveMatch)return;
 try{
  const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
  local.liveMatch=d.session;if(d.opponent)local.liveOpponent=d.opponent;if(local.liveMatch?.status==='completed'&&liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null}persist();render();
 }catch(e){alert(e.message)}
}
window.simulateLiveGame=async()=>{
 if(!local.liveMatch||local.liveMatch.status==='completed')return;
 try{
  const d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
  local.liveMatch=d.session;if(d.opponent)local.liveOpponent=d.opponent;persist();render();
 }catch(e){alert(e.message)}
}
window.simulateLiveSet=async()=>{
 if(!local.liveMatch||local.liveMatch.status==='completed')return;
 const startSets=Number(local.liveMatch.user_sets||0)+Number(local.liveMatch.opponent_sets||0);
 try{
  for(let i=0;i<20;i++){
   const d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
   local.liveMatch=d.session;if(d.opponent)local.liveOpponent=d.opponent;
   if(local.liveMatch.status==='completed'||Number(local.liveMatch.user_sets||0)+Number(local.liveMatch.opponent_sets||0)!==startSets)break;
  }
  persist();render();
 }catch(e){alert(e.message)}
}
window.simulateLiveMatch=async()=>{
 if(!local.liveMatch||local.liveMatch.status==='completed')return;
 try{
  for(let i=0;i<60;i++){
   const d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
   local.liveMatch=d.session;if(d.opponent)local.liveOpponent=d.opponent;
   if(local.liveMatch.status==='completed')break;
  }
  persist();render();
 }catch(e){alert(e.message)}
}
window.setLiveSpeed=speed=>{
 liveAutoSpeed=[1,2,4].includes(Number(speed))?Number(speed):1;
 if(liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null;toggleLiveAuto()}
 render();
}
async function liveAutoTick(){
 if(liveAutoBusy||!local.liveMatch||local.liveMatch.status==='completed'){
   if(local.liveMatch?.status==='completed'&&liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null;render()}
   return;
 }
 liveAutoBusy=true;
 try{
   const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
   local.liveMatch=d.session;if(d.opponent)local.liveOpponent=d.opponent;persist();render();
   if(local.liveMatch?.status==='completed'&&liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null;render()}
 }catch(e){
   if(liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null}
   alert(e.message);
 }finally{liveAutoBusy=false}
}
window.toggleLiveAuto=()=>{
 if(liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null;render();return}
 if(!local.liveMatch||local.liveMatch.status==='completed')return;
 liveAutoTimer=setInterval(liveAutoTick,Math.max(180,900/liveAutoSpeed));
 liveAutoTick();render();
}
window.clearLiveMatch=()=>{if(liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null}delete local.liveMatch;delete local.liveOpponent;persist();render()}
function doublesPage(){
 const c=career(),singlesOnly=String(c.career_focus||'mixed')==='singles_only';
 if(!doublesHubRows.length&&!doublesHubLoading)setTimeout(loadDoublesHub,0);
 const pool=doublesHubRows;
 const juniorPool=juniorDoublesHubRows;
 const partner=singlesOnly?null:(pool.find(p=>p.id===local.partnerId)||juniorPool.find(p=>p.id===local.partnerId)
   ||(management?.partnerships||[]).map(x=>x.partner||x.player_b).find(Boolean)
   ||null);
 const offers=management?.doublesPartnerOffers||[];
 const managedCommitment=management?.managedDoublesCommitment||null;
 const ownPartnership=(management?.partnerships||[]).find(x=>Number(x.player_b_id)===Number(partner?.id||0))||null;
 const incomingOffers=offers.filter(x=>x.direction==='incoming'&&x.status==='pending');
 const recentOutgoing=offers.filter(x=>x.direction==='outgoing').slice(0,6);
 const candidates=pool.filter(p=>p.name!==c.player_name).slice(0,30);
 const exact=pool.filter(p=>p.doubles_source).length;
 return `<div class="section-head"><div><div class="eyebrow">Circuit Double</div><h1>Double & partenariats</h1><div class="muted">Classement individuel officiel jusqu’au Top 1000, index scouting double profond, Race par équipes et gestion du partenaire. La base double étendue contient ${fmt(worldStats?.indexedDoubles||rankCount||0)} profils.</div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge ${String(c.career_focus||'mixed')==='doubles_only'?'good':''}">Orientation · ${careerFocusLabel(c.career_focus||'mixed')}</span>${String(c.career_focus||'mixed')==='doubles_only'?'<span class="badge good">Circuit principal</span>':''}</div></div><span class="pill">${fmt(worldStats?.sourcedDoubles||exact)} officiels · ${fmt(worldStats?.indexedDoubles||0)} indexés</span></div>
 ${singlesOnly?'<div class="notice"><b>Simple exclusivement</b> · consultation du circuit double uniquement. Les paires, propositions et inscriptions double sont verrouillées.</div>':''}
 <div class="tabs rank-tabs"><button class="active">Partenariat</button><button onclick="setRankKind('doubles');nav('rankings')">Classement Double</button><button onclick="setRankKind('doubles_race');nav('rankings')">Race Double</button><button onclick="setRankKind('junior_doubles');nav('rankings')">Junior Double</button><button onclick="setRankKind('junior_doubles_race');nav('rankings')">Race Junior Double</button><button onclick="dbCircuit='Double';dbOffset=0;dbQuery='';loadPlayerDatabase().then(()=>nav('players'))">Base double complète</button><button onclick="document.getElementById('dblRace').scrollIntoView({behavior:'smooth'})">Race équipes</button></div>
 <div class="grid g2" style="margin-top:10px">
  <div class="card"><div class="row between"><h2>Partenaire actuel</h2><span class="badge">Ton rang ${careerDoublesRankText(c)}</span></div>
   ${partner?`<div class="row between click" onclick="openPlayer(${partner.id})"><div><h2>${flags[partner.country]||'🏳️'} ${esc(partner.name)}</h2><div class="muted">Double #${fmt(partner.doubles_ranking)} ${partner.ranking?'· ATP #'+partner.ranking:''}</div><div class="muted mini">${partner.doubles_snapshot_date?'réf. '+df(partner.doubles_snapshot_date):''}</div></div><span class="badge good">Partenaire principal</span></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Chimie</span><b>${pairScore(partner,'chem')}%</b></div><div class="kpi"><span class="muted mini">Compatibilité</span><b>${pairScore(partner,'comp')}%</b></div><div class="kpi"><span class="muted mini">Force paire</span><b>${pairScore(partner,'power')}%</b></div><div class="kpi"><span class="muted mini">Engagement</span><b>${managedCommitment?.commitment??'—'}%</b></div></div>${managedCommitment?`<div class="row between muted mini" style="margin-top:8px"><span>Affinité ${managedCommitment.affinity}/100 · depuis ${df(managedCommitment.started_at)}</span><span>${managedCommitment.switches||0} changement${Number(managedCommitment.switches||0)>1?'s':''}</span></div><div class="muted micro" style="margin-top:5px">Le partenaire peut aussi décider de quitter la paire si le projet sportif ou l'engagement se dégrade.</div>`:''}`:'<div class="empty">Choisis un spécialiste dans le classement Double.</div>'}
  </div>
  <div class="card"><div class="row between"><h2>Top double vérifié</h2><button class="ghost" onclick="setRankKind('doubles');nav('rankings')">Voir tout</button></div>
   ${pool.slice(0,12).map(p=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>#${p.doubles_ranking} ${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${p.doubles_points==null?'points non publiés dans ce snapshot':fmt(p.doubles_points)+' pts'} · ${df(p.doubles_snapshot_date)}</div></div>${singlesOnly?'<button class="ghost" disabled>Verrouillé</button>':`<button class="soft-btn" onclick="approachPartner(${p.id})">Approcher</button>`}</div>`).join('')||'<div class="loader">Chargement du classement double…</div>'}
  </div>
 </div>
 ${ownPartnership&&partner?`<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Vie de la paire</div><h2>${esc(c.player_name||'Joueur')} / ${esc(partner.name)}</h2></div><span class="badge ${Number(ownPartnership.momentum||50)>=70?'good':Number(ownPartnership.momentum||50)<45?'bad':''}">Momentum ${fmt(ownPartnership.momentum??50)}%</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Tournois</span><b>${fmt(ownPartnership.events_played||0)}</b></div><div class="kpi"><span class="muted mini">Finales</span><b>${fmt(ownPartnership.finals||0)}</b></div><div class="kpi"><span class="muted mini">Titres</span><b>${fmt(ownPartnership.titles||0)}</b></div><div class="kpi"><span class="muted mini">Dernier match</span><b style="font-size:13px">${ownPartnership.last_played?df(ownPartnership.last_played):'—'}</b></div></div><div class="muted mini" style="margin-top:8px">Les résultats font évoluer la chimie, l’engagement et la force de la paire. Une série de gros résultats stabilise le duo, une mauvaise période peut pousser l’un des deux à partir.</div></div>`:''}
 ${incomingOffers.length||recentOutgoing.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Marché des partenaires</div><h2>Propositions & négociations</h2><div class="muted">Les joueurs peuvent accepter, refuser ou quitter une paire selon leur projet et leur engagement actuel.</div></div><span class="pill">${incomingOffers.length} proposition${incomingOffers.length>1?'s':''} reçue${incomingOffers.length>1?'s':''}</span></div>
 <div class="grid g2">
  ${incomingOffers.length?`<div class="card"><div class="row between"><h2>Ils veulent jouer avec toi</h2><span class="badge good">${incomingOffers.length}</span></div>${incomingOffers.map(x=>{const p=x.from_player||{};return `<div class="list-item"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</b><div class="muted mini">Double ${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'NR'} · ${careerFocusLabel(p.career_focus||'mixed')}</div></div><div style="text-align:right"><b>${x.interest_score}/100</b><div class="muted micro">intérêt</div></div></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:6px"><span class="badge">Chimie ${x.chemistry||'—'}</span><span class="badge">Compat. ${x.compatibility||'—'}</span><span class="badge">Engagement ${x.proposed_commitment||'—'}</span></div><div class="muted micro" style="margin-top:5px">${esc(x.reason||'Proposition de partenariat')}</div><div class="row" style="gap:7px;margin-top:8px"><button class="primary" onclick="respondPartnerOffer(${x.id},'accept')">Accepter</button><button class="ghost" onclick="respondPartnerOffer(${x.id},'decline')">Refuser</button></div></div>`}).join('')}</div>`:''}
  ${recentOutgoing.length?`<div class="card"><div class="row between"><h2>Tes approches récentes</h2><span class="badge">${recentOutgoing.length}</span></div>${recentOutgoing.map(x=>{const p=x.to_player||{};return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</b><div class="muted mini">${esc(x.reason||'Approche partenaire')} · ${df(x.offer_date)}</div></div><span class="badge ${x.status==='accepted'?'good':x.status==='declined'?'bad':''}">${x.status==='accepted'?'Acceptée':x.status==='declined'?'Refusée':esc(x.status)}</span></div>`}).join('')}</div>`:''}
 </div>`:''}
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Circuit Junior</div><h2>Top Junior Double</h2><div class="muted">Classement individuel séparé #1–#2000. Les joueurs peuvent former une paire et jouer le double dans les tournois juniors.</div></div><button class="ghost" onclick="setRankKind('junior_doubles');nav('rankings')">Voir les 2000</button></div>
 <div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Âge 01/12/25</th><th>Pts</th><th></th></tr></thead><tbody>
 ${juniorPool.slice(0,20).map(p=>`<tr><td class="rank-num">#${fmt(p.junior_doubles_ranking)}</td><td class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted micro">Junior simple #${p.junior_ranking||'—'}</div></td><td>${rankAge(p,'junior_doubles')}</td><td>${fmt(p.junior_doubles_points||0)}</td><td>${singlesOnly?'<button class="ghost" disabled>Verrouillé</button>':`<button class="soft-btn" onclick="choosePartner(${p.id})">Associer</button>`}</td></tr>`).join('')}
 </tbody></table></div></div>
 <div id="dblRace" class="section-head" style="margin-top:18px"><div><div class="eyebrow">ATP Finals</div><h2>Race double par équipes</h2><div class="muted">Race double · ${doublesRaceRows[0]?.snapshot_date?df(doublesRaceRows[0].snapshot_date):"snapshot courant"} · ${fmt(doublesRaceRows.length)} équipes chargées.</div></div></div>
 <div class="card"><div class="row between" style="margin-bottom:8px"><span class="muted mini">Historique équipes importé : ${fmt(doublesRaceRows.length)} équipes</span><button class="ghost" onclick="setRankKind(\'doubles\');nav(\'rankings\')">Classement individuel</button></div><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Équipe</th><th>Points</th><th>Référence</th></tr></thead><tbody>
 ${doublesRaceRows.map(x=>`<tr><td class="rank-num">#${x.rank}</td><td><b><span class="click" onclick="openPlayerByName('${esc(String(x.player_one||'').replace(/'/g,"\\'"))}')">${esc(x.player_one)}</span> / <span class="click" onclick="openPlayerByName('${esc(String(x.player_two||'').replace(/'/g,"\\'"))}')">${esc(x.player_two)}</span></b></td><td>${fmt(x.points)}</td><td>${df(x.snapshot_date)}</td></tr>`).join('')}
 </tbody></table></div>${!doublesRaceRows.length?'<div class="loader">Chargement de la Race équipes…</div>':''}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Scouting double</div><h2>Spécialistes disponibles</h2></div></div>
 <div class="grid g2">${candidates.slice(0,20).map(p=>`<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">Double #${p.doubles_ranking}</div><h3>${flags[p.country]||'🏳️'} ${esc(p.name)}</h3><div class="muted mini">${p.ranking?'ATP #'+p.ranking+' · ':''}CA ${p.current_ability} · PA ${p.potential}</div></div>${singlesOnly?'<button class="ghost" disabled>Verrouillé</button>':`<button class="primary" onclick="approachPartner(${p.id})">Approcher</button>`}</div></div>`).join('')}</div>`
}
function universityPage(){
 const teams=management?.college||[],offers=management?.collegeOffers||[],state=management?.collegeState||{},duals=management?.collegeDuals||[],collegeStaff=management?.collegeTeamStaff||[];
 const committed=state.status==='committed',alumni=state.status==='pro';
 return `<div class="section-head"><div><div class="eyebrow">Circuit universitaire</div><h1>NCAA / ITA</h1><div class="muted">Recrutement, bourses, team duals, simple/double, progression académique et passage pro. Le dossier NCAA reste attaché au joueur après son départ.</div></div><span class="pill">${committed?'NCAA actif':alumni?'NCAA Alumni':'Recrutement ouvert'}</span></div>
 <div class="grid g2">
  <div class="card"><h2>Ta situation</h2>${committed?`<div class="hero-name" style="font-size:24px">${esc(state.team?.name||'Université')}</div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Bourse</span><b>${state.scholarship_pct}%</b></div><div class="kpi"><span class="muted mini">Confiance coach</span><b>${state.coach_trust}%</b></div><div class="kpi"><span class="muted mini">Académique</span><b>${state.academic_progress}%</b></div><div class="kpi"><span class="muted mini">Éligibilité</span><b>${state.eligibility_years} ans</b></div></div><p class="muted mini" style="margin-top:10px">Position actuelle : #${state.lineup_position||6} dans le lineup équipe.</p><button class="primary" style="margin-top:10px" onclick="turnProCollege()">Passer professionnel</button><div class="muted micro" style="margin-top:6px">Le passage pro archive et certifie cette carrière NCAA dans la sauvegarde.</div>`:alumni?`<div class="hero-name" style="font-size:24px">${esc(state.team?.name||'Université')}</div><span class="badge good">NCAA Alumni · passage pro enregistré</span><p class="muted mini" style="margin-top:10px">La carrière universitaire et les titres restent visibles dans la fiche joueur.</p>`:'<div class="empty">Tu n’as pas encore choisi d’université. Compare les offres avant de t’engager.</div>'}</div>
  <div class="card"><h2>Top équipes ITA</h2>${teams.slice(0,10).map(t=>`<div class="list-item row between click" onclick="openCollegeTeam(${t.id})"><div><b>#${t.ita_rank} ${esc(t.name)}</b><div class="muted mini">Bilan ${esc(t.record)}</div></div><span class="badge">Voir</span></div>`).join('')}</div>
 </div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Recrutement</div><h2>Offres de bourse</h2></div></div>
 <div class="grid g2">${offers.map(o=>`<div class="card"><div class="row between"><div><div class="eyebrow">ITA #${o.team?.ita_rank||'—'}</div><h2>${esc(o.team?.name||'Université')}</h2></div><span class="badge ${o.status==='accepted'?'good':o.status==='declined'?'bad':''}">${esc(o.status)}</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Bourse</span><b>${o.scholarship_pct}%</b></div><div class="kpi"><span class="muted mini">Fit sportif</span><b>${o.development_fit}</b></div><div class="kpi"><span class="muted mini">Fit académique</span><b>${o.academic_fit}</b></div><div class="kpi"><span class="muted mini">Rôle</span><b style="font-size:12px">${esc(o.role)}</b></div></div>${!committed&&!alumni&&o.status==='available'?`<button class="primary" style="margin-top:10px" onclick="commitCollege(${o.id})">S’engager</button>`:''}</div>`).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Saison équipe</div><h2>Team duals</h2></div></div>
 <div class="stack">${duals.map(d=>`<div class="card"><div class="row between"><div><div class="eyebrow">${df(d.match_date)}</div><h2>${esc(d.home?.name||'Home')} vs ${esc(d.away?.name||'Away')}</h2></div>${d.status==='completed'?`<div class="big" style="font-size:25px">${d.home_score}-${d.away_score}</div>`:alumni?'<span class="badge">Archive NCAA</span>':`<button class="primary" onclick="playCollegeDual(${d.id})">Jouer le dual</button>`}</div><div class="muted mini">${d.status==='completed'?'Rencontre terminée':'Lineup simple + double avant la rencontre'}</div></div>`).join('')||'<div class="card empty">Aucun dual programmé.</div>'}</div>`
}
window.openPlayerByName=async name=>{
 try{
  const d=await get('/api/search-players?q='+encodeURIComponent(name)+'&limit=1');
  const p=(d.rows||[])[0];
  if(p)openPlayer(p.id);
 }catch(e){console.warn(e)}
}
window.openCollegeTeam=id=>{
 const t=(management?.college||[]).find(x=>x.id===id);if(!t)return;
 const offers=(management?.collegeOffers||[]).filter(x=>x.team_id===id);
 const staff=(management?.collegeTeamStaff||[]).filter(x=>Number(x.team_id)===Number(id));
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Programme NCAA</div><h1>#${t.ita_rank} ${esc(t.name)}</h1><div class="muted">Bilan ${esc(t.record)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
 <div class="card"><div class="row between"><h2>Staff du programme</h2><span class="badge">${staff.length}</span></div>${staff.length?staff.map(x=>{const sp=x.staff||{};return `<div class="list-item click" onclick="openStaffProfile(${sp.id})"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)} · ${esc(sp.coaching_style||sp.primary_role||'')}</div></div><div style="text-align:right"><b>${sp.reputation??'—'}/20</b><div class="muted micro">réputation</div></div></div><div class="row between muted micro"><span>Coach ${sp.coach_rating??'—'}</span><span>Tact ${sp.tactical_rating??'—'}</span><span>Jeunes ${sp.youth_rating??'—'}</span><span>Physique ${sp.fitness_rating??'—'}</span></div></div>`}).join(''):'<div class="empty">Staff en cours de génération.</div>'}</div>
 <div class="card" style="margin-top:10px"><h2>Recrutement</h2>${offers.length?offers.map(o=>`<div class="list-item"><div class="row between"><span>Bourse</span><b>${o.scholarship_pct}%</b></div><div class="muted mini">${esc(o.role)} · fit sportif ${o.development_fit}/100</div></div>`).join(''):'<div class="empty">Pas d’offre active.</div>'}</div></div></div>`;
}
window.commitCollege=async id=>{try{await managerAction('commit_college',id);await refreshManagerState();render()}catch(e){alert(e.message)}}
window.turnProCollege=async()=>{try{if(!confirm('Passer professionnel et quitter la NCAA ? Le dossier universitaire restera archivé.'))return;await managerAction('turn_pro_college',1);await refreshManagerState();render()}catch(e){alert(e.message)}}
window.playCollegeDual=async id=>{try{await managerAction('play_college_dual',id);await loadManagement();render()}catch(e){alert(e.message)}}
function davisPage(){
 const f=boot.federation||{},sq=boot.davisSquad||[],ties=management?.davisTies||[],history=management?.davisHistory||[],allDavisStaff=management?.davisTeamStaff||[];
 const federations=boot.federations||[];
 const nation=String(boot.selectedFederation||f.nation||career().country||'FRA').toUpperCase();
 const roles=['Simple 1','Simple 2','Double A','Double B','Réserve'];
 const doublesOnlyManaged=String(career().career_focus||'mixed')==='doubles_only';
 const singlesOnlyManaged=String(career().career_focus||'mixed')==='singles_only';
 const managedId=Number(career().managed_player_id||0);
 const nationStaff=allDavisStaff.filter(x=>String(x.nation||'').toUpperCase()===nation);
 const today=String(local.date||RANKING_SNAPSHOT);
 const nationTies=ties.filter(t=>t.home_nation===nation||t.away_nation===nation).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const nextTie=nationTies.find(t=>t.status!=='completed'&&String(t.tie_date)>=today)||null;
 const lastTie=[...nationTies].reverse().find(t=>t.status==='completed'||String(t.tie_date)<today)||null;
 const focusTie=nextTie||lastTie||nationTies[0]||null;
 const final8=ties.filter(t=>String(t.stage||'').includes('Final 8')).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const worldQualifiers=ties.filter(t=>!String(t.stage||'').includes('Final 8')).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const nationAlive=final8.some(t=>t.home_nation===nation||t.away_nation===nation);
 const seniorHistory=history.filter(x=>x.competition==='senior').sort((a,b)=>b.season-a.season);
 const juniorHistory=history.filter(x=>x.competition==='junior').sort((a,b)=>b.season-a.season);
 const scoreFor=t=>t.home_score!=null&&t.away_score!=null?`${t.home_score}-${t.away_score}`:'vs';
 const tieCard=t=>{const unresolved=/^(TBD|Winner )/i.test(String(t.home_nation||''))||/^(TBD|Winner )/i.test(String(t.away_nation||''));const ready=t.status!=='completed'&&!unresolved;return `<div class="davis-tie-card ${t.status==='completed'?'completed':''} ${ready?'click':''}" ${ready?`onclick="playDavisTie(${t.id})"`:''}>
   <div class="row between"><span class="badge tag-fed">${esc(t.stage||'Coupe Davis')}</span><span class="muted mini">${df(t.tie_date)}</span></div>
   <div class="davis-matchup"><b>${flags[t.home_nation]||'🏳️'} ${esc(t.home_nation)}</b><strong>${scoreFor(t)}</strong><b>${flags[t.away_nation]||'🏳️'} ${esc(t.away_nation)}</b></div>
   <div class="row between" style="margin-top:7px"><div class="muted mini">${esc(t.venue||'Lieu à confirmer')} · <span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span></div>${ready?'<span class="badge warn">Simuler</span>':t.status==='completed'?'<span class="badge good">Terminé</span>':'<span class="badge">En attente</span>'}</div>
 </div>`};
 const historyRows=rows=>rows.map(x=>`<div class="list-item row between"><div><b>${x.season}</b> · ${flags[x.winner_country]||'🏳️'} ${esc(x.winner_country||'Non disputé')}</div><div style="text-align:right"><b>${esc(x.score||'—')}</b><div class="muted micro">${x.runner_up_country?(flags[x.runner_up_country]||'🏳️')+' '+esc(x.runner_up_country):esc(x.venue||'')}</div></div></div>`).join('');
 const selector=`<select class="select" style="min-width:190px" onchange="selectFederation(this.value)">${federations.map(x=>`<option value="${esc(x.nation)}" ${x.nation===nation?'selected':''}>${flags[x.nation]||'🏳️'} ${esc(x.nation)} · ${x.reputation}/100</option>`).join('')}</select>`;
 return `<div class="fm-dashboard">
 <div class="fm-page-head"><div><div class="eyebrow">Équipe nationale</div><h1>Coupe Davis</h1><div class="muted">Fédération sélectionnable · calendrier mondial figé au 01/12/2025 puis simulé par la carrière.</div></div><div class="fm-head-stack">${selector}<div class="fm-head-badge">${flags[nation]||'🏳️'} ${nation} ${f.reputation||'—'}/100</div><div class="fm-head-badge subtle">${nationAlive?'Final 8':'Parcours / qualifications'}</div></div></div>

 <div class="grid g2">
  <div class="card davis-focus">
   <div class="row between"><div><div class="eyebrow">${nextTie?'Prochaine rencontre '+nation:'Dernière rencontre '+nation}</div><h2>${focusTie?`${flags[focusTie.home_nation]||'🏳️'} ${esc(focusTie.home_nation)} ${scoreFor(focusTie)} ${esc(focusTie.away_nation)} ${flags[focusTie.away_nation]||'🏳️'}`:'Aucune rencontre chargée'}</h2></div>${nextTie?'<span class="badge warn">À venir</span>':'<span class="badge">Archive</span>'}</div>
   ${focusTie?`<div class="list-item row between"><span>Date</span><b>${df(focusTie.tie_date)}</b></div><div class="list-item row between"><span>Phase</span><b>${esc(focusTie.stage||'—')}</b></div><div class="list-item row between"><span>Terrain</span><b class="${surfaceClass(surfaceLabel(focusTie))}">${esc(surfaceLabel(focusTie))}</b></div><div class="list-item row between"><span>Lieu</span><b>${esc(focusTie.venue||'—')}</b></div>`:''}
   ${nextTie?'<button class="primary" style="margin-top:10px" onclick="playDavisTie('+nextTie.id+')">Jouer la rencontre</button>':'<div class="notice" style="margin-top:10px">Aucune rencontre future connue pour cette fédération dans le calendrier actuellement chargé.</div>'}
  </div>
  <div class="card"><div class="row between"><div><div class="eyebrow">Sélection</div><h2>${flags[nation]||'🏳️'} ${nation}</h2></div><span class="pill">${sq.length} joueurs</span></div>
   ${sq.map(sqRow=>{const p=sqRow.players;if(!p)return'';const role=local.davisRoles[p.id]||sqRow.role||'Réserve';const ownDoubleOnly=doublesOnlyManaged&&Number(p.id)===managedId;const ownSinglesOnly=singlesOnlyManaged&&Number(p.id)===managedId;const allowedRoles=ownDoubleOnly?roles.filter(r=>!/^Simple/.test(r)):ownSinglesOnly?roles.filter(r=>!/^Double/.test(r)):roles;return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${esc(p.name)} ${ownDoubleOnly?'<span class="badge good">Double uniquement</span>':ownSinglesOnly?'<span class="badge good">Simple uniquement</span>':''}</b><div class="muted mini">ATP #${p.ranking||'—'} · Double #${fmt(p.doubles_ranking||9999)}</div></div><select class="select" style="width:auto" onchange="setDavisRole(${p.id},this.value)">${allowedRoles.map(r=>`<option ${r===role?'selected':''}>${r}</option>`).join('')}</select></div>`}).join('')||'<div class="empty">Aucun joueur sélectionné. La sélection sera générée depuis les meilleurs joueurs du pays.</div>'}
  </div>
 </div>

 <div class="card" style="margin-top:14px"><div class="row between"><div><div class="eyebrow">Encadrement national</div><h2>Staff Coupe Davis</h2></div><span class="pill">${nationStaff.length} membres</span></div>
  <div class="grid g2" style="margin-top:8px">${nationStaff.map(x=>{const sp=x.staff||{};return `<div class="list-item click" onclick="openStaffProfile(${sp.id})"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)}${x.part_time?' · temps partiel':''}</div></div><span class="badge">${sp.reputation??'—'}/20</span></div><div class="row between muted micro"><span>Tact ${sp.tactical_rating??'—'}</span><span>Mental ${sp.mental_rating??'—'}</span><span>Physique ${sp.fitness_rating??'—'}</span><span>Médical ${sp.medical_rating??'—'}</span></div></div>`}).join('')||'<div class="empty">Staff fédéral en cours de génération.</div>'}</div>
 </div>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Parcours ${nation}</div><h2>Rencontres de la fédération</h2></div></div>
 <div class="davis-timeline">${nationTies.map(tieCard).join('')||'<div class="card empty">Aucune rencontre chargée pour cette fédération.</div>'}</div>

 <details class="card davis-world-qualifiers" style="margin-top:16px">
  <summary class="row between"><div><div class="eyebrow">Monde</div><h2>Qualifications Coupe Davis 2025</h2></div><span class="pill">${worldQualifiers.length} rencontres</span></summary>
  <div class="davis-bracket" style="margin-top:10px">${worldQualifiers.map(tieCard).join('')||'<div class="empty">Aucune rencontre mondiale chargée.</div>'}</div>
 </details>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Bologne</div><h2>Final 8 2025</h2><div class="muted">Parcours archivé jusqu’au 01/12/2025.</div></div><span class="badge good">Dur intérieur</span></div>
 <div class="davis-bracket">${final8.map(tieCard).join('')||'<div class="card empty">Tableau Final 8 indisponible.</div>'}</div>

 <div class="grid g2" style="margin-top:18px">
  <details class="card" open><summary><div class="eyebrow">Palmarès officiel</div><h2>Coupe Davis senior · 1900–2025</h2></summary><div class="stack" style="margin-top:10px">${historyRows(seniorHistory)}</div></details>
  <details class="card" open><summary><div class="eyebrow">Palmarès U16</div><h2>Junior Davis Cup · 1985–2025</h2></summary><div class="stack" style="margin-top:10px">${historyRows(juniorHistory)}</div></details>
 </div>

 ${focusTie?.davis_rubbers?.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Détail</div><h2>Rubbers de la rencontre ${nation}</h2></div></div><div class="stack">${focusTie.davis_rubbers.sort((x,y)=>x.rubber_no-y.rubber_no).map(r=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(r.rubber_type)} · Rubber ${r.rubber_no}</div><h2>${esc(r.home_names)} vs ${esc(r.away_names)}</h2></div><div style="text-align:right"><div class="big" style="font-size:22px">${esc(r.score||'—')}</div><span class="badge ${r.winner_nation===nation?'good':'bad'}">${esc(r.winner_nation||'—')}</span></div></div></div>`).join('')}</div>`:''}
 </div>`
}
window.selectFederation=async nation=>{
 try{
  await managerAction('select_federation',1,{nation});
  boot=await get('/api/bootstrap');
  local.career={...(local.career||{}),...(boot.career||{})};
  await loadManagement();
  render();
 }catch(e){alert(e.message)}
}
window.playDavisTie=async id=>{
 try{
  const d=await managerAction('play_davis_tie',id);
  await refreshManagerState();
  if(d.tie&&management?.davisTies){
    const ix=management.davisTies.findIndex(x=>x.id===id);
    if(ix>=0)management.davisTies[ix]={...d.tie,davis_rubbers:d.rubbers||[]};
  }
  render();
 }catch(e){alert(e.message)}
}
function boardPage(){const a=boot.academy||{};return `<div class="section-head"><div><div class="eyebrow">Direction</div><h1>Board</h1><div class="muted">Confiance : ${a.board_confidence||76}%</div></div></div><div class="stack">${(boot.board||[]).map(o=>`<div class="card"><div class="row between"><div><h2>${esc(o.objective)}</h2><div class="muted">${esc(o.target_value||'')} · échéance ${df(o.deadline)}</div></div><b>${o.progress}%</b></div><div class="bar"><i style="width:${o.progress}%"></i></div></div>`).join('')}</div>`}
function worldPage(){
 const w=worldStats||{};
 return `<div class="section-head"><div><div class="eyebrow">Écosystème</div><h1>Monde du tennis</h1><div class="muted">Base mondiale, circuits séparés et simulation persistante.</div></div><button class="ghost" onclick="get('/api/world').then(x=>{worldStats=x;render()})">Actualiser</button></div>
 <div class="kpi-strip">
  <div class="kpi click" onclick="nav('players')"><span class="muted mini">Joueurs réels recherchables</span><b>${fmt(w.searchableRealPlayers||w.realPlayersTotal||w.playersTotal||10000)}</b></div>
  <div class="kpi click" onclick="setRankKind('singles');nav('rankings')"><span class="muted mini">Classés ATP</span><b>${fmt(w.atpRanked??0)}</b></div>
  <div class="kpi click" onclick="nav('calendar')"><span class="muted mini">Tournois</span><b>${fmt(w.tournaments||0)}</b></div>
  <div class="kpi"><span class="muted mini">Tournois vérifiés</span><b>${fmt(w.verifiedTournaments||0)}</b></div>
 </div>
 <div class="menu-grid" style="margin-top:14px">
  <div class="menu-card" onclick="setRankKind('singles');nav('rankings')"><div class="menu-icon">🎾</div><strong>ATP</strong><span class="muted">${fmt(w.atpRanked??0)} joueurs classés</span></div>
  <div class="menu-card" onclick="setRankKind('doubles');nav('rankings')"><div class="menu-icon">◉◉</div><strong>ATP Double</strong><span class="muted">${fmt(w.sourcedDoubles||0)} sourcés · ${fmt(w.indexedDoubles||0)} indexés</span></div>
  <div class="menu-card" onclick="setRankKind('itf');nav('rankings')"><div class="menu-icon">🌍</div><strong>ITF WTT</strong><span class="muted">${fmt(w.itfPlayers||0)} profils avec rang ITF</span></div>
  <div class="menu-card" onclick="setRankKind('junior');nav('rankings')"><div class="menu-icon">🌱</div><strong>Junior</strong><span class="muted">${fmt(w.juniorPlayers||0)} profils juniors</span></div>
  <div class="menu-card" onclick="rankKind='ncaa';rankOffset=0;rankQuery='';loadRankings().then(()=>nav('rankings'))"><div class="menu-icon">🎓</div><strong>NCAA / ITA</strong><span class="muted">${fmt(w.ncaaProfilesTotal||w.ncaaPlayers||0)} profils · ${fmt(w.ncaaActiveProfiles||w.ncaaPlayers||0)} actifs</span></div>
  <div class="menu-card" onclick="nav('scouting')"><div class="menu-icon">🔎</div><strong>Newgens</strong><span class="muted">${fmt(w.gameGenerated||0)} joueurs générés par Court Boss</span></div>
  <div class="menu-card" onclick="nav('competitions')"><div class="menu-icon">🏆</div><strong>Compétitions</strong><span class="muted">ATP, Challenger, ITF, Junior, NCAA, Davis</span></div>
  <div class="menu-card" onclick="nav('history')"><div class="menu-icon">🏛️</div><strong>Histoire & nations</strong><span class="muted">Meilleurs historiques par pays et continent</span></div>
 </div>
 <div class="card" style="margin-top:14px"><div class="row between"><div><div class="eyebrow">Couverture réelle</div><h2>Base de données</h2></div><span class="badge good">${fmt(w.searchableRealPlayers||0)} joueurs</span></div>
 <div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Âges connus</span><b>${fmt(w.realPlayersWithAge||0)}</b></div><div class="kpi"><span class="muted mini">ATP officiel</span><b>${fmt(w.officialATP||0)}</b></div><div class="kpi"><span class="muted mini">Challenger</span><b>${fmt(w.officialChallenger||0)}</b></div><div class="kpi"><span class="muted mini">ITF M15/M25</span><b>${fmt(w.officialITF||0)}</b></div><div class="kpi"><span class="muted mini">Junior vérifié</span><b>${fmt(w.officialJunior||0)}</b></div><div class="kpi"><span class="muted mini">NCAA vérifié</span><b>${fmt(w.officialNCAA||0)}</b></div></div>
 <div class="muted mini" style="margin-top:9px">${w.currentRankedMissingAge?'Il reste '+fmt(w.currentRankedMissingAge)+' âge(s) non renseigné(s) dans le classement ATP courant.':'Classement ATP courant : âge renseigné pour chaque joueur.'} ${w.currentRankedMissingDob?fmt(w.currentRankedMissingDob)+' joueur(s) ont un âge vérifié mais pas encore de date de naissance exacte, donc la date reste N/V.':'Les dates de naissance du classement ATP courant sont complètes.'}</div></div>
 <div class="card" style="margin-top:14px"><h2>Comment le monde évolue</h2><p class="muted">À chaque semaine, les tournois arrivés à terme sont simulés, les points bougent, les classements sont recalculés, les joueurs vieillissent, les blessures évoluent et les palmarès se remplissent. À l'intersaison, retraites et newgens maintiennent le vivier mondial.</p></div>`
}

function historyPage(){
 const d=historyData||{rows:[],countryBest:[],continentBest:[],hallOfFame:[],grandSlamRecords:[],u18:[],u21:[],coverage:{players:0,countries:0,ncaaProfiles:0}};
 const rows=d.rows||[],global=rows[0]||null,rec=d.nationalRecords||{};
 const continents=['','Europe','North America','South America','Asia','Africa','Oceania'];
 const recordCard=(label,x,field,suffix='')=>x?`<div class="fm-record click" onclick="openPlayer(${x.id})"><span>${label}</span><b>${flags[x.country]||'🏳️'} ${esc(x.name)}</b><strong>${fmt(x[field]||0)}${suffix}</strong></div>`:'';
 const youth=(arr,title)=>`<div class="card fm-squad-card"><div class="row between"><div><div class="eyebrow">Prospects</div><h2>${title}</h2></div><span class="badge">${arr.length}</span></div>${arr.slice(0,12).map((p,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${p.id})"><div class="fm-rank-dot">#${i+1}</div><div class="grow"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${p.age} ans · ${p.ranking?'ATP #'+fmt(p.ranking):p.junior_ranking?'Junior #'+fmt(p.junior_ranking):'Non classé'} ${p.game_generated?'· Newgen '+p.generated_year:''}</div></div><div style="text-align:right"><b>CA ${p.current_ability}</b><div class="muted mini">PA ${p.potential}</div></div></div>`).join('')||'<div class="empty">Aucun joueur.</div>'}</div>`;
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Data hub historique · Open Era</div><h1>Histoire, records & nations</h1><div class="muted">Finales ATP indexées depuis 1968, légendes, Hall of Fame, records de Grand Chelem et générations U18/U21 dans la même base.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(d.coverage?.historicalPlayers||0)} historiques</div><div class="fm-head-badge subtle">${fmt(d.coverage?.countries||0)} nations</div><div class="fm-head-badge subtle">${fmt(d.coverage?.ncaaProfiles||0)} NCAA</div></div></div>
  <div class="fm-filterbar">
   <select class="select" onchange="setHistoryCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${historyCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select>
   <select class="select" onchange="setHistoryContinent(this.value)">${continents.map(x=>`<option value="${esc(x)}" ${historyContinent===x?'selected':''}>${x||'Tous continents'}</option>`).join('')}</select>
   <button class="primary" onclick="openHistoryArchive()">Base historique complète</button>
   <button class="ghost" onclick="historyCountry='';historyContinent='';loadHistory().then(render)">Réinitialiser</button>
  </div>
  ${global?`<div class="fm-history-hero card click" onclick="openPlayer(${global.id})"><div><div class="eyebrow">Référence de la sélection</div><div class="hero-name">${flags[global.country]||'🏳️'} ${esc(global.name)}</div><div class="muted">${esc(global.country)} · ${esc(global.continent)} · ${global.career_status==='retired'?'Retraité':'Actif'}</div></div><div class="fm-history-score"><span>Indice historique</span><b>${fmt(global.history_score)}</b></div><div class="fm-history-stats"><div><span>Grand Chelem</span><b>${global.grand_slams}</b></div><div><span>Titres</span><b>${global.titles}</b></div><div><span>Victoires</span><b>${fmt(global.wins)}</b></div><div><span>% victoires</span><b>${global.win_pct==null?'—':global.win_pct+'%'}</b></div></div></div>`:''}

  <div class="fm-record-grid">
   ${recordCard('Record Grand Chelem',rec.grand_slams,'grand_slams',' GC')}
   ${recordCard('Record titres',rec.titles,'titles','')}
   ${recordCard('Record victoires',rec.wins,'wins','')}
   ${recordCard('Semaines n°1 mondial',rec.weeks_at_no1,'weeks_at_no1',' sem.')}
   ${recordCard('Semaines Top 10',rec.weeks_top10,'weeks_top10',' sem.')}
   ${recordCard('Semaines Top 100',rec.weeks_top100,'weeks_top100',' sem.')}
   ${rec.win_pct?`<div class="fm-record click" onclick="openPlayer(${rec.win_pct.id})"><span>Meilleur % victoires</span><b>${flags[rec.win_pct.country]||'🏳️'} ${esc(rec.win_pct.name)}</b><strong>${rec.win_pct.win_pct}%</strong></div>`:''}
  </div>

  <div class="grid g2" style="margin-top:12px">
   <div class="card"><div class="row between"><div><div class="eyebrow">Court Boss Hall of Fame</div><h2>Légendes majeures</h2></div><span class="badge">${(d.hallOfFame||[]).length}</span></div>${(d.hallOfFame||[]).slice(0,40).map((x,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">${i+1}</div><div class="grow"><b>${flags[x.country]||'🏳️'} ${esc(x.name)}</b><div class="muted mini">${x.grand_slams} GC · ${x.titles} titres · ${fmt(x.wins)} victoires</div></div><b>${fmt(x.history_score)}</b></div>`).join('')}</div>
   <div class="card"><div class="row between"><div><div class="eyebrow">Records majeurs</div><h2>Grand Chelem</h2></div><span class="badge">Historique</span></div>${(d.grandSlamRecords||[]).slice(0,24).map((x,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">${i+1}</div><div class="grow"><b>${esc(x.name)}</b><div class="muted mini">${flags[x.country]||'🏳️'} ${esc(x.country)} · ${x.titles} titres</div></div><strong class="a-good">${x.grand_slams} GC</strong></div>`).join('')}</div>
  </div>

  <div class="grid g2" style="margin-top:12px">${youth(d.u18||[],'Top U18')}${youth(d.u21||[],'Top U21')}</div>

  <div class="grid g2" style="margin-top:12px">
   <div class="card"><div class="row between"><div><div class="eyebrow">Par continent</div><h2>Références historiques</h2></div><span class="badge">Top par zone</span></div>${(d.continentBest||[]).filter(x=>x.continent!=='Other').map(x=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">#1</div><div class="grow"><b>${esc(x.continent)} · ${esc(x.name)}</b><div class="muted mini">${flags[x.country]||'🏳️'} ${esc(x.country)} · ${x.grand_slams} GC · ${x.titles} titres</div></div><b>${fmt(x.history_score)}</b></div>`).join('')||'<div class="empty">Pas assez de données historiques.</div>'}</div>
   <div class="card"><div class="row between"><div><div class="eyebrow">Par nationalité</div><h2>Meilleur de chaque pays</h2></div><span class="badge">${fmt((d.countryBest||[]).length)} pays</span></div><div class="fm-country-grid">${(d.countryBest||[]).slice(0,32).map(x=>`<button class="fm-country-tile" onclick="historyContinent='';setHistoryCountry('${esc(x.country)}')"><span>${flags[x.country]||'🏳️'} ${esc(x.country)}</span><b>${esc(x.name)}</b><small>${x.grand_slams} GC · ${x.titles} titres</small></button>`).join('')}</div></div>
  </div>

  <div class="card fm-panel" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Classement historique</div><h2>${historyCountry?'Nationalité '+esc(historyCountry):historyContinent?esc(historyContinent):'Monde'}</h2></div><span class="pill">${fmt(rows.length)} profils</span></div>
   <div class="table-wrap"><table class="table fm-history-table"><thead><tr><th>#</th><th>Joueur</th><th>Pays</th><th>Peak</th><th>Sem. #1</th><th>Top 10</th><th>Top 100</th><th>GC</th><th>Titres</th><th>Indice</th></tr></thead><tbody>${rows.map((x,i)=>`<tr class="click" onclick="openPlayer(${x.id})"><td class="rank-num">#${i+1}</td><td><b>${esc(x.name)}</b><div class="muted micro">${x.career_status==='retired'?'Retraité':'Actif'}</div></td><td>${flags[x.country]||'🏳️'} ${esc(x.country)}</td><td><b>${x.career_high_rank?'#'+fmt(x.career_high_rank):'—'}</b></td><td>${fmt(x.weeks_at_no1||0)}</td><td>${fmt(x.weeks_top10||0)}</td><td>${fmt(x.weeks_top100||0)}</td><td><b>${x.grand_slams}</b></td><td>${x.titles}</td><td class="a-good"><b>${fmt(x.history_score)}</b></td></tr>`).join('')}</tbody></table></div>
  </div>
  <div class="notice mini" style="margin-top:12px">${esc(d.methodology||'Indice historique Court Boss calculé sur les données de carrière importées.')} Le Hall of Fame est une vue du jeu, pas un classement officiel.</div>
 </div>`
}
window.setHistoryCountry=async c=>{historyCountry=String(c||'').toUpperCase();if(c)historyContinent='';await loadHistory();render()}
window.setHistoryContinent=async c=>{historyContinent=String(c||'');if(c)historyCountry='';await loadHistory();render()}
window.openHistoryArchive=()=>{
 overlay.innerHTML="<div class='modal' onclick='if(event.target===this)closeOverlay()'><div class='sheet'><div class='sheet-head'><div><div class='eyebrow'>Open Era 1968–2025</div><h1>Base historique complète</h1><div class='muted'>13 000+ profils historiques, pas seulement le Hall of Fame.</div></div><button class='close' onclick='closeOverlay()'>✕</button></div><div class='filters' style='margin-top:12px'><input id='historyArchiveInput' class='input' placeholder='Connors, Borg, McEnroe, Lendl…' value='"+esc(historyQuery)+"' onkeydown='if(event.key===\"Enter\")runHistoryArchiveSearch(this.value,0)'><select id='historyArchiveCountry' class='select' onchange='runHistoryArchiveSearch(document.getElementById(\"historyArchiveInput\").value,0)'><option value=''>Toutes nationalités</option>"+countryRows.map(x=>"<option value='"+esc(x.country)+"' "+(historyCountry===x.country?"selected":"")+">"+(flags[x.country]||"🏳️")+" "+esc(x.country)+"</option>").join("")+"</select><button class='primary' onclick='runHistoryArchiveSearch(document.getElementById(\"historyArchiveInput\").value,0)'>Rechercher</button></div><div id='historyArchiveResults' style='margin-top:12px'><div class='loader'>Chargement de l’archive…</div></div></div></div>";
 runHistoryArchiveSearch(historyQuery||"",historyDbOffset||0);
}
window.runHistoryArchiveSearch=async(q,offset=0)=>{
 historyQuery=String(q||"").trim();historyDbOffset=Math.max(0,Number(offset)||0);
 const box=document.getElementById("historyArchiveResults");if(!box)return;
 box.innerHTML="<div class='loader'>Recherche historique…</div>";
 try{
  const country=document.getElementById("historyArchiveCountry")?.value||"";
  const p=new URLSearchParams({offset:String(historyDbOffset),limit:"100"});
  if(historyQuery)p.set("q",historyQuery);
  if(country)p.set("country",country);
  const d=await get("/api/history-players?"+p.toString());
  historyDbRows=d.rows||[];historyDbCount=d.count||0;
  const body=historyDbRows.map((x,i)=>"<tr class='click' onclick='openPlayer("+x.id+")'><td class='rank-num'>#"+fmt(historyDbOffset+i+1)+"</td><td><b>"+esc(x.name)+"</b><div class='muted micro'>"+(x.career_status==="retired"?"Retraité":"Actif")+"</div></td><td>"+(flags[x.country]||"🏳️")+" "+esc(x.country||"—")+"</td><td><b>"+(x.career_high_rank?"#"+fmt(x.career_high_rank):"—")+"</b></td><td>"+fmt(x.weeks_at_no1||0)+"</td><td>"+fmt(x.weeks_top10||0)+"</td><td>"+fmt(x.weeks_top100||0)+"</td><td><b>"+fmt(x.grand_slams||0)+"</b></td><td>"+fmt(x.titles||0)+"</td><td>"+fmt(x.wins||0)+"</td><td class='a-good'><b>"+fmt(x.history_score||0)+"</b></td></tr>").join("");
  box.innerHTML="<div class='row between'><div><div class='eyebrow'>Résultats</div><h2>"+(historyQuery?"Recherche : "+esc(historyQuery):"Archive complète")+"</h2></div><span class='pill'>"+fmt(historyDbCount)+" profils</span></div><div class='table-wrap'><table class='table fm-history-table'><thead><tr><th>#</th><th>Joueur</th><th>Pays</th><th>Peak</th><th>Sem. #1</th><th>Top 10</th><th>Top 100</th><th>GC</th><th>Titres</th><th>Victoires</th><th>Indice</th></tr></thead><tbody>"+body+"</tbody></table></div><div class='pagination'><button "+(historyDbOffset===0?"disabled":"")+" onclick='historyArchivePage(-1)'>←</button><span class='muted mini'>"+(historyDbCount?fmt(historyDbOffset+1):0)+"–"+fmt(Math.min(historyDbOffset+historyDbRows.length,historyDbCount))+" / "+fmt(historyDbCount)+"</span><button "+(historyDbOffset+100>=historyDbCount?"disabled":"")+" onclick='historyArchivePage(1)'>→</button></div>";
 }catch(e){box.innerHTML="<div class='empty'>Recherche impossible : "+esc(e.message)+"</div>"}
}
window.historyArchivePage=d=>runHistoryArchiveSearch(historyQuery,Math.max(0,historyDbOffset+Number(d)*100));


function abilityStarValue(score){
 const n=Math.max(0,Math.min(100,Number(score||0)));
 return Math.max(.5,Math.min(5,Math.round(n/10)/2));
}
function starRatingHtml(value,label=''){
 const v=Math.max(.5,Math.min(5,Number(value||0)));
 const full=Math.floor(v),half=v-full>=.5;
 const glyph='★'.repeat(full)+(half?'◐':'')+'☆'.repeat(Math.max(0,5-full-(half?1:0)));
 return `<span class="player-star-rating" title="${esc(label||'')}"><span class="player-star-glyph">${glyph}</span><b>${v.toFixed(1)}</b></span>`;
}
function publicLevelStars(p){
 const r=Number(p?.ranking||p?.game_world_rank||999999);
 if(r<=5)return 5;
 if(r<=20)return 4.5;
 if(r<=60)return 4;
 if(r<=150)return 3.5;
 if(r<=350)return 3;
 if(r<=800)return 2.5;
 if(r<=1800)return 2;
 return 1.5;
}
function playerKnowledgeLabel(isManaged,report){
 if(isManaged)return 'Connaissance complète';
 if(report)return 'Rapport scout · '+Number(report.confidence||0)+'%';
 return 'Connaissance publique';
}
function developmentTypeLabel(v){
 return v==='early'?'Précoce':v==='late'?'Tardif':'Standard';
}
function developmentTypeDescription(v){
 return v==='early'?'Progression rapide et pic plus jeune.'
  :v==='late'?'Progression plus lente avec marge de développement plus tardive.'
  :'Courbe de progression équilibrée, pic généralement au milieu de la vingtaine.';
}
function playerTraitBadges(attrs={},dev={},focus='mixed',report=null){
 const n=k=>Number(attrs?.[k]);
 const ok=k=>Number.isFinite(n(k));
 const out=[];
 const add=(label,kind='')=>{if(!out.some(x=>x.label===label))out.push({label,kind})};
 if(ok('serve_power')&&ok('first_serve_quality')&&n('serve_power')>=17&&n('first_serve_quality')>=16)add('Gros serveur','good');
 if(ok('second_serve_quality')&&n('second_serve_quality')>=16)add('2e balle fiable','good');
 if(ok('return_aggression')&&n('return_aggression')>=16)add('Agressif en retour','good');
 if(ok('return_consistency')&&n('return_consistency')>=17)add('Mur en retour','good');
 if(ok('forehand_power')&&n('forehand_power')>=17)add('Coup droit destructeur','good');
 if(ok('backhand_accuracy')&&n('backhand_accuracy')>=17)add('Revers très sûr','good');
 if(ok('drop_shot')&&ok('touch')&&n('drop_shot')>=16&&n('touch')>=15)add('Amortie naturelle','good');
 if(ok('volley')&&ok('net_positioning')&&n('volley')>=16&&n('net_positioning')>=15)add('Instinct au filet','good');
 if(ok('poaching')&&n('poaching')>=16)add('Poaching agressif','good');
 if(ok('big_points')&&n('big_points')>=17)add('Clutch','good');
 if(ok('consistency')&&n('consistency')>=17)add('Très régulier','good');
 if(ok('decision_making')&&ok('shot_selection')&&n('decision_making')>=16&&n('shot_selection')>=16)add('Lecture tactique','good');
 if(ok('speed')&&ok('agility')&&n('speed')>=17&&n('agility')>=16)add('Déplacements explosifs','good');
 if(ok('stamina')&&ok('natural_fitness')&&n('stamina')>=17&&n('natural_fitness')>=15)add('Endurance élite','good');
 if(ok('aggression')&&n('aggression')>=17)add('Prend l’initiative');
 if(ok('patience')&&n('patience')>=17)add('Construit les points');
 if(ok('consistency')&&n('consistency')<=8)add('Irrégulier','bad');
 if(ok('second_serve_quality')&&n('second_serve_quality')<=8)add('2e balle attaquable','bad');
 if(ok('big_points')&&n('big_points')<=8)add('Fragile sous pression','bad');
 if(focus==='doubles_only')add('Spécialiste double','good');
 if(String(dev?.development_type||'')==='late')add('Éclosion tardive');
 if(String(dev?.development_type||'')==='early')add('Précoce');
 if(report?.injury_risk_read==='Élevé')add('Risque physique élevé','bad');
 return out.slice(0,10);
}
function careerFocusLabel(v){
 return v==='singles_only'?'Simple exclusivement':v==='doubles_only'?'Double exclusivement':v==='singles_priority'?'Simple prioritaire':'Simple + double';
}
function careerFocusDescription(v){
 return v==='singles_only'
  ?'Aucun tableau de double. Toute la saison, le staff et les objectifs sont construits autour du simple.'
  :v==='doubles_only'
    ?'Aucune inscription en simple. Le classement simple décroît naturellement et ton calendrier se construit autour du double.'
    :v==='singles_priority'
      ?'Le simple reste l’objectif principal, mais tu peux jouer du double ponctuellement.'
      :'Simple et double sont menés en parallèle avec deux classements actifs.';
}
function careerDoublesRankText(c=career()){
 const strict=String(c?.career_focus||'mixed')==='singles_only';
 const pts=Number(c?.doubles_points||0);
 return strict&&pts<=0?'NR':(c?.doubles_rank?'#'+fmt(c.doubles_rank):'NR');
}
function myPlayerPage(){
 const c=career(),focus=String(c.career_focus||'mixed');
 const modes=[
  ['singles_only','Simple exclusivement','Aucun double : calendrier, objectifs et sélection centrés à 100 % sur le simple.'],
  ['singles_priority','Simple prioritaire','ATP simple au centre du projet, double occasionnel.'],
  ['mixed','Simple + double','Deux carrières menées en parallèle.'],
  ['doubles_only','Double exclusivement','Plus aucun tableau simple, carrière construite autour des paires et de la Race double, avec une longévité potentiellement supérieure.']
 ];
 return `<div class="section-head"><div><div class="eyebrow">Carrière</div><h1>Mon joueur</h1><div class="muted">Personnalise ton joueur géré et définis sa trajectoire sportive.</div></div></div>
 <div class="card" style="margin-bottom:12px">
  <div class="row between"><div><div class="eyebrow">Orientation de carrière</div><h2>${careerFocusLabel(focus)}</h2><div class="muted mini">${careerFocusDescription(focus)}</div></div><span class="badge ${focus==='doubles_only'?'good':focus==='singles_priority'?'warn':''}">${careerFocusLabel(focus)}</span></div>
  <div class="grid g2 career-focus-grid" style="margin-top:10px">
   ${modes.map(m=>`<button class="card click career-focus-card ${focus===m[0]?'career-focus-active':''}" onclick="setCareerFocus('${m[0]}')"><div class="eyebrow">${focus===m[0]?'Actif':'Choisir'}</div><h3>${m[1]}</h3><div class="muted mini">${m[2]}</div></button>`).join('')}
  </div>
  <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px">
   <span class="badge">Dernier changement : ${df(c.career_focus_changed_at||'2025-12-01')}</span>
   <span class="badge">${fmt(c.career_focus_switches||0)} changement(s)</span>
   ${focus==='doubles_only'?'<span class="badge good">Inscriptions simple verrouillées</span>':focus==='singles_only'?'<span class="badge good">Inscriptions double verrouillées</span>':''}
  </div>
 </div>
 <div class="grid g2"><div class="card"><h2>Identité</h2><label class="mini muted">Nom</label><input class="input" value="${esc(c.player_name)}" onchange="editCareer('player_name',this.value)"><label class="mini muted">Pays</label><input class="input" value="${esc(c.country)}" onchange="editCareer('country',this.value)"><label class="mini muted">Style</label><select class="select" onchange="editCareer('style',this.value)">${['Attaquant polyvalent','Attaquant fond de court','Contreur','All-court','Serveur-volée'].map(x=>`<option ${x===c.style?'selected':''}>${x}</option>`).join('')}</select></div>
 <div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">ATP</span><b>#${fmt(c.singles_rank)}</b></div><div class="statbox"><span class="muted mini">Double</span><b>${careerDoublesRankText(c)}</b></div><div class="statbox"><span class="muted mini">CA</span><b>${c.current_ability||56}</b></div><div class="statbox"><span class="muted mini">PA</span><b>${c.potential||82}</b></div></div><div class="list-item row between"><span>Âge</span><input class="input" style="max-width:100px" type="number" value="${c.age||19}" onchange="editCareer('age',Number(this.value))"></div><div class="list-item row between"><span>Taille</span><input class="input" style="max-width:100px" type="number" value="${c.height_cm||184}" onchange="editCareer('height_cm',Number(this.value))"></div><div class="list-item row between"><span>Poids</span><input class="input" style="max-width:100px" type="number" value="${c.weight_kg||78}" onchange="editCareer('weight_kg',Number(this.value))"></div></div></div>`
}
function fantasyPage(){
 const rows=local.fantasy||[];
 return `<div class="section-head"><div><div class="eyebrow">Mode créatif</div><h1>Fantasy Court</h1><div class="muted">Crée ton propre tournoi, surface et format.</div></div><button class="primary" onclick="createFantasy()">Nouveau tournoi</button></div><div class="stack">${rows.map((t,i)=>`<div class="card click" onclick="openFantasy(${i})"><div class="row between"><div><div class="eyebrow">${esc(t.category)}</div><h2>${esc(t.name)}</h2><div class="muted">${esc(surfaceLabel(t))} · ${t.draw} joueurs</div></div><button class="danger-btn" onclick="event.stopPropagation();deleteFantasy(${i})">Supprimer</button></div></div>`).join('')||'<div class="card empty">Aucun tournoi personnalisé. Crée le premier.</div>'}</div>`
}
function inboxPage(){return `<div class="section-head"><div><div class="eyebrow">Communication</div><h1>Boîte de réception</h1></div></div><div class="stack">${(boot.inbox||[]).map(x=>`<div class="card click" onclick="openInboxItem(${x.id},'${esc(x.action_route||'home')}')"><div class="row between"><div class="eyebrow">${esc(x.kind)}</div><span class="badge ${x.is_read?'':'good'}">${x.is_read?'Lu':'Nouveau'}</span></div><h2>${esc(x.title)}</h2><p class="muted">${esc(x.body)}</p></div>`).join('')}</div>`}
function render(){
 if(!boot)return;
 const views={home,rankings,calendar,competitions:competitionsPage,academy,more,players:playersPage,training,scouting,staff:staffPage,contracts:contractsPage,finance:financePage,medical:medicalPage,match:matchPage,tactics:tacticsPage,fantasy:fantasyPage,doubles:doublesPage,university:universityPage,davis:davisPage,board:boardPage,world:worldPage,history:historyPage,myplayer:myPlayerPage,fantasy:fantasyPage,inbox:inboxPage};
 shell((views[route]||more)());
}
window.openPlayer=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du dossier joueur…</div></div></div>';
 try{
  const d=await get('/api/player?id='+id),p=d.player;if(!p)throw new Error('Joueur introuvable');
  const a=p.player_attributes||{},dev=d.developmentProfile||{},devHistory=d.developmentHistory||[],advanced=d.advancedMetrics||{},elo=d.eloRating||{},surfacePref=d.surfacePreference||{},h2hManaged=d.h2hWithManaged||null,matchupPreviews=d.matchupPreviews||{},styleHistory=d.styleHistory||[],tacticalProfile=d.tacticalProfile||{},tacticalTraits=d.tacticalTraits||[],seasonPlan=d.seasonPlan||null,scoutReport=d.scoutingReport||null,isManaged=Number(p.id)===Number(career().managed_player_id||0),knownAttrs=isManaged?a:(scoutReport?.attribute_estimates||{}),ncaaRows=d.ncaa||[],ncaaCareer=d.ncaaCareer||null,legend=d.legend||null,playerStaff=d.staff||[],playerStaffHistory=d.staffHistory||[],playerStaffBonds=d.staffBonds||[],relationships=d.relationships||[],agencyRepresentation=d.agencyRepresentation||null,agencyHistory=d.agencyHistory||[],careerFocusHistory=d.careerFocusHistory||[],primaryDoubles=d.primaryDoublesCommitment||null,doublesPartnerHistory=d.doublesPartnerHistory||[];
  const currentStars=isManaged?Number(dev.current_star_rating??abilityStarValue(p.current_ability)):Number(scoutReport?.estimated_current_stars??publicLevelStars(p));
  const potentialStars=isManaged?Number(dev.potential_star_rating??abilityStarValue(p.potential)):(scoutReport?.estimated_potential_stars!=null?Number(scoutReport.estimated_potential_stars):null);
  const potentialMin=isManaged?Number(dev.potential_star_min??abilityStarValue(p.potential)):(scoutReport?.estimated_potential_star_min!=null?Number(scoutReport.estimated_potential_star_min):null);
  const potentialMax=isManaged?Number(dev.potential_star_max??abilityStarValue(p.potential)):(scoutReport?.estimated_potential_star_max!=null?Number(scoutReport.estimated_potential_star_max):null);
  const traitDev=isManaged?dev:{development_type:String(scoutReport?.development_type_read||'').includes('late')?'late':String(scoutReport?.development_type_read||'').includes('early')?'early':''};
  const playerTraits=playerTraitBadges(knownAttrs,traitDev,String(p.career_focus||'mixed'),scoutReport);
  const ncaa=p.ncaa_current?(ncaaRows.find(x=>String(x.status||'')==='Active')||null):null;
  const ncaaIsAlumni=String(p.ncaa_status||'')==='Alumni'||String(ncaaCareer?.status||'')==='Alumni';
  const ncaaHistorical=!p.ncaa_current&&!!p.ncaa_verified&&!ncaaIsAlumni;
  const allTitles=d.titles||[];
  const hasCanonicalSingles=allTitles.some(t=>t.origin==='sackmann_atp_canonical'&&t.event_type==='singles');
  const singlesTitles=allTitles.filter(t=>(!t.event_type||t.event_type==='singles')&&(!hasCanonicalSingles||t.origin==='sackmann_atp_canonical'||t.origin==='game'));
  const doublesTitles=allTitles.filter(t=>t.event_type==='doubles');
  const juniorSinglesTitles=allTitles.filter(t=>t.event_type==='junior_singles');
  const juniorDoublesTitles=allTitles.filter(t=>t.event_type==='junior_doubles');
  const collegeTitles=allTitles.filter(t=>/^ncaa_|^college_/.test(String(t.event_type||'')));
  const titleCount=hasCanonicalSingles?singlesTitles.length:(legend?.titles??singlesTitles.length);
  const slamCount=legend?.grand_slams??singlesTitles.filter(t=>/Grand Chelem|Grand Slam/i.test(String(t.level||''))).length;
  const mastersCount=legend?.masters??singlesTitles.filter(t=>/Masters 1000|Masters/i.test(String(t.level||''))).length;
  const hardTitles=singlesTitles.filter(t=>/Hard|Dur/i.test(String(t.surface||''))).length;
  const clayTitles=singlesTitles.filter(t=>/Clay|Terre/i.test(String(t.surface||''))).length;
  const grassTitles=singlesTitles.filter(t=>/Grass|Gazon/i.test(String(t.surface||''))).length;
  const cs=d.careerStats||{};
  const titleYears=Object.entries((d.titles||[]).reduce((acc,t)=>{
    const y=String(t.title_date||'').slice(0,4)||'—';
    acc[y]=(acc[y]||0)+1;return acc;
  },{})).sort((a,b)=>Number(b[0])-Number(a[0]));
  const levelCounts=(d.titles||[]).reduce((acc,t)=>{
    const raw=String(t.level||'ATP');
    const key=/Grand Chelem|Grand Slam/i.test(raw)?'Grand Chelem':/Masters 1000|Masters/i.test(raw)?'Masters 1000':/Finals/i.test(raw)?'ATP Finals':/Challenger/i.test(raw)?'Challenger':/Davis/i.test(raw)?'Coupe Davis':'ATP Tour';
    acc[key]=(acc[key]||0)+1;return acc;
  },{});
  const historicalSeasonRows=d.historicalSeasons||[];
  const weightedSeason=x=>Number(x?.grand_slams||0)*100+Number(x?.masters||0)*35+Number(x?.tour_finals||0)*30+Number(x?.titles||0)*5;
  const bestHistoricalSeason=historicalSeasonRows.length
    ?historicalSeasonRows.filter(x=>Number(x.season)<=2025).sort((a,b)=>weightedSeason(b)-weightedSeason(a)||Number(b.season)-Number(a.season))[0]||null
    :null;
  const bestSeason=bestHistoricalSeason
    ?[String(bestHistoricalSeason.season),Number(bestHistoricalSeason.titles||0)]
    :(titleYears.length?titleYears.reduce((best,x)=>Number(x[1])>Number(best[1])?x:best,titleYears[0]):null);
  const personalityLabel=String(p.personality||'Profil à découvrir');
  const personalityText=String(p.personality_description||'La personnalité de jeu sera affinée avec le scouting et l’évolution de carrière.');
  const personalityKind=String(p.personality_kind||'simulated');
  const personalitySource=String(p.personality_source||'Court Boss · profil de jeu simulé');
  const finalRows=d.finals||[];
  const runnerUpCount=finalRows.filter(x=>x.result==='Finaliste').length;
  const finalsWon=finalRows.filter(x=>x.result==='Champion').length;
  const finalConversion=finalRows.length?Math.round(finalsWon/finalRows.length*100):0;
  const firstTitle=(d.titles||[]).length?(d.titles||[])[(d.titles||[]).length-1]:null;
  const lastTitle=(d.titles||[])[0]||null;
  const realMatches=Number(cs.wins||0)+Number(cs.losses||0);
  const realWinPct=realMatches?Math.round(Number(cs.wins||0)/realMatches*100):0;
  const pct=(w,l)=>Number(w||0)+Number(l||0)?Math.round(Number(w||0)/(Number(w||0)+Number(l||0))*100):0;
  const surfacePct=(w,l)=>w==null||l==null?'Non renseigné':pct(w,l)+'%';
  const groups=[
   ['Service',[['Puissance','serve_power'],['Précision','serve_precision'],['1re balle','first_serve_quality'],['2e balle','second_serve_quality'],['Variété','serve_variety']]],
   ['Fond de court',[['Coup droit','forehand'],['Puissance CD','forehand_power'],['Précision CD','forehand_accuracy'],['Revers','backhand'],['Puissance RV','backhand_power'],['Précision RV','backhand_accuracy'],['Slice','slice']]],
   ['Retour & toucher',[['Retour','return_game'],['Retour agressif','return_aggression'],['Régularité retour','return_consistency'],['Passing-shot','passing_shot'],['Réaction','reaction'],['Toucher','touch'],['Amortie','drop_shot'],['Lob','lob']]],
   ['Jeu au filet',[['Volée','volley'],['Demi-volée','half_volley'],['Smash','smash'],['Placement filet','net_positioning'],['Poaching','poaching']]],
   ['Physique',[['Déplacements','movement'],['Vitesse','speed'],['Accélération','acceleration'],['Agilité','agility'],['Équilibre','balance'],['Endurance','stamina'],['Force','strength'],['Défense','defensive_skill'],['Tolérance rallye','rally_tolerance'],['Fitness naturel','natural_fitness'],['Récupération','recovery'],['Souplesse','flexibility']]],
   ['Mental',[['Anticipation','anticipation'],['Concentration','concentration'],['Sang-froid','composure'],['Combativité','fighting_spirit'],['Détermination','determination'],['Confiance','confidence'],['Killer instinct','killer_instinct'],['Grands points','big_points'],['Régularité','consistency'],['Volume de travail','work_rate']]],
   ['Tactique',[['Tactique','tactics'],['Décisions','decision_making'],['Sélection de coups','shot_selection'],['Position court','court_positioning'],['Transition','transition_game'],['Défense → attaque','defense_to_attack'],['Service +1','serve_plus_one'],['Agressivité','aggression'],['Patience','patience'],['Adaptabilité','adaptability'],['Leadership','leadership']]],
   ['Double & surfaces',[['Aptitude double','doubles'],['Communication','doubles_communication'],['Terre battue','clay_affinity'],['Dur','hard_affinity'],['Gazon','grass_affinity']]]
  ];
  const nat=countryTheme(p.country);
  const races=d.races||{};
  const rankBits=[];
  if(p.ranking_current&&p.ranking!=null)rankBits.push('ATP #'+fmt(p.ranking));
  if(p.doubles_ranking!=null&&p.doubles_source)rankBits.push('Double #'+fmt(p.doubles_ranking)+(p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''));
  if(p.race_ranking!=null&&p.race_source)rankBits.push('Race #'+fmt(p.race_ranking)+(p.race_snapshot_date?' · '+df(p.race_snapshot_date):''));
  if(p.nextgen_ranking!=null&&p.nextgen_source)rankBits.push('Next Gen #'+fmt(p.nextgen_ranking)+(p.nextgen_snapshot_date?' · '+df(p.nextgen_snapshot_date):''));
  if(p.junior_doubles_ranking!=null)rankBits.push('Junior Double #'+fmt(p.junior_doubles_ranking));
  if(races.junior?.rank!=null)rankBits.push('Race Junior #'+fmt(races.junior.rank)+(races.junior.status==='qualified'?' · Qualifié Finals':''));
  if(races.doubles?.rank!=null)rankBits.push('Race Double #'+fmt(races.doubles.rank)+(races.doubles.status==='qualified'?' · Qualifié Finals':''));
  if(races.juniorDoubles?.rank!=null)rankBits.push('Race Junior Double #'+fmt(races.juniorDoubles.rank)+(races.juniorDoubles.status==='qualified'?' · Qualifié Finals':''));
  if(p.junior_ranking!=null){const jx=p.junior_rank_type==='official'&&p.junior_official_ranking!=null?' · ITF officiel #'+fmt(p.junior_official_ranking):p.junior_rank_type==='verified_nr'?' · rang estimé':p.game_generated?' · simulé':'';rankBits.push('Junior #'+fmt(p.junior_ranking)+jx);}
  if(p.ncaa_current)rankBits.push('NCAA actif'+(ncaa?.ita_rank?' ITA #'+fmt(ncaa.ita_rank):p.ncaa_rank?' ITA #'+fmt(p.ncaa_rank):'')+(ncaa?.utr_rating!=null?' · UTR '+(ncaa.utr_verified?'':'~')+Number(ncaa.utr_rating).toFixed(2):'')+(ncaa?.school?' · '+ncaa.school:p.ncaa_school?' · '+p.ncaa_school:''));
  else if(ncaaIsAlumni)rankBits.push('NCAA Alumni'+((ncaaCareer?.verified||p.ncaa_verified)?' certifié':'')+' · '+(ncaaCareer?.school||p.ncaa_last_school||'Université'));
  else if(ncaaHistorical)rankBits.push((p.ncaa_status||'NCAA historique')+(p.ncaa_last_school?' · '+p.ncaa_last_school:''));
  const isRetired=String(p.career_status||'active')==='retired';
  const rankSummary=isRetired?'Retraité · historique carrière':(rankBits.length?rankBits.join(' · '):'Non classé actuellement');
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier joueur ${isRetired?'· Légende':''}</div><h1>${flags[p.country]||'🏳️'} ${esc(p.name)} ${isRetired?'<span class="badge">Retraité</span>':''}</h1><div class="muted">${esc(rankSummary)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="tabs" style="margin-top:12px"><button class="active" data-player-tab="profile" onclick="playerSection('profile')">Profil</button><button data-player-tab="attrs" onclick="playerSection('attrs')">Attributs</button><button data-player-tab="analytics" onclick="playerSection('analytics')">Analytics</button><button data-player-tab="development" onclick="playerSection('development')">Développement</button><button data-player-tab="matches" onclick="playerSection('matches')">Matchs</button><button data-player-tab="double" onclick="playerSection('double')">Double</button><button data-player-tab="career" onclick="playerSection('career')">Palmarès</button><button data-player-tab="commercial" onclick="playerSection('commercial')">Commercial</button><button data-player-tab="history" onclick="playerSection('history')">Historique</button></div>
   <div id="playerBody">
    <div class="card fm-player-header" style="margin-bottom:12px;border-left:5px solid ${nat.a};background:linear-gradient(125deg,${nat.a}24,${nat.b}18 46%,rgba(7,25,17,.96) 78%)"><div class="row" style="align-items:center;gap:16px"><div style="width:142px;height:166px;border-radius:18px;overflow:hidden;background:#10251c;display:flex;align-items:center;justify-content:center;flex:0 0 auto;border:2px solid ${nat.a};box-shadow:0 0 0 3px ${nat.b}40">${playerPhotoMarkup(p)}</div><div><div class="eyebrow">${flags[p.country]||'🏳️'} ${esc(p.country||'')} · ${p.is_real?'Identité réelle':'Joueur généré Court Boss'}</div><h2 style="margin:2px 0 5px">${esc(p.name)}</h2><div class="muted">${p.birth_date?'Né le '+df(p.birth_date)+' · '+ageLabel(p,true):p.age!=null?(ageLabel(p,true)+' · date de naissance non vérifiée'):'Âge non vérifié'}</div><div class="row" style="margin-top:8px;flex-wrap:wrap">${!isRetired?`<span class="badge ${String(p.career_focus||'mixed')==='doubles_only'?'good':''}">${careerFocusLabel(p.career_focus||'mixed')}</span>`:''}${playerPhotoSourceLabel(p)?`<span class="badge">${esc(playerPhotoSourceLabel(p))}</span>`:''}${ncaa?`<span class="badge good">NCAA actif · ${esc(ncaa.school||p.ncaa_school||'Université')} · #${ncaa.ita_rank||p.ncaa_rank||'—'}</span>`:ncaaIsAlumni?`<span class="badge">NCAA Alumni${ncaaCareer?.verified||p.ncaa_verified?' certifié':''} · ${esc(ncaaCareer?.school||p.ncaa_last_school||'Université')}</span>`:ncaaHistorical?`<span class="badge">NCAA historique · ${esc(p.ncaa_last_school||ncaaCareer?.school||'Université')} · statut actuel non vérifié</span>`:''}${Array.isArray(p.circuits_2025)&&p.circuits_2025.map(c=>`<span class="badge">${esc(c)}</span>`).join('')}</div></div></div></div>
    <div class="grid g2"><div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">Âge au 01/12/2025</span><b>${esc(ageLabel(p,false))}</b><small class="muted micro">${/estim/i.test(String(p.age_source||''))?'estimé':'sourcé'}</small></div><div class="statbox"><span class="muted mini">Taille</span><b>${p.height_cm?p.height_cm+' cm':'—'}</b><small class="muted micro">${p.height_cm?(p.height_verified?'sourcée':'estimée'):''}</small></div><div class="statbox"><span class="muted mini">Main</span><b style="font-size:15px">${esc(p.handedness||'—')}</b></div><div class="statbox"><span class="muted mini">Revers</span><b style="font-size:15px">${esc(p.backhand||'2 mains')}</b><small class="muted micro">${p.backhand_verified?'sourcé':'estimé'}</small></div><div class="statbox"><span class="muted mini">Style</span><b style="font-size:15px">${esc(p.style||'—')}</b></div></div><div class="muted micro" style="margin-top:8px">Revers : ${esc(p.backhand_source||'Estimation Court Boss · non sourcée')}${p.birth_date_source?' · DOB : '+esc(p.birth_date_source):''}${p.age_source?' · Âge : '+esc(p.age_source):''}${p.height_source?' · Taille : '+esc(p.height_source):''}${p.weight_source?' · Poids : '+esc(p.weight_source):''}</div>
<div class="player-bio-grid" style="margin-top:10px">
 ${p.weight_kg?`<div class="list-item row between"><span>Poids</span><span><b>${p.weight_kg} kg</b> <span class="muted micro">${p.weight_verified?'sourcé':'estimé'}</span></span></div>`:''}
 ${p.birthplace?`<div class="list-item row between"><span>Lieu de naissance</span><b>${esc(p.birthplace)}</b></div>`:''}
 ${p.turned_pro_year?`<div class="list-item row between"><span>Passage pro</span><b>${p.turned_pro_year}</b></div>`:''}
 ${p.coaches&&!playerStaff.length?`<div class="list-item row between"><span>Coach(s)</span><b>${esc(p.coaches)}</b></div>`:''}
</div>
${!isRetired?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Orientation de carrière</div><h3 style="margin:2px 0">${careerFocusLabel(p.career_focus||'mixed')}</h3></div><span class="badge ${String(p.career_focus||'mixed')==='doubles_only'?'good':''}">${p.career_focus_source==='Utilisateur'?'Choix joueur':'Simulation Court Boss'}</span></div>
 <div class="muted mini">${esc(p.career_focus_reason||careerFocusDescription(p.career_focus||'mixed'))}</div>
 ${careerFocusHistory.length?`<div style="margin-top:8px">${careerFocusHistory.slice(0,5).map(x=>`<div class="list-item row between"><div><b>${careerFocusLabel(x.to_focus)}</b><div class="muted micro">${esc(x.reason||'Changement de trajectoire')}</div></div><div style="text-align:right"><span class="badge">${df(x.changed_at)}</span><div class="muted micro">${esc(x.source||'Court Boss')}</div></div></div>`).join('')}</div>`:''}
</div>`:''}
${agencyRepresentation?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Représentation</div><h3 style="margin:2px 0">Agent & agence</h3></div><span class="badge">Confiance ${agencyRepresentation.trust??'—'}/100</span></div>
 <div class="list-item"><div class="row between"><div><b>${esc(agencyRepresentation.agency?.name||'Agence')}</b><div class="muted mini">Commission ${agencyRepresentation.commission_pct??'—'}% · depuis ${df(agencyRepresentation.start_date)}</div></div><div style="text-align:right"><b class="click" onclick="openStaffProfile(${agencyRepresentation.agent?.id})">${esc(agencyRepresentation.agent?.name||'Agent')}</b><div class="muted micro">Négociation ${agencyRepresentation.agent?.negotiation_rating??'—'}/20 · rep ${agencyRepresentation.agent?.reputation??'—'}/20</div></div></div></div>
 ${agencyHistory.length?`<div class="muted micro" style="margin:6px 0">Historique de représentation</div>${agencyHistory.slice(0,4).map(x=>`<div class="list-item row between"><div><b>${esc(x.agency?.name||'Agence')}</b><div class="muted micro">${df(x.start_date)} → ${df(x.end_date)} · ${esc(x.ended_reason||'Changement')}</div></div><span class="badge">${esc(x.agent?.name||'Agent')}</span></div>`).join('')}`:''}
 </div>`:''}
${playerStaff.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Entourage professionnel</div><h3 style="margin:2px 0">Staff du joueur</h3></div><span class="badge">${playerStaff.length} membre(s)</span></div>
 <div class="stack" style="margin-top:8px">${playerStaff.map(x=>{const sp=x.staff||{};return `<div class="list-item"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)} · ${esc(sp.specialty||sp.primary_role||'')}</div></div><div style="text-align:right"><span class="badge ${x.verified?'good':''}">${x.verified?'Sourcé':'Base Court Boss'}</span><div class="muted micro">${esc(staffFormerLabel(sp))}</div></div></div><div class="row" style="margin-top:6px;gap:6px;flex-wrap:wrap"><span class="badge">Affinité ${x.affinity??'—'}/100</span><span class="badge">Confiance ${x.trust??'—'}/100</span><span class="badge">Fit ${x.role_fit??'—'}/100</span><span class="badge">Satisfaction ${x.satisfaction??'—'}/100</span><span class="badge">Cohésion ${x.team_chemistry??'—'}/100</span><span class="badge">Coach ${sp.coach_rating??'—'}/20</span><span class="badge">Tech ${sp.technical_rating??'—'}/20</span><span class="badge">Tact ${sp.tactical_rating??'—'}/20</span><span class="badge">Mental ${sp.mental_rating??'—'}/20</span><span class="badge">Physique ${sp.fitness_rating??'—'}/20</span><span class="badge">Médical ${sp.medical_rating??'—'}/20</span></div>${sp.former_player_id?`<button class="ghost" style="margin-top:6px" onclick="openPlayer(${sp.former_player_id})">Voir sa carrière de joueur</button>`:''}<div class="muted micro" style="margin-top:5px">${esc(x.source_label||sp.source_label||'Court Boss')}</div></div>`}).join('')}</div>
 </div>`:''}
${playerStaffHistory.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Historique staff</div><h3 style="margin:2px 0">Anciens membres de l'équipe</h3></div><span class="badge">${playerStaffHistory.length}</span></div>
 <div class="stack" style="margin-top:8px">${playerStaffHistory.slice(0,8).map(x=>{const sp=x.staff||{};return `<div class="list-item"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)} · ${df(x.start_date)} → ${df(x.end_date)}</div></div><span class="badge">${esc(x.ended_reason||'Fin de collaboration')}</span></div><div class="muted micro" style="margin-top:4px">Affinité finale ${fmt(x.affinity||0)}/100 · Confiance ${fmt(x.trust||0)}/100</div></div>`}).join('')}</div>
 </div>`:''}
${playerStaffBonds.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Relations staff persistantes</div><h3 style="margin:2px 0">Coachs favoris & liens de carrière</h3></div><span class="badge">FM · ${playerStaffBonds.length}</span></div>
 <div class="muted micro" style="margin:4px 0 8px">Ces liens sont des mécaniques de simulation Court Boss sauf mention sourcée. Ils peuvent influencer une future réunion ou négociation.</div>
 <div class="stack">${playerStaffBonds.slice(0,12).map(x=>{const sp=x.staff||{};return `<div class="list-item click" onclick="openStaffProfile(${sp.id})"><div class="row between"><div><b>${flags[sp.nationality]||'🏳️'} ${esc(sp.name||'Staff')}</b><div class="muted mini">${esc(sp.primary_role||'Staff')} · ${esc(x.bond_type||'Relation professionnelle')}</div></div><span class="badge ${x.bond_type==='Joueur favori'?'good':x.bond_type==='Relation difficile'?'bad':''}">${x.affinity}/100</span></div><div class="row between muted micro"><span>Confiance ${x.trust}</span><span>Respect ${x.respect}</span><span>${x.is_simulated?'Simulation':'Sourcé'}</span></div></div>`}).join('')}</div>
 </div>`:''}
${relationships.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Relations FM</div><h3 style="margin:2px 0">Affinités & proches</h3></div><span class="badge">Évolutif</span></div>
 <div class="muted micro" style="margin:4px 0 8px">Les relations marquées Simulation sont des mécaniques de jeu Court Boss, pas des affirmations sur la vie privée réelle des joueurs.</div>
 <div class="stack">${relationships.map(r=>{const o=r.other||{};return `<div class="list-item click" onclick="openPlayer(${o.id})"><div class="row between"><div><b>${flags[o.country]||'🏳️'} ${esc(o.name||'Joueur')}</b><div class="muted mini">${esc(r.relation_type||'Affinité sportive')} · ATP ${o.ranking?'#'+fmt(o.ranking):'NR'}</div></div><div style="text-align:right"><b>${fmt(r.affinity||0)}/100</b><div class="muted micro">${r.is_simulated?'Simulation':'Sourcé'}</div></div></div><div class="bar" style="margin-top:6px"><i style="width:${Number(r.affinity||0)}%"></i></div><div class="row between muted micro" style="margin-top:4px"><span>Confiance ${fmt(r.trust||0)}</span><span>Respect ${fmt(r.respect||0)}</span><span>Proximité ${fmt(r.closeness||0)}</span></div></div>`}).join('')}</div>
 </div>`:''}
${playerTraits.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Traits de jeu</div><h3 style="margin:2px 0">Tendances FM/TM</h3></div><span class="badge">${playerKnowledgeLabel(isManaged,scoutReport)}</span></div>
 <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${playerTraits.map(t=>`<span class="badge ${t.kind||''}">${esc(t.label)}</span>`).join('')}</div>
 <div class="muted micro" style="margin-top:7px">${isManaged?'Traits dérivés du profil complet et susceptibles d’évoluer avec les attributs.':'Traits estimés à partir du rapport de scouting disponible.'}</div>
</div>`:''}
<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div class="eyebrow">Classements du joueur</div><span class="badge">${p.career_high_rank?'Pic carrière #'+fmt(p.career_high_rank):'Historique'}</span></div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">ATP actuel</span><b>${p.ranking_current&&p.ranking!=null?'#'+fmt(p.ranking):'NR'}</b></div>
  <div class="kpi"><span class="muted mini">Meilleur simple</span><b>${p.career_high_rank?'#'+fmt(p.career_high_rank):'—'}</b><small class="muted micro">${p.career_high_rank_date?df(p.career_high_rank_date):''}</small></div>
  <div class="kpi"><span class="muted mini">Double actuel</span><b>${p.doubles_ranking!=null?'#'+fmt(p.doubles_ranking):'NR'}</b></div>
  <div class="kpi"><span class="muted mini">Meilleur double</span><b>${p.career_high_doubles_rank?'#'+fmt(p.career_high_doubles_rank):'—'}</b><small class="muted micro">${p.career_high_doubles_rank_date?df(p.career_high_doubles_rank_date):p.career_high_doubles_source?'meilleur connu':''}</small></div>
 </div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">Meilleure saison</span><b>${p.best_season_year||bestHistoricalSeason?.season||'—'}</b><small class="muted micro">${p.best_season_summary?esc(p.best_season_summary):bestHistoricalSeason?fmt(bestHistoricalSeason.titles||0)+' titres · '+fmt(bestHistoricalSeason.grand_slams||0)+' GC':''}</small></div>
  <div class="kpi"><span class="muted mini">Semaines n°1</span><b>${fmt(p.weeks_at_no1||0)}</b></div>
  <div class="kpi"><span class="muted mini">Junior</span><b>${p.junior_ranking!=null?'#'+fmt(p.junior_ranking):'—'}</b><small class="muted micro">${p.junior_rank_type==='official'&&p.junior_official_ranking!=null?'ITF officiel #'+fmt(p.junior_official_ranking):p.junior_rank_type==='verified_nr'?'ITF NR':p.game_generated&&p.junior_ranking!=null?'simulé':''}</small></div>
  <div class="kpi"><span class="muted mini">NCAA / ITA</span><b>${(ncaa?.ita_rank??p.ncaa_rank)!=null?'#'+fmt(ncaa?.ita_rank??p.ncaa_rank):p.ncaa_current?'Actif':'—'}</b><small class="muted micro">${ncaa?.utr_rating!=null?'UTR '+(ncaa.utr_verified?'':'~')+Number(ncaa.utr_rating).toFixed(2)+' · ':''}${esc(ncaa?.school||p.ncaa_school||'')}</small></div>
 </div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">Race Junior</span><b>${races.junior?.rank!=null?'#'+fmt(races.junior.rank):'—'}</b><small class="muted micro">${races.junior?.points!=null?fmt(races.junior.points)+' pts · ':''}${races.junior?.status==='qualified'?'Qualifié Finals':races.junior?.status==='alternate'?'Remplaçant':races.junior?.rank!=null?'En course':''}</small></div>
  <div class="kpi"><span class="muted mini">Race Double</span><b>${races.doubles?.rank!=null?'#'+fmt(races.doubles.rank):'—'}</b><small class="muted micro">${races.doubles?.points!=null?fmt(races.doubles.points)+' pts · ':''}${races.doubles?.status==='qualified'?'Qualifié Finals':races.doubles?.status==='alternate'?'Remplaçant':races.doubles?.rank!=null?'En course':''}${races.doubles?.team?' · '+esc(races.doubles.team):''}</small></div>
  <div class="kpi"><span class="muted mini">Race Junior Double</span><b>${races.juniorDoubles?.rank!=null?'#'+fmt(races.juniorDoubles.rank):'—'}</b><small class="muted micro">${races.juniorDoubles?.points!=null?fmt(races.juniorDoubles.points)+' pts · ':''}${races.juniorDoubles?.status==='qualified'?'Qualifié Finals':races.juniorDoubles?.status==='alternate'?'Remplaçant':races.juniorDoubles?.rank!=null?'En course':''}${races.juniorDoubles?.team?' · '+esc(races.juniorDoubles.team):''}</small></div>
  <div class="kpi"><span class="muted mini">Statut Finals</span><b>${[races.junior,races.doubles,races.juniorDoubles].some(x=>x?.status==='qualified')?'Qualifié':[races.junior,races.doubles,races.juniorDoubles].some(x=>x?.status==='alternate')?'Remplaçant':'—'}</b></div>
 </div>
</div>
<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Personnalité FM</div><h3 style="margin:2px 0 4px">${esc(personalityLabel)}</h3></div><span class="badge ${personalityKind==='curated'?'good':''}">${personalityKind==='curated'?'Profil éditorial':'Simulation'}</span></div>
 <div class="muted" style="line-height:1.45">${esc(personalityText)}</div>
 <div class="muted micro" style="margin-top:7px">${esc(personalitySource)}</div>
</div>
${p.bio_source?`<div class="muted micro" style="margin-top:6px">Bio : ${esc(p.bio_source)}${p.bio_verified?' · sourcée':''}</div>`:''}${Array.isArray(p.circuits_2025)&&p.circuits_2025.length?`<div class="row" style="margin-top:10px;flex-wrap:wrap">${p.circuits_2025.map(c=>`<span class="badge">${esc(c)} 2025</span>`).join('')}</div>`:''}${ncaa?`<div class="list-item row between"><span>NCAA / ITA · UTR</span><b>#${ncaa.ita_rank||p.ncaa_rank||'—'} · UTR ${ncaa.utr_rating!=null?(ncaa.utr_verified?'':'~')+Number(ncaa.utr_rating).toFixed(2):'—'} · ${esc(ncaa.school||p.ncaa_school||'Université')}</b></div>`:ncaaIsAlumni?`<div class="list-item row between"><span>Carrière NCAA</span><b>${esc(ncaaCareer?.school||p.ncaa_last_school||'Université')} · Alumni${ncaaCareer?.verified||p.ncaa_verified?' · certifié':''}</b></div>`:ncaaHistorical?`<div class="list-item row between"><span>NCAA historique</span><b>${esc(p.ncaa_last_school||ncaaCareer?.school||'Université')} · ${esc(p.ncaa_status||'Roster historique')}</b></div>`:''}</div><div class="card"><div class="row between"><div><div class="eyebrow">Évaluation FM/TM</div><h2>Niveau & potentiel</h2></div><span class="badge">${playerKnowledgeLabel(isManaged,scoutReport)}</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Niveau</span><b>${starRatingHtml(currentStars,'Niveau actuel')}</b><small class="muted micro">${isManaged?'CA '+p.current_ability+'/100':scoutReport?'CA estimée '+scoutReport.estimated_ca_min+'–'+scoutReport.estimated_ca_max:'Estimation publique'}</small></div><div class="kpi"><span class="muted mini">Potentiel</span><b>${potentialStars!=null?starRatingHtml(potentialStars,'Potentiel estimé'):'☆☆☆☆☆ ?'}</b><small class="muted micro">${isManaged?'PA '+p.potential+'/100 · dynamique':scoutReport?'PA estimé '+scoutReport.estimated_pa_min+'–'+scoutReport.estimated_pa_max:'À scout­er'}</small></div><div class="kpi"><span class="muted mini">Profil développement</span><b>${isManaged?developmentTypeLabel(dev.development_type||'standard'):scoutReport?developmentTypeLabel(String(scoutReport.development_type_read||'').replace('précoce probable','early').replace('tardif possible','late').replace('incertain','standard')):'?'}</b></div><div class="kpi"><span class="muted mini">Confiance</span><b>${isManaged?'100':scoutReport?.confidence??Math.min(45,p.scouting_confidence??35)}%</b></div></div></div><div class="card"><h2>Données historiques</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Titres simple</span><b>${titleCount}</b></div><div class="kpi"><span class="muted mini">Titres double</span><b>${doublesTitles.length}</b></div><div class="kpi"><span class="muted mini">NCAA / College</span><b>${collegeTitles.length}</b></div><div class="kpi"><span class="muted mini">Grand Chelem</span><b>${slamCount}</b></div></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${hardTitles}</span><span class="badge clay">Terre ${clayTitles}</span><span class="badge grass">Gazon ${grassTitles}</span></div></div></div>
    <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Bilan historique</h2>${realMatches?`<div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${fmt(realMatches)}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${fmt(cs.wins||0)}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${fmt(cs.losses||0)}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${realWinPct}%</b></div></div><div class="list-item row between"><span>Dur</span><b>${cs.hard_wins==null||cs.hard_losses==null?'Non renseigné':cs.hard_wins+'-'+cs.hard_losses+' · '+surfacePct(cs.hard_wins,cs.hard_losses)}</b></div><div class="list-item row between"><span>Terre battue</span><b>${cs.clay_wins==null||cs.clay_losses==null?'Non renseigné':cs.clay_wins+'-'+cs.clay_losses+' · '+surfacePct(cs.clay_wins,cs.clay_losses)}</b></div><div class="list-item row between"><span>Gazon</span><b>${cs.grass_wins==null||cs.grass_losses==null?'Non renseigné':cs.grass_wins+'-'+cs.grass_losses+' · '+surfacePct(cs.grass_wins,cs.grass_losses)}</b></div><div class="muted mini" style="margin-top:8px">Source : ${esc(cs.source||'Archives de matchs')} · relevé du ${cs.source_snapshot?df(cs.source_snapshot):'—'}${String(cs.source||'').startsWith('https://')?' · <a href="'+esc(cs.source)+'" target="_blank" rel="noopener noreferrer">Consulter la source</a>':' · Agrégat importé, périmètre non certifié ATP'}</div>`:'<div class="empty">Historique match réel non disponible pour ce joueur.</div>'}</div><div class="card"><h2>Scouting</h2><div class="notice">Les notes 1–20 sont des évaluations de jeu, pas des statistiques officielles ATP.</div><p class="muted mini" style="margin-top:10px">Confiance : ${p.scouting_confidence}% · Source : ${esc(p.data_source||'Court Boss')} ${p.data_snapshot?'· snapshot '+df(p.data_snapshot):''}</p><div class="row" style="margin-top:10px;flex-wrap:wrap"><button class="soft-btn" onclick="toggleShortlist(${p.id})">${(d.shortlist||(local.shortlist||[]).includes(p.id))?'Retirer de la shortlist':'Ajouter à la shortlist'}</button><button class="soft-btn" onclick="addComparePlayerV2(${p.id})">Comparer</button>${p.doubles_ranking!=null&&!isRetired?`<button class="soft-btn" onclick="approachPartner(${p.id});closeOverlay()">Approcher en double</button>`:''}${p.is_real&&!isRetired?`<button class="primary" onclick="startCareerWithPlayer(${p.id},'${esc(p.name).replaceAll("'","&#39;")}')">Gérer ce joueur</button>`:isRetired?'<span class="badge">Carrière terminée</span>':''}</div></div></div>
   </div>
   <template id="attrsTpl"><div class="notice"><b>${playerKnowledgeLabel(isManaged,scoutReport)}</b> · Les attributs 1–20 d’un autre joueur sont maintenant des estimations de scouting. Sans rapport, ils restent inconnus.</div><div class="attr-sections" style="margin-top:12px">${groups.map(g=>`<div class="attr-group"><h3>${g[0]}</h3>${g[1].map(x=>{const v=knownAttrs[x[1]];return `<div class="attr-row"><div class="row"><span>${x[0]}</span><b class="${v!=null?attrClass(v):''}">${v??'?'}</b></div><div class="bar"><i style="width:${v!=null?Number(v)*5:0}%"></i></div></div>`}).join('')}</div>`).join('')}</div></template>
   <template id="analyticsTpl">
    <div class="notice"><b>Analytics avancées</b> · Le moteur utilise les mêmes familles de lecture que Tennis Abstract / Match Charting Project : service, retour, pression, rally length, filet, directions et Elo. Ici, les valeurs « modelled » sont calculées par Court Boss à partir du profil joueur et évoluent ensuite dans la sauvegarde.</div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><div class="row between"><div><div class="eyebrow">Force contextuelle</div><h2>Elo Court Boss</h2></div><span class="badge">Confiance ${elo.confidence??'—'}%</span></div>
        <div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Global</span><b>${elo.overall_elo?Math.round(elo.overall_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Dur</span><b>${elo.hard_elo?Math.round(elo.hard_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Terre</span><b>${elo.clay_elo?Math.round(elo.clay_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Gazon</span><b>${elo.grass_elo?Math.round(elo.grass_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Indoor</span><b>${elo.indoor_elo?Math.round(elo.indoor_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Double</span><b>${elo.doubles_elo?Math.round(elo.doubles_elo):'—'}</b></div></div>
        <div class="muted micro" style="margin-top:8px">${esc(elo.source_label||'Court Boss Elo')} · l’Elo bouge après les matchs joués.</div>
      </div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Indices synthétiques</div><h2>Profil analytique</h2></div><span class="badge">${esc(advanced.source_kind||'modelled')}</span></div>
        <div class="kpi-strip"><div class="kpi"><span class="muted mini">Service</span><b>${advanced.serve_rating??'—'}</b></div><div class="kpi"><span class="muted mini">Retour</span><b>${advanced.return_rating??'—'}</b></div><div class="kpi"><span class="muted mini">Clutch</span><b>${advanced.clutch_rating??'—'}</b></div><div class="kpi"><span class="muted mini">Aggression</span><b>${advanced.aggression_index??'—'}</b></div></div>
      </div>
    </div>
    <div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Identité tactique</div><h2>${esc(tacticalProfile.tactical_identity||dev.preferred_archetype||p.style||'À préciser')}</h2></div><span class="badge">Évolutif</span></div>
      <div class="kpi-strip" style="margin-top:8px">
       <div class="kpi"><span class="muted micro">Agressivité</span><b>${tacticalProfile.aggression_bias??'—'}/20</b></div>
       <div class="kpi"><span class="muted micro">Prise de risque</span><b>${tacticalProfile.risk_tolerance??'—'}/20</b></div>
       <div class="kpi"><span class="muted micro">Montées filet</span><b>${tacticalProfile.net_frequency??'—'}/20</b></div>
       <div class="kpi"><span class="muted micro">Rallyes longs</span><b>${tacticalProfile.rally_length_preference??'—'}/20</b></div>
      </div>
      <div class="grid g2" style="margin-top:8px">
       <div>
        <div class="list-item row between"><span>Profondeur de position</span><b>${tacticalProfile.baseline_depth??'—'}/20</b></div>
        <div class="list-item row between"><span>Service + 1</span><b>${tacticalProfile.serve_plus_one_bias??'—'}/20</b></div>
        <div class="list-item row between"><span>Retour</span><b>${esc(tacticalProfile.return_position||'—')}</b></div>
        <div class="list-item row between"><span>Recherche coup droit</span><b>${tacticalProfile.forehand_bias??'—'}/20</b></div>
       </div>
       <div>
        <div class="list-item row between"><span>Amorties</span><b>${tacticalProfile.drop_shot_frequency??'—'}/20</b></div>
        <div class="list-item row between"><span>Slice</span><b>${tacticalProfile.slice_frequency??'—'}/20</b></div>
        <div class="list-item row between"><span>Cadence</span><b>${tacticalProfile.pace_preference??'—'}/20</b></div>
        <div class="list-item row between"><span>Défense → attaque</span><b>${tacticalProfile.defense_to_attack_bias??'—'}/20</b></div>
       </div>
      </div>
      <div class="muted micro" style="margin-top:8px">Ces tendances sont recalculées quand le profil technique et mental évolue. Elles influencent le moteur de match et la sélection des tournois.</div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card">
       <div class="row between"><div><div class="eyebrow">Traits préférés</div><h2>Comportements récurrents</h2></div><span class="badge">${tacticalTraits.length}</span></div>
       ${tacticalTraits.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${tacticalTraits.map(x=>`<span class="badge ${Number(x.intensity)>=85?'good':Number(x.intensity)>=72?'warn':''}">${esc(x.trait_name)} · ${x.intensity}%</span>`).join('')}</div>`:'<div class="empty">Aucun trait dominant détecté.</div>'}
       <div class="muted micro" style="margin-top:8px">Les traits ne sont pas figés : un changement technique, physique ou tactique peut les faire apparaître ou disparaître.</div>
      </div>
      <div class="card">
       <div class="row between"><div><div class="eyebrow">IA calendrier</div><h2>${seasonPlan?esc(String(seasonPlan.plan_type||'').replaceAll('_',' ')):'Plan non généré'}</h2></div>${seasonPlan?`<span class="badge">${seasonPlan.season}</span>`:''}</div>
       ${seasonPlan?`<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Tournois cible</span><b>${seasonPlan.target_events}</b></div><div class="kpi"><span class="muted micro">Surface</span><b>${esc(seasonPlan.preferred_surface||'—')}</b></div><div class="kpi"><span class="muted micro">Repos</span><b>${seasonPlan.rest_bias}/20</b></div><div class="kpi"><span class="muted micro">Prestige</span><b>${seasonPlan.prestige_bias}/20</b></div></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge">Voyage ${seasonPlan.travel_tolerance}/20</span><span class="badge">Développement ${seasonPlan.development_bias}/20</span><span class="badge">Double ${seasonPlan.doubles_bias}/20</span></div><div class="muted mini" style="margin-top:8px">${esc(seasonPlan.reason||'')}</div>`:'<div class="empty">Le plan apparaîtra au prochain cycle de planification.</div>'}
      </div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Service</h2>
        ${[['1res balles IN','first_serve_in_pct'],['Aces / pts service','ace_pct'],['Doubles fautes','double_fault_pct'],['Services non retournés','unreturned_serve_pct'],['Pts gagnés 1re','first_serve_points_won_pct'],['Pts gagnés 2e','second_serve_points_won_pct'],['Pts service gagnés','service_points_won_pct'],['Jeux service tenus','hold_pct']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+'%':'—'}</b></div>`).join('')}
      </div>
      <div class="card"><h2>Retour</h2>
        ${[['Pts retour gagnés','return_points_won_pct'],['Retour 1re gagné','first_return_points_won_pct'],['Retour 2e gagné','second_return_points_won_pct'],['Jeux retour breakés','break_pct'],['Retours remis en jeu','return_in_play_pct'],['Profondeur retour','return_depth_score']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+(k==='return_depth_score'?'/100':'%'):'—'}</b></div>`).join('')}
      </div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Pression & qualité de point</h2>
        ${[['Balles de break sauvées','break_points_saved_pct'],['Balles de break converties','break_points_converted_pct'],['Tie-breaks','tiebreak_win_pct'],['Winners','winner_rate_pct'],['Erreurs forcées provoquées','forced_error_induced_pct'],['Erreurs non forcées','unforced_error_pct']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+'%':'—'}</b></div>`).join('')}
      </div>
      <div class="card"><h2>Filet & rally length</h2>
        ${[['Montées au filet','net_approach_pct'],['Pts gagnés au filet','net_points_won_pct'],['Serve & volley','serve_volley_pct'],['Rally moyen','avg_rally_shots'],['Rally 0–4','rally_0_4_win_pct'],['Rally 5–8','rally_5_8_win_pct'],['Rally 9+','rally_9plus_win_pct']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+(k==='avg_rally_shots'?' coups':'%'):'—'}</b></div>`).join('')}
      </div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Direction du service</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Large</span><b>${advanced.serve_wide_pct!=null?Number(advanced.serve_wide_pct).toFixed(1)+'%':'—'}</b></div><div class="kpi"><span class="muted mini">Corps</span><b>${advanced.serve_body_pct!=null?Number(advanced.serve_body_pct).toFixed(1)+'%':'—'}</b></div><div class="kpi"><span class="muted mini">T</span><b>${advanced.serve_t_pct!=null?Number(advanced.serve_t_pct).toFixed(1)+'%':'—'}</b></div></div></div>
      <div class="card"><h2>Directions de frappe</h2><div class="list-item row between"><span>CD croisé / ligne / inside-out</span><b>${advanced.forehand_cross_pct??'—'} / ${advanced.forehand_dtl_pct??'—'} / ${advanced.forehand_insideout_pct??'—'}%</b></div><div class="list-item row between"><span>RV croisé / ligne / slice</span><b>${advanced.backhand_cross_pct??'—'} / ${advanced.backhand_dtl_pct??'—'} / ${advanced.backhand_slice_pct??'—'}%</b></div></div>
    </div>
    ${styleHistory.length?`<div class="card" style="margin-top:12px"><div class="row between"><h2>Évolution tactique</h2><span class="badge">${styleHistory.length}</span></div>${styleHistory.slice(0,8).map(x=>`<div class="list-item row between"><div><b>${esc(x.old_style||'—')} → ${esc(x.new_style)}</b><div class="muted micro">${esc(x.reason||'Évolution du profil')}</div></div><span class="badge">${df(x.changed_at)}</span></div>`).join('')}</div>`:''}
   </template>
   <template id="developmentTpl"><div class="grid g2"><div class="card"><div class="row between"><div><div class="eyebrow">Niveau actuel</div><h2>${starRatingHtml(currentStars,'Capacité actuelle')}</h2></div><b>${isManaged?'CA '+p.current_ability+'/100':scoutReport?scoutReport.estimated_ca_min+'–'+scoutReport.estimated_ca_max:'Public'}</b></div><div class="bar"><i style="width:${Math.round(currentStars/5*100)}%"></i></div><div class="row between" style="margin-top:14px"><div><div class="eyebrow">Potentiel estimé</div><h2>${potentialStars!=null?starRatingHtml(potentialStars,'Potentiel'):'☆☆☆☆☆ ?'}</h2></div><b>${isManaged?'PA '+p.potential+'/100':scoutReport?scoutReport.estimated_pa_min+'–'+scoutReport.estimated_pa_max:'Inconnu'}</b></div><div class="bar"><i style="width:${potentialStars!=null?Math.round(potentialStars/5*100):0}%"></i></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px"><span class="badge">Fourchette ${potentialMin!=null?potentialMin.toFixed(1):'?'}–${potentialMax!=null?potentialMax.toFixed(1):'?'} ★</span><span class="badge">Confiance ${isManaged?100:scoutReport?.confidence??35}%</span></div><p class="muted mini" style="margin-top:9px">Le potentiel est dynamique et l’estimation dépend du recruteur. Un joueur peut dépasser ou manquer son plafond prévu.</p></div><div class="card"><div class="row between"><div><div class="eyebrow">Courbe & personnalité</div><h2>${isManaged?developmentTypeLabel(dev.development_type||'standard'):esc(scoutReport?.development_type_read||'À observer')}</h2></div><span class="badge">${isManaged?'Pic ~'+(dev.peak_age??25)+' ans':esc(scoutReport?.trajectory_read||'Inconnu')}</span></div>${isManaged?`<p class="muted mini">${developmentTypeDescription(dev.development_type||'standard')}</p><div class="list-item row between"><span>Personnalité</span><b>${esc(dev.personality_label||'Équilibré')}</b></div><div class="list-item row between"><span>Mentalité</span><b>${esc(dev.mentality_profile||'Stable')}</b></div><div class="list-item row between"><span>Attitude entraînement</span><b>${esc(dev.training_attitude||'Correcte')}</b></div><div class="list-item row between"><span>Vitesse développement</span><b>${dev.development_rate??10}/20</b></div><div class="list-item row between"><span>Coachabilité</span><b>${dev.coachability??10}/20</b></div><div class="list-item row between"><span>Résilience</span><b>${dev.resilience??10}/20</b></div><div class="list-item row between"><span>Professionnalisme</span><b>${dev.professionalism??10}/20</b></div><div class="list-item row between"><span>Ambition</span><b>${dev.ambition??10}/20</b></div><div class="list-item row between"><span>Fragilité</span><b>${dev.injury_proneness??10}/20</b></div>
<div class="list-item row between"><span>Drive compétitif</span><b>${dev.competitive_drive??10}/20</b></div>
<div class="list-item row between"><span>Discipline</span><b>${dev.discipline??10}/20</b></div>
<div class="list-item row between"><span>Gestion pression</span><b>${dev.pressure??10}/20</b></div>
<div class="list-item row between"><span>Stabilité confiance</span><b>${21-Number(dev.confidence_volatility??10)}/20</b></div><div class="list-item row between"><span>Grands matchs</span><b>${dev.important_matches>=16?'Excellent':dev.important_matches>=13?'Fort':dev.important_matches>=9?'Correct':'À développer'}</b></div><div class="list-item row between"><span>Tempérament</span><b>${dev.temperament>=16?'Très stable':dev.temperament>=12?'Stable':dev.temperament>=8?'Variable':'Volatile'}</b></div><div class="list-item row between"><span>Drive compétitif</span><b>${dev.competitive_drive>=16?'Très élevé':dev.competitive_drive>=12?'Élevé':dev.competitive_drive>=8?'Moyen':'Faible'}</b></div>`:`<div class="list-item row between"><span>Personnalité lue</span><b>${esc(scoutReport?.personality_read||'À préciser')}</b></div><div class="list-item row between"><span>Archétype</span><b>${esc(scoutReport?.archetype_read||p.style||'À préciser')}</b></div><div class="list-item row between"><span>Risque physique</span><b>${esc(scoutReport?.injury_risk_read||'Incertain')}</b></div><div class="list-item row between"><span>Trajectoire</span><b>${esc(scoutReport?.trajectory_read||'À préciser')}</b></div><p class="muted mini">${esc(scoutReport?.detailed_notes||'Lance une mission de scouting pour préciser le profil.')}</p>`}</div></div><div class="grid g2" style="margin-top:12px"><div class="card"><h2>${isManaged?'Axes à travailler':'Lecture scout'}</h2>${Object.entries(knownAttrs).filter(([k,v])=>k!=='player_id'&&Number.isFinite(Number(v))).sort((x,y)=>Number(x[1])-Number(y[1])).slice(0,8).map(([k,v])=>`<div class="list-item row between"><span>${esc(k.replaceAll('_',' '))}</span><b>${v}/20</b></div>`).join('')||'<div class="empty">Rapport insuffisant pour identifier les faiblesses.</div>'}</div>${isManaged?`<div class="card"><div class="row between"><div><div class="eyebrow">Impact du staff</div><h2>Environnement de développement</h2></div><span class="badge ${Number(dev.coaching_environment||8)>=15?'good':''}">${dev.coaching_environment??8}/20</span></div>
<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Technique</span><b>${dev.technical_environment??8}</b></div><div class="kpi"><span class="muted micro">Tactique</span><b>${dev.tactical_environment??8}</b></div><div class="kpi"><span class="muted micro">Physique</span><b>${dev.physical_environment??8}</b></div><div class="kpi"><span class="muted micro">Mental</span><b>${dev.mental_environment??8}</b></div></div>
<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Médical</span><b>${dev.medical_environment??8}</b></div><div class="kpi"><span class="muted micro">Stabilité staff</span><b>${dev.staff_stability??8}</b></div><div class="kpi"><span class="muted micro">Coachabilité</span><b>${dev.coachability??10}</b></div><div class="kpi"><span class="muted micro">Résilience</span><b>${dev.resilience??10}</b></div></div>
<p class="muted mini" style="margin-top:8px">${esc(dev.development_context||'L’impact du staff sera recalculé au prochain cycle de développement.')}</p></div>`:''}
<div class="card"><div class="row between"><h2>Historique développement</h2><span class="badge">${devHistory.length}</span></div>${devHistory.length?devHistory.slice(0,12).map(x=>`<div class="list-item"><div class="row between"><b>${df(x.event_date)}</b><span class="badge">${esc(x.event_type)}</span></div><div class="muted mini">CA ${x.old_current_ability??'—'} → ${x.new_current_ability??'—'} · PA ${x.old_potential??'—'} → ${x.new_potential??'—'}</div>${x.old_development_type!==x.new_development_type?`<div class="muted micro">${developmentTypeLabel(x.old_development_type)} → ${developmentTypeLabel(x.new_development_type)}</div>`:''}<div class="muted micro">${esc(x.reason||'Évolution')}</div></div>`).join(''):'<div class="empty">Aucun changement dynamique enregistré depuis le début de la sauvegarde.</div>'}</div></div></template>
   <template id="matchesTpl">${(d.juniorEntries||[]).length?`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Circuit ITF Junior</div><h2>Tournois juniors vérifiés</h2></div><span class="badge">Junior #${p.junior_ranking||'—'}</span></div>${(d.juniorEntries||[]).map(e=>{const t=Array.isArray(e.tournaments)?e.tournaments[0]:e.tournaments;return `<div class="list-item row between"><div><b>${esc(t?.name||'Tournoi junior')}</b><div class="muted mini">${t?.city?esc(t.city)+' · ':''}${t?.start_date?df(t.start_date):''} · ${esc(t?.category||'Junior')} · ${esc(surfaceLabel(t||{}))}</div></div><div style="text-align:right"><b>${esc(e.result||'Engagé')}</b><div class="muted mini">${e.seed?'TDS '+esc(e.seed):''}</div></div></div>`}).join('')}</div>`:''}<div class="grid g2"><div class="card"><h2>Historique importé</h2>${realMatches?`<div class="big">${fmt(cs.wins||0)} - ${fmt(cs.losses||0)}</div><div class="muted">${realWinPct}% de victoires · ${fmt(realMatches)} matchs</div><div class="bar" style="margin-top:10px"><i style="width:${realWinPct}%"></i></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${pct(cs.hard_wins,cs.hard_losses)}%</span><span class="badge clay">Terre ${pct(cs.clay_wins,cs.clay_losses)}%</span><span class="badge grass">Gazon ${pct(cs.grass_wins,cs.grass_losses)}%</span></div>`:'<div class="empty">Pas de données historiques.</div>'}</div><div class="card"><h2>Bilan dans la sauvegarde</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${(d.matches||[]).length}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${(d.matches||[]).filter(m=>m.winner_id===p.id).length}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${(d.matches||[]).filter(m=>m.winner_id!==p.id).length}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${(d.matches||[]).length?Math.round((d.matches||[]).filter(m=>m.winner_id===p.id).length/(d.matches||[]).length*100):0}%</b></div></div></div><div class="card"><h2>Forme actuelle</h2><div class="row between"><span>Forme</span><b>${p.form}/100</b></div><div class="bar"><i style="width:${p.form}%"></i></div><div class="row between" style="margin-top:10px"><span>Fitness</span><b>${p.fitness}/100</b></div><div class="bar"><i style="width:${p.fitness}%"></i></div></div></div><div class="card" style="margin-top:12px"><h2>Historique des matchs</h2>${(d.matches||[]).length?(d.matches||[]).map(m=>{const oppId=m.player_a_id===p.id?m.player_b_id:m.player_a_id;const opp=m.player_a_id===p.id?m.player_b_name:m.player_a_name;const won=m.winner_id===p.id;const tour=m.tournament_runs?.tournaments;return `<div class="list-item row between"><div class="click" onclick="openPlayer(${oppId})"><div><b class="${won?'good':'bad'}">${won?'V':'D'}</b> vs ${esc(opp)}</div><div class="muted mini">${esc(tour?.name||'Tournoi')} · ${esc(m.round_name)} · ${esc(surfaceLabel(tour||{}))}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="muted mini">${df(tour?.start_date)}</div></div></div>`}).join(''):'<div class="empty">Aucun match simulé pour ce joueur dans cette sauvegarde.</div>'}</div></template>
   <template id="doubleTpl">
    <div class="grid g2">
      <div class="card"><div class="row between"><div><div class="eyebrow">Classement individuel</div><h2>ATP Double</h2></div><span class="badge ${p.doubles_source?'good':''}">${p.doubles_source?'Sourcé':'Index DB'}</span></div>
        <div class="statline"><div class="statbox"><span class="muted mini">Rang actuel</span><b>${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'NR'}</b></div><div class="statbox"><span class="muted mini">Meilleur carrière</span><b>${p.career_high_doubles_rank?'#'+fmt(p.career_high_doubles_rank):'—'}</b><small class="muted micro">${p.career_high_doubles_rank_date?df(p.career_high_doubles_rank_date):''}</small></div><div class="statbox"><span class="muted mini">Points</span><b>${p.doubles_points==null?'—':fmt(p.doubles_points)}</b></div><div class="statbox"><span class="muted mini">Aptitude double</span><b>${a.doubles??'—'}/20</b></div></div>
        <div class="muted mini" style="margin-top:8px">${p.doubles_source?esc(p.doubles_source):'Classement indexé Court Boss'}${p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''}</div>
        ${p.doubles_ranking!=null&&!isRetired?`<button class="primary" style="width:100%;margin-top:10px" onclick="approachPartner(${p.id});closeOverlay()">Approcher comme partenaire</button>`:''}
      </div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Race par équipes</div><h2>Paires ${String(local.date||RANKING_SNAPSHOT).slice(0,4)}</h2></div><span class="badge">${(d.doublesTeams||[]).length}</span></div>
        ${(d.doublesTeams||[]).length?(d.doublesTeams||[]).map(x=>{const partner=x.player_one===p.name?x.player_two:x.player_one;return `<div class="list-item row between"><div><b>#${fmt(x.rank)} · ${esc(partner)}</b><div class="muted mini">${esc(x.player_one)} / ${esc(x.player_two)} · ${x.snapshot_date?df(x.snapshot_date):''}</div></div><b>${fmt(x.points)} pts</b></div>`}).join(''):'<div class="empty">Aucune paire Race actuelle trouvée pour ce joueur.</div>'}
      </div>
    </div>
    ${primaryDoubles?`<div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Projet double</div><h2>Partenaire principal</h2></div><span class="badge good">Engagement ${primaryDoubles.commitment}/100</span></div>
      <div class="list-item click" onclick="openPlayer(${primaryDoubles.partner?.id})"><div class="row between"><div><b>${flags[primaryDoubles.partner?.country]||'🏳️'} ${esc(primaryDoubles.partner?.name||'Partenaire')}</b><div class="muted mini">Double ${primaryDoubles.partner?.doubles_ranking?'#'+fmt(primaryDoubles.partner.doubles_ranking):'NR'} · depuis ${df(primaryDoubles.started_at)}</div></div><div style="text-align:right"><b>${primaryDoubles.affinity}/100</b><div class="muted micro">affinité</div></div></div></div>
      <div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Saison</span><b>${primaryDoubles.season}</b></div><div class="kpi"><span class="muted mini">Changements</span><b>${primaryDoubles.switches||0}</b></div><div class="kpi"><span class="muted mini">Affinité</span><b>${primaryDoubles.affinity}/100</b></div><div class="kpi"><span class="muted mini">Engagement</span><b>${primaryDoubles.commitment}/100</b></div></div>
      <div class="muted mini" style="margin-top:8px">${esc(primaryDoubles.reason||'Partenariat principal de double.')}</div>
      ${doublesPartnerHistory.length?`<div style="margin-top:8px"><div class="muted micro">Anciens partenaires principaux</div>${doublesPartnerHistory.slice(0,5).map(x=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${x.partner?.id})"><b>${esc(x.partner?.name||'Partenaire')}</b><div class="muted micro">${df(x.start_date)} → ${df(x.end_date)}</div></div><span class="badge">${x.affinity_end??x.affinity_start??'—'}/100</span></div>`).join('')}</div>`:''}
    </div>`:''}
    <div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Palmarès</div><h2>Titres en double</h2></div><span class="badge good">${doublesTitles.length} titre${doublesTitles.length>1?'s':''}</span></div>
      ${doublesTitles.length?doublesTitles.map(t=>`<div class="list-item row between"><div><b>${esc(t.tournament_name)}</b><div class="muted mini">${df(t.title_date)} · ${esc(t.level||'Double')} · ${esc(t.surface||'—')}</div>${t.partner_name?`<div class="muted mini">Partenaire : ${t.partner_player_id?`<span class="click" onclick="openPlayer(${t.partner_player_id})">${esc(t.partner_name)}</span>`:esc(t.partner_name)}</div>`:''}</div><div style="text-align:right">${t.verified?'<span class="badge good">Vérifié</span>':'<span class="badge">Carrière</span>'}${t.source_url?`<div style="margin-top:5px"><a class="soft-btn" href="${esc(t.source_url)}" target="_blank" rel="noopener noreferrer">Source</a></div>`:''}</div></div>`).join(''):'<div class="empty">Aucun titre double enregistré.</div>'}
    </div>
    <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Scouting double</div><h2>Lecture du profil</h2></div><button class="ghost" onclick="closeOverlay();nav('doubles')">Hub Double</button></div>
      <div class="kpi-strip"><div class="kpi"><span class="muted mini">Volée</span><b>${a.volley??'—'}</b></div><div class="kpi"><span class="muted mini">Retour</span><b>${a.return_game??'—'}</b></div><div class="kpi"><span class="muted mini">Service</span><b>${a.serve_power??'—'}</b></div><div class="kpi"><span class="muted mini">Toucher</span><b>${a.touch??'—'}</b></div></div>
    </div>
   </template>
   <template id="careerTpl">
    ${window.renderPalmaresHtml?window.renderPalmaresHtml(d,p):'<div class="card empty">Module palmarès indisponible.</div>'}
    <div class="card fm-panel" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Carrière saison par saison</div><h2>Palmarès annuel</h2></div><span class="badge">${(d.historicalSeasons||[]).length} saisons</span></div>
      ${(d.historicalSeasons||[]).length?`<div class="table-wrap"><table class="table"><thead><tr><th>Saison</th><th>Rang</th><th>Titres</th><th>GC</th><th>Masters</th><th>Finals</th><th>Score saison</th><th>Source</th></tr></thead><tbody>${d.historicalSeasons.map(y=>{const score=weightedSeason(y);const best=Number(y.season)===Number(p.best_season_year||bestHistoricalSeason?.season);return `<tr ${best?'style="background:rgba(92,222,145,.08)"':''}><td class="rank-num">${y.season}${best?' <span class="badge good">BEST</span>':''}</td><td>${y.best_rank?'#'+fmt(y.best_rank):'—'}</td><td>${y.titles==null?'—':y.titles}</td><td><b>${y.grand_slams||0}</b></td><td>${y.masters||0}</td><td>${y.tour_finals||0}</td><td><b>${fmt(score)}</b></td><td class="muted mini">${esc(y.source_label||'Archive')}</td></tr>`}).join('')}</tbody></table></div>`:'<div class="empty">Pas encore de découpage annuel disponible.</div>'}
    </div>
   </template>
   <template id="commercialTpl"><div class="card"><h2>Sponsors vérifiés</h2>${d.sponsors.filter(s=>s.verified).length?d.sponsors.filter(s=>s.verified).map(s=>`<span class="badge good" style="margin:4px">${esc(s.sponsor)}</span>`).join(''):'<div class="empty">Non vérifié</div>'}<p class="muted mini" style="margin-top:10px">Aucune marque n'est inventée quand la donnée n'est pas vérifiée.</p></div></template>
   <template id="historyTpl"><div class="card"><div class="row between"><div><div class="eyebrow">Records classement</div><h2>Historique ATP</h2></div><span class="badge">au 01/12/2025</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Meilleur simple</span><b>${p.career_high_rank?'#'+fmt(p.career_high_rank):'—'}</b><small class="muted micro">${p.career_high_rank_date?df(p.career_high_rank_date):''}</small></div><div class="kpi"><span class="muted mini">Meilleur double</span><b>${p.career_high_doubles_rank?'#'+fmt(p.career_high_doubles_rank):'—'}</b><small class="muted micro">${p.career_high_doubles_source?esc(p.career_high_doubles_source):''}</small></div><div class="kpi"><span class="muted mini">Meilleure saison</span><b>${p.best_season_year||bestHistoricalSeason?.season||'—'}</b><small class="muted micro">${p.best_season_summary?esc(p.best_season_summary):''}</small></div><div class="kpi"><span class="muted mini">Semaines n°1</span><b>${fmt(p.weeks_at_no1||0)}</b></div></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Semaines Top 10</span><b>${fmt(p.weeks_top10||0)}</b></div><div class="kpi"><span class="muted mini">Semaines Top 100</span><b>${fmt(p.weeks_top100||0)}</b></div><div class="kpi"><span class="muted mini">Titres</span><b>${titleCount}</b></div><div class="kpi"><span class="muted mini">Grand Chelem</span><b>${slamCount}</b></div></div><div class="muted micro" style="margin-top:8px">${esc(p.ranking_history_source||'Archive ATP')} · ${fmt(p.ranking_history_weeks||0)} semaines indexées.</div></div><div class="card" style="margin-top:12px"><h2>Snapshots de la sauvegarde</h2>${d.history.length?d.history.map(h=>`<div class="list-item row between"><span>${df(h.snapshot_date)}</span><b>#${h.ranking} · ${fmt(h.points)} pts</b></div>`).join(''):'<div class="empty">Pas encore assez de snapshots dans la sauvegarde.</div>'}</div></template>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur</h2><p>${esc(e.message)}</p></div></div>`}
}
window.playerSection=s=>{const body=document.getElementById('playerBody');if(!body)return;if(!body.dataset.profile)body.dataset.profile=body.innerHTML;const map={attrs:'attrsTpl',analytics:'analyticsTpl',development:'developmentTpl',matches:'matchesTpl',double:'doubleTpl',career:'careerTpl',commercial:'commercialTpl',history:'historyTpl'};const t=document.getElementById(map[s]);if(s==='profile')body.innerHTML=body.dataset.profile;else if(t)body.innerHTML=t.innerHTML;overlay.querySelectorAll('[data-player-tab]').forEach(b=>{b.classList.toggle('active',b.dataset.playerTab===s);b.setAttribute('aria-selected',String(b.dataset.playerTab===s))});}
window.closeOverlay=()=>{overlay.innerHTML='';};
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeOverlay();});
window.toggleShortlist=async id=>{
 local.shortlist=local.shortlist||[];
 const active=!local.shortlist.includes(id);
 try{await get('/api/shortlist',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({player_id:id,active,priority:'Normal'})})}catch(e){console.warn(e)}
 local.shortlist=active?[...new Set([...local.shortlist,id])]:local.shortlist.filter(x=>x!==id);
 persist();await loadManagement();closeOverlay();render();
}
function tournamentDoublesHistoryHtml(rows){
 if(!Array.isArray(rows)||!rows.length)return '';
 const team=(aId,aName,bId,bName,champ)=>{
  if(!aName)return '—';
  const a=aId?"<span class='click' onclick='openPlayer("+aId+")'>"+esc(aName)+"</span>":esc(aName);
  const b=bName?(bId?"<span class='click' onclick='openPlayer("+bId+")'>"+esc(bName)+"</span>":esc(bName)):'—';
  return (champ?'🏆 ':'')+a+' / '+b;
 };
 return "<div style='margin-top:14px'><div class='row between'><div><div class='eyebrow'>Archive double</div><h2>Palmarès double documenté</h2></div><span class='badge'>"+rows.length+" édition"+(rows.length>1?'s':'')+"</span></div>"+
  "<div class='notice mini' style='margin-top:8px'><b>Couverture source :</b> le double est documenté partiellement entre 2000 et 2020. Les années absentes ne sont pas inventées.</div>"+
  "<div class='table-wrap' style='margin-top:8px'><table class='table'><thead><tr><th>Année</th><th>Champions</th><th>Finalistes</th><th>Surface</th></tr></thead><tbody>"+
  rows.map(h=>"<tr><td class='rank-num'>"+h.season+"</td><td><b>"+team(h.winner_a_id,h.winner_a_name,h.winner_b_id,h.winner_b_name,true)+"</b></td><td>"+team(h.runner_a_id,h.runner_a_name,h.runner_b_id,h.runner_b_name,false)+"</td><td>"+esc(h.surface||'—')+"</td></tr>").join('')+
  "</tbody></table></div></div>";
}

window.openTournament=async id=>{
 const fallback=[...(tourRows||[]),...(boot.upcoming||[]),...(scheduleAdvice?.recommended||[])].find(x=>x.id===id);if(!id)return;
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du tournoi…</div></div></div>';
 try{
  const d=await get('/api/tournament-detail?id='+id),t=d.tournament||fallback;if(!t)throw new Error('Tournoi introuvable');
  const cr=career(),wc=d.wildcard||null,isJunior=String(t.circuit)==='Junior',isNcaa=String(t.circuit)==='NCAA',isFed=String(t.circuit)==='Federation';
  const joined=(local.entries||[]).includes(t.id),dJoined=(local.doublesEntries||[]).includes(t.id);
  let singleRule=singlesEligibility(t),doubleRule=doublesEligibility(t);
  const serverRun=d.run||null,doublesRun=d.doubles_run||null;
  const activePartner=activeDoublesPartner();
  const played=local.playedTournaments?.[t.id]||(serverRun?{user_round:serverRun.user_round,user_points:serverRun.user_points,user_prize:serverRun.user_prize}:null);
  const pairs=(d.main||[]).slice(0,Math.min(64,t.draw_size||32));
  const ncaaPlayers=d.ncaa_players||[];
  const forfeits=d.forfeits||[];
  const completedDraw=d.completed_draw||[];
  const doublesProjection=d.doubles_main||[],doublesCompleted=d.doubles_completed_draw||[];
  const drawRounds=[...new Set(completedDraw.map(m=>m.round_name))];
  const editionHistory=d.tournament_history||[],doublesEditionHistory=d.tournament_doubles_history||[],historyRecords=d.tournament_history_records||{};
  const historyMajor=['Grand Chelem','Masters 1000','ATP 500','ATP 250','ATP Finals','Challenger 175','Challenger 125'].includes(String(t.category||''));

  const managedId=Number(cr.managed_player_id||boot?.career?.managed_player_id||0);
  const managedJunior=pairs.find(p=>Number(p.id)===managedId);
  const isJuniorFinals=isJunior&&/Junior Finals/i.test(String(t.category||''))&&!/Double/i.test(String(t.category||''));
  const isJuniorDoubleFinals=/Junior Double Finals/i.test(String(t.category||''));
  const isAtpSinglesFinals=String(t.circuit)==='ATP'&&/ATP Finals/i.test(String(t.category||''))&&!/Next Gen/i.test(String(t.category||''))&&Boolean(t.singles);
  const isAtpDoubleFinals=String(t.circuit)==='ATP'&&/ATP Finals/i.test(String(t.category||''))&&Boolean(t.doubles);
  const isSinglesFinals=isJuniorFinals||isAtpSinglesFinals;
  const isDoublesFinals=isJuniorDoubleFinals||isAtpDoubleFinals;
  if(isJuniorFinals){
    const raceEntry=pairs.find(p=>Number(p.id)===managedId);
    singleRule=raceEntry
      ?{label:'Qualifié Race Junior #'+fmt(raceEntry.ranking||raceEntry.seed||'—'),cls:'good',can:true,phase:'finals'}
      :{label:'Non qualifié · Top 8 Race Junior requis',cls:'bad',can:false,phase:'finals'};
  }else if(isAtpSinglesFinals){
    const raceEntry=pairs.find(p=>Number(p.id)===managedId);
    singleRule=raceEntry
      ?{label:'Qualifié ATP Race #'+fmt(raceEntry.ranking||raceEntry.seed||'—'),cls:'good',can:true,phase:'finals'}
      :{label:'Non qualifié · Top 8 ATP Race requis',cls:'bad',can:false,phase:'finals'};
  }
  if(isDoublesFinals){
    const partnerId=Number(activePartner?.id||0);
    const racePair=doublesProjection.find(x=>{
      const a=Number(x.player_a?.id||0),b=Number(x.player_b?.id||0);
      return (a===managedId&&b===partnerId)||(a===partnerId&&b===managedId);
    });
    doubleRule=racePair
      ?{label:'Qualifié Race #'+fmt(racePair.race_rank||racePair.seed||'—'),cls:'good',can:true,phase:'finals'}
      :{label:'Non qualifié · Top 8 Race requis',cls:'bad',can:false,phase:'finals'};
  }
  const rawElig=managedJunior&&!isSinglesFinals?'Engagé officiel':singleRule.label;
  const elig=wc?.status==='accepted'&&!isSinglesFinals?'Wild Card':rawElig;
  const canAttempt=(isSinglesFinals||(!isJunior&&!isNcaa&&!isFed))&&(singleRule.can||(!isSinglesFinals&&wc?.status==='accepted'));
  const cuts=tmCuts(t);

  const rankTitle=isJunior?'Junior':'ATP';
  const drawIntro=isJunior
    ?((d.junior_entries||[]).length?'Engagés/résultats vérifiés pour ce tournoi junior.':'Projection à partir du classement junior vérifié.')
    :'Avant le tirage officiel, Court Boss affiche une projection à partir du classement et du cut.';
  const sourceLink=t.source_url?'<a class="soft-btn" href="'+esc(t.source_url)+'" target="_blank" rel="noopener noreferrer">Source officielle</a>':'';
  const detailPhoto=String(t.image_url||"").trim()||(t.id?API+'/api/tournament-image?id='+encodeURIComponent(t.id):'');
  const detailPhotoLabel=t.image_source_label||'Photo du tournoi';

  const juniorResults=(d.junior_entries||[]).map(e=>{
    const p=Array.isArray(e.players)?e.players[0]:e.players;
    return p?`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">Junior #${p.junior_ranking||'—'} ${e.seed?'· TDS '+esc(e.seed):''}</div></div><b>${esc(e.result||'Engagé')}</b></div>`:'';
  }).join('');

  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div class="tm-title-with-logo">${tournamentLogoHtml(t,'tm-detail-logo')}<div><div class="eyebrow">${esc(t.circuit||'Circuit')} · ${esc(t.category||t.level)}</div><h1>${flags[t.country]||'🏳️'} ${esc(t.name)}</h1><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} → ${df(t.end_date)}</div></div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   ${detailPhoto?`<div class="tm-tour-hero"><img src="${esc(detailPhoto)}" alt="${esc(t.name)}" onerror="this.parentElement.style.display='none'"><div class="tm-tour-hero-overlay"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.circuit)}</span><span class="badge good">${esc(detailPhotoLabel)}</span></div></div>`:''}
   <div class="tabs" style="margin-top:12px"><button class="active" onclick="tourSection('overview')">Vue</button>${editionHistory.length?'<button onclick="tourSection(\'history\')">Histoire '+editionHistory.length+'</button>':''}${isNcaa?`<button onclick="tourSection('ncaa')">NCAA / ITA</button>`:`<button onclick="tourSection('draw')">${isJunior?'Engagés':'Tableau'}</button>${!isJunior?'<button onclick="tourSection(\'qual\')">Qualifs</button>':''}${t.doubles?'<button onclick="tourSection(\'double\')">Double</button>':''}<button onclick="tourSection('forfeits')">Forfaits ${forfeits.length}</button>${(completedDraw.length||juniorResults)?`<button onclick="tourSection('results')">Résultats</button>`:''}`}</div>
   <div id="tourBody">
    <div class="grid g2">
      <div class="card"><div class="row between"><h2>${isNcaa?'Accès NCAA':isFed?'Sélection':isJunior?'Circuit Junior':'Inscription simple'}</h2><span class="badge ${singleRule.cls}">${esc(elig)}</span></div>
        <div class="list-item row between"><span>Cut tableau</span><b>${cuts.direct?'#'+fmt(cuts.direct)+(cuts.projected?' · projeté':''):'—'}</b></div>
        <div class="list-item row between"><span>Cut qualifs</span><b>${cuts.qual?'#'+fmt(cuts.qual)+(cuts.projected?' · projeté':''):'—'}</b></div>
        <div class="list-item row between"><span>Deadline simple</span><b>${t.singles_entry_deadline?df(t.singles_entry_deadline):'—'}</b></div>
        <div class="list-item row between"><span>Deadline qualifs</span><b>${t.qualifying_entry_deadline?df(t.qualifying_entry_deadline):'—'}</b></div>
        ${wc&&!isJunior&&!isNcaa&&!isFed?`<div class="list-item row between"><span>Wild card</span><span class="badge ${wc.status==='accepted'?'good':wc.status==='declined'?'bad':''}">${esc(wc.status)}</span></div>`:''}
        ${t.entry_rule_note?`<div class="notice mini" style="margin-top:9px"><b>Règle :</b> ${esc(t.entry_rule_note)}</div>`:''}
        <div class="row" style="margin-top:10px;flex-wrap:wrap">${sourceLink}${isNcaa?`<button class="soft-btn" onclick="closeOverlay();nav('university')">Voir mon université</button>`:isFed?`<button class="soft-btn" onclick="closeOverlay();nav('davis')">Voir la sélection</button>`:isSinglesFinals?(singleRule.can?`${!played?`<button class="primary" onclick="playTournament(${t.id})">Jouer / simuler les Finals</button>`:''}<span class="badge good">Qualification automatique par la Race</span>`:`<span class="badge bad">${esc(singleRule.label)}</span>`):singleRule.can?`<button class="${joined?'danger-btn':'primary'}" onclick="toggleSinglesEntry(${t.id});closeOverlay()">${joined?'Retirer le simple':'Inscription simple'}</button>${joined&&!played&&canAttempt?`<button class="primary" onclick="playTournament(${t.id})">Jouer / simuler</button>`:''}`:`<span class="badge bad">${esc(singleRule.label)}</span>`}</div>
        ${played?`<div class="notice" style="margin-top:10px"><b>Résultat :</b> ${esc(played.user_round)} · +${played.user_points} pts · +${euro(played.user_prize)}</div>`:''}
      </div>
      <div class="card"><h2>Format & calendrier</h2><div class="list-item row between"><span>Surface</span><b class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Tableau simple</span><b>${t.singles_draw_size||t.draw_size||'—'}</b></div><div class="list-item row between"><span>Qualifs</span><b>${isSinglesFinals?'Top 8 Race · qualification automatique':t.qualifying_draw_size||'—'}</b></div><div class="list-item row between"><span>Tableau double</span><b>${t.doubles?t.doubles_draw_size||t.draw_size||'—':'Non'}</b></div>${(isSinglesFinals||isDoublesFinals)?'<div class="list-item row between"><span>Format Finals</span><b>2 groupes de 4 · demi-finales · finale</b></div>':''}<div class="list-item row between"><span>Points vainqueur</span><b>${isJuniorFinals?'1 000':t.winner_points!=null?fmt(t.winner_points):'—'}</b></div><div class="list-item row between"><span>Prize money</span><b>${t.prize_money!=null?euro(t.prize_money):'—'}</b></div><div class="list-item row between"><span>Donnée</span><b>${t.is_verified?'Officielle':'Fictive Court Boss'}</b></div></div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Historique</div><h2>Tenant du titre</h2></div><span class="badge">${t.defending_champion_year||'—'}</span></div>
       ${t.defending_champion_name?`<div class="list-item row between"><span>Simple</span><b class="click" ${t.defending_champion_player_id?`onclick="openPlayer(${t.defending_champion_player_id})"`:''}>🏆 ${esc(t.defending_champion_name)}</b></div>`:`<div class="list-item row between"><span>Simple</span><b>${t.defending_champion_source&&/première édition/i.test(t.defending_champion_source)?'Première édition':'—'}</b></div>`}
       ${t.defending_doubles_champion_name?`<div class="list-item row between"><span>Double</span><b>🏆 ${esc(t.defending_doubles_champion_name)} / ${esc(t.defending_doubles_partner_name||'')}</b></div>`:''}
       ${t.defending_champion_source?`<div class="muted micro" style="margin-top:8px">${esc(t.defending_champion_source)}</div>`:''}
      </div>
    </div>
    ${t.doubles&&!isNcaa?`<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Inscription double</div><h2>${activePartner?esc(activePartner.name):'Partenaire requis'}</h2></div><span class="badge ${doubleRule.cls}">${esc(doubleRule.label)}</span></div><div class="list-item row between"><span>Ton rang double</span><b>#${fmt(cr.doubles_rank||0)}</b></div>${activePartner?`<div class="list-item row between"><span>Partenaire</span><b>#${fmt(activePartner.doubles_ranking||0)} · ${esc(activePartner.name)}</b></div>`:''}<div class="list-item row between"><span>Advance entry double</span><b>${t.doubles_entry_deadline?df(t.doubles_entry_deadline):String(t.entry_rule_code)==='ITF_M15'?'Aucune':'—'}</b></div><div class="list-item row between"><span>On-site sign-in</span><b>${t.doubles_onsite_deadline?df(t.doubles_onsite_deadline):'—'}</b></div>${doublesRun?`<div class="notice good"><b>Déjà joué :</b> ${esc(doublesRun.user_round)} · +${doublesRun.user_points||0} pts · +${euro(doublesRun.user_prize||0)}</div>`:isDoublesFinals?(doubleRule.can?`<button class="primary" style="width:100%;margin-top:8px" onclick="playDoublesTournament(${t.id})">Jouer / simuler les Finals double</button><div class="notice good mini" style="margin-top:8px">Qualification automatique par la Race de la paire.</div>`:`<div class="notice bad mini" style="margin-top:8px">${esc(doubleRule.label)}</div><button class="soft-btn" style="width:100%;margin-top:8px" onclick="closeOverlay();nav('doubles')">Voir la Race Double</button>`):doubleRule.can?`<button class="${dJoined?'danger-btn':'primary'}" style="width:100%;margin-top:8px" onclick="toggleDoublesEntry(${t.id});closeOverlay()">${dJoined?'Retirer le double':'Inscrire la paire'}</button>`:`<button class="soft-btn" style="width:100%;margin-top:8px" onclick="closeOverlay();nav('doubles')">${activePartner?'Voir le hub Double':'Choisir un partenaire'}</button>`}</div>`:''}
   </div>

   <template id="tourOverviewTpl"><div class="grid g2"><div class="card"><h2>${isNcaa?'Accès NCAA / ITA':isJunior?'Circuit Junior':'Entrée'}</h2>${isNcaa?`<div class="list-item row between"><span>Mode d’accès</span><b>${esc(singleRule.label)}</b></div><div class="list-item row between"><span>Inscription libre</span><b>Non</b></div><div class="list-item row between"><span>Profils NCAA indexés</span><b>${fmt(ncaaPlayers.length)}</b></div>${t.entry_rule_note?`<div class="notice mini" style="margin-top:8px">${esc(t.entry_rule_note)}</div>`:''}`:isJunior?`<div class="list-item row between"><span>Classement</span><b>ITF Junior</b></div><div class="list-item row between"><span>Engagés connus</span><b>${pairs.length}</b></div>`:`<div class="list-item row between"><span>Cut tableau</span><b>${cuts.direct?'#'+fmt(cuts.direct)+(cuts.projected?' · proj.':''):'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${cuts.qual?'#'+fmt(cuts.qual)+(cuts.projected?' · proj.':''):'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`}</div><div class="card"><h2>Format</h2><div class="list-item row between"><span>Tableau / champ</span><b>${t.singles_draw_size||t.draw_size||'—'}</b></div><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Référence</span><b>${t.is_verified?'Officielle':'Simulation'}</b></div><div class="list-item row between"><span>Simple / Double</span><b>${t.singles?'S':''}${t.singles&&t.doubles?' + ':''}${t.doubles?'D':''}</b></div></div></div></template>

   <template id="tourNcaaTpl"><div class="card"><div class="row between"><div><div class="eyebrow">Circuit universitaire</div><h2>Vivier NCAA · ITA + UTR</h2></div><span class="badge">${fmt(ncaaPlayers.length)} profils</span></div><p class="muted mini">ITA = classement universitaire. UTR = niveau individuel séparé. Le symbole ~ indique une estimation Court Boss quand aucune valeur UTR sourcée n’est disponible.</p><div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>ITA</th><th>Joueur</th><th>Université</th><th>UTR</th><th>ATP</th><th>Statut</th></tr></thead><tbody>${ncaaPlayers.slice(0,125).map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${p.ita_rank?'#'+fmt(p.ita_rank):'—'}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${esc(p.school||p.ncaa_school||'—')}</td><td>${p.utr_rating!=null?'<b>'+(p.utr_verified?'':'~')+Number(p.utr_rating).toFixed(2)+'</b>':'—'}</td><td>${p.ranking?'#'+fmt(p.ranking):'—'}</td><td><span class="badge good">${esc(p.ncaa_status||'Active')}</span></td></tr>`).join('')}</tbody></table></div>${!ncaaPlayers.length?'<div class="empty">Aucun profil NCAA relié à ce snapshot.</div>':''}</div></template>

   <template id="tourDrawTpl"><div class="card"><h2>${isJunior?'Engagés juniors':'Liste d’acceptation / tableau projeté'}</h2><p class="muted mini">${drawIntro}</p><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Points</th><th>${isJunior?'Seed / résultat':'Forme'}</th></tr></thead><tbody>${pairs.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${p.ranking||'—'}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.points==null?'—':fmt(p.points)}</td><td>${isJunior?esc([p.seed?'TDS '+p.seed:'',p.result||''].filter(Boolean).join(' · ')||'Engagé'):(p.form??'—')}</td></tr>`).join('')}</tbody></table></div></div></template>

   <template id="tourQualTpl"><div class="card"><h2>Qualifications</h2><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Condition</th></tr></thead><tbody>${(d.qualifying||[]).map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${p.ranking}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.fitness}% / fatigue ${p.fatigue}%</td></tr>`).join('')}</tbody></table></div></div></template>

   <template id="tourDoubleTpl">
    <div class="grid g2"><div class="card"><div class="eyebrow">Partenariat</div><h2>${activePartner?flags[activePartner.country]||'🏳️':''} ${activePartner?esc(activePartner.name):'Aucun partenaire'}</h2><div class="list-item row between"><span>Ton classement</span><b>#${fmt(cr.doubles_rank||0)}</b></div>${activePartner?`<div class="list-item row between"><span>Partenaire</span><b>#${fmt(activePartner.doubles_ranking||0)}</b></div><div class="list-item row between"><span>Chimie</span><b>${pairScore(activePartner,'chem')}%</b></div>`:''}</div><div class="card"><div class="eyebrow">Tournoi</div><h2>${esc(t.name)} · Double</h2><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Catégorie</span><b>${esc(t.category||t.level||'—')}</b></div>${doublesRun?`<div class="notice good"><b>Résultat :</b> ${esc(doublesRun.user_round)} · +${doublesRun.user_points||0} pts</div>`:isDoublesFinals?(doubleRule.can&&activePartner?`<button class="primary" style="width:100%;margin-top:10px" onclick="playDoublesTournament(${t.id})">Jouer / simuler les Finals double</button><div class="notice good mini" style="margin-top:8px">Top 8 Race · paire qualifiée automatiquement.</div>`:`<div class="notice bad mini" style="margin-top:8px">${esc(doubleRule.label)}</div><button class="soft-btn" style="width:100%;margin-top:8px" onclick="setRankKind('${isJuniorDoubleFinals?'junior_doubles_race':'doubles_race'}');closeOverlay();nav('rankings')">Voir la Race</button>`):activePartner?`<button class="primary" style="width:100%;margin-top:10px" onclick="playDoublesTournament(${t.id})">Jouer / simuler le double</button>`:`<button class="soft-btn" style="width:100%;margin-top:10px" onclick="closeOverlay();nav('doubles')">Choisir un partenaire</button>`}</div></div>
    <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Projection tableau</div><h2>Paires de double</h2></div><span class="badge">${doublesProjection.length} équipes</span></div><div class="table-wrap"><table class="table"><thead><tr><th>TDS</th><th>Équipe</th><th>Rangs double</th><th>Source</th></tr></thead><tbody>${doublesProjection.slice(0,32).map(x=>`<tr><td>#${x.seed}</td><td><b>${flags[x.player_a?.country]||'🏳️'} ${esc(x.player_a?.name)} / ${flags[x.player_b?.country]||'🏳️'} ${esc(x.player_b?.name)}</b></td><td>#${fmt(x.player_a?.doubles_ranking||0)} / #${fmt(x.player_b?.doubles_ranking||0)}</td><td><span class="badge ${x.source==='official'?'good':''}">${x.source==='official'?'Officiel':x.source==='affinity-pair'?'Paire active · affinité':x.source==='atp-doubles-race'?'Race Double':x.source==='junior-doubles-race'?'Race Junior Double':x.source==='junior-simulated'?'Junior Double':'Index DB'}</span></td></tr>`).join('')}</tbody></table></div>${!doublesProjection.length?'<div class="empty">Aucune projection double disponible.</div>':''}</div>
    ${doublesCompleted.length?`<div class="card" style="margin-top:12px"><div class="eyebrow">Ton parcours double</div><h2>Résultats</h2>${doublesCompleted.map(m=>`<div class="list-item"><div class="row between"><b>${esc(m.round_name)}</b><b>${esc(m.score)}</b></div><div>${esc(m.user_pair)} vs ${esc(m.opponent_pair)}</div><div class="muted mini">Vainqueurs : ${esc(m.winner_pair)}</div></div>`).join('')}</div>`:''}
   </template>

   <template id='tourHistoryTpl'>
    <div class='card'>
      <div class='row between'><div><div class='eyebrow'>Archives du tournoi</div><h2>Palmarès année par année</h2></div><span class='badge'>${editionHistory.length} édition${editionHistory.length>1?'s':''}</span></div>
      <div class='kpi-strip' style='margin-top:10px'>
        <div class='kpi'><span class='muted mini'>Record de titres</span><b style='font-size:14px'>${historyRecords.most_titles_name?esc(historyRecords.most_titles_name):'—'}</b><small class='muted micro'>${historyRecords.most_titles?fmt(historyRecords.most_titles)+' titre(s)':''}</small></div>
        <div class='kpi'><span class='muted mini'>Dernier vainqueur</span><b style='font-size:14px'>${historyRecords.latest_winner?esc(historyRecords.latest_winner):'—'}</b><small class='muted micro'>${historyRecords.latest_season||''}</small></div>
        <div class='kpi'><span class='muted mini'>Couverture</span><b>${editionHistory.length?editionHistory[editionHistory.length-1].season+'–'+editionHistory[0].season:'—'}</b></div>
        <div class='kpi'><span class='muted mini'>Niveau</span><b style='font-size:13px'>${esc(t.category||t.level||'—')}</b></div>
      </div>
      ${historyMajor?'<div class="notice mini" style="margin-top:10px"><b>Historique FM :</b> vainqueurs et finalistes issus des archives Court Boss / Tennis Abstract quand disponibles. Les changements de sponsor sont regroupés sous le même tournoi.</div>':''}
      <div class='table-wrap' style='margin-top:10px'><table class='table'><thead><tr><th>Année</th><th>Vainqueur</th><th>Finaliste</th><th>Score</th><th>Surface</th></tr></thead><tbody>
       ${editionHistory.map(h=>'<tr><td class="rank-num">'+h.season+'</td><td>'+(h.winner_player_id?'<b class="click" onclick="openPlayer('+h.winner_player_id+')">🏆 '+esc(h.winner_name)+'</b>':'<b>🏆 '+esc(h.winner_name||'—')+'</b>')+'</td><td>'+(h.runner_up_player_id?'<span class="click" onclick="openPlayer('+h.runner_up_player_id+')">'+esc(h.runner_up_name||'—')+'</span>':esc(h.runner_up_name||'—'))+'</td><td class="muted mini">'+esc(h.score||'—')+'</td><td>'+esc(h.surface||'—')+'</td></tr>').join('')}
      </tbody></table></div>
      ${tournamentDoublesHistoryHtml(doublesEditionHistory)}
    </div>
   </template>
   <template id="tourForfeitsTpl"><div class="card"><h2>Forfaits</h2>${forfeits.length?forfeits.map(x=>{const p=Array.isArray(x.players)?x.players[0]:x.players;return `<div class="list-item row between">${p?`<div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${isJunior?'Junior':'ATP'} #${p.junior_ranking||p.ranking||'—'}</div></div>`:'<div>Joueur indisponible</div>'}<span class="badge bad">${esc(x.reason||'Blessure')}</span></div>`}).join(''):'<div class="empty">Aucun forfait enregistré.</div>'}</div></template>

   <template id="tourResultsTpl">${isJunior&&juniorResults?`<div class="card"><h2>Résultats / statut des engagés</h2>${juniorResults}</div>`:''}<div class="stack">${drawRounds.map(r=>`<div class="card"><h2>${esc(r)}</h2>${completedDraw.filter(m=>m.round_name===r).map(m=>`<div class="list-item"><div class="row between"><div><div ${m.player_a_id?`class="click" onclick="openPlayer(${m.player_a_id})"`:''}>${esc(m.player_a_name)}</div><div ${m.player_b_id?`class="click" onclick="openPlayer(${m.player_b_id})"`:''}>${esc(m.player_b_name)}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="muted mini">Vainqueur : ${esc(m.winner_name)}</div></div></div></div>`).join('')}</div>`).join('')}</div></template>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur tournoi</h2><p>${esc(e.message)}</p></div></div>`}
}
window.requestWildcard=async id=>{
 try{
   const d=await managerAction('request_wildcard',id);
   alert(d.status==='accepted'?'Wild card accordée. Tu peux entrer dans le tableau.':'Wild card refusée pour ce tournoi.');
   await openTournament(id);
 }catch(e){alert(e.message)}
}
window.playTournament=async id=>{
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Simulation du tournoi en cours…</div></div></div>';
  try{
    const d=await get('/api/play-tournament',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tournament_id:id,tactics:local.tactics||{}})});
    local.playedTournaments=local.playedTournaments||{};local.playedTournaments[id]=d;
    boot=await get('/api/bootstrap');
    if(boot.career)local.career={...(local.career||{}),budget:boot.career.budget,points:boot.career.points,singles_rank:boot.career.singles_rank,fatigue:boot.career.fatigue,fitness:boot.career.fitness,form:boot.career.form,morale:boot.career.morale};
    await Promise.all([loadRankings(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice()]);
    persist();
    overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(d.tournament?.name||'Tournoi')}</div><h1>${d.user_round==='Champion'?'🏆 Champion':esc(d.user_round)}</h1><div class="muted">Champion : ${esc(d.champion?.name||'—')}</div><div class="row" style="margin-top:6px">${d.wildcard?'<span class="badge good">Wild Card</span>':''}${d.alternate?'<span class="badge warn">Alternate entré</span>':''}${d.lucky_loser?'<span class="badge warn">Lucky Loser</span>':''}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
      <div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Tour atteint</span><b style="font-size:16px">${esc(d.user_round)}</b></div><div class="kpi"><span class="muted mini">Points</span><b>+${d.user_points}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${euro(d.user_prize)}</b></div><div class="kpi"><span class="muted mini">Voyage</span><b>-${euro(d.travel_cost||0)}</b></div></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Fatigue ajoutée</span><b>+${d.fatigue_added||0}</b></div><div class="kpi"><span class="muted mini">Fitness après</span><b>${d.fitness||career().fitness}%</b></div><div class="kpi"><span class="muted mini">Matchs tableau</span><b>${d.draw_matches}</b></div><div class="kpi"><span class="muted mini">Décision</span><b style="font-size:13px">${(d.fatigue_added||0)>20?'Récupération conseillée':'Charge gérable'}</b></div></div>
      <div class="card" style="margin-top:12px"><h2>Parcours de ${esc(career().player_name||'Joueur')}</h2>${(d.matches||[]).map(m=>`<div class="list-item"><div class="row between"><b>${esc(m.round_name)}</b><span class="badge ${m.winner_name===(career().player_name||'Anthony')?'good':'bad'}">${m.winner_name===(career().player_name||'Anthony')?'Victoire':'Défaite'}</span></div><div>${esc(m.player_a_name)} vs ${esc(m.player_b_name)}</div><div class="muted mini">${esc(m.score)}</div>${m.stats?`<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">1res balles</span><b>${m.stats.first_serve_pct}%</b></div><div class="kpi"><span class="muted mini">Winners</span><b>${m.stats.winners}</b></div><div class="kpi"><span class="muted mini">Fautes</span><b>${m.stats.unforced_errors}</b></div><div class="kpi"><span class="muted mini">Filet</span><b>${m.stats.net_points_won_pct}%</b></div></div>`:''}</div>`).join('')||'<div class="empty">Aucun match utilisateur.</div>'}</div>
    </div></div>`;
  }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Tournoi impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`}
}
window.playDoublesTournament=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Simulation du tableau double…</div></div></div>';
 try{
  const d=await get('/api/play-doubles',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tournament_id:id})});
  boot=await get('/api/bootstrap');
  if(boot.career)local.career={...(local.career||{}),budget:boot.career.budget,doubles_rank:boot.career.doubles_rank,doubles_points:boot.career.doubles_points,fatigue:boot.career.fatigue,fitness:boot.career.fitness};
  await Promise.all([loadManagement(),loadSeasonSummary(),loadDoublesHub()]);
  persist();
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(d.tournament?.name||'Double')}</div><h1>${d.round==='Champion'?'🏆 Champions':esc(d.round)}</h1><div class="muted">Avec ${esc(d.partner?.name||'partenaire')} · nouveau rang double #${fmt(d.rank||career().doubles_rank)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Tour</span><b>${esc(d.round)}</b></div><div class="kpi"><span class="muted mini">Points double</span><b>+${d.points||0}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${euro(d.prize||0)}</b></div><div class="kpi"><span class="muted mini">Fatigue</span><b>+${d.fatigue_added||0}</b></div></div><div class="card" style="margin-top:12px"><h2>Parcours</h2>${(d.matches||[]).map(m=>`<div class="list-item"><div class="row between"><b>${esc(m.round_name)}</b><b>${esc(m.score)}</b></div><div class="muted mini">${esc(m.user_pair)} vs ${esc(m.opponent_pair)} · vainqueur ${esc(m.winner_pair)}</div></div>`).join('')||'<div class="empty">Aucun match.</div>'}</div></div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Double impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`}
}
window.tourSection=s=>{const m={overview:'tourOverviewTpl',history:'tourHistoryTpl',ncaa:'tourNcaaTpl',draw:'tourDrawTpl',qual:'tourQualTpl',double:'tourDoubleTpl',forfeits:'tourForfeitsTpl',results:'tourResultsTpl'},t=document.getElementById(m[s]);if(t)document.getElementById('tourBody').innerHTML=t.innerHTML}

async function managerAction(action,id,extra={}){
  return get('/api/manager-action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,id,...extra})});
}
async function refreshManagerState(){
  boot=await get('/api/bootstrap');
  await loadManagement();
  if(boot.career){
    local.career={...(local.career||{}),budget:boot.career.budget};
    persist();
  }
}
window.openYouth=id=>{
  const y=(boot.youth||[]).find(x=>x.id===id);if(!y)return;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Prospect académie</div><h1>${flags[y.country]||'🏳️'} ${esc(y.name)}</h1><div class="muted">${y.age} ans · ${esc(y.style||'')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  <div class="grid g2" style="margin-top:12px"><div class="card"><div class="big">PA ${y.potential}</div><div class="muted">Potentiel estimé</div></div><div class="card"><div class="big">CA ${y.current_ability}</div><div class="muted">Niveau actuel</div></div></div>
  <div class="card" style="margin-top:12px"><div class="list-item row between"><span>Coût académie</span><b>${euro(y.scholarship_cost)}</b></div><div class="list-item row between"><span>Statut</span><b>${esc(y.status||'prospect')}</b></div>${y.status==='signed'?'<div class="notice">Ce joueur est déjà sous contrat avec ton académie.</div>':`<button class="primary" style="margin-top:10px" onclick="signYouth(${y.id})">Signer le prospect</button>`}</div></div></div>`;
}
window.signYouth=async id=>{try{const d=await managerAction('sign_youth',id);if(local.career)local.career.budget=d.budget;await refreshManagerState();closeOverlay();render()}catch(e){alert(e.message)}}
window.openStaff=id=>{
  const s=(boot.staff||[]).find(x=>x.id===id);if(!s)return;
  const p=s.profile||null,n=s.name||p?.name||s.role;
  const course=p?.id?(management?.userStaffTraining||[]).find(x=>Number(x.staff_profile_id)===Number(p.id)&&x.status==='active'):null;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(s.role)}</div><h1>${esc(n)}</h1><div class="muted">${esc(p?.specialty||'Membre du staff')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="row between"><span>Niveau poste</span><b>${s.skill}/20</b></div><div class="bar"><i style="width:${s.skill*5}%"></i></div><div class="list-item row between"><span>Coût hebdomadaire</span><b>${euro(s.weekly_cost)}</b></div>${p?`<div class="list-item row between"><span>Charge</span><b>${p.workload??0}/100</b></div><div class="list-item row between"><span>Burnout</span><b class="${Number(p.burnout||0)>=65?'bad':''}">${p.burnout??0}/100</b></div><div class="list-item row between"><span>Énergie</span><b>${p.energy??100}/100</b></div>${p.operational_status==='rest'?`<div class="notice warn">Au repos jusqu’au ${df(p.rest_until)}.</div>`:''}`:''}${p?`<div class="list-item row between"><span>Parcours</span><b>${esc(staffFormerLabel(p))}</b></div>`:''}${p?.former_player_id?`<button class="ghost" onclick="openPlayer(${p.former_player_id})">Voir la carrière joueur</button>`:''}</div>${p?`<div class="card" style="margin-top:10px"><h2>Attributs staff</h2>${staffMetaBadges(p)}${staffRatingGrid(p)}<p class="muted mini" style="margin-top:8px">${esc(p.notes||'Notes de gameplay Court Boss.')}</p><div class="muted micro">${esc(p.source_label||'Court Boss')}</div><button class="ghost" style="margin-top:8px" onclick="openStaffProfile(${p.id})">Dossier carrière complet</button></div>`:''}<div class="row" style="gap:8px;margin-top:10px;flex-wrap:wrap">${course?`<div class="card" style="width:100%"><div class="row between"><span>Formation active · ${esc(course.focus||'')}</span><b>${course.progress||0}%</b></div><div class="bar" style="margin-top:6px"><i style="width:${Number(course.progress||0)}%"></i></div><div class="muted micro" style="margin-top:4px">${esc(course.center?.name||'Centre')} · fin ${df(course.expected_end)}</div></div>`:p?`<button class="primary" onclick="openStaffTraining(${s.id})">Former / certifier</button>`:''}${p&&p.operational_status!=='rest'&&Number(p.burnout||0)>=35?`<button class="ghost" onclick="restStaff(${s.id})">Repos 2 semaines</button>`:''}<button class="danger-btn" onclick="fireStaff(${s.id})">Se séparer</button></div></div></div>`;
}
window.openStaffTraining=id=>{
 const member=(boot.staff||[]).find(x=>Number(x.id)===Number(id));if(!member)return;
 const centers=management?.staffTrainingCenters||[];
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Formation staff</div><h1>${esc(member.name||member.profile?.name||member.role)}</h1><div class="muted">Choisis une spécialisation. La progression se fait chaque mois de jeu.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
 <div class="grid g2">${centers.map(c=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(c.specialty||'Formation')}</div><h2>${esc(c.name)}</h2><div class="muted mini">${esc(c.country||'INT')} · réputation ${c.reputation}/20</div></div><span class="badge">${c.course_weeks||10} sem.</span></div><div class="list-item row between"><span>Coût</span><b>${euro(c.course_cost||0)}</b></div><div class="list-item row between"><span>Capacité</span><b>${c.capacity||'—'}</b></div><button class="primary" style="margin-top:8px" onclick="enrollStaffTraining(${member.id},${c.id})">Inscrire</button></div>`).join('')||'<div class="card empty">Aucun centre disponible.</div>'}</div>
 </div></div>`;
}
window.enrollStaffTraining=async(staffId,centerId)=>{
 try{
  const d=await managerAction('enroll_staff_training',staffId,{center_id:centerId});
  if(local.career)local.career.budget=d.budget;
  await refreshManagerState();
  render();
  closeOverlay();
  alert('Formation lancée jusqu’au '+df(d.expected_end)+'.');
 }catch(e){alert(e.message)}
}
window.openStaffCandidate=id=>{
 const x=(management?.candidates||[]).find(v=>Number(v.id)===Number(id));if(!x)return;
 const p=x.profile||null,available=x.status==='available',done=x.interview_status==='completed',rejected=x.interview_status==='rejected';
 const demands=x.demands||{};
 const demandRows=[
  demands.lead_role?'Rôle principal exigé':null,
  demands.shared_role?'Rôle partagé accepté':null,
  demands.performance_bonus?'Bonus de performance demandé':null,
  demands.release_clause?'Clause de sortie demandée':null,
  Array.isArray(demands.preferred_circuits)&&demands.preferred_circuits.length?'Circuits : '+demands.preferred_circuits.join(' / '):null
 ].filter(Boolean);
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet">
  <div class="sheet-head"><div><div class="eyebrow">${esc(x.role)}</div><h1>${esc(x.name)}</h1><div class="muted">${esc(x.specialty||p?.specialty||'Candidat staff')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  <div class="card">
   <div class="row between"><span>Niveau poste</span><b>${x.skill}/20</b></div>
   <div class="list-item row between"><span>Compatibilité avec ton joueur</span><b>${x.managed_fit??'—'}/100</b></div>
   <div class="list-item row between"><span>Salaire ${done?'demandé':'estimé'}</span><b>${euro(done?(x.requested_weekly||x.weekly_cost):x.weekly_cost)}/sem.</b></div>
   <div class="list-item row between"><span>Prime ${done?'demandée':'estimée'}</span><b>${euro(done?(x.requested_signing||x.signing_cost):x.signing_cost)}</b></div>
   ${done?`<div class="list-item row between"><span>Durée souhaitée</span><b>${x.desired_years||2} an(s)</b></div><div class="list-item row between"><span>Intérêt</span><b class="${Number(x.interest||0)>=70?'good':Number(x.interest||0)>=50?'warn':'bad'}">${x.interest??'—'}/100</b></div>`:''}
   <div class="list-item row between"><span>Offres concurrentes</span><b>${Number(x.competing_offers||0)}</b></div>
   ${p?`<div class="list-item row between"><span>Parcours</span><b>${esc(staffFormerLabel(p))}</b></div>`:''}
   ${p?.former_player_id?`<button class="ghost" onclick="openPlayer(${p.former_player_id})">Voir sa carrière joueur</button>`:''}
  </div>
  ${done&&demandRows.length?`<div class="card" style="margin-top:10px"><div class="eyebrow">Exigences contractuelles</div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${demandRows.map(v=>`<span class="badge">${esc(v)}</span>`).join('')}</div></div>`:''}
  ${p?`<div class="card" style="margin-top:10px"><div class="row between"><h2>Profil FM</h2><b>${x.managed_fit!=null?x.managed_fit+'/100':''}</b></div>${staffMetaBadges(p)}<div class="list-item row between"><span>Ambition / Loyauté</span><b>${p.ambition??'—'} / ${p.loyalty??'—'}</b></div><h3>Attributs 1–20</h3>${staffRatingGrid(p)}<button class="ghost" onclick="openStaffProfile(${p.id})">Dossier carrière complet</button></div>`:''}
  ${available&&!done&&!rejected?`<button class="primary" style="margin-top:10px" onclick="interviewStaff(${x.id})">Passer l'entretien</button>`:''}
  ${available&&done?`<div class="card" style="margin-top:10px"><div class="eyebrow">Négociation</div><div class="grid g3" style="margin-top:8px"><label class="mini muted">Salaire / sem.<input id="staffOfferWeekly" class="input" type="number" min="0" value="${Number(x.requested_weekly||x.weekly_cost||0)}"></label><label class="mini muted">Prime<input id="staffOfferSigning" class="input" type="number" min="0" value="${Number(x.requested_signing||x.signing_cost||0)}"></label><label class="mini muted">Durée<input id="staffOfferYears" class="input" type="number" min="1" max="5" value="${Number(x.desired_years||2)}"></label></div><div class="row" style="gap:8px;margin-top:10px;flex-wrap:wrap"><button class="ghost" onclick="counterStaffOffer(${x.id})">Proposer ces conditions</button><button class="primary" onclick="hireStaff(${x.id})">Signer aux conditions actuelles</button></div>${demands.negotiation_status==='counter'?'<div class="notice warn" style="margin-top:8px">Le candidat a fait une contre-proposition. Ajuste les conditions ou signe sur cette base.</div>':demands.negotiation_status==='agreed'?'<div class="notice good" style="margin-top:8px">Accord de principe trouvé.</div>':''}</div>`:''}
  ${rejected?'<div class="notice bad" style="margin-top:10px">Le candidat n’est pas suffisamment intéressé pour rejoindre ton projet actuellement.</div>':''}
 </div></div>`;
}
window.filterStaffMarket=()=>{
 const q=String(document.getElementById('staffMarketSearch')?.value||'').trim().toLowerCase();
 const role=String(document.getElementById('staffMarketRole')?.value||'');
 document.querySelectorAll('.staff-market-card').forEach(el=>{
  const okName=!q||String(el.dataset.name||'').includes(q);
  const okRole=!role||String(el.dataset.role||'')===role;
  el.style.display=okName&&okRole?'':'none';
 });
}
window.counterStaffOffer=async id=>{
 try{
  const weekly=Number(document.getElementById('staffOfferWeekly')?.value||0);
  const signing=Number(document.getElementById('staffOfferSigning')?.value||0);
  const years=Number(document.getElementById('staffOfferYears')?.value||2);
  const d=await managerAction('counter_staff_offer',id,{weekly,signing,years});
  await refreshManagerState();
  render();
  openStaffCandidate(id);
  if(d.status==='counter')alert('Le candidat fait une contre-proposition.');
  if(d.status==='accepted')alert('Accord de principe trouvé.');
 }catch(e){alert(e.message)}
}
window.applyStaffWorldFilters=async()=>{
 staffWorldFilters={
  q:String(document.getElementById('staffWorldQ')?.value||'').trim(),
  role:String(document.getElementById('staffWorldRole')?.value||''),
  country:String(document.getElementById('staffWorldCountry')?.value||''),
  former:String(document.getElementById('staffWorldFormer')?.value||'Tous'),
  status:String(document.getElementById('staffWorldStatus')?.value||'Tous')
 };
 staffWorldOffset=0;
 await loadStaffWorld();
 render();
}
window.staffWorldPage=async dir=>{
 const total=Number(staffWorldData?.total||0);
 const lastOffset=Math.max(0,Math.floor(Math.max(0,total-1)/50)*50);
 staffWorldOffset=Math.max(0,Math.min(lastOffset,staffWorldOffset+Number(dir||0)*50));
 await loadStaffWorld();
 render();
 const el=document.querySelector('.staff-world-filter');
 if(el)window.scrollTo({top:el.getBoundingClientRect().top+window.scrollY-90,behavior:'smooth'});
}
window.approachStaffProfile=async profileId=>{
 try{
  const d=await managerAction('approach_staff',profileId);
  await loadManagement();
  await loadStaffWorld();
  render();
  if(d?.candidate_id)openStaffCandidate(d.candidate_id);
 }catch(err){alert(err.message)}
}
window.interviewStaff=async id=>{
 try{
  const d=await managerAction('interview_staff',id);
  await refreshManagerState();
  render();
  openStaffCandidate(id);
  if(d.status==='rejected')alert("Le candidat n'est pas suffisamment intéressé pour le moment.");
 }catch(e){alert(e.message)}
}
window.hireStaff=async id=>{try{const d=await managerAction('hire_staff',id);if(local.career)local.career.budget=d.budget;await refreshManagerState();render()}catch(e){alert(e.message)}}
window.openStaffProfile=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du dossier staff…</div></div></div>';
 try{
  const d=await get('/api/staff-profile?id='+id),p=d.profile||{},active=d.activeAssignments||[],hist=d.history||[],events=d.events||[],agency=d.agency?.agency||null,licenses=d.licenses||[],pref=d.preferences||null,scope=d.scopeReputation||[],peers=d.peers||[],recs=d.recommendations||{from:[],to:[]},college=d.collegeStaff||[],davis=d.davisStaff||[],training=d.training||[],coachAcademy=d.coachAcademy||null,playerBonds=d.playerBonds||[],careerStats=d.careerStats||null,achievements=d.achievements||[],awards=d.awards||[],agentClients=d.agentClients||[],agentClientCount=Number(d.agentClientCount||0);
  const playerLink=x=>x?.player?.id?`<span class="click" onclick="openPlayer(${x.player.id})"><b>${esc(x.player.name)}</b></span>`:'—';
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet">
   <div class="sheet-head"><div><div class="eyebrow">${esc(p.primary_role||'Staff')}</div><h1>${esc(p.name||'Profil staff')}</h1><div class="muted">${esc(p.specialty||'')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="card"><div class="row between"><div><b>${esc(staffFormerLabel(p))}</b><div class="muted mini">${esc(p.nationality||'')} · Réputation ${p.reputation??'—'}/20</div></div><span class="badge">${esc(p.market_status||'')}</span></div><div style="margin-top:8px">${staffMetaBadges(p)}</div><div class="kpi-strip" style="margin-top:9px"><div class="kpi"><span class="muted micro">Charge</span><b>${p.workload??0}</b></div><div class="kpi"><span class="muted micro">Burnout</span><b>${p.burnout??0}</b></div><div class="kpi"><span class="muted micro">Énergie</span><b>${p.energy??100}</b></div><div class="kpi"><span class="muted micro">Voyage</span><b>${p.travel_fatigue??0}</b></div></div>${p.operational_status==='rest'?`<div class="notice warn" style="margin-top:8px">Repos programmé jusqu’au ${df(p.rest_until)}.</div>`:''}</div>
   ${agency||licenses.length||pref||scope.length||coachAcademy?`<div class="card" style="margin-top:10px"><h2>Réseau, formation & licences</h2>
    ${agency?`<div class="list-item row between"><span>Agence</span><b>${esc(agency.name)}</b></div><div class="muted micro">Commission ${agency.commission_pct}% · force réseau ${agency.network_strength}/20</div>`:''}
    ${coachAcademy?.academy?`<div class="list-item"><div class="row between"><span>Académie de coachs</span><b>${esc(coachAcademy.academy.name)}</b></div><div class="muted micro">${esc(coachAcademy.academy.philosophy||'')} · prestige ${coachAcademy.academy.prestige}/20</div>${coachAcademy.mentor?`<div class="micro">Mentor : <span class="click" onclick="openStaffProfile(${coachAcademy.mentor.id})">${esc(coachAcademy.mentor.name)}</span></div>`:''}</div>`:''}
    ${licenses.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${licenses.slice(0,5).map(l=>`<span class="badge">${esc(l.license_code)} · niv. ${l.license_level}</span>`).join('')}</div>`:''}
    ${pref?`<div class="list-item row between"><span>Style préféré</span><b>${esc(pref.preferred_style||'—')}</b></div><div class="list-item row between"><span>Classement visé</span><b>#${pref.preferred_min_rank||'—'} à #${pref.preferred_max_rank||'—'}</b></div><div class="list-item row between"><span>Rôle principal</span><b>${pref.wants_lead_role?'Oui':'Non'}</b></div><div class="list-item row between"><span>Partage de rôle</span><b>${pref.willing_shared_role?'Oui':'Non'}</b></div><div class="list-item row between"><span>Tolérance voyage</span><b>${pref.travel_tolerance}/20</b></div>`:''}
    ${scope.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${scope.slice(0,8).map(x=>`<span class="badge">${esc(x.scope_code)} ${x.rating}/20</span>`).join('')}</div>`:''}
   </div>`:''}
   <div class="card" style="margin-top:10px"><h2>Attributs</h2>${staffRatingGrid(p)}</div>
   ${careerStats?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Palmarès staff</div><h2>Carrière d'encadrement</h2></div><span class="badge">${careerStats.titles_total||0} titres</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Grand Chelem</span><b>${careerStats.grand_slams||0}</b></div><div class="kpi"><span class="muted micro">Masters 1000</span><b>${careerStats.masters1000||0}</b></div><div class="kpi"><span class="muted micro">Double</span><b>${careerStats.doubles_titles||0}</b></div><div class="kpi"><span class="muted micro">Meilleur client</span><b>${careerStats.best_client_rank?'#'+fmt(careerStats.best_client_rank):'—'}</b></div></div>${awards.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${awards.map(x=>`<span class="badge good">${x.season} · ${esc(x.award_name)}</span>`).join('')}</div>`:''}${achievements.length?`<div style="margin-top:8px">${achievements.slice(0,8).map(x=>`<div class="list-item"><div class="row between"><div><b>${esc(x.tournament_name)}</b><div class="muted micro">${df(x.achievement_date)} · ${esc(x.level||x.event_type||'Titre')}</div></div><span class="badge">+${x.achievement_points}</span></div>${x.player?.name?`<div class="muted micro">avec <span class="click" onclick="openPlayer(${x.player.id})">${esc(x.player.name)}</span></div>`:''}</div>`).join('')}</div>`:''}</div>`:''}
   ${agentClientCount?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Portefeuille agent</div><h2>Joueurs représentés</h2></div><span class="badge">${agentClientCount} clients</span></div>
    ${agentClients.slice(0,20).map(x=>{const pl=x.player||{};return `<div class="list-item click" onclick="openPlayer(${pl.id})"><div class="row between"><div><b>${flags[pl.country]||'🏳️'} ${esc(pl.name||'Joueur')}</b><div class="muted micro">Depuis ${df(x.start_date)} · commission ${x.commission_pct}%</div></div><div style="text-align:right"><b>#${fmt(pl.game_world_rank||pl.ranking||0)}</b><div class="muted micro">confiance ${x.trust}/100</div></div></div></div>`}).join('')}
    ${agentClientCount>20?`<div class="muted mini" style="margin-top:7px">+${agentClientCount-20} autres clients dans le réseau.</div>`:''}
   </div>`:''}
   <div class="card" style="margin-top:10px"><div class="row between"><h2>Équipe actuelle</h2><span class="badge">${active.length}</span></div>${active.length?active.map(x=>`<div class="list-item"><div class="row between"><div>${playerLink(x)}<div class="muted mini">${esc(x.role)} · depuis ${df(x.start_date)}</div></div><div style="text-align:right"><b>${x.role_fit??'—'}/100</b><div class="muted micro">fit</div></div></div><div class="row between muted micro"><span>Affinité ${x.affinity??'—'}</span><span>Confiance ${x.trust??'—'}</span><span>Satisfaction ${x.satisfaction??'—'}</span><span>Cohésion ${x.team_chemistry??'—'}</span></div></div>`).join(''):'<div class="empty">Disponible sur le marché.</div>'}</div>
   ${playerBonds.length?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Relations FM</div><h2>Joueurs favoris & anciennes relations</h2></div><span class="badge">${playerBonds.length}</span></div>${playerBonds.slice(0,16).map(x=>{const pl=x.player||{};return `<div class="list-item click" onclick="openPlayer(${pl.id})"><div class="row between"><div><b>${flags[pl.country]||'🏳️'} ${esc(pl.name||'Joueur')}</b><div class="muted micro">${esc(x.bond_type)} · depuis ${df(x.formed_date)}</div></div><span class="badge ${x.bond_type==='Joueur favori'?'good':x.bond_type==='Relation difficile'?'bad':''}">${x.affinity}/100</span></div><div class="row between muted micro"><span>Confiance ${x.trust}</span><span>Respect ${x.respect}</span><span>${x.is_simulated?'Simulation Court Boss':'Sourcé'}</span></div></div>`}).join('')}</div>`:''}
   ${college.length||davis.length?`<div class="card" style="margin-top:10px"><h2>Fonctions institutionnelles</h2>${college.map(x=>`<div class="list-item row between"><span>NCAA · ${esc(x.team?.name||'Université')}</span><b>${esc(x.role)}</b></div>`).join('')}${davis.map(x=>`<div class="list-item row between"><span>Coupe Davis · ${esc(x.nation)}</span><b>${esc(x.role)}${x.part_time?' · temps partiel':''}</b></div>`).join('')}</div>`:''}
   ${training.length?`<div class="card" style="margin-top:10px"><h2>Formation continue</h2>${training.map(x=>`<div class="list-item"><div class="row between"><span>${esc(x.center?.name||'Institut')}</span><b>${x.progress??0}%</b></div><div class="muted micro">${esc(x.focus||'Formation')} · ${esc(x.status||'')}</div></div>`).join('')}</div>`:''}
   ${peers.length?`<div class="card" style="margin-top:10px"><h2>Réseau & relations staff</h2>${peers.slice(0,12).map(x=>`<div class="list-item"><div class="row between"><b class="click" onclick="openStaffProfile(${x.other?.id})">${esc(x.other?.name||'Staff')}</b><span class="badge ${Number(x.conflict_score||0)>=60?'bad':''}">${esc(x.relation_type)}</span></div><div class="row between muted micro"><span>Affinité ${x.affinity}</span><span>Confiance ${x.trust}</span><span>Rivalité ${x.rivalry}</span><span>Conflit ${x.conflict_score}</span></div></div>`).join('')}</div>`:''}
   ${(recs.from?.length||recs.to?.length)?`<div class="card" style="margin-top:10px"><h2>Recommandations professionnelles</h2>${(recs.from||[]).slice(0,6).map(x=>`<div class="list-item"><div class="row between"><span>Recommande <b class="click" onclick="openStaffProfile(${x.other?.id})">${esc(x.other?.name||'un collègue')}</b></span><b>${x.strength}/100</b></div>${x.other?.market_status==='available'?`<div class="row between" style="margin-top:5px"><span class="muted micro">${esc(x.other?.primary_role||'Staff')} · ${esc(x.other?.specialty||'')}</span><button class="soft-btn" onclick="approachStaffProfile(${x.other?.id})">Contacter</button></div>`:''}</div>`).join('')}${(recs.to||[]).slice(0,6).map(x=>`<div class="list-item row between"><span>Recommandé par <b class="click" onclick="openStaffProfile(${x.other?.id})">${esc(x.other?.name||'un collègue')}</b></span><b>${x.strength}/100</b></div>`).join('')}</div>`:''}
   ${hist.length?`<div class="card" style="margin-top:10px"><div class="row between"><h2>Historique carrière</h2><span class="badge">${hist.length}</span></div>${hist.slice(0,20).map(x=>`<div class="list-item"><div class="row between"><div>${playerLink(x)}<div class="muted mini">${esc(x.role)} · ${df(x.start_date)} → ${df(x.end_date)}</div></div><span class="badge">${esc(x.ended_reason||'Fin de collaboration')}</span></div></div>`).join('')}</div>`:''}
   ${events.length?`<div class="card" style="margin-top:10px"><h2>Événements de carrière</h2>${events.slice(0,20).map(x=>`<div class="list-item"><div class="row between"><b>${df(x.event_date)}</b><span class="badge">${esc(x.event_type)}</span></div><div class="muted mini">${esc(x.description||'')}</div></div>`).join('')}</div>`:''}
  </div></div>`;
 }catch(err){overlay.innerHTML=`<div class="modal"><div class="sheet"><div class="notice bad">${esc(err.message||'Erreur')}</div><button class="primary" onclick="closeOverlay()">Fermer</button></div></div>`}
}
window.matchStaffOffer=async id=>{
 if(!confirm("S'aligner sur l'offre concurrente ? Une prime de fidélité de 2 semaines sera payée."))return;
 try{
  const d=await managerAction('match_staff_offer',id);
  if(local.career)local.career.budget=d.budget;
  await refreshManagerState();render();
 }catch(e){alert(e.message)}
}
window.releaseStaffOffer=async id=>{
 if(!confirm("Laisser ce membre du staff rejoindre l'autre joueur ?"))return;
 try{await managerAction('release_staff_offer',id);await refreshManagerState();render()}catch(e){alert(e.message)}
}
window.mediateStaffConflict=async(aId,bId)=>{
 try{
  const d=await managerAction('mediate_staff_conflict',0,{staff_a_id:aId,staff_b_id:bId});
  await refreshManagerState();render();
  alert('Médiation réussie : conflit '+d.conflict_score+'/100.');
 }catch(e){alert(e.message)}
}
window.restStaff=async id=>{
 if(!confirm('Mettre ce membre du staff au repos pendant 2 semaines ? Son impact sportif sera fortement réduit pendant cette période.'))return;
 try{
  const d=await managerAction('rest_staff',id);
  await refreshManagerState();render();closeOverlay();
  alert('Repos programmé jusqu’au '+df(d.rest_until)+'.');
 }catch(e){alert(e.message)}
}
window.fireStaff=async id=>{
 if(!confirm('Se séparer de ce membre du staff ? Une indemnité de 4 semaines sera versée.'))return;
 try{
  const d=await managerAction('fire_staff',id);
  if(local.career)local.career.budget=d.budget;
  closeOverlay();
  await refreshManagerState();
  render();
 }catch(e){alert(e.message)}
}
window.openContract=id=>{
  const x=(management?.contracts||[]).find(v=>v.id===id);if(!x)return;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Contrat</div><h1>${esc(x.subject_name)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Rôle</span><b>${esc(x.role||x.subject_type)}</b></div><div class="list-item row between"><span>Salaire</span><b>${euro(x.weekly_salary)}/sem.</b></div><div class="list-item row between"><span>Échéance</span><b>${df(x.end_date)}</b></div><button class="primary" onclick="renewContract(${x.id});closeOverlay()">Proposer +1 an</button></div></div></div>`;
}
window.renewContract=async id=>{try{await managerAction('renew_contract',id);await loadManagement();render()}catch(e){alert(e.message)}}
window.acceptSponsor=async id=>{try{const d=await managerAction('accept_sponsor',id);if(local.career)local.career.budget=d.budget;await refreshManagerState();render()}catch(e){alert(e.message)}}
window.openInjury=id=>{
  const i=(boot.injuries||[]).find(x=>x.id===id);if(!i)return;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier médical</div><h1>${esc(i.injury_type)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Sévérité</span><b>${esc(i.severity)}</b></div><div class="list-item row between"><span>Retour estimé</span><b>${df(i.expected_return)}</b></div><div class="list-item row between"><span>Risque aggravation</span><b>${i.aggravation_risk}%</b></div><div class="list-item"><span class="muted mini">Traitement</span><p>${esc(i.treatment||'Repos et suivi médical')}</p></div></div></div></div>`;
}
window.setMedicalProtocol=async protocol=>{
  try{
    const d=await managerAction('set_medical_protocol',0,{protocol});
    boot=await get('/api/bootstrap');
    if(protocol==='Repos complet')local.training=['Repos','Repos','Récupération','Repos','Récupération','Repos','Repos'];
    else if(protocol==='Récupération active')local.training=['Récupération','Repos','Récupération','Repos','Récupération','Repos','Repos'];
    persist();render();
  }catch(e){alert(e.message)}
}
window.setRecovery=mode=>{
  const map={Repos:'Repos complet','Récupération':'Récupération active',mix:'Récupération active'};
  return setMedicalProtocol(map[mode]||'Récupération active');
}
window.applyRecovery=()=>setMedicalProtocol('Récupération active');
window.setTactic=(k,v)=>{local.tactics=local.tactics||{};local.tactics[k]=['aggression','risk','net'].includes(k)?Number(v):v;persist();render()}
window.simulatePracticeMatch=async()=>{
  const cr=career();let opp={name:'Adversaire ATP',current_ability:55,form:70,fatigue:20};
  try{const d=await get('/api/rankings?kind=singles&offset='+Math.max(0,(cr.singles_rank||742)-3)+'&limit=5');opp=d.rows.find(x=>x.name!==cr.player_name)||opp}catch{}
  const strength=(cr.current_ability||56)+(cr.form||72)*.18-(cr.fatigue||18)*.12+(local.tactics?.aggression||58)*.03;
  const other=(opp.current_ability||55)+(opp.form||70)*.18-(opp.fatigue||20)*.12;
  const win=strength>=other+(Math.random()*12-6);
  const score=win?(Math.random()>.5?'6-4 6-3':'7-6 3-6 6-2'):(Math.random()>.5?'4-6 3-6':'6-4 4-6 3-6');
  const md={premieres_balles:58+Math.floor(Math.random()*16)+'%',winners:18+Math.floor(Math.random()*20),fautes_directes:12+Math.floor(Math.random()*18),rallye_moyen:3+Math.floor(Math.random()*6)};
  local.practiceMatches=local.practiceMatches||[];local.practiceMatches.unshift({tournament_name:'Match entraînement',round:'Simulation',player_a:cr.player_name||'Anthony',player_b:opp.name,winner:win?(cr.player_name||'Anthony'):opp.name,score,surface:'Dur',match_date:local.date,match_data:md});
  cr.fatigue=clamp((cr.fatigue||18)+10,0,100);cr.form=clamp((cr.form||72)+(win?2:-1),0,100);local.career=cr;persist();render();
}
window.openMatch=idx=>{
  const all=[...(local.practiceMatches||[]),...(boot.matches||[])],m=all[idx];if(!m)return;
  const d=m.match_data||{};
  const firstServe=d.first_serve_pct??d.premieres_balles??'—';
  const winners=d.winners??'—';
  const errors=d.unforced_errors??d.fautes_directes??'—';
  const net=d.net_points_won_pct??'—';
  const rally=d.avg_rally??d.rallye_moyen??'—';
  const bp=d.break_points_won??'—';
  const plan=d.tactical_plan||local.tactics||{};
  const result=m.winner===(career().player_name||'Anthony')||m.winner===(career().player_name||'Joueur');
  const efficiency=(()=>{
    const w=Number(winners)||0,e=Number(errors)||0,n=Number(net)||50,r=Number(rally)||5;
    return clamp(Math.round(50+(w-e)*1.2+(n-50)*.25-(r>8?3:0)),20,95);
  })();
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet">
    <div class="sheet-head"><div><div class="eyebrow">${esc(m.tournament_name||'Match')}</div><h1>${esc(m.player_a)} vs ${esc(m.player_b)}</h1><div class="muted">${df(m.match_date||local.date)} · ${esc(m.surface||'Dur')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
    <div class="score-hero" style="margin-top:12px">${esc(m.score||'—')}</div><div class="row" style="justify-content:center;margin-top:7px"><span class="badge ${result?'good':'bad'}">${result?'Victoire':'Défaite'}</span></div>
    <div class="kpi-strip" style="margin-top:14px">
      <div class="kpi"><span class="muted mini">1res balles</span><b>${typeof firstServe==='number'?firstServe+'%':esc(firstServe)}</b></div>
      <div class="kpi"><span class="muted mini">Winners</span><b>${winners}</b></div>
      <div class="kpi"><span class="muted mini">Fautes directes</span><b>${errors}</b></div>
      <div class="kpi"><span class="muted mini">Filet gagné</span><b>${net==='—'?'—':net+'%'}</b></div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Lecture du match</h2>
        <div class="list-item row between"><span>Longueur moyenne des échanges</span><b>${rally} coups</b></div>
        <div class="list-item row between"><span>Break points gagnés</span><b>${bp}</b></div>
        <div class="list-item row between"><span>Efficacité globale</span><b>${efficiency}/100</b></div>
        <div class="bar"><i style="width:${efficiency}%"></i></div>
      </div>
      <div class="card"><h2>Plan tactique utilisé</h2>
        <div class="list-item row between"><span>Agressivité</span><b>${plan.aggression??'—'}${plan.aggression!=null?'%':''}</b></div>
        <div class="list-item row between"><span>Prise de risque</span><b>${plan.risk??'—'}${plan.risk!=null?'%':''}</b></div>
        <div class="list-item row between"><span>Montées au filet</span><b>${plan.net??'—'}${plan.net!=null?'%':''}</b></div>
        <div class="list-item row between"><span>Position au retour</span><b>${esc(plan.return_position??plan.returnPos??'Neutre')}</b></div>
      </div>
    </div>
    <div class="card" style="margin-top:12px"><h2>Recommandation coach</h2><p class="muted">${errors!=='—'&&Number(errors)>Number(winners)?'Réduire légèrement la prise de risque sur le prochain match.':net!=='—'&&Number(net)>65?'Le jeu vers l’avant a été efficace. Conserver les montées au filet sur surface rapide.':rally!=='—'&&Number(rally)>7?'Les échanges sont longs : surveiller la fatigue et privilégier les schémas service + 1.':'Plan de jeu équilibré. Ajuster surtout selon le prochain adversaire.'}</p></div>
  </div></div>`;
}
window.pairScore=(p,k)=>{
 const rows=management?.partnerships||[];
 const rel=rows.find(x=>
   Number(x.player_b_id)===Number(p?.id)||
   Number(x.player_a_id)===Number(p?.id)
 );
 if(rel){
   if(k==='chem')return Number(rel.chemistry||60);
   if(k==='comp')return Number(rel.compatibility||60);
   return Number(rel.pair_strength||60);
 }
 const cr=career();
 const rankFit=Math.max(0,18-Math.min(18,Math.abs(Number(p?.doubles_ranking||1500)-Number(cr.doubles_rank||1500))/100));
 const nation=String(p?.country||'')===String(cr.country||'')?6:0;
 const level=Math.max(0,Math.min(18,(Number(p?.current_ability||55)-45)*.9));
 const base=54+rankFit+nation+level;
 return clamp(Math.round(k==='power'?base+3:k==='comp'?base:base-2),40,94)
}
window.approachPartner=async id=>{
 if(String(career().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : les partenariats double sont désactivés.');return}
 try{
  const d=await managerAction('approach_partner',id);
  if(d.accepted){
   local.partnerId=id;persist();
   alert('Proposition acceptée. Cette paire devient ton partenariat principal.');
  }else{
   alert('Proposition refusée : '+(d.reason||'le joueur ne souhaite pas changer de projet actuellement.'));
  }
  await loadManagement();render();
 }catch(e){alert(e.message)}
}
window.respondPartnerOffer=async(id,decision)=>{
 if(String(career().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : les propositions de double sont désactivées.');return}
 try{
  const d=await managerAction('respond_partner_offer',id,{decision});
  if(decision==='accept'&&d.partnership?.partner_id){
   local.partnerId=Number(d.partnership.partner_id);persist();
  }
  await loadManagement();render();
 }catch(e){alert(e.message)}
}
window.choosePartner=async id=>{if(String(career().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : change d’orientation avant de former une paire.');return}try{await managerAction('choose_partner',id);local.partnerId=id;persist();await loadManagement();render()}catch(e){alert(e.message)}}
window.setDavisRole=async(id,role)=>{local.davisRoles=local.davisRoles||{};for(const [pid,r] of Object.entries(local.davisRoles)){if(r===role&&role!=='Réserve')delete local.davisRoles[pid]}local.davisRoles[id]=role;persist();try{await managerAction('davis_role',id,{role});boot=await get('/api/bootstrap')}catch(e){alert(e.message)}render()}
window.setCareerFocus=async focus=>{
 const labels={singles_only:'Simple exclusivement',singles_priority:'Simple prioritaire',mixed:'Simple + double',doubles_only:'Double exclusivement'};
 const cr=career();
 if(String(cr.career_focus||'mixed')===focus)return;
 const warning=focus==='doubles_only'
  ?'Passer en Double exclusivement ? Tes inscriptions simple futures seront retirées et tu ne pourras plus jouer de tableau simple tant que ce mode reste actif.'
  :focus==='singles_only'
    ?'Passer en Simple exclusivement ? Ta paire active sera rompue et tu ne pourras plus jouer de tableau double tant que ce mode reste actif.'
    :'Passer en '+labels[focus]+' ?';
 if(!confirm(warning))return;
 try{
  const d=await managerAction('set_career_focus',0,{focus});
  if(focus==='doubles_only'){
    local.entries=[];
    local.entryMeta={};
    local.training=['Double','Service','Retour','Double','Match play','Récupération','Repos'];
    tmCalFilters.entry='Double';
    rankKind='doubles';
  }else if(focus==='singles_only'){
    local.partnerId=null;
    local.doublesEntries=[];
    local.doublesEntryMeta={};
    local.training=['Service','Retour','Coup droit','Revers','Match play','Déplacements','Récupération'];
    tmCalFilters.entry='Simple';
    rankKind='singles';
  }else if(['doubles_only','singles_only'].includes(String(cr.career_focus||'mixed'))){
    tmCalFilters.entry='Tous';
  }
  boot=await get('/api/bootstrap');
  if(boot.career)local.career={...(local.career||{}),...boot.career};
  await Promise.all([loadScheduleAdvice(),loadTournaments(),loadManagement()]);
  persist();render();
  if(focus==='doubles_only'&&d.needs_partner){
    alert('Orientation active : '+(d.label||labels[focus])+'. Il te faut maintenant un partenaire.');
    nav('doubles');
    return;
  }
  alert('Orientation active : '+(d.label||labels[focus])+'.');
 }catch(e){alert(e.message)}
}
window.editCareer=async(k,v)=>{const cr=career();cr[k]=v;local.career=cr;persist();render();try{await managerAction('edit_career',0,{field:k,value:v});boot=await get('/api/bootstrap');if(boot.career)local.career={...local.career,...boot.career};persist();render()}catch(e){alert(e.message)}}
window.createFantasy=()=>{const name=prompt('Nom du tournoi ?','Court Boss Invitational');if(!name)return;const surface=prompt('Surface ? Dur / Terre / Gazon','Dur')||'Dur';const draw=Number(prompt('Taille du tableau ?','32'))||32;local.fantasy=local.fantasy||[];local.fantasy.push({name,surface,draw,category:'Fantasy'});persist();render()}
window.deleteFantasy=i=>{local.fantasy.splice(i,1);persist();render()}
window.openFantasy=i=>{const t=local.fantasy[i];if(!t)return;overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Fantasy Court</div><h1>${esc(t.name)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw} joueurs</b></div></div></div></div>`}
window.facilityLevel=f=>local.facilityLevels?.[f.id]??f.level
window.upgradeFacility=async(id,name,base)=>{try{const d=await managerAction('upgrade_facility',id);boot=await get('/api/bootstrap');if(boot.career)local.career={...local.career,...boot.career};local.facilityLevels=local.facilityLevels||{};local.facilityLevels[id]=d.level;persist();render()}catch(e){alert(e.message)}}
window.openInboxItem=async(id,r)=>{try{await managerAction('mark_inbox_read',id);boot=await get('/api/bootstrap')}catch{}await nav(r)}
window.simulateWeek=async()=>{
 if(simulating)return;
 if(local.liveSessionId){alert('Termine le match en cours avant de passer à la semaine suivante.');nav('match');return;}
 simulating=true;render();
 try{
  const cr=career(),load=trainingLoad();
  cr.fatigue=clamp((cr.fatigue||18)+Math.max(0,load-5)-Math.floor(Math.random()*6),0,100);
  cr.fitness=clamp((cr.fitness||91)+(load<=10?1:-3),40,100);
  cr.form=clamp((cr.form||72)+Math.floor(Math.random()*7)-2,35,100);
  cr.morale=clamp((cr.morale||78)+Math.floor(Math.random()*5)-1,35,100);
  if(load>13&&Math.random()>.72){cr.injury_status='Gêne musculaire';cr.fitness=clamp(cr.fitness-9,0,100);local.feed=local.feed||[];local.feed.unshift('Alerte médicale : la charge élevée a provoqué une gêne musculaire.')}
  else if(cr.injury_status&&cr.injury_status!=='Fit'&&Math.random()>.45)cr.injury_status='Fit';
  const d=new Date((local.date||RANKING_SNAPSHOT)+'T12:00:00');d.setDate(d.getDate()+7);
  const nextDate=d.toISOString().slice(0,10),nextWeek=(local.week||1)+1;
  const currentYear=Number(String(local.date||RANKING_SNAPSHOT).slice(0,4)),nextYear=Number(nextDate.slice(0,4));
  if(nextYear>currentYear){
    const roll=await get('/api/rollover-season',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({new_year:nextYear})});
    local.date=String(nextYear)+'-01-05';local.week=1;if(nextYear>Number(String(RANKING_SNAPSHOT).slice(0,4)))tourFilters.source='Tous';
    if(roll.userRanking){cr.singles_rank=roll.userRanking.rank;cr.points=roll.userRanking.points}
    if(roll.userDoublesRanking){cr.doubles_rank=roll.userDoublesRanking.rank;cr.doubles_points=roll.userDoublesRanking.points}
    local.feed=local.feed||[];
    const ng=roll.rollover?.newgens||{};
    local.feed.unshift(`Nouvelle saison ${nextYear} : ${roll.rollover?.retired_players||0} retraite(s), ${ng.created||0} jeunes générés, ${ng.promoted||0} promu(s) vers le circuit pro.`);
    local.career=cr;persist();
    boot=await get('/api/bootstrap');
    if(boot.career){local.career={...cr,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??1;}
    await Promise.all([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries()]);
    if(route==='history')await loadHistory();
    return;
  }
  const sim=await get('/api/simulate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({week:nextWeek,date:nextDate,career_state:{form:cr.form,fitness:cr.fitness,morale:cr.morale,fatigue:cr.fatigue,injury_status:cr.injury_status},training:local.training})});
  local.date=sim.date||nextDate;local.week=sim.week||nextWeek;local.career=cr;local.scoutingBoost=Math.min(50,(local.scoutingBoost||0)+4);
  if(sim.userRanking){cr.singles_rank=sim.userRanking.rank;cr.points=sim.userRanking.points}
  if(sim.userDoublesRanking){cr.doubles_rank=sim.userDoublesRanking.rank;cr.doubles_points=sim.userDoublesRanking.points}
  if(sim.training?.current_ability)cr.current_ability=sim.training.current_ability;
  if(sim.training?.improvements?.length){
    const labels={serve_power:'Puissance service',serve_precision:'Précision service',forehand:'Coup droit',backhand:'Revers',return_game:'Retour',volley:'Volée',touch:'Toucher',movement:'Déplacements',speed:'Vitesse',stamina:'Endurance',strength:'Force',anticipation:'Anticipation',concentration:'Concentration',composure:'Sang-froid',fighting_spirit:'Combativité',tactics:'Tactique',doubles:'Double'};
    local.feed=local.feed||[];
    local.feed.unshift('Progression entraînement : '+sim.training.improvements.map(x=>(labels[x.attribute]||x.attribute)+' '+x.from+'→'+x.to).join(', '));
  }
  local.feed=local.feed||[];if(sim.medical){local.feed.unshift(sim.medical.recovered?'Centre médical : retour à 100%, le joueur est déclaré apte.':`Centre médical : ${sim.medical.protocol}, risque ${sim.medical.risk_delta>=0?'+':''}${sim.medical.risk_delta}, retour gagné ${sim.medical.return_days_gained||0} jour(s).`)}if(sim.weeklyFinance)local.feed.unshift(`Finances semaine : sponsors +${euro(sim.weeklyFinance.sponsors||0)}, staff -${euro(sim.weeklyFinance.staff||0)}, joueurs -${euro(sim.weeklyFinance.players||0)}, médical -${euro(sim.weeklyFinance.medical||0)} · net ${sim.weeklyFinance.net>=0?'+':''}${euro(sim.weeklyFinance.net||0)}.`);if((sim.weeklyFinance?.expired_contracts||0)>0)local.feed.unshift(`${sim.weeklyFinance.expired_contracts} contrat(s) joueur arrivé(s) à échéance.`);if((sim.academyDevelopment?.ability_progressions||0)>0)local.feed.unshift(`Académie : ${sim.academyDevelopment.ability_progressions} jeune(s) ont progressé en niveau global, ${sim.academyDevelopment.attribute_improvements||0} attribut(s) amélioré(s).`);if((sim.injuries?.new_injuries||0)>0)local.feed.unshift(`${sim.injuries.new_injuries} nouvelle(s) blessure(s) dans le monde cette semaine.`);if((sim.forfeits?.forfeits||0)>0)local.feed.unshift(`${sim.forfeits.forfeits} place(s) libérée(s) par forfait sur les tournois à venir.`);if((sim.worldDoublesTournaments?.tournaments_simulated||0)>0)local.feed.unshift(`Circuit double mondial : ${sim.worldDoublesTournaments.tournaments_simulated} tournoi(s) simulé(s), avec palmarès et points de paire mis à jour.`);local.feed.unshift(`Semaine simulée : ${cr.player_name||'Joueur'} est ${String(cr.career_focus||'mixed')==='doubles_only'?'Double #'+cr.doubles_rank:'ATP #'+cr.singles_rank} · Monde mis à jour : ${sim.world?.updated_players||0} joueurs.`);local.feed=local.feed.slice(0,8);
  local.career=cr;persist();
  boot=await get('/api/bootstrap');
  if(boot.career){local.career={...cr,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week;}
  await Promise.all([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries()]);
  if(route==='history')await loadHistory();
 }catch(e){try{boot=await get('/api/bootstrap');if(boot.career){local.career={...local.career,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week;localStorage.setItem('cbLocal',JSON.stringify(local));}}catch{}alert('Simulation incomplète : '+e.message)}
 finally{simulating=false;render()}
}
window.openGlobalSearch=()=>{
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Base mondiale · ${fmt(worldStats?.searchableRealPlayers||20000)} joueurs réels · classement mondial #1–#30000 + base profonde</div><h1>Recherche joueurs</h1></div><button class="close" onclick="closeOverlay()">✕</button></div>
 <input id="globalSearchInput" class="input" style="margin-top:12px" placeholder="Nom du joueur…" oninput="runGlobalSearch(this.value)" autofocus>
 <div class="filters" style="margin-top:8px">
  <select id="globalSearchCountry" class="select" onchange="runGlobalSearch(document.getElementById('globalSearchInput').value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}">${flags[x.country]||'🏳️'} ${esc(x.country)}</option>`).join('')}</select>
  <select id="globalSearchCircuit" class="select" onchange="runGlobalSearch(document.getElementById('globalSearchInput').value)">
   <option>Tous</option><option>Tous réels</option><option>ATP classés</option><option>ATP profond</option><option>Double</option><option>Junior Double</option><option>Race</option><option>Next Gen</option><option>ITF</option><option>Junior</option><option>NCAA</option>
  </select>
  <select id="globalSearchAge" class="select" onchange="runGlobalSearch(document.getElementById('globalSearchInput').value)">
   <option value="99">Tous âges</option><option value="18">U18</option><option value="21">U21</option><option value="23">U23</option><option value="30">30 ans max</option>
  </select>
 </div>
 <div id="globalSearchResults" class="stack" style="margin-top:12px"><div class="empty">Tape au moins 2 caractères, ou choisis une nationalité/circuit.</div></div></div></div>`;
 setTimeout(()=>document.getElementById('globalSearchInput')?.focus(),20);
}
window.runGlobalSearch=async q=>{
 const box=document.getElementById('globalSearchResults');if(!box)return;
 const country=document.getElementById('globalSearchCountry')?.value||'';
 const circuit=document.getElementById('globalSearchCircuit')?.value||'Tous';
 const age=document.getElementById('globalSearchAge')?.value||'99';
 if(q.trim().length<2&&!country&&circuit==='Tous'&&age==='99'){box.innerHTML='<div class="empty">Tape au moins 2 caractères, ou utilise un filtre.</div>';return}
 try{
  const p=new URLSearchParams({offset:'0',limit:'60',q:q.trim(),country,circuit,age_max:age});
  const d=await get('/api/search-players?'+p.toString());
  box.innerHTML=`<div class="row between"><span class="muted mini">${fmt(d.count||0)} résultat(s)</span><span class="badge">${esc(circuit==='Tous'?'Base mondiale':circuit)}</span></div>`+
  (d.rows.map(p=>{
   const tags=[];
   if(p.ranking)tags.push('ATP #'+fmt(p.ranking));
   if(p.doubles_ranking)tags.push('Double #'+fmt(p.doubles_ranking));
   if(p.junior_doubles_ranking)tags.push('Junior Double #'+fmt(p.junior_doubles_ranking));
   if(p.itf_ranking)tags.push('ITF #'+fmt(p.itf_ranking));
   if(p.ncaa_current)tags.push('NCAA'+(p.ncaa_rank?' #'+fmt(p.ncaa_rank):'')+(p.ncaa_school?' · '+p.ncaa_school:''));
   if(p.junior_ranking&&p.birth_date&&String(p.birth_date)>='2007-01-01')tags.push('Junior #'+fmt(p.junior_ranking));
   const ageText=ageLabel(p,true);
   const bh=p.backhand?(p.backhand+(p.backhand_verified?'':' (estimé)')):'revers N/V';
   return `<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><div><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${esc(ageText)} · ${esc(bh)} · ${esc(tags.join(' · ')||'Joueur réel')}</div></div><span class="badge">Profil</span></div></div>`;
  }).join('')||'<div class="empty">Aucun joueur trouvé.</div>');
 }catch(e){box.innerHTML=`<div class="empty">${esc(e.message)}</div>`}
}

init();