
let cbDoublesTournaments=[];
let cbSeasonHistory=[];
let cbMatchOpponents=[];
let cbLiveSession=null;
let cbLiveOpponent=null;
let cbLiveSurface='Dur';

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
  const uniq=[...new Map(pool.map(p=>[p.id,p])).values()].filter(p=>p.name!=='Anthony').slice(0,14);
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
            <div><div class="eyebrow">Double · ${esc(d.tournament?.name||'Tournoi')}</div><h1>${d.round==='Champion'?'🏆 Champions':esc(d.round)}</h1><div class="muted">Anthony / ${esc(d.partner?.name||'Partenaire')}</div></div>
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
                <div class="row between"><b>${esc(m.round_name)}</b><span class="badge ${m.winner_pair.includes('Anthony')?'good':'bad'}">${m.winner_pair.includes('Anthony')?'Victoire':'Défaite'}</span></div>
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
    await loadCbMatchOpponents();
    shell(liveMatchPageV2());
    return;
  }
  return cbBaseNav(r);
};

const cbBaseRender=window.render;
window.render=function(){
  if(route==='season')return shell(seasonPageV2());
  if(route==='doubles'&&cbDoublesTournaments.length)return shell(doublesPageV2());
  if(route==='match'&&cbMatchOpponents.length)return shell(liveMatchPageV2());
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

function liveMatchPageV2(){
  const cr=career();
  if(!cbLiveSession){
    return `
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
              <button class="primary" onclick="startLiveMatchV2(${p.id})">Jouer</button>
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
      <button class="ghost" onclick="resetLiveMatchV2()">Quitter</button>
    </div>

    <div class="card live-score">
      <div class="score-line">
        <div><span class="muted mini">JOUEUR</span><h2>Anthony</h2></div>
        <div class="score-pills"><span>${s.user_sets}</span><strong>${s.user_games}</strong></div>
      </div>
      <div class="score-line">
        <div><span class="muted mini">ADVERSAIRE</span><h2>${esc(o.name||'Adversaire')}</h2></div>
        <div class="score-pills"><span>${s.opponent_sets}</span><strong>${s.opponent_games}</strong></div>
      </div>
      <div class="muted mini" style="margin-top:8px">${s.serving_user?'🎾 '+esc(cr.player_name||'Joueur')+' au service':'🎾 '+esc(o.name||'Adversaire')+' au service'} · ${totalGames} jeu(x) dans le set</div>
    </div>

    <div class="grid g2" style="margin-top:12px">
      <div class="card">
        <h2>Momentum</h2>
        <div class="momentum-track"><i style="left:${50+momentum}%"></i></div>
        <div class="row between mini muted"><span>Adversaire</span><b>${momentum>0?'Anthony +'+momentum:momentum<0?'Adversaire '+Math.abs(momentum):'Équilibre'}</b><span>Anthony</span></div>
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
        :`<button class="primary" style="margin-top:12px;width:100%" onclick="advanceLiveMatchV2()">Jouer le prochain jeu</button>`}
    </div>

    <div class="card" style="margin-top:12px">
      <h2>Historique du score</h2>
      ${(s.score_log||[]).slice(-12).reverse().map(x=>`<div class="list-item row between"><span>Set ${x.set} · ${x.user_games}-${x.opponent_games}</span><b class="${x.winner_game===(cr.player_name||'Anthony')?'good':'bad'}">${esc(x.winner_game)}</b></div>`).join('')||'<div class="empty">Le match n’a pas encore commencé.</div>'}
    </div>`;
}

async function startLiveMatchV2(opponentId){
  try{
    const d=await get('/api/live-match/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({opponent_id:opponentId,surface:cbLiveSurface,tactics:local.tactics||{}})});
    cbLiveSession=d.session;cbLiveOpponent=d.opponent;
    shell(liveMatchPageV2());
  }catch(e){alert(e.message)}
}

async function advanceLiveMatchV2(){
  if(!cbLiveSession)return;
  try{
    const d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:cbLiveSession.id,tactics:local.tactics||{}})});
    cbLiveSession=d.session;cbLiveOpponent=d.opponent||cbLiveOpponent;
    if(d.completed){
      boot=await get('/api/bootstrap');
      if(boot.career)local.career={...(local.career||{}),...boot.career};
      await loadSeasonSummary();
      persist();
    }
    shell(liveMatchPageV2());
  }catch(e){alert(e.message)}
}

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
  cbLiveSession=null;cbLiveOpponent=null;
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
