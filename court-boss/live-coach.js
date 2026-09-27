
let cbLiveSurface='Dur';

function matchPageLive(){
  const cr=career();
  return `
  <div class="card" style="margin-bottom:12px">
    <div class="row between">
      <div>
        <div class="eyebrow">Coaching en direct</div>
        <h2>Match set par set</h2>
        <div class="muted">Change la tactique entre les sets et observe le momentum.</div>
      </div>
      <button class="primary" onclick="openLiveCoachPicker()">Choisir un adversaire</button>
    </div>
    <div class="kpi-strip" style="margin-top:12px">
      <div class="kpi"><span class="muted mini">Forme</span><b>${cr.form||70}</b></div>
      <div class="kpi"><span class="muted mini">Fitness</span><b>${cr.fitness||90}</b></div>
      <div class="kpi"><span class="muted mini">Fatigue</span><b>${cr.fatigue||15}</b></div>
      <div class="kpi"><span class="muted mini">Plan</span><b style="font-size:12px">A${local.tactics?.aggression||58} / R${local.tactics?.risk||52}</b></div>
    </div>
  </div>` + matchPage();
}

window.openLiveCoachPicker=async function(){
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Recherche d’adversaires…</div></div></div>';
  try{
    const cr=career();
    const offset=Math.max(0,Number(cr.singles_rank||100)-16);
    const d=await get('/api/rankings?kind=singles&offset='+offset+'&limit=30');
    const rows=(d.rows||[]).filter(p=>p.name!==cr.player_name).slice(0,20);
    overlay.innerHTML=`
      <div class="modal" onclick="if(event.target===this)closeOverlay()">
        <div class="sheet">
          <div class="sheet-head">
            <div><div class="eyebrow">Live Coaching</div><h1>Choisir l’adversaire</h1></div>
            <button class="close" onclick="closeOverlay()">✕</button>
          </div>
          <div class="list-item row between" style="margin-top:12px">
            <span>Surface</span>
            <select class="select" style="width:auto" onchange="cbLiveSurface=this.value">
              <option>Dur</option><option>Terre</option><option>Gazon</option>
            </select>
          </div>
          <div class="stack" style="margin-top:12px">
            ${rows.map(p=>`
              <div class="card click" onclick="startLiveCoach(${p.id})">
                <div class="row between">
                  <div><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">ATP #${p.ranking} · CA ${p.current_ability} · forme ${p.form}</div></div>
                  <span class="badge">Jouer</span>
                </div>
              </div>`).join('')}
          </div>
        </div>
      </div>`;
  }catch(e){
    overlay.innerHTML='<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur</h2><p>'+esc(e.message)+'</p></div></div>';
  }
};

window.startLiveCoach=async function(opponentId){
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Préparation du match…</div></div></div>';
  try{
    const d=await get('/api/live-match/start',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({opponent_id:opponentId,surface:cbLiveSurface,tactics:local.tactics||{}})
    });
    const state=await get('/api/live-match/state?id='+d.session.id);
    renderLiveCoach(state);
  }catch(e){
    overlay.innerHTML='<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Match impossible</h2><p>'+esc(e.message)+'</p></div></div>';
  }
};

window.liveSetTactic=function(k,v){
  local.tactics=local.tactics||{};
  local.tactics[k]=['aggression','risk','net'].includes(k)?Number(v):v;
  persist();
};

