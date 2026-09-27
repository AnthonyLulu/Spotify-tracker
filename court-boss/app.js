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
const fmt=n=>new Intl.NumberFormat('fr-FR').format(Math.round(Number(n)||0));
const euro=n=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(Number(n)||0);
const df=s=>s?new Date(s+'T12:00:00').toLocaleDateString('fr-FR',{day:'2-digit',month:'short',year:'numeric'}):'—';
const RANKING_SNAPSHOT='2025-12-01';
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const get=async(path,opts={})=>{const r=await fetch(API+path,{...opts,headers:{'X-Save-Key':saveKey,...(opts.headers||{})}});const body=await r.json().catch(()=>({error:'Réponse serveur illisible'}));if(!r.ok)throw new Error(body.error||'Erreur serveur '+r.status);return body;};
let boot=null,route='home',rankKind='singles',rankOffset=0,rankRows=[],rankCount=0,rankMeta={},rankQuery='',rankCountry='',nextGenAge=21,countryRows=[],historyData=null,historyCountry='',historyContinent='',tourOffset=0,tourRows=[],tourTbc=[],tourCount=0,tourFilters={circuit:'Tous',category:'Toutes',surface:'Toutes',source:'Officiel',month:'',q:''},tourShowPast=false,management=null,worldStats=null,rankingLedger=null,seasonSummary=null,scheduleAdvice=null,simulating=false;
let doublesHubRows=[],juniorDoublesHubRows=[],doublesRaceRows=[],doublesHubLoading=false;
let ncaaView='singles',ncaaDoublesRows=[],ncaaDoublesMeta={};
let liveAutoTimer=null,liveAutoBusy=false,liveAutoSpeed=1;
let dbRows=[],dbCount=0,dbOffset=0,dbQuery='',dbCountry='',dbCircuit='Tous réels',dbLoaded=false,dbLoading=false;
let local={date:'2026-09-27',week:1,training:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'],entries:[],shortlist:[],career:null,feed:[],scoutingBoost:0,partnerId:null,davisRoles:{},fantasy:[],tactics:{aggression:58,risk:52,net:28,returnPos:'Neutre'}};
try{Object.assign(local,JSON.parse(localStorage.getItem('cbLocal')||'{}'))}catch{}
function persist(){localStorage.setItem('cbLocal',JSON.stringify(local));fetch(API+'/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Save-Key':saveKey},body:JSON.stringify(local)}).catch(()=>{})}
function surfaceClass(s){const v=String(s||'');return v==='Terre'?'surface-clay':v==='Gazon'?'surface-grass':/intérieur/i.test(v)?'surface-indoor':'surface-hard'}
function surfaceLabel(t){
 if(typeof t==='string')return t;
 const base=String(t?.surface||'Dur');
 return base==='Dur'?((t?.indoor===true||String(t?.environment||'Outdoor')==='Indoor')?'Dur intérieur':'Dur extérieur'):base;
}
function circuitClass(c){return c==='Challenger'?'tag-challenger':c==='ITF'?'tag-itf':c==='NCAA'?'tag-ncaa':c==='Junior'?'tag-junior':c==='Federation'?'tag-fed':'tag-atp'}
function rankValue(p,k){return k==='doubles'?p.doubles_ranking:k==='junior_doubles'?p.junior_doubles_ranking:k==='race'?p.race_ranking:k==='nextgen'?p.nextgen_ranking:k==='itf'?p.itf_ranking:k==='junior'?p.junior_ranking:k==='ncaa'?p.ncaa_rank:(p.official_ranking??(p.ranking_current?p.ranking:null)??p.game_world_rank??p.world_rank??p.ranking)}
function rankCell(p,k){
 const v=rankValue(p,k);
 return v==null?'<span class="muted">NR</span>':'#'+fmt(v);
}
function rankPoints(p,k){return k==='doubles'?p.doubles_points:k==='junior_doubles'?p.junior_doubles_points:k==='race'?p.race_points:k==='nextgen'?p.nextgen_points:k==='junior'?p.junior_points:k==='ncaa'?null:p.points}
function rankSnapshot(p,k){
 return k==='doubles'?p.doubles_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_doubles'?p.junior_doubles_snapshot_date||RANKING_SNAPSHOT:
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
function rankAge(p,k){return displayAge(p,RANKING_SNAPSHOT)??'—'}
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
 const c=career(),fin=boot?.finance||{};
 return `<div class="manager-strip">
  <div class="manager-cell"><span>Semaine</span><b>${local.week||1}</b></div>
  <div class="manager-cell"><span>ATP</span><b>#${fmt(c.singles_rank||0)}</b></div>
  <div class="manager-cell"><span>Budget</span><b>${euro(c.budget??fin.balance??0)}</b></div>
  <div class="manager-cell wide"><span>Date carrière</span><b>${df(local.date||c.career_date)}</b></div>
  <button class="manager-world" onclick="nav('world')">Monde ▸</button>
 </div>`
}
function shell(body){app.innerHTML=`<div class="app-shell">${header()}${managerStrip()}<main class="page">${body}</main>${navBar()}</div>`}
function loading(t='Chargement du monde tennis…'){shell(`<div class="loader">${t}</div>`)}
window.nav=async r=>{route=r;window.scrollTo({top:0,behavior:'smooth'});if(r==='history'&&!historyData)await loadHistory();await render()}
async function init(){
 loading();
 try{
   boot=await get('/api/bootstrap');
   if(boot.save&&typeof boot.save==='object') Object.assign(local,boot.save);
   local.career={...(local.career||{}),...(boot.career||{})};
   local.date=boot.career?.career_date||local.date||'2026-09-27';
   local.week=boot.career?.week??local.week??1;
   localStorage.setItem('cbLocal',JSON.stringify(local));
   const [_,__,___,____,_____,______,_______,world]=await Promise.all([
     loadManagement(),loadRankings(),loadTournaments(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),get('/api/world').catch(()=>null)
   ]);
   worldStats=world;
   render();
 }catch(e){shell(`<div class="card"><h2>Connexion au monde impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="location.reload()">Réessayer</button></div>`)}
}
async function loadManagement(){try{management=await get('/api/management')}catch{management={contracts:[],college:[],shortlist:[]}}}
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
 const p=new URLSearchParams({limit:'80'});
 if(historyCountry)p.set('country',historyCountry);
 if(historyContinent)p.set('continent',historyContinent);
 try{historyData=await get('/api/history-hub?'+p.toString())}catch(e){historyData={rows:[],countryBest:[],continentBest:[],methodology:e.message,coverage:{players:0,countries:0}}}
}
async function loadTournaments(){
 const p=new URLSearchParams({offset:String(tourOffset),limit:'60'});
 if(!tourFilters.month&&!tourShowPast)p.set('from',local.date||'2026-09-27');
 Object.entries(tourFilters).forEach(([k,v])=>{if(v&&v!=='Tous'&&v!=='Toutes')p.set(k,v)});
 const d=await get('/api/tournaments?'+p.toString());tourRows=d.rows;tourTbc=d.tbc||[];tourCount=d.count;
}
async function loadRankingLedger(){try{rankingLedger=await get('/api/ranking-ledger?date='+(local.date||'2026-09-27'))}catch(e){rankingLedger={total:((local.career&&local.career.points)||34),active:[],expired:[]}}}
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
  doublesRaceRows=t.rows||[];
 }catch(e){console.warn('Double hub',e)}
 finally{doublesHubLoading=false;if(route==='doubles')render()}
}

