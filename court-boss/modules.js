
let cbDoublesTournaments=[];
let cbLiveWinProb=50;
let cbPlayerSearch={q:'',country:'',circuit:'Tous',age_max:99,potential_min:0,offset:0,limit:60,rows:[],count:0};
let cbSeasonHistory=[];
let cbMatchOpponents=[];
let cbLiveSession=null;
let cbLiveOpponent=null;
let cbLiveSurface='Dur';
let cbLiveBusy=false;
let cbLiveRestoreError='';
let cbFantasyData={tournaments:[],entries:[],runs:[]};
let cbFantasySearch=[];

async function loadCbDoublesTournaments(){
  try{
    const d=await get('/api/tournaments?offset=0&limit=60&from='+encodeURIComponent(local.date||'2026-09-27'));
    cbDoublesTournaments=(d.rows||[]).filter(t=>t.doubles);
  }catch(e){
    cbDoublesTournaments=[];
  }
}

async function loadCbSeasonHistory(){
  try{
    const d=await get('/api/season-history');
    cbSeasonHistory=d.rows||[];
  }catch(e){
    cbSeasonHistory=[];
  }
}

function seasonPageV2(){
  const s=seasonSummary||{stats:{},singles:[],doubles:[],singles_points:[],doubles_points:[]};
  const st=s.stats||{},cr=career();
  const winPct=st.matches?Math.round((st.wins||0)/st.matches*100):0;
  return `
  <div class="section-head">
    <div>
      <div class="eyebrow">Saison ${String(local.date||'2026').slice(0,4)}</div>
      <h1>Bilan de saison</h1>
      <div class="muted">Résultats, prize money et points 52 semaines.</div>
    </div>
    <div class="row">
      <button class="ghost" onclick="refreshSeasonV2()">Actualiser</button>
      <button class="primary" onclick="rolloverSeasonV2()">Nouvelle saison</button>
    </div>
  </div>

  <div class="kpi-strip">
    <div class="kpi"><span class="muted mini">Classement</span><b>#${cr.singles_rank}</b></div>
    <div class="kpi"><span class="muted mini">Tournois</span><b>${st.tournaments||0}</b></div>
    <div class="kpi"><span class="muted mini">Titres</span><b>${st.titles||0}</b></div>
    <div class="kpi"><span class="muted mini">Prize money</span><b>${euro(st.prize||0)}</b></div>
  </div>

  <div class="grid g2" style="margin-top:12px">
    <div class="card">
      <h2>Bilan matchs</h2>
      <div class="big">${st.wins||0} - ${Math.max(0,(st.matches||0)-(st.wins||0))}</div>
      <div class="muted">${winPct}% de victoires</div>
      <div class="bar" style="margin-top:10px"><i style="width:${winPct}%"></i></div>
    </div>
    <div class="card">
      <h2>Points ATP actifs</h2>
      <div class="big">${fmt(rankingLedger?.total||cr.points)}</div>
      <div class="muted mini">Expiration après 52 semaines.</div>
      ${(rankingLedger?.active||[]).slice(0,5).map(p=>`
        <div class="list-item row between">
          <div><b>${esc(p.label)}</b><div class="muted mini">Expire ${df(p.expiry_date)}</div></div>
          <b>${p.points}</b>
        </div>`).join('')}
    </div>
  </div>

  <div class="section-head" style="margin-top:18px">
    <div><div class="eyebrow">Historique carrière</div><h2>Saisons terminées</h2></div>
  </div>
  <div class="stack">
    ${cbSeasonHistory.map(y=>`
      <div class="card">
        <div class="row between">
          <div><div class="eyebrow">Saison ${y.season_year}</div><h2>ATP #${y.final_rank||'—'} · Double #${y.doubles_rank||'—'}</h2></div>
          <div style="text-align:right"><span class="badge ${y.titles>0?'good':''}">${y.titles} titre(s)</span><div class="muted mini">${euro(y.prize_money)} · ${y.points} pts</div></div>
        </div>
      </div>`).join('')||'<div class="card empty">Aucune saison archivée pour l’instant.</div>'}
  </div>

  <div class="section-head" style="margin-top:18px">
    <div><div class="eyebrow">Simple</div><h2>Tournois joués</h2></div>
  </div>
  <div class="stack">
    ${(s.singles||[]).map(r=>`
      <div class="card click" onclick="openTournament(${r.tournament_id})">
        <div class="row between">
          <div>
            <div class="eyebrow">${df(r.tournaments?.start_date)} · ${esc(r.tournaments?.category||'')}</div>
            <h2>${esc(r.tournaments?.name||'Tournoi')}</h2>
          </div>
          <div style="text-align:right">
            <span class="badge ${r.user_round==='Champion'?'good':''}">${esc(r.user_round)}</span>
            <div class="muted mini">+${r.user_points} pts · ${euro(r.user_prize)}</div>
          </div>
        </div>
      </div>`).join('')||'<div class="card empty">Aucun tournoi simple joué.</div>'}
  </div>

  <div class="section-head" style="margin-top:18px">
    <div><div class="eyebrow">Double</div><h2>Résultats</h2></div>
  </div>
  <div class="stack">
    ${(s.doubles||[]).map(r=>`
      <div class="card">
        <div class="row between">
          <div><b>${esc(r.tournaments?.name||'Tournoi')}</b><div class="muted mini">avec ${esc(r.partner?.name||'partenaire')}</div></div>
          <div style="text-align:right"><span class="badge">${esc(r.user_round)}</span><div class="muted mini">+${r.user_points} pts</div></div>
        </div>
      </div>`).join('')||'<div class="card empty">Aucun double joué.</div>'}
  </div>`;
}

async function refreshSeasonV2(){
  await Promise.all([loadSeasonSummary(),loadRankingLedger(),loadCbSeasonHistory()]);
  shell(seasonPageV2());
}

async function rolloverSeasonV2(){
  const current=Number((boot?.career?.season_year)||String(local.date||'2026').slice(0,4)||2026);
  const next=current+1;
  if(!confirm('Passer à la saison '+next+' ? Les joueurs vieilliront, les points expireront normalement et la saison '+current+' sera archivée.'))return;
  try{
    const d=await get('/api/rollover-season',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({new_year:next})});
    boot=await get('/api/bootstrap');
    if(boot.career)local.career={...(local.career||{}),...boot.career};
    local.date=boot.career?.career_date||String(next)+'-01-05';
    local.week=1;
    await Promise.all([loadSeasonSummary(),loadRankingLedger(),loadScheduleAdvice(),loadCbSeasonHistory(),loadManagement()]);
    persist();
    shell(seasonPageV2());
  }catch(e){
    alert(e.message);
  }
}

