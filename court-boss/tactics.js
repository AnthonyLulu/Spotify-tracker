function tacticsPage(){
  const t=local.tactics||{aggression:58,risk:52,net:28,returnPos:'Neutre'};
  const intensity=Math.round((Number(t.aggression||0)+Number(t.risk||0))/2);
  const style=Number(t.aggression)>68?'Attaque':Number(t.risk)<40?'Contrôle':'Équilibré';
  return `
    <div class="section-head">
      <div>
        <div class="eyebrow">Préparation de match</div>
        <h1>Tactique</h1>
        <div class="muted">Prépare ton plan de jeu puis applique-le au Match Center.</div>
      </div>
      <button class="primary" onclick="nav('match')">Match Center</button>
    </div>

    <div class="grid g2">
      <div class="card">
        <div class="row between"><h2>Plan de jeu</h2><span class="pill">${style}</span></div>
        <div class="list-item">
          <div class="row between"><span>Agressivité</span><b id="value-aggression">${t.aggression}%</b></div>
          <input class="range" type="range" min="1" max="100" value="${t.aggression}" oninput="updatePreparedTactic('aggression',this.value)">
        </div>
        <div class="list-item">
          <div class="row between"><span>Prise de risque</span><b id="value-risk">${t.risk}%</b></div>
          <input class="range" type="range" min="1" max="100" value="${t.risk}" oninput="updatePreparedTactic('risk',this.value)">
        </div>
        <div class="list-item">
          <div class="row between"><span>Jeu au filet</span><b id="value-net">${t.net}%</b></div>
          <input class="range" type="range" min="1" max="100" value="${t.net}" oninput="updatePreparedTactic('net',this.value)">
        </div>
        <div class="list-item row between">
          <span>Position retour</span>
          <select class="select" style="width:auto" onchange="updatePreparedTactic('returnPos',this.value)">
            <option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option>
            <option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option>
            <option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option>
          </select>
        </div>
      </div>

      <div class="card">
        <h2>Lecture du plan</h2>
        <div class="kpi-strip">
          <div class="kpi"><span class="muted mini">Intensité</span><b>${intensity}</b></div>
          <div class="kpi"><span class="muted mini">Filet</span><b>${t.net}%</b></div>
          <div class="kpi"><span class="muted mini">Retour</span><b style="font-size:14px">${esc(t.returnPos)}</b></div>
        </div>
        <div class="notice" style="margin-top:12px">Ces réglages sont utilisés par le match live et les simulations. Tu peux les modifier pendant le match.</div>
      </div>
    </div>

    <div class="section-head" style="margin-top:18px">
      <div><div class="eyebrow">Presets</div><h2>Plans rapides</h2></div>
    </div>
    <div class="row tactic-presets">
      <button class="soft-btn" onclick="applyTacticPreset('control')">Contrôle</button>
      <button class="soft-btn" onclick="applyTacticPreset('balanced')">Équilibré</button>
      <button class="soft-btn" onclick="applyTacticPreset('attack')">Attaque</button>
      <button class="soft-btn" onclick="applyTacticPreset('serveVolley')">Service-volée</button>
    </div>
  `;
}
window.updatePreparedTactic=(k,v)=>{
  local.tactics=local.tactics||{};
  local.tactics[k]=['aggression','risk','net'].includes(k)?Number(v):v;
  persist();
  const el=document.getElementById('value-'+k);
  if(el)el.textContent=local.tactics[k]+(k==='returnPos'?'':'%');
};
window.applyTacticPreset=name=>{
  const presets={
    control:{aggression:42,risk:34,net:18,returnPos:'Reculée'},
    balanced:{aggression:58,risk:52,net:28,returnPos:'Neutre'},
    attack:{aggression:78,risk:70,net:38,returnPos:'Avancée'},
    serveVolley:{aggression:72,risk:60,net:78,returnPos:'Avancée'}
  };
  local.tactics={...(local.tactics||{}),...(presets[name]||presets.balanced)};
  persist();render();
};
window.tacticsPage=tacticsPage;
