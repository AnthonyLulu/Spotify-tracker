/* Court Boss Match Experience V23 · briefing, changeovers, live theatre, post-match */
(function(){
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const cap=(v,a,b)=>Math.max(a,Math.min(b,Number(v)||0));
  const pct=(a,b)=>Number(b||0)>0?Math.round(Number(a||0)/Number(b)*100):0;
  const live=()=>typeof local!=='undefined'?local.liveMatch:null;
  const opp=()=>typeof local!=='undefined'?(local.liveOpponent||{}):{};
  const career=()=>{try{return typeof activePlayerCareerView==='function'?activePlayerCareerView():{}}catch{return {}}};
  const meta=()=>live()?.stats?._meta||{};
  const point=()=>live()?.last_point||{};
  const stats=()=>live()?.stats||{};
  const isDoubles=()=>String(meta()?.match_type||'')==='doubles';
  const sessionKey=()=>String(live()?.id||'none');
  const state={prematch:new Set(),changeover:new Set(),post:new Set(),lastFx:'',resume:false};
  const modalId='cb-match-experience-modal-v23';

  const clearAuto=()=>{
    let running=false;
    try{
      if(typeof liveAutoTimer!=='undefined'&&liveAutoTimer){
        running=true;clearTimeout(liveAutoTimer);liveAutoTimer=null;
      }
    }catch{}
    return running;
  };
  const restartAuto=(delay=320)=>{
    try{
      if(!live()||String(live().status||'')!=='active')return;
      if(typeof startLiveAutoFlow==='function')startLiveAutoFlow(delay);
      else if(typeof toggleLiveAuto==='function'&&typeof liveAutoTimer!=='undefined'&&!liveAutoTimer)toggleLiveAuto();
    }catch{}
  };
  const removeModal=(resume=false)=>{
    document.getElementById(modalId)?.remove();
    if(resume)restartAuto(260);
  };
  const showModal=(html,resume)=>{
    document.getElementById(modalId)?.remove();
    const root=document.createElement('div');
    root.id=modalId;root.className='cb-xp-modal-v23';root.dataset.resume=resume?'1':'0';
    root.innerHTML='<div class="cb-xp-sheet-v23">'+html+'</div>';
    document.body.appendChild(root);
  };
  const rankText=v=>Number(v)>0&&Number(v)<9999?'#'+Number(v):'NC';
  const weatherText=()=>{
    const w=meta().weather||{};
    return [w.condition||'Conditions stables',Number.isFinite(Number(w.temperature_c))?Math.round(Number(w.temperature_c))+'°C':null,Number(w.wind_kph||0)>0?'vent '+Math.round(Number(w.wind_kph))+' km/h':null].filter(Boolean).join(' · ');
  };
  const surfaceText=()=>String(live()?.surface||meta().surface||meta().tournament?.surface||'Dur');
  const h2h=()=>meta().h2h_memory||{};
  const scoutingConfidence=()=>{
    const o=opp(),h=h2h();
    let score=48;
    if(o.ranking)score+=8;
    if(o.style)score+=10;
    if(o.handedness)score+=6;
    score+=Math.min(20,Number(h.encounters||0)*5);
    if(meta().tournament)score+=4;
    return cap(score,45,96);
  };
  const styleHint=style=>{
    const s=String(style||'').toLowerCase();
    if(/filet|volley|serve/.test(s))return 'Aime raccourcir les échanges et prendre le filet.';
    if(/contre|defen|défen/.test(s))return 'Très à l’aise quand tu lui donnes du rythme. Il faut varier.';
    if(/punche|power|attaque/.test(s))return 'Cherche à prendre la balle tôt et à dicter.';
    if(/créa|crea|vari|craft/.test(s))return 'Varie beaucoup les zones, le rythme et les hauteurs.';
    return 'Profil équilibré. La lecture des premiers jeux sera importante.';
  };
  const defaultPlan=()=>{
    const s=surfaceText().toLowerCase(),o=opp(),style=String(o.style||'').toLowerCase();
    if(isDoubles())return {key:'double-balanced',label:'Plan de paire équilibré',reason:'Commencer lisible, puis basculer vers poach ou australienne selon les retours.',tactics:{doublesPlan:'balanced',risk:50,aggression:56,net:45,tempo:'Neutre'}};
    if(/gazon|grass/.test(s))return {key:'grass-first-strike',label:'Première frappe',reason:'Sur gazon, protège tes jeux de service et prends le retour plus tôt.',tactics:{aggression:64,risk:57,net:40,returnPos:'Avancée',tempo:'Rapide',servePattern:'Mixte',targetWing:'Revers'}};
    if(/terre|clay/.test(s))return {key:'clay-patient',label:'Construire puis accélérer',reason:'Accepte l’échange, charge en lift et ouvre le court avant de forcer.',tactics:{aggression:55,risk:45,net:22,returnPos:'Reculée',tempo:'Patient',spin:'Lift',targetWing:'Revers'}};
    if(/filet|volley|serve/.test(style))return {key:'anti-net',label:'Retour + passing',reason:'Neutralise la première volée et oblige-le à jouer une frappe de plus.',tactics:{aggression:57,risk:48,net:24,returnPos:'Avancée',tempo:'Rapide',targetWing:'Revers'}};
    if(/contre|defen|défen/.test(style))return {key:'break-rhythm',label:'Casser son rythme',reason:'Ne lui donne pas la même balle deux fois : variation de tempo, spin et cible.',tactics:{aggression:57,risk:48,net:34,returnPos:'Neutre',tempo:'Varié',spin:'Mixte',targetWing:'Mixte'}};
    return {key:'balanced',label:'Plan équilibré',reason:'Commencer propre, lire les deux premiers jeux, puis exploiter la tendance.',tactics:{aggression:58,risk:50,net:30,returnPos:'Neutre',tempo:'Neutre',servePattern:'Mixte',targetWing:'Revers'}};
  };
  const alternativePlans=()=>{
    const base=defaultPlan();
    const rows=[
      base,
      {key:'safe',label:'Sécuriser',reason:'Réduire les fautes et allonger les échanges.',tactics:{aggression:50,risk:38,net:20,tempo:'Patient',servePattern:'Mixte'}},
      {key:'attack',label:'Prendre l’initiative',reason:'Jouer plus tôt et chercher à finir avant que le point s’installe.',tactics:{aggression:70,risk:62,net:42,returnPos:'Avancée',tempo:'Rapide'}}
    ];
    if(isDoubles())rows.splice(1,0,{key:'poach',label:'Poach agressif',reason:'Mettre le joueur de filet au centre du point.',tactics:{doublesPlan:'poach',net:62,aggression:64,risk:54}});
    return rows.slice(0,4);
  };
  const applyTactics=patch=>{
    try{
      local.tactics={...(local.tactics||{}),...patch};
      for(const k of ['aggression','risk','net','effort'])if(local.tactics[k]!=null)local.tactics[k]=cap(local.tactics[k],1,100);
      if(patch.doublesPlan)local.doublesTactics={...(local.doublesTactics||{}),plan:String(patch.doublesPlan)};
      if(typeof persist==='function')persist();
    }catch{}
  };
  window.cbXpApplyPlanV23=key=>{
    const plan=alternativePlans().find(x=>x.key===key)||defaultPlan();
    applyTactics(plan.tactics);
    document.querySelectorAll('.cb-xp-plan-v23').forEach(b=>b.classList.toggle('active',b.dataset.key===plan.key));
    const note=document.querySelector('.cb-xp-applied-v23');if(note)note.textContent='Plan appliqué · '+plan.label;
  };
  window.cbXpEnterCourtV23=()=>{const m=document.getElementById(modalId),resume=m?.dataset.resume==='1';removeModal(resume)};
  const prematchNotes=()=>{
    const o=opp(),h=h2h(),m=meta(),notes=[];
    notes.push(styleHint(o.style));
    if(Number(h.encounters||0)>0)notes.push('H2H connu : '+Number(h.encounters)+' duel'+(Number(h.encounters)>1?'s':'')+(h.last_score?' · dernier score '+h.last_score:'')+'.');
    else notes.push('Pas de H2H exploitable : les premiers jeux servent aussi de scouting live.');
    const w=m.weather||{};
    if(Number(w.wind_kph||0)>=16)notes.push('Vent sensible : évite de surjouer les lignes et garde une marge au service.');
    if(Number(w.temperature_c||0)>=29)notes.push('Chaleur élevée : surveille l’effort pour éviter de payer le troisième set.');
    if(isDoubles()){
      const d=m.doubles||{},ch=d.chemistry||{};
      if(ch.user!=null)notes.push('Chimie de ta paire : '+Math.round(Number(ch.user))+'/100. Communication et couverture comptent.');
    }
    return notes.slice(0,4);
  };
  const showPrematch=()=>{
    const s=live();if(!s||String(s.status||'')!=='active')return;
    const key=sessionKey();
    if(state.prematch.has(key)||Number(s.rally_no||0)>0||Number(s.last_point?.point_no||0)>0)return;
    state.prematch.add(key);
    const running=clearAuto()||true;
    const c=career(),o=opp(),m=meta(),t=m.tournament||{},h=h2h(),plans=alternativePlans(),confidence=scoutingConfidence();
    const title=String(t.name||'Match live'),round=String(m.round||'Match');
    const versus=isDoubles()?String(c.player_name||'Ta paire')+' vs '+String(o.name||'Paire adverse'):String(c.player_name||'Joueur')+' vs '+String(o.name||'Adversaire');
    const html=
      '<div class="cb-xp-head-v23"><div><small>BRIEFING AVANT MATCH</small><h2>'+esc(title)+'</h2><span>'+esc(round)+' · '+esc(surfaceText())+' · '+esc(weatherText())+'</span></div><div class="cb-xp-confidence-v23"><b>'+confidence+'%</b><span>confiance scouting</span></div></div>'+
      '<div class="cb-xp-versus-v23"><div><small>TON JOUEUR</small><b>'+esc(c.player_name||'Joueur')+'</b><span>'+rankText(c.singles_rank||c.ranking)+' · '+esc(c.style||'Profil équilibré')+'</span></div><strong>VS</strong><div><small>ADVERSAIRE</small><b>'+esc(o.name||'Adversaire')+'</b><span>'+rankText(o.ranking)+' · '+esc(o.style||'Style à lire')+'</span></div></div>'+
      '<div class="cb-xp-prematch-grid-v23">'+prematchNotes().map((x,i)=>'<article><i>'+String(i+1)+'</i><span>'+esc(x)+'</span></article>').join('')+'</div>'+
      '<div class="cb-xp-h2h-v23"><span>H2H</span><b>'+Number(h.encounters||0)+'</b><em>'+(h.last_match_date?esc(String(h.last_match_date)):'Premier duel ou historique insuffisant')+'</em></div>'+
      '<div class="cb-xp-section-title-v23">Plan de départ conseillé</div>'+
      '<div class="cb-xp-plans-v23">'+plans.map((p,i)=>'<button class="cb-xp-plan-v23 '+(i===0?'recommended':'')+'" data-key="'+esc(p.key)+'" onclick="cbXpApplyPlanV23(\''+esc(p.key)+'\')"><b>'+esc(p.label)+'</b><span>'+esc(p.reason)+'</span></button>').join('')+'</div>'+
      '<div class="cb-xp-applied-v23">Le plan actuel reste actif tant que tu ne choisis rien.</div>'+
      '<div class="cb-xp-footer-v23"><button class="primary" onclick="cbXpEnterCourtV23()">Entrer sur le court ▶</button></div>';
    showModal(html,running);
  };

  const coachMetrics=()=>{
    const st=stats(),lp=point(),env=lp.environment_effects||{},memory=env.opponent_memory_read||{};
    const first=pct(st.user_first_serves_in,st.user_first_serves);
    const serve=pct(st.user_service_points_won,st.user_service_points);
    const ret=pct(st.user_return_points_won,st.user_return_points);
    const net=pct(st.user_net_points_won,st.user_net_points);
    return {
      first,serve,ret,net,w:Number(st.user_winners||0),e:Number(st.user_errors||0),
      oppW:Number(st.opp_winners||0),oppE:Number(st.opp_errors||0),
      fatigue:Math.round(Number(env.user_condition_detail?.effective_fatigue??career().fatigue??0)),
      oppFatigue:Math.round(Number(env.opponent_condition_detail?.effective_fatigue??0)),
      memory,plan:env.opponent_plan||{}
    };
  };
  const coachAdvice=()=>{
    const x=coachMetrics(),rows=[];
    if(x.e>x.w+2)rows.push({kind:'safe',title:'Nettoie les fautes',text:'Tu donnes trop de points gratuits. Baisse le risque et construis une frappe de plus.'});
    if(x.serve>0&&x.serve<55)rows.push({kind:'deceive',title:'Service trop lisible',text:'Tes points au service sont faibles. Mélange davantage les zones et le tempo.'});
    if(x.ret>0&&x.ret<34)rows.push({kind:'return',title:'Change la position retour',text:'Tu ne prends pas assez de points en retour. Avance pour couper le temps si le serveur te domine.'});
    if(x.net>=68&&Number(stats().user_net_points||0)>=3)rows.push({kind:'net',title:'Le filet paie',text:'Tes montées fonctionnent. Continue à avancer derrière les bonnes balles.'});
    if(Number(x.memory.confidence||0)>=.6)rows.push({kind:'deceive',title:'L’IA commence à te lire',text:'Change deux paramètres ensemble pour casser la lecture : cible + tempo ou service + retour.'});
    if(x.fatigue>=72)rows.push({kind:'safe',title:'Attention physique',text:'Ton effort commence à coûter cher. Garde de la marge avant le prochain long jeu.'});
    if(!rows.length)rows.push({kind:'balanced',title:'Plan stable',text:'Pas de signal rouge. Garde le plan et surveille les deux prochains jeux.'});
    return rows.slice(0,3);
  };
  const coachPatch=kind=>{
    const t=local.tactics||{};
    if(kind==='safe')return {risk:cap(Number(t.risk||50)-12,25,80),aggression:cap(Number(t.aggression||58)-5,35,80),tempo:'Patient',effort:cap(Number(t.effort||60)-8,30,90)};
    if(kind==='return')return {returnPos:'Avancée',aggression:cap(Number(t.aggression||58)+4,35,85),targetWing:'Revers'};
    if(kind==='net')return {net:cap(Number(t.net||28)+16,10,80),aggression:cap(Number(t.aggression||58)+5,35,85)};
    if(kind==='deceive')return {servePattern:'Mixte',targetWing:'Mixte',tempo:'Varié',spin:'Mixte',risk:cap(Number(t.risk||50)-3,30,75)};
    if(kind==='attack')return {aggression:cap(Number(t.aggression||58)+10,40,90),risk:cap(Number(t.risk||50)+7,35,82),tempo:'Rapide'};
    if(kind==='poach')return {doublesPlan:'poach',net:cap(Number(t.net||40)+10,30,85)};
    if(kind==='australian')return {doublesPlan:'australian'};
    return {tempo:'Neutre'};
  };
  window.cbXpCoachActionV23=kind=>{
    applyTactics(coachPatch(kind));
    if(isDoubles()&&typeof cbSetLiveDoublesPlanV13==='function'&&['poach','australian'].includes(kind))cbSetLiveDoublesPlanV13(kind);
    const n=document.querySelector('.cb-xp-coach-applied-v23');if(n)n.textContent='Consigne appliquée · elle agit dès le prochain point.';
  };
  window.cbXpResumeV23=()=>{const m=document.getElementById(modalId),resume=m?.dataset.resume==='1';removeModal(resume)};
  const showChangeover=()=>{
    const s=live(),lp=point();if(!s||String(s.status||'')!=='active'||!lp.changeover)return;
    const key=sessionKey()+'|'+String(lp.point_no||s.rally_no||'0')+'|'+String(s.user_games)+'-'+String(s.opponent_games);
    if(state.changeover.has(key))return;
    state.changeover.add(key);
    const running=clearAuto();
    const x=coachMetrics(),advice=coachAdvice();
    const score=String(s.user_sets||0)+'-'+String(s.opponent_sets||0)+' sets · '+String(s.user_games||0)+'-'+String(s.opponent_games||0)+' jeux';
    const memoryText=Number(x.memory.confidence||0)>=.6?'L’adversaire pense avoir identifié tes habitudes.':'L’adversaire est encore en phase de lecture.';
    const doubleButtons=isDoubles()?'<button onclick="cbXpCoachActionV23(\'poach\')">Poach</button><button onclick="cbXpCoachActionV23(\'australian\')">Australienne</button>':'';
    const html=
      '<div class="cb-xp-head-v23"><div><small>CHANGEMENT DE CÔTÉ</small><h2>Coaching rapide</h2><span>'+esc(score)+' · '+esc(surfaceText())+'</span></div><div class="cb-xp-bench-clock-v23">90s</div></div>'+
      '<div class="cb-xp-metrics-v23">'+
        '<div><span>1res balles</span><b>'+x.first+'%</b></div><div><span>Pts service</span><b>'+x.serve+'%</b></div><div><span>Pts retour</span><b>'+x.ret+'%</b></div><div><span>Filet</span><b>'+(Number(stats().user_net_points||0)?x.net+'%':'—')+'</b></div>'+
      '</div>'+
      '<div class="cb-xp-energy-v23"><div><span>Énergie</span><i><b style="width:'+cap(100-x.fatigue,4,100)+'%"></b></i><em>'+(100-cap(x.fatigue,0,100))+'%</em></div><p>'+esc(memoryText)+'</p></div>'+
      '<div class="cb-xp-coach-grid-v23">'+advice.map(a=>'<article><b>'+esc(a.title)+'</b><span>'+esc(a.text)+'</span><button onclick="cbXpCoachActionV23(\''+esc(a.kind)+'\')">Appliquer</button></article>').join('')+'</div>'+
      '<div class="cb-xp-quick-v23"><button onclick="cbXpCoachActionV23(\'safe\')">Sécuriser</button><button onclick="cbXpCoachActionV23(\'attack\')">Agresser</button><button onclick="cbXpCoachActionV23(\'return\')">Prendre tôt</button><button onclick="cbXpCoachActionV23(\'deceive\')">Casser les habitudes</button>'+doubleButtons+'</div>'+
      '<div class="cb-xp-coach-applied-v23">Tu peux ne rien changer et simplement reprendre.</div>'+
      '<div class="cb-xp-footer-v23"><button class="primary" onclick="cbXpResumeV23()">Reprendre le match ▶</button></div>';
    showModal(html,running);
  };

  const insightRows=()=>{
    const st=stats(),rows=[];
    const uw=Number(st.user_winners||0),ue=Number(st.user_errors||0),ow=Number(st.opp_winners||0),oe=Number(st.opp_errors||0);
    const serve=pct(st.user_service_points_won,st.user_service_points),ret=pct(st.user_return_points_won,st.user_return_points);
    const net=pct(st.user_net_points_won,st.user_net_points);
    if(uw>ue)rows.push('Bilan offensif positif : '+uw+' winners pour '+ue+' fautes directes.');
    else rows.push('Le ratio winners/fautes a coûté cher : '+uw+' / '+ue+'.');
    if(serve>=65)rows.push('Le service a tenu le match avec '+serve+'% des points de service gagnés.');
    else if(st.user_service_points)rows.push('Le service est resté attaquable : '+serve+'% de points gagnés.');
    if(ret>=40)rows.push('Très bonne pression au retour : '+ret+'% des points de retour gagnés.');
    else if(st.user_return_points)rows.push('Le retour a peu pesé : '+ret+'%. Il faudra ajuster position ou cible au prochain duel.');
    if(Number(st.user_net_points||0)>=4)rows.push('Au filet : '+net+'% de réussite sur '+Number(st.user_net_points)+' montées.');
    const short=Number(st.user_short_rallies_won||0),shortOpp=Number(st.opp_short_rallies_won||0);
    const med=Number(st.user_medium_rallies_won||0),medOpp=Number(st.opp_medium_rallies_won||0);
    const long=Number(st.user_long_rallies_won||0),longOpp=Number(st.opp_long_rallies_won||0);
    if(short+shortOpp>=4&&short>shortOpp)rows.push('Tu as pris l’avantage dans les échanges courts ('+short+'-'+shortOpp+').');
    else if(long+longOpp>=4&&long>longOpp)rows.push('Tu as dominé les échanges longs ('+long+'-'+longOpp+').');
    else if(med+medOpp>=4&&med<medOpp)rows.push('La zone 4-9 frappes a penché côté adverse ('+med+'-'+medOpp+').');
    return rows.slice(0,5);
  };
  const keyMoments=()=>{
    const rows=[],log=Array.isArray(live()?.score_log)?live().score_log:[],events=Array.isArray(stats()._visual_events)?stats()._visual_events:[];
    log.filter(x=>x?.set_finished).forEach((x,i)=>rows.push('Set '+(i+1)+' · '+String(x.user_games||0)+'-'+String(x.opponent_games||0)+(x.tiebreak?' · tie-break':'')));
    events.slice(-5).forEach(e=>{if(e?.label&&!rows.includes(e.label))rows.push(String(e.label))});
    return rows.slice(-6);
  };
  const ensurePostMatch=()=>{
    const s=live();if(!s||!['finished','completed','committed'].includes(String(s.status||'')))return;
    const card=document.querySelector('.cb-live-card');if(!card||document.querySelector('.cb-post-match-v23'))return;
    const won=Number(s.user_sets||0)>Number(s.opponent_sets||0),ins=insightRows(),mom=keyMoments(),st=stats();
    const sec=document.createElement('section');sec.className='cb-post-match-v23';
    sec.innerHTML=
      '<div class="cb-post-head-v23"><div><small>ANALYSE APRÈS-MATCH</small><h3>'+(won?'Ce qui a fait gagner':'Ce qui a fait basculer le match')+'</h3></div><strong class="'+(won?'good':'bad')+'">'+(won?'VICTOIRE':'DÉFAITE')+'</strong></div>'+
      '<div class="cb-post-stats-v23"><div><span>Aces</span><b>'+Number(st.user_aces||0)+'</b></div><div><span>DF</span><b>'+Number(st.user_double_faults||0)+'</b></div><div><span>Winners</span><b>'+Number(st.user_winners||0)+'</b></div><div><span>Fautes</span><b>'+Number(st.user_errors||0)+'</b></div><div><span>Pts service</span><b>'+pct(st.user_service_points_won,st.user_service_points)+'%</b></div><div><span>Pts retour</span><b>'+pct(st.user_return_points_won,st.user_return_points)+'%</b></div></div>'+
      '<div class="cb-post-grid-v23"><div><h4>Lecture du match</h4>'+ins.map(x=>'<p>'+esc(x)+'</p>').join('')+'</div><div><h4>Moments clés</h4>'+(mom.length?mom.map(x=>'<p>'+esc(x)+'</p>').join(''):'<p>Pas d’événement spécial enregistré.</p>')+'</div></div>';
    card.insertAdjacentElement('afterend',sec);
  };

  const ensureCourtWear=()=>{
    const court=document.querySelector('.cb-live-card .cb-court'),s=live();if(!court||!s)return;
    const surface=surfaceText().toLowerCase(),m=meta(),wear=cap((Number(s.rally_no||0)/150)+(Number(m.tournament_wins||0)*.055),0,.92);
    court.style.setProperty('--cb-xp-wear',wear.toFixed(3));
    const round=String(m.round||'').toUpperCase();
    const crowd=/F|FINAL/.test(round)?.98:/SF/.test(round)?.92:/QF/.test(round)?.84:.62;
    court.style.setProperty('--cb-xp-round-crowd',String(crowd));
    let layer=court.querySelector('.cb-surface-wear-v23');
    if(!layer){layer=document.createElement('div');layer.className='cb-surface-wear-v23';layer.innerHTML='<i></i><i></i><i></i><i></i>';court.prepend(layer)}
    layer.dataset.surface=/gazon|grass/.test(surface)?'grass':/terre|clay/.test(surface)?'clay':'hard';
  };
  const flashPointFx=()=>{
    const s=live(),lp=point(),court=document.querySelector('.cb-live-card .cb-court');if(!s||!court||!lp)return;
    const key=sessionKey()+'|'+String(lp.point_no||s.rally_no||0)+'|'+String(lp.visual_label||'');
    if(key===state.lastFx)return;state.lastFx=key;
    court.querySelectorAll('.cb-speed-flash-v23,.cb-review-flash-v23').forEach(x=>x.remove());
    const shots=Array.isArray(lp.visual?.shots)?lp.visual.shots:[],serve=shots.find(x=>String(x.stroke||'').toLowerCase()==='service')||shots[0];
    const speed=Math.round(Number(serve?.speed_kph||lp.visual?.max_speed_kph||0));
    if(speed>=165||lp.ace){
      const f=document.createElement('div');f.className='cb-speed-flash-v23';f.innerHTML='<b>'+speed+'</b><span>km/h</span>';court.appendChild(f);setTimeout(()=>f.remove(),1450);
    }
    if(lp.line_review){
      const r=document.createElement('div');r.className='cb-review-flash-v23';r.innerHTML='<small>REVIEW</small><b>'+esc(lp.line_review.decision==='confirmed'?'Décision confirmée':'Décision modifiée')+'</b>';court.appendChild(r);setTimeout(()=>r.remove(),1800);
    }
    const server=court.querySelector('.fm-player-dot.'+(s.serving_user?'user':'opponent')+':not(.cb-live-double-partner-v13)');
    if(server){server.classList.remove('cb-serve-prep-v23');void server.offsetWidth;server.classList.add('cb-serve-prep-v23');setTimeout(()=>server.classList.remove('cb-serve-prep-v23'),900)}
  };

  const enhance=()=>{
    if(typeof local==='undefined')return;
    showPrematch();
    ensureCourtWear();
    flashPointFx();
    showChangeover();
    ensurePostMatch();
  };
  let queued=false;
  const schedule=()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;try{enhance()}catch(e){console.warn('Match Experience V23',e)}})};
  const root=document.getElementById('app')||document.body;
  new MutationObserver(schedule).observe(root,{childList:true,subtree:true});
  schedule();
  console.info('Court Boss Match Experience V23 active');
})();