function doublesPageV2(){
  const cr=career();
  const pool=[...(boot.davisSquad||[]).map(x=>x.players).filter(Boolean),...(boot.topPlayers||[]).filter(p=>p.country==='FRA')];
  const uniq=[...new Map(pool.map(p=>[p.id,p])).values()].filter(p=>p.name!==cr.player_name).slice(0,14);
  const stored=management?.partnerships?.[0]?.player_b||null;
  const partner=uniq.find(p=>p.id===local.partnerId)||stored;
  const dPoints=(seasonSummary?.doubles_points||[]).filter(x=>x.active);
  const activePts=dPoints.reduce((s,x)=>s+Number(x.points||0),0);

  return `
  <div class="section-head">
    <div>
      <div class="eyebrow">Circuit double</div>
      <h1>Partenariat & saison double</h1>
      <div class="muted">Double #${fmt(cr.doubles_rank)} · ${fmt(cr.doubles_points||activePts)} pts actifs</div>
    </div>
    <button class="ghost" onclick="nav('season')">Bilan saison</button>
  </div>

  <div class="grid g2">
    <div class="card">
      <h2>Partenaire actuel</h2>
      ${partner?`
        <div class="row between click" onclick="openPlayer(${partner.id})">
          <div><h2>${flags[partner.country]||'🏳️'} ${esc(partner.name)}</h2><div class="muted">Double #${fmt(partner.doubles_ranking||9999)}</div></div>
          <span class="badge good">Sélectionné</span>
        </div>
        <div class="kpi-strip" style="margin-top:12px">
          <div class="kpi"><span class="muted mini">Chimie</span><b>${pairScore(partner,'chem')}%</b></div>
          <div class="kpi"><span class="muted mini">Compatibilité</span><b>${pairScore(partner,'comp')}%</b></div>
          <div class="kpi"><span class="muted mini">Force paire</span><b>${pairScore(partner,'power')}%</b></div>
        </div>`
        :'<div class="empty">Choisis un partenaire avant de jouer un tournoi double.</div>'}
    </div>
    <div class="card">
      <h2>Candidats</h2>
      ${uniq.map(p=>`
        <div class="list-item row between click" onclick="choosePartner(${p.id})">
          <div><b>${esc(p.name)}</b><div class="muted mini">Double #${fmt(p.doubles_ranking||9999)} · simple #${p.ranking}</div></div>
          <span class="badge">${pairScore(p,'comp')}%</span>
        </div>`).join('')}
    </div>
  </div>

  <div class="section-head" style="margin-top:18px">
    <div><div class="eyebrow">Calendrier double</div><h2>Tournois jouables</h2></div>
  </div>
  <div class="stack">
    ${cbDoublesTournaments.slice(0,12).map(t=>{
      const done=(seasonSummary?.doubles||[]).find(x=>x.tournament_id===t.id);
      return `
      <div class="card">
        <div class="row between">
          <div class="click" onclick="openTournament(${t.id})">
            <div class="eyebrow">${esc(t.category||t.level)} · ${df(t.start_date)}</div>
            <h2>${esc(t.name)}</h2>
            <div class="muted">${esc(t.city||'')} · ${esc(t.surface)}</div>
          </div>
          ${done
            ?`<div style="text-align:right"><span class="badge good">${esc(done.user_round)}</span><div class="muted mini">+${done.user_points} pts</div></div>`
            :`<button class="primary" ${partner?'':'disabled'} onclick="playDoublesV2(${t.id})">Jouer double</button>`}
        </div>
      </div>`;
    }).join('')||'<div class="card empty">Aucun tournoi double chargé.</div>'}
  </div>

  <div class="section-head" style="margin-top:18px">
    <div><div class="eyebrow">Historique</div><h2>Résultats double</h2></div>
  </div>
  <div class="stack">
    ${(seasonSummary?.doubles||[]).slice(0,10).map(r=>`
      <div class="card">
        <div class="row between">
          <div><b>${esc(r.tournaments?.name||'Tournoi')}</b><div class="muted mini">${df(r.tournaments?.start_date)} · avec ${esc(r.partner?.name||'partenaire')}</div></div>
          <div style="text-align:right"><span class="badge ${r.user_round==='Champion'?'good':''}">${esc(r.user_round)}</span><div class="muted mini">+${r.user_points} pts · ${euro(r.user_prize)}</div></div>
        </div>
      </div>`).join('')||'<div class="card empty">Aucun tournoi double joué.</div>'}
  </div>`;
}

