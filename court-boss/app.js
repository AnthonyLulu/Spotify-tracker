const API='https://qrsvliliezbiedmaewml.supabase.co/functions/v1/court-boss';
const app=document.getElementById('app'),overlay=document.getElementById('overlay');
const flags={FRA:'🇫🇷',ITA:'🇮🇹',GER:'🇩🇪',ESP:'🇪🇸',USA:'🇺🇸',CAN:'🇨🇦',RUS:'🇷🇺',AUS:'🇦🇺',SRB:'🇷🇸',NOR:'🇳🇴',CZE:'🇨🇿',ARG:'🇦🇷',BRA:'🇧🇷',GBR:'🇬🇧',NED:'🇳🇱',BEL:'🇧🇪',SUI:'🇨🇭',AUT:'🇦🇹',JPN:'🇯🇵',KOR:'🇰🇷',CHN:'🇨🇳',MEX:'🇲🇽',POR:'🇵🇹',POL:'🇵🇱',GRE:'🇬🇷',DEN:'🇩🇰',MON:'🇲🇨',TUN:'🇹🇳'};
const saveKey=(()=>{let k=localStorage.getItem('courtBossSaveKey');if(!k){k=crypto.randomUUID();localStorage.setItem('courtBossSaveKey',k)}return k})();
const fmt=n=>new Intl.NumberFormat('fr-FR').format(Math.round(Number(n)||0));
const euro=n=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(Number(n)||0);
const df=s=>s?new Date(s+'T12:00:00').toLocaleDateString('fr-FR',{day:'2-digit',month:'short',year:'numeric'}):'—';
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const get=async(path,opts={})=>{const r=await fetch(API+path,{...opts,headers:{'X-Save-Key':saveKey,...(opts.headers||{})}});if(!r.ok)throw new Error(await r.text());return r.json()};
let boot=null,route='home',rankKind='singles',rankOffset=0,rankRows=[],rankCount=0,rankQuery='',tourOffset=0,tourRows=[],tourCount=0,tourFilters={circuit:'Tous',category:'Toutes',month:'',q:''},management=null;
let local={date:'2026-09-27',week:1,training:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'],entries:[],shortlist:[],career:null,feed:[],scoutingBoost:0,partnerId:null,davisRoles:{},fantasy:[],tactics:{aggression:58,risk:52,net:28,returnPos:'Neutre'}};
try{Object.assign(local,JSON.parse(localStorage.getItem('cbLocal')||'{}'))}catch{}
function persist(){localStorage.setItem('cbLocal',JSON.stringify(local));fetch(API+'/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Save-Key':saveKey},body:JSON.stringify(local)}).catch(()=>{})}
function surfaceClass(s){return s==='Terre'?'surface-clay':s==='Gazon'?'surface-grass':'surface-hard'}
function circuitClass(c){return c==='Challenger'?'tag-challenger':c==='ITF'?'tag-itf':c==='NCAA'?'tag-ncaa':c==='Junior'?'tag-junior':c==='Federation'?'tag-fed':'tag-atp'}
function rankValue(p,k){return k==='doubles'?p.doubles_ranking:k==='itf'?p.itf_ranking:p.ranking}
function attrClass(v){return v>=18?'a-elite':v>=15?'a-good':v<=8?'a-low':'a-mid'}
function header(){
 const c=local.career||boot?.career||{};
 return `<header class="topbar"><div class="logo">COURT <b>BOSS</b></div><span class="top-date">${df(local.date||c.career_date)}</span><div class="grow"></div><button class="ghost" onclick="nav('inbox')">Boîte <span class="badge">${boot?.inbox?.filter(x=>!x.is_read).length||0}</span></button><button class="primary" onclick="simulateWeek()">+ 1 semaine</button></header>`
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
   if(!local.career)local.career={...(boot.career||{})};
   if(!local.date)local.date=boot.career?.career_date||'2026-09-27';
   localStorage.setItem('cbLocal',JSON.stringify(local));
   await Promise.all([loadManagement(),loadRankings(),loadTournaments()]);
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
 Object.entries(tourFilters).forEach(([k,v])=>{if(v&&v!=='Tous'&&v!=='Toutes')p.set(k,v)});
 const d=await get('/api/tournaments?'+p.toString());tourRows=d.rows;tourCount=d.count;
}
function career(){
 const c={...(boot?.career||{}),...(local.career||{})};
 c.singles_rank=c.singles_rank||742;c.doubles_rank=c.doubles_rank||1284;c.points=c.points||34;c.player_name=c.player_name||'Anthony';c.country=c.country||'FRA';
 return c;
}
function home(){
 const c=career(),next=boot.upcoming?.[0],academy=boot.academy||{},fin=boot.finance||{};
 const msgs=[...(local.feed||[]),...(boot.news||[]).map(x=>x.body)].slice(0,6);
 return `<div class="section-head"><div><div class="eyebrow">Carrière · semaine ${local.week}</div><h1>Centre de management</h1><div class="muted">Le monde avance même quand tu ne joues pas.</div></div><span class="pill">${fmt(boot?.topPlayers?.length?2000:0)} joueurs classés</span></div>
 <section class="hero">
  <div class="card">
   <div class="row between"><div><div class="eyebrow">Joueur géré</div><div class="hero-name">${flags[c.country]||'🏳️'} ${esc(c.player_name)}</div><div class="muted">ATP #${fmt(c.singles_rank)} · Double #${fmt(c.doubles_rank)} · ${fmt(c.points)} pts</div></div><div class="progress-ring" style="--p:${c.form||72}"><b>${c.form||72}</b></div></div>
   <div class="kpi-strip" style="margin-top:14px">
    ${[['Forme',c.form||72],['Fitness',c.fitness||91],['Moral',c.morale||78],['Fatigue',c.fatigue||18]].map(x=>`<div class="kpi"><span class="muted mini">${x[0]}</span><b>${x[1]}</b><div class="bar"><i style="width:${x[1]}%"></i></div></div>`).join('')}
   </div>
  </div>
  <div class="card click" onclick="nav('finance')"><div class="eyebrow">Académie</div><h2>${esc(academy.name||'Court Boss Academy')}</h2><div class="statline"><div class="statbox"><span class="muted mini">Budget</span><b>${euro(c.budget??academy.budget??14800)}</b></div><div class="statbox"><span class="muted mini">Board</span><b>${academy.board_confidence||76}%</b></div></div><p class="muted mini" style="margin-top:10px">${esc(academy.philosophy||'Développement complet du joueur')}</p></div>
 </section>
 <div class="quick-grid" style="margin-top:12px">
  ${[['calendar','Calendrier','Inscrire le joueur'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Chercher des talents'],['match','Match Center','Analyser les matchs'],['tactics','Tactique','Plan de match'],['contracts','Contrats','Staff & joueurs'],['medical','Médical','Fatigue & blessures'],['davis','Fédération','Coupe Davis'],['world','Monde','2 000 joueurs']].map(x=>`<div class="quick" onclick="nav('${x[0]}')"><span class="muted mini">${x[1]}</span><strong>${x[2]}</strong></div>`).join('')}
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
 const kinds=[['singles','ATP Simple'],['doubles','ATP Double'],['itf','ITF WTT'],['ncaa','NCAA / ITA']];
 if(rankKind==='ncaa')return ncaaRanking();
 const start=rankOffset+1,end=Math.min(rankOffset+rankRows.length,rankCount);
 return `<div class="section-head"><div><div class="eyebrow">Classements mondiaux</div><h1>Classements</h1><div class="muted">Challenger = catégorie de tournoi, jamais un classement.</div></div><span class="pill">${rankKind==='singles'?'Top 2000':'Circuit mondial'}</span></div>
 <div class="tabs">${kinds.map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}</div>
 <div class="card">
  <input class="input" value="${esc(rankQuery)}" placeholder="Rechercher un joueur…" onkeydown="if(event.key==='Enter')searchRanking(this.value)">
  <div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Pays</th><th>Points</th><th>Âge</th><th>Niveau</th><th>Potentiel</th></tr></thead><tbody>
  ${rankRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">#${fmt(rankValue(p,rankKind))}</td><td><b>${esc(p.name)}</b></td><td>${flags[p.country]||'🏳️'} ${esc(p.country)}</td><td>${rankKind==='singles'?fmt(p.points):'—'}</td><td>${p.age||'—'}</td><td>${p.current_ability}/100</td><td>${p.potential}/100</td></tr>`).join('')}
  </tbody></table></div>
  <div class="pagination"><button ${rankOffset===0?'disabled':''} onclick="rankPage(-1)">←</button><span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(rankCount)}</span><button ${rankOffset+100>=rankCount?'disabled':''} onclick="rankPage(1)">→</button><input id="rankJump" class="input" style="max-width:110px;padding:7px 9px" type="number" min="1" max="2000" placeholder="Rang"><button onclick="jumpRank()">Aller</button></div>
 </div>`
}
function ncaaRanking(){
 const rows=management?.college||[];
 return `<div class="section-head"><div><div class="eyebrow">NCAA / ITA</div><h1>Classement universitaire</h1><div class="muted">Vue équipe actuellement disponible.</div></div></div>
 <div class="tabs">${[['singles','ATP Simple'],['doubles','ATP Double'],['itf','ITF WTT'],['ncaa','NCAA / ITA']].map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}</div>
 <div class="card"><table class="table" style="min-width:0"><thead><tr><th>#</th><th>Université</th><th>Bilan</th></tr></thead><tbody>${rows.map(x=>`<tr><td class="rank-num">#${x.ita_rank}</td><td><b>${esc(x.name)}</b></td><td>${esc(x.record)}</td></tr>`).join('')}</tbody></table></div>`
}
window.setRankKind=async k=>{rankKind=k;rankOffset=0;rankQuery='';if(k!=='ncaa')await loadRankings();render()}
window.searchRanking=async q=>{rankQuery=q.trim();rankOffset=0;await loadRankings();render()}
window.rankPage=async d=>{rankOffset=Math.max(0,rankOffset+d*100);await loadRankings();render();window.scrollTo(0,0)}
window.jumpRank=async()=>{const n=clamp(Number(document.getElementById('rankJump')?.value||1),1,2000);rankOffset=Math.floor((n-1)/100)*100;await loadRankings();render();window.scrollTo(0,0)}
function calendar(){
 const cats=['Toutes','Grand Chelem','Masters 1000','ATP 500','ATP 250','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','NCAA','Junior','Davis Cup'];
 const circs=['Tous','ATP','Challenger','ITF','NCAA','Junior','Federation'];
 return `<div class="section-head"><div><div class="eyebrow">Planification</div><h1>Calendrier mondial</h1><div class="muted">ATP, Challenger, ITF, NCAA, Junior et fédérations sont des circuits / catégories d'événements.</div></div><span class="pill">${fmt(tourCount)} événements</span></div>
 <div class="filters"><input class="input" placeholder="Rechercher un tournoi…" value="${esc(tourFilters.q)}" onchange="tourFilter('q',this.value)"><select class="select" onchange="tourFilter('circuit',this.value)">${circs.map(x=>`<option ${x===tourFilters.circuit?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('category',this.value)">${cats.map(x=>`<option ${x===tourFilters.category?'selected':''}>${x}</option>`).join('')}</select><input class="input" type="month" value="${tourFilters.month}" onchange="tourFilter('month',this.value)"></div>
 <div class="stack">${tourRows.map(t=>tournamentCard(t)).join('')||'<div class="card empty">Aucun tournoi pour ces filtres.</div>'}</div>
 <div class="pagination"><button ${tourOffset===0?'disabled':''} onclick="tourPage(-1)">←</button><span class="muted mini">${fmt(tourOffset+1)}–${fmt(Math.min(tourOffset+tourRows.length,tourCount))} / ${fmt(tourCount)}</span><button ${tourOffset+60>=tourCount?'disabled':''} onclick="tourPage(1)">→</button></div>`
}
function tournamentCard(t){
 const c=career(),elig=t.direct_cut==null?'Règles spéciales':c.singles_rank<=t.direct_cut?'Tableau direct':c.singles_rank<=t.qual_cut?'Qualifications':'Alternate / hors cut';
 const joined=(local.entries||[]).includes(t.id);
 return `<div class="card click" onclick="openTournament(${t.id})"><div class="row between"><div><div class="row"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span>${!t.is_verified?'<span class="badge">Simulation</span>':''}</div><h2 style="margin:8px 0 4px">${flags[t.country]||'🏳️'} ${esc(t.name)}</h2><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} · <span class="${surfaceClass(t.surface)}">${esc(t.surface)}</span></div></div><div style="text-align:right"><span class="badge ${elig==='Tableau direct'?'good':elig==='Qualifications'?'warn':''}">${elig}</span><div style="margin-top:8px"><button class="${joined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleEntry(${t.id})">${joined?'Retirer':'Inscrire'}</button></div></div></div></div>`
}
window.tourFilter=async(k,v)=>{tourFilters[k]=v;tourOffset=0;await loadTournaments();render()}
window.tourPage=async d=>{tourOffset=Math.max(0,tourOffset+d*60);await loadTournaments();render();window.scrollTo(0,0)}
window.toggleEntry=id=>{local.entries=local.entries||[];local.entries=local.entries.includes(id)?local.entries.filter(x=>x!==id):[...local.entries,id];persist();render()}
function academy(){
 const a=boot.academy||{},c=career();
 return `<div class="section-head"><div><div class="eyebrow">Structure</div><h1>${esc(a.name||'Court Boss Academy')}</h1><div class="muted">Réputation ${a.reputation||48}/100 · Board ${a.board_confidence||76}%</div></div><button class="primary" onclick="nav('board')">Voir le board</button></div>
 <div class="kpi-strip"><div class="kpi click" onclick="nav('finance')"><span class="muted mini">Budget</span><b>${euro(c.budget??a.budget)}</b></div><div class="kpi click" onclick="nav('scouting')"><span class="muted mini">Scouting</span><b>Niv. ${a.scouting_network||2}</b></div><div class="kpi click" onclick="nav('medical')"><span class="muted mini">Médical</span><b>Niv. ${a.medical_level||1}</b></div><div class="kpi"><span class="muted mini">Marketing</span><b>Niv. ${a.marketing||1}</b></div></div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><div class="row between"><h2>Effectif</h2><button class="ghost" onclick="nav('players')">Base joueurs</button></div><div class="list-item row between"><span>${flags.FRA} Anthony</span><b>ATP #${c.singles_rank}</b></div></div>
  <div class="card"><div class="row between"><h2>Prospects académie</h2><button class="ghost" onclick="nav('scouting')">Scouting</button></div>${(boot.youth||[]).map(y=>`<div class="list-item row between"><div><b>${flags[y.country]||'🏳️'} ${esc(y.name)}</b><div class="muted mini">${y.age} ans · ${esc(y.style||'')}</div></div><div><b>PA ${y.potential}</b><div class="muted mini">CA ${y.current_ability}</div></div></div>`).join('')}</div>
 </div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Installations</h2>${(boot.facilities||[]).map(f=>`<div class="list-item row between"><span>${esc(f.name)}</span><b>Niveau ${f.level}/5</b></div>`).join('')}</div>
  <div class="card"><h2>Objectifs du board</h2>${(boot.board||[]).map(o=>`<div class="list-item"><div class="row between"><b>${esc(o.objective)}</b><span>${o.progress}%</span></div><div class="bar"><i style="width:${o.progress}%"></i></div></div>`).join('')}</div>
 </div>`
}
function training(){
 const sessions=['Service','Retour','Coup droit','Revers','Déplacements','Endurance','Match play','Double','Récupération','Repos'];
 return `<div class="section-head"><div><div class="eyebrow">Performance</div><h1>Entraînement hebdomadaire</h1><div class="muted">La charge influe sur progression, forme, fatigue et risque médical.</div></div></div>
 <div class="card"><div class="stack">${local.training.map((x,i)=>`<div class="list-item row between"><div><b>Jour ${i+1}</b><div class="muted mini">${i<5?'Séance principale':'Week-end'}</div></div><select class="select" style="width:auto" onchange="setTraining(${i},this.value)">${sessions.map(s=>`<option ${s===x?'selected':''}>${s}</option>`).join('')}</select></div>`).join('')}</div></div>
 <div class="grid g3" style="margin-top:12px"><div class="card"><h3>Charge actuelle</h3><div class="big">${trainingLoad()}</div><div class="muted">/ 14 conseillé</div></div><div class="card"><h3>Risque fatigue</h3><div class="big">${career().fatigue||18}%</div></div><div class="card"><h3>Staff performance</h3><div class="big">${Math.round((boot.staff||[]).reduce((a,x)=>a+x.skill,0)/Math.max(1,(boot.staff||[]).length))}/20</div></div></div>`
}
function trainingLoad(){return local.training.reduce((a,s)=>a+(['Endurance','Match play','Déplacements'].includes(s)?3:['Service','Retour','Coup droit','Revers','Double'].includes(s)?2:s==='Récupération'?0:-1),0)}
window.setTraining=(i,v)=>{local.training[i]=v;persist();render()}
function scouting(){
 return `<div class="section-head"><div><div class="eyebrow">Recrutement</div><h1>Scouting</h1><div class="muted">Affectations régionales, confiance d'observation et profils à suivre.</div></div><button class="primary" onclick="nav('players')">Chercher joueur</button></div>
 <div class="grid g3">${(boot.scouting||[]).map(s=>`<div class="card"><div class="eyebrow">${esc(s.region)}</div><h2>${esc(s.focus)}</h2><div class="muted">${esc(s.scout_name)}</div><div class="bar" style="margin-top:12px"><i style="width:${Math.min(100,s.progress+(local.scoutingBoost||0))}%"></i></div><div class="mini muted" style="margin-top:5px">${Math.min(100,s.progress+(local.scoutingBoost||0))}% du rapport</div></div>`).join('')}</div>
 <div class="card" style="margin-top:12px"><h2>Prospects de l'académie</h2><div class="table-wrap"><table class="table"><thead><tr><th>Joueur</th><th>Âge</th><th>Pays</th><th>CA</th><th>PA</th><th>Style</th><th>Coût</th></tr></thead><tbody>${(boot.youth||[]).map(y=>`<tr><td><b>${esc(y.name)}</b></td><td>${y.age}</td><td>${flags[y.country]||'🏳️'} ${y.country}</td><td>${y.current_ability}</td><td class="a-good"><b>${y.potential}</b></td><td>${esc(y.style||'')}</td><td>${euro(y.scholarship_cost)}</td></tr>`).join('')}</tbody></table></div></div>`
}
function tacticsPage(){
 const t=local.tactics;
 return `<div class="section-head"><div><div class="eyebrow">Plan de match</div><h1>Tactique</h1><div class="muted">Ajuste le style selon l'adversaire et la surface.</div></div></div>
 <div class="grid g2">
  <div class="card"><h2>Intentions</h2>
   <div class="attr-row"><div class="row between"><span>Agressivité</span><b>${t.aggression}</b></div><input type="range" min="0" max="100" value="${t.aggression}" oninput="setTactic('aggression',this.value)"></div>
   <div class="attr-row"><div class="row between"><span>Montées au filet</span><b>${t.net}</b></div><input type="range" min="0" max="100" value="${t.net}" oninput="setTactic('net',this.value)"></div>
   <div class="attr-row"><div class="row between"><span>Position retour</span><b>${t.returnPos}</b></div><input type="range" min="0" max="100" value="${t.returnPos}" oninput="setTactic('returnPos',this.value)"></div>
  </div>
  <div class="card"><h2>Consignes</h2>
   <label class="muted mini">Cible au service</label><select class="select" onchange="setTactic('serveTarget',this.value)">${['Varié','Extérieur','T','Corps'].map(x=>`<option ${x===t.serveTarget?'selected':''}>${x}</option>`).join('')}</select>
   <label class="muted mini" style="display:block;margin-top:10px">Construction des échanges</label><select class="select" onchange="setTactic('rally',this.value)">${['Équilibré','Coup droit','Revers adverse','Court croisé','Long de ligne','Variation'].map(x=>`<option ${x===t.rally?'selected':''}>${x}</option>`).join('')}</select>
   <div class="info" style="margin-top:12px">Ces choix influencent la simulation des matchs d'exhibition et serviront ensuite de base au coaching point par point.</div>
  </div>
 </div>`}
