(() => {
  'use strict';

  const DAYS=['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
  const SESSIONS=['Service','Retour','Coup droit','Revers','Déplacements','Endurance','Match play','Double','Récupération','Repos'];
  const INTENSITIES=['Léger','Normal','Élevé'];
  const LOADS={'Service':2,'Retour':2,'Coup droit':2,'Revers':2,'Déplacements':3,'Endurance':3,'Match play':3,'Double':2,'Récupération':-.75,'Repos':-1.25};
  const INTENSITY_MULT={'Léger':.78,'Normal':1,'Élevé':1.16};

  function primaryId(){
    return Number((career&&career())?.managed_player_id||local.primaryPlayerId||0);
  }

  function rosterPlayers(){
    const rows=(management&&management.academyRoster)||[];
    const primary=primaryId();
    const out=rows
      .filter(r=>String(r.status||'active')==='active')
      .map(r=>{
        const p=r.players||{};
        return {
          id:Number(p.id||r.player_id||0),
          name:String(p.name||r.display_name||'Joueur'),
          country:String(p.country||''),
          role:String(r.squad_role||'Académie'),
          focus:String(r.development_focus||'Équilibré'),
          sourceYouthId:r.source_youth_id??null
        };
      })
      .filter(x=>x.id&&x.sourceYouthId==null);
    if(primary&&!out.some(x=>x.id===primary)){
      const c=career();
      out.unshift({id:primary,name:String(c?.player_name||'Joueur'),country:String(c?.country||''),role:'Joueur principal',focus:'Équilibré',sourceYouthId:null});
    }
    return out.filter((x,i,a)=>a.findIndex(y=>y.id===x.id)===i).slice(0,8);
  }

  function legacyPlan(id){
    const p=primaryId();
    if(Number(id)===p)return Array.isArray(local.training)&&local.training.length?local.training.slice(0,7):[];
    const raw=local.playerTraining&&local.playerTraining[String(id)];
    return Array.isArray(raw)&&raw.length?raw.slice(0,7):[];
  }

  function defaultDailyFromLegacy(id){
    const legacy=legacyPlan(id);
    const base=legacy.length?legacy:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'];
    return DAYS.map((_,i)=>{
      const morning=String(base[i]||'Repos');
      const afternoon=morning==='Repos'?'Repos':morning==='Récupération'?'Repos':(i===5?'Récupération':'Récupération');
      return {
        morning,
        afternoon,
        intensity:(morning==='Repos'||morning==='Récupération'||i===6)?'Léger':'Normal'
      };
    });
  }

  function ensureDailyTraining(){
    if(!local.dailyTraining||typeof local.dailyTraining!=='object')local.dailyTraining={};
    for(const p of rosterPlayers()){
      const key=String(p.id);
      const row=local.dailyTraining[key];
      if(!Array.isArray(row)||row.length!==7){
        local.dailyTraining[key]=defaultDailyFromLegacy(p.id);
      }else{
        local.dailyTraining[key]=row.slice(0,7).map((d,i)=>({
          morning:SESSIONS.includes(String(d?.morning))?String(d.morning):String(legacyPlan(p.id)[i]||'Repos'),
          afternoon:SESSIONS.includes(String(d?.afternoon))?String(d.afternoon):'Récupération',
          intensity:INTENSITIES.includes(String(d?.intensity))?String(d.intensity):'Normal'
        }));
      }
    }
    syncAllLegacy();
  }

  function selectedId(){
    const ids=rosterPlayers().map(x=>x.id);
    const p=primaryId();
    let id=Number(local.trainingPlayerId||local.activeManagedPlayerId||p);
    if(!ids.includes(id))id=p||ids[0]||0;
    return id;
  }

  function dailyPlan(id){
    ensureDailyTraining();
    const key=String(id||selectedId());
    if(!Array.isArray(local.dailyTraining[key]))local.dailyTraining[key]=defaultDailyFromLegacy(Number(key));
    return local.dailyTraining[key];
  }

  function syncLegacy(id){
    const p=primaryId(),plan=dailyPlan(id);
    const legacy=plan.map(d=>d.morning);
    if(Number(id)===p)local.training=[...legacy];
    else{
      if(!local.playerTraining||typeof local.playerTraining!=='object')local.playerTraining={};
      local.playerTraining[String(id)]=[...legacy];
    }
  }

  function syncAllLegacy(){
    if(!local.dailyTraining)return;
    for(const id of Object.keys(local.dailyTraining)){
      const p=primaryId(),plan=local.dailyTraining[id];
      if(!Array.isArray(plan))continue;
      const legacy=plan.map(d=>String(d?.morning||'Repos'));
      if(Number(id)===p)local.training=[...legacy];
      else{
        if(!local.playerTraining||typeof local.playerTraining!=='object')local.playerTraining={};
        local.playerTraining[id]=legacy;
      }
    }
  }

  function sessionLoad(name){return Number(LOADS[String(name)]??1)}
  function dayLoad(day){
    const m=Number(INTENSITY_MULT[String(day?.intensity)]||1);
    return (sessionLoad(day?.morning)+sessionLoad(day?.afternoon))*m*.55;
  }
  function planLoad(plan){return Number((plan||[]).reduce((s,d)=>s+dayLoad(d),0).toFixed(1))}

  function isoDatePlus(date,days){
    const d=new Date(String(date||'2025-12-01')+'T12:00:00Z');
    d.setUTCDate(d.getUTCDate()+Number(days||0));
    return d.toISOString().slice(0,10);
  }
  function isoDow(date){
    const d=new Date(String(date)+'T12:00:00Z');
    const x=d.getUTCDay();
    return x===0?7:x;
  }
  function currentWeekDates(){
    const date=String(local.date||career()?.career_date||'2025-12-01');
    const dow=isoDow(date);
    const monday=isoDatePlus(date,-(dow-1));
    return DAYS.map((_,i)=>isoDatePlus(monday,i));
  }
  function nextDate(){return isoDatePlus(String(local.date||career()?.career_date||'2025-12-01'),1)}
  function nextDayIndex(){return isoDow(nextDate())-1}

  function allManagedIds(){
    const ids=new Set();
    const p=primaryId();if(p)ids.add(p);
    for(const x of rosterPlayers())if(x.id)ids.add(x.id);
    for(const x of (local.managedPlayerIds||[]))if(Number(x))ids.add(Number(x));
    return [...ids];
  }

  function todayPlanPayload(){
    ensureDailyTraining();
    const idx=nextDayIndex();
    const payload={};
    for(const id of allManagedIds()){
      const p=dailyPlan(id)[idx]||{morning:'Repos',afternoon:'Repos',intensity:'Léger'};
      payload[String(id)]={morning:p.morning,afternoon:p.afternoon,intensity:p.intensity};
    }
    return payload;
  }

  function template(name,focus){
    const dbl=String(focus||'').toLowerCase().includes('double');
    const sets={
      balanced:[
        ['Service','Retour','Normal'],
        ['Coup droit','Déplacements','Normal'],
        ['Revers','Match play','Normal'],
        ['Récupération','Repos','Léger'],
        [dbl?'Double':'Service','Retour','Normal'],
        ['Match play','Récupération','Léger'],
        ['Repos','Repos','Léger']
      ],
      pretournament:[
        ['Service','Retour','Normal'],
        ['Match play','Déplacements','Léger'],
        [dbl?'Double':'Coup droit','Récupération','Léger'],
        ['Service','Retour','Léger'],
        ['Récupération','Repos','Léger'],
        ['Repos','Repos','Léger'],
        ['Repos','Repos','Léger']
      ],
      physical:[
        ['Endurance','Déplacements','Élevé'],
        ['Service','Endurance','Normal'],
        ['Déplacements','Match play','Élevé'],
        ['Récupération','Repos','Léger'],
        ['Endurance','Déplacements','Normal'],
        ['Service','Récupération','Léger'],
        ['Repos','Repos','Léger']
      ],
      recovery:[
        ['Récupération','Repos','Léger'],
        ['Service','Récupération','Léger'],
        ['Repos','Repos','Léger'],
        ['Retour','Récupération','Léger'],
        ['Récupération','Repos','Léger'],
        ['Repos','Repos','Léger'],
        ['Repos','Repos','Léger']
      ],
      doubles:[
        ['Double','Service','Normal'],
        ['Retour','Double','Normal'],
        ['Déplacements','Double','Normal'],
        ['Récupération','Repos','Léger'],
        ['Service','Retour','Normal'],
        ['Match play','Double','Normal'],
        ['Repos','Repos','Léger']
      ],
      preseason:[
        ['Endurance','Déplacements','Élevé'],
        ['Service','Coup droit','Normal'],
        ['Endurance','Revers','Normal'],
        ['Récupération','Repos','Léger'],
        ['Déplacements','Match play','Élevé'],
        ['Service','Retour','Normal'],
        ['Repos','Repos','Léger']
      ]
    };
    return (sets[name]||sets.balanced).map(x=>({morning:x[0],afternoon:x[1],intensity:x[2]}));
  }

  window.setDailyTrainingSlot=async function(day,slot,value){
    ensureDailyTraining();
    const id=selectedId(),plan=dailyPlan(id);
    if(!plan[Number(day)])return;
    plan[Number(day)][slot==='afternoon'?'afternoon':'morning']=String(value);
    syncLegacy(id);
    trainingPreview=null;
    persist();
    render();
    try{await loadTrainingPreview(true)}catch{}
    render();
  };

  window.setDailyTrainingIntensity=async function(day,value){
    ensureDailyTraining();
    const id=selectedId(),plan=dailyPlan(id);
    if(!plan[Number(day)])return;
    plan[Number(day)].intensity=INTENSITIES.includes(String(value))?String(value):'Normal';
    syncLegacy(id);
    trainingPreview=null;
    persist();
    render();
    try{await loadTrainingPreview(true)}catch{}
    render();
  };

  window.applyDailyTrainingTemplate=async function(name){
    ensureDailyTraining();
    const id=selectedId();
    const focus=Number(id)===primaryId()?career()?.career_focus:(rosterPlayers().find(x=>x.id===id)?.focus||'');
    local.dailyTraining[String(id)]=template(String(name),focus);
    syncLegacy(id);
    trainingPreview=null;
    persist();
    render();
    try{await loadTrainingPreview(true)}catch{}
    render();
  };

  const oldSetTraining=window.setTraining;
  window.setTraining=async function(i,v){
    return window.setDailyTrainingSlot(i,'morning',v);
  };

  const previousLoadTrainingPreview=typeof loadTrainingPreview==='function'?loadTrainingPreview:null;
  loadTrainingPreview=async function(force=false){
    if(trainingPreviewLoading)return trainingPreview;
    if(trainingPreview&&!force)return trainingPreview;
    trainingPreviewLoading=true;
    try{
      const id=selectedId(),plan=dailyPlan(id);
      trainingPreview=await get('/api/training-preview',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({
          player_id:id,
          daily_training:plan,
          training:plan.map(d=>d.morning),
          difficulty:local.difficulty||'normal'
        })
      });
      return trainingPreview;
    }catch(e){
      trainingPreview={error:e.message};
      return trainingPreview;
    }finally{trainingPreviewLoading=false}
  };
  window.refreshTrainingPreview=async function(){trainingPreview=null;await loadTrainingPreview(true);render()};

  trainingLoad=function(){
    try{return planLoad(dailyPlan(primaryId()))}catch{return 0}
  };

  training=function(){
    ensureDailyTraining();
    const roster=rosterPlayers(),id=selectedId(),plan=dailyPlan(id);
    const player=roster.find(x=>x.id===id)||{name:career()?.player_name||'Joueur',country:career()?.country||'',role:'Joueur principal',focus:'Équilibré'};
    const p=trainingPreview&&!trainingPreview.error?trainingPreview:null;
    const load=planLoad(plan);
    const min=Number(p?.recommended_load?.min??9),max=Number(p?.recommended_load?.max??12);
    const risk=String(p?.risk||(load>max+2?'Élevé':load>max?'Modéré':'Maîtrisé'));
    const riskClass=risk==='Élevé'?'bad':risk==='Modéré'?'warn':'good';
    const dates=currentWeekDates(),today=String(local.date||career()?.career_date||''),tomorrow=nextDate();
    const report=local.lastDailyTrainingReport||null;
    const playerReport=Array.isArray(report?.training)?report.training.find(x=>Number(x.player_id)===Number(id)):null;
    const playerRecovery=playerReport?.recovery||null;
    const reportLabels={serve_power:'Puissance service',serve_precision:'Précision service',first_serve_quality:'1re balle',second_serve_quality:'2e balle',serve_variety:'Variété service',serve_spin:'Effet service',serve_consistency:'Régularité service',serve_plus_one:'Service +1',return_game:'Retour',return_aggression:'Retour agressif',return_consistency:'Régularité retour',counter_skill:'Contre',shot_control:'Contrôle de balle',timing:'Timing',forehand:'Coup droit',forehand_power:'Puissance CD',forehand_accuracy:'Précision CD',forehand_consistency:'Régularité CD',topspin:'Lift',backhand:'Revers',backhand_power:'Puissance revers',backhand_accuracy:'Précision revers',backhand_consistency:'Régularité revers',volley:'Volée',touch:'Toucher',movement:'Déplacements',speed:'Vitesse',acceleration:'Accélération',agility:'Agilité',balance:'Équilibre',footwork:'Jeu de jambes',athleticism:'Physique',stamina:'Endurance',strength:'Force',recovery:'Récupération',tactics:'Tactique',decision_making:'Décisions',shot_selection:'Choix de coups',big_points:'Points importants',concentration:'Concentration',composure:'Sang-froid',fighting_spirit:'Combativité',tenacity:'Ténacité',doubles:'Double',net_positioning:'Placement filet',doubles_communication:'Communication double',poaching:'Interceptions'};
    const options=s=>SESSIONS.map(x=>'<option '+(x===s?'selected':'')+'>'+esc(x)+'</option>').join('');
    const intensityOptions=v=>INTENSITIES.map(x=>'<option '+(x===v?'selected':'')+'>'+esc(x)+'</option>').join('');
    const dev=p?.development||{};
    const targets=(p?.targets||[]).slice(0,5);
    const warnings=p?.warnings||[];

    return '<div class="section-head"><div><div class="eyebrow">Performance · daily training V22</div><h1>Entraînement jour par jour</h1><div class="muted">Deux créneaux maximum par jour. Le travail crée de l’XP invisible avant les vrais paliers d’attribut.</div></div><button class="soft-btn" onclick="refreshTrainingPreview()">↻ Réanalyser</button></div>'
      +'<div class="card tm-training-roster"><div class="row between"><div><div class="eyebrow">Groupe géré</div><h2>'+esc(player.name)+'</h2></div><span class="badge">'+esc((local.difficulty||'normal'))+'</span></div>'
      +'<div class="tm-training-player-tabs">'+roster.map(x=>'<button class="'+(x.id===id?'active':'')+'" onclick="tmSelectTrainingPlayer('+x.id+')"><b>'+(flags[x.country]||'🏳️')+' '+esc(x.name)+'</b><small>'+esc(x.role)+(x.id===primaryId()?' · principal':' · '+esc(x.focus))+'</small></button>').join('')+'</div></div>'
      +'<div class="grid g3">'
      +'<div class="card"><div class="eyebrow">Charge semaine</div><div class="big">'+load.toFixed(1)+'</div><div class="muted">Zone conseillée '+min+'–'+max+'</div><div style="margin-top:8px"><span class="badge '+(load>=min&&load<=max?'good':'warn')+'">'+(load>=min&&load<=max?'Zone optimale':'À ajuster')+'</span></div></div>'
      +'<div class="card"><div class="eyebrow">Risque physique</div><div class="big">'+esc(risk)+'</div><div style="margin-top:8px"><span class="badge '+riskClass+'">Fatigue '+Number(p?.fatigue??career()?.fatigue??0)+'% · fitness '+Number(p?.fitness??career()?.fitness??90)+'%</span></div></div>'
      +'<div class="card"><div class="eyebrow">Qualité progression</div><div class="big">'+(p?.multiplier!=null?'×'+Number(p.multiplier).toFixed(2):'—')+'</div><div class="muted">Staff '+(p?.staff_score??'—')+'/20 · installations '+(p?.facility_score??'—')+'</div></div>'
      +'</div>'
      +'<div class="card daily-training-templates"><div class="row between"><div><div class="eyebrow">Plans rapides</div><h2>Cycle d’entraînement</h2></div><span class="pill">Prochain jour · '+df(tomorrow)+'</span></div><div class="daily-template-row">'
      +[['balanced','Équilibré'],['pretournament','Pré-tournoi'],['physical','Bloc physique'],['recovery','Récupération'],['doubles','Double'],['preseason','Pré-saison']].map(x=>'<button class="soft-btn" onclick="applyDailyTrainingTemplate(\''+x[0]+'\')">'+x[1]+'</button>').join('')
      +'</div></div>'
      +'<div class="card daily-training-week"><div class="row between"><div><div class="eyebrow">Semaine '+Number(local.week||1)+'</div><h2>Matin / après-midi</h2></div><span class="badge">2 blocs max / jour</span></div>'
      +'<div class="daily-training-grid">'+plan.map((d,i)=>{
        const date=dates[i],passed=date<today,isToday=date===today,isNext=date===tomorrow;
        return '<div class="daily-training-day '+(passed?'past ':'')+(isToday?'today ':'')+(isNext?'next ':'')+'">'
          +'<div class="daily-day-head"><div><b>'+DAYS[i]+'</b><small>'+df(date)+'</small></div>'+(isToday?'<span class="badge">Aujourd’hui</span>':isNext?'<span class="badge good">Prochain</span>':passed?'<span class="muted micro">passé</span>':'')+'</div>'
          +'<label><span>Matin</span><select class="select" onchange="setDailyTrainingSlot('+i+',\'morning\',this.value)">'+options(d.morning)+'</select></label>'
          +'<label><span>Après-midi</span><select class="select" onchange="setDailyTrainingSlot('+i+',\'afternoon\',this.value)">'+options(d.afternoon)+'</select></label>'
          +'<label><span>Intensité</span><select class="select" onchange="setDailyTrainingIntensity('+i+',this.value)">'+intensityOptions(d.intensity)+'</select></label>'
          +'<div class="daily-load"><span>Charge</span><b>'+dayLoad(d).toFixed(1)+'</b></div>'
          +'</div>';
      }).join('')+'</div><div class="muted mini" style="margin-top:10px">Les jours déjà passés servent de modèle pour la prochaine semaine si tu ne modifies pas le cycle. Les journées futures s’appliquent immédiatement.</div></div>'
      +(targets.length?'<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Rendement estimé</div><h2>Axes qui lui profitent le plus</h2></div><span class="badge">'+esc(p?.career_focus||career()?.career_focus||'mixed')+'</span></div><div class="stack" style="margin-top:8px">'+targets.map((t,i)=>'<div class="list-item row between"><span><b>#'+(i+1)+' '+esc(t.session)+'</b></span><span class="badge '+(i<2?'good':'')+'">indice '+Number(t.score).toFixed(2)+'</span></div>').join('')+'</div></div>':'')
      +(warnings.length?'<div class="card" style="margin-top:12px"><div class="eyebrow">Alertes du staff</div><h2>À surveiller</h2><div class="stack" style="margin-top:8px">'+warnings.map(w=>'<div class="list-item"><span class="badge warn">!</span> '+esc(w)+'</div>').join('')+'</div></div>':'')
      +'<div class="grid g2" style="margin-top:12px"><div class="card"><div class="eyebrow">Profil de développement</div><h2>'+esc(dev.type||'standard')+'</h2><div class="list-item row between"><span>Phase</span><b>'+esc(dev.phase||'—')+'</b></div><div class="list-item row between"><span>Développement</span><b>'+(dev.development_rate??'—')+'/20</b></div><div class="list-item row between"><span>Professionnalisme</span><b>'+(dev.professionalism??'—')+'/20</b></div><div class="list-item row between"><span>Coachability</span><b>'+(dev.coachability??'—')+'/20</b></div><div class="list-item row between"><span>Pic</span><b>'+(dev.peak_age??'—')+' ans</b></div></div>'
      +'<div class="card"><div class="eyebrow">Dernière journée</div><h2>'+(report?.date?df(report.date):'Aucune journée simulée')+'</h2>'
      +(playerReport?'<div class="list-item row between"><span>Séances</span><b>'+esc(playerReport.morning)+' / '+esc(playerReport.afternoon)+'</b></div><div class="list-item row between"><span>Charge</span><b>'+Number(playerReport.load||0).toFixed(1)+'</b></div><div class="list-item row between"><span>Fatigue</span><b>'+Number(playerReport.fatigue_before||0)+' → '+Number(playerReport.fatigue_after||0)+'</b></div><div class="list-item row between"><span>Fitness</span><b>'+Number(playerReport.fitness_before||0)+' → '+Number(playerReport.fitness_after||0)+'</b></div>'
        +(playerRecovery?'<div class="list-item row between"><span>Récupération nuit</span><b>-'+Number(playerRecovery.fatigue_recovered||0)+' fatigue</b></div><div class="list-item row between"><span>Dette post-match</span><b>'+Number(playerRecovery.post_match_debt_before||0).toFixed(1)+' → '+Number(playerRecovery.post_match_debt_after||0).toFixed(1)+'</b></div>':'')
        +(playerRecovery?.travel_applied?'<div class="notice warn" style="margin-top:8px"><b>Voyage '+esc(playerRecovery.travel_from||'?')+' → '+esc(playerRecovery.travel_to||'?')+'</b> · charge physique +'+Number(playerRecovery.travel_load||0).toFixed(1)+'.</div>':'')
        +(playerReport.automatic_medical_restriction?'<div class="notice warn" style="margin-top:8px"><b>Restriction médicale.</b> Le staff a remplacé la séance prévue par récupération / repos.</div>':'')
        +((playerReport.improvements||[]).length?'<div class="daily-improvements">'+playerReport.improvements.slice(0,6).map(x=>'<span class="badge good">'+esc(reportLabels[x.attribute]||x.attribute)+' '+x.from+'→'+x.to+'</span>').join('')+'</div>':'<div class="muted mini" style="margin-top:8px">XP accumulée, aucun palier visible aujourd’hui.</div>')
        +(playerReport.training_niggle?'<div class="notice bad" style="margin-top:8px">Gêne musculaire déclenchée par la charge du jour.</div>':'')
        :'<div class="muted">Le premier rapport apparaîtra après Continuer.</div>')+'</div></div>';
  };

  function weeklyFeed(checkpoint){
    if(!checkpoint)return;
    local.feed=local.feed||[];
    if(checkpoint.weeklyFinance){
      const f=checkpoint.weeklyFinance;
      local.feed.unshift('Bilan semaine : sponsors +'+euro(f.sponsors||0)+' · staff -'+euro(f.staff||0)+' · joueurs -'+euro(f.players||0)+' · médical -'+euro(f.medical||0)+' · net '+(Number(f.net||0)>=0?'+':'')+euro(f.net||0)+'.');
    }
    if((checkpoint.injuries?.new_injuries||0)>0)local.feed.unshift(String(checkpoint.injuries.new_injuries)+' nouvelle(s) blessure(s) détectée(s) sur le cycle hebdomadaire.');
  }

  async function refreshAfterDay(weekly){
    boot=await get('/api/bootstrap');
    if(boot.career){
      local.career={...(local.career||{}),...boot.career};
      local.date=boot.career.career_date||local.date;
      local.week=boot.career.week??local.week;
    }
    const activeId=Number(local.activeManagedPlayerId||0);
    if(activeId&&activeId!==primaryId()&&typeof loadActiveManagedContext==='function')await loadActiveManagedContext(true,activeId).catch(()=>{});
    trainingPreview=null;
    careerHub=null;
    const tasks=[loadManagement(),loadTournaments(),loadCareerHub(true)];
    if(weekly)tasks.push(loadRankings(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries());
    await Promise.allSettled(tasks);
    if(route==='training')await loadTrainingPreview(true).catch(()=>{});
    if(route==='history')await loadHistory().catch(()=>{});
  }

  window.continueCareer=async function(){
    if(simulating)return;
    if(saveSlotBusy){alert('Une sauvegarde ou un chargement est en cours.');return}
    if(local.liveSessionId||window.hasManagedLiveMatches?.()){alert('Termine le match en cours avant de continuer.');nav('match');return}
    ensureDailyTraining();
    simulating=true;
    render();
    try{
      let payload=todayPlanPayload();
      let checkpoint=null;
      const advanceOneDay=()=>get('/api/advance-day',{
        method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({
          today_plan:payload,
          difficulty:local.difficulty||'normal',
          expected_from_date:String(local.date||career()?.career_date||'')
        })
      });
      let day=await advanceOneDay();

      if(day?.checkpoint_required){
        const cr=career()||{};
        checkpoint=await get('/api/simulate',{
          method:'POST',headers:{'Content-Type':'application/json'},
          body:JSON.stringify({
            clock_mode:'checkpoint',
            from_date:day.from_date,
            date:day.checkpoint_date||local.date,
            career_state:{
              form:cr.form,fitness:cr.fitness,morale:cr.morale,
              fatigue:cr.fatigue,injury_status:cr.injury_status
            },
            training:[],player_training:{},
            difficulty:local.difficulty||'normal'
          })
        });
        weeklyFeed(checkpoint);
        day=await advanceOneDay();
      }

      if(day?.requires_rollover){
        const roll=await get('/api/rollover-season',{
          method:'POST',headers:{'Content-Type':'application/json'},
          body:JSON.stringify({new_year:Number(day.new_year),daily_mode:true,clock_mode:'daily'})
        });
        local.feed=local.feed||[];
        const ng=roll.rollover?.newgens||{};
        local.feed.unshift('Nouvelle saison '+day.new_year+' : '+Number(roll.rollover?.retired_players||0)+' retraite(s), '+Number(ng.created||0)+' newgen(s).');
        day=await advanceOneDay();
      }

      if(!day?.ok){
        if(day?.reason==='pending_match'||day?.stop_reason==='match'){
          local.feed=local.feed||[];
          const due=day?.due_matches?.matches?.[0]||null;
          local.pendingManagedMatch=due||null;
          local.feed.unshift(due
            ?'Match à jouer aujourd’hui · '+String(due.tournament_name||'Tournoi')+' · '+String(due.round||'')
            :'Un match de ton groupe doit être joué avant de continuer.'
          );
          local.feed=local.feed.slice(0,12);
          const duePlayerId=Number(due?.player_id||0);
          if(duePlayerId&&duePlayerId!==activeManagedId()
             &&typeof window.setActiveManagedPlayer==='function'
             &&managedSquadIds().includes(duePlayerId)){
            await window.setActiveManagedPlayer(duePlayerId);
          }
          persist();
          await nav('calendar');
          if(Number(due?.tournament_id||0)){
            setTimeout(()=>window.openTournamentPlayMode?.(Number(due.tournament_id)),0);
          }
          return;
        }
        if(day?.reason==='clock_busy')throw new Error('Le calendrier est déjà en cours de mise à jour. Relance Continuer.');
        throw new Error(day?.reason||'Tick journalier impossible');
      }
      local.date=day.date||local.date;
      local.week=day.week??local.week;
      local.career={...(local.career||{}),...(day.career||{})};
      local.lastDailyTrainingReport=day;
      const dueToday=(day?.due_matches?.matches||[])[0]||null;
      local.pendingManagedMatch=dueToday;
      local.feed=local.feed||[];

      const primaryReport=(day.training||[]).find(x=>Number(x.player_id)===primaryId())||(day.training||[])[0];
      const primaryRecovery=primaryReport?.recovery||null;
      if(primaryRecovery?.travel_applied){
        local.feed.unshift('Voyage '+String(primaryRecovery.travel_from||'?')+' → '+String(primaryRecovery.travel_to||'?')+' · charge trajet +'+Number(primaryRecovery.travel_load||0).toFixed(1)+' · fatigue '+Number(primaryRecovery.fatigue_before||0)+'→'+Number(primaryRecovery.fatigue_after||0)+'.');
      }else if(primaryRecovery&&Number(primaryRecovery.post_match_debt_before||0)>0){
        local.feed.unshift('Récupération post-match · fatigue '+Number(primaryRecovery.fatigue_before||0)+'→'+Number(primaryRecovery.fatigue_after||0)+' · dette '+Number(primaryRecovery.post_match_debt_before||0).toFixed(1)+'→'+Number(primaryRecovery.post_match_debt_after||0).toFixed(1)+'.');
      }
      if(primaryReport?.automatic_medical_restriction)local.feed.unshift('Staff médical : entraînement remplacé par récupération / repos pour protéger le joueur.');
      if(primaryReport?.training_niggle)local.feed.unshift('Alerte entraînement : '+primaryReport.player_name+' termine la journée avec une gêne musculaire.');
      if((primaryReport?.improvements||[]).length){
        local.feed.unshift('Progression du jour : '+primaryReport.improvements.slice(0,3).map(x=>String(x.attribute)+' '+x.from+'→'+x.to).join(', ')+'.');
      }else if(primaryReport){
        local.feed.unshift(df(day.date)+' · '+primaryReport.player_name+' : '+primaryReport.morning+' / '+primaryReport.afternoon+' · charge '+Number(primaryReport.load||0).toFixed(1)+'.');
      }
      if(day.pending_matches>0)local.feed.unshift('Match à jouer : le calendrier s’arrête sur une rencontre de ton groupe.');
      else if(day.pending_decisions>0)local.feed.unshift('Décision manager en attente : le temps s’arrête avant de poursuivre.');

      if(day.weekly_checkpoint_due&&Number(day.pending_matches||0)===0){
        checkpoint=await get('/api/simulate',{
          method:'POST',headers:{'Content-Type':'application/json'},
          body:JSON.stringify({
            clock_mode:'checkpoint',
            from_date:day.week_start_date,
            date:day.date,
            career_state:{
              form:day.career?.form,fitness:day.career?.fitness,morale:day.career?.morale,
              fatigue:day.career?.fatigue,injury_status:day.career?.injury_status
            },
            training:[],
            player_training:{},
            difficulty:local.difficulty||'normal'
          })
        });
        weeklyFeed(checkpoint);
      }

      local.feed=local.feed.slice(0,12);
      persist();
      await refreshAfterDay(Boolean(checkpoint));
      const autosave=await saveCareerSlot(0,'autosave',true);
      if(!autosave?.ok)throw new Error('La journée est validée mais l’autosave a échoué.');

      if(day.stop_reason==='match'||Number(day.pending_matches||0)>0){
        const due=local.pendingManagedMatch||null;
        const duePlayerId=Number(due?.player_id||0);
        if(duePlayerId&&duePlayerId!==activeManagedId()
           &&typeof window.setActiveManagedPlayer==='function'
           &&managedSquadIds().includes(duePlayerId)){
          await window.setActiveManagedPlayer(duePlayerId);
        }
        await nav('calendar');
        if(Number(due?.tournament_id||0)){
          setTimeout(()=>window.openTournamentPlayMode?.(Number(due.tournament_id)),0);
        }
      }
      else if(day.stop_reason==='decision')await nav('inbox');
      else if(day.stop_reason==='medical')await nav('medical');
      else if(day.stop_reason==='training_progress')await nav('training');
    }catch(e){
      try{
        boot=await get('/api/bootstrap');
        if(boot.career){
          local.career={...(local.career||{}),...boot.career};
          local.date=boot.career.career_date||local.date;
          local.week=boot.career.week??local.week;
          localStorage.setItem('cbLocal',JSON.stringify(local));
        }
      }catch{}
      alert('Journée incomplète : '+e.message);
    }finally{
      simulating=false;
      render();
    }
  };

  window.simulateWeek=window.continueCareer;

  if(typeof header==='function'){
    header=function(){
      const cr=local.career||boot?.career||{};
      const next=nextDate();
      return '<header class="topbar"><div class="logo">COURT <b>BOSS</b></div><span class="top-date">'+df(local.date||cr.career_date)+'</span><div class="grow"></div><button class="ghost icon-btn" onclick="openGlobalSearch()" aria-label="Recherche">⌕</button><button class="ghost icon-btn" onclick="nav(\'saves\')" aria-label="Sauvegardes">▣</button><button class="ghost" onclick="nav(\'inbox\')">Boîte <span class="badge">'+(boot?.inbox?.filter(x=>!x.is_read).length||0)+'</span></button><button class="primary daily-continue" '+(simulating?'disabled':'')+' onclick="continueCareer()" title="Passer au '+df(next)+'">'+(simulating?'Journée…':'Continuer ›')+'</button></header>';
    };
  }

  // Daily tournament UX: a tournament is no longer a one-click block.
  // Only the match scheduled for the current career date can be played or quick-simmed.
  window.openTournamentPlayMode=function(id){
    const t=(tourRows||[]).find(x=>Number(x.id)===Number(id))||{};
    const current=String(local.date||career()?.career_date||'');
    const pending=(local.pendingManagedMatch
      &&Number(local.pendingManagedMatch.tournament_id||0)===Number(id)
      &&String(local.pendingManagedMatch.match_date||'')===current)
      ?local.pendingManagedMatch:null;
    const isDoubles=String(pending?.discipline||'singles')==='doubles';
    const playAction=isDoubles?'startTournamentLiveDoubles':'startTournamentLiveMatch';
    const exactLine=pending?.world_match_reserved
      ?'<span class="badge good">Tableau verrouillé · match #'+Number(pending.world_match_id||0)+'</span>'
      :'<span class="badge">Réservation du tableau au lancement</span>';
    overlay.innerHTML='<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet tournament-play-mode">'
      +'<div class="sheet-head"><div><div class="eyebrow">Journée de tournoi · '+df(current)+'</div><h1>'+esc(t.name||pending?.tournament_name||'Tournoi')+'</h1><div class="muted">'+(pending?esc(String(pending.round||'Match'))+' · '+(isDoubles?'Double':'Simple')+' · ':'')+'Le Match Center reprend exactement la case du tableau mondial.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>'
      +'<div class="row" style="gap:7px;flex-wrap:wrap;margin:10px 0">'+exactLine+'</div>'
      +'<div class="match-mode-grid">'
      +'<button class="match-mode-card live" onclick="'+playAction+'('+Number(id)+',false)"><span>JOUER</span><b>Match du jour</b><small>Match Center point par point. L’adversaire'+(isDoubles?' / la paire adverse':'')+' vient du tableau réservé.</small></button>'
      +'<button class="match-mode-card quick" onclick="'+playAction+'('+Number(id)+',true)"><span>SIMULER</span><b>Simuler le match du jour</b><small>Simule uniquement cette rencontre avec la même case de tableau, jamais tout le tournoi.</small></button>'
      +'</div><div class="notice" style="margin-top:12px"><b>Mode carrière quotidien</b> · après le match, valide le résultat puis utilise Continuer pour passer au lendemain. Les jours off restent de vraies journées de récupération, voyage ou entraînement.</div>'
      +'</div></div>';
  };

  window.playTournament=async function(){
    alert('La simulation complète du tournoi est désactivée en mode quotidien. Joue ou simule uniquement le match du jour.');
  };
  window.playDoublesTournament=async function(id){
    if(typeof startTournamentLiveDoubles==='function')return startTournamentLiveDoubles(Number(id),true);
    alert('Le double avance lui aussi jour par jour. Ouvre le Match Center double pour la rencontre du jour.');
  };

  const baseContinueCareer=window.continueCareer;
  window.continueCareer=async function(){
    const last=local.lastDailyTrainingReport||null;
    if(last&&String(last.date||'')===String(local.date||'')&&Number(last.pending_matches||0)>0){
      alert('Un match de ton groupe est à jouer aujourd’hui. Termine-le avant de passer au lendemain.');
      nav('calendar');
      return;
    }
    return baseContinueCareer();
  };
  window.simulateWeek=window.continueCareer;

  ensureDailyTraining();
  persist();
})();