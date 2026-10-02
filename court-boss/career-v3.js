(function careerV3Bootstrap(){
  const DEFAULT_PLAN=['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'];
  const DIFFICULTIES={
    discovery:{label:'Découverte',tag:'Accessible',desc:'Aides renforcées, progression plus rapide et davantage de marge sur la charge.',mult:'×1,12 entraînement'},
    normal:{label:'Normal',tag:'Équilibré',desc:'Expérience Court Boss standard. Progression, risque et décisions équilibrés.',mult:'×1,00 entraînement'},
    manager:{label:'Manager',tag:'Exigeant',desc:'La progression pardonne moins. La qualité du staff, du planning et de l’académie compte davantage.',mult:'×0,94 entraînement'},
    hardcore:{label:'Hardcore',tag:'Expert',desc:'Développement plus lent et gestion de charge plus punitive. Chaque mauvais choix laisse une trace.',mult:'×0,88 entraînement'}
  };
  const CAPACITY={1:2,2:4,3:6,4:8};
  const clampV=(v,a,b)=>Math.max(a,Math.min(b,Number(v)||a));
  const setupDefaults=()=>({
    step:1,
    managerName:String(local?.managerProfile?.name||'Anthony'),
    difficulty:String(local?.difficulty||'normal'),
    academyName:'Court Boss Academy',
    academyCountry:String(career()?.country||'FRA').toUpperCase(),
    academyLevel:2,
    selected:[],
    primaryId:null,
    results:[],
    query:'',
    country:'',
    loading:false,
    launching:false
  });
  let setup=setupDefaults();

  const difficultyLabel=key=>DIFFICULTIES[key]?.label||DIFFICULTIES.normal.label;
  const setupCapacity=()=>CAPACITY[Number(setup.academyLevel)||2]||4;
  const selectedPlayer=id=>setup.selected.find(p=>Number(p.id)===Number(id))||null;

  function playerPlan(id){
    const primary=Number(career()?.managed_player_id||0);
    if(Number(id)===primary)return Array.isArray(local.training)&&local.training.length?local.training:DEFAULT_PLAN.slice();
    local.playerTraining=local.playerTraining&&typeof local.playerTraining==='object'?local.playerTraining:{};
    if(!Array.isArray(local.playerTraining[String(id)])||!local.playerTraining[String(id)].length){
      local.playerTraining[String(id)]=DEFAULT_PLAN.slice();
    }
    return local.playerTraining[String(id)];
  }

  function academyRosterPlayers(){
    const rows=Array.isArray(management?.academyRoster)?management.academyRoster:[];
    const primaryId=Number(career()?.managed_player_id||0),out=[],seen=new Set(),c=career();
    if(primaryId){
      out.push({id:primaryId,name:c.player_name||'Joueur principal',country:c.country||'',ranking:c.singles_rank||0,age:c.age||null,primary:true});
      seen.add(primaryId);
    }
    for(const row of rows){
      const p=row?.players||{},id=Number(row?.player_id||p.id||0);
      if(!id||seen.has(id))continue;
      seen.add(id);
      out.push({id,name:p.name||'Joueur',country:p.country||'',ranking:p.ranking||0,age:p.age||null,primary:row?.squad_role==='Joueur principal',row});
    }
    return out.slice(0,8);
  }

  function trainingTargetId(){
    const roster=academyRosterPlayers(),primary=Number(career()?.managed_player_id||0),wanted=Number(local.trainingPlayerId||primary||0);
    return roster.some(p=>Number(p.id)===wanted)?wanted:(primary||Number(roster[0]?.id||0));
  }

  function styleOnce(){
    if(document.getElementById('cbCareerV3Style'))return;
    const style=document.createElement('style');
    style.id='cbCareerV3Style';
    style.textContent=`
      .cb-ng-modal{position:fixed;inset:0;background:rgba(1,7,5,.88);backdrop-filter:blur(12px);z-index:9999;display:flex;align-items:stretch;justify-content:center;padding:max(12px,env(safe-area-inset-top)) 10px max(12px,env(safe-area-inset-bottom))}
      .cb-ng-shell{width:min(980px,100%);height:100%;max-height:940px;background:linear-gradient(145deg,#0d1c16,#07110d 52%,#0a1712);border:1px solid rgba(255,255,255,.10);border-radius:24px;overflow:hidden;display:flex;flex-direction:column;box-shadow:0 30px 100px rgba(0,0,0,.55)}
      .cb-ng-head{padding:18px 20px 14px;border-bottom:1px solid rgba(255,255,255,.08);background:rgba(255,255,255,.025)}
      .cb-ng-brand{font-size:11px;text-transform:uppercase;letter-spacing:.18em;color:#8ed6b1;font-weight:900}
      .cb-ng-title{font-size:28px;line-height:1.05;margin:5px 0 4px}
      .cb-ng-steps{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-top:14px}
      .cb-ng-step{padding:9px 8px;border-radius:11px;border:1px solid rgba(255,255,255,.08);font-size:11px;color:#80938a;text-align:center;font-weight:800}
      .cb-ng-step.active{background:rgba(94,234,151,.12);border-color:rgba(94,234,151,.34);color:#d9ffe9}
      .cb-ng-step.done{color:#92d6b1}
      .cb-ng-body{overflow:auto;padding:18px 20px 22px;flex:1}
      .cb-ng-foot{padding:13px 20px;border-top:1px solid rgba(255,255,255,.08);display:flex;gap:8px;justify-content:space-between;background:#08110d}
      .cb-ng-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
      .cb-ng-difficulties{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-top:12px}
      .cb-ng-choice{padding:14px;border:1px solid rgba(255,255,255,.10);background:rgba(255,255,255,.025);border-radius:15px;cursor:pointer;transition:.16s ease}
      .cb-ng-choice:hover{transform:translateY(-1px);border-color:rgba(94,234,151,.28)}
      .cb-ng-choice.selected{border-color:#5eea97;background:rgba(94,234,151,.10);box-shadow:inset 0 0 0 1px rgba(94,234,151,.16)}
      .cb-ng-choice h3{margin:0 0 5px;font-size:16px}.cb-ng-choice p{margin:0;color:#91a69b;font-size:12px;line-height:1.45}
      .cb-ng-field{display:flex;flex-direction:column;gap:6px}.cb-ng-field>span{font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:#8da298;font-weight:800}
      .cb-ng-input{width:100%;box-sizing:border-box;background:#07100c;border:1px solid rgba(255,255,255,.12);color:#f3fff8;border-radius:11px;padding:12px 13px;font:inherit}
      .cb-ng-note{padding:12px 13px;border-radius:13px;background:rgba(82,162,255,.08);border:1px solid rgba(82,162,255,.18);font-size:12px;color:#bfd8cf;line-height:1.45}
      .cb-ng-roster{display:flex;gap:7px;flex-wrap:wrap;margin:10px 0}.cb-ng-chip{display:flex;align-items:center;gap:7px;padding:7px 9px;border-radius:999px;background:rgba(94,234,151,.08);border:1px solid rgba(94,234,151,.18);font-size:12px}.cb-ng-chip.primary{background:rgba(94,234,151,.16);border-color:rgba(94,234,151,.38)}
      .cb-ng-results{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:10px}.cb-ng-player{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:11px;border:1px solid rgba(255,255,255,.08);border-radius:13px;background:rgba(255,255,255,.02)}.cb-ng-player.selected{border-color:rgba(94,234,151,.36);background:rgba(94,234,151,.07)}
      .cb-ng-player-name{font-weight:850;font-size:13px}.cb-ng-player-meta{font-size:11px;color:#8fa399;margin-top:2px}.cb-ng-summary{display:grid;grid-template-columns:1fr 1fr;gap:10px}.cb-ng-summary .card{margin:0}
      .cb-training-switcher{display:flex;gap:7px;overflow-x:auto;padding:3px 0 10px;scrollbar-width:none}.cb-training-switcher::-webkit-scrollbar{display:none}.cb-training-player{flex:0 0 auto;min-width:145px;text-align:left;padding:9px 11px;border-radius:12px;border:1px solid rgba(255,255,255,.09);background:rgba(255,255,255,.025);color:inherit}.cb-training-player.active{border-color:rgba(94,234,151,.45);background:rgba(94,234,151,.10)}.cb-training-player b,.cb-training-player small{display:block}.cb-training-player small{color:#90a49a;margin-top:2px}
      @media(max-width:720px){.cb-ng-modal{padding:0}.cb-ng-shell{border-radius:0;max-height:none;border:0}.cb-ng-head,.cb-ng-body,.cb-ng-foot{padding-left:14px;padding-right:14px}.cb-ng-grid,.cb-ng-difficulties,.cb-ng-results,.cb-ng-summary{grid-template-columns:1fr}.cb-ng-title{font-size:24px}.cb-ng-step{font-size:10px;padding:8px 4px}}
    `;
    document.head.appendChild(style);
  }

  function stepsHtml(){
    const labels=['Manager','Académie','Joueurs','Validation'];
    return '<div class="cb-ng-steps">'+labels.map((x,i)=>{
      const n=i+1,cls=n===setup.step?'active':n<setup.step?'done':'';
      return '<div class="cb-ng-step '+cls+'">'+n+' · '+x+'</div>';
    }).join('')+'</div>';
  }

  function difficultyCard(key){
    const d=DIFFICULTIES[key],sel=setup.difficulty===key;
    return '<div class="cb-ng-choice '+(sel?'selected':'')+'" onclick="setNewCareerDifficulty(\''+key+'\')"><div class="row between"><h3>'+esc(d.label)+'</h3><span class="badge '+(key==='hardcore'?'bad':key==='manager'?'warn':key==='discovery'?'good':'')+'">'+esc(d.tag)+'</span></div><p>'+esc(d.desc)+'</p><div class="muted micro" style="margin-top:8px">'+esc(d.mult)+'</div></div>';
  }

  function resultsHtml(){
    if(setup.loading)return '<div class="loader" style="margin-top:16px">Recherche dans la base mondiale…</div>';
    if(!setup.results.length)return '<div class="empty" style="margin-top:12px">Recherche un nom ou lance une recherche vide pour afficher les meilleurs profils disponibles.</div>';
    return '<div class="cb-ng-results">'+setup.results.map(p=>{
      const sel=Boolean(selectedPlayer(p.id));
      return '<div class="cb-ng-player '+(sel?'selected':'')+'"><div><div class="cb-ng-player-name">'+esc(p.name)+'</div><div class="cb-ng-player-meta">'+esc(p.country||'—')+' · '+(p.ranking?'ATP #'+fmt(p.ranking):'Non classé')+' · '+(p.age??'—')+' ans'+(p.ncaa_current?' · NCAA':'')+'</div></div><button class="'+(sel?'ghost':'soft-btn')+'" onclick="toggleNewCareerPlayer('+Number(p.id)+')">'+(sel?'Retirer':'Ajouter')+'</button></div>';
    }).join('')+'</div>';
  }

  function stepBody(){
    if(setup.step===1){
      return '<div><div class="eyebrow">Profil manager</div><h2>Qui prend les décisions ?</h2><div class="cb-ng-grid" style="margin-top:12px"><label class="cb-ng-field"><span>Nom du manager</span><input class="cb-ng-input" value="'+esc(setup.managerName)+'" oninput="setNewCareerField(\'managerName\',this.value)"></label><label class="cb-ng-field"><span>Date de départ</span><input class="cb-ng-input" value="01/12/2025" disabled></label></div><div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Difficulté</div><h2>Choisis ton niveau de contrôle</h2></div><span class="badge">'+esc(difficultyLabel(setup.difficulty))+'</span></div><div class="cb-ng-difficulties">'+Object.keys(DIFFICULTIES).map(difficultyCard).join('')+'</div><div class="cb-ng-note" style="margin-top:12px">La difficulté n’est pas cosmétique : elle intervient dans le rendement d’entraînement, la progression des joueurs de l’académie et la tolérance de charge.</div></div>';
    }
    if(setup.step===2){
      const cap=setupCapacity();
      const structures=[
        [1,'Petite structure','2 joueurs','Départ resserré, gestion très individuelle.'],
        [2,'Standard','4 joueurs','Bon équilibre pour une première carrière.'],
        [3,'Performance','6 joueurs','Groupe large, planning plus exigeant.'],
        [4,'Élite','8 joueurs','Effectif complet, huit plans individuels possibles.']
      ];
      return '<div><div class="eyebrow">Structure</div><h2>Ton académie de départ</h2><div class="cb-ng-grid" style="margin-top:12px"><label class="cb-ng-field"><span>Nom de l’académie</span><input class="cb-ng-input" value="'+esc(setup.academyName)+'" oninput="setNewCareerField(\'academyName\',this.value)"></label><label class="cb-ng-field"><span>Pays</span><input class="cb-ng-input" maxlength="3" value="'+esc(setup.academyCountry)+'" oninput="setNewCareerField(\'academyCountry\',this.value.toUpperCase())"></label></div><div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Taille de structure</div><h2>Jusqu’à 8 joueurs</h2><div class="muted">La taille fixe le nombre maximal de joueurs que tu peux sélectionner au lancement.</div></div><span class="pill">'+cap+' joueurs max.</span></div><div class="cb-ng-difficulties">'+structures.map(x=>'<div class="cb-ng-choice '+(Number(setup.academyLevel)===x[0]?'selected':'')+'" onclick="setNewCareerAcademyLevel('+x[0]+')"><div class="row between"><h3>'+x[1]+'</h3><span class="badge">'+x[2]+'</span></div><p>'+x[3]+'</p></div>').join('')+'</div><div class="cb-ng-note" style="margin-top:12px">Le premier joueur sera ton joueur principal. Les autres rejoignent le groupe géré de l’académie et disposent chacun de leur propre entraînement hebdomadaire.</div></div>';
    }
    if(setup.step===3){
      const cap=setupCapacity();
      const chips=setup.selected.length?setup.selected.map(p=>'<div class="cb-ng-chip '+(Number(setup.primaryId)===Number(p.id)?'primary':'')+'"><span>'+esc(p.name)+'</span>'+(Number(setup.primaryId)===Number(p.id)?'<b>Principal</b>':'<button class="ghost" style="padding:2px 6px" onclick="setNewCareerPrimary('+Number(p.id)+')">Principal</button>')+'<button class="ghost" style="padding:2px 6px" onclick="toggleNewCareerPlayer('+Number(p.id)+')">✕</button></div>').join(''):'<span class="muted mini">Aucun joueur sélectionné.</span>';
      return '<div><div class="row between"><div><div class="eyebrow">Effectif de départ</div><h2>Choisis tes joueurs</h2><div class="muted">1 joueur minimum, jusqu’à '+cap+'. Choisis aussi lequel est le joueur principal du cockpit.</div></div><span class="pill">'+setup.selected.length+' / '+cap+'</span></div><div class="cb-ng-roster">'+chips+'</div><div class="cb-ng-grid"><label class="cb-ng-field"><span>Recherche</span><input id="cbNewGameQuery" class="cb-ng-input" value="'+esc(setup.query)+'" placeholder="Sinner, Shelton, Fonseca…" onkeydown="if(event.key===\'Enter\')searchNewCareerPlayers()" oninput="setNewCareerField(\'query\',this.value)"></label><label class="cb-ng-field"><span>Pays (optionnel)</span><input id="cbNewGameCountry" class="cb-ng-input" maxlength="3" value="'+esc(setup.country)+'" placeholder="FRA, ITA, USA…" onkeydown="if(event.key===\'Enter\')searchNewCareerPlayers()" oninput="setNewCareerField(\'country\',this.value.toUpperCase())"></label></div><button class="soft-btn" style="margin-top:9px" onclick="searchNewCareerPlayers()">Rechercher dans la base mondiale</button><div id="cbNewGameResults">'+resultsHtml()+'</div></div>';
    }
    const primary=selectedPlayer(setup.primaryId)||setup.selected[0];
    return '<div><div class="eyebrow">Validation</div><h2>Prêt à prendre le circuit</h2><div class="cb-ng-summary" style="margin-top:12px"><div class="card"><div class="eyebrow">Manager</div><h2>'+esc(setup.managerName||'Manager')+'</h2><div class="muted">Difficulté '+esc(difficultyLabel(setup.difficulty))+'</div></div><div class="card"><div class="eyebrow">Académie</div><h2>'+esc(setup.academyName||'Court Boss Academy')+'</h2><div class="muted">'+esc(setup.academyCountry||'FRA')+' · structure niveau '+setup.academyLevel+' · '+setupCapacity()+' places</div></div></div><div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Groupe géré</div><h2>'+setup.selected.length+' joueur'+(setup.selected.length>1?'s':'')+'</h2></div><span class="badge good">'+(primary?esc(primary.name):'Aucun principal')+'</span></div><div class="stack" style="margin-top:8px">'+setup.selected.map(p=>'<div class="list-item row between"><span><b>'+(Number(p.id)===Number(setup.primaryId)?'★ ':'')+esc(p.name)+'</b><div class="muted micro">'+esc(p.country||'—')+' · ATP '+(p.ranking?'#'+fmt(p.ranking):'—')+'</div></span><span class="badge">'+(Number(p.id)===Number(setup.primaryId)?'Principal':'Académie')+'</span></div>').join('')+'</div></div><div class="cb-ng-note" style="margin-top:12px">Au lancement, Court Boss réinitialise le monde géré au 01/12/2025, crée l’effectif, initialise les plans d’entraînement et génère les premiers messages manager.</div></div>';
  }

  function renderWizard(){
    styleOnce();
    const labels=['Manager','Académie','Joueurs','Validation'];
    const steps='<div class="cb-ng-steps">'+labels.map((x,i)=>{const n=i+1,cls=n===setup.step?'active':n<setup.step?'done':'';return '<div class="cb-ng-step '+cls+'">'+n+' · '+x+'</div>'}).join('')+'</div>';
    const canNext=setup.step===1?Boolean(String(setup.managerName||'').trim()):setup.step===2?Boolean(String(setup.academyName||'').trim()&&String(setup.academyCountry||'').trim()):setup.step===3?setup.selected.length>0&&Boolean(setup.primaryId):true;
    const footer='<div class="cb-ng-foot"><button class="ghost" onclick="'+(setup.step===1?'closeNewCareerWizard()':'newCareerPrevStep()')+'">'+(setup.step===1?'Annuler':'← Retour')+'</button>'+(setup.step<4?'<button class="primary" '+(canNext?'':'disabled')+' onclick="newCareerNextStep()">Continuer →</button>':'<button class="primary" '+(setup.launching?'disabled':'')+' onclick="launchConfiguredCareer()">'+(setup.launching?'Création de la carrière…':'Lancer la partie')+'</button>')+'</div>';
    overlay.innerHTML='<div class="cb-ng-modal"><div class="cb-ng-shell"><div class="cb-ng-head"><div class="row between"><div><div class="cb-ng-brand">Court Boss · Nouvelle partie</div><h1 class="cb-ng-title">Créer une carrière</h1><div class="muted mini">Monde de départ figé au 01/12/2025 · configuration façon manager</div></div><button class="close" onclick="closeNewCareerWizard()">✕</button></div>'+steps+'</div><div class="cb-ng-body">'+stepBody()+'</div>'+footer+'</div></div>';
  }

  window.closeNewCareerWizard=()=>{if(!setup.launching)closeOverlay()};
  window.setNewCareerField=(field,value)=>{if(field in setup)setup[field]=value};
  window.setNewCareerDifficulty=key=>{if(DIFFICULTIES[key]){setup.difficulty=key;renderWizard()}};
  window.setNewCareerAcademyLevel=level=>{
    setup.academyLevel=clampV(level,1,4);
    const cap=setupCapacity();
    if(setup.selected.length>cap){
      setup.selected=setup.selected.slice(0,cap);
      if(!setup.selected.some(p=>Number(p.id)===Number(setup.primaryId)))setup.primaryId=setup.selected[0]?.id||null;
    }
    renderWizard();
  };
  window.newCareerPrevStep=()=>{setup.step=clampV(setup.step-1,1,4);renderWizard()};
  window.newCareerNextStep=async()=>{
    if(setup.step===1&&!String(setup.managerName||'').trim())return alert('Entre un nom de manager.');
    if(setup.step===2&&(!String(setup.academyName||'').trim()||!String(setup.academyCountry||'').trim()))return alert('Complète les informations de l’académie.');
    if(setup.step===3&&(!setup.selected.length||!setup.primaryId))return alert('Choisis au moins un joueur et définis le joueur principal.');
    setup.step=clampV(setup.step+1,1,4);renderWizard();
    if(setup.step===3&&!setup.results.length)await window.searchNewCareerPlayers();
  };
  window.searchNewCareerPlayers=async()=>{
    setup.query=String(document.getElementById('cbNewGameQuery')?.value??setup.query??'').trim();
    setup.country=String(document.getElementById('cbNewGameCountry')?.value??setup.country??'').trim().toUpperCase().slice(0,3);
    setup.loading=true;renderWizard();
    try{
      const p=new URLSearchParams({offset:'0',limit:'50',circuit:'Tous réels'});
      if(setup.query)p.set('q',setup.query);
      if(setup.country)p.set('country',setup.country);
      const d=await get('/api/search-players?'+p.toString());
      setup.results=(d.rows||[]).filter(p=>String(p.career_status||'active')!=='retired');
    }catch(e){setup.results=[];alert('Recherche impossible : '+e.message)}
    finally{setup.loading=false;renderWizard()}
  };
  window.toggleNewCareerPlayer=id=>{
    id=Number(id);
    const existing=selectedPlayer(id);
    if(existing){
      setup.selected=setup.selected.filter(p=>Number(p.id)!==id);
      if(Number(setup.primaryId)===id)setup.primaryId=setup.selected[0]?.id||null;
    }else{
      if(setup.selected.length>=setupCapacity())return alert('Ta structure de départ est limitée à '+setupCapacity()+' joueurs.');
      const p=setup.results.find(x=>Number(x.id)===id);if(!p)return;
      setup.selected.push({id:Number(p.id),name:p.name,country:p.country,ranking:p.ranking,age:p.age,ncaa_current:p.ncaa_current});
      if(!setup.primaryId)setup.primaryId=Number(p.id);
    }
    renderWizard();
  };
  window.setNewCareerPrimary=id=>{if(selectedPlayer(id)){setup.primaryId=Number(id);renderWizard()}};

  window.openNewCareerWizard=()=>{
    if(typeof simulating!=='undefined'&&simulating)return alert('Une simulation est en cours.');
    if(typeof saveSlotBusy!=='undefined'&&saveSlotBusy)return alert('Une opération de sauvegarde est en cours.');
    if(local?.liveSessionId)return alert('Termine le match en cours avant de démarrer une nouvelle partie.');
    setup=setupDefaults();styleOnce();renderWizard();
  };
  window.startNewCareer=window.openNewCareerWizard;

  window.launchConfiguredCareer=async()=>{
    if(setup.launching)return;
    const primary=selectedPlayer(setup.primaryId)||setup.selected[0];
    if(!primary)return alert('Choisis un joueur principal.');
    setup.launching=true;renderWizard();
    try{
      const reset=await get('/api/new-career',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
      local=cleanCareerLocalState(reset.local_payload||{});
      local.difficulty=setup.difficulty;
      local.managerProfile={name:String(setup.managerName||'Manager').trim()};
      local.academySetup={name:String(setup.academyName||'Court Boss Academy').trim(),country:String(setup.academyCountry||primary.country||'FRA').toUpperCase(),level:Number(setup.academyLevel)||2};
      local.managedSquad=setup.selected.map(p=>({id:Number(p.id),name:p.name,country:p.country,primary:Number(p.id)===Number(primary.id)}));
      local.training=DEFAULT_PLAN.slice();
      local.playerTraining={};
      for(const p of setup.selected)if(Number(p.id)!==Number(primary.id))local.playerTraining[String(p.id)]=DEFAULT_PLAN.slice();
      local.trainingPlayerId=Number(primary.id);
      localStorage.setItem('cbLocal',JSON.stringify(local));
      invalidateCareerCaches();
      await managerAction('take_over_player',Number(primary.id),{
        date:'2025-12-01',
        difficulty:setup.difficulty,
        additional_player_ids:setup.selected.filter(p=>Number(p.id)!==Number(primary.id)).map(p=>Number(p.id)),
        manager_profile:{name:String(setup.managerName||'Manager').trim()},
        academy:{name:String(setup.academyName||'Court Boss Academy').trim(),country:String(setup.academyCountry||primary.country||'FRA').toUpperCase(),level:Number(setup.academyLevel)||2,recruitment_reach:Number(setup.academyLevel)||2,development_intensity:Number(setup.academyLevel)||2}
      });
      boot=await get('/api/bootstrap');
      local.career={...(local.career||{}),...(boot.career||{})};local.date=boot.career?.career_date||'2025-12-01';local.week=boot.career?.week??1;
      localStorage.setItem('cbLocal',JSON.stringify(local));
      await Promise.allSettled([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadCareerHub(true)]);
      saveSlots=[];setup.launching=false;
      await saveCareerSlot(0,'autosave',true);await loadSaveSlots();persist();closeOverlay();route='home';render();
    }catch(e){setup.launching=false;renderWizard();alert('Nouvelle carrière impossible : '+e.message)}
  };

  const legacyTraining=training;
  loadTrainingPreview=async function(force=false){
    if(trainingPreviewLoading)return trainingPreview;
    if(trainingPreview&&!force)return trainingPreview;
    trainingPreviewLoading=true;
    try{
      const pid=trainingTargetId(),plan=playerPlan(pid);
      trainingPreview=await get('/api/training-preview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({training:plan,player_id:pid,difficulty:local.difficulty||'normal'})});
      return trainingPreview;
    }catch(e){trainingPreview={error:e.message};return trainingPreview}
    finally{trainingPreviewLoading=false}
  };

  training=function(){
    const roster=academyRosterPlayers(),pid=trainingTargetId(),primary=Number(career()?.managed_player_id||0),currentPlan=playerPlan(pid);
    const originalPrimary=local.training,originalReport=local.lastTrainingReport;
    local.training=currentPlan;if(pid!==primary)local.lastTrainingReport=null;
    let html='';
    try{html=legacyTraining()}finally{local.training=originalPrimary;local.lastTrainingReport=originalReport}
    const selected=roster.find(p=>Number(p.id)===pid);
    const selector='<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Groupe géré · entraînement individuel</div><h2>'+(roster.length||1)+' joueur'+(roster.length>1?'s':'')+'</h2><div class="muted mini">Chaque joueur conserve son propre plan 7 jours. Les plans académie sont traités lors de la simulation hebdomadaire.</div></div><span class="badge">'+esc(difficultyLabel(local.difficulty||'normal'))+'</span></div><div class="cb-training-switcher" style="margin-top:10px">'+roster.map(p=>'<button class="cb-training-player '+(Number(p.id)===pid?'active':'')+'" onclick="setTrainingPlayer('+Number(p.id)+')"><b>'+(Number(p.id)===primary?'★ ':'')+esc(p.name)+'</b><small>'+(p.ranking?'ATP #'+fmt(p.ranking):'Académie')+(Number(p.id)===primary?' · principal':'')+'</small></button>').join('')+'</div>'+(selected?'<div class="muted micro">Plan affiché : '+esc(selected.name)+' · '+(Number(selected.id)===primary?'joueur principal':'joueur académie')+'</div>':'')+'</div>';
    return selector+html;
  };

  window.setTrainingPlayer=async id=>{local.trainingPlayerId=Number(id);playerPlan(Number(id));trainingPreview=null;localStorage.setItem('cbLocal',JSON.stringify(local));render();await loadTrainingPreview(true);render()};
  window.refreshTrainingPreview=async()=>{trainingPreview=null;await loadTrainingPreview(true);render()};
  window.setTraining=async(i,v)=>{
    const pid=trainingTargetId(),primary=Number(career()?.managed_player_id||0);
    if(pid===primary){local.training=Array.isArray(local.training)?local.training:DEFAULT_PLAN.slice();local.training[i]=v}
    else{local.playerTraining=local.playerTraining&&typeof local.playerTraining==='object'?local.playerTraining:{};const plan=playerPlan(pid);plan[i]=v;local.playerTraining[String(pid)]=plan}
    trainingPreview=null;persist();render();await loadTrainingPreview(true);render();
  };

  window.trainAcademyPlayer=async id=>{
    const pid=Number(id||0);if(!pid)return;
    local.trainingPlayerId=pid;
    playerPlan(pid);
    trainingPreview=null;
    localStorage.setItem('cbLocal',JSON.stringify(local));
    await nav('training');
  };

  const legacyLauncher=launcherPage;
  launcherPage=function(){
    let html=legacyLauncher();
    html=html.replace('Réinitialise la carrière gérée au 01/12/2025, puis ouvre la base mondiale pour choisir le joueur à manager. Tes slots manuels restent disponibles.','Assistant de création complet : difficulté, académie et sélection de 1 à 8 joueurs avant le lancement. Tes slots manuels restent disponibles.');
    html=html.replace('Choisir un joueur réel','Configurer la nouvelle partie');
    html=html.replace('<div class="eyebrow">Carrière active</div>','<div class="eyebrow">Carrière active</div><span class="badge" style="margin-left:6px">Difficulté '+esc(difficultyLabel(local.difficulty||'normal'))+'</span>');
    return html;
  };

  styleOnce();
})();