window.setTactic=(k,v)=>{local.tactics[k]=['aggression','net','returnPos'].includes(k)?Number(v):v;persist();if(!['aggression','net','returnPos'].includes(k))render()}
function fantasyPage(){
 const f=local.fantasy;
 return `<div class="section-head"><div><div class="eyebrow">Mode création</div><h1>Fantasy Court</h1><div class="muted">Crée un tournoi personnalisé avec les joueurs de la base.</div></div></div>
 <div class="grid g2"><div class="card"><h2>Nouveau tournoi</h2><input id="fantasyName" class="input" placeholder="Nom du tournoi" value="${esc(f?.name||'Court Boss Masters')}"><select id="fantasySurface" class="select" style="margin-top:8px"><option>Dur</option><option>Terre</option><option>Gazon</option></select><select id="fantasySize" class="select" style="margin-top:8px"><option value="8">8 joueurs</option><option value="16">16 joueurs</option><option value="32">32 joueurs</option></select><button class="primary" style="margin-top:10px" onclick="createFantasy()">Créer / simuler</button></div>
 <div class="card"><h2>Dernier résultat</h2>${f?`<div class="big" style="font-size:22px">${esc(f.name)}</div><p class="muted">${esc(f.surface)} · ${f.size} joueurs</p><div class="notice">Champion : <b>${esc(f.champion)}</b></div>`:'<div class="empty">Aucun tournoi créé.</div>'}</div></div>`}