async function playDoublesV2(id){
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Simulation du double…</div></div></div>';
  try{
    const d=await get('/api/play-doubles',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tournament_id:id})});
    boot=await get('/api/bootstrap');
    if(boot.career)local.career={...(local.career||{}),...boot.career};
    await Promise.all([loadSeasonSummary(),loadManagement(),loadRankingLedger(),loadScheduleAdvice()]);
    persist();
    overlay.innerHTML=`
      <div class="modal" onclick="if(event.target===this)closeOverlay()">
        <div class="sheet">
          <div class="sheet-head">
            <div><div class="eyebrow">Double · ${esc(d.tournament?.name||'Tournoi')}</div><h1>${d.round==='Champion'?'🏆 Champions':esc(d.round)}</h1><div class="muted">${esc(career().player_name||'Joueur')} / ${esc(d.partner?.name||'Partenaire')}</div></div>
            <button class="close" onclick="closeOverlay()">✕</button>
          </div>
          <div class="kpi-strip" style="margin-top:12px">
            <div class="kpi"><span class="muted mini">Classement</span><b>#${d.rank}</b></div>
            <div class="kpi"><span class="muted mini">Points</span><b>+${d.points}</b></div>
            <div class="kpi"><span class="muted mini">Prize money</span><b>${euro(d.prize)}</b></div>
            <div class="kpi"><span class="muted mini">Fatigue</span><b>+${d.fatigue_added}</b></div>
          </div>
          <div class="card" style="margin-top:12px"><h2>Parcours</h2>
            ${(d.matches||[]).map(m=>`
              <div class="list-item">
                <div class="row between"><b>${esc(m.round_name)}</b><span class="badge ${m.winner_pair.includes(career().player_name||'Joueur')?'good':'bad'}">${m.winner_pair.includes(career().player_name||'Joueur')?'Victoire':'Défaite'}</span></div>
                <div>${esc(m.user_pair)} vs ${esc(m.opponent_pair)}</div>
                <div class="muted mini">${esc(m.score)}</div>
              </div>`).join('')}
          </div>
        </div>
      </div>`;
  }catch(e){
    overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Double impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`;
  }
}

window.playDoublesV2=playDoublesV2;
window.refreshSeasonV2=refreshSeasonV2;


async function loadCbPlayerSearch(reset=false){
  if(reset)cbPlayerSearch.offset=0;
  const p=new URLSearchParams({
    q:cbPlayerSearch.q||'',
    country:cbPlayerSearch.country||'',
    circuit:cbPlayerSearch.circuit||'Tous',
    age_max:String(cbPlayerSearch.age_max||99),
    potential_min:String(cbPlayerSearch.potential_min||0),
    offset:String(cbPlayerSearch.offset||0),
    limit:String(cbPlayerSearch.limit||60)
  });
  try{
    const d=await get('/api/search-players?'+p.toString());
    cbPlayerSearch={...cbPlayerSearch,rows:d.rows||[],count:d.count||0};
  }catch(e){
    cbPlayerSearch={...cbPlayerSearch,rows:[],count:0,error:e.message};
  }
}

function playerCircuitLabelV2(p){
  if(p.ranking_current)return 'ATP';
  if(p.junior_ranking!=null)return 'Junior';
  if(p.itf_ranking!=null)return 'ITF';
  return p.is_real?'Hors classement':'Prospect';
}

function playerDatabasePageV2(){
  const s=cbPlayerSearch;
  const countries=['','FRA','USA','ESP','ITA','GER','AUS','CZE','ARG','GBR','CAN','BRA','NED','BEL','SUI','AUT','JPN','KOR','SRB','CRO','SWE'];
  const circuits=['Tous','ATP','ITF','Junior','Prospects'];
  const start=s.count?Number(s.offset)+1:0,end=Math.min(Number(s.offset)+s.rows.length,s.count);
  return `
  <div class="section-head">
    <div>
      <div class="eyebrow">Database mondiale</div>
      <h1>Base joueurs</h1>
      <div class="muted">5 000 profils · ATP, ITF, juniors et prospects. Challenger reste une catégorie de tournoi.</div>
    </div>
    <div class="row"><button class="ghost" onclick="openCustomPlayerCreatorV2()">Créer mon joueur</button><button class="primary" onclick="nav('rankings')">Classement ATP</button></div>
  </div>

  <div class="card">
    <div class="filters">
      <input class="input" id="cbPlayerQ" value="${esc(s.q)}" placeholder="Nom du joueur…" onkeydown="if(event.key==='Enter')applyPlayerSearchV2()">
      <select class="select" id="cbPlayerCircuit">
        ${circuits.map(x=>`<option ${x===s.circuit?'selected':''}>${x}</option>`).join('')}
      </select>
      <select class="select" id="cbPlayerCountry">
        ${countries.map(x=>`<option value="${x}" ${x===s.country?'selected':''}>${x||'Tous pays'}</option>`).join('')}
      </select>
      <select class="select" id="cbPlayerAge">
        ${[[99,'Tout âge'],[23,'23 ans max'],[20,'20 ans max'],[18,'18 ans max']].map(([v,l])=>`<option value="${v}" ${Number(v)===Number(s.age_max)?'selected':''}>${l}</option>`).join('')}
      </select>
      <select class="select" id="cbPlayerPotential">
        ${[[0,'Tout potentiel'],[70,'PA 70+'],[80,'PA 80+'],[90,'PA 90+']].map(([v,l])=>`<option value="${v}" ${Number(v)===Number(s.potential_min)?'selected':''}>${l}</option>`).join('')}
      </select>
      <button class="soft-btn" onclick="applyPlayerSearchV2()">Filtrer</button>
    </div>
    <div class="row between" style="margin-top:10px">
      <span class="muted mini">${fmt(s.count)} profil(s) · lignes ${fmt(start)}–${fmt(end)}</span>
      <button class="ghost" onclick="resetPlayerSearchV2()">Réinitialiser</button>
    </div>
  </div>

  <div class="grid g3" style="margin-top:12px">
    ${s.rows.map(p=>`
      <div class="card">
        <div class="row between click" onclick="openPlayer(${p.id})">
          <div>
            <div class="eyebrow">${playerCircuitLabelV2(p)} ${p.ranking_current?'#'+p.ranking:p.itf_ranking!=null?'#'+p.itf_ranking:p.junior_ranking!=null?'#'+p.junior_ranking:''}</div>
            <h2>${flags[p.country]||'🏳️'} ${esc(p.name)}</h2>
            <div class="muted mini">${p.age||'—'} ans · ${esc(p.style||'Non renseigné')}</div>
          </div>
          <span class="badge">${p.scouting_confidence||0}% scout</span>
        </div>
        <div class="kpi-strip" style="margin-top:10px">
          <div class="kpi"><span class="muted mini">CA</span><b>${p.current_ability}</b></div>
          <div class="kpi"><span class="muted mini">PA</span><b>${p.potential}</b></div>
          <div class="kpi"><span class="muted mini">Forme</span><b>${p.form}</b></div>
          <div class="kpi"><span class="muted mini">Fitness</span><b>${p.fitness}</b></div>
        </div>
        <div class="row" style="margin-top:10px">
          <button class="soft-btn" onclick="openPlayer(${p.id})">Profil</button>
          <button class="ghost" onclick="addComparePlayerV2(${p.id})">Comparer</button>
        </div>
      </div>`).join('')||`<div class="card empty">${esc(s.error||'Aucun joueur trouvé.')}</div>`}
  </div>

  <div class="pagination">
    <button ${s.offset===0?'disabled':''} onclick="playerPageV2(-1)">←</button>
    <span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(s.count)}</span>
    <button ${Number(s.offset)+Number(s.limit)>=Number(s.count)?'disabled':''} onclick="playerPageV2(1)">→</button>
  </div>`;
}

async function applyPlayerSearchV2(){
  cbPlayerSearch.q=document.getElementById('cbPlayerQ')?.value||'';
  cbPlayerSearch.circuit=document.getElementById('cbPlayerCircuit')?.value||'Tous';
  cbPlayerSearch.country=document.getElementById('cbPlayerCountry')?.value||'';
  cbPlayerSearch.age_max=Number(document.getElementById('cbPlayerAge')?.value||99);
  cbPlayerSearch.potential_min=Number(document.getElementById('cbPlayerPotential')?.value||0);
  await loadCbPlayerSearch(true);
  shell(playerDatabasePageV2());
}
async function resetPlayerSearchV2(){
  cbPlayerSearch={q:'',country:'',circuit:'Tous',age_max:99,potential_min:0,offset:0,limit:60,rows:[],count:0};
  await loadCbPlayerSearch(true);
  shell(playerDatabasePageV2());
}
async function playerPageV2(dir){
  cbPlayerSearch.offset=Math.max(0,Number(cbPlayerSearch.offset)+(dir*Number(cbPlayerSearch.limit)));
  await loadCbPlayerSearch(false);
  shell(playerDatabasePageV2());
  window.scrollTo({top:0,behavior:'smooth'});
}
window.applyPlayerSearchV2=applyPlayerSearchV2;
window.resetPlayerSearchV2=resetPlayerSearchV2;
window.playerPageV2=playerPageV2;


async function loadFantasyV2(){
  try{cbFantasyData=await get('/api/fantasy/list')}catch(e){cbFantasyData={tournaments:[],entries:[],runs:[]}}
}
function fantasyPageV2(){
  return `
  <div class="section-head">
    <div><div class="eyebrow">Mode créatif</div><h1>Fantasy Court</h1><div class="muted">Crée un tournoi, choisis les joueurs et simule le tableau.</div></div>
  </div>
  <div class="card">
    <h2>Nouveau tournoi</h2>
    <div class="filters">
      <input id="fantasyName" class="input" placeholder="Nom du tournoi" value="Court Boss Invitational">
      <select id="fantasySurface" class="select"><option>Dur</option><option>Terre</option><option>Gazon</option></select>
      <select id="fantasyDraw" class="select"><option value="8">8 joueurs</option><option value="16" selected>16 joueurs</option><option value="32">32 joueurs</option><option value="64">64 joueurs</option></select>
      <select id="fantasyBest" class="select"><option value="3" selected>Meilleur des 3 sets</option><option value="5">Meilleur des 5 sets</option></select>
    </div>
    <button class="primary" onclick="createFantasyV2()">Créer le tournoi</button>
  </div>
  <div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Tes créations</div><h2>Tournois Fantasy</h2></div></div>
  <div class="stack">
    ${(cbFantasyData.tournaments||[]).map(t=>{
      const entries=(cbFantasyData.entries||[]).filter(e=>e.fantasy_id===t.id);
      const run=(cbFantasyData.runs||[]).find(r=>r.fantasy_id===t.id);
      return `<div class="card click" onclick="openFantasyV2(${t.id})">
        <div class="row between">
          <div><div class="eyebrow">${esc(t.surface)} · ${t.draw_size} joueurs</div><h2>${esc(t.name)}</h2><div class="muted mini">${entries.length}/${t.draw_size} participants · ${t.best_of===5?'Best of 5':'Best of 3'}</div></div>
          <div style="text-align:right"><span class="badge ${t.status==='completed'?'good':''}">${esc(t.status)}</span>${run?.champion?`<div class="muted mini">🏆 ${esc(run.champion.name)}</div>`:''}</div>
        </div>
      </div>`;
    }).join('')||'<div class="card empty">Aucun tournoi Fantasy créé.</div>'}
  </div>`;
}
async function createFantasyV2(){
  const name=document.getElementById('fantasyName')?.value||'Court Boss Invitational';
  const surface=document.getElementById('fantasySurface')?.value||'Dur';
  const draw_size=Number(document.getElementById('fantasyDraw')?.value||16);
  const best_of=Number(document.getElementById('fantasyBest')?.value||3);
  try{
    await get('/api/fantasy/create',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name,surface,draw_size,best_of})});
    await loadFantasyV2();shell(fantasyPageV2());
  }catch(e){alert(e.message)}
}
async function fantasySearchV2(id,q){
  const box=document.getElementById('fantasySearchResults');if(!box)return;
  if(String(q||'').trim().length<2){box.innerHTML='<div class="empty">Tape au moins 2 caractères.</div>';return}
  try{
    const d=await get('/api/search-players?circuit=ATP&offset=0&limit=20&q='+encodeURIComponent(q.trim()));
    cbFantasySearch=d.rows||[];
    box.innerHTML=cbFantasySearch.map(p=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking} · CA ${p.current_ability} · PA ${p.potential}</div></div><button class="soft-btn" onclick="addFantasyEntryV2(${id},${p.id})">Ajouter</button></div>`).join('')||'<div class="empty">Aucun joueur.</div>';
  }catch(e){box.innerHTML='<div class="empty">'+esc(e.message)+'</div>'}
}
async function addFantasyEntryV2(fid,pid){
  try{await get('/api/fantasy/entry',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({fantasy_id:fid,player_id:pid,mode:'add'})});await loadFantasyV2();openFantasyV2(fid)}catch(e){alert(e.message)}
}
async function removeFantasyEntryV2(fid,pid){
  try{await get('/api/fantasy/entry',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({fantasy_id:fid,player_id:pid,mode:'remove'})});await loadFantasyV2();openFantasyV2(fid)}catch(e){alert(e.message)}
}
async function runFantasyV2(fid){
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Simulation du tableau Fantasy…</div></div></div>';
  try{
    const d=await get('/api/fantasy/run',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({fantasy_id:fid})});
    await loadFantasyV2();
    const rounds=[...new Set((d.run?.matches||[]).map(m=>m.round_name))];
    overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Fantasy Court</div><h1>🏆 ${esc(d.run?.champion?.name||'Champion')}</h1><div class="muted">Tournoi terminé</div></div><button class="close" onclick="closeOverlay()">✕</button></div>${rounds.map(r=>`<div class="card" style="margin-top:10px"><h2>${esc(r)}</h2>${(d.run.matches||[]).filter(m=>m.round_name===r).map(m=>`<div class="list-item row between"><div><b>${esc(m.player_a_name)}</b><div class="muted mini">vs ${esc(m.player_b_name)}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="good mini">→ ${esc(m.winner_name)}</div></div></div>`).join('')}</div>`).join('')}</div></div>`;
  }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Simulation impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`}
}
async function openFantasyV2(id){
  const t=(cbFantasyData.tournaments||[]).find(x=>x.id===id);if(!t)return;
  const entries=(cbFantasyData.entries||[]).filter(e=>e.fantasy_id===id);
  const run=(cbFantasyData.runs||[]).find(r=>r.fantasy_id===id);
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Fantasy Court · ${esc(t.surface)}</div><h1>${esc(t.name)}</h1><div class="muted">${entries.length}/${t.draw_size} joueurs · ${t.best_of===5?'Best of 5':'Best of 3'}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  ${run?.champion?`<div class="notice good" style="margin-top:12px">Champion actuel : <b>${esc(run.champion.name)}</b></div>`:''}
  <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Participants</h2>${entries.map((e,i)=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${e.players?.id})"><b>#${i+1} ${esc(e.players?.name||'Joueur')}</b><div class="muted mini">${e.players?.country||''} · ATP #${e.players?.ranking||'—'}</div></div>${t.status!=='completed'?`<button class="danger-btn" onclick="removeFantasyEntryV2(${id},${e.players?.id})">Retirer</button>`:''}</div>`).join('')||'<div class="empty">Aucun participant.</div>'}</div>
  <div class="card"><h2>Ajouter un joueur</h2><input class="input" placeholder="Nom du joueur…" oninput="fantasySearchV2(${id},this.value)"><div id="fantasySearchResults" style="margin-top:8px"><div class="empty">Recherche dans les 5 000 profils.</div></div></div></div>
  ${t.status!=='completed'?`<button class="primary" style="margin-top:12px" ${entries.length<2?'disabled':''} onclick="runFantasyV2(${id})">Simuler le tournoi</button>`:''}
  </div></div>`;
}
window.createFantasyV2=createFantasyV2;
window.fantasySearchV2=fantasySearchV2;
window.addFantasyEntryV2=addFantasyEntryV2;
window.removeFantasyEntryV2=removeFantasyEntryV2;
window.runFantasyV2=runFantasyV2;
window.openFantasyV2=openFantasyV2;

const cbBaseNav=window.nav;
window.nav=async function(r){
  if(r==='season'){
    route='season';window.scrollTo({top:0,behavior:'smooth'});
    if(!seasonSummary)await loadSeasonSummary();await loadCbSeasonHistory();
    shell(seasonPageV2());
    return;
  }
  if(r==='doubles'){
    route='doubles';window.scrollTo({top:0,behavior:'smooth'});
    await Promise.all([loadCbDoublesTournaments(),loadSeasonSummary(),loadManagement(),loadCbSeasonHistory()]);
    shell(doublesPageV2());
    return;
  }
  if(r==='match'){
    route='match';window.scrollTo({top:0,behavior:'smooth'});
    await Promise.all([loadCbMatchOpponents(),restoreLiveMatchV2()]);
    shell(liveMatchPageV2());
    return;
  }
  if(r==='players'){
    route='players';window.scrollTo({top:0,behavior:'smooth'});
    if(!cbPlayerSearch.rows.length)await loadCbPlayerSearch(true);
    shell(playerDatabasePageV2());
    return;
  }
  if(r==='fantasy'){
    route='fantasy';window.scrollTo({top:0,behavior:'smooth'});
    await loadFantasyV2();
    shell(fantasyPageV2());
    return;
  }
  return cbBaseNav(r);
};

const cbBaseRender=window.render;
window.render=function(){
  if(route==='season')return shell(seasonPageV2());
  if(route==='doubles'&&cbDoublesTournaments.length)return shell(doublesPageV2());
  if(route==='match')return shell(liveMatchPageV2());
  if(route==='players')return shell(playerDatabasePageV2());
  if(route==='fantasy')return shell(fantasyPageV2());
  return cbBaseRender();
};

window.rolloverSeasonV2=rolloverSeasonV2;

window.startCareerWithPlayer=async function(id,name){
  if(!confirm("Démarrer une nouvelle carrière avec "+name+" ? Les résultats de la carrière actuelle seront réinitialisés."))return;
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Création de la nouvelle carrière…</div></div></div>';
  try{
    const d=await managerAction('take_over_player',id,{date:local.date||'2026-09-27'});
    Object.assign(local,{
      date:d.career?.career_date||local.date||'2026-09-27',
      week:1,
      training:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'],
      entries:[],
      entryMeta:{},
      shortlist:[],
      career:d.career||null,
      feed:['Nouvelle carrière lancée avec '+name+'.'],
      scoutingBoost:0,
      partnerId:null,
      davisRoles:{},
      tactics:{aggression:58,risk:52,net:28,returnPos:'Neutre'},
      playedTournaments:{},
      practiceMatches:[],
      facilityLevels:{}
    });
    persist();
    boot=await get('/api/bootstrap');
    if(boot.career)local.career={...boot.career};
    rankKind='singles';rankOffset=0;rankQuery='';
    tourOffset=0;
    await Promise.all([
      loadManagement(),loadRankings(),loadTournaments(),loadRankingLedger(),
      loadSeasonSummary(),loadScheduleAdvice(),loadCbDoublesTournaments()
    ]);
    delete local.liveSessionId;cbLiveSession=null;cbLiveOpponent=null;persist();
    closeOverlay();
    route='home';
    shell(home());
  }catch(e){
    overlay.innerHTML='<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Nouvelle carrière impossible</h2><p class="muted">'+esc(e.message)+'</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>';
  }
};

async function loadCbMatchOpponents(){
  const r=Math.max(1,Number(career().singles_rank||750));
  const offset=Math.max(0,r-8);
  try{
    const d=await get('/api/rankings?kind=singles&offset='+offset+'&limit=16');
    cbMatchOpponents=(d.rows||[]).filter(p=>p.name!==career().player_name);
  }catch(e){
    cbMatchOpponents=[];
  }
}

function cbPointLabel(a,b){
  a=Number(a||0);b=Number(b||0);
  if(a>=3&&b>=3){
    if(a===b)return '40';
    if(a===b+1)return 'Av';
    if(b===a+1)return '40';
  }
  return ['0','15','30','40'][Math.min(a,3)]||'40';
}
function liveMatchPageV2(){
  const cr=career();
  if(!cbLiveSession){
    return `
      ${cbLiveRestoreError?`<div class="notice bad">${esc(cbLiveRestoreError)} <button class="ghost" onclick="nav('match')">Réessayer</button></div>`:''}
      <div class="section-head">
        <div><div class="eyebrow">Match Center</div><h1>Match live</h1><div class="muted">Choisis un adversaire puis coache jeu par jeu.</div></div>
        <button class="ghost" onclick="nav('tactics')">Tactique</button>
      </div>
      <div class="grid g2">
        <div class="card">
          <h2>Ton état</h2>
          <div class="kpi-strip">
            <div class="kpi"><span class="muted mini">ATP</span><b>#${cr.singles_rank}</b></div>
            <div class="kpi"><span class="muted mini">Forme</span><b>${cr.form}</b></div>
            <div class="kpi"><span class="muted mini">Fitness</span><b>${cr.fitness}</b></div>
            <div class="kpi"><span class="muted mini">Fatigue</span><b>${cr.fatigue}</b></div>
          </div>
        </div>
        <div class="card">
          <h2>Plan de jeu</h2>
          <div class="list-item row between"><span>Agressivité</span><b>${local.tactics?.aggression||58}</b></div>
          <div class="list-item row between"><span>Prise de risque</span><b>${local.tactics?.risk||52}</b></div>
          <div class="list-item row between"><span>Jeu au filet</span><b>${local.tactics?.net||28}</b></div>
          <div class="list-item row between"><span>Position retour</span><b>${esc(local.tactics?.returnPos||'Neutre')}</b></div>
        </div>
      </div>
      <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Conditions du match</div><h2>Surface</h2></div><select class="select" style="width:auto" onchange="setLiveSurfaceV2(this.value)"><option ${cbLiveSurface==='Dur'?'selected':''}>Dur</option><option ${cbLiveSurface==='Terre'?'selected':''}>Terre</option><option ${cbLiveSurface==='Gazon'?'selected':''}>Gazon</option></select></div></div>
      <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Adversaires</div><h2>Autour de ton classement</h2></div></div>
      <div class="grid g2">
        ${cbMatchOpponents.map(p=>`
          <div class="card">
            <div class="row between">
              <div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">ATP #${p.ranking}</div><h2>${flags[p.country]||'🏳️'} ${esc(p.name)}</h2><div class="muted mini">CA ${p.current_ability} · forme ${p.form} · fatigue ${p.fatigue}</div></div>
              <button class="primary" onclick="startLiveMatchV2(${p.id})" ${cbLiveBusy?'disabled':''}>${cbLiveBusy?'Préparation…':'Jouer'}</button>
            </div>
          </div>`).join('')||'<div class="card empty">Aucun adversaire chargé.</div>'}
      </div>`;
  }

  const s=cbLiveSession,o=cbLiveOpponent||{};
  const totalGames=(s.user_games||0)+(s.opponent_games||0);
  const momentum=Math.max(-40,Math.min(40,Number(s.momentum??50)-50));
  const stats=s.stats||{};
  const done=s.status!=='active';

  return `
    <div class="section-head">
      <div><div class="eyebrow">Match live · ${esc(s.surface||'Dur')}</div><h1>${esc(cr.player_name||'Joueur')} vs ${esc(o.name||'Adversaire')}</h1><div class="muted">ATP #${o.ranking||'—'} · set ${s.set_no||1}</div></div>
      <button class="ghost" onclick="nav('home')">Revenir à l’accueil</button>
    </div>

    <div class="card live-score">
      <div class="score-head"><span></span><span>SET</span><span>JEU</span><span>POINT</span></div>
      <div class="score-line">
        <div><span class="muted mini">JOUEUR</span><h2>${esc(cr.player_name||'Joueur')}</h2></div>
        <div class="score-pills"><span>${s.user_sets}</span><strong>${s.user_games}</strong><em>${cbPointLabel(s.user_points,s.opponent_points)}</em></div>
      </div>
      <div class="score-line">
        <div><span class="muted mini">ADVERSAIRE</span><h2>${esc(o.name||'Adversaire')}</h2></div>
        <div class="score-pills"><span>${s.opponent_sets}</span><strong>${s.opponent_games}</strong><em>${cbPointLabel(s.opponent_points,s.user_points)}</em></div>
      </div>
      <div class="muted mini" style="margin-top:8px">${done?'Match terminé · ':''}${s.serving_user?'🎾 '+esc(cr.player_name||'Joueur')+' au service':'🎾 '+esc(o.name||'Adversaire')+' au service'} · ${totalGames} jeu(x) dans le set</div>
    </div>

    <div class="card" style="margin-top:12px">
      <div class="row between">
        <div><div class="eyebrow">Vue tactique</div><h2>Terrain 2D</h2></div>
        <div style="text-align:right"><span class="muted mini">Chance prochain jeu</span><div class="big" style="font-size:22px">${Math.round(cbLiveWinProb)}%</div></div>
      </div>
      ${(()=>{
        const lp=s.last_point||{};
        const ux=Number(lp.user_x??(55+Math.max(-18,Math.min(18,momentum*.28))));
        const ox=Number(lp.opp_x??(45+Math.max(-18,Math.min(18,-momentum*.28))));
        const bx=Number(lp.ball_x??(s.serving_user?57:43));
        const by=Number(lp.ball_y??(s.serving_user?70:28));
        const rally=Number(lp.rally||0);
        return `<div class="court2d ${String(s.surface||'Dur').toLowerCase().replace('terre','clay').replace('gazon','grass')} ${rally?'rallying':''}">
          <div class="court-line baseline top"></div><div class="court-line baseline bottom"></div>
          <div class="court-line sideline left"></div><div class="court-line sideline right"></div>
          <div class="court-line service top"></div><div class="court-line service bottom"></div>
          <div class="court-line center"></div><div class="court-net"></div>
          <div class="court-shadow opponent" style="left:${ox}%"></div>
          <div class="court-shadow user" style="left:${ux}%"></div>
          <div class="court-player opponent" style="left:${ox}%"><span>${esc((o.name||'A').slice(0,1))}</span></div>
          <div class="court-player user" style="left:${ux}%"><span>${esc((cr.player_name||'A').slice(0,1))}</span></div>
          <div class="court-ball ${s.serving_user?'serve-user':'serve-opp'} ${rally?'ball-live':''}" style="left:${bx}%;top:${by}%"></div>
          <div class="court-zone z1 ${(local.tactics?.returnPos||'Neutre')==='Avancée'?'active':''}"></div>
          <div class="court-zone z2 ${Number(local.tactics?.net||28)>55?'active':''}"></div>
          ${rally?`<div class="rally-chip">${rally} coups · ${esc(lp.shot||'échange')} · ${lp.winner==='user'?esc(cr.player_name||'Joueur'):esc(o.name||'Adversaire')}</div>`:''}
        </div>`;
      })()}
      <div class="grid g3" style="margin-top:10px">
        <div class="kpi"><span class="muted mini">Service ciblé</span><b style="font-size:13px">${Number(local.tactics?.risk||52)>65?'Extérieur':'Mixte'}</b></div>
        <div class="kpi"><span class="muted mini">Position retour</span><b style="font-size:13px">${esc(local.tactics?.returnPos||'Neutre')}</b></div>
        <div class="kpi"><span class="muted mini">Montée filet</span><b>${local.tactics?.net||28}%</b></div>
      </div>
    </div>

    <div class="grid g2" style="margin-top:12px">
      <div class="card">
        <h2>Momentum</h2>
        <div class="momentum-track"><i style="left:${50+momentum}%"></i></div>
        <div class="row between mini muted"><span>Adversaire</span><b>${momentum>0?(cr.player_name||'Joueur')+' +'+momentum:momentum<0?'Adversaire '+Math.abs(momentum):'Équilibre'}</b><span>${esc(cr.player_name||'Joueur')}</span></div>
      </div>
      <div class="card">
        <h2>Stats live</h2>
        <div class="kpi-strip">
          <div class="kpi"><span class="muted mini">Winners</span><b>${stats.user_winners||0}</b></div>
          <div class="kpi"><span class="muted mini">Fautes</span><b>${stats.user_errors||0}</b></div>
          <div class="kpi"><span class="muted mini">Aces</span><b>${stats.user_aces||0}</b></div>
          <div class="kpi"><span class="muted mini">DF</span><b>${stats.double_faults||0}</b></div>
        </div>
      </div>
    </div>

    <div class="card" style="margin-top:12px">
      <h2>Coaching tactique</h2>
      <div class="live-slider"><span>Agressivité</span><input type="range" min="1" max="100" value="${local.tactics?.aggression||58}" oninput="setLiveTacticV2('aggression',Number(this.value));this.nextElementSibling.textContent=this.value"><b>${local.tactics?.aggression||58}</b></div>
      <div class="live-slider"><span>Prise de risque</span><input type="range" min="1" max="100" value="${local.tactics?.risk||52}" oninput="setLiveTacticV2('risk',Number(this.value));this.nextElementSibling.textContent=this.value"><b>${local.tactics?.risk||52}</b></div>
      <div class="live-slider"><span>Jeu au filet</span><input type="range" min="1" max="100" value="${local.tactics?.net||28}" oninput="setLiveTacticV2('net',Number(this.value));this.nextElementSibling.textContent=this.value"><b>${local.tactics?.net||28}</b></div>
      <div class="list-item row between"><span>Position au retour</span><select class="select" style="width:auto" onchange="setLiveTacticV2('returnPos',this.value)"><option ${(local.tactics?.returnPos||'Neutre')==='Neutre'?'selected':''}>Neutre</option><option ${local.tactics?.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${local.tactics?.returnPos==='Reculée'?'selected':''}>Reculée</option></select></div>
      ${done
        ?`<div class="notice ${s.user_sets>s.opponent_sets?'good':'bad'}" style="margin-top:12px"><b>${s.user_sets>s.opponent_sets?'Victoire':'Défaite'} ${s.user_sets}-${s.opponent_sets}</b></div><button class="primary" style="margin-top:10px" onclick="resetLiveMatchV2()">Nouveau match</button>`
        :`<div class="match-controls" style="margin-top:12px">
          <button class="primary" ${cbLiveBusy?'disabled':''} onclick="advanceLiveMatchV2()">${cbLiveBusy?'Échange…':'1 point'}</button>
          <button class="soft-btn" ${cbLiveBusy?'disabled':''} onclick="advanceLiveMatchGameV2()">Finir le jeu</button>
          <button class="soft-btn" ${cbLiveBusy?'disabled':''} onclick="advanceLiveMatchSetV2()">Finir le set</button>
        </div><p class="muted mini" style="margin-top:8px">Le match est sauvegardé à chaque point. Sur mobile, joue point par point pour suivre le terrain comme un match viewer.</p>`}
    </div>

    <div class="card" style="margin-top:12px">
      <h2>Historique du score</h2>
      ${(s.score_log||[]).slice(-12).reverse().map(x=>`<div class="list-item row between"><span>Set ${x.set} · ${x.user_games}-${x.opponent_games}</span><b class="${x.winner_game===(cr.player_name||'Anthony')?'good':'bad'}">${esc(x.winner_game)}</b></div>`).join('')||'<div class="empty">Le match n’a pas encore commencé.</div>'}
    </div>`;
}

// One live match controller: the server owns the score; local state only keeps its ID.
async function restoreLiveMatchV2(){
  if(cbLiveSession||!local.liveSessionId)return;
  cbLiveRestoreError='';
  try{
    const d=await get('/api/live-match/state?id='+encodeURIComponent(local.liveSessionId));
    cbLiveSession=d.session;cbLiveOpponent=d.session.opponent;
    cbLiveSurface=d.session.surface||'Dur';
  }catch(e){cbLiveRestoreError='Reprise du match impossible : '+e.message;}
}
async function startLiveMatchV2(opponentId){
  if(cbLiveBusy||local.liveSessionId)return;
  cbLiveBusy=true;shell(liveMatchPageV2());
  try{
    const d=await get('/api/live-match/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({opponent_id:opponentId,surface:cbLiveSurface,tactics:local.tactics||{}})});
    cbLiveSession=d.session;cbLiveOpponent=d.opponent;cbLiveWinProb=50;
    local.liveSessionId=d.session.id;persist();
  }catch(e){alert(e.message)}
  finally{cbLiveBusy=false;if(route==='match')shell(liveMatchPageV2());}
}
async function advanceLiveV2(target='point'){
  if(!cbLiveSession||cbLiveBusy||cbLiveSession.status!=='active')return;
  cbLiveBusy=true;shell(liveMatchPageV2());
  const startGames=Number(cbLiveSession.user_games||0)+Number(cbLiveSession.opponent_games||0);
  const startSet=Number(cbLiveSession.set_no||1);
  try{
    const max=target==='set'?180:target==='game'?36:1;
    for(let i=0;i<max;i++){
      const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:cbLiveSession.id,tactics:local.tactics||{}})});
      cbLiveSession=d.session;cbLiveOpponent=d.opponent||cbLiveOpponent;
      cbLiveWinProb=Number(d.win_probability??cbLiveWinProb);
      if(d.completed){
        delete local.liveSessionId;
        boot=await get('/api/bootstrap');
        if(boot.career)local.career={...boot.career};
        await loadSeasonSummary();persist();break;
      }
      const games=Number(cbLiveSession.user_games||0)+Number(cbLiveSession.opponent_games||0);
      if(target==='point')break;
      if(target==='game'&&(games!==startGames||Number(cbLiveSession.set_no||1)!==startSet))break;
      if(target==='set'&&Number(cbLiveSession.set_no||1)!==startSet)break;
    }
  }catch(e){alert('Le score reste sauvegardé. '+e.message)}
  finally{cbLiveBusy=false;if(route==='match')shell(liveMatchPageV2());}
}
async function advanceLiveMatchV2(){return advanceLiveV2('point')}
async function advanceLiveMatchGameV2(){return advanceLiveV2('game')}
async function advanceLiveMatchSetV2(){return advanceLiveV2('set')}
window.advanceLiveMatchGameV2=advanceLiveMatchGameV2;
window.advanceLiveMatchSetV2=advanceLiveMatchSetV2;

function setLiveSurfaceV2(v){
  cbLiveSurface=['Dur','Terre','Gazon'].includes(v)?v:'Dur';
  shell(liveMatchPageV2());
}
function setLiveTacticV2(k,v){
  local.tactics=local.tactics||{};
  local.tactics[k]=v;
  persist();
}

function resetLiveMatchV2(){
  if(cbLiveBusy)return;
  if(cbLiveSession?.status==='active'){alert('Ce match est encore en cours. Reviens à l’accueil pour le conserver.');return;}
  delete local.liveSessionId;persist();
  cbLiveSession=null;cbLiveOpponent=null;cbLiveWinProb=50;
  shell(liveMatchPageV2());
}

window.startLiveMatchV2=startLiveMatchV2;
window.advanceLiveMatchV2=advanceLiveMatchV2;
window.setLiveSurfaceV2=setLiveSurfaceV2;
window.setLiveTacticV2=setLiveTacticV2;
window.resetLiveMatchV2=resetLiveMatchV2;


async function addComparePlayerV2(id){
  local.comparePlayers=Array.isArray(local.comparePlayers)?local.comparePlayers:[];
  if(!local.comparePlayers.includes(id)){
    if(local.comparePlayers.length>=3)local.comparePlayers.shift();
    local.comparePlayers.push(id);
    persist();
  }
  if(local.comparePlayers.length>=2) await openCompareV2();
  else alert('Joueur ajouté au comparateur. Ajoute encore un joueur pour comparer.');
}

async function openCompareV2(){
  const ids=(local.comparePlayers||[]).slice(-3);
  if(ids.length<2){alert('Ajoute au moins 2 joueurs au comparateur.');return}
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Comparaison des joueurs…</div></div></div>';
  try{
    const rows=[];
    for(const id of ids){
      const d=await get('/api/player?id='+id);
      if(d.player)rows.push(d.player);
    }
    const attrs=[
      ['Puissance service','serve_power'],['Précision service','serve_precision'],['Coup droit','forehand'],
      ['Revers','backhand'],['Retour','return_game'],['Volée','volley'],['Toucher','touch'],
      ['Déplacements','movement'],['Vitesse','speed'],['Endurance','stamina'],['Force','strength'],
      ['Anticipation','anticipation'],['Concentration','concentration'],['Sang-froid','composure'],
      ['Combativité','fighting_spirit'],['Tactique','tactics'],['Double','doubles'],
      ['Terre battue','clay_affinity'],['Dur','hard_affinity'],['Gazon','grass_affinity']
    ];
    const best=(key)=>Math.max(...rows.map(p=>Number(p.player_attributes?.[key]||0)));
    overlay.innerHTML=`
      <div class="modal" onclick="if(event.target===this)closeOverlay()">
        <div class="sheet compare-sheet">
          <div class="sheet-head">
            <div><div class="eyebrow">Scouting</div><h1>Comparateur joueurs</h1><div class="muted">Jusqu'à 3 profils côte à côte.</div></div>
            <button class="close" onclick="closeOverlay()">✕</button>
          </div>
          <div class="compare-grid" style="margin-top:12px">
            <div class="compare-label"></div>
            ${rows.map(p=>`<div class="compare-player"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking}</div><button class="ghost mini" onclick="removeComparePlayerV2(${p.id})">Retirer</button></div>`).join('')}
            
            <div class="compare-label">CA</div>
            ${rows.map(p=>`<div class="compare-value"><b>${p.current_ability}</b>/100</div>`).join('')}
            <div class="compare-label">Potentiel</div>
            ${rows.map(p=>`<div class="compare-value"><b>${p.potential}</b>/100</div>`).join('')}
            <div class="compare-label">Forme</div>
            ${rows.map(p=>`<div class="compare-value">${p.form}/100</div>`).join('')}
            <div class="compare-label">Fitness</div>
            ${rows.map(p=>`<div class="compare-value">${p.fitness}/100</div>`).join('')}
            <div class="compare-label">Fatigue</div>
            ${rows.map(p=>`<div class="compare-value">${p.fatigue}/100</div>`).join('')}
            ${attrs.map(([label,key])=>`
              <div class="compare-label">${label}</div>
              ${rows.map(p=>{const v=Number(p.player_attributes?.[key]||0);return `<div class="compare-value ${v===best(key)?'compare-best':''}"><b>${v}</b>/20</div>`}).join('')}
            `).join('')}
          </div>
        </div>
      </div>`;
  }catch(e){
    overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Comparaison impossible</h2><p class="muted">${esc(e.message)}</p></div></div>`;
  }
}

function removeComparePlayerV2(id){
  local.comparePlayers=(local.comparePlayers||[]).filter(x=>x!==id);
  persist();
  if(local.comparePlayers.length>=2)openCompareV2();else closeOverlay();
}

window.addComparePlayerV2=addComparePlayerV2;
window.openCompareV2=openCompareV2;
window.removeComparePlayerV2=removeComparePlayerV2;

window.openGlobalSearchV2=()=>{
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Recherche globale</div><h1>${fmt(worldStats?.playersTotal??5000)} joueurs</h1><div class="muted">Joueurs réels et prospects de simulation. Challenger est une catégorie de tournoi.</div></div><button class="close" onclick="closeOverlay()">✕</button></div><input id="globalSearchInputV2" class="input" style="margin-top:12px" placeholder="Nom du joueur…" oninput="runGlobalSearchV2(this.value)" autofocus><div id="globalSearchResultsV2" class="stack" style="margin-top:12px"><div class="empty">Tape au moins 2 caractères.</div></div></div></div>`;
  setTimeout(()=>document.getElementById('globalSearchInputV2')?.focus(),20);
}
let cbSearchTimer=null;
let cbSearchVersion=0;
window.runGlobalSearchV2=q=>{
  const version=++cbSearchVersion;
  clearTimeout(cbSearchTimer);
  const box=document.getElementById('globalSearchResultsV2');
  if(!box)return;
  if(q.trim().length<2){box.innerHTML='<div class="empty">Tape au moins 2 caractères.</div>';return}
  cbSearchTimer=setTimeout(async()=>{
    try{
      const d=await get('/api/search-players?q='+encodeURIComponent(q.trim())+'&limit=30');
      if(version!==cbSearchVersion||!box.isConnected)return;
      box.innerHTML=(d.rows||[]).map(p=>`<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${playerCircuitLabelV2(p)} · CA ${p.current_ability} · PA ${p.potential}</div></div><button class="ghost" onclick="addComparePlayerV2(${p.id})">Comparer</button></div></div>`).join('')||'<div class="empty">Aucun joueur.</div>';
    }catch(e){box.innerHTML=`<div class="empty">${esc(e.message)}</div>`}
  },180);
}
window.openGlobalSearch=window.openGlobalSearchV2;

window.openCustomPlayerCreatorV2=()=>{
  overlay.innerHTML=`
  <div class="modal" onclick="if(event.target===this)closeOverlay()">
    <div class="sheet">
      <div class="sheet-head">
        <div><div class="eyebrow">Nouvelle carrière</div><h1>Créer ton joueur</h1><div class="muted">Le profil sera ajouté à la base Court Boss puis utilisé pour une nouvelle carrière.</div></div>
        <button class="close" onclick="closeOverlay()">✕</button>
      </div>
      <div class="grid g2" style="margin-top:12px">
        <label class="card"><span class="muted mini">Nom</span><input id="cpName" class="input" value="Anthony" maxlength="60"></label>
        <label class="card"><span class="muted mini">Pays</span><select id="cpCountry" class="select"><option>FRA</option><option>USA</option><option>ESP</option><option>ITA</option><option>GBR</option><option>GER</option><option>AUS</option><option>CAN</option><option>BRA</option><option>SRB</option><option>SUI</option></select></label>
        <label class="card"><span class="muted mini">Âge</span><input id="cpAge" class="input" type="number" min="15" max="35" value="18"></label>
        <label class="card"><span class="muted mini">Potentiel</span><input id="cpPotential" class="input" type="number" min="55" max="99" value="86"></label>
        <label class="card"><span class="muted mini">Taille (cm)</span><input id="cpHeight" class="input" type="number" min="155" max="215" value="184"></label>
        <label class="card"><span class="muted mini">Poids (kg)</span><input id="cpWeight" class="input" type="number" min="45" max="130" value="78"></label>
        <label class="card"><span class="muted mini">Main</span><select id="cpHand" class="select"><option>Droitier</option><option>Gaucher</option></select></label>
        <label class="card"><span class="muted mini">Revers</span><select id="cpBackhand" class="select"><option>2 mains</option><option>1 main</option></select></label>
        <label class="card"><span class="muted mini">Style</span><select id="cpStyle" class="select"><option>All-court</option><option>Attaquant fond de court</option><option>Contreur</option><option>Serveur-attaquant</option><option>Spécialiste terre battue</option></select></label>
        <label class="card"><span class="muted mini">Niveau de départ</span><select id="cpTier" class="select"><option>Débutant</option><option selected>ITF</option><option>Challenger</option><option>Espoir</option></select></label>
      </div>
      <div class="notice" style="margin-top:12px">Les notes 1–20 sont des évaluations de jeu Court Boss basées sur le style, le niveau de départ et le potentiel choisi.</div>
      <button class="primary" style="margin-top:12px;width:100%" onclick="createCustomPlayerV2()">Créer et démarrer la carrière</button>
    </div>
  </div>`;
}

window.createCustomPlayerV2=async()=>{
  const payload={
    name:document.getElementById('cpName')?.value||'Anthony',
    country:document.getElementById('cpCountry')?.value||'FRA',
    age:Number(document.getElementById('cpAge')?.value||18),
    potential:Number(document.getElementById('cpPotential')?.value||86),
    height_cm:Number(document.getElementById('cpHeight')?.value||184),
    weight_kg:Number(document.getElementById('cpWeight')?.value||78),
    handedness:document.getElementById('cpHand')?.value||'Droitier',
    backhand:document.getElementById('cpBackhand')?.value||'2 mains',
    style:document.getElementById('cpStyle')?.value||'All-court',
    tier:document.getElementById('cpTier')?.value||'ITF'
  };
  if(String(payload.name).trim().length<2){alert('Entre un nom valide.');return}
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Création du joueur…</div></div></div>';
  try{
    const d=await managerAction('create_custom_player',0,payload);
    closeOverlay();
    await startCareerWithPlayer(d.player.id,d.player.name);
  }catch(e){
    overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Création impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`;
  }
}


