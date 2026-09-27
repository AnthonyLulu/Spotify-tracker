const API='https://qrsvliliezbiedmaewml.supabase.co/functions/v1/court-boss';
const app=document.getElementById('app'),overlay=document.getElementById('overlay');
const flags={FRA:'🇫🇷',ITA:'🇮🇹',GER:'🇩🇪',ESP:'🇪🇸',USA:'🇺🇸',CAN:'🇨🇦',RUS:'🇷🇺',AUS:'🇦🇺',SRB:'🇷🇸',NOR:'🇳🇴',CZE:'🇨🇿',ARG:'🇦🇷',BRA:'🇧🇷',GBR:'🇬🇧',NED:'🇳🇱',BEL:'🇧🇪',SUI:'🇨🇭',AUT:'🇦🇹',JPN:'🇯🇵',KOR:'🇰🇷',CHN:'🇨🇳',MEX:'🇲🇽',POR:'🇵🇹',POL:'🇵🇱',GRE:'🇬🇷',DEN:'🇩🇰',MON:'🇲🇨',TUN:'🇹🇳'};
const saveKey=(()=>{let k=localStorage.getItem('courtBossSaveKey');if(!k){k=crypto.randomUUID();localStorage.setItem('courtBossSaveKey',k)}return k})();
const fmt=n=>new Intl.NumberFormat('fr-FR').format(Math.round(Number(n)||0));
const euro=n=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(Number(n)||0);
const df=s=>s?new Date(s+'T12:00:00').toLocaleDateString('fr-FR',{day:'2-digit',month:'short',year:'numeric'}):'—';
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const get=async(path,opts={})=>{const r=await fetch(API+path,{...opts,headers:{'X-Save-Key':saveKey,...(opts.headers||{})}});const body=await r.json().catch(()=>({error:'Réponse serveur illisible'}));if(!r.ok)throw new Error(body.error||'Erreur serveur '+r.status);return body;};
let boot=null,route='home',rankKind='singles',rankOffset=0,rankRows=[],rankCount=0,rankQuery='',tourOffset=0,tourRows=[],tourCount=0,tourFilters={circuit:'Tous',category:'Toutes',source:'Tous',month:'',q:''},management=null,worldStats=null,rankingLedger=null,seasonSummary=null,scheduleAdvice=null,simulating=false;
let doublesHubRows=[],doublesRaceRows=[],doublesHubLoading=false;
let local={date:'2026-09-27',week:1,training:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'],entries:[],shortlist:[],career:null,feed:[],scoutingBoost:0,partnerId:null,davisRoles:{},fantasy:[],tactics:{aggression:58,risk:52,net:28,returnPos:'Neutre'}};
try{Object.assign(local,JSON.parse(localStorage.getItem('cbLocal')||'{}'))}catch{}
function persist(){localStorage.setItem('cbLocal',JSON.stringify(local));fetch(API+'/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Save-Key':saveKey},body:JSON.stringify(local)}).catch(()=>{})}
function surfaceClass(s){return s==='Terre'?'surface-clay':s==='Gazon'?'surface-grass':'surface-hard'}
function circuitClass(c){return c==='Challenger'?'tag-challenger':c==='ITF'?'tag-itf':c==='NCAA'?'tag-ncaa':c==='Junior'?'tag-junior':c==='Federation'?'tag-fed':'tag-atp'}
function rankValue(p,k){return k==='doubles'?p.doubles_ranking:k==='race'?p.race_ranking:k==='nextgen'?p.nextgen_ranking:k==='itf'?p.itf_ranking:k==='junior'?p.junior_ranking:p.ranking}
function rankPoints(p,k){return k==='doubles'?p.doubles_points:k==='race'?p.race_points:k==='nextgen'?p.nextgen_points:k==='junior'?p.junior_points:p.points}
function rankSnapshot(p,k){return k==='doubles'?p.doubles_snapshot_date:k==='race'?p.race_snapshot_date:k==='nextgen'?p.nextgen_snapshot_date:k==='junior'?p.junior_snapshot_date:p.ranking_snapshot_date||p.data_snapshot}
function ageAtSnapshot(birth,snapshot){
 if(!birth)return null;
 const b=new Date(birth+'T12:00:00'),d=new Date((snapshot||'2025-12-01')+'T12:00:00');
 let a=d.getFullYear()-b.getFullYear();
 if(d.getMonth()<b.getMonth()||(d.getMonth()===b.getMonth()&&d.getDate()<b.getDate()))a--;
 return a;
}
function rankAge(p,k){return ageAtSnapshot(p.birth_date,rankSnapshot(p,k)||'2025-12-01')??p.age??'—'}
function attrClass(v){return v>=18?'a-elite':v>=15?'a-good':v<=8?'a-low':'a-mid'}
function header(){
 const cr=local.career||boot?.career||{};
 return `<header class="topbar"><div class="logo">COURT <b>BOSS</b></div><span class="top-date">${df(local.date||cr.career_date)}</span><div class="grow"></div><button class="ghost icon-btn" onclick="openGlobalSearch()" aria-label="Recherche">⌕</button><button class="ghost" onclick="nav('inbox')">Boîte <span class="badge">${boot?.inbox?.filter(x=>!x.is_read).length||0}</span></button><button class="primary" ${simulating?'disabled':''} onclick="simulateWeek()">${simulating?'Simulation…':'+ 1 semaine'}</button></header>`
}
function navBar(){
 const x=[['home','Accueil'],['rankings','Classements'],['calendar','Calendrier'],['academy','Académie'],['more','Plus']];
 return `<nav class="bottom-nav">${x.map(i=>`<button class="${route===i[0]?'active':''}" onclick="nav('${i[0]}')">${i[1]}</button>`).join('')}</nav>`
}
function shell(body){app.innerHTML=`<div class="app-shell">${header()}<main class="page">${body}</main>${navBar()}</div>`}
function loading(t='Chargement du monde tennis…'){shell(`<div class="loader">${t}</div>`)}
window.nav=async r=>{route=r;window.scrollTo({top:0,behavior:'smooth'});await render()}
async function init(){
 loading();
 try{
   boot=await get('/api/bootstrap');
   if(boot.save&&typeof boot.save==='object') Object.assign(local,boot.save);
   local.career={...(local.career||{}),...(boot.career||{})};
   local.date=boot.career?.career_date||local.date||'2026-09-27';
   local.week=boot.career?.week??local.week??1;
   localStorage.setItem('cbLocal',JSON.stringify(local));
   const [_,__,___,____,_____,______,world]=await Promise.all([
     loadManagement(),loadRankings(),loadTournaments(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),get('/api/world').catch(()=>null)
   ]);
   worldStats=world;
   render();
 }catch(e){shell(`<div class="card"><h2>Connexion au monde impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="location.reload()">Réessayer</button></div>`)}
}
async function loadManagement(){try{management=await get('/api/management')}catch{management={contracts:[],college:[],shortlist:[]}}}
async function loadRankings(){
 const q=rankQuery?'&q='+encodeURIComponent(rankQuery):'';
 const d=await get(`/api/rankings?kind=${rankKind}&offset=${rankOffset}&limit=100${q}`);
 rankRows=d.rows;rankCount=d.count;
}
async function loadTournaments(){
 const p=new URLSearchParams({offset:String(tourOffset),limit:'60'});
 if(!tourFilters.month)p.set('from',local.date||'2026-09-27');
 Object.entries(tourFilters).forEach(([k,v])=>{if(v&&v!=='Tous'&&v!=='Toutes')p.set(k,v)});
 const d=await get('/api/tournaments?'+p.toString());tourRows=d.rows;tourCount=d.count;
}
async function loadRankingLedger(){try{rankingLedger=await get('/api/ranking-ledger?date='+(local.date||'2026-09-27'))}catch(e){rankingLedger={total:((local.career&&local.career.points)||34),active:[],expired:[]}}}
async function loadSeasonSummary(){try{seasonSummary=await get('/api/season-summary')}catch(e){seasonSummary={stats:{tournaments:0,titles:0,finals:0,prize:0,matches:0,wins:0},singles:[],doubles:[],singles_points:[],doubles_points:[]}}}
async function loadScheduleAdvice(){try{scheduleAdvice=await get('/api/schedule-advice')}catch(e){scheduleAdvice={recommended:[]}}}
async function loadDoublesHub(){
 if(doublesHubLoading)return;
 doublesHubLoading=true;
 try{
  const [r,t]=await Promise.all([
    get('/api/rankings?kind=doubles&offset=0&limit=100'),
    get('/api/doubles-race')
  ]);
  doublesHubRows=r.rows||[];
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
 return `<div class="section-head"><div><div class="eyebrow">Carrière · semaine ${local.week}</div><h1>Centre de management</h1><div class="muted">Le monde avance même quand tu ne joues pas.</div></div><span class="pill">ATP · Top 200 exacts au 01/12/2025</span></div>
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
  <div class="card click" onclick="openTournament(${next?.id||0})"><div class="eyebrow">Prochain événement</div>${next?`<h2>${esc(next.name)}</h2><div class="row"><span class="badge ${circuitClass(next.circuit)}">${esc(next.category||next.level)}</span><span class="badge ${surfaceClass(next.surface)}">${esc(next.surface)}</span></div><p class="muted">${esc(next.city||'')} · ${df(next.start_date)}</p>`:'<div class="empty">Aucun événement</div>'}</div>
  <div class="card"><div class="row between"><h2>Fil manager</h2><button class="ghost" onclick="nav('inbox')">Tout voir</button></div>${msgs.map(m=>`<div class="news-item">${esc(m)}</div>`).join('')}</div>
 </section>
 <section class="grid g2" style="margin-top:12px">
  <div class="card"><div class="row between"><h2>Objectifs du board</h2><span class="pill">${academy.board_confidence||76}% confiance</span></div>${(boot.board||[]).map(o=>`<div class="list-item"><div class="row between"><b>${esc(o.objective)}</b><span class="mini muted">${o.progress}%</span></div><div class="bar"><i style="width:${o.progress}%"></i></div><div class="mini muted" style="margin-top:5px">${esc(o.target_value||'')} · ${df(o.deadline)}</div></div>`).join('')}</div>
  <div class="card"><div class="row between"><h2>Top mondial</h2><button class="ghost" onclick="nav('rankings')">Classement complet</button></div>${(boot.topPlayers||[]).slice(0,8).map(p=>`<div class="list-item row between click" onclick="openPlayer(${p.id})"><span><b>#${p.ranking}</b> ${flags[p.country]||'🏳️'} ${esc(p.name)}</span><b>${fmt(p.points)}</b></div>`).join('')}</div>
 </section>`
}
function rankings(){
 const kinds=[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['itf','ITF WTT'],['ncaa','NCAA / ITA']];
 if(rankKind==='ncaa')return ncaaRanking();
 const startRow=rankCount?rankOffset+1:0,endRow=Math.min(rankOffset+rankRows.length,rankCount);
 const first=rankRows[0]||{},snap=rankSnapshot(first,rankKind);
 const label=rankKind==='singles'?'ATP Ranking':rankKind==='doubles'?'ATP Doubles':rankKind==='race'?'ATP Race':rankKind==='nextgen'?'Next Gen Race U21':rankKind==='junior'?'ITF Juniors':'ITF World Tennis Tour';
 const reference=rankKind==='singles'
   ?'Top 200 vérifiés au 01/12/2025 · #201–#2000 = continuation de la base, non certifiée à cette date'
   :rankKind==='doubles'
     ?'Top 10 au 01/12/2025 · classement year-end étendu publié le 17/11/2025'
     :rankKind==='race'
       ?'Race finale de qualification ATP Finals 2025'
       :rankKind==='nextgen'
         ?'Race Next Gen 2025 · joueurs nés en 2005 ou après'
       :rankKind==='junior'
         ?'Top 100 garçons · bilan 2025'
         :(snap?'Référence '+df(snap):'Snapshot importé');
 const pill=rankKind==='singles'?'01/12/2025':rankKind==='doubles'?'2025 vérifié':rankKind==='race'?'Race 2025':rankKind==='nextgen'?'Next Gen 2025':rankKind==='junior'?'Junior 2025':(snap?df(snap):label);
 return `<div class="section-head"><div><div class="eyebrow">Base mondiale</div><h1>Classements</h1><div class="muted">Vue inspirée de Live-Tennis : Ranking, Race, Doubles et Next Gen séparés. Les juniors ITF restent un circuit distinct.</div></div><span class="pill">${pill}</span></div>
 <div class="tabs rank-tabs">${kinds.map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}</div>
 ${rankKind==='singles'? `<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Ton classement</div><div class="hero-name" style="font-size:25px">ATP #${career().singles_rank}</div><div class="muted">${fmt(career().points)} points actifs</div></div><div style="text-align:right"><div class="muted mini">Prochaine expiration</div><b>${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?df(rankingLedger.active[0].expiry_date):'—'}</b><div class="muted mini">${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?'-'+rankingLedger.active[0].points+' pts':''}</div></div></div></div>`:''}
 <div class="card">
  <div class="rank-tools"><input class="input" value="${esc(rankQuery)}" placeholder="Rechercher un joueur…" onkeydown="if(event.key==='Enter')searchRanking(this.value)"><div class="rank-jump"><input class="input" id="rankJump" type="number" min="1" max="${Math.max(rankCount,1)}" placeholder="Aller au rang"><button class="soft-btn" onclick="jumpRanking()">Aller</button></div></div>
  <div class="notice mini" style="margin-top:10px"><b>${label}</b> · ${reference}. Les valeurs de simulation restent séparées des snapshots historiques.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Âge</th><th>Pays</th><th>Pts</th><th>${rankKind==='nextgen'?'ATP':'Niv.'}</th><th>${rankKind==='nextgen'?'Statut':'Pot.'}</th></tr></thead><tbody>
  ${rankRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">#${fmt(rankValue(p,rankKind))}</td><td><b>${esc(p.name)}</b><div class="muted micro">${rankSnapshot(p,rankKind)?'au '+df(rankSnapshot(p,rankKind)):''}</div></td><td>${rankAge(p,rankKind)}</td><td>${flags[p.country]||'🏳️'} ${esc(p.country)}</td><td><b>${rankPoints(p,rankKind)==null?'—':fmt(rankPoints(p,rankKind))}</b></td><td>${rankKind==='nextgen'?(p.ranking?'#'+fmt(p.ranking):'—'):p.current_ability+'/100'}</td><td>${rankKind==='nextgen'?(p.nextgen_status==='withdrawn'?'<span class="badge bad">Retiré</span>':p.nextgen_status==='alternate'?'<span class="badge warn">Alternate</span>':p.nextgen_status==='qualified'?'<span class="badge good">Qualifié</span>':p.potential+'/100'):p.potential+'/100'}</td></tr>`).join('')}
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
 const rows=management?.college||[];
 return `<div class="section-head"><div><div class="eyebrow">NCAA / ITA</div><h1>Classement universitaire</h1><div class="muted">Vue équipe actuellement disponible.</div></div></div>
 <div class="tabs rank-tabs">${[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['itf','ITF WTT'],['ncaa','NCAA / ITA']].map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}</div>
 <div class="card"><table class="table" style="min-width:0"><thead><tr><th>#</th><th>Université</th><th>Bilan</th></tr></thead><tbody>${rows.map(x=>`<tr><td class="rank-num">#${x.ita_rank}</td><td><b>${esc(x.name)}</b></td><td>${esc(x.record)}</td></tr>`).join('')}</tbody></table></div>`
}
window.setRankKind=async k=>{rankKind=k;rankOffset=0;rankQuery='';if(k!=='ncaa')await loadRankings();render()}
window.searchRanking=async q=>{rankQuery=q.trim();rankOffset=0;await loadRankings();render()}
window.rankPage=async d=>{rankOffset=Math.max(0,rankOffset+d*100);await loadRankings();render();window.scrollTo(0,0)}
window.jumpRank=async()=>{const n=clamp(Number(document.getElementById('rankJump')?.value||1),1,2000);rankOffset=Math.floor((n-1)/100)*100;await loadRankings();render();window.scrollTo(0,0)}
function calendar(){
 const cats=['Toutes','Grand Chelem','Masters 1000','ATP 500','ATP 250','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','J300','J200','J100','J60','J30','Junior Finals','NCAA','Junior','Davis Cup'];
 const circs=['Tous','ATP','Challenger','ITF','NCAA','Junior','Federation'];
 return `<div class="section-head"><div><div class="eyebrow">Planification</div><h1>Calendrier mondial</h1><div class="muted">ATP, Challenger, ITF, NCAA, Junior et fédérations sont des circuits / catégories d'événements.</div></div><span class="pill">${fmt(tourCount)} événements</span></div>
 <div class="filters"><input class="input" placeholder="Rechercher un tournoi…" value="${esc(tourFilters.q)}" onchange="tourFilter('q',this.value)"><select class="select" onchange="tourFilter('circuit',this.value)">${circs.map(x=>`<option ${x===tourFilters.circuit?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('category',this.value)">${cats.map(x=>`<option ${x===tourFilters.category?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('source',this.value)">${['Tous','Officiel','Simulation'].map(x=>`<option ${x===tourFilters.source?'selected':''}>${x}</option>`).join('')}</select><input class="input" type="month" value="${tourFilters.month}" onchange="tourFilter('month',this.value)"></div>
 <div class="section-head" style="margin-top:14px"><div><div class="eyebrow">Conseiller calendrier</div><h2>Recommandé pour ton joueur</h2><div class="muted">Score basé sur cut, fatigue, voyage, surface et niveau.</div></div><button class="ghost" onclick="loadScheduleAdvice().then(render)">Actualiser</button></div>
 <div class="grid g3">${(scheduleAdvice?.recommended||[]).slice(0,6).map(t=>`<div class="card click" onclick="openTournament(${t.id})"><div class="row between"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span><b>${t.recommendation_score}/100</b></div><h3>${esc(t.name)}</h3><div class="muted mini">${esc(t.city||'')} · ${df(t.start_date)} · ${esc(t.surface)} · ${t.is_verified?'Officiel':'Simulation'}</div><div class="bar" style="margin-top:9px"><i style="width:${t.recommendation_score}%"></i></div></div>`).join('')||'<div class="card empty">Aucune recommandation.</div>'}</div>
 <div class="stack">${tourRows.map(t=>tournamentCard(t)).join('')||'<div class="card empty">Aucun tournoi pour ces filtres.</div>'}</div>
 <div class="pagination"><button ${tourOffset===0?'disabled':''} onclick="tourPage(-1)">←</button><span class="muted mini">${fmt(tourOffset+1)}–${fmt(Math.min(tourOffset+tourRows.length,tourCount))} / ${fmt(tourCount)}</span><button ${tourOffset+60>=tourCount?'disabled':''} onclick="tourPage(1)">→</button></div>`
}
function tournamentCard(t){
 const c=career(),elig=t.direct_cut==null?'Règles spéciales':c.singles_rank<=t.direct_cut?'Tableau direct':c.singles_rank<=t.qual_cut?'Qualifications':'Alternate / hors cut';
 const joined=(local.entries||[]).includes(t.id);
 return `<div class="card click" onclick="openTournament(${t.id})"><div class="row between"><div><div class="row"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span>${t.is_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Monde simulé</span>'}</div><h2 style="margin:8px 0 4px">${flags[t.country]||'🏳️'} ${esc(t.name)}</h2><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} · <span class="${surfaceClass(t.surface)}">${esc(t.surface)}</span></div></div><div style="text-align:right"><span class="badge ${elig==='Tableau direct'?'good':elig==='Qualifications'?'warn':''}">${elig}</span><div style="margin-top:8px"><button class="${joined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleEntry(${t.id})">${joined?'Inscrit · retirer':'S’inscrire'}</button></div></div></div></div>`
}
window.tourFilter=async(k,v)=>{tourFilters[k]=v;tourOffset=0;await loadTournaments();render()}
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
 const items=[['players','Base joueurs','Classement ATP jusqu’au #2000'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Réseau et prospects'],['staff','Staff','Coach, fitness, physio, agent'],['contracts','Contrats','Salaires et échéances'],['finance','Finances','Budget et dépenses'],['medical','Médical','Blessures, fatigue, récupération'],['match','Match Center','Historique et données match'],['tactics','Tactique','Plan de match & coaching'],['fantasy','Fantasy Court','Créer un tournoi personnalisé'],['doubles','Double','Partenaires et compatibilité'],['university','Universitaire','NCAA / ITA'],['davis','Coupe Davis','Fédération française'],['board','Board','Objectifs et confiance'],['world','Monde','Circuits et profondeur'],['myplayer','Mon joueur','Identité, style et carrière'],['inbox','Boîte de réception','Décisions et alertes']];
 return `<div class="section-head"><div><div class="eyebrow">Centre manager</div><h1>Tous les modules</h1></div></div><div class="grid g2">${items.map(x=>`<div class="card click" onclick="nav('${x[0]}')"><div class="eyebrow">${x[1]}</div><h2>${x[2]}</h2></div>`).join('')}</div>`
}
function playersPage(){
 rankKind='singles';
 return `<div class="section-head"><div><div class="eyebrow">Database</div><h1>Base joueurs</h1><div class="muted">Clique sur n'importe quel joueur pour ouvrir son dossier.</div></div><button class="primary" onclick="nav('rankings')">Classement ATP</button></div>
 <div class="card"><input class="input" placeholder="Recherche globale…" value="${esc(rankQuery)}" onkeydown="if(event.key==='Enter'){rankKind='singles';searchRanking(this.value);nav('rankings')}"><p class="muted mini" style="margin-top:9px">La recherche couvre le snapshot courant et le fallback identifié jusqu’à la zone ATP #2000.</p></div>
 <div class="grid g3" style="margin-top:12px">${(boot.topPlayers||[]).slice(0,18).map(p=>`<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><b>#${p.ranking}</b><span>${flags[p.country]||'🏳️'}</span></div><h2>${esc(p.name)}</h2><div class="muted">${fmt(p.points)} pts · CA ${p.current_ability} · PA ${p.potential}</div></div>`).join('')}</div>`
}
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
 if(!s)return `<div class="card"><div class="row between"><div><div class="eyebrow">Coaching live</div><h2>Match point par point</h2><div class="muted">Lance une rencontre et modifie tes consignes pendant le match.</div></div><button class="primary" onclick="startLiveMatch()">Démarrer</button></div></div>`;
 const st=s.stats||{a:{},b:{}},done=s.status==='completed';
 const avgA=st.a?.rallies?Math.round((st.a.rally_shots||0)/st.a.rallies):0;
 const avgB=st.b?.rallies?Math.round((st.b.rally_shots||0)/st.b.rallies):0;
 return `<div class="card live-match-card">
  <div class="row between"><div><div class="eyebrow">Match live · ${esc(s.surface)}</div><h2>${esc(s.player_a_name)} vs ${esc(s.player_b_name)}</h2></div><span class="badge ${done?'good':'warn'}">${done?'Terminé':'En cours'}</span></div>
  <div class="live-score">
    <div class="live-player"><span>${s.server_side==='A'?'●':''} ${esc(s.player_a_name)}</span><b>${s.sets_a}</b><b>${s.games_a}</b><strong>${pointLabel(s.points_a,s.points_b,'A')}</strong></div>
    <div class="live-player"><span>${s.server_side==='B'?'●':''} ${esc(s.player_b_name)}</span><b>${s.sets_b}</b><b>${s.games_b}</b><strong>${pointLabel(s.points_a,s.points_b,'B')}</strong></div>
  </div>
  <div class="muted mini" style="margin-top:6px">Sets terminés : ${(s.set_history||[]).map(x=>x[0]+'-'+x[1]).join(' · ')||'aucun'}</div>
  <div class="kpi-strip" style="margin-top:12px">
    <div class="kpi"><span class="muted mini">Points gagnés</span><b>${st.a?.points||0} / ${st.b?.points||0}</b></div>
    <div class="kpi"><span class="muted mini">Winners</span><b>${st.a?.winners||0} / ${st.b?.winners||0}</b></div>
    <div class="kpi"><span class="muted mini">Fautes</span><b>${st.a?.errors||0} / ${st.b?.errors||0}</b></div>
    <div class="kpi"><span class="muted mini">Rallye moyen</span><b>${avgA} / ${avgB}</b></div>
  </div>
  <div class="row" style="margin-top:12px;flex-wrap:wrap">
    ${done?`<button class="ghost" onclick="clearLiveMatch()">Nouveau match</button>`:`
      <button class="primary" onclick="playLivePoint()">Jouer 1 point</button>
      <button class="soft-btn" onclick="simulateLiveGame()">Simuler le jeu</button>
      <button class="soft-btn" onclick="simulateLiveSet()">Simuler le set</button>`}
  </div>
  ${done?`<div class="notice" style="margin-top:10px"><b>${s.winner_side==='A'?esc(s.player_a_name):esc(s.player_b_name)}</b> remporte le match.</div>`:''}
 </div>`;
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
window.startLiveMatch=async()=>{
 try{
  const d=await get('/api/live-match/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({surface:'Dur',tactics:local.tactics||{}})});
  local.liveMatch=d.session;persist();render();
 }catch(e){alert(e.message)}
}
window.playLivePoint=async()=>{
 if(!local.liveMatch)return;
 try{
  const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:local.liveMatch.id,tactics:local.tactics||{}})});
  local.liveMatch=d.session;persist();render();
 }catch(e){alert(e.message)}
}
window.simulateLiveGame=async()=>{
 if(!local.liveMatch||local.liveMatch.status==='completed')return;
 const startGames=(local.liveMatch.games_a||0)+(local.liveMatch.games_b||0);
 for(let i=0;i<24;i++){
  const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:local.liveMatch.id,tactics:local.tactics||{}})});
  local.liveMatch=d.session;
  if(local.liveMatch.status==='completed'||(local.liveMatch.games_a||0)+(local.liveMatch.games_b||0)!==startGames)break;
 }
 persist();render();
}
window.simulateLiveSet=async()=>{
 if(!local.liveMatch||local.liveMatch.status==='completed')return;
 const startSets=(local.liveMatch.sets_a||0)+(local.liveMatch.sets_b||0);
 for(let i=0;i<120;i++){
  const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:local.liveMatch.id,tactics:local.tactics||{}})});
  local.liveMatch=d.session;
  if(local.liveMatch.status==='completed'||(local.liveMatch.sets_a||0)+(local.liveMatch.sets_b||0)!==startSets)break;
 }
 persist();render();
}
window.clearLiveMatch=()=>{delete local.liveMatch;persist();render()}
function doublesPage(){
 const c=career();
 if(!doublesHubRows.length&&!doublesHubLoading)setTimeout(loadDoublesHub,0);
 const pool=doublesHubRows;
 const partner=pool.find(p=>p.id===local.partnerId)
   ||(management?.partnerships||[]).map(x=>x.partner||x.player_b).find(Boolean)
   ||null;
 const candidates=pool.filter(p=>p.name!==c.player_name).slice(0,30);
 const exact=pool.filter(p=>p.doubles_snapshot_date==='2025-12-01').length;
 return `<div class="section-head"><div><div class="eyebrow">Circuit Double</div><h1>Double & partenariats</h1><div class="muted">Classement individuel, Race par équipes et gestion du partenaire, séparés du simple.</div></div><span class="pill">${exact} joueurs datés 01/12/2025</span></div>
 <div class="tabs rank-tabs"><button class="active">Partenariat</button><button onclick="setRankKind('doubles');nav('rankings')">Classement Double</button><button onclick="document.getElementById('dblRace').scrollIntoView({behavior:'smooth'})">Race équipes</button></div>
 <div class="grid g2" style="margin-top:10px">
  <div class="card"><div class="row between"><h2>Partenaire actuel</h2><span class="badge">Ton rang #${fmt(c.doubles_rank)}</span></div>
   ${partner?`<div class="row between click" onclick="openPlayer(${partner.id})"><div><h2>${flags[partner.country]||'🏳️'} ${esc(partner.name)}</h2><div class="muted">Double #${fmt(partner.doubles_ranking)} ${partner.ranking?'· ATP #'+partner.ranking:''}</div><div class="muted mini">${partner.doubles_snapshot_date?'réf. '+df(partner.doubles_snapshot_date):''}</div></div><span class="badge good">Sélectionné</span></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Chimie</span><b>${pairScore(partner,'chem')}%</b></div><div class="kpi"><span class="muted mini">Compatibilité</span><b>${pairScore(partner,'comp')}%</b></div><div class="kpi"><span class="muted mini">Force paire</span><b>${pairScore(partner,'power')}%</b></div></div>`:'<div class="empty">Choisis un spécialiste dans le classement Double.</div>'}
  </div>
  <div class="card"><div class="row between"><h2>Top double vérifié</h2><button class="ghost" onclick="setRankKind('doubles');nav('rankings')">Voir tout</button></div>
   ${pool.slice(0,12).map(p=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>#${p.doubles_ranking} ${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${p.doubles_points==null?'points non publiés dans ce snapshot':fmt(p.doubles_points)+' pts'} · ${df(p.doubles_snapshot_date)}</div></div><button class="soft-btn" onclick="choosePartner(${p.id})">Choisir</button></div>`).join('')||'<div class="loader">Chargement du classement double…</div>'}
  </div>
 </div>
 <div id="dblRace" class="section-head" style="margin-top:18px"><div><div class="eyebrow">ATP Finals</div><h2>Race double par équipes</h2><div class="muted">Classement final de qualification 2025.</div></div></div>
 <div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Équipe</th><th>Points</th><th>Référence</th></tr></thead><tbody>
 ${doublesRaceRows.map(x=>`<tr><td class="rank-num">#${x.rank}</td><td><b>${esc(x.player_one)} / ${esc(x.player_two)}</b></td><td>${fmt(x.points)}</td><td>${df(x.snapshot_date)}</td></tr>`).join('')}
 </tbody></table></div>${!doublesRaceRows.length?'<div class="loader">Chargement de la Race équipes…</div>':''}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Scouting double</div><h2>Spécialistes disponibles</h2></div></div>
 <div class="grid g2">${candidates.slice(0,20).map(p=>`<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">Double #${p.doubles_ranking}</div><h3>${flags[p.country]||'🏳️'} ${esc(p.name)}</h3><div class="muted mini">${p.ranking?'ATP #'+p.ranking+' · ':''}CA ${p.current_ability} · PA ${p.potential}</div></div><button class="primary" onclick="choosePartner(${p.id})">Associer</button></div></div>`).join('')}</div>`
}
function universityPage(){
 const teams=management?.college||[],offers=management?.collegeOffers||[],state=management?.collegeState||{},duals=management?.collegeDuals||[];
 const committed=state.status==='committed';
 return `<div class="section-head"><div><div class="eyebrow">Circuit universitaire</div><h1>NCAA / ITA</h1><div class="muted">Recrutement, bourses, team duals, simple/double, progression académique et passage pro.</div></div><span class="pill">${committed?'Engagé':'Recrutement ouvert'}</span></div>
 <div class="grid g2">
  <div class="card"><h2>Ta situation</h2>${committed?`<div class="hero-name" style="font-size:24px">${esc(state.team?.name||'Université')}</div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Bourse</span><b>${state.scholarship_pct}%</b></div><div class="kpi"><span class="muted mini">Confiance coach</span><b>${state.coach_trust}%</b></div><div class="kpi"><span class="muted mini">Académique</span><b>${state.academic_progress}%</b></div><div class="kpi"><span class="muted mini">Éligibilité</span><b>${state.eligibility_years} ans</b></div></div><p class="muted mini" style="margin-top:10px">Position actuelle : #${state.lineup_position||6} dans le lineup équipe.</p>`:'<div class="empty">Tu n’as pas encore choisi d’université. Compare les offres avant de t’engager.</div>'}</div>
  <div class="card"><h2>Top équipes ITA</h2>${teams.slice(0,10).map(t=>`<div class="list-item row between click" onclick="openCollegeTeam(${t.id})"><div><b>#${t.ita_rank} ${esc(t.name)}</b><div class="muted mini">Bilan ${esc(t.record)}</div></div><span class="badge">Voir</span></div>`).join('')}</div>
 </div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Recrutement</div><h2>Offres de bourse</h2></div></div>
 <div class="grid g2">${offers.map(o=>`<div class="card"><div class="row between"><div><div class="eyebrow">ITA #${o.team?.ita_rank||'—'}</div><h2>${esc(o.team?.name||'Université')}</h2></div><span class="badge ${o.status==='accepted'?'good':o.status==='declined'?'bad':''}">${esc(o.status)}</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Bourse</span><b>${o.scholarship_pct}%</b></div><div class="kpi"><span class="muted mini">Fit sportif</span><b>${o.development_fit}</b></div><div class="kpi"><span class="muted mini">Fit académique</span><b>${o.academic_fit}</b></div><div class="kpi"><span class="muted mini">Rôle</span><b style="font-size:12px">${esc(o.role)}</b></div></div>${!committed&&o.status==='available'?`<button class="primary" style="margin-top:10px" onclick="commitCollege(${o.id})">S’engager</button>`:''}</div>`).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Saison équipe</div><h2>Team duals</h2></div></div>
 <div class="stack">${duals.map(d=>`<div class="card"><div class="row between"><div><div class="eyebrow">${df(d.match_date)}</div><h2>${esc(d.home?.name||'Home')} vs ${esc(d.away?.name||'Away')}</h2></div>${d.status==='completed'?`<div class="big" style="font-size:25px">${d.home_score}-${d.away_score}</div>`:`<button class="primary" onclick="playCollegeDual(${d.id})">Jouer le dual</button>`}</div><div class="muted mini">${d.status==='completed'?'Rencontre terminée':'Lineup simple + double avant la rencontre'}</div></div>`).join('')||'<div class="card empty">Aucun dual programmé.</div>'}</div>`
}
window.openCollegeTeam=id=>{
 const t=(management?.college||[]).find(x=>x.id===id);if(!t)return;
 const offers=(management?.collegeOffers||[]).filter(x=>x.team_id===id);
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Programme NCAA</div><h1>#${t.ita_rank} ${esc(t.name)}</h1><div class="muted">Bilan ${esc(t.record)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><h2>Recrutement</h2>${offers.length?offers.map(o=>`<div class="list-item"><div class="row between"><span>Bourse</span><b>${o.scholarship_pct}%</b></div><div class="muted mini">${esc(o.role)} · fit sportif ${o.development_fit}/100</div></div>`).join(''):'<div class="empty">Pas d’offre active.</div>'}</div></div></div>`;
}
window.commitCollege=async id=>{try{await managerAction('commit_college',id);await refreshManagerState();render()}catch(e){alert(e.message)}}
window.playCollegeDual=async id=>{try{await managerAction('play_college_dual',id);await loadManagement();render()}catch(e){alert(e.message)}}
function davisPage(){
 const f=boot.federation||{},sq=boot.davisSquad||[],ties=management?.davisTies||[];
 const roles=['Simple 1','Simple 2','Double A','Double B','Réserve'];
 const tie=ties[0]||null;
 return `<div class="section-head"><div><div class="eyebrow">Fédération française</div><h1>Coupe Davis</h1><div class="muted">Réputation ${f.reputation||91}/100 · intérêt manager ${f.manager_interest||38}% · capitaine ${esc(f.captain||'À déterminer')}</div></div>${tie&&tie.status!=='completed'?`<button class="primary" onclick="playDavisTie(${tie.id})">Jouer le tie</button>`:''}</div>
 <div class="grid g2"><div class="card"><h2>Prochaine rencontre</h2>${tie?`<div class="big" style="font-size:24px">${tie.home_nation} vs ${tie.away_nation}</div><p class="muted">${df(tie.tie_date)} · ${esc(tie.surface)} · ${esc(tie.stage)}</p>${tie.status==='completed'?`<div class="score-hero">${tie.home_score} - ${tie.away_score}</div><span class="badge ${tie.home_score>tie.away_score?'good':'bad'}">${tie.home_score>tie.away_score?'Victoire France':'Défaite France'}</span>`:`<div class="notice">Objectif : ${esc(f.objective||'Atteindre le Final 8')}</div>`}`:`<div class="empty">Aucun tie programmé.</div>`}
  <div class="list-item"><b>Format</b><div class="muted mini">2 simples J1 · double + reverse singles J2</div></div></div>
 <div class="card"><h2>Sélection France</h2>${sq.map(s=>{const p=s.players;if(!p)return'';const role=local.davisRoles[p.id]||s.role||'Réserve';return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking} · Double #${fmt(p.doubles_ranking||9999)}</div></div><select class="select" style="width:auto" onchange="setDavisRole(${p.id},this.value)">${roles.map(r=>`<option ${r===role?'selected':''}>${r}</option>`).join('')}</select></div>`}).join('')||'<div class="empty">Aucun joueur sélectionné.</div>'}</div></div>
 ${tie?.davis_rubbers?.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Résultats</div><h2>Rubbers</h2></div></div><div class="stack">${tie.davis_rubbers.sort((x,y)=>x.rubber_no-y.rubber_no).map(r=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(r.rubber_type)} · Rubber ${r.rubber_no}</div><h2>${esc(r.home_names)} vs ${esc(r.away_names)}</h2></div><div style="text-align:right"><div class="big" style="font-size:22px">${esc(r.score)}</div><span class="badge ${r.winner_nation==='FRA'?'good':'bad'}">${esc(r.winner_nation)}</span></div></div></div>`).join('')}</div>`:''}`
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
  <div class="kpi click" onclick="nav('players')"><span class="muted mini">Profils totaux</span><b>${fmt(w.playersTotal||5000)}</b></div>
  <div class="kpi click" onclick="setRankKind('singles');nav('rankings')"><span class="muted mini">Classés ATP</span><b>${fmt(w.atpRanked||2000)}</b></div>
  <div class="kpi click" onclick="nav('calendar')"><span class="muted mini">Tournois</span><b>${fmt(w.tournaments||0)}</b></div>
  <div class="kpi"><span class="muted mini">Tournois vérifiés</span><b>${fmt(w.verifiedTournaments||0)}</b></div>
 </div>
 <div class="menu-grid" style="margin-top:14px">
  <div class="menu-card" onclick="setRankKind('singles');nav('rankings')"><div class="menu-icon">🎾</div><strong>ATP</strong><span class="muted">${fmt(w.atpRanked||2000)} joueurs classés</span></div>
  <div class="menu-card" onclick="setRankKind('itf');nav('rankings')"><div class="menu-icon">🌍</div><strong>ITF WTT</strong><span class="muted">${fmt(w.itfPlayers||0)} profils avec rang ITF</span></div>
  <div class="menu-card" onclick="setRankKind('junior');nav('rankings')"><div class="menu-icon">🌱</div><strong>Junior</strong><span class="muted">${fmt(w.juniorPlayers||0)} profils juniors</span></div>
  <div class="menu-card" onclick="nav('university')"><div class="menu-icon">🎓</div><strong>NCAA / ITA</strong><span class="muted">${fmt(w.ncaaTeams||0)} équipes</span></div>
  <div class="menu-card" onclick="nav('scouting')"><div class="menu-icon">🔎</div><strong>Newgens</strong><span class="muted">${fmt(w.gameGenerated||0)} joueurs générés par Court Boss</span></div>
  <div class="menu-card" onclick="nav('calendar')"><div class="menu-icon">📅</div><strong>Compétitions</strong><span class="muted">ATP, Challenger, ITF, Junior, NCAA, Davis</span></div>
 </div>
 <div class="card" style="margin-top:14px"><h2>Comment le monde évolue</h2><p class="muted">À chaque semaine, les tournois arrivés à terme sont simulés, les points bougent, les classements sont recalculés, les joueurs vieillissent, les blessures évoluent et les palmarès se remplissent. À l'intersaison, retraites et newgens maintiennent le vivier mondial.</p></div>`
}
function myPlayerPage(){
 const c=career();
 return `<div class="section-head"><div><div class="eyebrow">Carrière</div><h1>Mon joueur</h1><div class="muted">Personnalise ton joueur géré et suis sa trajectoire.</div></div></div>
 <div class="grid g2"><div class="card"><h2>Identité</h2><label class="mini muted">Nom</label><input class="input" value="${esc(c.player_name)}" onchange="editCareer('player_name',this.value)"><label class="mini muted">Pays</label><input class="input" value="${esc(c.country)}" onchange="editCareer('country',this.value)"><label class="mini muted">Style</label><select class="select" onchange="editCareer('style',this.value)">${['Attaquant polyvalent','Attaquant fond de court','Contreur','All-court','Serveur-volée'].map(s=>`<option ${s===c.style?'selected':''}>${s}</option>`).join('')}</select></div>
 <div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">ATP</span><b>#${fmt(c.singles_rank)}</b></div><div class="statbox"><span class="muted mini">Double</span><b>#${fmt(c.doubles_rank)}</b></div><div class="statbox"><span class="muted mini">CA</span><b>${c.current_ability||56}</b></div><div class="statbox"><span class="muted mini">PA</span><b>${c.potential||82}</b></div></div><div class="list-item row between"><span>Âge</span><input class="input" style="max-width:100px" type="number" value="${c.age||19}" onchange="editCareer('age',Number(this.value))"></div><div class="list-item row between"><span>Taille</span><input class="input" style="max-width:100px" type="number" value="${c.height_cm||184}" onchange="editCareer('height_cm',Number(this.value))"></div><div class="list-item row between"><span>Poids</span><input class="input" style="max-width:100px" type="number" value="${c.weight_kg||78}" onchange="editCareer('weight_kg',Number(this.value))"></div></div></div>`
}
function fantasyPage(){
 const rows=local.fantasy||[];
 return `<div class="section-head"><div><div class="eyebrow">Mode créatif</div><h1>Fantasy Court</h1><div class="muted">Crée ton propre tournoi, surface et format.</div></div><button class="primary" onclick="createFantasy()">Nouveau tournoi</button></div><div class="stack">${rows.map((t,i)=>`<div class="card click" onclick="openFantasy(${i})"><div class="row between"><div><div class="eyebrow">${esc(t.category)}</div><h2>${esc(t.name)}</h2><div class="muted">${esc(t.surface)} · ${t.draw} joueurs</div></div><button class="danger-btn" onclick="event.stopPropagation();deleteFantasy(${i})">Supprimer</button></div></div>`).join('')||'<div class="card empty">Aucun tournoi personnalisé. Crée le premier.</div>'}</div>`
}
function inboxPage(){return `<div class="section-head"><div><div class="eyebrow">Communication</div><h1>Boîte de réception</h1></div></div><div class="stack">${(boot.inbox||[]).map(x=>`<div class="card click" onclick="openInboxItem(${x.id},'${esc(x.action_route||'home')}')"><div class="row between"><div class="eyebrow">${esc(x.kind)}</div><span class="badge ${x.is_read?'':'good'}">${x.is_read?'Lu':'Nouveau'}</span></div><h2>${esc(x.title)}</h2><p class="muted">${esc(x.body)}</p></div>`).join('')}</div>`}
function render(){
 if(!boot)return;
 const views={home,rankings,calendar,academy,more,players:playersPage,training,scouting,staff:staffPage,contracts:contractsPage,finance:financePage,medical:medicalPage,match:matchPage,tactics:tacticsPage,fantasy:fantasyPage,doubles:doublesPage,university:universityPage,davis:davisPage,board:boardPage,world:worldPage,myplayer:myPlayerPage,fantasy:fantasyPage,inbox:inboxPage};
 shell((views[route]||more)());
}
window.openPlayer=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du dossier joueur…</div></div></div>';
 try{
  const d=await get('/api/player?id='+id),p=d.player;if(!p)throw new Error('Joueur introuvable');
  const a=p.player_attributes||{};
  const titleCount=(d.titles||[]).length;
  const slamCount=(d.titles||[]).filter(t=>/Grand Chelem|Grand Slam/i.test(String(t.level||''))).length;
  const mastersCount=(d.titles||[]).filter(t=>/Masters 1000|Masters/i.test(String(t.level||''))).length;
  const hardTitles=(d.titles||[]).filter(t=>/Hard|Dur/i.test(String(t.surface||''))).length;
  const clayTitles=(d.titles||[]).filter(t=>/Clay|Terre/i.test(String(t.surface||''))).length;
  const grassTitles=(d.titles||[]).filter(t=>/Grass|Gazon/i.test(String(t.surface||''))).length;
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
  if(p.ranking!=null)rankBits.push('ATP #'+fmt(p.ranking)+(p.ranking_snapshot_date?' · '+df(p.ranking_snapshot_date):''));
  if(p.doubles_ranking!=null&&p.doubles_source)rankBits.push('Double #'+fmt(p.doubles_ranking)+(p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''));
  if(p.race_ranking!=null&&p.race_source)rankBits.push('Race #'+fmt(p.race_ranking));
  if(p.junior_ranking!=null&&p.junior_source)rankBits.push('Junior #'+fmt(p.junior_ranking)+(p.junior_snapshot_date?' · '+df(p.junior_snapshot_date):''));
  const rankSummary=rankBits.length?rankBits.join(' · '):'Non classé actuellement';
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier joueur</div><h1>${flags[p.country]||'🏳️'} ${esc(p.name)}</h1><div class="muted">${esc(rankSummary)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="tabs" style="margin-top:12px"><button class="active" data-player-tab="profile" onclick="playerSection('profile')">Profil</button><button data-player-tab="attrs" onclick="playerSection('attrs')">Attributs</button><button data-player-tab="development" onclick="playerSection('development')">Développement</button><button data-player-tab="matches" onclick="playerSection('matches')">Matchs</button><button data-player-tab="career" onclick="playerSection('career')">Palmarès</button><button data-player-tab="commercial" onclick="playerSection('commercial')">Commercial</button><button data-player-tab="history" onclick="playerSection('history')">Historique</button></div>
   <div id="playerBody">
    <div class="grid g2"><div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">Âge</span><b>${p.age||'—'}</b></div><div class="statbox"><span class="muted mini">Taille</span><b>${p.height_cm?p.height_cm+' cm':'—'}</b></div><div class="statbox"><span class="muted mini">Main</span><b style="font-size:15px">${esc(p.handedness||'—')}</b></div><div class="statbox"><span class="muted mini">Style</span><b style="font-size:15px">${esc(p.style||'—')}</b></div></div></div><div class="card"><h2>Données historiques</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Titres</span><b>${titleCount}</b></div><div class="kpi"><span class="muted mini">Grand Chelem</span><b>${slamCount}</b></div><div class="kpi"><span class="muted mini">Masters</span><b>${mastersCount}</b></div><div class="kpi"><span class="muted mini">Source</span><b style="font-size:11px">ATP match DB</b></div></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${hardTitles}</span><span class="badge clay">Terre ${clayTitles}</span><span class="badge grass">Gazon ${grassTitles}</span></div></div></div>
    <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Bilan historique</h2>${realMatches?`<div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${fmt(realMatches)}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${fmt(cs.wins||0)}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${fmt(cs.losses||0)}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${realWinPct}%</b></div></div><div class="list-item row between"><span>Dur</span><b>${cs.hard_wins==null||cs.hard_losses==null?'Non renseigné':cs.hard_wins+'-'+cs.hard_losses+' · '+surfacePct(cs.hard_wins,cs.hard_losses)}</b></div><div class="list-item row between"><span>Terre battue</span><b>${cs.clay_wins==null||cs.clay_losses==null?'Non renseigné':cs.clay_wins+'-'+cs.clay_losses+' · '+surfacePct(cs.clay_wins,cs.clay_losses)}</b></div><div class="list-item row between"><span>Gazon</span><b>${cs.grass_wins==null||cs.grass_losses==null?'Non renseigné':cs.grass_wins+'-'+cs.grass_losses+' · '+surfacePct(cs.grass_wins,cs.grass_losses)}</b></div><div class="muted mini" style="margin-top:8px">Source : ${esc(cs.source||'Archives de matchs')} · relevé du ${cs.source_snapshot?df(cs.source_snapshot):'—'}${String(cs.source||'').startsWith('https://')?' · <a href="'+esc(cs.source)+'" target="_blank" rel="noopener noreferrer">Consulter la source</a>':' · Agrégat importé, périmètre non certifié ATP'}</div>`:'<div class="empty">Historique match réel non disponible pour ce joueur.</div>'}</div><div class="card"><h2>Scouting</h2><div class="notice">Les notes 1–20 sont des évaluations de jeu, pas des statistiques officielles ATP.</div><p class="muted mini" style="margin-top:10px">Confiance : ${p.scouting_confidence}% · Source : ${esc(p.data_source||'Court Boss')} ${p.data_snapshot?'· snapshot '+df(p.data_snapshot):''}</p><div class="row" style="margin-top:10px;flex-wrap:wrap"><button class="soft-btn" onclick="toggleShortlist(${p.id})">${(d.shortlist||(local.shortlist||[]).includes(p.id))?'Retirer de la shortlist':'Ajouter à la shortlist'}</button><button class="soft-btn" onclick="addComparePlayerV2(${p.id})">Comparer</button>${p.is_real?`<button class="primary" onclick="startCareerWithPlayer(${p.id},'${esc(p.name).replaceAll("'","&#39;")}')">Gérer ce joueur</button>`:''}</div></div></div>
   </div>
   <template id="attrsTpl"><div class="notice">Les attributs 1–20 décrivent le profil de scouting du jeu. Pour le top mondial, les profils sont corrigés manuellement afin d'éviter des aberrations comme Djokovic à 8/20 sur toutes les surfaces.</div><div class="attr-sections" style="margin-top:12px">${groups.map(g=>`<div class="attr-group"><h3>${g[0]}</h3>${g[1].map(x=>{const v=a[x[1]];return `<div class="attr-row"><div class="row"><span>${x[0]}</span><b class="${attrClass(v)}">${v??'—'}</b></div><div class="bar"><i style="width:${(v??0)*5}%"></i></div></div>`}).join('')}</div>`).join('')}</div></template>
   <template id="developmentTpl"><div class="grid g2"><div class="card"><h2>Développement</h2><div class="row between"><span>Capacité actuelle</span><b>${p.current_ability}/100</b></div><div class="bar"><i style="width:${p.current_ability}%"></i></div><div class="row between" style="margin-top:12px"><span>Potentiel</span><b>${p.potential}/100</b></div><div class="bar"><i style="width:${p.potential}%"></i></div><p class="muted mini" style="margin-top:10px">L'âge, le staff, les installations et la charge de travail influencent la progression.</p></div><div class="card"><h2>Axes à travailler</h2>${Object.entries(a).filter(([k,v])=>k!=='player_id'&&Number.isFinite(Number(v))).sort((x,y)=>Number(x[1])-Number(y[1])).slice(0,5).map(([k,v])=>`<div class="list-item row between"><span>${esc(k.replaceAll('_',' '))}</span><b>${v}/20</b></div>`).join('')}</div></div></template>
   <template id="matchesTpl">${(d.juniorEntries||[]).length?`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Circuit ITF Junior</div><h2>Tournois juniors vérifiés</h2></div><span class="badge">Junior #${p.junior_ranking||'—'}</span></div>${(d.juniorEntries||[]).map(e=>{const t=Array.isArray(e.tournaments)?e.tournaments[0]:e.tournaments;return `<div class="list-item row between"><div><b>${esc(t?.name||'Tournoi junior')}</b><div class="muted mini">${t?.city?esc(t.city)+' · ':''}${t?.start_date?df(t.start_date):''} · ${esc(t?.category||'Junior')} · ${esc(t?.surface||'')}</div></div><div style="text-align:right"><b>${esc(e.result||'Engagé')}</b><div class="muted mini">${e.seed?'TDS '+esc(e.seed):''}</div></div></div>`}).join('')}</div>`:''}<div class="grid g2"><div class="card"><h2>Historique importé</h2>${realMatches?`<div class="big">${fmt(cs.wins||0)} - ${fmt(cs.losses||0)}</div><div class="muted">${realWinPct}% de victoires · ${fmt(realMatches)} matchs</div><div class="bar" style="margin-top:10px"><i style="width:${realWinPct}%"></i></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${pct(cs.hard_wins,cs.hard_losses)}%</span><span class="badge clay">Terre ${pct(cs.clay_wins,cs.clay_losses)}%</span><span class="badge grass">Gazon ${pct(cs.grass_wins,cs.grass_losses)}%</span></div>`:'<div class="empty">Pas de données historiques.</div>'}</div><div class="card"><h2>Bilan dans la sauvegarde</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${(d.matches||[]).length}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${(d.matches||[]).filter(m=>m.winner_id===p.id).length}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${(d.matches||[]).filter(m=>m.winner_id!==p.id).length}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${(d.matches||[]).length?Math.round((d.matches||[]).filter(m=>m.winner_id===p.id).length/(d.matches||[]).length*100):0}%</b></div></div></div><div class="card"><h2>Forme actuelle</h2><div class="row between"><span>Forme</span><b>${p.form}/100</b></div><div class="bar"><i style="width:${p.form}%"></i></div><div class="row between" style="margin-top:10px"><span>Fitness</span><b>${p.fitness}/100</b></div><div class="bar"><i style="width:${p.fitness}%"></i></div></div></div><div class="card" style="margin-top:12px"><h2>Historique des matchs</h2>${(d.matches||[]).length?(d.matches||[]).map(m=>{const oppId=m.player_a_id===p.id?m.player_b_id:m.player_a_id;const opp=m.player_a_id===p.id?m.player_b_name:m.player_a_name;const won=m.winner_id===p.id;const tour=m.tournament_runs?.tournaments;return `<div class="list-item row between"><div class="click" onclick="openPlayer(${oppId})"><div><b class="${won?'good':'bad'}">${won?'V':'D'}</b> vs ${esc(opp)}</div><div class="muted mini">${esc(tour?.name||'Tournoi')} · ${esc(m.round_name)} · ${esc(tour?.surface||'')}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="muted mini">${df(tour?.start_date)}</div></div></div>`}).join(''):'<div class="empty">Aucun match simulé pour ce joueur dans cette sauvegarde.</div>'}</div></template>
   <template id="careerTpl">${window.renderPalmaresHtml?window.renderPalmaresHtml(d,p):'<div class="card empty">Module palmarès indisponible.</div>'}</template>
   <template id="commercialTpl"><div class="card"><h2>Sponsors vérifiés</h2>${d.sponsors.filter(s=>s.verified).length?d.sponsors.filter(s=>s.verified).map(s=>`<span class="badge good" style="margin:4px">${esc(s.sponsor)}</span>`).join(''):'<div class="empty">Non vérifié</div>'}<p class="muted mini" style="margin-top:10px">Aucune marque n'est inventée quand la donnée n'est pas vérifiée.</p></div></template>
   <template id="historyTpl"><div class="card"><h2>Historique de classement</h2>${d.history.length?d.history.map(h=>`<div class="list-item row between"><span>${df(h.snapshot_date)}</span><b>#${h.ranking} · ${fmt(h.points)} pts</b></div>`).join(''):'<div class="empty">Pas encore assez de snapshots.</div>'}</div></template>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur</h2><p>${esc(e.message)}</p></div></div>`}
}
window.playerSection=s=>{const body=document.getElementById('playerBody');if(!body)return;if(!body.dataset.profile)body.dataset.profile=body.innerHTML;const map={attrs:'attrsTpl',development:'developmentTpl',matches:'matchesTpl',career:'careerTpl',commercial:'commercialTpl',history:'historyTpl'};const t=document.getElementById(map[s]);if(s==='profile')body.innerHTML=body.dataset.profile;else if(t)body.innerHTML=t.innerHTML;overlay.querySelectorAll('[data-player-tab]').forEach(b=>{b.classList.toggle('active',b.dataset.playerTab===s);b.setAttribute('aria-selected',String(b.dataset.playerTab===s))});}
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
  const serverRun=d.run||null;
  const played=local.playedTournaments?.[t.id]||(serverRun?{user_round:serverRun.user_round,user_points:serverRun.user_points,user_prize:serverRun.user_prize}:null);
  const pairs=(d.main||[]).slice(0,Math.min(64,t.draw_size||32));
  const forfeits=d.forfeits||[];
  const completedDraw=d.completed_draw||[];
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
   <div class="tabs" style="margin-top:12px"><button class="active" onclick="tourSection('overview')">Vue</button><button onclick="tourSection('draw')">${isJunior?'Engagés':'Tableau'}</button>${!isJunior?'<button onclick="tourSection(\'qual\')">Qualifs</button>':''}<button onclick="tourSection('forfeits')">Forfaits ${forfeits.length}</button>${(completedDraw.length||juniorResults)?`<button onclick="tourSection('results')">Résultats</button>`:''}</div>
   <div id="tourBody">
    <div class="grid g2">
      <div class="card"><h2>${isJunior?'Circuit Junior':'Entrée'}</h2>
        ${isJunior?`<div class="list-item row between"><span>Classement utilisé</span><b>ITF Junior</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`:`<div class="list-item row between"><span>Cut tableau</span><b>${t.direct_cut?'#'+t.direct_cut:'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${t.qual_cut?'#'+t.qual_cut:'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`}
        ${wc&&!isJunior?`<div class="list-item row between"><span>Wild card</span><span class="badge ${wc.status==='accepted'?'good':wc.status==='declined'?'bad':''}">${esc(wc.status)}</span></div>`:''}
        <div class="row" style="margin-top:10px;flex-wrap:wrap">${sourceLink}${!isJunior?`<button class="${joined?'danger-btn':'primary'}" onclick="toggleEntry(${t.id});closeOverlay()">${joined?'Retirer l’inscription':rawElig==='Alternate'?'S’inscrire alternate':'S’inscrire'}</button>${rawElig==='Hors cut'&&!wc?`<button class="soft-btn" onclick="requestWildcard(${t.id})">Demander wild card</button>`:''}${joined&&!played&&canAttempt?`<button class="primary" onclick="playTournament(${t.id})">Jouer / simuler</button>`:''}`:''}</div>
        ${played?`<div class="notice" style="margin-top:10px"><b>Résultat :</b> ${esc(played.user_round)} · +${played.user_points} pts · +${euro(played.user_prize)}</div>`:''}
      </div>
      <div class="card"><h2>Informations</h2><div class="list-item row between"><span>Surface</span><b class="${surfaceClass(t.surface)}">${esc(t.surface)}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw_size||32}</b></div><div class="list-item row between"><span>Catégorie</span><b>${esc(t.category||t.level||'—')}</b></div><div class="list-item row between"><span>Donnée</span><b>${t.is_verified?'Vérifiée':'Simulation'}</b></div></div>
    </div>
   </div>

   <template id="tourOverviewTpl"><div class="grid g2"><div class="card"><h2>${isJunior?'Circuit Junior':'Entrée'}</h2>${isJunior?`<div class="list-item row between"><span>Classement</span><b>ITF Junior</b></div><div class="list-item row between"><span>Engagés connus</span><b>${pairs.length}</b></div>`:`<div class="list-item row between"><span>Cut tableau</span><b>${t.direct_cut?'#'+t.direct_cut:'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${t.qual_cut?'#'+t.qual_cut:'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>`}</div><div class="card"><h2>Format</h2><div class="list-item row between"><span>Tableau</span><b>${t.draw_size||32}</b></div><div class="list-item row between"><span>Surface</span><b>${esc(t.surface)}</b></div><div class="list-item row between"><span>Référence</span><b>${t.is_verified?'Officielle':'Simulation'}</b></div></div></div></template>

   <template id="tourDrawTpl"><div class="card"><h2>${isJunior?'Engagés juniors':'Liste d’acceptation / tableau projeté'}</h2><p class="muted mini">${drawIntro}</p><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Points</th><th>${isJunior?'Seed / résultat':'Forme'}</th></tr></thead><tbody>${pairs.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${p.ranking||'—'}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.points==null?'—':fmt(p.points)}</td><td>${isJunior?esc([p.seed?'TDS '+p.seed:'',p.result||''].filter(Boolean).join(' · ')||'Engagé'):(p.form??'—')}</td></tr>`).join('')}</tbody></table></div></div></template>

   <template id="tourQualTpl"><div class="card"><h2>Qualifications</h2><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Condition</th></tr></thead><tbody>${(d.qualifying||[]).map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${p.ranking}</td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.fitness}% / fatigue ${p.fatigue}%</td></tr>`).join('')}</tbody></table></div></div></template>

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
window.tourSection=s=>{const m={overview:'tourOverviewTpl',draw:'tourDrawTpl',qual:'tourQualTpl',forfeits:'tourForfeitsTpl',results:'tourResultsTpl'},t=document.getElementById(m[s]);if(t)document.getElementById('tourBody').innerHTML=t.innerHTML}

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
window.openFantasy=i=>{const t=local.fantasy[i];if(!t)return;overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Fantasy Court</div><h1>${esc(t.name)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Surface</span><b>${esc(t.surface)}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw} joueurs</b></div></div></div></div>`}
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
  const sim=await get('/api/simulate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({week:nextWeek,date:nextDate,career_state:{form:cr.form,fitness:cr.fitness,morale:cr.morale,fatigue:cr.fatigue,injury_status:cr.injury_status},training:local.training})});
  local.date=nextDate;local.week=nextWeek;local.career=cr;local.scoutingBoost=Math.min(50,(local.scoutingBoost||0)+4);
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
  if(boot.career)local.career={...cr,...boot.career};
  await Promise.all([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice()]);
 }catch(e){alert('Simulation incomplète : '+e.message)}
 finally{simulating=false;render()}
}
window.openGlobalSearch=()=>{
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Recherche globale</div><h1>Joueurs</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><input id="globalSearchInput" class="input" style="margin-top:12px" placeholder="Sinner, Fils, Djokovic…" oninput="runGlobalSearch(this.value)" autofocus><div id="globalSearchResults" class="stack" style="margin-top:12px"><div class="empty">Tape au moins 2 caractères.</div></div></div></div>`;
 setTimeout(()=>document.getElementById('globalSearchInput')?.focus(),20);
}
window.runGlobalSearch=async q=>{
 const box=document.getElementById('globalSearchResults');if(!box)return;
 if(q.trim().length<2){box.innerHTML='<div class="empty">Tape au moins 2 caractères.</div>';return}
 try{const d=await get('/api/rankings?kind=singles&offset=0&limit=30&q='+encodeURIComponent(q.trim()));box.innerHTML=d.rows.map(p=>`<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><div><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking} · ${fmt(p.points)} pts</div></div><span class="badge">Profil</span></div></div>`).join('')||'<div class="empty">Aucun joueur trouvé.</div>'}catch(e){box.innerHTML=`<div class="empty">${esc(e.message)}</div>`}
}

init();