function career(){
 const c={...(boot?.career||{}),...(local.career||{})};
 c.singles_rank=c.singles_rank??742;c.doubles_rank=c.doubles_rank??1284;c.points=c.points??34;c.player_name=c.player_name||'Anthony';c.country=c.country||'FRA';
 return c;
}
function home(){
 const c=career(),next=boot.upcoming?.[0],academy=boot.academy||{},fin=boot.finance||{};
 const msgs=[...(local.feed||[]),...(boot.news||[]).map(x=>x.body)].slice(0,6);
 return `<div class="section-head"><div><div class="eyebrow">Carrière · semaine ${local.week}</div><h1>Centre de management</h1><div class="muted">Le monde avance même quand tu ne joues pas.</div></div><span class="pill">ATP · classement réf. ${df(RANKING_SNAPSHOT)}</span></div>
 <section class="hero">
  <div class="card click" onclick="nav('myplayer')">
   <div class="row between"><div><div class="eyebrow">Joueur géré</div><div class="hero-name">${flags[c.country]||'🏳️'} ${esc(c.player_name)}</div><div class="muted">ATP #${fmt(c.singles_rank)} · Double #${fmt(c.doubles_rank)} · ${fmt(c.points)} pts</div></div><div class="progress-ring" style="--p:${c.form||72}"><b>${c.form||72}</b></div></div>
   <div class="kpi-strip" style="margin-top:14px">
    ${[['Forme',c.form||72],['Fitness',c.fitness||91],['Moral',c.morale||78],['Fatigue',c.fatigue||18]].map(x=>`<div class="kpi"><span class="muted mini">${x[0]}</span><b>${x[1]}</b><div class="bar"><i style="width:${x[1]}%"></i></div></div>`).join('')}
   </div>
  </div>
  <div class="card click" onclick="nav('finance')"><div class="eyebrow">Académie</div><h2>${esc(academy.name||'Court Boss Academy')}</h2><div class="statline"><div class="statbox"><span class="muted mini">Budget</span><b>${euro(c.budget??academy.budget??14800)}</b></div><div class="statbox"><span class="muted mini">Board</span><b>${academy.board_confidence||76}%</b></div></div><p class="muted mini" style="margin-top:10px">${esc(academy.philosophy||'Développement complet du joueur')}</p></div>
 </section>
 <div class="quick-grid" style="margin-top:12px">
  ${[['calendar','Calendrier','Inscrire le joueur'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Chercher des talents'],['match','Match Center','Analyser les matchs'],['tactics','Tactique','Plan de match'],['contracts','Contrats','Staff & joueurs'],['medical','Médical','Fatigue & blessures'],['davis','Fédération','Coupe Davis'],['world','Monde','Base mondiale & circuits'],['season','Saison','Bilan & points 52 semaines']].map(x=>`<div class="quick" onclick="nav('${x[0]}')"><span class="muted mini">${x[1]}</span><strong>${x[2]}</strong></div>`).join('')}
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
 const kinds=[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['junior_doubles','Junior Double'],['itf','ITF WTT'],['ncaa','NCAA / ITA']];
 if(rankKind==='ncaa')return ncaaRanking();
 const startRow=rankCount?rankOffset+1:0,endRow=Math.min(rankOffset+rankRows.length,rankCount);
 const first=rankRows[0]||{},snap=rankSnapshot(first,rankKind);
 const label=rankKind==='singles'?'ATP Ranking':rankKind==='doubles'?'ATP Doubles':rankKind==='junior_doubles'?'Court Boss Junior Doubles':rankKind==='race'?'ATP Race':rankKind==='nextgen'?'Next Gen Race U21':rankKind==='junior'?'ITF Juniors':'ITF World Tennis Tour';
 const reference=rankKind==='singles'
   ?'Classement monde Court Boss jusqu’au rang 30 000. Le rang ATP officiel reste identifié séparément quand il est disponible · snapshot '+df(snap||RANKING_SNAPSHOT)+'.'
   :rankKind==='doubles'
     ?'Classement ATP Double officiel Live-Tennis · Top 1000 au '+df(snap||RANKING_SNAPSHOT)+' · '+fmt(worldStats?.indexedDoubles||rankCount)+' profils indexés pour le scouting.'
     :rankKind==='race'
       ?'ATP Race Live-Tennis 2026 · '+df(snap||RANKING_SNAPSHOT)
       :rankKind==='nextgen'
         ?'ATP Next Gen Race 2026 · '+df(snap||RANKING_SNAPSHOT)+' · âge au 01/12/2025'
       :rankKind==='junior'
         ?'ITF Juniors · snapshot '+df(snap||RANKING_SNAPSHOT)
       :rankKind==='junior_doubles'
         ?'Court Boss Junior Double · classement simulé séparé · snapshot '+df(snap||RANKING_SNAPSHOT)
         :'ITF World Tennis Tour · snapshot '+df(snap||RANKING_SNAPSHOT);
 const pill=rankKind==='ncaa'?(snap?df(snap):'NCAA'):df(snap||RANKING_SNAPSHOT);
 return `<div class="section-head"><div><div class="eyebrow">Base mondiale</div><h1>Classements</h1><div class="muted">Ranking, Race, Double et Next Gen sont séparés. Le classement ATP de départ correspond au snapshot officiel du 1er décembre 2025, puis la simulation de ta carrière fait évoluer ce monde.</div></div><span class="pill">${pill}</span></div>
 <div class="tabs rank-tabs">${kinds.map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}<button class="deep-db-tab" onclick="dbCircuit='Tous réels';dbOffset=0;dbLoaded=false;nav('players')">Monde ${fmt(worldStats?.worldRankingCapacity||30000)}</button></div>
 ${rankKind==='nextgen'? `<div class="age-filter"><span class="muted mini">Âge au 01/12/2025</span>${[18,19,20,21].map(a=>`<button class="${nextGenAge===a?'active':''}" onclick="setNextGenAge(${a})">U${a}</button>`).join('')}</div>`:''}
 ${rankKind==='junior'? `<div class="notice mini" style="margin-bottom:12px"><b>Vivier junior Court Boss</b> · <b>classement de jeu continu #1 à #2000</b> · ${fmt(rankMeta?.officialRealCount||0)} vrais vérifiés + ${fmt(rankMeta?.generatedCount||0)} newgens. Le rang ITF officiel reste conservé séparément quand il existe. À 18 ans, les newgens basculent vers NCAA ou ITF/pro.</div>`:''} ${rankKind==='junior_doubles'? `<div class="notice mini" style="margin-bottom:12px"><b>Circuit Junior Double</b> · classement séparé #1 à #2000, basé sur aptitude double, volée, retour, service et niveau global. Les 87 tournois juniors actifs proposent désormais le double.</div>`:''} ${rankKind==='singles'? `<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Classement carrière simulé</div><div class="hero-name" style="font-size:25px">ATP #${career().singles_rank}</div><div class="muted">${fmt(career().points)} points actifs · base initiale ${df(RANKING_SNAPSHOT)}</div></div><div style="text-align:right"><div class="muted mini">Prochaine expiration</div><b>${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?df(rankingLedger.active[0].expiry_date):'—'}</b><div class="muted mini">${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?'-'+rankingLedger.active[0].points+' pts':''}</div></div></div></div>`:''}
 <div class="card">
  <div class="rank-tools fm-rank-tools"><input class="input" value="${esc(rankQuery)}" placeholder="Rechercher dans les 30 000 joueurs…" onkeydown="if(event.key==='Enter')searchRanking(this.value)"><select class="select" onchange="setRankCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${rankCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select><div class="rank-jump"><input class="input" id="rankJump" type="number" min="1" max="${Math.max(rankCount,1)}" placeholder="Aller au rang"><button class="soft-btn" onclick="jumpRanking()">Aller</button></div></div>
  <div class="notice mini" style="margin-top:10px"><b>${label}</b> · ${reference}. Les valeurs de simulation restent séparées des snapshots historiques.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>${rankKind==='singles'?'# ATP / Monde':'#'}</th>${rankKind==='singles'?'<th>Best 2025</th><th>+/−</th>':''}<th>Joueur</th><th>Âge 01/12/25</th><th>Pays</th><th>Pts</th><th>${rankKind==='nextgen'?'ATP':'Niv.'}</th><th>${rankKind==='nextgen'?'Statut':'Pot.'}</th></tr></thead><tbody>
  ${rankRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${rankCell(p,rankKind)}</td>${rankKind==='singles'?`<td>${p.best_rank_2025?'#'+fmt(p.best_rank_2025):'—'}</td><td>${p.ranking_change==null?'<span class="muted">—</span>':p.ranking_change>0?'<span class="rank-up">▲ '+p.ranking_change+'</span>':p.ranking_change<0?'<span class="rank-down">▼ '+Math.abs(p.ranking_change)+'</span>':'<span class="muted">=</span>'}</td>`:''}<td><b>${esc(p.name)}</b> ${p.game_generated?'<span class="badge">Newgen</span>':''}${rankKind==='junior'&&p.junior_rank_type==='official'?'<span class="badge good">ITF vérifié</span>':rankKind==='junior'&&p.junior_rank_type==='verified_nr'?'<span class="badge">ITF · NR</span>':''}${p.ncaa_current?'<span class="badge tag-ncaa">NCAA</span>':p.ncaa_status==='Alumni'?'<span class="badge tag-ncaa">NCAA Alumni</span>':''}${rankKind==='doubles'?(p.doubles_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Index DB</span>'):''}<div class="muted micro">${rankKind==='singles'?(p.official_ranking?'ATP officiel #'+fmt(p.official_ranking):p.game_generated?'Joueur généré Court Boss':'Base historique / scouting'):rankKind==='junior'?(p.junior_rank_type==='official'?'Rang jeu #'+fmt(p.junior_ranking)+' · ITF source #'+fmt(p.junior_official_ranking)+(rankSnapshot(p,rankKind)?' · au '+df(rankSnapshot(p,rankKind)):''):p.junior_rank_type==='verified_nr'?'Rang jeu #'+fmt(p.junior_ranking)+' · ITF vérifié, rang estimé':'Rang jeu #'+fmt(p.junior_ranking)+' · Newgen simulé · 13–17 ans'):(rankSnapshot(p,rankKind)?'au '+df(rankSnapshot(p,rankKind)):'')}${p.ncaa_current&&p.ncaa_school?' · '+esc(p.ncaa_school):p.ncaa_status==='Alumni'&&p.ncaa_last_school?' · ex-'+esc(p.ncaa_last_school):''}</div></td><td>${rankAge(p,rankKind)}</td><td>${flags[p.country]||'🏳️'} ${esc(p.country)}</td><td><b>${rankPoints(p,rankKind)==null?'—':fmt(rankPoints(p,rankKind))}</b></td><td>${rankKind==='nextgen'?(p.ranking?'#'+fmt(p.ranking):'—'):p.current_ability+'/100'}</td><td>${rankKind==='nextgen'?(p.nextgen_status==='withdrawn'?'<span class="badge bad">Retiré</span>':p.nextgen_status==='alternate'?'<span class="badge warn">Remplaçant</span>':p.nextgen_status==='qualified'?'<span class="badge good">Qualifié</span>':p.potential+'/100'):p.potential+'/100'}</td></tr>`).join('')}
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
  <div class="notice mini" style="margin-top:10px"><b>ITA NCAA Division I Simple</b> · ${fmt(rankMeta?.verifiedCurrentRanks||0)}/${fmt(rankMeta?.officialCapacity||125)} rangs officiels 2026-27 reliés · snapshot ${df(rankMeta?.rankingDate||'2026-08-25')}. Le vivier affiche ensuite les actifs, rosters historiques et alumni NCAA vérifiés, sans inventer de rang ITA.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Âge 01/12/25</th><th>Université</th><th>Division</th><th>ATP</th><th>Statut</th></tr></thead><tbody>
   ${rows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${p.ncaa_rank?'#'+fmt(p.ncaa_rank):'—'}</td><td><b>${esc(p.name)}</b><div class="muted micro">${flags[p.country]||'🏳️'} ${esc(p.country||'')}</div></td><td>${rankAge(p,'ncaa')}</td><td><b>${esc(p.ncaa_school||'—')}</b></td><td>${esc(p.ncaa_division||'NCAA')}</td><td>${p.ranking_current&&p.ranking?'#'+fmt(p.ranking):'—'}</td><td><span class="badge ${(p.ncaa_current||p.ncaa_current_verified)?'good':''}">${(p.ncaa_current||p.ncaa_current_verified)?'NCAA actif':p.ncaa_status==='Alumni'?'NCAA Alumni':esc(p.ncaa_status||'NCAA historique')}</span></td></tr>`).join('')}
  </tbody></table></div>
  ${rows.length?'' : '<div class="empty">Aucun profil NCAA pour ce filtre.</div>'}
  <div class="pagination"><button ${rankOffset===0?'disabled':''} onclick="rankPage(-1)">←</button><span class="muted mini">lignes ${fmt(startRow)}–${fmt(endRow)} / ${fmt(rankCount)}</span><button ${rankOffset+100>=rankCount?'disabled':''} onclick="rankPage(1)">→</button></div>`;
 const doublesTable=`
  <div class="notice mini" style="margin-top:10px"><b>ITA NCAA Division I Double</b> · ${fmt(ncaaDoublesMeta?.count||doubleRows.length)}/${fmt(ncaaDoublesMeta?.officialCapacity||90)} paires officielles · snapshot ${df(ncaaDoublesMeta?.rankingDate||'2026-08-25')}. Chaque joueur ouvre sa vraie fiche Court Boss.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>#</th><th>Paire</th><th>Université</th><th>Référence</th></tr></thead><tbody>
   ${doubleRows.map(x=>`<tr><td class="rank-num">#${fmt(x.ita_rank)}</td><td><b><span class="click" onclick="openPlayer(${x.player_one_id})">${esc(x.player_one_name)}</span> / <span class="click" onclick="openPlayer(${x.player_two_id})">${esc(x.player_two_name)}</span></b></td><td>${esc(x.school||'—')}</td><td><span class="badge good">ITA officiel</span></td></tr>`).join('')}
  </tbody></table></div>
  ${doubleRows.length?'' : '<div class="empty">Aucune paire NCAA pour ce filtre.</div>'}`;
 return `<div class="section-head"><div><div class="eyebrow">NCAA / ITA</div><h1>Joueurs universitaires</h1><div class="muted">Base NCAA profonde : Top 125 simple, Top 90 double, actifs 2026-27, rosters historiques, alumni et transferts reliés à la même base mondiale.</div></div><span class="pill">${fmt(rankCount)} profils NCAA</span></div>
 <div class="tabs rank-tabs">${[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['junior_doubles','Junior Double'],['itf','ITF WTT'],['ncaa','NCAA / ITA']].map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}<button class="deep-db-tab" onclick="dbCircuit='Tous réels';dbOffset=0;dbLoaded=false;nav('players')">Monde ${fmt(worldStats?.worldRankingCapacity||30000)}</button></div>
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
function calendar(){
 const cats=['Toutes','Grand Chelem','Masters 1000','ATP 500','ATP 250','ATP Finals','Next Gen Finals','United Cup','Laver Cup','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','Junior Grand Slam','J500','J300','J200','J100','J60','J30','Junior Finals','Junior Davis Cup','NCAA DI Team Championship','NCAA DI Individual Championship','NCAA','Junior','Davis Cup'];
 const circs=['Tous','ATP','Challenger','ITF','NCAA','Junior','Federation'];
 const surfaces=['Toutes','Dur extérieur','Dur intérieur','Terre','Gazon','Moquette'];
 const officialCount=worldStats?.verifiedTournaments||0;
 const coverage=`ATP ${fmt(worldStats?.officialATP||0)} · CH ${fmt(worldStats?.officialChallenger||0)} · ITF ${fmt(worldStats?.officialITF||0)} · Junior ${fmt(worldStats?.officialJunior||0)} · NCAA ${fmt(worldStats?.officialNCAA||0)} · Davis ${fmt(worldStats?.officialFederation||0)}`;
 return `<div class="section-head"><div><div class="eyebrow">Planification</div><h1>Calendrier mondial</h1><div class="muted">ATP, Challenger, ITF, Juniors, NCAA et Coupe Davis. Par défaut : à partir de la date de ta carrière.</div></div><div class="row" style="flex-wrap:wrap;justify-content:flex-end"><button class="${tourShowPast?'primary':'ghost'}" onclick="toggleFullCalendar()">${tourShowPast?'Saison 2026 complète':'Voir toute la saison'}</button><span class="pill">${fmt(tourCount)} affichés</span><span class="badge good">${fmt(officialCount)} officiels</span><span class="badge">${coverage}</span></div></div>
 <div class="filters fm-calendar-filters"><input class="input" placeholder="Rechercher un tournoi…" value="${esc(tourFilters.q)}" onchange="tourFilter('q',this.value)"><select class="select" onchange="tourFilter('circuit',this.value)">${circs.map(x=>`<option ${x===tourFilters.circuit?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('category',this.value)">${cats.map(x=>`<option ${x===tourFilters.category?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('surface',this.value)">${surfaces.map(x=>`<option ${x===tourFilters.surface?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('source',this.value)">${['Tous','Officiel','Simulation'].map(x=>`<option ${x===tourFilters.source?'selected':''}>${x}</option>`).join('')}</select><input class="input" type="month" value="${tourFilters.month}" onchange="tourFilter('month',this.value)"></div>
 <div class="surface-legend"><span class="surface-hard">● Dur extérieur</span><span class="surface-indoor">● Dur intérieur</span><span class="surface-clay">● Terre battue</span><span class="surface-grass">● Gazon</span></div>
 <div class="section-head" style="margin-top:14px"><div><div class="eyebrow">Conseiller calendrier</div><h2>Recommandé pour ton joueur</h2><div class="muted">Score basé sur cut, fatigue, voyage, surface et niveau.</div></div><button class="ghost" onclick="loadScheduleAdvice().then(render)">Actualiser</button></div>
 <div class="grid g3">${(scheduleAdvice?.recommended||[]).slice(0,6).map(t=>`<div class="card click" onclick="openTournament(${t.id})"><div class="row between"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span><b>${t.recommendation_score}/100</b></div><h3>${esc(t.name)}</h3><div class="muted mini">${esc(t.city||'')} · ${df(t.start_date)} · <span class="${String(t.environment||'')==='Indoor'?'surface-indoor':surfaceClass(t.surface)}">${esc(surfaceLabel(t))}</span> · ${t.is_verified?'Officiel':'Simulation'}</div><div class="bar" style="margin-top:9px"><i style="width:${t.recommendation_score}%"></i></div></div>`).join('')||'<div class="card empty">Aucune recommandation.</div>'}</div>
 <div class="stack">${tourRows.map(t=>tournamentCard(t)).join('')||'<div class="card empty">Aucun tournoi daté pour ces filtres.</div>'}</div>
 ${tourTbc.length?`<div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Date à confirmer</div><h2>Événements officiels TBC</h2></div></div><div class="stack">${tourTbc.map(t=>`<div class="card"><div class="row between"><div><span class="badge good">Officiel · TBC</span><h2 style="margin:8px 0 4px">${esc(t.name)}</h2><div class="muted">${esc(t.city||'TBC')} · date à confirmer · <span class="surface-indoor">${esc(surfaceLabel(t))}</span></div></div><span class="badge">${esc(t.category||'ATP')}</span></div></div>`).join('')}</div>`:''}
 <div class="pagination"><button ${tourOffset===0?'disabled':''} onclick="tourPage(-1)">←</button><span class="muted mini">${tourCount?fmt(tourOffset+1):0}–${fmt(Math.min(tourOffset+tourRows.length,tourCount))} / ${fmt(tourCount)}</span><button ${tourOffset+60>=tourCount?'disabled':''} onclick="tourPage(1)">→</button></div>`
}
function tournamentCard(t){
 const c=career(),isJunior=String(t.circuit)==='Junior',isFederation=String(t.circuit)==='Federation',isNcaa=String(t.circuit)==='NCAA';
 const elig=isFederation?'Par sélection nationale':isNcaa?'Championnat universitaire':isJunior?'Circuit Junior ITF':t.direct_cut==null?'Règles spéciales':c.singles_rank<=t.direct_cut?'Tableau direct':c.singles_rank<=t.qual_cut?'Qualifications':'Alternate / hors cut';
 const joined=(local.entries||[]).includes(t.id);
 const target=isFederation?"nav('davis')":isNcaa?"nav('university')":'openTournament('+t.id+')';
 const action=isFederation?'<button class="soft-btn" onclick="event.stopPropagation();nav(\'davis\')">Voir la Coupe Davis</button>':isNcaa?'<button class="soft-btn" onclick="event.stopPropagation();nav(\'university\')">Voir NCAA</button>':`<button class="${joined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleEntry(${t.id})">${joined?'Inscrit · retirer':'S’inscrire'}</button>`;
 return `<div class="card click" onclick="${target}"><div class="row between"><div><div class="row"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span>${t.is_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Monde simulé</span>'}</div><h2 style="margin:8px 0 4px">${flags[t.country]||'🏳️'} ${esc(t.name)}</h2><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} · <span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span>${t.venue?' · '+esc(t.venue):''}</div></div><div style="text-align:right"><span class="badge ${elig==='Tableau direct'?'good':elig==='Qualifications'?'warn':''}">${elig}</span><div style="margin-top:8px">${action}</div></div></div></div>`
}
window.tourFilter=async(k,v)=>{tourFilters[k]=v;if(k==='circuit'&&v==='Junior'&&tourFilters.source==='Tous')tourFilters.source='Officiel';tourOffset=0;await loadTournaments();render()}
window.toggleFullCalendar=async()=>{tourShowPast=!tourShowPast;tourOffset=0;await loadTournaments();render()}
window.tourPage=async d=>{tourOffset=Math.max(0,tourOffset+d*60);await loadTournaments();render();window.scrollTo(0,0)}
function datesOverlap(aStart,aEnd,bStart,bEnd){
 const a1=new Date((aStart||aEnd)+'T12:00:00'),a2=new Date((aEnd||aStart)+'T12:00:00'),b1=new Date((bStart||bEnd)+'T12:00:00'),b2=new Date((bEnd||bStart)+'T12:00:00');
 return a1<=b2&&b1<=a2;
}
window.toggleEntry=id=>{
 local.entries=local.entries||[];local.entryMeta=local.entryMeta||{};
 const exists=local.entries.includes(id);
 if(exists){
   local.entries=local.entries.filter(x=>x!==id);delete local.entryMeta[id];persist();render();return;
 }
 const t=[...(tourRows||[]),...(boot.upcoming||[])].find(x=>x.id===id);
 if(t){
   const conflict=Object.entries(local.entryMeta).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(t.start_date,t.end_date,e.start_date,e.end_date));
   if(conflict){
     alert('Conflit calendrier avec '+conflict[1].name+' ('+df(conflict[1].start_date)+'). Retire d’abord l’autre inscription.');
     return;
   }
   local.entryMeta[id]={name:t.name,start_date:t.start_date,end_date:t.end_date,country:t.country,circuit:t.circuit,category:t.category};
 }
 local.entries.push(id);persist();render();
}
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
 const missions=['U23 potentiel','Top 300 immédiat','Serveurs puissants','Spécialistes terre battue','Double & volée','NCAA / université'];
 return `<div class="section-head"><div><div class="eyebrow">Recrutement</div><h1>Scouting</h1><div class="muted">Affectations régionales, missions, confiance d'observation et shortlist.</div></div><button class="primary" onclick="nav('players')">Chercher joueur</button></div>
 <div class="grid g3">${(boot.scouting||[]).map(s=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(s.region)}</div><h2>${esc(s.scout_name)}</h2></div><span class="badge ${s.status==='completed'?'good':''}">${esc(s.status)}</span></div><div class="list-item"><span class="muted mini">Mission</span><select class="select" onchange="changeScoutAssignment(${s.id},this.value)">${missions.map(m=>`<option ${m===s.focus?'selected':''}>${m}</option>`).join('')}</select></div><div class="bar" style="margin-top:12px"><i style="width:${s.progress}%"></i></div><div class="mini muted" style="margin-top:5px">${s.progress}% du rapport · début ${df(s.started_at)}</div></div>`).join('')}</div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Shortlist</h2>${shortlist.length?shortlist.map(s=>`<div class="list-item row between click" onclick="openPlayer(${s.players?.id})"><div><b>${flags[s.players?.country]||'🏳️'} ${esc(s.players?.name||'Joueur')}</b><div class="muted mini">ATP #${s.players?.ranking||'—'} · PA ${s.players?.potential||'—'}</div></div><span class="badge">${esc(s.priority||'Normal')}</span></div>`).join(''):'<div class="empty">Aucun joueur suivi. Ajoute-en depuis un profil.</div>'}</div>
  <div class="card"><h2>Prospects académie</h2><div class="table-wrap"><table class="table"><thead><tr><th>Joueur</th><th>Âge</th><th>PA</th></tr></thead><tbody>${(boot.youth||[]).map(y=>`<tr class="click" onclick="openYouth(${y.id})"><td><b>${esc(y.name)}</b></td><td>${y.age}</td><td class="a-good"><b>${y.potential}</b></td></tr>`).join('')}</tbody></table></div></div>
 </div>`
}
window.changeScoutAssignment=async(id,focus)=>{try{await managerAction('set_scouting_assignment',id,{focus});boot=await get('/api/bootstrap');render()}catch(e){alert(e.message)}}
function more(){
 const items=[['players','Base joueurs',fmt(worldStats?.searchableRealPlayers||22000)+' profils réels · recherche mondiale au-delà du Top 2000 + ITF + Juniors + NCAA + Double'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Réseau et prospects'],['staff','Staff','Coach, fitness, physio, agent'],['contracts','Contrats','Salaires et échéances'],['finance','Finances','Budget et dépenses'],['medical','Médical','Blessures, fatigue, récupération'],['match','Match Center','Historique et données match'],['tactics','Tactique','Plan de match & coaching'],['fantasy','Fantasy Court','Créer un tournoi personnalisé'],['doubles','Double','Partenaires et compatibilité'],['university','Universitaire','NCAA / ITA'],['davis','Coupe Davis','Fédération française'],['board','Board','Objectifs et confiance'],['world','Monde','Circuits et profondeur'],['history','Histoire & nations','Légendes par pays et continent'],['myplayer','Mon joueur','Identité, style et carrière'],['inbox','Boîte de réception','Décisions et alertes']];
 return `<div class="section-head"><div><div class="eyebrow">Centre manager</div><h1>Tous les modules</h1></div></div><div class="grid g2">${items.map(x=>`<div class="card click" onclick="nav('${x[0]}')"><div class="eyebrow">${x[1]}</div><h2>${x[2]}</h2></div>`).join('')}</div>`
}
function playersPage(){
 if(!dbLoaded&&!dbLoading)setTimeout(()=>loadPlayerDatabase().then(()=>{if(route==='players')render()}).catch(()=>{}),0);
 const circuits=['Tous','Tous réels','ATP classés','ATP profond','ITF','Junior','Junior Double','NCAA','Double','Race','Next Gen'];
 const start=dbCount?dbOffset+1:0,end=Math.min(dbOffset+dbRows.length,dbCount);
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Scouting database · ${fmt(worldStats?.searchableRealPlayers||dbCount||20000)} profils réels</div><h1>Base joueurs mondiale</h1><div class="muted">Recherche sans plafond Top 2000 : ATP profond, ITF, NCAA, juniors, anciens joueurs et prospects réels.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(worldStats?.searchableRealPlayers||dbCount||20000)} joueurs</div><div class="fm-head-badge subtle">${fmt(worldStats?.realPlayersWithDob||0)} DOB sourcées</div><div class="fm-head-badge subtle">${fmt(worldStats?.estimatedAgeReal||0)} âges estimés</div></div></div>
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
   ${dbLoading?'<div class="loader">Recherche dans la base…</div>':`<div class="table-wrap"><table class="table fm-db-table"><thead><tr><th>Joueur</th><th>Âge 01/12/25</th><th>Pays</th><th>ATP</th><th>Double</th><th>Junior Dbl</th><th>ITF</th><th>Revers</th><th>NCAA</th><th>CA</th><th>PA</th></tr></thead><tbody>${dbRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td><b>${esc(p.name)}</b><div class="muted micro">${p.is_real?'Réel':'Newgen'}${p.style?' · '+esc(p.style):''}</div></td><td>${displayAge(p)==null?'<span class="muted">N/V</span>':`<span title="${esc(p.age_source||'')}">${esc(ageLabel(p,false))}</span>`}</td><td>${flags[p.country]||'🌐'} ${esc(p.country||'—')}</td><td>${p.ranking?'#'+fmt(p.ranking)+(p.ranking>2000?' <span class="muted micro">ATP profond</span>':''):'—'}</td><td>${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'—'}</td><td>${p.junior_doubles_ranking?'#'+fmt(p.junior_doubles_ranking):'—'}</td><td>${p.itf_ranking?'#'+fmt(p.itf_ranking):'—'}</td><td><span class="badge ${p.backhand_verified?'good':''}">${esc(p.backhand||'2 mains')}${p.backhand_verified?'':' · estimé'}</span></td><td>${p.ncaa_current?'<span class="badge tag-ncaa">'+(p.ncaa_rank?'#'+fmt(p.ncaa_rank):'NCAA actif')+'</span>':p.ncaa_verified?'<span class="badge">'+(p.ncaa_status==='Alumni'?'NCAA Alumni':'NCAA historique')+'</span>':'—'}</td><td><b>${p.current_ability??'—'}</b></td><td>${p.potential??'—'}</td></tr>`).join('')}</tbody></table></div>`}
   ${!dbLoading&&!dbRows.length?'<div class="empty">Aucun joueur trouvé avec ces filtres.</div>':''}
   <div class="pagination"><button ${dbOffset===0?'disabled':''} onclick="dbPage(-1)">←</button><span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(dbCount)}</span><button ${dbOffset+100>=dbCount?'disabled':''} onclick="dbPage(1)">→</button></div>
  </div>
 </div>`
}
window.searchPlayerDatabase=async q=>{dbQuery=String(q||'').trim();dbOffset=0;await loadPlayerDatabase();render()}
window.setDbCountry=async c=>{dbCountry=String(c||'').toUpperCase();dbOffset=0;await loadPlayerDatabase();render()}
window.setDbCircuit=async c=>{dbCircuit=String(c||'Tous');dbOffset=0;await loadPlayerDatabase();render()}
window.dbPage=async d=>{dbOffset=Math.max(0,dbOffset+d*100);await loadPlayerDatabase();render();window.scrollTo(0,0)}

function staffPage(){
 const cand=management?.candidates||[];
 return `<div class="section-head"><div><div class="eyebrow">Équipe</div><h1>Staff</h1><div class="muted">Compétences, coûts et recrutement.</div></div></div>
 <div class="grid g2">${(boot.staff||[]).map(s=>`<div class="card click" onclick="openStaff(${s.id})"><div class="row between"><div><div class="eyebrow">${esc(s.role)}</div><h2>${esc(s.role)}</h2></div><div class="progress-ring" style="--p:${s.skill*5}"><b>${s.skill}/20</b></div></div><p class="muted">Coût hebdomadaire : ${euro(s.weekly_cost)}</p></div>`).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Marché du staff</div><h2>Candidats disponibles</h2></div></div>
 <div class="grid g2">${cand.map(x=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(x.role)}</div><h2>${esc(x.name)}</h2></div><div class="progress-ring" style="--p:${x.skill*5}"><b>${x.skill}/20</b></div></div><p class="muted">${esc(x.specialty||'')} · ${euro(x.weekly_cost)}/sem.</p><div class="row between"><span class="mini muted">Prime ${euro(x.signing_cost)}</span><button class="${x.status==='hired'?'ghost':'primary'}" ${x.status==='hired'?'disabled':''} onclick="hireStaff(${x.id})">${x.status==='hired'?'Recruté':'Recruter'}</button></div></div>`).join('')}</div>`
}
function contractsPage(){
 const rows=management?.contracts||[];
 return `<div class="section-head"><div><div class="eyebrow">Négociations</div><h1>Contrats</h1><div class="muted">Échéances, salaires et renouvellements.</div></div></div><div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>Personne</th><th>Rôle</th><th>Salaire/sem.</th><th>Fin</th><th>Statut</th><th></th></tr></thead><tbody>${rows.map(x=>`<tr><td class="click" onclick="openContract(${x.id})"><b>${esc(x.subject_name)}</b></td><td>${esc(x.role||x.subject_type)}</td><td>${euro(x.weekly_salary)}</td><td>${df(x.end_date)}</td><td><span class="badge good">${esc(x.status)}</span></td><td><button class="soft-btn" onclick="renewContract(${x.id})">+ 1 an</button></td></tr>`).join('')}</tbody></table></div></div>`
}
function financePage(){
 const cr=career(),f=boot.finance||{},offers=management?.sponsors||[];
 const accepted=offers.filter(x=>x.status==='accepted');
 const sponsorWeekly=accepted.reduce((sum,x)=>sum+Number(x.weekly_value||0),0);
 const staffWeekly=(boot.staff||[]).reduce((sum,x)=>sum+Number(x.weekly_cost||0),0);
 const playerWeekly=(management?.academyRoster||[]).reduce((sum,x)=>sum+Number(x.weekly_cost||0),0);
 return `<div class="section-head"><div><div class="eyebrow">Comptabilité</div><h1>Finances & sponsors</h1></div></div>
 <div class="kpi-strip"><div class="kpi"><span class="muted mini">Solde</span><b>${euro(cr.budget)}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${euro(f.prize_money)}</b></div><div class="kpi"><span class="muted mini">Sponsors / sem.</span><b>${euro(sponsorWeekly)}</b></div><div class="kpi"><span class="muted mini">Masse salariale</span><b>${euro(staffWeekly+playerWeekly)}</b></div></div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Offres commerciales</h2>${offers.map(x=>`<div class="list-item"><div class="row between"><div><b>${esc(x.brand)}</b><div class="muted mini">${euro(x.weekly_value)}/sem. · bonus ${euro(x.signing_bonus)} · ${x.duration_weeks} sem.</div></div><span class="badge ${x.status==='accepted'?'good':x.status==='locked'?'bad':''}">${esc(x.status)}</span></div><div class="muted mini" style="margin-top:5px">${esc(x.requirement||'')}</div>${x.status==='available'?`<button class="primary" style="margin-top:8px" onclick="acceptSponsor(${x.id})">Accepter</button>`:''}</div>`).join('')||'<div class="empty">Aucune offre.</div>'}</div>
  <div class="card"><h2>Projection hebdomadaire</h2><div class="list-item row between"><span>Revenus sponsors</span><b class="good">+${euro(sponsorWeekly)}</b></div><div class="list-item row between"><span>Staff</span><b class="bad">-${euro(staffWeekly)}</b></div><div class="list-item row between"><span>Joueurs académie</span><b class="bad">-${euro(playerWeekly)}</b></div><div class="list-item row between"><span>Net hebdomadaire</span><b class="${sponsorWeekly-staffWeekly-playerWeekly>=0?'good':'bad'}">${sponsorWeekly-staffWeekly-playerWeekly>=0?'+':''}${euro(sponsorWeekly-staffWeekly-playerWeekly)}</b></div><div class="list-item row between"><span>Voyage moyen</span><b class="bad">-${euro(Number(f.travel_cost||0)/4)}</b></div><div class="notice" style="margin-top:10px">Les sponsors signés alimentent le budget à chaque semaine simulée.</div></div>
 </div>`
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
    ${lp.shot?`<div class="fm-rally-call">${esc(lp.shot)} · ${Number(lp.rally||0)} coups${lp.zone?' · '+esc(lp.zone):''}</div>`:''}
  </div>

  <div class="fm-momentum"><span>${esc(oppName)}</span><div><i style="left:${momentum}%"></i></div><span>${esc(userName)}</span></div>
  <div class="fm-match-stats">
   <div><span>Winners</span><b>${st.user_winners||0}–${st.opp_winners||0}</b></div>
   <div><span>Fautes</span><b>${st.user_errors||0}–${st.opp_errors||0}</b></div>
   <div><span>Aces</span><b>${st.user_aces||0}</b></div>
   <div><span>Rallyes</span><b>${s.rally_no||0}</b></div>
  </div>
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
 const all=[...(local.practiceMatches||[]),...(boot.matches||[])];
 return `<div class="section-head"><div><div class="eyebrow">Analyse & coaching</div><h1>Match Center</h1><div class="muted">Prépare le plan de jeu, coache point par point et analyse les tendances.</div></div><button class="ghost" onclick="simulatePracticeMatch()">Simulation rapide</button></div>
 ${liveMatchPanel()}
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
 const c=career();
 if(!doublesHubRows.length&&!doublesHubLoading)setTimeout(loadDoublesHub,0);
 const pool=doublesHubRows;
 const juniorPool=juniorDoublesHubRows;
 const partner=pool.find(p=>p.id===local.partnerId)||juniorPool.find(p=>p.id===local.partnerId)
   ||(management?.partnerships||[]).map(x=>x.partner||x.player_b).find(Boolean)
   ||null;
 const candidates=pool.filter(p=>p.name!==c.player_name).slice(0,30);
 const exact=pool.filter(p=>p.doubles_source).length;
 return `<div class="section-head"><div><div class="eyebrow">Circuit Double</div><h1>Double & partenariats</h1><div class="muted">Classement individuel officiel jusqu’au Top 1000, index scouting double profond, Race par équipes et gestion du partenaire. La base double étendue contient ${fmt(worldStats?.indexedDoubles||rankCount||0)} profils.</div></div><span class="pill">${fmt(worldStats?.sourcedDoubles||exact)} officiels · ${fmt(worldStats?.indexedDoubles||0)} indexés</span></div>
 <div class="tabs rank-tabs"><button class="active">Partenariat</button><button onclick="setRankKind('doubles');nav('rankings')">Classement Double</button><button onclick="setRankKind('junior_doubles');nav('rankings')">Junior Double</button><button onclick="dbCircuit='Double';dbOffset=0;dbQuery='';loadPlayerDatabase().then(()=>nav('players'))">Base double complète</button><button onclick="document.getElementById('dblRace').scrollIntoView({behavior:'smooth'})">Race équipes</button></div>
 <div class="grid g2" style="margin-top:10px">
  <div class="card"><div class="row between"><h2>Partenaire actuel</h2><span class="badge">Ton rang #${fmt(c.doubles_rank)}</span></div>
   ${partner?`<div class="row between click" onclick="openPlayer(${partner.id})"><div><h2>${flags[partner.country]||'🏳️'} ${esc(partner.name)}</h2><div class="muted">Double #${fmt(partner.doubles_ranking)} ${partner.ranking?'· ATP #'+partner.ranking:''}</div><div class="muted mini">${partner.doubles_snapshot_date?'réf. '+df(partner.doubles_snapshot_date):''}</div></div><span class="badge good">Sélectionné</span></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Chimie</span><b>${pairScore(partner,'chem')}%</b></div><div class="kpi"><span class="muted mini">Compatibilité</span><b>${pairScore(partner,'comp')}%</b></div><div class="kpi"><span class="muted mini">Force paire</span><b>${pairScore(partner,'power')}%</b></div></div>`:'<div class="empty">Choisis un spécialiste dans le classement Double.</div>'}
  </div>
  <div class="card"><div class="row between"><h2>Top double vérifié</h2><button class="ghost" onclick="setRankKind('doubles');nav('rankings')">Voir tout</button></div>
   ${pool.slice(0,12).map(p=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>#${p.doubles_ranking} ${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${p.doubles_points==null?'points non publiés dans ce snapshot':fmt(p.doubles_points)+' pts'} · ${df(p.doubles_snapshot_date)}</div></div><button class="soft-btn" onclick="choosePartner(${p.id})">Choisir</button></div>`).join('')||'<div class="loader">Chargement du classement double…</div>'}
  </div>
 </div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Circuit Junior</div><h2>Top Junior Double</h2><div class="muted">Classement individuel séparé #1–#2000. Les joueurs peuvent former une paire et jouer le double dans les tournois juniors.</div></div><button class="ghost" onclick="setRankKind('junior_doubles');nav('rankings')">Voir les 2000</button></div>
 <div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Âge 01/12/25</th><th>Pts</th><th></th></tr></thead><tbody>
 ${juniorPool.slice(0,20).map(p=>`<tr><td class="rank-num">#${fmt(p.junior_doubles_ranking)}</td><td class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted micro">Junior simple #${p.junior_ranking||'—'}</div></td><td>${rankAge(p,'junior_doubles')}</td><td>${fmt(p.junior_doubles_points||0)}</td><td><button class="soft-btn" onclick="choosePartner(${p.id})">Associer</button></td></tr>`).join('')}
 </tbody></table></div></div>
 <div id="dblRace" class="section-head" style="margin-top:18px"><div><div class="eyebrow">ATP Finals</div><h2>Race double par équipes</h2><div class="muted">Race double · ${doublesRaceRows[0]?.snapshot_date?df(doublesRaceRows[0].snapshot_date):"snapshot courant"} · ${fmt(doublesRaceRows.length)} équipes chargées.</div></div></div>
 <div class="card"><div class="row between" style="margin-bottom:8px"><span class="muted mini">Historique équipes importé : ${fmt(doublesRaceRows.length)} équipes</span><button class="ghost" onclick="setRankKind(\'doubles\');nav(\'rankings\')">Classement individuel</button></div><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Équipe</th><th>Points</th><th>Référence</th></tr></thead><tbody>
 ${doublesRaceRows.map(x=>`<tr><td class="rank-num">#${x.rank}</td><td><b><span class="click" onclick="openPlayerByName('${esc(String(x.player_one||'').replace(/'/g,"\\'"))}')">${esc(x.player_one)}</span> / <span class="click" onclick="openPlayerByName('${esc(String(x.player_two||'').replace(/'/g,"\\'"))}')">${esc(x.player_two)}</span></b></td><td>${fmt(x.points)}</td><td>${df(x.snapshot_date)}</td></tr>`).join('')}
 </tbody></table></div>${!doublesRaceRows.length?'<div class="loader">Chargement de la Race équipes…</div>':''}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Scouting double</div><h2>Spécialistes disponibles</h2></div></div>
 <div class="grid g2">${candidates.slice(0,20).map(p=>`<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">Double #${p.doubles_ranking}</div><h3>${flags[p.country]||'🏳️'} ${esc(p.name)}</h3><div class="muted mini">${p.ranking?'ATP #'+p.ranking+' · ':''}CA ${p.current_ability} · PA ${p.potential}</div></div><button class="primary" onclick="choosePartner(${p.id})">Associer</button></div></div>`).join('')}</div>`
}
function universityPage(){
 const teams=management?.college||[],offers=management?.collegeOffers||[],state=management?.collegeState||{},duals=management?.collegeDuals||[];
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
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Programme NCAA</div><h1>#${t.ita_rank} ${esc(t.name)}</h1><div class="muted">Bilan ${esc(t.record)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><h2>Recrutement</h2>${offers.length?offers.map(o=>`<div class="list-item"><div class="row between"><span>Bourse</span><b>${o.scholarship_pct}%</b></div><div class="muted mini">${esc(o.role)} · fit sportif ${o.development_fit}/100</div></div>`).join(''):'<div class="empty">Pas d’offre active.</div>'}</div></div></div>`;
}
window.commitCollege=async id=>{try{await managerAction('commit_college',id);await refreshManagerState();render()}catch(e){alert(e.message)}}
window.turnProCollege=async()=>{try{if(!confirm('Passer professionnel et quitter la NCAA ? Le dossier universitaire restera archivé.'))return;await managerAction('turn_pro_college',1);await refreshManagerState();render()}catch(e){alert(e.message)}}
window.playCollegeDual=async id=>{try{await managerAction('play_college_dual',id);await loadManagement();render()}catch(e){alert(e.message)}}
function davisPage(){
 const f=boot.federation||{},sq=boot.davisSquad||[],ties=management?.davisTies||[];
 const roles=['Simple 1','Simple 2','Double A','Double B','Réserve'];
 const today=String(local.date||'2026-09-27');
 const franceTies=ties.filter(t=>t.home_nation==='FRA'||t.away_nation==='FRA').sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const nextFrance=franceTies.find(t=>t.status!=='completed'&&String(t.tie_date)>=today)||null;
 const lastFrance=[...franceTies].reverse().find(t=>t.status==='completed'||String(t.tie_date)<today)||null;
 const focusTie=nextFrance||lastFrance||franceTies[0]||null;
 const final8=ties.filter(t=>String(t.stage||'').includes('Final 8')).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const worldQualifiers=ties.filter(t=>!String(t.stage||'').includes('Final 8')).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const franceAlive=final8.some(t=>t.home_nation==='FRA'||t.away_nation==='FRA');
 const scoreFor=t=>t.home_score!=null&&t.away_score!=null?`${t.home_score}-${t.away_score}`:'vs';
 const tieCard=t=>{const unresolved=/^(TBD|Winner )/i.test(String(t.home_nation||''))||/^(TBD|Winner )/i.test(String(t.away_nation||''));const ready=t.status!=='completed'&&!unresolved;return `<div class="davis-tie-card ${t.status==='completed'?'completed':''} ${ready?'click':''}" ${ready?`onclick="playDavisTie(${t.id})"`:''}>
   <div class="row between"><span class="badge tag-fed">${esc(t.stage||'Coupe Davis')}</span><span class="muted mini">${df(t.tie_date)}</span></div>
   <div class="davis-matchup"><b>${flags[t.home_nation]||'🏳️'} ${esc(t.home_nation)}</b><strong>${scoreFor(t)}</strong><b>${flags[t.away_nation]||'🏳️'} ${esc(t.away_nation)}</b></div>
   <div class="row between" style="margin-top:7px"><div class="muted mini">${esc(t.venue||'Lieu à confirmer')} · <span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span></div>${ready?'<span class="badge warn">Simuler</span>':t.status==='completed'?'<span class="badge good">Terminé</span>':'<span class="badge">En attente</span>'}</div>
 </div>`};
 return `<div class="fm-dashboard">
 <div class="fm-page-head"><div><div class="eyebrow">Équipe nationale</div><h1>Coupe Davis</h1><div class="muted">Saison 2026, sélection française et tableau mondial.</div></div><div class="fm-head-stack"><div class="fm-head-badge">FRA ${f.reputation||91}/100</div><div class="fm-head-badge subtle">${franceAlive?'Final 8':'Parcours terminé'}</div></div></div>

 <div class="grid g2">
  <div class="card davis-focus">
   <div class="row between"><div><div class="eyebrow">${nextFrance?'Prochaine rencontre France':'Dernière rencontre France'}</div><h2>${focusTie?`${flags[focusTie.home_nation]||'🏳️'} ${esc(focusTie.home_nation)} ${scoreFor(focusTie)} ${esc(focusTie.away_nation)} ${flags[focusTie.away_nation]||'🏳️'}`:'Aucune rencontre'}</h2></div>${nextFrance?'<span class="badge warn">À venir</span>':'<span class="badge">Terminée</span>'}</div>
   ${focusTie?`<div class="list-item row between"><span>Date</span><b>${df(focusTie.tie_date)}</b></div><div class="list-item row between"><span>Phase</span><b>${esc(focusTie.stage||'—')}</b></div><div class="list-item row between"><span>Terrain</span><b class="${surfaceClass(surfaceLabel(focusTie))}">${esc(surfaceLabel(focusTie))}</b></div><div class="list-item row between"><span>Lieu</span><b>${esc(focusTie.venue||'—')}</b></div>`:''}
   ${nextFrance?'<button class="primary" style="margin-top:10px" onclick="playDavisTie('+nextFrance.id+')">Jouer la rencontre</button>':'<div class="notice" style="margin-top:10px">La France n’est pas qualifiée pour le Final 8 actuellement affiché. Le tableau mondial continue quand même dans la simulation.</div>'}
  </div>
  <div class="card"><div class="row between"><div><div class="eyebrow">Sélection</div><h2>Équipe de France</h2></div><span class="pill">${sq.length} joueurs</span></div>
   ${sq.map(sqRow=>{const p=sqRow.players;if(!p)return'';const role=local.davisRoles[p.id]||sqRow.role||'Réserve';return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking||'—'} · Double #${fmt(p.doubles_ranking||9999)}</div></div><select class="select" style="width:auto" onchange="setDavisRole(${p.id},this.value)">${roles.map(r=>`<option ${r===role?'selected':''}>${r}</option>`).join('')}</select></div>`}).join('')||'<div class="empty">Aucun joueur sélectionné.</div>'}
  </div>
 </div>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Parcours France</div><h2>Qualifications 2026</h2></div></div>
 <div class="davis-timeline">${franceTies.map(tieCard).join('')||'<div class="card empty">Aucune rencontre France chargée.</div>'}</div>

 <details class="card davis-world-qualifiers" style="margin-top:16px" open>
  <summary class="row between"><div><div class="eyebrow">Monde</div><h2>Qualifications Coupe Davis 2026</h2></div><span class="pill">${worldQualifiers.length} rencontres</span></summary>
  <div class="davis-bracket" style="margin-top:10px">${worldQualifiers.map(tieCard).join('')||'<div class="empty">Aucune rencontre mondiale chargée.</div>'}</div>
 </details>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Bologne</div><h2>Final 8 2026</h2><div class="muted">Quarts programmés du 24 au 26 novembre, puis demi-finales et finale.</div></div><span class="badge good">Dur intérieur</span></div>
 <div class="davis-bracket">${final8.map(tieCard).join('')||'<div class="card empty">Tableau Final 8 indisponible.</div>'}</div>

 ${focusTie?.davis_rubbers?.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Détail</div><h2>Rubbers de la rencontre France</h2></div></div><div class="stack">${focusTie.davis_rubbers.sort((x,y)=>x.rubber_no-y.rubber_no).map(r=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(r.rubber_type)} · Rubber ${r.rubber_no}</div><h2>${esc(r.home_names)} vs ${esc(r.away_names)}</h2></div><div style="text-align:right"><div class="big" style="font-size:22px">${esc(r.score||'—')}</div><span class="badge ${r.winner_nation==='FRA'?'good':'bad'}">${esc(r.winner_nation||'—')}</span></div></div></div>`).join('')}</div>`:''}
 </div>`
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
  <div class="menu-card" onclick="nav('calendar')"><div class="menu-icon">📅</div><strong>Compétitions</strong><span class="muted">ATP, Challenger, ITF, Junior, NCAA, Davis</span></div>
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
  <div class="fm-page-head"><div><div class="eyebrow">Data hub historique</div><h1>Histoire, records & nations</h1><div class="muted">Légendes, Hall of Fame, records de Grand Chelem et générations U18/U21 dans la même base.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(d.coverage?.countries||0)} nations</div><div class="fm-head-badge subtle">${fmt(d.coverage?.ncaaProfiles||0)} profils NCAA</div></div></div>
  <div class="fm-filterbar">
   <select class="select" onchange="setHistoryCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${historyCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select>
   <select class="select" onchange="setHistoryContinent(this.value)">${continents.map(x=>`<option value="${esc(x)}" ${historyContinent===x?'selected':''}>${x||'Tous continents'}</option>`).join('')}</select>
   <button class="ghost" onclick="historyCountry='';historyContinent='';loadHistory().then(render)">Réinitialiser</button>
  </div>
  ${global?`<div class="fm-history-hero card click" onclick="openPlayer(${global.id})"><div><div class="eyebrow">Référence de la sélection</div><div class="hero-name">${flags[global.country]||'🏳️'} ${esc(global.name)}</div><div class="muted">${esc(global.country)} · ${esc(global.continent)} · ${global.career_status==='retired'?'Retraité':'Actif'}</div></div><div class="fm-history-score"><span>Indice historique</span><b>${fmt(global.history_score)}</b></div><div class="fm-history-stats"><div><span>Grand Chelem</span><b>${global.grand_slams}</b></div><div><span>Titres</span><b>${global.titles}</b></div><div><span>Victoires</span><b>${fmt(global.wins)}</b></div><div><span>% victoires</span><b>${global.win_pct==null?'—':global.win_pct+'%'}</b></div></div></div>`:''}

  <div class="fm-record-grid">
   ${recordCard('Record Grand Chelem',rec.grand_slams,'grand_slams',' GC')}
   ${recordCard('Record titres',rec.titles,'titles','')}
   ${recordCard('Record victoires',rec.wins,'wins','')}
   ${rec.win_pct?`<div class="fm-record click" onclick="openPlayer(${rec.win_pct.id})"><span>Meilleur % victoires</span><b>${flags[rec.win_pct.country]||'🏳️'} ${esc(rec.win_pct.name)}</b><strong>${rec.win_pct.win_pct}%</strong></div>`:''}
  </div>

  <div class="grid g2" style="margin-top:12px">
   <div class="card"><div class="row between"><div><div class="eyebrow">Court Boss Hall of Fame</div><h2>Légendes majeures</h2></div><span class="badge">${(d.hallOfFame||[]).length}</span></div>${(d.hallOfFame||[]).slice(0,16).map((x,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">${i+1}</div><div class="grow"><b>${flags[x.country]||'🏳️'} ${esc(x.name)}</b><div class="muted mini">${x.grand_slams} GC · ${x.titles} titres · ${fmt(x.wins)} victoires</div></div><b>${fmt(x.history_score)}</b></div>`).join('')}</div>
   <div class="card"><div class="row between"><div><div class="eyebrow">Records majeurs</div><h2>Grand Chelem</h2></div><span class="badge">Historique</span></div>${(d.grandSlamRecords||[]).slice(0,16).map((x,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">${i+1}</div><div class="grow"><b>${esc(x.name)}</b><div class="muted mini">${flags[x.country]||'🏳️'} ${esc(x.country)} · ${x.titles} titres</div></div><strong class="a-good">${x.grand_slams} GC</strong></div>`).join('')}</div>
  </div>

  <div class="grid g2" style="margin-top:12px">${youth(d.u18||[],'Top U18')}${youth(d.u21||[],'Top U21')}</div>

  <div class="grid g2" style="margin-top:12px">
   <div class="card"><div class="row between"><div><div class="eyebrow">Par continent</div><h2>Références historiques</h2></div><span class="badge">Top par zone</span></div>${(d.continentBest||[]).filter(x=>x.continent!=='Other').map(x=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">#1</div><div class="grow"><b>${esc(x.continent)} · ${esc(x.name)}</b><div class="muted mini">${flags[x.country]||'🏳️'} ${esc(x.country)} · ${x.grand_slams} GC · ${x.titles} titres</div></div><b>${fmt(x.history_score)}</b></div>`).join('')||'<div class="empty">Pas assez de données historiques.</div>'}</div>
   <div class="card"><div class="row between"><div><div class="eyebrow">Par nationalité</div><h2>Meilleur de chaque pays</h2></div><span class="badge">${fmt((d.countryBest||[]).length)} pays</span></div><div class="fm-country-grid">${(d.countryBest||[]).slice(0,32).map(x=>`<button class="fm-country-tile" onclick="historyContinent='';setHistoryCountry('${esc(x.country)}')"><span>${flags[x.country]||'🏳️'} ${esc(x.country)}</span><b>${esc(x.name)}</b><small>${x.grand_slams} GC · ${x.titles} titres</small></button>`).join('')}</div></div>
  </div>

  <div class="card fm-panel" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Classement historique</div><h2>${historyCountry?'Nationalité '+esc(historyCountry):historyContinent?esc(historyContinent):'Monde'}</h2></div><span class="pill">${fmt(rows.length)} profils</span></div>
   <div class="table-wrap"><table class="table fm-history-table"><thead><tr><th>#</th><th>Joueur</th><th>Pays</th><th>Continent</th><th>GC</th><th>Titres</th><th>V-D</th><th>Indice</th></tr></thead><tbody>${rows.map((x,i)=>`<tr class="click" onclick="openPlayer(${x.id})"><td class="rank-num">#${i+1}</td><td><b>${esc(x.name)}</b><div class="muted micro">${x.career_status==='retired'?'Retraité':'Actif'}</div></td><td>${flags[x.country]||'🏳️'} ${esc(x.country)}</td><td>${esc(x.continent)}</td><td><b>${x.grand_slams}</b></td><td>${x.titles}</td><td>${fmt(x.wins)}-${fmt(x.losses)}</td><td class="a-good"><b>${fmt(x.history_score)}</b></td></tr>`).join('')}</tbody></table></div>
  </div>
  <div class="notice mini" style="margin-top:12px">${esc(d.methodology||'Indice historique Court Boss calculé sur les données de carrière importées.')} Le Hall of Fame est une vue du jeu, pas un classement officiel.</div>
 </div>`
}
window.setHistoryCountry=async c=>{historyCountry=String(c||'').toUpperCase();if(c)historyContinent='';await loadHistory();render()}
window.setHistoryContinent=async c=>{historyContinent=String(c||'');if(c)historyCountry='';await loadHistory();render()}

function myPlayerPage(){
 const c=career();
 return `<div class="section-head"><div><div class="eyebrow">Carrière</div><h1>Mon joueur</h1><div class="muted">Personnalise ton joueur géré et suis sa trajectoire.</div></div></div>
 <div class="grid g2"><div class="card"><h2>Identité</h2><label class="mini muted">Nom</label><input class="input" value="${esc(c.player_name)}" onchange="editCareer('player_name',this.value)"><label class="mini muted">Pays</label><input class="input" value="${esc(c.country)}" onchange="editCareer('country',this.value)"><label class="mini muted">Style</label><select class="select" onchange="editCareer('style',this.value)">${['Attaquant polyvalent','Attaquant fond de court','Contreur','All-court','Serveur-volée'].map(s=>`<option ${s===c.style?'selected':''}>${s}</option>`).join('')}</select></div>
 <div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">ATP</span><b>#${fmt(c.singles_rank)}</b></div><div class="statbox"><span class="muted mini">Double</span><b>#${fmt(c.doubles_rank)}</b></div><div class="statbox"><span class="muted mini">CA</span><b>${c.current_ability||56}</b></div><div class="statbox"><span class="muted mini">PA</span><b>${c.potential||82}</b></div></div><div class="list-item row between"><span>Âge</span><input class="input" style="max-width:100px" type="number" value="${c.age||19}" onchange="editCareer('age',Number(this.value))"></div><div class="list-item row between"><span>Taille</span><input class="input" style="max-width:100px" type="number" value="${c.height_cm||184}" onchange="editCareer('height_cm',Number(this.value))"></div><div class="list-item row between"><span>Poids</span><input class="input" style="max-width:100px" type="number" value="${c.weight_kg||78}" onchange="editCareer('weight_kg',Number(this.value))"></div></div></div>`
}
function fantasyPage(){
 const rows=local.fantasy||[];
 return `<div class="section-head"><div><div class="eyebrow">Mode créatif</div><h1>Fantasy Court</h1><div class="muted">Crée ton propre tournoi, surface et format.</div></div><button class="primary" onclick="createFantasy()">Nouveau tournoi</button></div><div class="stack">${rows.map((t,i)=>`<div class="card click" onclick="openFantasy(${i})"><div class="row between"><div><div class="eyebrow">${esc(t.category)}</div><h2>${esc(t.name)}</h2><div class="muted">${esc(surfaceLabel(t))} · ${t.draw} joueurs</div></div><button class="danger-btn" onclick="event.stopPropagation();deleteFantasy(${i})">Supprimer</button></div></div>`).join('')||'<div class="card empty">Aucun tournoi personnalisé. Crée le premier.</div>'}</div>`
}
function inboxPage(){return `<div class="section-head"><div><div class="eyebrow">Communication</div><h1>Boîte de réception</h1></div></div><div class="stack">${(boot.inbox||[]).map(x=>`<div class="card click" onclick="openInboxItem(${x.id},'${esc(x.action_route||'home')}')"><div class="row between"><div class="eyebrow">${esc(x.kind)}</div><span class="badge ${x.is_read?'':'good'}">${x.is_read?'Lu':'Nouveau'}</span></div><h2>${esc(x.title)}</h2><p class="muted">${esc(x.body)}</p></div>`).join('')}</div>`}
function render(){
 if(!boot)return;
 const views={home,rankings,calendar,academy,more,players:playersPage,training,scouting,staff:staffPage,contracts:contractsPage,finance:financePage,medical:medicalPage,match:matchPage,tactics:tacticsPage,fantasy:fantasyPage,doubles:doublesPage,university:universityPage,davis:davisPage,board:boardPage,world:worldPage,history:historyPage,myplayer:myPlayerPage,fantasy:fantasyPage,inbox:inboxPage};
 shell((views[route]||more)());
}
window.openPlayer=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du dossier joueur…</div></div></div>';
 try{
  const d=await get('/api/player?id='+id),p=d.player;if(!p)throw new Error('Joueur introuvable');
  const a=p.player_attributes||{},ncaaRows=d.ncaa||[],ncaaCareer=d.ncaaCareer||null,legend=d.legend||null;
  const ncaa=p.ncaa_current?(ncaaRows.find(x=>String(x.status||'')==='Active')||null):null;
  const ncaaIsAlumni=String(p.ncaa_status||'')==='Alumni'||String(ncaaCareer?.status||'')==='Alumni';
  const ncaaHistorical=!p.ncaa_current&&!!p.ncaa_verified&&!ncaaIsAlumni;
  const allTitles=d.titles||[],singlesTitles=allTitles.filter(t=>!t.event_type||t.event_type==='singles'),doublesTitles=allTitles.filter(t=>t.event_type==='doubles'),collegeTitles=allTitles.filter(t=>/^ncaa_|^college_/.test(String(t.event_type||'')));
  const titleCount=legend?.titles??singlesTitles.length;
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
  const bestSeason=titleYears.length?titleYears.reduce((best,x)=>Number(x[1])>Number(best[1])?x:best,titleYears[0]):null;
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
   ['Technique',[['Puissance service','serve_power'],['Précision service','serve_precision'],['Coup droit','forehand'],['Revers','backhand'],['Retour','return_game'],['Volée','volley'],['Toucher','touch']]],
   ['Physique',[['Déplacements','movement'],['Vitesse','speed'],['Endurance','stamina'],['Force','strength']]],
   ['Mental',[['Anticipation','anticipation'],['Concentration','concentration'],['Sang-froid','composure'],['Combativité','fighting_spirit'],['Tactique','tactics']]],
   ['Spécial',[['Double','doubles'],['Terre battue','clay_affinity'],['Dur','hard_affinity'],['Gazon','grass_affinity']]]
  ];
  const rankBits=[];
  if(p.ranking_current&&p.ranking!=null)rankBits.push('ATP #'+fmt(p.ranking));
  if(p.doubles_ranking!=null&&p.doubles_source)rankBits.push('Double #'+fmt(p.doubles_ranking)+(p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''));
  if(p.race_ranking!=null&&p.race_source)rankBits.push('Race #'+fmt(p.race_ranking)+(p.race_snapshot_date?' · '+df(p.race_snapshot_date):''));
  if(p.nextgen_ranking!=null&&p.nextgen_source)rankBits.push('Next Gen #'+fmt(p.nextgen_ranking)+(p.nextgen_snapshot_date?' · '+df(p.nextgen_snapshot_date):''));
  if(p.junior_doubles_ranking!=null)rankBits.push('Junior Double #'+fmt(p.junior_doubles_ranking));
  if(p.junior_ranking!=null){const jx=p.junior_rank_type==='official'&&p.junior_official_ranking!=null?' · ITF officiel #'+fmt(p.junior_official_ranking):p.junior_rank_type==='verified_nr'?' · rang estimé':p.game_generated?' · simulé':'';rankBits.push('Junior #'+fmt(p.junior_ranking)+jx);}
  if(p.ncaa_current)rankBits.push('NCAA actif'+(ncaa?.ita_rank?' ITA #'+fmt(ncaa.ita_rank):p.ncaa_rank?' ITA #'+fmt(p.ncaa_rank):'')+(ncaa?.school?' · '+ncaa.school:p.ncaa_school?' · '+p.ncaa_school:''));
  else if(ncaaIsAlumni)rankBits.push('NCAA Alumni'+((ncaaCareer?.verified||p.ncaa_verified)?' certifié':'')+' · '+(ncaaCareer?.school||p.ncaa_last_school||'Université'));
  else if(ncaaHistorical)rankBits.push((p.ncaa_status||'NCAA historique')+(p.ncaa_last_school?' · '+p.ncaa_last_school:''));
  const isRetired=String(p.career_status||'active')==='retired';
  const rankSummary=isRetired?'Retraité · historique carrière':(rankBits.length?rankBits.join(' · '):'Non classé actuellement');
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier joueur ${isRetired?'· Légende':''}</div><h1>${flags[p.country]||'🏳️'} ${esc(p.name)} ${isRetired?'<span class="badge">Retraité</span>':''}</h1><div class="muted">${esc(rankSummary)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="tabs" style="margin-top:12px"><button class="active" data-player-tab="profile" onclick="playerSection('profile')">Profil</button><button data-player-tab="attrs" onclick="playerSection('attrs')">Attributs</button><button data-player-tab="development" onclick="playerSection('development')">Développement</button><button data-player-tab="matches" onclick="playerSection('matches')">Matchs</button><button data-player-tab="double" onclick="playerSection('double')">Double</button><button data-player-tab="career" onclick="playerSection('career')">Palmarès</button><button data-player-tab="commercial" onclick="playerSection('commercial')">Commercial</button><button data-player-tab="history" onclick="playerSection('history')">Historique</button></div>
   <div id="playerBody">
    <div class="card fm-player-header" style="margin-bottom:12px"><div class="row" style="align-items:center;gap:14px"><div style="width:108px;height:128px;border-radius:16px;overflow:hidden;background:#10251c;display:flex;align-items:center;justify-content:center;flex:0 0 auto">${playerPhotoMarkup(p)}</div><div><div class="eyebrow">${p.is_real?'Identité réelle':'Joueur généré Court Boss'}</div><h2 style="margin:2px 0 5px">${esc(p.name)}</h2><div class="muted">${p.birth_date?'Né le '+df(p.birth_date)+' · '+ageLabel(p,true):p.age!=null?(ageLabel(p,true)+' · date de naissance non vérifiée'):'Âge non vérifié'}</div><div class="row" style="margin-top:8px;flex-wrap:wrap">${playerPhotoSourceLabel(p)?`<span class="badge">${esc(playerPhotoSourceLabel(p))}</span>`:''}${ncaa?`<span class="badge good">NCAA actif · ${esc(ncaa.school||p.ncaa_school||'Université')} · #${ncaa.ita_rank||p.ncaa_rank||'—'}</span>`:ncaaIsAlumni?`<span class="badge">NCAA Alumni${ncaaCareer?.verified||p.ncaa_verified?' certifié':''} · ${esc(ncaaCareer?.school||p.ncaa_last_school||'Université')}</span>`:ncaaHistorical?`<span class="badge">NCAA historique · ${esc(p.ncaa_last_school||ncaaCareer?.school||'Université')} · statut actuel non vérifié</span>`:''}${Array.isArray(p.circuits_2025)&&p.circuits_2025.map(c=>`<span class="badge">${esc(c)}</span>`).join('')}</div></div></div></div>
    <div class="grid g2"><div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">Âge au 01/12/2025</span><b>${esc(ageLabel(p,false))}</b><small class="muted micro">${/estim/i.test(String(p.age_source||''))?'estimé':'sourcé'}</small></div><div class="statbox"><span class="muted mini">Taille</span><b>${p.height_cm?p.height_cm+' cm':'—'}</b><small class="muted micro">${p.height_cm?(p.height_verified?'sourcée':'estimée'):''}</small></div><div class="statbox"><span class="muted mini">Main</span><b style="font-size:15px">${esc(p.handedness||'—')}</b></div><div class="statbox"><span class="muted mini">Revers</span><b style="font-size:15px">${esc(p.backhand||'2 mains')}</b><small class="muted micro">${p.backhand_verified?'sourcé':'estimé'}</small></div><div class="statbox"><span class="muted mini">Style</span><b style="font-size:15px">${esc(p.style||'—')}</b></div></div><div class="muted micro" style="margin-top:8px">Revers : ${esc(p.backhand_source||'Estimation Court Boss · non sourcée')}${p.birth_date_source?' · DOB : '+esc(p.birth_date_source):''}${p.age_source?' · Âge : '+esc(p.age_source):''}${p.height_source?' · Taille : '+esc(p.height_source):''}${p.weight_source?' · Poids : '+esc(p.weight_source):''}</div>
<div class="player-bio-grid" style="margin-top:10px">
 ${p.weight_kg?`<div class="list-item row between"><span>Poids</span><span><b>${p.weight_kg} kg</b> <span class="muted micro">${p.weight_verified?'sourcé':'estimé'}</span></span></div>`:''}
 ${p.birthplace?`<div class="list-item row between"><span>Lieu de naissance</span><b>${esc(p.birthplace)}</b></div>`:''}
 ${p.turned_pro_year?`<div class="list-item row between"><span>Passage pro</span><b>${p.turned_pro_year}</b></div>`:''}
 ${p.coaches?`<div class="list-item row between"><span>Coach(s)</span><b>${esc(p.coaches)}</b></div>`:''}
</div>
<div class="card" style="margin-top:10px;padding:12px">
 <div class="eyebrow">Classements du joueur</div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">ATP</span><b>${p.ranking_current&&p.ranking!=null?'#'+fmt(p.ranking):'NR'}</b></div>
  <div class="kpi"><span class="muted mini">Double</span><b>${p.doubles_ranking!=null?'#'+fmt(p.doubles_ranking):'NR'}</b></div>
  <div class="kpi"><span class="muted mini">Junior</span><b>${p.junior_ranking!=null?'#'+fmt(p.junior_ranking):'—'}</b><small class="muted micro">${p.junior_rank_type==='official'&&p.junior_official_ranking!=null?'ITF officiel #'+fmt(p.junior_official_ranking):p.junior_rank_type==='verified_nr'?'rang estimé · ITF NR':p.game_generated&&p.junior_ranking!=null?'simulé':''}</small></div><div class="kpi"><span class="muted mini">Junior Double</span><b>${p.junior_doubles_ranking!=null?'#'+fmt(p.junior_doubles_ranking):'—'}</b><small class="muted micro">${p.junior_doubles_ranking!=null?'simulé':''}</small></div>
  <div class="kpi"><span class="muted mini">NCAA / ITA</span><b>${(ncaa?.ita_rank??p.ncaa_rank)!=null?'#'+fmt(ncaa?.ita_rank??p.ncaa_rank):p.ncaa_current?'Actif':'—'}</b><small class="muted micro">${esc(ncaa?.school||p.ncaa_school||'')}</small></div>
 </div>
</div>
${p.bio_source?`<div class="muted micro" style="margin-top:6px">Bio : ${esc(p.bio_source)}${p.bio_verified?' · sourcée':''}</div>`:''}${Array.isArray(p.circuits_2025)&&p.circuits_2025.length?`<div class="row" style="margin-top:10px;flex-wrap:wrap">${p.circuits_2025.map(c=>`<span class="badge">${esc(c)} 2025</span>`).join('')}</div>`:''}${ncaa?`<div class="list-item row between"><span>NCAA / ITA</span><b>#${ncaa.ita_rank||p.ncaa_rank||'—'} · ${esc(ncaa.school||p.ncaa_school||'Université')}</b></div>`:ncaaIsAlumni?`<div class="list-item row between"><span>Carrière NCAA</span><b>${esc(ncaaCareer?.school||p.ncaa_last_school||'Université')} · Alumni${ncaaCareer?.verified||p.ncaa_verified?' · certifié':''}</b></div>`:ncaaHistorical?`<div class="list-item row between"><span>NCAA historique</span><b>${esc(p.ncaa_last_school||ncaaCareer?.school||'Université')} · ${esc(p.ncaa_status||'Roster historique')}</b></div>`:''}</div><div class="card"><h2>Données historiques</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Titres simple</span><b>${titleCount}</b></div><div class="kpi"><span class="muted mini">Titres double</span><b>${doublesTitles.length}</b></div><div class="kpi"><span class="muted mini">NCAA / College</span><b>${collegeTitles.length}</b></div><div class="kpi"><span class="muted mini">Grand Chelem</span><b>${slamCount}</b></div></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${hardTitles}</span><span class="badge clay">Terre ${clayTitles}</span><span class="badge grass">Gazon ${grassTitles}</span></div></div></div>
    <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Bilan historique</h2>${realMatches?`<div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${fmt(realMatches)}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${fmt(cs.wins||0)}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${fmt(cs.losses||0)}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${realWinPct}%</b></div></div><div class="list-item row between"><span>Dur</span><b>${cs.hard_wins==null||cs.hard_losses==null?'Non renseigné':cs.hard_wins+'-'+cs.hard_losses+' · '+surfacePct(cs.hard_wins,cs.hard_losses)}</b></div><div class="list-item row between"><span>Terre battue</span><b>${cs.clay_wins==null||cs.clay_losses==null?'Non renseigné':cs.clay_wins+'-'+cs.clay_losses+' · '+surfacePct(cs.clay_wins,cs.clay_losses)}</b></div><div class="list-item row between"><span>Gazon</span><b>${cs.grass_wins==null||cs.grass_losses==null?'Non renseigné':cs.grass_wins+'-'+cs.grass_losses+' · '+surfacePct(cs.grass_wins,cs.grass_losses)}</b></div><div class="muted mini" style="margin-top:8px">Source : ${esc(cs.source||'Archives de matchs')} · relevé du ${cs.source_snapshot?df(cs.source_snapshot):'—'}${String(cs.source||'').startsWith('https://')?' · <a href="'+esc(cs.source)+'" target="_blank" rel="noopener noreferrer">Consulter la source</a>':' · Agrégat importé, périmètre non certifié ATP'}</div>`:'<div class="empty">Historique match réel non disponible pour ce joueur.</div>'}</div><div class="card"><h2>Scouting</h2><div class="notice">Les notes 1–20 sont des évaluations de jeu, pas des statistiques officielles ATP.</div><p class="muted mini" style="margin-top:10px">Confiance : ${p.scouting_confidence}% · Source : ${esc(p.data_source||'Court Boss')} ${p.data_snapshot?'· snapshot '+df(p.data_snapshot):''}</p><div class="row" style="margin-top:10px;flex-wrap:wrap"><button class="soft-btn" onclick="toggleShortlist(${p.id})">${(d.shortlist||(local.shortlist||[]).includes(p.id))?'Retirer de la shortlist':'Ajouter à la shortlist'}</button><button class="soft-btn" onclick="addComparePlayerV2(${p.id})">Comparer</button>${p.doubles_ranking!=null&&!isRetired?`<button class="soft-btn" onclick="choosePartner(${p.id});closeOverlay()">Partenaire double</button>`:''}${p.is_real&&!isRetired?`<button class="primary" onclick="startCareerWithPlayer(${p.id},'${esc(p.name).replaceAll("'","&#39;")}')">Gérer ce joueur</button>`:isRetired?'<span class="badge">Carrière terminée</span>':''}</div></div></div>
   </div>
   <template id="attrsTpl"><div class="notice">Les attributs 1–20 décrivent le profil de scouting du jeu. Pour le top mondial, les profils sont corrigés manuellement afin d'éviter des aberrations comme Djokovic à 8/20 sur toutes les surfaces.</div><div class="attr-sections" style="margin-top:12px">${groups.map(g=>`<div class="attr-group"><h3>${g[0]}</h3>${g[1].map(x=>{const v=a[x[1]];return `<div class="attr-row"><div class="row"><span>${x[0]}</span><b class="${attrClass(v)}">${v??'—'}</b></div><div class="bar"><i style="width:${(v??0)*5}%"></i></div></div>`}).join('')}</div>`).join('')}</div></template>
   <template id="developmentTpl"><div class="grid g2"><div class="card"><h2>Développement</h2><div class="row between"><span>Capacité actuelle</span><b>${p.current_ability}/100</b></div><div class="bar"><i style="width:${p.current_ability}%"></i></div><div class="row between" style="margin-top:12px"><span>Potentiel</span><b>${p.potential}/100</b></div><div class="bar"><i style="width:${p.potential}%"></i></div><p class="muted mini" style="margin-top:10px">L'âge, le staff, les installations et la charge de travail influencent la progression.</p></div><div class="card"><h2>Axes à travailler</h2>${Object.entries(a).filter(([k,v])=>k!=='player_id'&&Number.isFinite(Number(v))).sort((x,y)=>Number(x[1])-Number(y[1])).slice(0,5).map(([k,v])=>`<div class="list-item row between"><span>${esc(k.replaceAll('_',' '))}</span><b>${v}/20</b></div>`).join('')}</div></div></template>
   <template id="matchesTpl">${(d.juniorEntries||[]).length?`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Circuit ITF Junior</div><h2>Tournois juniors vérifiés</h2></div><span class="badge">Junior #${p.junior_ranking||'—'}</span></div>${(d.juniorEntries||[]).map(e=>{const t=Array.isArray(e.tournaments)?e.tournaments[0]:e.tournaments;return `<div class="list-item row between"><div><b>${esc(t?.name||'Tournoi junior')}</b><div class="muted mini">${t?.city?esc(t.city)+' · ':''}${t?.start_date?df(t.start_date):''} · ${esc(t?.category||'Junior')} · ${esc(surfaceLabel(t||{}))}</div></div><div style="text-align:right"><b>${esc(e.result||'Engagé')}</b><div class="muted mini">${e.seed?'TDS '+esc(e.seed):''}</div></div></div>`}).join('')}</div>`:''}<div class="grid g2"><div class="card"><h2>Historique importé</h2>${realMatches?`<div class="big">${fmt(cs.wins||0)} - ${fmt(cs.losses||0)}</div><div class="muted">${realWinPct}% de victoires · ${fmt(realMatches)} matchs</div><div class="bar" style="margin-top:10px"><i style="width:${realWinPct}%"></i></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${pct(cs.hard_wins,cs.hard_losses)}%</span><span class="badge clay">Terre ${pct(cs.clay_wins,cs.clay_losses)}%</span><span class="badge grass">Gazon ${pct(cs.grass_wins,cs.grass_losses)}%</span></div>`:'<div class="empty">Pas de données historiques.</div>'}</div><div class="card"><h2>Bilan dans la sauvegarde</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${(d.matches||[]).length}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${(d.matches||[]).filter(m=>m.winner_id===p.id).length}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${(d.matches||[]).filter(m=>m.winner_id!==p.id).length}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${(d.matches||[]).length?Math.round((d.matches||[]).filter(m=>m.winner_id===p.id).length/(d.matches||[]).length*100):0}%</b></div></div></div><div class="card"><h2>Forme actuelle</h2><div class="row between"><span>Forme</span><b>${p.form}/100</b></div><div class="bar"><i style="width:${p.form}%"></i></div><div class="row between" style="margin-top:10px"><span>Fitness</span><b>${p.fitness}/100</b></div><div class="bar"><i style="width:${p.fitness}%"></i></div></div></div><div class="card" style="margin-top:12px"><h2>Historique des matchs</h2>${(d.matches||[]).length?(d.matches||[]).map(m=>{const oppId=m.player_a_id===p.id?m.player_b_id:m.player_a_id;const opp=m.player_a_id===p.id?m.player_b_name:m.player_a_name;const won=m.winner_id===p.id;const tour=m.tournament_runs?.tournaments;return `<div class="list-item row between"><div class="click" onclick="openPlayer(${oppId})"><div><b class="${won?'good':'bad'}">${won?'V':'D'}</b> vs ${esc(opp)}</div><div class="muted mini">${esc(tour?.name||'Tournoi')} · ${esc(m.round_name)} · ${esc(surfaceLabel(tour||{}))}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="muted mini">${df(tour?.start_date)}</div></div></div>`}).join(''):'<div class="empty">Aucun match simulé pour ce joueur dans cette sauvegarde.</div>'}</div></template>
   <template id="doubleTpl">
    <div class="grid g2">
      <div class="card"><div class="row between"><div><div class="eyebrow">Classement individuel</div><h2>ATP Double</h2></div><span class="badge ${p.doubles_source?'good':''}">${p.doubles_source?'Sourcé':'Index DB'}</span></div>
        <div class="statline"><div class="statbox"><span class="muted mini">Rang</span><b>${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'NR'}</b></div><div class="statbox"><span class="muted mini">Points</span><b>${p.doubles_points==null?'—':fmt(p.doubles_points)}</b></div><div class="statbox"><span class="muted mini">Aptitude double</span><b>${a.doubles??'—'}/20</b></div></div>
        <div class="muted mini" style="margin-top:8px">${p.doubles_source?esc(p.doubles_source):'Classement indexé Court Boss'}${p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''}</div>
        ${p.doubles_ranking!=null&&!isRetired?`<button class="primary" style="width:100%;margin-top:10px" onclick="choosePartner(${p.id});closeOverlay()">Choisir comme partenaire</button>`:''}
      </div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Race par équipes</div><h2>Paires 2026</h2></div><span class="badge">${(d.doublesTeams||[]).length}</span></div>
        ${(d.doublesTeams||[]).length?(d.doublesTeams||[]).map(x=>{const partner=x.player_one===p.name?x.player_two:x.player_one;return `<div class="list-item row between"><div><b>#${fmt(x.rank)} · ${esc(partner)}</b><div class="muted mini">${esc(x.player_one)} / ${esc(x.player_two)} · ${x.snapshot_date?df(x.snapshot_date):''}</div></div><b>${fmt(x.points)} pts</b></div>`}).join(''):'<div class="empty">Aucune paire Race actuelle trouvée pour ce joueur.</div>'}
      </div>
    </div>
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
      ${(d.historicalSeasons||[]).length?`<div class="table-wrap"><table class="table"><thead><tr><th>Saison</th><th>Titres</th><th>GC</th><th>Masters</th><th>Finals</th><th>Source</th></tr></thead><tbody>${d.historicalSeasons.map(y=>`<tr><td class="rank-num">${y.season}</td><td>${y.titles==null?'—':y.titles}</td><td><b>${y.grand_slams||0}</b></td><td>${y.masters||0}</td><td>${y.tour_finals||0}</td><td class="muted mini">${esc(y.source_label||'Archive')}</td></tr>`).join('')}</tbody></table></div>`:'<div class="empty">Pas encore de découpage annuel disponible.</div>'}
    </div>
   </template>
   <template id="commercialTpl"><div class="card"><h2>Sponsors vérifiés</h2>${d.sponsors.filter(s=>s.verified).length?d.sponsors.filter(s=>s.verified).map(s=>`<span class="badge good" style="margin:4px">${esc(s.sponsor)}</span>`).join(''):'<div class="empty">Non vérifié</div>'}<p class="muted mini" style="margin-top:10px">Aucune marque n'est inventée quand la donnée n'est pas vérifiée.</p></div></template>
   <template id="historyTpl"><div class="card"><h2>Historique de classement</h2>${d.history.length?d.history.map(h=>`<div class="list-item row between"><span>${df(h.snapshot_date)}</span><b>#${h.ranking} · ${fmt(h.points)} pts</b></div>`).join(''):'<div class="empty">Pas encore assez de snapshots.</div>'}</div></template>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur</h2><p>${esc(e.message)}</p></div></div>`}
}
window.playerSection=s=>{const body=document.getElementById('playerBody');if(!body)return;if(!body.dataset.profile)body.dataset.profile=body.innerHTML;const map={attrs:'attrsTpl',development:'developmentTpl',matches:'matchesTpl',double:'doubleTpl',career:'careerTpl',commercial:'commercialTpl',history:'historyTpl'};const t=document.getElementById(map[s]);if(s==='profile')body.innerHTML=body.dataset.profile;else if(t)body.innerHTML=t.innerHTML;overlay.querySelectorAll('[data-player-tab]').forEach(b=>{b.classList.toggle('active',b.dataset.playerTab===s);b.setAttribute('aria-selected',String(b.dataset.playerTab===s))});}
window.closeOverlay=()=>{overlay.innerHTML='';};
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeOverlay();});
window.toggleShortlist=async id=>{
 local.shortlist=local.shortlist||[];
 const active=!local.shortlist.includes(id);
 try{await get('/api/shortlist',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({player_id:id,active,priority:'Normal'})})}catch(e){console.warn(e)}
 local.shortlist=active?[...new Set([...local.shortlist,id])]:local.shortlist.filter(x=>x!==id);
 persist();await loadManagement();closeOverlay();render();
}
window.openTournament=async id=>{
 const fallback=[...(tourRows||[]),...(boot.upcoming||[]),...(scheduleAdvice?.recommended||[])].find(x=>x.id===id);if(!id)return;
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du tournoi…</div></div></div>';
 try{
  const d=await get('/api/tournament-detail?id='+id),t=d.tournament||fallback;if(!t)throw new Error('Tournoi introuvable');
  const cr=career(),wc=d.wildcard||null,isJunior=String(t.circuit)==='Junior';
  const joined=(local.entries||[]).includes(t.id);
  const serverRun=d.run||null,doublesRun=d.doubles_run||null;
  const activePartner=(management?.partnerships||[]).map(x=>x.partner||x.player_b).find(Boolean)||doublesHubRows.find(p=>p.id===local.partnerId)||null;
  const played=local.playedTournaments?.[t.id]||(serverRun?{user_round:serverRun.user_round,user_points:serverRun.user_points,user_prize:serverRun.user_prize}:null);
  const pairs=(d.main||[]).slice(0,Math.min(64,t.draw_size||32));
  const forfeits=d.forfeits||[];
  const completedDraw=d.completed_draw||[];
  const doublesProjection=d.doubles_main||[],doublesCompleted=d.doubles_completed_draw||[];
  const drawRounds=[...new Set(completedDraw.map(m=>m.round_name))];

  const managedId=Number(cr.managed_player_id||boot?.career?.managed_player_id||0);
  const managedJunior=pairs.find(p=>Number(p.id)===managedId);
  const rawElig=isJunior
    ?(managedJunior?'Engagé officiel':'Circuit junior')
    :(t.direct_cut==null?'Règles spéciales':cr.singles_rank<=t.direct_cut?'Tableau direct':cr.singles_rank<=t.qual_cut?'Qualifications':cr.singles_rank<=Number(t.qual_cut||0)+50?'Alternate':'Hors cut');
  const elig=wc?.status==='accepted'?'Wild Card':rawElig;
  const canAttempt=!isJunior&&(elig!=='Hors cut'||wc?.status==='accepted');

  const rankTitle=isJunior?'Junior':'ATP';
  const drawIntro=isJunior
    ?((d.junior_entries||[]).length?'Engagés/résultats vérifiés pour ce tournoi junior.':'Projection à partir du classement junior vérifié.')
    :'Avant le tirage officiel, Court Boss affiche une projection à partir du classement et du cut.';
  const sourceLink=t.source_url?'<a class="soft-btn" href="'+esc(t.source_url)+'" target="_blank" rel="noopener noreferrer">Source officielle</a>':'';

  const juniorResults=(d.junior_entries||[]).map(e=>{
    const p=Array.isArray(e.players)?e.players[0]:e.players;
    return p?`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">Junior #${p.junior_ranking||'—'} ${e.seed?'· TDS '+esc(e.seed):''}</div></div><b>${esc(e.result||'Engagé')}</b></div>`:'';
  }).join('');

  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(t.circuit||'Circuit')} · ${esc(t.category||t.level)}</div><h1>${flags[t.country]||'🏳️'} ${esc(t.name)}</h1><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} → ${df(t.end_date)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="tabs" style="margin-top:12px"><button class="active" onclick="tourSection('overview')">Vue</button><button onclick="tourSection('draw')">${isJunior?'Engagés':'Tableau'}</button>${!isJunior?'<button onclick="tourSection(\'qual\')">Qualifs</button>':''}${t.doubles?'<button onclick="tourSection(\'double\')">Double</button>':''}<button onclick="tourSection('forfeits')">Forfaits ${forfeits.length}</button>${(completedDraw.length||juniorResults)?`<button onclick="tourSection('results')">Résultats</button>`:''}</div>
   <div id="tourBody">
    <div class="grid g2">
      <div class="card"><h2>${isJunior?'Circuit Junior':'Entrée'}</h2>
        ${isJunior?`<div class="list-item row between"><span>Classement utilisé</span><b>ITF Junior</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`:`<div class="list-item row between"><span>Cut tableau</span><b>${t.direct_cut?'#'+t.direct_cut:'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${t.qual_cut?'#'+t.qual_cut:'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`}
        ${wc&&!isJunior?`<div class="list-item row between"><span>Wild card</span><span class="badge ${wc.status==='accepted'?'good':wc.status==='declined'?'bad':''}">${esc(wc.status)}</span></div>`:''}
        <div class="row" style="margin-top:10px;flex-wrap:wrap">${sourceLink}${!isJunior?`<button class="${joined?'danger-btn':'primary'}" onclick="toggleEntry(${t.id});closeOverlay()">${joined?'Retirer l’inscription':rawElig==='Alternate'?'S’inscrire alternate':'S’inscrire'}</button>${rawElig==='Hors cut'&&!wc?`<button class="soft-btn" onclick="requestWildcard(${t.id})">Demander wild card</button>`:''}${joined&&!played&&canAttempt?`<button class="primary" onclick="playTournament(${t.id})">Jouer / simuler</button>`:''}`:''}</div>
        ${played?`<div class="notice" style="margin-top:10px"><b>Résultat :</b> ${esc(played.user_round)} · +${played.user_points} pts · +${euro(played.user_prize)}</div>`:''}
      </div>
      <div class="card"><h2>Informations</h2><div class="list-item row between"><span>Surface</span><b class="${surfaceClass(t.surface)}">${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw_size||32}</b></div><div class="list-item row between"><span>Catégorie</span><b>${esc(t.category||t.level||'—')}</b></div><div class="list-item row between"><span>Donnée</span><b>${t.is_verified?'Vérifiée':'Simulation'}</b></div><div class="list-item row between"><span>Double</span><b>${t.doubles?'Oui':'Non'}</b></div></div>
    </div>
    ${t.doubles?`<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Tableau double</div><h2>${activePartner?esc(activePartner.name):'Partenaire requis'}</h2></div><span class="badge">Ton rang #${fmt(cr.doubles_rank||0)}</span></div>${doublesRun?`<div class="notice good"><b>Déjà joué :</b> ${esc(doublesRun.user_round)} · +${doublesRun.user_points||0} pts · +${euro(doublesRun.user_prize||0)}</div>`:activePartner?`<button class="primary" style="width:100%;margin-top:8px" onclick="playDoublesTournament(${t.id})">Jouer le double avec ${esc(activePartner.name)}</button>`:`<button class="soft-btn" style="width:100%;margin-top:8px" onclick="closeOverlay();nav('doubles')">Choisir un partenaire</button>`}</div>`:''}
   </div>

   <template id="tourOverviewTpl"><div class="grid g2"><div class="card"><h2>${isJunior?'Circuit Junior':'Entrée'}</h2>${isJunior?`<div class="list-item row between"><span>Classement</span><b>ITF Junior</b></div><div class="list-item row between"><span>Engagés connus</span><b>${pairs.length}</b></div>`:`<div class="list-item row between"><span>Cut tableau</span><b>${t.direct_cut?'#'+t.direct_cut:'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${t.qual_cut?'#'+t.qual_cut:'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`}</div><div class="card"><h2>Format</h2><div class="list-item row between"><span>Tableau</span><b>${t.draw_size||32}</b></div><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Référence</span><b>${t.is_verified?'Officielle':'Simulation'}</b></div></div></div></template>

   <template id="tourDrawTpl"><div class="card"><h2>${isJunior?'Engagés juniors':'Liste d’acceptation / tableau projeté'}</h2><p class="muted mini">${drawIntro}</p><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Points</th><th>${isJunior?'Seed / résultat':'Forme'}</th></tr></thead><tbody>${pairs.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${p.ranking||'—'}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.points==null?'—':fmt(p.points)}</td><td>${isJunior?esc([p.seed?'TDS '+p.seed:'',p.result||''].filter(Boolean).join(' · ')||'Engagé'):(p.form??'—')}</td></tr>`).join('')}</tbody></table></div></div></template>

   <template id="tourQualTpl"><div class="card"><h2>Qualifications</h2><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Condition</th></tr></thead><tbody>${(d.qualifying||[]).map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${p.ranking}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.fitness}% / fatigue ${p.fatigue}%</td></tr>`).join('')}</tbody></table></div></div></template>

   <template id="tourDoubleTpl">
    <div class="grid g2"><div class="card"><div class="eyebrow">Partenariat</div><h2>${activePartner?flags[activePartner.country]||'🏳️':''} ${activePartner?esc(activePartner.name):'Aucun partenaire'}</h2><div class="list-item row between"><span>Ton classement</span><b>#${fmt(cr.doubles_rank||0)}</b></div>${activePartner?`<div class="list-item row between"><span>Partenaire</span><b>#${fmt(activePartner.doubles_ranking||0)}</b></div><div class="list-item row between"><span>Chimie</span><b>${pairScore(activePartner,'chem')}%</b></div>`:''}</div><div class="card"><div class="eyebrow">Tournoi</div><h2>${esc(t.name)} · Double</h2><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Catégorie</span><b>${esc(t.category||t.level||'—')}</b></div>${doublesRun?`<div class="notice good"><b>Résultat :</b> ${esc(doublesRun.user_round)} · +${doublesRun.user_points||0} pts</div>`:activePartner?`<button class="primary" style="width:100%;margin-top:10px" onclick="playDoublesTournament(${t.id})">Jouer / simuler le double</button>`:`<button class="soft-btn" style="width:100%;margin-top:10px" onclick="closeOverlay();nav('doubles')">Choisir un partenaire</button>`}</div></div>
    <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Projection tableau</div><h2>Paires de double</h2></div><span class="badge">${doublesProjection.length} équipes</span></div><div class="table-wrap"><table class="table"><thead><tr><th>TDS</th><th>Équipe</th><th>Rangs double</th><th>Source</th></tr></thead><tbody>${doublesProjection.slice(0,32).map(x=>`<tr><td>#${x.seed}</td><td><b>${flags[x.player_a?.country]||'🏳️'} ${esc(x.player_a?.name)} / ${flags[x.player_b?.country]||'🏳️'} ${esc(x.player_b?.name)}</b></td><td>#${fmt(x.player_a?.doubles_ranking||0)} / #${fmt(x.player_b?.doubles_ranking||0)}</td><td><span class="badge ${x.source==='official'?'good':''}">${x.source==='official'?'Officiel':x.source==='junior-simulated'?'Junior Double':'Index DB'}</span></td></tr>`).join('')}</tbody></table></div>${!doublesProjection.length?'<div class="empty">Aucune projection double disponible.</div>':''}</div>
    ${doublesCompleted.length?`<div class="card" style="margin-top:12px"><div class="eyebrow">Ton parcours double</div><h2>Résultats</h2>${doublesCompleted.map(m=>`<div class="list-item"><div class="row between"><b>${esc(m.round_name)}</b><b>${esc(m.score)}</b></div><div>${esc(m.user_pair)} vs ${esc(m.opponent_pair)}</div><div class="muted mini">Vainqueurs : ${esc(m.winner_pair)}</div></div>`).join('')}</div>`:''}
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
window.tourSection=s=>{const m={overview:'tourOverviewTpl',draw:'tourDrawTpl',qual:'tourQualTpl',double:'tourDoubleTpl',forfeits:'tourForfeitsTpl',results:'tourResultsTpl'},t=document.getElementById(m[s]);if(t)document.getElementById('tourBody').innerHTML=t.innerHTML}

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
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Staff</div><h1>${esc(s.role)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="row between"><span>Niveau</span><b>${s.skill}/20</b></div><div class="bar"><i style="width:${s.skill*5}%"></i></div><div class="list-item row between"><span>Coût hebdomadaire</span><b>${euro(s.weekly_cost)}</b></div></div></div></div>`;
}
window.hireStaff=async id=>{try{const d=await managerAction('hire_staff',id);if(local.career)local.career.budget=d.budget;await refreshManagerState();render()}catch(e){alert(e.message)}}
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
window.pairScore=(p,k)=>{const seed=(Number(p.id||1)*17+(k==='chem'?7:k==='comp'?13:19))%19;return clamp(68+seed,55,94)}
window.choosePartner=async id=>{try{await managerAction('choose_partner',id);local.partnerId=id;persist();await loadManagement();render()}catch(e){alert(e.message)}}
window.setDavisRole=async(id,role)=>{local.davisRoles=local.davisRoles||{};for(const [pid,r] of Object.entries(local.davisRoles)){if(r===role&&role!=='Réserve')delete local.davisRoles[pid]}local.davisRoles[id]=role;persist();try{await managerAction('davis_role',id,{role});boot=await get('/api/bootstrap')}catch(e){alert(e.message)}render()}
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
  const d=new Date((local.date||'2026-09-27')+'T12:00:00');d.setDate(d.getDate()+7);
  const nextDate=d.toISOString().slice(0,10),nextWeek=(local.week||1)+1;
  const currentYear=Number(String(local.date||'2026-09-27').slice(0,4)),nextYear=Number(nextDate.slice(0,4));
  if(nextYear>currentYear){
    const roll=await get('/api/rollover-season',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({new_year:nextYear})});
    local.date=String(nextYear)+'-01-05';local.week=1;if(nextYear>2026)tourFilters.source='Tous';
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
  local.feed=local.feed||[];if(sim.medical){local.feed.unshift(sim.medical.recovered?'Centre médical : retour à 100%, le joueur est déclaré apte.':`Centre médical : ${sim.medical.protocol}, risque ${sim.medical.risk_delta>=0?'+':''}${sim.medical.risk_delta}, retour gagné ${sim.medical.return_days_gained||0} jour(s).`)}if(sim.weeklyFinance)local.feed.unshift(`Finances semaine : sponsors +${euro(sim.weeklyFinance.sponsors||0)}, staff -${euro(sim.weeklyFinance.staff||0)}, joueurs -${euro(sim.weeklyFinance.players||0)}, médical -${euro(sim.weeklyFinance.medical||0)} · net ${sim.weeklyFinance.net>=0?'+':''}${euro(sim.weeklyFinance.net||0)}.`);if((sim.weeklyFinance?.expired_contracts||0)>0)local.feed.unshift(`${sim.weeklyFinance.expired_contracts} contrat(s) joueur arrivé(s) à échéance.`);if((sim.academyDevelopment?.ability_progressions||0)>0)local.feed.unshift(`Académie : ${sim.academyDevelopment.ability_progressions} jeune(s) ont progressé en niveau global, ${sim.academyDevelopment.attribute_improvements||0} attribut(s) amélioré(s).`);if((sim.injuries?.new_injuries||0)>0)local.feed.unshift(`${sim.injuries.new_injuries} nouvelle(s) blessure(s) dans le monde cette semaine.`);if((sim.forfeits?.forfeits||0)>0)local.feed.unshift(`${sim.forfeits.forfeits} place(s) libérée(s) par forfait sur les tournois à venir.`);local.feed.unshift(`Semaine simulée : ${cr.player_name||'Joueur'} est ATP #${cr.singles_rank} avec ${cr.points} pts. Monde mis à jour : ${sim.world?.updated_players||0} joueurs.`);local.feed=local.feed.slice(0,8);
  local.career=cr;persist();
  boot=await get('/api/bootstrap');
  if(boot.career){local.career={...cr,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week;}
  await Promise.all([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries()]);
  if(route==='history')await loadHistory();
 }catch(e){try{boot=await get('/api/bootstrap');if(boot.career){local.career={...local.career,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week;localStorage.setItem('cbLocal',JSON.stringify(local));}}catch{}alert('Simulation incomplète : '+e.message)}
 finally{simulating=false;render()}
}
window.openGlobalSearch=()=>{
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Base mondiale · ${fmt(worldStats?.searchableRealPlayers||20000)} joueurs réels · recherche au-delà du Top 2000</div><h1>Recherche joueurs</h1></div><button class="close" onclick="closeOverlay()">✕</button></div>
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