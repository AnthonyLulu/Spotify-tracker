
let cbDoublesTournaments=[];
let cbSeasonHistory=[];

async function loadCbDoublesTournaments(){
  try{
    const d=await get('/api/tournaments?offset=0&limit=60');
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
  return cbBaseNav(r);
};

const cbBaseRender=window.render;
window.render=function(){
  if(route==='season')return shell(seasonPageV2());
  if(route==='doubles'&&cbDoublesTournaments.length)return shell(doublesPageV2());
  return cbBaseRender();
};

window.rolloverSeasonV2=rolloverSeasonV2;