window.renderPalmaresHtml=function(d,p){
  const titles=d?.titles||[];
  const cs=d?.careerStats||{};
  window.__cbPalmares={player:p,titles};

  const levels=titles.reduce((acc,t)=>{
    const raw=String(t.level||'ATP').trim();
    let key='Autres';
    if(/Grand Chelem|Grand Slam/i.test(raw))key='Grand Chelem';
    else if(/Masters 1000|Masters/i.test(raw))key='Masters 1000';
    else if(/^500$|ATP 500/i.test(raw))key='ATP 500';
    else if(/^250$|ATP 250/i.test(raw))key='ATP 250';
    else if(/Finals/i.test(raw))key='ATP Finals';
    else if(/^O$|Olymp/i.test(raw))key='Jeux olympiques';
    else if(/Challenger/i.test(raw))key='Challenger';
    else if(/Davis/i.test(raw))key='Coupe Davis';
    else if(/ATP Tour/i.test(raw))key='ATP Tour';
    acc[key]=(acc[key]||0)+1;
    return acc;
  },{});

  const surfaces={
    hard:titles.filter(t=>/Hard|Dur/i.test(String(t.surface||''))).length,
    clay:titles.filter(t=>/Clay|Terre/i.test(String(t.surface||''))).length,
    grass:titles.filter(t=>/Grass|Gazon/i.test(String(t.surface||''))).length
  };

  const years={};
  titles.forEach((t,i)=>{
    const y=String(t.title_date||'').slice(0,4)||'Sans date';
    (years[y]??=[]).push({...t,__i:i});
  });
  const yearRows=Object.entries(years).sort((a,b)=>Number(b[0])-Number(a[0]));
  const bestSeason=yearRows.length?yearRows.reduce((best,x)=>x[1].length>best[1].length?x:best,yearRows[0]):null;

  const repeated=Object.entries(titles.reduce((acc,t)=>{
    const k=String(t.tournament_name||'Tournoi');
    acc[k]=(acc[k]||0)+1;
    return acc;
  },{})).sort((a,b)=>b[1]-a[1]);

  const slamBreakdown={
    'Australian Open':titles.filter(t=>/Australian Open/i.test(String(t.tournament_name||''))).length,
    'Roland-Garros':titles.filter(t=>/Roland[ -]?Garros/i.test(String(t.tournament_name||''))).length,
    'Wimbledon':titles.filter(t=>/Wimbledon/i.test(String(t.tournament_name||''))).length,
    'US Open':titles.filter(t=>/US Open/i.test(String(t.tournament_name||''))).length
  };

  const first=titles.length?titles[titles.length-1]:null;
  const last=titles[0]||null;
  const totalMatches=Number(cs.wins||0)+Number(cs.losses||0);
  const winPct=totalMatches?Math.round(Number(cs.wins||0)/totalMatches*100):0;
  const pct=(w,l)=>{
    const n=Number(w||0)+Number(l||0);
    return n?Math.round(Number(w||0)/n*100):0;
  };

  const catOrder=['Grand Chelem','Masters 1000','ATP Finals','ATP 500','ATP 250','Jeux olympiques','ATP Tour','Challenger','Coupe Davis','Autres'];

  return `
    <div class="grid g2">
      <div class="card">
        <div class="row between"><h2>Résumé du palmarès</h2><span class="badge good">${titles.length} titre${titles.length>1?'s':''}</span></div>
        <div class="kpi-strip">
          <div class="kpi"><span class="muted mini">Grand Chelem</span><b>${levels['Grand Chelem']||0}</b></div>
          <div class="kpi"><span class="muted mini">Masters 1000</span><b>${levels['Masters 1000']||0}</b></div>
          <div class="kpi"><span class="muted mini">ATP 500</span><b>${levels['ATP 500']||0}</b></div>
          <div class="kpi"><span class="muted mini">ATP 250</span><b>${levels['ATP 250']||0}</b></div>
        </div>
        <div class="kpi-strip" style="margin-top:8px">
          <div class="kpi"><span class="muted mini">ATP Finals</span><b>${levels['ATP Finals']||0}</b></div>
          <div class="kpi"><span class="muted mini">JO</span><b>${levels['Jeux olympiques']||0}</b></div>
          <div class="kpi"><span class="muted mini">Premier titre</span><b style="font-size:12px">${first?df(first.title_date):'—'}</b></div>
          <div class="kpi"><span class="muted mini">Dernier titre</span><b style="font-size:12px">${last?df(last.title_date):'—'}</b></div>
        </div>
        ${bestSeason?`<div class="notice mini" style="margin-top:10px"><b>Meilleure saison :</b> ${bestSeason[0]} · ${bestSeason[1].length} trophée(s)${repeated[0]?` · tournoi le plus remporté : ${esc(repeated[0][0])} (${repeated[0][1]}×)`:''}</div>`:''}
      </div>

      <div class="card">
        <h2>Bilan carrière</h2>
        <div class="kpi-strip">
          <div class="kpi"><span class="muted mini">Victoires</span><b>${fmt(cs.wins||0)}</b></div>
          <div class="kpi"><span class="muted mini">Défaites</span><b>${fmt(cs.losses||0)}</b></div>
          <div class="kpi"><span class="muted mini">% victoires</span><b>${winPct}%</b></div>
          <div class="kpi"><span class="muted mini">Aces</span><b>${fmt(cs.aces||0)}</b></div>
        </div>
        <div class="list-item row between"><span>Dur</span><b>${fmt(cs.hard_wins||0)}-${fmt(cs.hard_losses||0)} · ${pct(cs.hard_wins,cs.hard_losses)}%</b></div>
        <div class="list-item row between"><span>Terre battue</span><b>${fmt(cs.clay_wins||0)}-${fmt(cs.clay_losses||0)} · ${pct(cs.clay_wins,cs.clay_losses)}%</b></div>
        <div class="list-item row between"><span>Gazon</span><b>${fmt(cs.grass_wins||0)}-${fmt(cs.grass_losses||0)} · ${pct(cs.grass_wins,cs.grass_losses)}%</b></div>
        <div class="muted micro" style="margin-top:8px">Source matchs : ${esc(cs.source||'non vérifié')} · snapshot ${cs.source_snapshot?df(cs.source_snapshot):'—'}.</div>
      </div>
    </div>

    <div class="grid g2" style="margin-top:12px">
      <div class="card">
        <h2>Titres par catégorie</h2>
        ${catOrder.map(k=>`<div class="list-item row between"><span>${k}</span><b>${levels[k]||0}</b></div>`).join('')}
        <h3 style="margin-top:14px">Grand Chelem en détail</h3>
        ${Object.entries(slamBreakdown).map(([name,n])=>`<div class="list-item row between ${n?'click':''}" ${n?`data-palmares-name="${name==='Roland-Garros'?'Roland Garros':name}"`:''}><span>${name}</span><b>${n}</b></div>`).join('')}
      </div>
      <div class="card">
        <h2>Titres par surface</h2>
        <div class="list-item row between"><span>Dur</span><b>${surfaces.hard}</b></div>
        <div class="list-item row between"><span>Terre battue</span><b>${surfaces.clay}</b></div>
        <div class="list-item row between"><span>Gazon</span><b>${surfaces.grass}</b></div>
        <div class="list-item row between"><span>Autres</span><b>${Math.max(0,titles.length-surfaces.hard-surfaces.clay-surfaces.grass)}</b></div>
        <h3 style="margin-top:14px">Tournois les plus remportés</h3>
        ${repeated.slice(0,6).map(([name,n])=>`<div class="list-item row between click" data-palmares-name="${esc(name)}"><span>${esc(name)}</span><b>${n}×</b></div>`).join('')||'<div class="empty">Aucun titre.</div>'}
      </div>
    </div>

    <div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Chronologie</div><h2>Palmarès année par année</h2></div><span class="pill">${yearRows.length} saison(s) titrée(s)</span></div>
      ${yearRows.length?yearRows.map(([year,rows])=>`
        <details class="list-item">
          <summary class="row between click"><b>${year}</b><span class="badge">${rows.length} titre${rows.length>1?'s':''}</span></summary>
          <div style="padding-top:8px">
            ${rows.map(t=>`<div class="list-item row between click" data-palmares-index="${t.__i}"><div><b>${esc(t.tournament_name)}</b><div class="muted mini">${esc(t.level||'ATP')} · ${esc(t.surface||'—')}</div></div><span class="badge good">🏆 ${df(t.title_date)}</span></div>`).join('')}
          </div>
        </details>
      `).join(''):'<div class="empty">Palmarès détaillé non importé pour ce joueur.</div>'}
    </div>
  `;
};