function renderLiveCoach(d){
  const s=d.session,opp=s.opponent||{},events=d.events||[];
  const t=local.tactics||{aggression:58,risk:52,net:28,returnPos:'Neutre'};
  const complete=s.status==='completed';
  overlay.innerHTML=`
    <div class="modal">
      <div class="sheet">
        <div class="sheet-head">
          <div>
            <div class="eyebrow">Live Coaching · ${esc(s.surface)}</div>
            <h1>${esc(career().player_name||'Anthony')} ${s.user_sets} - ${s.opponent_sets} ${esc(opp.name||'Adversaire')}</h1>
            <div class="muted">Set ${Math.max(1,s.set_no)} · momentum ${s.momentum}/100</div>
          </div>
          <button class="close" onclick="closeOverlay()">✕</button>
        </div>
        <div class="bar" style="margin-top:12px"><i style="width:${s.momentum}%"></i></div>

        <div class="grid g2" style="margin-top:12px">
          <div class="card">
            <h2>Plan de jeu</h2>
            <div class="list-item"><div class="row between"><span>Agressivité</span><b>${t.aggression}%</b></div><input class="range" type="range" min="1" max="100" value="${t.aggression}" oninput="liveSetTactic('aggression',this.value)"></div>
            <div class="list-item"><div class="row between"><span>Prise de risque</span><b>${t.risk}%</b></div><input class="range" type="range" min="1" max="100" value="${t.risk}" oninput="liveSetTactic('risk',this.value)"></div>
            <div class="list-item"><div class="row between"><span>Montées au filet</span><b>${t.net}%</b></div><input class="range" type="range" min="1" max="100" value="${t.net}" oninput="liveSetTactic('net',this.value)"></div>
            <div class="list-item row between"><span>Position retour</span><select class="select" style="width:auto" onchange="liveSetTactic('returnPos',this.value)"><option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option><option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option></select></div>
          </div>
          <div class="card">
            <h2>Adversaire</h2>
            <div class="list-item row between"><span>Classement</span><b>#${opp.ranking||'—'}</b></div>
            <div class="list-item row between"><span>Style</span><b>${esc(opp.style||'—')}</b></div>
            <div class="list-item row between"><span>Forme</span><b>${opp.form||'—'}</b></div>
            <div class="list-item row between"><span>Fatigue</span><b>${opp.fatigue||0}</b></div>
          </div>
        </div>

        <div class="section-head" style="margin-top:14px"><div><div class="eyebrow">Déroulé</div><h2>Sets</h2></div></div>
        <div class="stack">
          ${events.map(e=>`
            <div class="card">
              <div class="row between">
                <div><b>Set ${e.set_no}</b><div class="muted mini">${esc(e.summary||'')}</div></div>
                <div style="text-align:right"><div class="big" style="font-size:22px">${esc(e.set_score)}</div><span class="badge ${e.user_won?'good':'bad'}">${e.user_won?'Gagné':'Perdu'}</span></div>
              </div>
              <div class="kpi-strip" style="margin-top:8px">
                <div class="kpi"><span class="muted mini">1res</span><b>${e.stats?.first_serve_pct||0}%</b></div>
                <div class="kpi"><span class="muted mini">Winners</span><b>${e.stats?.winners||0}</b></div>
                <div class="kpi"><span class="muted mini">Fautes</span><b>${e.stats?.unforced_errors||0}</b></div>
                <div class="kpi"><span class="muted mini">Filet</span><b>${e.stats?.net_points_won_pct||0}%</b></div>
              </div>
            </div>`).join('')||'<div class="card empty">Le match n’a pas encore commencé.</div>'}
        </div>

        <div class="row" style="margin-top:14px;justify-content:flex-end">
          ${complete?'<button class="primary" onclick="finishLiveCoach()">Terminer</button>':`<button class="primary" onclick="advanceLiveCoach(${s.id})">Jouer le set suivant</button>`}
        </div>
      </div>
    </div>`;
}

window.advanceLiveCoach=async function(sessionId){
  try{
    await get('/api/live-match/advance',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({session_id:sessionId,tactics:local.tactics||{}})
    });
    const d=await get('/api/live-match/state?id='+sessionId);
    renderLiveCoach(d);
  }catch(e){alert(e.message)}
};

window.finishLiveCoach=async function(){
  boot=await get('/api/bootstrap');
  if(boot.career)local.career={...(local.career||{}),...boot.career};
  await loadSeasonSummary();
  local.feed=local.feed||[];
  local.feed.unshift('Match coaché en direct terminé. Condition et forme mises à jour.');
  local.feed=local.feed.slice(0,8);
  persist();
  closeOverlay();
  shell(matchPageLive());
};

const cbLiveBaseRender=window.render;
window.render=function(){
  if(route==='match')return shell(matchPageLive());
  return cbLiveBaseRender();
};