window.createFantasy=()=>{
 const n=document.getElementById('fantasyName').value.trim()||'Court Boss Masters',surf=document.getElementById('fantasySurface').value,size=Number(document.getElementById('fantasySize').value);
 const pool=(boot.topPlayers||[]).slice(0,size);const weighted=pool.map((p,i)=>({p,score:(p.current_ability||70)+(p.form||70)/10+Math.random()*12-i*.15})).sort((a,b)=>b.score-a.score);
 local.fantasy={name:n,surface:surf,size,champion:weighted[0]?.p?.name||'Anthony'};local.feed.unshift(`Fantasy Court : ${n} remporté par ${local.fantasy.champion}.`);persist();render()
}
function more(){
 const items=[['players','Base joueurs','2 000 joueurs réels classés'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Réseau et prospects'],['staff','Staff','Coach, fitness, physio, agent'],['contracts','Contrats','Salaires et échéances'],['finance','Finances','Budget et dépenses'],['medical','Médical','Blessures, fatigue, récupération'],['match','Match Center','Historique et données match'],['tactics','Tactique','Plan de match & coaching'],['fantasy','Fantasy Court','Créer un tournoi personnalisé'],['doubles','Double','Partenaires et compatibilité'],['university','Universitaire','NCAA / ITA'],['davis','Coupe Davis','Fédération française'],['board','Board','Objectifs et confiance'],['world','Monde','Circuits et profondeur'],['myplayer','Mon joueur','Identité, style et carrière'],['fantasy','Fantasy Court','Créer un tournoi personnalisé'],['inbox','Boîte de réception','Décisions et alertes']];
 return `<div class="section-head"><div><div class="eyebrow">Centre manager</div><h1>Tous les modules</h1></div></div><div class="grid g2">${items.map(x=>`<div class="card click" onclick="nav('${x[0]}')"><div class="eyebrow">${x[1]}</div><h2>${x[2]}</h2></div>`).join('')}</div>`
}
function playersPage(){
 rankKind='singles';
 return `<div class="section-head"><div><div class="eyebrow">Database</div><h1>Base joueurs</h1><div class="muted">Clique sur n'importe quel joueur pour ouvrir son dossier.</div></div><button class="primary" onclick="nav('rankings')">Classement ATP</button></div>
 <div class="card"><input class="input" placeholder="Recherche globale…" value="${esc(rankQuery)}" onkeydown="if(event.key==='Enter'){rankKind='singles';searchRanking(this.value);nav('rankings')}"><p class="muted mini" style="margin-top:9px">La recherche interroge la base réelle jusqu'au rang ATP 2000.</p></div>
 <div class="grid g3" style="margin-top:12px">${(boot.topPlayers||[]).slice(0,18).map(p=>`<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><b>#${p.ranking}</b><span>${flags[p.country]||'🏳️'}</span></div><h2>${esc(p.name)}</h2><div class="muted">${fmt(p.points)} pts · CA ${p.current_ability} · PA ${p.potential}</div></div>`).join('')}</div>`
}
function staffPage(){return `<div class="section-head"><div><div class="eyebrow">Équipe</div><h1>Staff</h1></div></div><div class="grid g2">${(boot.staff||[]).map(s=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(s.role)}</div><h2>${esc(s.role)}</h2></div><div class="progress-ring" style="--p:${s.skill*5}"><b>${s.skill}/20</b></div></div><p class="muted">Coût hebdomadaire : ${euro(s.weekly_cost)}</p></div>`).join('')}</div>`}
function contractsPage(){return `<div class="section-head"><div><div class="eyebrow">Négociations</div><h1>Contrats</h1></div></div><div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>Personne</th><th>Rôle</th><th>Salaire/sem.</th><th>Début</th><th>Fin</th><th>Statut</th></tr></thead><tbody>${(management?.contracts||[]).map(c=>`<tr><td><b>${esc(c.subject_name)}</b></td><td>${esc(c.role||c.subject_type)}</td><td>${euro(c.weekly_salary)}</td><td>${df(c.start_date)}</td><td>${df(c.end_date)}</td><td><span class="badge good">${esc(c.status)}</span></td></tr>`).join('')}</tbody></table></div></div>`}
function financePage(){const c=career(),f=boot.finance||{};return `<div class="section-head"><div><div class="eyebrow">Comptabilité</div><h1>Finances</h1></div></div><div class="kpi-strip"><div class="kpi"><span class="muted mini">Solde</span><b>${euro(c.budget)}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${euro(f.prize_money)}</b></div><div class="kpi"><span class="muted mini">Voyages</span><b>${euro(f.travel_cost)}</b></div><div class="kpi"><span class="muted mini">Staff</span><b>${euro(f.staff_cost)}/sem</b></div></div><div class="card" style="margin-top:12px"><h2>Projection</h2><p class="muted">Le budget baisse chaque semaine avec le staff, les déplacements et les installations. Les résultats et sponsors alimentent les revenus.</p></div>`}
function injuryRisk(){
 const c=career(),load=trainingLoad();
 let r=12+(c.fatigue||18)*.45+(100-(c.fitness||91))*.35+Math.max(0,65-(c.form||72))*.2+Math.max(0,load-9)*4;
 if(local.injuryTreatment==='Prudent')r-=10;if(local.injuryTreatment==='Agressif')r+=8;
 return Math.round(clamp(r,2,95));
}
function medicalPage(){
 const c=career(),inj=boot.injuries||[];
 const risk=clamp(Math.round((c.fatigue||18)*.75+(trainingLoad()*3)),0,100);
 return `<div class="section-head"><div><div class="eyebrow">Centre médical</div><h1>Condition & blessures</h1><div class="muted">Charge, récupération, rechute et disponibilité.</div></div><button class="primary" onclick="applyRecovery()">Semaine récupération</button></div>
 <div class="grid g4"><div class="card"><h3>Fitness</h3><div class="big">${c.fitness||91}%</div><div class="bar"><i style="width:${c.fitness||91}%"></i></div></div><div class="card"><h3>Fatigue</h3><div class="big">${c.fatigue||18}%</div><div class="bar"><i style="width:${c.fatigue||18}%"></i></div></div><div class="card"><h3>Risque</h3><div class="big ${risk>65?'bad':risk>35?'warn':'good'}">${risk}%</div></div><div class="card"><h3>Statut</h3><div class="big" style="font-size:20px">${esc(c.injury_status||'Fit')}</div></div></div>
 <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Dossier blessures</h2>${inj.length?inj.map(i=>`<div class="list-item click" onclick="openInjury(${i.id})"><div class="row between"><b>${esc(i.players?.name||'Joueur')} · ${esc(i.injury_type)}</b><span class="badge ${i.status==='Active'?'bad':'good'}">${esc(i.status)}</span></div><div class="muted mini">Sévérité ${esc(i.severity)} · retour ${df(i.expected_return)} · rechute ${i.aggravation_risk}%</div></div>`).join(''):'<div class="empty">Aucune blessure active enregistrée.</div>'}</div>
 <div class="card"><h2>Protocoles</h2><div class="list-item row between"><span>Repos complet</span><button class="soft-btn" onclick="setRecovery('Repos')">Appliquer</button></div><div class="list-item row between"><span>Récupération active</span><button class="soft-btn" onclick="setRecovery('Récupération')">Appliquer</button></div><div class="list-item row between"><span>Maintien de forme</span><button class="soft-btn" onclick="setRecovery('mix')">Appliquer</button></div><div class="notice" style="margin-top:10px">Une blessure mal gérée augmente le risque d'aggravation et peut impacter la progression sur plusieurs semaines.</div></div></div>`
}
function matchPage(){
 const t=local.tactics||{aggression:58,risk:52,net:28,returnPos:'Neutre'};
 const all=[...(local.practiceMatches||[]),...(boot.matches||[])];
 return `<div class="section-head"><div><div class="eyebrow">Analyse & coaching</div><h1>Match Center</h1><div class="muted">Prépare le plan de jeu, simule et analyse les tendances.</div></div><button class="primary" onclick="simulatePracticeMatch()">Simuler un match</button></div>
 <div class="grid g2"><div class="card"><h2>Plan de jeu</h2>
 <div class="list-item"><div class="row between"><span>Agressivité</span><b>${t.aggression}%</b></div><input class="range" type="range" min="1" max="100" value="${t.aggression}" oninput="setTactic('aggression',this.value)"></div>
 <div class="list-item"><div class="row between"><span>Prise de risque</span><b>${t.risk}%</b></div><input class="range" type="range" min="1" max="100" value="${t.risk}" oninput="setTactic('risk',this.value)"></div>
 <div class="list-item"><div class="row between"><span>Montées au filet</span><b>${t.net}%</b></div><input class="range" type="range" min="1" max="100" value="${t.net}" oninput="setTactic('net',this.value)"></div>
 <div class="list-item row between"><span>Position retour</span><select class="select" style="width:auto" onchange="setTactic('returnPos',this.value)"><option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option><option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option></select></div></div>
 <div class="card"><h2>Lecture tactique</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Intensité</span><b>${Math.round((t.aggression+t.risk)/2)}</b></div><div class="kpi"><span class="muted mini">Jeu avant</span><b>${t.net}</b></div><div class="kpi"><span class="muted mini">Retour</span><b style="font-size:15px">${esc(t.returnPos)}</b></div></div><p class="muted mini" style="margin-top:10px">Le simulateur combine niveau, forme, fatigue, surface et consignes. L'analyse conserve service, rallyes, winners et fautes.</p></div></div>
 <div class="stack" style="margin-top:12px">${all.map((m,idx)=>`<div class="card click" onclick="openMatch(${idx})"><div class="row between"><div><div class="eyebrow">${esc(m.tournament_name||'Match entraînement')} · ${esc(m.round||'Exhibition')}</div><h2>${esc(m.player_a)} vs ${esc(m.player_b)}</h2><div class="muted">${df(m.match_date||local.date)} · <span class="${surfaceClass(m.surface||'Dur')}">${esc(m.surface||'Dur')}</span></div></div><div><div class="big">${esc(m.score||'—')}</div><span class="badge ${m.winner==='Anthony'?'good':'bad'}">${m.winner==='Anthony'?'Victoire':'Défaite'}</span></div></div><div class="kpi-strip" style="margin-top:12px">${Object.entries(m.match_data||{}).slice(0,4).map(([k,v])=>`<div class="kpi"><span class="muted mini">${esc(k.replaceAll('_',' '))}</span><b>${v}</b></div>`).join('')}</div></div>`).join('')||'<div class="card empty">Aucun match enregistré.</div>'}</div>`
}
function doublesPage(){
 const c=career();
 const pool=[...(boot.davisSquad||[]).map(x=>x.players).filter(Boolean),...(boot.topPlayers||[]).filter(p=>p.country==='FRA')];
 const uniq=[...new Map(pool.map(p=>[p.id,p])).values()].filter(p=>p.name!=='Anthony').slice(0,14);
 const partner=uniq.find(p=>p.id===local.partnerId);
 return `<div class="section-head"><div><div class="eyebrow">Double</div><h1>Partenariats</h1><div class="muted">Classement actuel #${fmt(c.doubles_rank)}</div></div></div>
 <div class="grid g2"><div class="card"><h2>Partenaire actuel</h2>${partner?`<div class="row between click" onclick="openPlayer(${partner.id})"><div><h2>${flags[partner.country]||'🏳️'} ${esc(partner.name)}</h2><div class="muted">Double #${fmt(partner.doubles_ranking||9999)} · ${esc(partner.style||'')}</div></div><span class="badge good">Sélectionné</span></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Chimie</span><b>${pairScore(partner,'chem')}%</b></div><div class="kpi"><span class="muted mini">Compatibilité</span><b>${pairScore(partner,'comp')}%</b></div><div class="kpi"><span class="muted mini">Force paire</span><b>${pairScore(partner,'power')}%</b></div></div>`:'<div class="empty">Choisis un partenaire dans la liste.</div>'}</div>
 <div class="card"><h2>Candidats</h2>${uniq.map(p=>`<div class="list-item row between click" onclick="choosePartner(${p.id})"><div><b>${esc(p.name)}</b><div class="muted mini">Double #${fmt(p.doubles_ranking||9999)} · simple #${p.ranking}</div></div><span class="badge">${pairScore(p,'comp')}%</span></div>`).join('')}</div></div>`
}
function universityPage(){return ncaaRanking().replace('<div class="tabs">','<div class="info">Voie universitaire : recrutement, bourses, eligibility, team duals et passage pro.</div><div class="tabs" style="margin-top:12px">')}
function davisPage(){
 const f=boot.federation||{},sq=boot.davisSquad||[];
 const roles=['Simple 1','Simple 2','Double A','Double B','Réserve'];
 return `<div class="section-head"><div><div class="eyebrow">Fédération française</div><h1>Coupe Davis</h1><div class="muted">Réputation ${f.reputation||91}/100 · intérêt manager ${f.manager_interest||38}% · capitaine ${esc(f.captain||'À déterminer')}</div></div></div>
 <div class="grid g2"><div class="card"><h2>Prochaine rencontre</h2><div class="big" style="font-size:24px">${esc(f.next_tie||'France vs Italie')}</div><p class="muted">${esc(f.home_surface||'Dur indoor')}</p><div class="notice">Objectif : ${esc(f.objective||'Atteindre le Final 8')}</div><div class="list-item"><b>Qualifiers</b><div class="muted mini">2 simples J1 · double + reverse singles J2</div></div><div class="list-item"><b>Final 8</b><div class="muted mini">2 simples + double décisif</div></div></div>
 <div class="card"><h2>Sélection France</h2>${sq.map(s=>{const p=s.players;if(!p)return'';const role=local.davisRoles[p.id]||s.role||'Réserve';return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking} · Double #${fmt(p.doubles_ranking||9999)}</div></div><select class="select" style="width:auto" onchange="setDavisRole(${p.id},this.value)">${roles.map(r=>`<option ${r===role?'selected':''}>${r}</option>`).join('')}</select></div>`}).join('')||'<div class="empty">Aucun joueur sélectionné.</div>'}</div></div>`
}
function boardPage(){const a=boot.academy||{};return `<div class="section-head"><div><div class="eyebrow">Direction</div><h1>Board</h1><div class="muted">Confiance : ${a.board_confidence||76}%</div></div></div><div class="stack">${(boot.board||[]).map(o=>`<div class="card"><div class="row between"><div><h2>${esc(o.objective)}</h2><div class="muted">${esc(o.target_value||'')} · échéance ${df(o.deadline)}</div></div><b>${o.progress}%</b></div><div class="bar"><i style="width:${o.progress}%"></i></div></div>`).join('')}</div>`}
function worldPage(){return `<div class="section-head"><div><div class="eyebrow">Écosystème</div><h1>Monde du tennis</h1><div class="muted">La base va jusqu'au rang ATP 2000. Les catégories de tournois sont séparées des classements.</div></div></div><div class="grid g3"><div class="card click" onclick="nav('rankings')"><div class="big">2 000</div><div class="muted">joueurs réels classés</div></div><div class="card click" onclick="nav('calendar')"><div class="big">${fmt(tourCount)}</div><div class="muted">événements en base</div></div><div class="card"><div class="big">6</div><div class="muted">familles de circuits</div></div></div><div class="card" style="margin-top:12px"><h2>Circuits</h2><div class="row" style="flex-wrap:wrap">${['ATP','Challenger','ITF','NCAA','Junior','Federation'].map(c=>`<span class="badge ${circuitClass(c)}">${c}</span>`).join('')}</div></div>`}
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
function inboxPage(){return `<div class="section-head"><div><div class="eyebrow">Communication</div><h1>Boîte de réception</h1></div></div><div class="stack">${(boot.inbox||[]).map(x=>`<div class="card click" onclick="nav('${esc(x.action_route||'home')}')"><div class="eyebrow">${esc(x.kind)}</div><h2>${esc(x.title)}</h2><p class="muted">${esc(x.body)}</p></div>`).join('')}</div>`}
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
  const groups=[
   ['Technique',[['Puissance service','serve_power'],['Précision service','serve_precision'],['Coup droit','forehand'],['Revers','backhand'],['Retour','return_game'],['Volée','volley'],['Toucher','touch']]],
   ['Physique',[['Déplacements','movement'],['Vitesse','speed'],['Endurance','stamina'],['Force','strength']]],
   ['Mental',[['Anticipation','anticipation'],['Concentration','concentration'],['Sang-froid','composure'],['Combativité','fighting_spirit'],['Tactique','tactics']]],
   ['Spécial',[['Double','doubles'],['Terre battue','clay_affinity'],['Dur','hard_affinity'],['Gazon','grass_affinity']]]
  ];
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier joueur</div><h1>${flags[p.country]||'🏳️'} ${esc(p.name)}</h1><div class="muted">ATP #${fmt(p.ranking)} · ${fmt(p.points)} pts · Double #${fmt(p.doubles_ranking||0)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="tabs" style="margin-top:12px"><button class="active">Profil</button><button onclick="playerSection('attrs')">Attributs</button><button onclick="playerSection('career')">Carrière</button><button onclick="playerSection('commercial')">Commercial</button><button onclick="playerSection('history')">Historique</button></div>
   <div id="playerBody">
    <div class="grid g2"><div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">Âge</span><b>${p.age||'—'}</b></div><div class="statbox"><span class="muted mini">Taille</span><b>${p.height_cm?p.height_cm+' cm':'—'}</b></div><div class="statbox"><span class="muted mini">Main</span><b style="font-size:15px">${esc(p.handedness||'—')}</b></div><div class="statbox"><span class="muted mini">Style</span><b style="font-size:15px">${esc(p.style||'—')}</b></div></div></div><div class="card"><h2>Niveau</h2><div class="row between"><span>CA</span><b>${p.current_ability}/100</b></div><div class="bar"><i style="width:${p.current_ability}%"></i></div><div class="row between" style="margin-top:12px"><span>Potentiel</span><b>${p.potential}/100</b></div><div class="bar"><i style="width:${p.potential}%"></i></div></div></div>
    <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Condition</h2>${[['Forme',p.form],['Fitness',p.fitness],['Moral',p.morale],['Fatigue',p.fatigue]].map(x=>`<div class="attr-row"><div class="row between"><span>${x[0]}</span><b>${x[1]}</b></div><div class="bar"><i style="width:${x[1]}%"></i></div></div>`).join('')}</div><div class="card"><h2>Scouting</h2><div class="notice">Les notes 1–20 sont des évaluations de jeu, pas des statistiques officielles ATP.</div><p class="muted mini" style="margin-top:10px">Confiance : ${p.scouting_confidence}% · Source : ${esc(p.data_source||'Court Boss')} ${p.data_snapshot?'· snapshot '+df(p.data_snapshot):''}</p><button class="soft-btn" onclick="toggleShortlist(${p.id})">${d.shortlist?'Retirer de la shortlist':'Ajouter à la shortlist'}</button></div></div>
   </div>
   <template id="attrsTpl"><div class="notice">Les attributs 1–20 décrivent le profil de scouting du jeu. Pour le top mondial, les profils sont corrigés manuellement afin d'éviter des aberrations comme Djokovic à 8/20 sur toutes les surfaces.</div><div class="attr-sections" style="margin-top:12px">${groups.map(g=>`<div class="attr-group"><h3>${g[0]}</h3>${g[1].map(x=>{const v=a[x[1]]??0;return `<div class="attr-row"><div class="row"><span>${x[0]}</span><b class="${attrClass(v)}">${v}</b></div><div class="bar"><i style="width:${v*5}%"></i></div></div>`}).join('')}</div>`).join('')}</div></template>
   <template id="careerTpl"><div class="card"><h2>Palmarès</h2>${d.titles.length?d.titles.map(t=>`<div class="list-item"><b>${esc(t.tournament_name)}</b><div class="muted mini">${df(t.title_date)} · ${esc(t.level||'')} · ${esc(t.surface||'')}</div></div>`).join(''):'<div class="empty">Palmarès détaillé non importé pour ce joueur.</div>'}</div></template>
   <template id="commercialTpl"><div class="card"><h2>Sponsors vérifiés</h2>${d.sponsors.length?d.sponsors.map(s=>`<span class="badge good" style="margin:4px">${esc(s.sponsor)}</span>`).join(''):'<div class="empty">Non vérifié</div>'}<p class="muted mini" style="margin-top:10px">Aucune marque n'est inventée quand la donnée n'est pas vérifiée.</p></div></template>
   <template id="historyTpl"><div class="card"><h2>Historique de classement</h2>${d.history.length?d.history.map(h=>`<div class="list-item row between"><span>${df(h.snapshot_date)}</span><b>#${h.ranking} · ${fmt(h.points)} pts</b></div>`).join(''):'<div class="empty">Pas encore assez de snapshots.</div>'}</div></template>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur</h2><p>${esc(e.message)}</p></div></div>`}
}
window.playerSection=s=>{const map={attrs:'attrsTpl',career:'careerTpl',commercial:'commercialTpl',history:'historyTpl'};const t=document.getElementById(map[s]);if(t)document.getElementById('playerBody').innerHTML=t.innerHTML}
window.closeOverlay=()=>overlay.innerHTML='';
window.toggleShortlist=id=>{local.shortlist=local.shortlist||[];local.shortlist=local.shortlist.includes(id)?local.shortlist.filter(x=>x!==id):[...local.shortlist,id];persist();closeOverlay();render()}
window.openTournament=id=>{
 const t=[...(tourRows||[]),...(boot.upcoming||[])].find(x=>x.id===id);if(!t)return;
 const c=career(),elig=t.direct_cut==null?'Règles spéciales':c.singles_rank<=t.direct_cut?'Tableau direct':c.singles_rank<=t.qual_cut?'Qualifications':'Alternate / hors cut';
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(t.circuit||'Circuit')} · ${esc(t.category||t.level)}</div><h1>${flags[t.country]||'🏳️'} ${esc(t.name)}</h1><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} → ${df(t.end_date)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="grid g2" style="margin-top:12px"><div class="card"><h2>Entrée</h2><div class="list-item row between"><span>Cut tableau</span><b>${t.direct_cut?'#'+t.direct_cut:'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${t.qual_cut?'#'+t.qual_cut:'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div><button class="primary" style="margin-top:10px" onclick="toggleEntry(${t.id});closeOverlay()">${(local.entries||[]).includes(t.id)?'Retirer l’inscription':'S’inscrire'}</button></div><div class="card"><h2>Informations</h2><div class="list-item row between"><span>Surface</span><b class="${surfaceClass(t.surface)}">${esc(t.surface)}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw_size||32}</b></div><div class="list-item row between"><span>Prize money</span><b>${euro(t.prize_money)}</b></div><div class="list-item row between"><span>Donnée</span><b>${t.is_verified?'Vérifiée':'Simulation'}</b></div></div></div></div></div>`
}
window.openInjury=id=>{const i=(boot.injuries||[]).find(x=>x.id===id);if(!i)return;overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier médical</div><h1>${esc(i.injury_type)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Sévérité</span><b>${esc(i.severity)}</b></div><div class="list-item row between"><span>Retour estimé</span><b>${df(i.expected_return)}</b></div><div class="list-item row between"><span>Risque aggravation</span><b>${i.aggravation_risk}%</b></div><div class="list-item"><span class="muted mini">Traitement</span><p>${esc(i.treatment||'Repos et suivi médical')}</p></div></div></div></div>`}
window.setRecovery=mode=>{if(mode==='mix')local.training=['Récupération','Repos','Récupération','Repos','Récupération','Repos','Repos'];else local.training=local.training.map(()=>mode);persist();render()}
window.applyRecovery=()=>setRecovery('mix')
window.setTactic=(k,v)=>{local.tactics=local.tactics||{};local.tactics[k]=['aggression','risk','net'].includes(k)?Number(v):v;persist();render()}
window.simulatePracticeMatch=async()=>{const c=career();let opp={name:'Adversaire ATP',current_ability:55,form:70,fatigue:20};try{const d=await get('/api/rankings?kind=singles&offset='+Math.max(0,(c.singles_rank||742)-3)+'&limit=5');opp=d.rows.find(x=>x.name!=='Anthony')||opp}catch{}const strength=(c.current_ability||56)+(c.form||72)*.18-(c.fatigue||18)*.12+(local.tactics?.aggression||58)*.03;const os=(opp.current_ability||55)+(opp.form||70)*.18-(opp.fatigue||20)*.12;const win=strength>=os+(Math.random()*12-6);const score=win?(Math.random()>.5?'6-4 6-3':'7-6 3-6 6-2'):(Math.random()>.5?'4-6 3-6':'6-4 4-6 3-6');const md={first_serve:58+Math.floor(Math.random()*16)+'%',winners:18+Math.floor(Math.random()*20),unforced_errors:12+Math.floor(Math.random()*18),avg_rally:3+Math.floor(Math.random()*6)};local.practiceMatches=local.practiceMatches||[];local.practiceMatches.unshift({tournament_name:'Match entraînement',round:'Simulation',player_a:'Anthony',player_b:opp.name,winner:win?'Anthony':opp.name,score,surface:'Dur',match_date:local.date,match_data:md});c.fatigue=clamp((c.fatigue||18)+10,0,100);c.form=clamp((c.form||72)+(win?2:-1),0,100);local.career=c;persist();render()}
window.openMatch=idx=>{const all=[...(local.practiceMatches||[]),...(boot.matches||[])],m=all[idx];if(!m)return;overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(m.tournament_name)}</div><h1>${esc(m.player_a)} vs ${esc(m.player_b)}</h1><div class="muted">${esc(m.score||'—')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="grid g2" style="margin-top:12px">${Object.entries(m.match_data||{}).map(([k,v])=>`<div class="card"><div class="muted mini">${esc(k.replaceAll('_',' '))}</div><div class="big">${v}</div></div>`).join('')}</div></div></div>`}
window.pairScore=(p,k)=>{const seed=(Number(p.id||1)*17+(k==='chem'?7:k==='comp'?13:19))%19;return clamp(68+seed,55,94)}
window.choosePartner=id=>{local.partnerId=id;persist();render()}
window.setDavisRole=(id,role)=>{local.davisRoles=local.davisRoles||{};for(const [pid,r] of Object.entries(local.davisRoles)){if(r===role&&role!=='Réserve')delete local.davisRoles[pid]}local.davisRoles[id]=role;persist();render()}
window.editCareer=(k,v)=>{const c=career();c[k]=v;local.career=c;persist();render()}
window.createFantasy=()=>{const name=prompt('Nom du tournoi ?','Court Boss Invitational');if(!name)return;const surface=prompt('Surface ? Dur / Terre / Gazon','Dur')||'Dur';const draw=Number(prompt('Taille du tableau ?','32'))||32;local.fantasy=local.fantasy||[];local.fantasy.push({name,surface,draw,category:'Fantasy'});persist();render()}
window.deleteFantasy=i=>{local.fantasy.splice(i,1);persist();render()}
window.openFantasy=i=>{const t=local.fantasy[i];if(!t)return;overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Fantasy Court</div><h1>${esc(t.name)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Surface</span><b>${esc(t.surface)}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw} joueurs</b></div></div></div></div>`}
window.simulateWeek=()=>{
 const c=career(),load=trainingLoad();
 c.fatigue=clamp((c.fatigue||18)+Math.max(0,load-5)-Math.floor(Math.random()*6),0,100);
 c.fitness=clamp((c.fitness||91)+(load<=10?1:-3),40,100);
 c.form=clamp((c.form||72)+Math.floor(Math.random()*7)-2,35,100);
 c.morale=clamp((c.morale||78)+Math.floor(Math.random()*5)-1,35,100);
 const gain=Math.random()<.62; if(gain){c.singles_rank=Math.max(1,c.singles_rank-(1+Math.floor(Math.random()*12)));c.points=(c.points||34)+4+Math.floor(Math.random()*17);c.budget=(c.budget||14800)+250+Math.floor(Math.random()*900)}else c.singles_rank+=Math.floor(Math.random()*5);
 c.budget=(c.budget||14800)-920;
 if(load>13&&Math.random()>.72){c.injury_status='Gêne musculaire';c.fitness=clamp(c.fitness-9,0,100);local.feed.unshift('Alerte médicale : la charge élevée a provoqué une gêne musculaire.')}else if(c.injury_status&&c.injury_status!=='Fit'&&Math.random()>.45)c.injury_status='Fit';
 const d=new Date((local.date||'2026-09-27')+'T12:00:00');d.setDate(d.getDate()+7);local.date=d.toISOString().slice(0,10);local.week=(local.week||1)+1;local.career=c;local.scoutingBoost=Math.min(50,(local.scoutingBoost||0)+4);local.feed=local.feed||[];local.feed.unshift(`Semaine simulée : Anthony est maintenant ATP #${c.singles_rank} avec ${c.points} points.`);local.feed=local.feed.slice(0,8);persist();render();
}
init();