window.openPalmaresTitle=function(i){
  const data=window.__cbPalmares||{titles:[],player:{}};
  const t=(data.titles||[])[Number(i)];
  if(t)window.openPalmaresByName(t.tournament_name);
};

window.openPalmaresByName=function(name){
  const data=window.__cbPalmares||{titles:[],player:{}};
  const rows=(data.titles||[]).filter(t=>String(t.tournament_name||'')===String(name)).sort((a,b)=>String(b.title_date||'').localeCompare(String(a.title_date||'')));
  if(!rows.length)return;
  overlay.innerHTML=`
    <div class="modal" onclick="if(event.target===this)closeOverlay()">
      <div class="sheet">
        <div class="sheet-head">
          <div><div class="eyebrow">Palmarès · ${esc(data.player?.name||'Joueur')}</div><h1>${esc(String(name))}</h1><div class="muted">${rows.length} victoire${rows.length>1?'s':''} dans ce tournoi</div></div>
          <button class="close" onclick="closeOverlay()">✕</button>
        </div>
        <div class="stack" style="margin-top:12px">
          ${rows.map(t=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(t.level||'ATP')}</div><h2>${String(t.title_date||'').slice(0,4)}</h2></div><span class="badge good">🏆 ${esc(t.surface||'—')}</span></div><div class="muted mini">${df(t.title_date)}</div></div>`).join('')}
        </div>
      </div>
    </div>
  `;
};

document.addEventListener('click',e=>{
  const ix=e.target.closest?.('[data-palmares-index]');
  if(ix){window.openPalmaresTitle(Number(ix.dataset.palmaresIndex));return;}
  const nm=e.target.closest?.('[data-palmares-name]');
  if(nm)window.openPalmaresByName(nm.dataset.palmaresName);
});
