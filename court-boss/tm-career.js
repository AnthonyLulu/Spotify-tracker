(() => {
  'use strict';

  const DEFAULT_PLAN = ['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'];
  const DIFFICULTIES = {
    discovery:{label:'Découverte',tag:'Accessible',training:1.12,injury:0.72,form:1.12,desc:'Plus tolérant sur la forme, la charge et la progression. Idéal pour apprendre les systèmes.'},
    normal:{label:'Normal',tag:'Équilibré',training:1.00,injury:1.00,form:1.00,desc:'Expérience Court Boss complète, sans bonus ni malus.'},
    manager:{label:'Manager',tag:'Exigeant',training:0.94,injury:1.18,form:0.90,desc:'La planification, le staff, la récupération et les choix de calendrier comptent davantage.'},
    hardcore:{label:'Hardcore',tag:'Simulation',training:0.88,injury:1.35,form:0.82,desc:'Très peu de marge : surcharge, mauvais staff et mauvaise forme coûtent cher.'}
  };
  const LEVELS = {
    1:{label:'Locale',capacity:2,reputation:34,budget:9000,reach:1,development:1},
    2:{label:'Régionale',capacity:4,reputation:50,budget:15000,reach:2,development:2},
    3:{label:'Internationale',capacity:6,reputation:66,budget:26000,reach:3,development:3},
    4:{label:'Élite',capacity:8,reputation:80,budget:45000,reach:4,development:4}
  };

  let draft = null;
  let searchRows = [];
  let searchBusy = false;
  let searchTimer = null;
  let baseStartNewCareer = window.startNewCareer;
  let baseTrainingPage = typeof training === 'function' ? training : null;
  let baseLoadTrainingPreview = typeof loadTrainingPreview === 'function' ? loadTrainingPreview : null;
  let tmInboxFilter = 'all';
  let tmInboxPlayerId = 0;

  function ensureLocalCareerConfig(){
    if(!local.difficulty)local.difficulty='normal';
    if(!local.managerProfile)local.managerProfile={name:'Manager Court Boss',country:'FRA',experience:'Rookie',style:'Développeur'};
    if(!local.academySetup)local.academySetup={mode:'existing',name:(boot&&boot.academy&&boot.academy.name)||'Court Boss Academy',country:(boot&&boot.academy&&boot.academy.country)||'FRA',level:Number((boot&&boot.academy&&boot.academy.academy_level)||2)};
    if(!Array.isArray(local.managedPlayerIds))local.managedPlayerIds=career() && career().managed_player_id ? [Number(career().managed_player_id)] : [];
    if(!local.primaryPlayerId)local.primaryPlayerId=Number((career()&&career().managed_player_id)||local.managedPlayerIds[0]||0)||null;
    if(!local.playerTraining||typeof local.playerTraining!=='object')local.playerTraining={};
    if(!local.trainingPlayerId)local.trainingPlayerId=local.primaryPlayerId;
    localStorage.setItem('cbLocal',JSON.stringify(local));
  }

  function cap(){
    const level=LEVELS[Number(draft&&draft.academy&&draft.academy.level)||2]||LEVELS[2];
    return level.capacity;
  }

  function selectedIds(){
    return (draft&&draft.players||[]).map(x=>Number(x.id)).filter(Boolean);
  }

  function difficultyCard(key){
    const d=DIFFICULTIES[key];
    const active=draft.difficulty===key?' active':'';
    return '<button class="tm-diff-card'+active+'" onclick="tmSetDifficulty(\''+key+'\')">'
      +'<span class="tm-diff-check">'+(draft.difficulty===key?'✓':'')+'</span>'
      +'<b>'+esc(d.label)+'</b><span class="badge">'+esc(d.tag)+'</span>'
      +'<small>'+esc(d.desc)+'</small>'
      +'</button>';
  }

  function stepsBar(){
    const labels=['Difficulté','Manager','Académie','Joueurs','Résumé'];
    return '<div class="tm-wizard-steps">'+labels.map((x,i)=>{
      const n=i+1,cls=n===draft.step?'active':n<draft.step?'done':'';
      return '<button class="'+cls+'" onclick="tmGoNewGameStep('+n+')"><span>'+n+'</span><b>'+esc(x)+'</b></button>';
    }).join('')+'</div>';
  }

  function wizardShell(body){
    overlay.innerHTML='<div class="modal tm-newgame-modal"><div class="sheet tm-newgame-sheet">'
      +'<div class="sheet-head"><div><div class="eyebrow">Court Boss · Nouvelle partie</div><h1>Créer une carrière</h1><div class="muted">Difficulté, identité du manager, académie et jusqu’à 8 joueurs.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>'
      +stepsBar()
      +'<div class="tm-wizard-body">'+body+'</div>'
      +'</div></div>';
  }

  function renderDifficulty(){
    wizardShell('<div class="tm-wizard-title"><div><div class="eyebrow">Étape 1/5</div><h2>Choisis la difficulté</h2><p class="muted">Elle agit sur la tolérance à la forme, la progression et le risque lié à une mauvaise charge d’entraînement.</p></div></div>'
      +'<div class="tm-diff-grid">'+Object.keys(DIFFICULTIES).map(difficultyCard).join('')+'</div>'
      +navButtons(false,true));
  }

  function renderManager(){
    const m=draft.manager;
    wizardShell('<div class="tm-wizard-title"><div><div class="eyebrow">Étape 2/5</div><h2>Ton profil de manager</h2><p class="muted">Ton expérience et ton style servent de contexte au staff et à la carrière. Tu pourras les faire évoluer.</p></div></div>'
      +'<div class="grid g2">'
      +'<label class="field"><span>Nom du manager</span><input id="tmMgrName" class="input" value="'+esc(m.name)+'" oninput="tmDraftManager(\'name\',this.value)"></label>'
      +'<label class="field"><span>Nationalité</span><input id="tmMgrCountry" class="input" maxlength="3" value="'+esc(m.country)+'" oninput="tmDraftManager(\'country\',this.value.toUpperCase())"></label>'
      +'<label class="field"><span>Expérience</span><select class="select" onchange="tmDraftManager(\'experience\',this.value)">'
      +['Rookie','Club','Circuit ITF','Circuit pro','Ancien joueur'].map(x=>'<option '+(x===m.experience?'selected':'')+'>'+esc(x)+'</option>').join('')+'</select></label>'
      +'<label class="field"><span>Style</span><select class="select" onchange="tmDraftManager(\'style\',this.value)">'
      +['Développeur','Tacticien','Préparateur','Recruteur','Gestionnaire'].map(x=>'<option '+(x===m.style?'selected':'')+'>'+esc(x)+'</option>').join('')+'</select></label>'
      +'</div>'+navButtons(true,true));
  }

  function academyLevelCards(){
    return Object.keys(LEVELS).map(k=>{
      const x=LEVELS[k],active=Number(draft.academy.level)===Number(k)?' active':'';
      return '<button class="tm-level-card'+active+'" onclick="tmSetAcademyLevel('+k+')">'
        +'<b>Niv. '+k+' · '+esc(x.label)+'</b><span>'+x.capacity+' joueurs max</span><small>Réseau '+x.reach+'/4 · développement '+x.development+'/4</small>'
        +'</button>';
    }).join('');
  }

  function renderAcademy(){
    const a=draft.academy;
    wizardShell('<div class="tm-wizard-title"><div><div class="eyebrow">Étape 3/5</div><h2>Choisis ton académie</h2><p class="muted">Le niveau fixe la capacité initiale. Le niveau Élite donne le droit de démarrer avec 8 joueurs.</p></div></div>'
      +'<div class="tm-choice-row">'
      +'<button class="'+(a.mode==='existing'?'active':'')+'" onclick="tmSetAcademyMode(\'existing\')"><b>Reprendre l’académie</b><small>Conserver la structure de départ</small></button>'
      +'<button class="'+(a.mode==='new'?'active':'')+'" onclick="tmSetAcademyMode(\'new\')"><b>Créer mon académie</b><small>Nom, pays et niveau de départ</small></button>'
      +'</div>'
      +'<div class="grid g2" style="margin-top:14px">'
      +'<label class="field"><span>Nom</span><input class="input" value="'+esc(a.name)+'" '+(a.mode==='existing'?'readonly':'')+' oninput="tmDraftAcademy(\'name\',this.value)"></label>'
      +'<label class="field"><span>Pays</span><input class="input" maxlength="3" value="'+esc(a.country)+'" '+(a.mode==='existing'?'readonly':'')+' oninput="tmDraftAcademy(\'country\',this.value.toUpperCase())"></label>'
      +'</div>'
      +'<div class="tm-level-grid">'+academyLevelCards()+'</div>'
      +'<div class="notice"><b>Capacité de départ : '+cap()+' joueurs.</b> Tu pourras faire évoluer les installations, le recrutement, le staff et la filière jeunes pendant la carrière.</div>'
      +navButtons(true,true));
  }

  function playerLine(p,selected){
    const tags=[];
    if(p.ranking)tags.push('ATP #'+fmt(p.ranking));
    if(p.doubles_ranking)tags.push('Double #'+fmt(p.doubles_ranking));
    if(p.itf_ranking)tags.push('ITF #'+fmt(p.itf_ranking));
    if(p.ncaa_current)tags.push('NCAA');
    if(p.junior_ranking)tags.push('Junior #'+fmt(p.junior_ranking));
    return '<div class="tm-player-pick '+(selected?'selected':'')+'">'
      +'<div class="tm-player-pick-main"><b>'+(flags[p.country]||'🏳️')+' '+esc(p.name)+'</b><small>'+esc(tags.join(' · ')||'Base mondiale')+'</small></div>'
      +(selected?'<button class="soft-btn" onclick="tmRemoveNewGamePlayer('+Number(p.id)+')">Retirer</button>':'<button class="primary" onclick="tmAddNewGamePlayer('+Number(p.id)+')">Ajouter</button>')
      +'</div>';
  }

  function renderPlayers(){
    const capacity=cap(),players=draft.players||[];
    const selected=new Set(selectedIds());
    const selectedHtml=players.length?players.map((p,i)=>
      '<div class="tm-selected-player '+(i===0?'primary-player':'')+'">'
      +'<span class="tm-slot">'+(i+1)+'</span><div><b>'+(flags[p.country]||'🏳️')+' '+esc(p.name)+'</b><small>'+(i===0?'Joueur principal':'Joueur académie')+'</small></div>'
      +(i>0?'<button class="ghost" onclick="tmMakePrimary('+Number(p.id)+')">Principal</button>':'<span class="badge good">Principal</span>')
      +'<button class="close mini-close" onclick="tmRemoveNewGamePlayer('+Number(p.id)+')">×</button></div>'
    ).join(''):'<div class="empty">Sélectionne au moins un joueur.</div>';
    const rows=searchRows.map(p=>playerLine(p,selected.has(Number(p.id)))).join('');
    wizardShell('<div class="tm-wizard-title"><div><div class="eyebrow">Étape 4/5</div><h2>Choisis tes joueurs</h2><p class="muted">Le premier est ton joueur principal. Les autres rejoignent vraiment ton académie et évoluent chaque semaine.</p></div><span class="tm-capacity '+(players.length>=capacity?'full':'')+'">'+players.length+'/'+capacity+'</span></div>'
      +'<div class="tm-selected-grid">'+selectedHtml+'</div>'
      +'<div class="tm-player-search"><input id="tmPlayerSearch" class="input" placeholder="Rechercher Sinner, Fils, Shelton, NCAA, junior…" oninput="tmQueuePlayerSearch(this.value)">'
      +'<div class="filters"><select id="tmPlayerCircuit" class="select" onchange="tmQueuePlayerSearch(document.getElementById(\'tmPlayerSearch\').value,true)">'
      +['Tous réels','ATP classés','ATP profond','ITF','Junior','NCAA','Double'].map(x=>'<option>'+esc(x)+'</option>').join('')+'</select>'
      +'<input id="tmPlayerCountry" class="input" maxlength="3" placeholder="Pays ex. FRA" oninput="tmQueuePlayerSearch(document.getElementById(\'tmPlayerSearch\').value,true)"></div>'
      +'<div id="tmPlayerSearchResults" class="tm-search-results">'+(searchBusy?'<div class="loader">Recherche…</div>':rows||'<div class="empty">Tape un nom ou utilise les filtres.</div>')+'</div></div>'
      +navButtons(true,players.length>0));
  }

  function renderSummary(){
    const d=DIFFICULTIES[draft.difficulty],a=draft.academy,l=LEVELS[Number(a.level)]||LEVELS[2],m=draft.manager;
    wizardShell('<div class="tm-wizard-title"><div><div class="eyebrow">Étape 5/5</div><h2>Résumé de la carrière</h2><p class="muted">Rien n’est réinitialisé avant que tu appuies sur Démarrer.</p></div></div>'
      +'<div class="grid g2">'
      +'<div class="card"><div class="eyebrow">Manager</div><h2>'+esc(m.name)+'</h2><div class="muted">'+esc(m.country)+' · '+esc(m.experience)+' · '+esc(m.style)+'</div></div>'
      +'<div class="card"><div class="eyebrow">Difficulté</div><h2>'+esc(d.label)+'</h2><div class="muted">'+esc(d.desc)+'</div></div>'
      +'<div class="card"><div class="eyebrow">Académie</div><h2>'+esc(a.name)+'</h2><div class="muted">'+esc(a.country)+' · '+esc(l.label)+' · '+l.capacity+' places</div></div>'
      +'<div class="card"><div class="eyebrow">Effectif</div><h2>'+draft.players.length+' joueur(s)</h2><div class="muted">'+draft.players.map((p,i)=>(i===0?'★ ':'')+p.name).join(' · ')+'</div></div>'
      +'</div>'
      +'<div class="notice" style="margin-top:12px"><b>Départ : 1 décembre 2025.</b> Les sauvegardes manuelles restent disponibles, mais la carrière active sera réinitialisée.</div>'
      +'<div class="tm-wizard-actions"><button class="ghost" onclick="tmGoNewGameStep(4)">Retour</button><button class="danger-btn tm-start-career" onclick="tmStartCareer()">Démarrer la carrière</button></div>');
  }

  function navButtons(back,next){
    return '<div class="tm-wizard-actions">'
      +(back?'<button class="ghost" onclick="tmGoNewGameStep('+(draft.step-1)+')">Retour</button>':'<button class="ghost" onclick="closeOverlay()">Annuler</button>')
      +(next?'<button class="primary" onclick="tmGoNewGameStep('+(draft.step+1)+')">Continuer</button>':'<button class="primary" disabled>Continuer</button>')
      +'</div>';
  }

  function renderWizard(){
    if(!draft)return;
    if(draft.step===1)return renderDifficulty();
    if(draft.step===2)return renderManager();
    if(draft.step===3)return renderAcademy();
    if(draft.step===4)return renderPlayers();
    return renderSummary();
  }

  window.openNewGameWizard = async function(){
    if(simulating||saveSlotBusy){alert('Une simulation ou une sauvegarde est en cours.');return;}
    if(local.liveSessionId||window.hasManagedLiveMatches?.()){alert('Termine ou abandonne les matchs en cours avant de démarrer une nouvelle partie.');return;}
    ensureLocalCareerConfig();
    const currentAcademy=(boot&&boot.academy)||{};
    draft={
      step:1,
      difficulty:local.difficulty||'normal',
      manager:{...(local.managerProfile||{name:'Manager Court Boss',country:'FRA',experience:'Rookie',style:'Développeur'})},
      academy:{
        mode:'new',
        name:'Court Boss Academy',
        country:String((career()&&career().country)||'FRA').toUpperCase(),
        level:2
      },
      players:[]
    };
    searchRows=[];
    if(!countryRows.length){try{await loadCountries()}catch{}}
    renderWizard();
  };

  window.startNewCareer = window.openNewGameWizard;

  window.tmSetDifficulty=function(key){
    if(DIFFICULTIES[key])draft.difficulty=key;
    renderWizard();
  };
  window.tmDraftManager=function(field,value){if(draft&&draft.manager)draft.manager[field]=value;};
  window.tmDraftAcademy=function(field,value){if(draft&&draft.academy)draft.academy[field]=value;};
  window.tmSetAcademyMode=function(mode){
    draft.academy.mode=mode;
    if(mode==='existing'){
      const a=(boot&&boot.academy)||{};
      draft.academy.name=a.name||'Court Boss Academy';
      draft.academy.country=a.country||'FRA';
      draft.academy.level=Number(a.academy_level||2);
    }
    renderWizard();
  };
  window.tmSetAcademyLevel=function(level){
    draft.academy.level=Number(level);
    while(draft.players.length>cap())draft.players.pop();
    renderWizard();
  };
  window.tmGoNewGameStep=function(step){
    step=Math.max(1,Math.min(5,Number(step)||1));
    if(step>=3&&String(draft.manager.name||'').trim().length<2){alert('Donne un nom à ton manager.');return;}
    if(step>=4&&String(draft.academy.name||'').trim().length<2){alert('Donne un nom à ton académie.');return;}
    if(step===5&&!draft.players.length){alert('Choisis au moins un joueur.');return;}
    draft.step=step;renderWizard();
  };

  window.tmQueuePlayerSearch=function(q,instant){
    if(searchTimer)clearTimeout(searchTimer);
    searchTimer=setTimeout(()=>tmNewGameSearch(q),instant?30:260);
  };

  window.tmNewGameSearch=async function(q){
    if(!draft||draft.step!==4)return;
    const circuit=document.getElementById('tmPlayerCircuit')?.value||'Tous réels';
    const country=String(document.getElementById('tmPlayerCountry')?.value||'').trim().toUpperCase();
    q=String(q||'').trim();
    if(q.length<2&&!country&&circuit==='Tous réels'){searchRows=[];renderWizard();return;}
    searchBusy=true;renderWizard();
    try{
      const p=new URLSearchParams({offset:'0',limit:'60',q,country,circuit,age_max:'99'});
      const data=await get('/api/search-players?'+p.toString());
      searchRows=(data.rows||[]).filter(x=>String(x.career_status||'active')!=='retired');
    }catch(e){
      searchRows=[];
    }finally{
      searchBusy=false;renderWizard();
      const input=document.getElementById('tmPlayerSearch');if(input){input.value=q;input.focus();}
      const cc=document.getElementById('tmPlayerCountry');if(cc)cc.value=country;
      const cs=document.getElementById('tmPlayerCircuit');if(cs)cs.value=circuit;
    }
  };

  window.tmAddNewGamePlayer=function(id){
    const capacity=cap();
    if(draft.players.length>=capacity){alert('Cette académie peut gérer '+capacity+' joueur(s) au départ. Monte son niveau pour ajouter plus de joueurs.');return;}
    if(selectedIds().includes(Number(id)))return;
    const p=searchRows.find(x=>Number(x.id)===Number(id));
    if(!p)return;
    draft.players.push({id:Number(p.id),name:p.name,country:p.country,ranking:p.ranking,doubles_ranking:p.doubles_ranking,itf_ranking:p.itf_ranking});
    renderWizard();
  };
  window.tmRemoveNewGamePlayer=function(id){
    draft.players=draft.players.filter(x=>Number(x.id)!==Number(id));
    renderWizard();
  };
  window.tmMakePrimary=function(id){
    const i=draft.players.findIndex(x=>Number(x.id)===Number(id));
    if(i<=0)return;
    const p=draft.players.splice(i,1)[0];draft.players.unshift(p);renderWizard();
  };

  window.tmStartCareer=async function(){
    if(!draft||!draft.players.length)return;
    if(!confirm('Démarrer cette nouvelle carrière ? La carrière active sera réinitialisée.'))return;
    const primary=draft.players[0],extras=draft.players.slice(1),level=LEVELS[Number(draft.academy.level)]||LEVELS[2];
    saveSlotBusy=true;
    try{
      const reset=await get('/api/new-career',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
      local=cleanCareerLocalState(reset.local_payload||{});
      localStorage.setItem('cbLocal',JSON.stringify(local));
      invalidateCareerCaches();
      await managerAction('take_over_player',Number(primary.id),{
        date:'2025-12-01',
        additional_player_ids:extras.map(x=>Number(x.id)),
        difficulty:draft.difficulty,
        manager_profile:draft.manager,
        academy:{
          mode:draft.academy.mode,
          name:draft.academy.name,
          country:draft.academy.country,
          level:Number(draft.academy.level),
          capacity:level.capacity,
          reputation:level.reputation,
          budget:level.budget,
          recruitment_reach:level.reach,
          development_intensity:level.development
        }
      });
      local.difficulty=draft.difficulty;
      local.managerProfile={...draft.manager};
      local.academySetup={...draft.academy,capacity:level.capacity};
      local.managedPlayerIds=draft.players.map(x=>Number(x.id));
      local.primaryPlayerId=Number(primary.id);
      local.activeManagedPlayerId=Number(primary.id);
      local.trainingPlayerId=Number(primary.id);
      local.playerTraining={};
      for(const p of draft.players)local.playerTraining[String(p.id)]=[...DEFAULT_PLAN];
      local.training=[...DEFAULT_PLAN];
      local.date='2025-12-01';local.week=1;local.entries=[];local.entryMeta={};local.doublesEntries=[];local.doublesEntryMeta={};local.partnerId=null;local.shortlist=[];local.playedTournaments={};
      localStorage.setItem('cbLocal',JSON.stringify(local));
      invalidateCareerCaches();
      boot=await get('/api/bootstrap');
      local.career={...(local.career||{}),...(boot.career||{})};
      local.date=boot.career?.career_date||local.date;local.week=boot.career?.week??1;
      await Promise.allSettled([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadCareerHub(true)]);
      saveSlotBusy=false;
      saveSlots=[];
      await saveCareerSlot(0,'autosave',true);
      await loadSaveSlots();
      persist();closeOverlay();route='home';render();
    }catch(e){
      alert('Nouvelle carrière impossible : '+e.message);
    }finally{
      saveSlotBusy=false;
    }
  };

  function academyRosterPlayers(){
    const rows=(management&&management.academyRoster)||[];
    return rows.map(r=>{
      const p=r.players||{};
      return {rosterId:Number(r.id),id:Number(p.id||r.player_id),name:p.name||r.display_name||'Joueur',country:p.country||'',role:r.squad_role||'',focus:r.development_focus||'Équilibré',sourceYouthId:r.source_youth_id};
    }).filter(x=>x.id);
  }

  function selectedTrainingId(){
    ensureLocalCareerConfig();
    const ids=academyRosterPlayers().map(x=>Number(x.id));
    const primary=Number((career()&&career().managed_player_id)||local.primaryPlayerId||0);
    let id=Number(local.trainingPlayerId||primary);
    if(!ids.includes(id)&&primary)id=primary;
    return id;
  }

  function planFor(id){
    const primary=Number((career()&&career().managed_player_id)||local.primaryPlayerId||0);
    if(Number(id)===primary)return local.training;
    if(!local.playerTraining)local.playerTraining={};
    if(!Array.isArray(local.playerTraining[String(id)]))local.playerTraining[String(id)]=[...DEFAULT_PLAN];
    return local.playerTraining[String(id)];
  }

  function focusFromPlan(plan){
    const counts={Service:0,Retour:0,'Fond de court':0,'Déplacements':0,Physique:0,Mental:0,Double:0};
    for(const s of plan||[]){
      if(s==='Service')counts.Service++;
      else if(s==='Retour')counts.Retour++;
      else if(s==='Coup droit'||s==='Revers')counts['Fond de court']++;
      else if(s==='Déplacements')counts['Déplacements']++;
      else if(s==='Endurance')counts.Physique++;
      else if(s==='Match play')counts.Mental++;
      else if(s==='Double')counts.Double++;
    }
    return Object.entries(counts).sort((a,b)=>b[1]-a[1])[0][1] ? Object.entries(counts).sort((a,b)=>b[1]-a[1])[0][0] : 'Équilibré';
  }

  loadTrainingPreview=async function(force=false){
    if(trainingPreviewLoading)return trainingPreview;
    if(trainingPreview&&!force)return trainingPreview;
    trainingPreviewLoading=true;
    try{
      const id=selectedTrainingId(),plan=planFor(id);
      trainingPreview=await get('/api/training-preview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({training:plan,player_id:id,difficulty:local.difficulty||'normal'})});
      return trainingPreview;
    }catch(e){
      trainingPreview={error:e.message};return trainingPreview;
    }finally{trainingPreviewLoading=false;}
  };

  window.tmSelectTrainingPlayer=async function(id){
    local.trainingPlayerId=Number(id);
    local.activeManagedPlayerId=Number(id);
    activeManagedContext=null;
    trainingPreview=null;
    persist();
    if(typeof loadActiveManagedContext==='function')await loadActiveManagedContext(true,Number(id)).catch(()=>{});
    render();
    await loadTrainingPreview(true);render();
  };

  window.trainAcademyPlayer=async function(id){
    ensureLocalCareerConfig();
    const target=Number(id||0);
    if(!target)return;
    local.trainingPlayerId=target;
    local.activeManagedPlayerId=target;
    activeManagedContext=null;
    trainingPreview=null;
    persist();
    if(typeof loadActiveManagedContext==='function')await loadActiveManagedContext(true,target).catch(()=>{});
    await nav('training');
    await loadTrainingPreview(true);
    render();
    window.scrollTo({top:0,behavior:'smooth'});
  };

  window.refreshTrainingPreview=async function(){trainingPreview=null;await loadTrainingPreview(true);render();};

  window.setTraining=async function(i,v){
    const id=selectedTrainingId(),primary=Number((career()&&career().managed_player_id)||local.primaryPlayerId||0);
    const plan=planFor(id);
    plan[Number(i)]=v;
    if(id===primary)local.training=plan;
    else{
      local.playerTraining[String(id)]=plan;
      const row=academyRosterPlayers().find(x=>Number(x.id)===id);
      if(row&&row.rosterId){
        try{await managerAction('academy_focus',row.rosterId,{focus:focusFromPlan(plan)})}catch(e){console.warn('academy focus',e)}
      }
    }
    trainingPreview=null;persist();render();await loadTrainingPreview(true);render();
  };

  if(baseTrainingPage){
    training=function(){
      ensureLocalCareerConfig();
      const roster=academyRosterPlayers();
      const primary=Number((career()&&career().managed_player_id)||local.primaryPlayerId||0);
      const selected=selectedTrainingId(),originalPlan=local.training,originalReport=local.lastTrainingReport;
      const secondary=selected!==primary;
      if(secondary){local.training=planFor(selected);local.lastTrainingReport=null;}
      let core=baseTrainingPage();
      if(secondary){local.training=originalPlan;local.lastTrainingReport=originalReport;}
      const lastAcademy=(local.lastAcademyTrainingReport&&Array.isArray(local.lastAcademyTrainingReport.players))
        ?local.lastAcademyTrainingReport.players.find(x=>Number(x.player_id)===selected):null;
      const strip='<div class="card tm-training-roster"><div class="row between"><div><div class="eyebrow">Académie · entraînement individuel</div><h2>Choisir le joueur à préparer</h2></div><span class="badge">'+esc((DIFFICULTIES[local.difficulty]||DIFFICULTIES.normal).label)+'</span></div>'
        +'<div class="tm-training-player-tabs">'+roster.map(x=>'<button class="'+(Number(x.id)===selected?'active':'')+'" onclick="tmSelectTrainingPlayer('+x.id+')"><b>'+(flags[x.country]||'🏳️')+' '+esc(x.name)+'</b><small>'+esc(x.role)+(Number(x.id)!==primary?' · '+esc(x.focus):' · principal')+'</small></button>').join('')+'</div>'
        +(secondary?'<div class="notice mini"><b>Plan individuel de '+esc((roster.find(x=>x.id===selected)||{}).name||'ce joueur')+'.</b> La dominante de la semaine alimente son focus académie et le moteur de progression de l’effectif.</div>':'')
        +(secondary&&lastAcademy?'<div class="tm-training-week-report"><span class="badge good">Dernière semaine</span><b>Charge '+Number(lastAcademy.load||0)+' · focus '+esc(lastAcademy.focus||'Équilibré')+'</b>'+(lastAcademy.improvement?'<small>Progression : '+esc(lastAcademy.improvement.attribute)+' '+lastAcademy.improvement.from+'→'+lastAcademy.improvement.to+'</small>':'<small>XP / adaptation accumulée, pas de palier visible cette semaine.</small>')+'</div>':'')
        +'</div>';
      return strip+core;
    };
  }

  const oldAcademy=typeof academy==='function'?academy:null;
  if(oldAcademy){
    academy=function(){
      ensureLocalCareerConfig();
      const level=Number((boot&&boot.academy&&boot.academy.academy_level)||local.academySetup?.level||2);
      const proCap=({1:2,2:4,3:6,4:8})[level]||8;
      const proUsed=((management&&management.academyRoster)||[]).filter(x=>x.status==='active'||!x.status).length;
      let html=oldAcademy();
      const anchor='<div class="kpi-strip">';
      const pro='<div class="notice tm-pro-capacity"><div><b>Effectif joueurs gérés : '+proUsed+'/'+proCap+'</b><span>'+esc((local.managerProfile&&local.managerProfile.name)||'Manager')+' · niveau '+level+'</span></div><button class="soft-btn" onclick="nav(\'training\')">Plans individuels</button></div>';
      if(html.includes(anchor))html=html.replace(anchor,pro+anchor);
      return html;
    };
  }

  const oldMedicalPage=typeof medicalPage==='function'?medicalPage:null;
  if(oldMedicalPage){
    medicalPage=function(){
      const core=oldMedicalPage();
      const rosterRows=(management&&management.academyRoster)||[];
      const primary=Number((career()&&career().managed_player_id)||local.primaryPlayerId||0);
      const active=rosterRows.filter(r=>String(r.status||'active')==='active'&&Number((r.players||{}).id||r.player_id||0)>0).slice(0,8);
      if(active.length<=1)return core;
      const known=boot.injuries||[];
      const block='<div class="card tm-squad-medical"><div class="row between"><div><div class="eyebrow">Groupe géré</div><h2>État médical de l’effectif</h2><div class="muted mini">Vue rapide des 1 à 8 joueurs avant de modifier les charges.</div></div><button class="soft-btn" onclick="nav(\'training\')">Plans individuels</button></div>'
        +'<div class="tm-squad-medical-grid">'+active.map(r=>{
          const p=r.players||{},id=Number(p.id||r.player_id),isPrimary=id===primary;
          const c0=isPrimary?career():p;
          const fatigue=Number(c0.fatigue??p.fatigue??0),fitness=Number(c0.fitness??p.fitness??90),form=Number(c0.form??p.form??70);
          const injury=known.find(i=>Number(i.player_id||i.players?.id||0)===id&&String(i.status||'Active')==='Active');
          const status=injury?String(injury.injury_type||'Blessure'):String(c0.injury_status||p.injury_status||'Fit');
          const danger=Boolean(injury)||status!=='Fit'||fatigue>=65||fitness<70;
          return '<div class="tm-squad-medical-row '+(danger?'warn':'')+'"><div><b>'+(isPrimary?'★ ':'')+(flags[p.country]||'🏳️')+' '+esc(p.name||'Joueur')+'</b><small>'+esc(status)+'</small></div><div class="tm-squad-medical-kpis"><span>Forme <b>'+form+'</b></span><span>Fit <b>'+fitness+'</b></span><span>Fatigue <b>'+fatigue+'</b></span></div><button class="soft-btn" onclick="trainAcademyPlayer('+id+')">Ajuster</button></div>';
        }).join('')+'</div></div>';
      const hook='<div class="grid g4">';
      return core.includes(hook)?core.replace(hook,block+hook):block+core;
    };
  }

  const oldCareerHubPage=typeof careerHubPage==='function'?careerHubPage:null;
  if(oldCareerHubPage){
    careerHubPage=function(){
      ensureLocalCareerConfig();
      let html=oldCareerHubPage();
      const roster=academyRosterPlayers();
      const primary=Number((career()&&career().managed_player_id)||local.primaryPlayerId||0);
      const rosterRows=(management&&management.academyRoster)||[];
      const rowById=new Map(rosterRows.map(r=>[Number((r.players||{}).id||r.player_id),r]));
      const block='<div class="card tm-managed-roster-card"><div class="row between"><div><div class="eyebrow">Groupe géré</div><h2>'+roster.length+' / 8 joueur'+(roster.length>1?'s':'')+'</h2><div class="muted mini">Vue manager rapide : état, rang, potentiel et accès direct au plan individuel.</div></div><button class="soft-btn" onclick="nav(\'academy\')">Academy Hub</button></div>'
        +'<div class="tm-managed-roster-grid">'+roster.map(x=>{
          const rr=rowById.get(Number(x.id))||{},p=rr.players||{},isPrimary=Number(x.id)===primary;
          const fatigue=Number(p.fatigue||0),fitness=Number(p.fitness||90),form=Number(p.form||70);
          const status=String(p.injury_status||'Fit');
          const danger=status!=='Fit'||fatigue>=65||fitness<70;
          const stars=Math.max(.5,Math.min(5,Math.round(Number(p.current_ability||0)/10)/2));
          const pot=Math.max(.5,Math.min(5,Math.round(Number(p.potential||0)/10)/2));
          return '<button class="tm-managed-player-card '+(danger?'warn':'')+'" onclick="trainAcademyPlayer('+Number(x.id)+')">'
            +'<div class="row between"><b>'+(isPrimary?'★ ':'')+(flags[x.country]||'🏳️')+' '+esc(x.name)+'</b><span class="badge '+(danger?'warn':'good')+'">'+(status!=='Fit'?esc(status):fatigue>=65?'Fatigue '+fatigue:'Disponible')+'</span></div>'
            +'<div class="tm-managed-player-meta"><span>'+(Number(p.ranking||0)?'ATP #'+fmt(p.ranking):'ATP NR')+'</span><span>Forme '+form+'</span><span>Fit '+fitness+'</span></div>'
            +'<div class="muted micro">Niveau '+stars.toFixed(1)+'★ · potentiel '+pot.toFixed(1)+'★ · '+esc(rr.development_focus||x.focus||'Équilibré')+'</div>'
            +'<small>Ouvrir son entraînement →</small>'
            +'</button>';
        }).join('')+'</div></div>';
      const hook='<div class="quick-grid">';
      if(html.includes(hook))html=html.replace(hook,block+hook);
      else html=block+html;
      return html;
    };
  }

  const senderByKind={
    career:'Direction',academy:'Directeur académie',training:'Coach principal',staff:'Direction sportive',
    contract:'Juridique',medical:'Médecin',scouting:'Scouting',sponsor:'Commercial',
    finance:'Finance',media:'Presse',davis:'Fédération',tournament:'Organisation tournoi',
    doubles:'Coach double',college:'NCAA'
  };
  const oldInbox=typeof inboxPage==='function'?inboxPage:null;
  if(oldInbox){
    inboxPage=function(){
      const all=[...(boot.inbox||[])].sort((a,b)=>Number(a.is_read)-Number(b.is_read)||({urgent:0,high:1,normal:2}[a.priority]??2)-({urgent:0,high:1,normal:2}[b.priority]??2)||String(b.created_at||'').localeCompare(String(a.created_at||'')));
      const roster=academyRosterPlayers();
      const playerMap=new Map(roster.map(x=>[Number(x.id),x]));
      const linkedPlayerId=x=>{
        const entityType=String(x?.related_entity_type||'');
        const direct=['player','academy_player'].includes(entityType)?Number(x?.related_entity_id||0):0;
        return Number(x?.action_payload?.player_id||direct||0);
      };
      const groups=[
        ['all','Tous',()=>true],
        ['decisions','Décisions',x=>x.decision_status==='pending'&&x.action_type&&x.action_type!=='open_route'],
        ['sport','Sport',x=>['tournament','training','doubles','career'].includes(String(x.kind||''))],
        ['academy','Académie',x=>['academy','scouting','college'].includes(String(x.kind||''))],
        ['staff','Staff',x=>['staff','contract'].includes(String(x.kind||''))],
        ['medical','Médical',x=>String(x.kind||'')==='medical'],
        ['business','Business',x=>['sponsor','finance','media'].includes(String(x.kind||''))]
      ];
      const finder=groups.find(g=>g[0]===tmInboxFilter)||groups[0];
      const rows=all.filter(finder[2]).filter(x=>!tmInboxPlayerId||linkedPlayerId(x)===tmInboxPlayerId);
      const unread=all.filter(x=>!x.is_read).length;
      const decisions=all.filter(x=>x.decision_status==='pending'&&x.action_type&&!['open_route'].includes(x.action_type)).length;
      return '<div class="section-head"><div><div class="eyebrow">Communication · Manager Inbox</div><h1>Boîte de réception</h1><div class="muted">'+unread+' non lu(s) · '+decisions+' décision(s) en attente</div></div><button class="soft-btn" onclick="markAllInboxRead()">Tout marquer lu</button></div>'
        +(roster.length>1?'<div class="tm-inbox-player-filter"><button class="'+(!tmInboxPlayerId?'active':'')+'" onclick="tmSetInboxPlayer(0)">Tout le groupe</button>'+roster.map(p=>'<button class="'+(tmInboxPlayerId===Number(p.id)?'active':'')+'" onclick="tmSetInboxPlayer('+Number(p.id)+')">'+(Number(p.id)===Number((career()||{}).managed_player_id)?'★ ':'')+esc(p.name)+'</button>').join('')+'</div>':'')
        +'<div class="tm-inbox-tabs">'+groups.map(g=>'<button class="'+(tmInboxFilter===g[0]?'active':'')+'" onclick="tmSetInboxFilter(\''+g[0]+'\')">'+esc(g[1])+' <span>'+all.filter(g[2]).length+'</span></button>').join('')+'</div>'
        +'<div class="stack">'+rows.map(x=>'<div class="card inbox-card '+(x.is_read?'':'is-unread')+' '+(x.priority==='high'||x.priority==='urgent'?'is-priority':'')+'" onclick="openInboxItem('+x.id+',\''+esc(x.action_route||'home')+'\')">'
          +'<div class="row between"><div><div class="eyebrow">'+esc(senderByKind[String(x.kind||'')]||'Court Boss')+' · '+(x.game_date?df(x.game_date):new Date(x.created_at).toLocaleDateString('fr-FR'))+'</div><span class="muted micro">'+esc(x.kind||'info')+'</span></div><div class="row"><span class="badge '+(x.priority==='high'||x.priority==='urgent'?'warn':'')+'">'+esc(x.priority||'normal')+'</span><span class="badge '+(x.is_read?'':'good')+'">'+(x.is_read?'Lu':'Nouveau')+'</span></div></div>'
          +(linkedPlayerId(x)&&playerMap.get(linkedPlayerId(x))?'<div class="muted micro" style="margin-top:6px">Joueur · <b>'+esc(playerMap.get(linkedPlayerId(x)).name)+'</b></div>':'')
          +'<h2>'+esc(x.title)+'</h2><p class="muted">'+esc(x.body)+'</p>'
          +(x.decision_status==='resolved'?'<span class="badge good">Décision prise</span>':x.decision_status==='expired'?'<span class="badge warn">Expiré</span>':'')
          +(x.action_type&&!['resolved','expired'].includes(String(x.decision_status||''))?'<div class="row" style="margin-top:10px;flex-wrap:wrap">'+inboxActionButton(x,x.action_type,x.action_label||'Ouvrir',x.action_payload,'primary')+inboxActionButton(x,x.secondary_action_type,x.secondary_action_label,x.secondary_action_payload,'soft-btn')+'</div>':'')
          +'</div>').join('')
        +(rows.length?'':'<div class="card empty">Aucun message dans cette catégorie.</div>')+'</div>';
    };
  }
  window.tmSetInboxFilter=function(value){tmInboxFilter=value||'all';render();};
  window.tmSetInboxPlayer=function(value){tmInboxPlayerId=Number(value||0);render();};

  const oldLauncher=typeof launcherPage==='function'?launcherPage:null;
  if(oldLauncher){
    launcherPage=function(){
      ensureLocalCareerConfig();
      let html=oldLauncher();
      html=html.replace('Réinitialise la carrière gérée au 01/12/2025, puis ouvre la base mondiale pour choisir le joueur à manager. Tes slots manuels restent disponibles.','Assistant complet façon Tennis Manager : difficulté, manager, académie et sélection de 1 à 8 joueurs. Tes slots manuels restent disponibles.');
      html=html.replace('Choisir un joueur réel','Créer une nouvelle carrière');
      return html;
    };
  }

  ensureLocalCareerConfig();
})();