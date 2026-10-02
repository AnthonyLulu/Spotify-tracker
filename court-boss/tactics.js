function tacticsPage(){
  const t={aggression:58,risk:52,net:28,returnPos:'Neutre',effort:60,tempo:'Neutre',targetWing:'Mixte',servePattern:'Mixte',spin:'Mixte',...(local.tactics||{})};
  const intensity=Math.round((Number(t.aggression||0)+Number(t.risk||0)+Number(t.effort||0))/3);
  const style=Number(t.aggression)>70?'Attaque':Number(t.risk)<40?'Contrôle':Number(t.net)>60?'Jeu vers l’avant':'Équilibré';
  const select=(key,values)=>`<select class="select" style="width:auto" onchange="updatePreparedTactic('${key}',this.value)">${values.map(v=>`<option ${String(t[key])===v?'selected':''}>${v}</option>`).join('')}</select>`;
  return `
    <div class="section-head">
      <div><div class="eyebrow">Préparation de match</div><h1>Tactique</h1><div class="muted">Prépare un plan précis. Les réglages sont appliqués au moteur point par point et aux simulations rapides.</div></div>
      <button class="primary" onclick="nav('match')">Match Center</button>
    </div>
    <div class="grid g2">
      <div class="card">
        <div class="row between"><h2>Plan de jeu</h2><span class="pill">${style}</span></div>
        ${[['Agressivité','aggression'],['Prise de risque','risk'],['Jeu au filet','net'],['Intensité physique','effort']].map(([label,key])=>`<div class="list-item"><div class="row between"><span>${label}</span><b id="value-${key}">${t[key]}%</b></div><input class="range" type="range" min="${key==='effort'?20:1}" max="100" value="${t[key]}" oninput="updatePreparedTactic('${key}',this.value)"></div>`).join('')}
        <div class="list-item row between"><span>Position retour</span>${select('returnPos',['Avancée','Neutre','Reculée'])}</div>
      </div>
      <div class="card">
        <h2>Schémas avancés</h2>
        <div class="list-item row between"><span>Tempo</span>${select('tempo',['Patient','Neutre','Rapide'])}</div>
        <div class="list-item row between"><span>Côté ciblé</span>${select('targetWing',['Mixte','Revers','Coup droit'])}</div>
        <div class="list-item row between"><span>Cible service</span>${select('servePattern',['Mixte','T','Large','Corps'])}</div>
        <div class="list-item row between"><span>Effet dominant</span>${select('spin',['Mixte','Lift','Plat','Slice'])}</div>
        <div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Intensité</span><b>${intensity}</b></div><div class="kpi"><span class="muted mini">Filet</span><b>${t.net}%</b></div><div class="kpi"><span class="muted mini">Retour</span><b style="font-size:14px">${esc(t.returnPos)}</b></div></div>
        <div class="notice" style="margin-top:12px">Effort augmente la dépense physique. Tempo, effet, côté ciblé et schéma de service modifient réellement les points suivants.</div>
      </div>
    </div>
    <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Presets</div><h2>Plans rapides</h2></div></div>
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
  local.tactics[k]=['aggression','risk','net','effort'].includes(k)?Number(v):v;
  persist();
  const el=document.getElementById('value-'+k);
  if(el)el.textContent=local.tactics[k]+(['aggression','risk','net','effort'].includes(k)?'%':'');
};
window.applyTacticPreset=name=>{
  const presets={
    control:{aggression:42,risk:34,net:18,effort:54,returnPos:'Reculée',tempo:'Patient',targetWing:'Mixte',servePattern:'Mixte',spin:'Lift'},
    balanced:{aggression:58,risk:52,net:28,effort:60,returnPos:'Neutre',tempo:'Neutre',targetWing:'Mixte',servePattern:'Mixte',spin:'Mixte'},
    attack:{aggression:78,risk:70,net:38,effort:74,returnPos:'Avancée',tempo:'Rapide',targetWing:'Revers',servePattern:'Large',spin:'Plat'},
    serveVolley:{aggression:72,risk:60,net:78,effort:72,returnPos:'Avancée',tempo:'Rapide',targetWing:'Mixte',servePattern:'T',spin:'Slice'}
  };
  local.tactics={...(local.tactics||{}),...(presets[name]||presets.balanced)};
  persist();render();
};
window.tacticsPage=tacticsPage;
