/* Court Boss Match Center V12 · Living Arena */
(function(){
  const finished=s=>['finished','completed','committed'].includes(String(s?.status||''));
  const committed=s=>String(s?.status||'')==='committed';
  const pct=(n,d)=>Number(d||0)>0?Math.round(Number(n||0)*100/Number(d)):0;
  const score=s=>{
    const sets=(Array.isArray(s?.score_log)?s.score_log:[]).filter(x=>x?.set_finished);
    const base=sets.length?sets.map(x=>{
      const setScore=String(x.user_games)+'-'+String(x.opponent_games);
      if(x.match_tiebreak)return '['+String(x.tiebreak_user_points||0)+'-'+String(x.tiebreak_opponent_points||0)+']';
      return x.tiebreak?setScore+' ('+String(x.tiebreak_user_points||0)+'-'+String(x.tiebreak_opponent_points||0)+')':setScore;
    }).join(' '):'Sets '+Number(s?.user_sets||0)+'-'+Number(s?.opponent_sets||0);
    return base+(s?.stats?._retirement?' RET':'');
  };
  const safe=v=>typeof esc==='function'?esc(v==null?'':String(v)):String(v==null?'':v);
  const cap=(v,a,b)=>typeof clamp==='function'?clamp(Number(v),a,b):Math.max(a,Math.min(b,Number(v)));
  const wi=c=>{const v=String(c||'').toLowerCase();if(v.includes('vent'))return '≋';if(v.includes('humide'))return '◌';if(v.includes('chaud'))return '☀';if(v.includes('nuage'))return '☁';if(v.includes('indoor'))return '⌂';return '☀'};
  const speed=v=>{const n=Number(v||1);return n<.82?'Lent':n<.96?'Moyen-lent':n<1.08?'Moyen':n<1.2?'Rapide':'Très rapide'};
  const mood=v=>{const n=Number(v||70);return n>=86?'En feu':n>=75?'Confiant':n>=62?'Stable':n>=50?'Tendu':'Fragile'};
  const phaseLabel=v=>({service:'SERVICE',return:'RETOUR',rally:'ÉCHANGE',net:'FILET',game:'JEU',set:'SET',tiebreak:'TIE-BREAK',match_tiebreak:'MATCH TB',medical:'MÉDICAL'}[String(v||'').toLowerCase()]||'POINT');
  const endingLabel=v=>({
    ace:'Ace',double_fault:'Double faute',unreturned_serve:'Service non retourné',
    return_winner:'Retour gagnant',winner:'Coup gagnant',forced_error:'Faute provoquée',
    unforced_error:'Faute directe',rally_winner:'Point construit',
    passing_winner:'Passing gagnant',lob_winner:'Lob gagnant',drop_shot_winner:'Amortie gagnante',
    volley_winner:'Volée gagnante',inside_out_winner:'Inside-out gagnant',inside_in_winner:'Inside-in gagnant',
    line_winner:'Long de ligne gagnant',net_error:'Faute au filet',out_error:'Faute en longueur'
  }[String(v||'').toLowerCase()]||String(v||'Point').replaceAll('_',' '));
  const pos=(p,f)=>({x:cap(Number(p?.x??f.x),8,92),y:cap(Number(p?.y??f.y),7,93)});
  const ballPos=(p,f)=>({x:cap(Number(p?.x??f.x),3,97),y:cap(Number(p?.y??f.y),3,97)});
  const strokeLabel=v=>String(v||'').toLowerCase()==='coup_droit'?'CD':String(v||'').toLowerCase()==='revers'?'REV':String(v||'').toLowerCase()==='service'?'SERV':'FRAPPE';
  const patternLabel=v=>({crosscourt:'Croisé',down_the_line:'Long de ligne',inside_out:'Inside-out',inside_in:'Inside-in',drop_shot:'Amortie',lob:'Lob',passing:'Passing',approach:'Montée',volley:'Volée',wide:'Extérieur',body:'Corps',t:'T',net_error:'Filet',out:'Dehors'}[String(v||'')]||String(v||''));
  const intentLabel=v=>({construction:'Construction',acceleration:'Accélération',variation:'Variation',contre:'Contre',transition_filet:'Transition filet',finition_filet:'Finition filet',service:'Service'}[String(v||'')]||'');
  const physicsLabel=p=>!p?'':p.kick?'Kick haut':p.skid?'Rebond fusant':Number(p.bounce_height_factor||0)>=1.12?'Rebond haut':Number(p.bounce_height_factor||0)<=.76?'Rebond bas':'Rebond neutre';
  const stakeLabel=v=>({break_point:'BALLE DE BREAK',set_point:'BALLE DE SET',match_point:'BALLE DE MATCH',game_point:'BALLE DE JEU'}[String(v||'')]||'');
  const moveKeyframes=(name,frames,key)=>{
    const src=Array.isArray(frames)&&frames.length?frames:[],weights=src.slice(1).map(f=>Math.max(70,Number(f.frame_ms||f.physics?.hangtime_ms||180)));
    const total=weights.reduce((a,b)=>a+b,0)||1;let elapsed=0;
    return '@keyframes '+name+'{'+src.map((f,i)=>{if(i>0)elapsed+=weights[i-1]||0;const p=f[key],pct=i===src.length-1?100:Math.round(elapsed/total*10000)/100;return pct+'%{left:'+p.x+'%;top:'+p.y+'%}'}).join('')+'}';
  };
  const physicsTimeline=frames=>{
    const src=Array.isArray(frames)&&frames.length?frames:[];
    if(src.length<=1)return src.map((f,i)=>({pct:i?100:0,ball:f.ball||{x:50,y:50},scale:Number(f.ball_scale||1),lift:0,physics:f.physics||{}}));
    const weights=src.slice(1).map(f=>Math.max(70,Number(f.frame_ms||f.physics?.hangtime_ms||180))),total=weights.reduce((a,b)=>a+b,0)||1;
    let elapsed=0,out=[{pct:0,ball:src[0].ball||{x:50,y:50},scale:Number(src[0].ball_scale||.84),lift:0,physics:src[0].physics||{}}];
    for(let i=1;i<src.length;i++){
      const from=src[i-1].ball||{x:50,y:50},to=src[i].ball||from,p=src[i].physics||{},w=weights[i-1],start=elapsed/total*100,end=(elapsed+w)/total*100;
      const lerp=(a,b,t)=>Number(a)+(Number(b)-Number(a))*t;
      out.push({pct:start+(end-start)*.52,ball:{x:lerp(from.x,to.x,.55),y:lerp(from.y,to.y,.55)},scale:Number(p.apex_scale||1.2),lift:Number(p.apex_lift_px||7),physics:p});
      out.push({pct:start+(end-start)*.88,ball:{x:lerp(from.x,to.x,.93),y:lerp(from.y,to.y,.93)},scale:Number(p.bounce_scale||.94),lift:1,physics:p});
      out.push({pct:end,ball:to,scale:Number(src[i].ball_scale||1),lift:0,physics:p});
      elapsed+=w;
    }
    return out;
  };
  const ballKeyframes=(name,frames)=>'@keyframes '+name+'{'+physicsTimeline(frames).map(k=>{const p=k.ball,pct=Math.max(0,Math.min(100,Number(k.pct||0))).toFixed(2),scale=cap(Number(k.scale||1),.68,1.65),lift=cap(Number(k.lift||0),0,22),blur=k.physics?.skid?.2:0;return pct+'%{left:'+p.x+'%;top:'+p.y+'%;transform:translate(-50%,-50%) translateY(-'+lift+'px) scale('+scale+');filter:drop-shadow(0 '+Math.max(1,Math.round(lift*.34))+'px '+Math.max(3,Math.round(4+lift*.22))+'px rgba(0,0,0,.34)) blur('+blur+'px)}'}).join('')+'}';
  const courtStyle=(meta,surface)=>{
    const name=String(meta?.tournament?.name||'').toLowerCase(),clay=/terre|clay/i.test(surface),grass=/gazon|grass/i.test(surface);
    let a=clay?'#c06f47':grass?'#5f8d4e':'#3477ad',b=clay?'#a85634':grass?'#3e7037':'#255681';
    if(/australian open/.test(name)){a='#2c96ca';b='#17628d'}
    else if(/roland|french open/.test(name)){a='#ca7046';b='#a95734'}
    else if(/wimbledon/.test(name)){a='#66925b';b='#426f3e'}
    else if(/us open/.test(name)){a='#367caf';b='#245d8b'}
    else if(/indian wells/.test(name)){a='#4c78a8';b='#355d83'}
    else if(/miami open/.test(name)){a='#4c98b5';b='#2b718e'}
    return 'background:linear-gradient(180deg,'+a+','+b+');';
  };
  const tact=()=>({aggression:58,risk:52,net:28,returnPos:'Neutre',servePattern:'Mixte',targetWing:'Mixte',tempo:'Neutre',spin:'Mixte',effort:60,decidingSide:'Mixte',...(local.tactics||{})});

  window.cbSetMatchTactic=(k,v)=>{
    local.tactics=local.tactics||{};
    local.tactics[k]=['aggression','risk','net','effort'].includes(k)?Number(v):v;
    persist();render();
  };

  const cbMatchPlans={
    balanced:{label:'Équilibré',aggression:56,risk:50,net:28,effort:60,returnPos:'Neutre',servePattern:'Mixte',targetWing:'Mixte',tempo:'Neutre',spin:'Mixte'},
    pressure:{label:'Mettre la pression',aggression:70,risk:61,net:38,effort:72,returnPos:'Avancée',servePattern:'Large',targetWing:'Revers',tempo:'Rapide',spin:'Plat'},
    patient:{label:'Faire jouer',aggression:46,risk:36,net:18,effort:58,returnPos:'Reculée',servePattern:'Mixte',targetWing:'Revers',tempo:'Patient',spin:'Lift'},
    net:{label:'Prendre le filet',aggression:66,risk:54,net:72,effort:68,returnPos:'Avancée',servePattern:'Large',targetWing:'Revers',tempo:'Rapide',spin:'Slice'},
    protect:{label:'Fermer le jeu',aggression:44,risk:30,net:16,effort:50,returnPos:'Neutre',servePattern:'Corps',targetWing:'Mixte',tempo:'Patient',spin:'Mixte'},
    redline:{label:'Tout donner',aggression:82,risk:74,net:46,effort:88,returnPos:'Avancée',servePattern:'Large',targetWing:'Revers',tempo:'Rapide',spin:'Plat'}
  };
  window.cbApplyMatchPlan=(key)=>{
    const plan=cbMatchPlans[String(key||'balanced')]||cbMatchPlans.balanced;
    local.tactics={...(local.tactics||{}),...plan};
    delete local.tactics.label;
    local.lastMatchPlan=String(key||'balanced');
    persist();render();
  };

  function env(meta,userName,oppName){
    const w=meta?.weather||{},m=meta?.mood||{},f=meta?.form||{},t=meta?.tournament||null;
    const fm=n=>{n=Number(n||1);return '×'+n.toFixed(2)};
    const logo=t&&typeof tournamentLogoHtml==='function'?tournamentLogoHtml(t,'cb-event-logo-official'):(t?.logo_url?`<img class="cb-event-logo" src="${safe(t.logo_url)}" alt="" onerror="this.style.display='none'">`:'<div class="cb-event-logo-fallback">CB</div>');
    return `<div class="cb-env-card">
      <div class="cb-env-top">
        <div class="cb-event-brand">
          ${logo}
          <div><div class="eyebrow">${t?safe(t.name):'Match Center'}</div><b>${t?[safe(t.city),safe(t.venue)].filter(Boolean).join(' · '):'Session manager'}</b></div>
        </div>
        <span class="badge">${safe(meta?.surface||'Dur')}</span>
      </div>
      <div class="cb-env-grid">
        <div><small>Conditions</small><b>${wi(w.condition)} ${safe(w.condition||'Stable')}</b></div>
        <div><small>Température</small><b>${Math.round(Number(w.temperature_c||21))}°C</b></div>
        <div><small>Vent</small><b>${Math.round(Number(w.wind_kph||0))} km/h</b></div>
        <div><small>Humidité</small><b>${Math.round(Number(w.humidity_pct||50))}%</b></div>
        <div><small>Court</small><b>${speed(meta?.court_speed)} · ${Number(meta?.court_speed||1).toFixed(2)}</b></div>
        <div><small>Altitude</small><b>${Math.round(Number(meta?.altitude_m||0))} m</b></div>
        <div><small>Format</small><b>${meta?.next_gen_format?'BO5 · sets à 4 · TB 3-3 · No-Ad':meta?.ncaa_format?'BO3 · TB 6-6 · No-Ad':meta?.match_tiebreak_decider?'2 sets + Match TB '+Number(meta?.match_tiebreak_points||10):'Best of '+Number(meta?.best_of||3)}</b></div>
      </div>
      <div class="cb-mood-grid">
        <div><span>${safe(userName)}</span><b>${Math.round(Number(m.user||70))}/100 · ${mood(m.user)}</b></div>
        <div><span>${safe(oppName)}</span><b>${Math.round(Number(m.opponent||70))}/100 · ${mood(m.opponent)}</b></div>
      </div>
      <div class="cb-form-grid">
        <div><span>Forme ${safe(userName)}</span><b class="${Number(f.user_multiplier||1)>1?'good':Number(f.user_multiplier||1)<1?'bad':''}">${Math.round(Number(f.user||70))}/100 · ${fm(f.user_multiplier)}</b></div>
        <div><span>Forme ${safe(oppName)}</span><b class="${Number(f.opponent_multiplier||1)>1?'good':Number(f.opponent_multiplier||1)<1?'bad':''}">${Math.round(Number(f.opponent||70))}/100 · ${fm(f.opponent_multiplier)}</b></div>
      </div>
      <div class="muted micro cb-env-note">Météo, surface, fatigue et moral alimentent le même kernel. La forme est un multiplicateur temporaire de match : aucune note de base n’est réécrite.</div>
    </div>`;
  }

  function coaching(meta={}){
    const t=tact();
    const activePlan=String(local.lastMatchPlan||'custom');
    const planButtons=Object.entries(cbMatchPlans).map(([key,p])=>'<button type="button" class="cb-plan-btn '+(activePlan===key?'active':'')+'" onclick="cbApplyMatchPlan(\''+key+'\')">'+safe(p.label)+'</button>').join('');
    return `<div class="cb-plan-strip">${planButtons}</div><div class="cb-coach-grid">
      <div class="cb-coach-slider"><div><span>Agressivité</span><b>${t.aggression}%</b></div><input type="range" min="1" max="100" value="${t.aggression}" oninput="cbSetMatchTactic('aggression',this.value)"></div>
      <div class="cb-coach-slider"><div><span>Risque</span><b>${t.risk}%</b></div><input type="range" min="1" max="100" value="${t.risk}" oninput="cbSetMatchTactic('risk',this.value)"></div>
      <div class="cb-coach-slider"><div><span>Filet</span><b>${t.net}%</b></div><input type="range" min="1" max="100" value="${t.net}" oninput="cbSetMatchTactic('net',this.value)"></div>
      <div class="cb-coach-slider"><div><span>Effort</span><b>${t.effort}%</b></div><input type="range" min="20" max="100" value="${t.effort}" oninput="cbSetMatchTactic('effort',this.value)"></div>
      <label>Retour<select onchange="cbSetMatchTactic('returnPos',this.value)"><option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option><option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option></select></label>
      <label>Cible service<select onchange="cbSetMatchTactic('servePattern',this.value)"><option ${t.servePattern==='Mixte'?'selected':''}>Mixte</option><option ${t.servePattern==='T'?'selected':''}>T</option><option ${t.servePattern==='Large'?'selected':''}>Large</option><option ${t.servePattern==='Corps'?'selected':''}>Corps</option></select></label>
      <label>Côté ciblé<select onchange="cbSetMatchTactic('targetWing',this.value)"><option ${t.targetWing==='Mixte'?'selected':''}>Mixte</option><option ${t.targetWing==='Revers'?'selected':''}>Revers</option><option ${t.targetWing==='Coup droit'?'selected':''}>Coup droit</option></select></label>
      <label>Tempo<select onchange="cbSetMatchTactic('tempo',this.value)"><option ${t.tempo==='Patient'?'selected':''}>Patient</option><option ${t.tempo==='Neutre'?'selected':''}>Neutre</option><option ${t.tempo==='Rapide'?'selected':''}>Rapide</option></select></label>
      <label>Effet / variation<select onchange="cbSetMatchTactic('spin',this.value)"><option ${t.spin==='Mixte'?'selected':''}>Mixte</option><option ${t.spin==='Lift'?'selected':''}>Lift</option><option ${t.spin==='Slice'?'selected':''}>Slice</option><option ${t.spin==='Plat'?'selected':''}>Plat</option></select></label>
      ${meta?.no_ad?`<label>Côté retour · point décisif<select onchange="cbSetMatchTactic('decidingSide',this.value)"><option ${t.decidingSide==='Mixte'?'selected':''}>Mixte</option><option ${t.decidingSide==='Deuce'?'selected':''}>Deuce</option><option ${t.decidingSide==='Avantage'?'selected':''}>Avantage</option></select></label>`:''}
    </div>`;
  }

  liveMatchPanel=function(){
    const s=local.liveMatch;
    const selectedSurface=local.matchSurface||'Dur',selectedIndoor=!!local.matchIndoor;
    if(!s)return `<div class="card cb-launch-card">
      <div class="row between"><div><div class="eyebrow">Court Boss Match Engine</div><h2>Jouer ou simuler</h2><div class="muted">Même moteur pour le live et la simulation. Aucun résultat n'est définitif avant validation.</div></div><span class="badge good">Point par point</span></div>
      <div class="match-surface-pills cb-surface-pills">
        <button class="${selectedSurface==='Dur'&&!selectedIndoor?'active':''}" onclick="setMatchSurface('Dur',false)">Dur ext.</button>
        <button class="${selectedSurface==='Dur'&&selectedIndoor?'active':''}" onclick="setMatchSurface('Dur',true)">Dur indoor</button>
        <button class="${selectedSurface==='Terre'?'active':''}" onclick="setMatchSurface('Terre',false)">Terre</button>
        <button class="${selectedSurface==='Gazon'?'active':''}" onclick="setMatchSurface('Gazon',false)">Gazon</button>
      </div>
      <div class="cb-launch-actions"><button class="primary" onclick="startLiveMatch()">▶ Jouer en live</button><button class="soft-btn" onclick="simulatePracticeMatch()">⚡ Simulation rapide</button></div>
      <div class="muted micro cb-launch-foot">Un checkpoint est créé avant le premier point. Fermer sans sauvegarder revient avant le match.</div>
    </div>`;

    const c=activePlayerCareerView(),opp=local.liveOpponent||{},lp=s.last_point||{},st=s.stats||{},meta=st._meta||{};
    const userName=c.player_name||'Joueur',oppName=opp.name||'Adversaire';
    const us=Number(s.user_sets||0),os=Number(s.opponent_sets||0),ug=Number(s.user_games||0),og=Number(s.opponent_games||0),up=Number(s.user_points||0),op=Number(s.opponent_points||0);
    const done=finished(s),isCommitted=committed(s),visual=lp.visual||{},weather=meta.weather||{},retirement=st._retirement||null;
    const ux=cap(lp.user_x??48,12,88),uy=cap(lp.user_y??78,55,90),ox=cap(lp.opp_x??52,12,88),oy=cap(lp.opp_y??22,10,45),bx=cap(lp.ball_x??50,10,90),by=cap(lp.ball_y??50,8,92);
    const endsFlipped=Boolean(lp.ends_flipped??((Array.isArray(s.score_log)?s.score_log.length:0)%2===1));
    const orientPoint=p=>endsFlipped?{x:p.x,y:100-p.y}:p;
    const userStart=orientPoint(pos(visual.user_start,{x:48,y:86})),userEnd=orientPoint(pos(visual.user_end,{x:ux,y:uy}));
    const oppStart=orientPoint(pos(visual.opponent_start,{x:52,y:14})),oppEnd=orientPoint(pos(visual.opponent_end,{x:ox,y:oy}));
    const rawFrames=Array.isArray(visual.frames)?visual.frames:[],rawPath=Array.isArray(visual.ball_path)?visual.ball_path:[];
    const motionFrames=rawFrames.length?rawFrames.map(f=>({
      ...f,user:orientPoint(pos(f.user,userEnd)),opponent:orientPoint(pos(f.opponent,oppEnd)),
      ball:orientPoint(ballPos(f.ball,{x:bx,y:by}))
    })):[{user:userStart,opponent:oppStart,ball:orientPoint(ballPos(rawPath[0],{x:bx,y:by})),ball_scale:.9},
         {user:userEnd,opponent:oppEnd,ball:orientPoint(ballPos(rawPath[rawPath.length-1],{x:bx,y:by})),ball_scale:1}];
    const ballPath=motionFrames.map(f=>f.ball),hasFlight=motionFrames.length>=2,ballEnd=ballPath[ballPath.length-1]||{x:bx,y:by};
    const surface=String(s.surface||'Dur'),courtClass=/terre|clay/i.test(surface)?'clay':/gazon|grass/i.test(surface)?'grass':'hard',indoor=/intérieur|indoor/i.test(surface);
    const condition=String(weather.condition||'').toLowerCase(),weatherClass=Number(weather.wind_kph||0)>=18?'windy':condition.includes('humide')?'humid':Number(weather.temperature_c||0)>=29?'hot':condition.includes('nuage')?'cloudy':'clear';
    const uInit=safe(userName.split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase()),oInit=safe(oppName.split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase());
    const momentum=cap(s.momentum||50,10,90);
    const setsToWin=Math.max(2,Math.min(3,Number(meta?.sets_to_win||2)));
    const matchTiebreakActive=Boolean(meta?.match_tiebreak_decider)
      &&Number(s.set_no||1)===Number(meta?.best_of||3)
      &&us===setsToWin-1&&os===setsToWin-1&&!done;
    const tiebreakAtGames=Math.max(1,Number(meta?.tiebreak_at_games||6));
    const tiebreakActive=(matchTiebreakActive||(ug===tiebreakAtGames&&og===tiebreakAtGames))&&!done;
    const tiebreakTarget=Number(st._tiebreak_target||lp.tiebreak_target||(matchTiebreakActive?meta?.match_tiebreak_points:0)||((/grand chelem|grand slam/i.test(String(meta?.tournament?.category||''))&&Number(s.set_no||1)===Number(meta.best_of||3))?10:7));
    const pA=tiebreakActive?String(up):(typeof pointLabel==='function'?pointLabel(up,op,'A'):String(up));
    const pB=tiebreakActive?String(op):(typeof pointLabel==='function'?pointLabel(up,op,'B'):String(op));
    const call=String(visual.label||lp.visual_label||endingLabel(lp.ending||lp.shot||'')),phase=phaseLabel(retirement?'medical':matchTiebreakActive?'match_tiebreak':tiebreakActive?'tiebreak':visual.phase||lp.phase);
    const serviceCourtLabel=String(lp.service_court||'')==='ad'?'Avantage':String(lp.service_court||'')==='deuce'?'Égalité':'';
    const target=String(visual.target_zone||lp.zone||'Zone neutre'),setScore=score(s);
    const userWonLast=String(lp.winner||'')==='user',oppWonLast=String(lp.winner||'')==='opponent';
    const eventRows=(Array.isArray(st._visual_events)?st._visual_events:[]).slice(-6).reverse();
    const shotRows=Array.isArray(visual.shots)?visual.shots:[];
    const stake=String(visual.stake||lp.stake||'normal');
    const noAdDeciding=Boolean(meta?.no_ad)&&!tiebreakActive&&up===3&&op===3;
    const stakeText=noAdDeciding?'POINT DÉCISIF':stakeLabel(stake);
    const category=String(meta?.tournament?.category||'').toLowerCase(),circuit=String(meta?.tournament?.circuit||'').toLowerCase();
    const eventTier=/grand chelem|grand slam/.test(category)?'grand-slam':/masters|1000/.test(category)?'masters':/challenger/.test(category)||circuit.includes('challenger')?'challenger':/itf/.test(category)||circuit.includes('itf')?'itf':'tour';
    const ambienceLabel=eventTier==='grand-slam'?'Grand Chelem · grande arène':eventTier==='masters'?'Masters 1000 · grande affluence':eventTier==='challenger'?'Challenger · court compact':eventTier==='itf'?'ITF · court annexe':'Circuit ATP';
    const specialClass=retirement?'cb-special-medical':lp.ace?'cb-special-ace':stake==='match_point'?'cb-special-match':stake==='set_point'?'cb-special-set':stake==='break_point'?'cb-special-break':'';
    const slideUser=Boolean(visual.user_slide)&&courtClass==='clay',slideOpp=Boolean(visual.opponent_slide)&&courtClass==='clay';
    const visualRate=typeof liveAutoSpeed==='number'?liveAutoSpeed:1;
    const visualMs=Math.round(cap(Number(visual.duration_ms||Math.max(820,shotRows.length*190)),650,12000)/Math.max(1,visualRate));
    const motionId='cbm'+Number(s.id||0)+'p'+Number(visual.point_no||lp.point_no||s.rally_no||0);
    const userAnim=motionId+'u',oppAnim=motionId+'o',ballAnim=motionId+'b';
    const motionStyle=hasFlight?'<style>'+moveKeyframes(userAnim,motionFrames,'user')+moveKeyframes(oppAnim,motionFrames,'opponent')+ballKeyframes(ballAnim,motionFrames)+'</style>':'';
    const tracePoints=ballPath.map(p=>p.x+','+p.y).join(' ');
    const styles=visual.profiles||{},styleText=(styles.user?.archetype&&styles.opponent?.archetype)?(styles.user.archetype+' vs '+styles.opponent.archetype):'';
    const resolution=visual.resolution||{},pressureScore=cap(Number(resolution.pressure_score||0),0,100);
    const matchPressure=cap(Number(lp.environment_effects?.pressure_level??eventRows?.[0]?.match_pressure??0),0,100);
    const mentalPressureEdge=Number(lp.environment_effects?.mental_pressure_edge||0);
    const opponentPlan=lp.environment_effects?.opponent_plan||null;
    const userConditionDetail=lp.environment_effects?.user_condition_detail||null;
    const opponentConditionDetail=lp.environment_effects?.opponent_condition_detail||null;
    const resolutionText=resolution.pattern?patternLabel(resolution.pattern):'';
    const physicsSummary=visual.physics_summary||{};
    const mix=visual.pattern_mix||{};
    const patternSummary=Object.entries(mix).sort((a,b)=>Number(b[1])-Number(a[1])).slice(0,4).map(([k,v])=>patternLabel(k)+' ×'+Number(v)).join(' · ');
    const styleTags=p=>Array.isArray(p?.tags)?p.tags:[];
    const profileCard=(name,p,side)=>p?.archetype?`<div class="cb-style-card ${side}"><div><small>${safe(name)}</small><b>${safe(p.archetype)} · ${safe(p.dominant_wing||'Équilibré')}</b></div><div class="cb-style-tags">${styleTags(p).map(t=>`<span>${safe(t)}</span>`).join('')}</div><em>Mob ${Number(p.mobility||0).toFixed(1)} · Déf ${Number(p.defense||0).toFixed(1)} · Touch ${Number(p.touch||0).toFixed(1)} · Filet ${Number(p.net||0).toFixed(1)}</em></div>`:'';


    const broadcastRows=(Array.isArray(s.score_log)?s.score_log:[]).filter(x=>x?.set_finished);
    const broadcastBestOf=Math.max(3,Number(meta?.best_of||3));
    const broadcastSetCount=Math.max(broadcastBestOf,broadcastRows.length+(!done?1:0));
    const broadcastSetHead=Array.from({length:broadcastSetCount},(_,i)=>{
      const r=broadcastRows[i];
      return '<span>'+(r?.match_tiebreak?'MTB':'S'+(i+1))+'</span>';
    }).join('');
    const broadcastCell=(side,i)=>{
      const r=broadcastRows[i];
      if(r){
        const isUser=side==='user';
        const value=r.match_tiebreak
          ?Number(isUser?r.tiebreak_user_points:r.tiebreak_opponent_points)
          :Number(isUser?r.user_games:r.opponent_games);
        const other=r.match_tiebreak
          ?Number(isUser?r.tiebreak_opponent_points:r.tiebreak_user_points)
          :Number(isUser?r.opponent_games:r.user_games);
        return '<b class="cb-tv-set '+(value>other?'won ':'')+(r.match_tiebreak?'tb':'')+'">'+value+'</b>';
      }
      if(!done&&i===broadcastRows.length){
        const value=matchTiebreakActive?(side==='user'?up:op):(side==='user'?ug:og);
        return '<b class="cb-tv-set live '+(matchTiebreakActive?'tb':'')+'">'+value+'</b>';
      }
      return '<b class="cb-tv-set empty">–</b>';
    };
    const broadcastUserSets=Array.from({length:broadcastSetCount},(_,i)=>broadcastCell('user',i)).join('');
    const broadcastOppSets=Array.from({length:broadcastSetCount},(_,i)=>broadcastCell('opponent',i)).join('');
    const broadcastTournament=meta?.tournament||{};
    const broadcastLogo=broadcastTournament&&typeof tournamentLogoHtml==='function'
      ?tournamentLogoHtml(broadcastTournament,'cb-broadcast-logo')
      :(broadcastTournament?.logo_url?'<img class="cb-broadcast-logo-img" src="'+safe(broadcastTournament.logo_url)+'" alt="">':'<div class="cb-broadcast-logo-fallback">CB</div>');
    const broadcastCategory=[broadcastTournament?.circuit,broadcastTournament?.category].filter(Boolean).join(' · ')||'Court Boss Tour';
    const broadcastLocation=[broadcastTournament?.city,broadcastTournament?.venue].filter(Boolean).join(' · ')||'Match Center';
    const userMoodValue=Math.round(Number(meta?.mood?.user||70));
    const oppMoodValue=Math.round(Number(meta?.mood?.opponent||70));
    const userFormValue=Math.round(Number(meta?.form?.user||70));
    const oppFormValue=Math.round(Number(meta?.form?.opponent||70));
    const weatherDifficulty=Math.round(Number(weather?.weather_difficulty||0));
    const serverName=s.serving_user?userName:oppName;

    const roundText=String(meta?.round||'').toUpperCase();
    const bestRank=Math.min(Number(c?.singles_rank||c?.ranking||9999),Number(opp?.ranking||9999));
    const lateRound=/^(F|SF|FINAL|FINALE|SEMI|DEMI)/.test(roundText)||/FINALE|DEMI/.test(roundText);
    const quarterRound=/QF|QUART/.test(roundText);
    const arenaLevel=lateRound||(eventTier==='grand-slam'&&(quarterRound||bestRank<=10))||(eventTier==='masters'&&quarterRound)
      ?'center'
      :(eventTier==='grand-slam'||eventTier==='masters'||bestRank<=32?'show':'outer');
    const arenaLabel=arenaLevel==='center'?'Court central':arenaLevel==='show'?'Show court':'Court annexe';
    const arenaCapacity=arenaLevel==='center'
      ?(eventTier==='grand-slam'?'15–24k':eventTier==='masters'?'9–15k':'6–10k')
      :arenaLevel==='show'?'3–8k':'0.5–2k';
    const changeoverCoach=Boolean(lp.changeover)&&!done;
    const benchUser=cap(100-Number(userConditionDetail?.effective_fatigue??c?.fatigue??18),0,100);
    const benchOpp=cap(100-Number(opponentConditionDetail?.effective_fatigue??opp?.fatigue??18),0,100);

    return `<div class="cb-match-shell">${env({...meta,surface},userName,oppName)}
      <div class="card fm-live-match cb-live-card">
        <div class="cb-broadcast-head">
          <div class="cb-broadcast-brand">${broadcastLogo}<div><small>${safe(broadcastCategory)}</small><b>${safe(broadcastTournament.name||'Match Center')}</b><em>${safe(broadcastLocation)}</em></div></div>
          <div class="cb-broadcast-status"><span>${safe(meta.round||'Match live')}</span><b>${isCommitted?'VALIDÉ':done?'À VALIDER':phase}</b></div>
        </div>
        <div class="cb-tv-score" style="--cb-set-count:${broadcastSetCount}">
          <div class="cb-tv-score-row cb-tv-score-head"><span>JOUEUR</span>${broadcastSetHead}<span>JEU</span><span>PT</span></div>
          <div class="cb-tv-score-row user">
            <div class="cb-tv-player"><i class="${s.serving_user?'serving':''}"></i><div><b>${safe(userName)} <small>${flags?.[c.country]||''}</small></b><em>${mood(userMoodValue)} · moral ${userMoodValue} · forme ${userFormValue}</em></div></div>
            ${broadcastUserSets}<b class="cb-tv-game">${ug}</b><strong class="cb-tv-point">${pA}</strong>
          </div>
          <div class="cb-tv-score-row opponent">
            <div class="cb-tv-player"><i class="${!s.serving_user?'serving':''}"></i><div><b>${safe(oppName)} <small>${flags?.[opp.country]||''}</small></b><em>${mood(oppMoodValue)} · moral ${oppMoodValue} · forme ${oppFormValue}</em></div></div>
            ${broadcastOppSets}<b class="cb-tv-game">${og}</b><strong class="cb-tv-point">${pB}</strong>
          </div>
        </div>
        <div class="cb-match-context">
          <span><i class="cb-context-ball"></i><b>${safe(serverName)}</b> au service</span>
          <span>${safe(surface)} · ${indoor?'Indoor':'Outdoor'}</span>
          <span>${wi(weather.condition)} ${safe(weather.condition||'Stable')} · ${Math.round(Number(weather.temperature_c||21))}°C · ${Math.round(Number(weather.wind_kph||0))} km/h</span>
          <span class="${weatherDifficulty>=12?'warn':weatherDifficulty>=7?'soft':''}">Difficulté météo ${weatherDifficulty}/20</span>
        </div>
        <div class="fm-court ${courtClass} ${indoor?'indoor':''} cb-court cb-weather-${weatherClass} cb-event-${eventTier} cb-arena-${arenaLevel} ${specialClass} ${endsFlipped?'cb-ends-flipped':''}" style="${courtStyle(meta,surface)};--cb-visual-ms:${visualMs}ms">
          <div class="cb-arena-shell" aria-hidden="true">
            <div class="cb-stand cb-stand-north"></div><div class="cb-stand cb-stand-south"></div>
            <div class="cb-stand cb-stand-west"></div><div class="cb-stand cb-stand-east"></div>
            <div class="cb-score-tower"><span>${safe(meta.round||'LIVE')}</span><b>${safe(arenaLabel)}</b></div>
            <div class="cb-ad-board cb-ad-board-nw">${safe(broadcastTournament.name||broadcastTournament.circuit||'COURT BOSS')}</div>
            <div class="cb-ad-board cb-ad-board-ne">${safe(broadcastTournament.circuit||broadcastTournament.category||'TENNIS')}</div>
            <div class="cb-ad-board cb-ad-board-sw">${safe(broadcastTournament.city||'TOUR')}</div>
            <div class="cb-ad-board cb-ad-board-se">${safe(broadcastTournament.category||'MATCH CENTER')}</div>
            <div class="cb-umpire-chair"><i></i><b>ARBITRE</b></div>
            <div class="cb-ball-kid cb-ball-kid-a"></div><div class="cb-ball-kid cb-ball-kid-b"></div>
            <div class="cb-bench cb-bench-user"><span>${safe(userName.split(' ').slice(-1)[0]||'MOI')}</span><i style="--energy:${benchUser}%"></i></div>
            <div class="cb-bench cb-bench-opp"><span>${safe(oppName.split(' ').slice(-1)[0]||'ADV')}</span><i style="--energy:${benchOpp}%"></i></div>
          </div>
          ${motionStyle}
          ${tracePoints?`<svg class="cb-rally-trace" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true"><polyline points="${tracePoints}"></polyline></svg>`:''}
          <i class="fm-court-line baseline top"></i><i class="fm-court-line baseline bottom"></i><i class="fm-court-line sideline left"></i><i class="fm-court-line sideline right"></i><i class="fm-court-line service horizontal top"></i><i class="fm-court-line service horizontal bottom"></i><i class="fm-court-line service vertical"></i><i class="fm-net"></i>
          <div class="cb-weather-fx" aria-hidden="true"></div>
          <div class="cb-crowd cb-crowd-top" aria-hidden="true"></div><div class="cb-crowd cb-crowd-bottom" aria-hidden="true"></div>
          <div class="cb-court-hud"><span>${phase}</span><b>${arenaLabel} · ${arenaCapacity} · ${ambienceLabel} · ${wi(weather.condition)} ${Math.round(Number(weather.temperature_c||21))}° · ${Math.round(Number(weather.wind_kph||0))} km/h</b></div>
          ${stakeText?`<div class="cb-stake-banner cb-stake-${safe(stake)}">${safe(stakeText)}</div>`:''}
          ${lp.changeover?'<div class="cb-changeover">↔ Changement de côté · fenêtre coaching</div>':''}
          ${meta?.tournament?.logo_url?`<img class="cb-court-watermark" src="${safe(meta.tournament.logo_url)}" alt="" onerror="this.style.display='none'">`:''}
          ${hasFlight?`<i class="cb-target-zone" style="left:${ballEnd.x}%;top:${ballEnd.y}%"></i>`:''}
          <div class="fm-player-dot opponent cb-dot cb-dot-motion ${slideOpp?'cb-clay-slide':''} ${oppWonLast?'cb-point-winner':userWonLast?'cb-point-loser':''}" style="left:${oppEnd.x}%;top:${oppEnd.y}%;animation:${oppAnim} ${visualMs}ms cubic-bezier(.18,.72,.22,1) both"><span>${oInit}</span><small>${safe(oppName.split(' ').slice(-1)[0]||'ADV')}</small>${oppWonLast?'<em class="cb-reaction">POINT</em>':''}</div>
          <div class="fm-player-dot user cb-dot cb-dot-motion ${slideUser?'cb-clay-slide':''} ${userWonLast?'cb-point-winner':oppWonLast?'cb-point-loser':''}" style="left:${userEnd.x}%;top:${userEnd.y}%;animation:${userAnim} ${visualMs}ms cubic-bezier(.18,.72,.22,1) both"><span>${uInit}</span><small>${safe(userName.split(' ').slice(-1)[0]||'MOI')}</small>${userWonLast?'<em class="cb-reaction">POINT</em>':''}</div>
          <i class="fm-ball cb-ball ${hasFlight?'cb-ball-flight':''}" style="left:${ballEnd.x}%;top:${ballEnd.y}%;animation:${ballAnim} ${visualMs}ms linear both"></i>
          ${lp.winner?`<div class="fm-rally-call cb-rally"><span>${phase}</span><b>${safe(call)}</b> · ${Number(lp.rally||0)} coups · ${safe(target)}</div>`:''}
        </div>
        ${(styles.user?.archetype||styles.opponent?.archetype)?`<div class="cb-style-duel">${profileCard(userName,styles.user,'user')}${profileCard(oppName,styles.opponent,'opponent')}</div>`:''}
        ${opponentPlan?`<div class="cb-resolution-card"><div><small>Plan adverse · ${safe(opponentPlan.archetype||'All-court')}</small><b>${safe(opponentPlan.adaptation||'Plan naturel')} · cible ${safe(opponentPlan.targetWing||'Mixte')}</b></div><div class="cb-physics-metrics"><span>Agg ${Math.round(Number(opponentPlan.aggression||0))}</span><span>Risque ${Math.round(Number(opponentPlan.risk||0))}</span><span>Filet ${Math.round(Number(opponentPlan.net||0))}</span><span>${safe(opponentPlan.tempo||'Neutre')} · ${safe(opponentPlan.spin||'Mixte')}</span></div></div>`:''}
        ${(userConditionDetail&&opponentConditionDetail)?`<div class="cb-resolution-card"><div><small>Condition live · charge physique</small><b>${safe(userName)} : forme ${Math.round(Number(userConditionDetail.effective_fitness||0))}% · fatigue ${Math.round(Number(userConditionDetail.effective_fatigue||0))}%</b></div><div class="cb-physics-metrics"><span>Effort ${Math.round(Number(userConditionDetail.effort||0))}</span><span>Charge ${Number(userConditionDetail.live_load||0).toFixed(1)}</span><span>${safe(oppName)} fatigue ${Math.round(Number(opponentConditionDetail.effective_fatigue||0))}%</span><span>Effort adv. ${Math.round(Number(opponentConditionDetail.effort||0))}</span></div></div>`:''}
        ${resolution.source&&resolution.source!=='kernel'?`<div class="cb-resolution-card"><div><small>Résolution spatiale</small><b>${safe(endingLabel(lp.ending||lp.shot))}${resolutionText?' · '+safe(resolutionText):''}</b></div><div class="cb-pressure"><span>Pression ${Math.round(pressureScore)}/100</span><i><b style="width:${pressureScore}%"></b></i></div></div>`:''}
        ${shotRows.length?`<div class="cb-physics-card"><div><small>Physique du rallye</small><b>${courtClass==='clay'?'Terre · rebond haut':courtClass==='grass'?'Gazon · rebond bas / fusant':'Dur · rebond intermédiaire'}</b></div><div class="cb-physics-metrics"><span>${Number(physicsSummary.avg_pre_bounce_kph||0)} km/h avant</span><span>${Number(physicsSummary.avg_post_bounce_kph||0)} km/h après</span><span>${Number(physicsSummary.kick_shots||0)} kick · ${Number(physicsSummary.skid_shots||0)} fusants</span></div></div><div class="cb-shot-strip"><span class="cb-shot-count">${shotRows.length} frappes${shotRows.length>=20?' · rallye long':''}</span>${shotRows.map((sh,i)=>`<span class="cb-shot-chip ${sh.hitter==='user'?'user':'opponent'} ${String(sh.spin||'').toLowerCase()} ${sh.stretched_receiver?'stretched':''}"><i>${i+1}</i><b>${sh.hitter==='user'?'MOI':'ADV'} · ${strokeLabel(sh.stroke)} · ${safe(patternLabel(sh.pattern))}</b><em>${safe(sh.spin||'Mixte')} · ${Math.round(Number(sh.speed_kph||0))}→${Math.round(Number(sh.post_bounce_speed_kph||sh.speed_kph||0))} km/h${sh.physics?' · '+safe(physicsLabel(sh.physics)):''}${sh.intent?' · '+safe(intentLabel(sh.intent)):''}${sh.stretched_receiver?' · débordé':''}${shotRows.length>=16&&sh.hitter_archetype?' · '+safe(sh.hitter_archetype):''}</em></span>`).join('')}</div>`:''}
        ${retirement?`<div class="cb-resolution-card cb-medical-card"><div><small>Abandon médical · résultat provisoire</small><b>${safe(retirement.player_name||'Joueur')} · ${safe(retirement.injury_type||'Incident physique')}</b></div><div class="cb-physics-metrics"><span>${safe(retirement.severity||'—')}</span><span>${Number(retirement.days_out||0)} j estimés</span><span>Risque aggravation ${Math.round(Number(retirement.aggravation_risk||0))}%</span><span>${retirement.side==='user'?'Ton joueur abandonne':'Adversaire abandonne'}</span></div><small class="muted">La blessure n'entre dans la carrière que si tu valides ce résultat. Quitter sans sauvegarder restaure le checkpoint.</small></div>`:''}
        <div class="cb-match-story">
          ${lp.winner?`<div class="cb-point-story"><span class="badge ${matchPressure>=80?'bad':matchPressure>=55?'warn':''}">Pression ${Math.round(matchPressure)}%</span><div><b>${matchPressure>=90?'Point critique':matchPressure>=70?'Très haute pression':matchPressure>=45?'Pression élevée':matchPressure>=20?'Moment sensible':'Situation stable'}</b><small>Impact mental ${mentalPressureEdge>=0?'+':''}${(mentalPressureEdge*100).toFixed(1)} pt · modèle CB-PRESSURE-v2</small></div></div>`:''}
          <div class="cb-point-story">
            <span class="badge">${phase}</span>
            <div><b>${lp.winner?safe(call):'Prêt à jouer'}</b><small>${lp.winner?(safe(lp.serve_direction||'mixte')+(serviceCourtLabel?' · '+safe(serviceCourtLabel):'')+' · retour '+safe(lp.return_depth||'—')+' · '+shotRows.length+' frappes'+(patternSummary?' · '+safe(patternSummary):'')+(styleText?' · '+safe(styleText):'')):'Le prochain point utilisera le moteur v6.'}</small></div>
          </div>
          <div class="cb-event-feed">
            ${eventRows.length?eventRows.map(e=>`<div class="cb-event-line ${e.winner==='user'?'user':e.winner==='opponent'?'opponent':''}"><span>${safe(phaseLabel(e.phase||e.kind))}</span><b>${safe(e.label||'Point')}</b><small>${e.kind==='point'?((Number(e.rally||0)+' coups')+(e.pressure_score!=null?' · P'+Math.round(Number(e.pressure_score)):'')):(e.score||'')}</small></div>`).join(''):'<div class="cb-event-empty">Les événements du match apparaîtront ici.</div>'}
          </div>
        </div>
        <div class="fm-momentum"><span>${safe(oppName)}</span><div><i style="left:${momentum}%"></i></div><span>${safe(userName)}</span></div>
        <div class="cb-stat-grid">
          <div><span>Winners</span><b>${st.user_winners||0} - ${st.opp_winners||0}</b></div><div><span>Fautes</span><b>${st.user_errors||0} - ${st.opp_errors||0}</b></div><div><span>Aces</span><b>${st.user_aces||0} - ${st.opp_aces||0}</b></div>
          <div><span>1res IN</span><b>${pct(st.user_first_serves_in,st.user_first_serves)}% - ${pct(st.opp_first_serves_in,st.opp_first_serves)}%</b></div><div><span>DF</span><b>${st.user_double_faults||0} - ${st.opp_double_faults||0}</b></div><div><span>Filet</span><b>${st.user_net_points_won||0}/${st.user_net_points||0} - ${st.opp_net_points_won||0}/${st.opp_net_points||0}</b></div>
          <div><span>Points gagnés</span><b>${st.user_points_won||0} - ${st.opp_points_won||0}</b></div><div><span>Pts service</span><b>${pct(st.user_service_points_won,st.user_service_points)}% - ${pct(st.opp_service_points_won,st.opp_service_points)}%</b></div><div><span>Pts retour</span><b>${pct(st.user_return_points_won,st.user_return_points)}% - ${pct(st.opp_return_points_won,st.opp_return_points)}%</b></div>
          <div><span>Balles de break</span><b>${st.user_break_points_converted||0}/${st.user_break_points||0} - ${st.opp_break_points_converted||0}/${st.opp_break_points||0}</b></div><div><span>BP sauvées</span><b>${st.user_break_points_saved||0}/${st.user_break_points_faced||0} - ${st.opp_break_points_saved||0}/${st.opp_break_points_faced||0}</b></div>
        </div>
        ${!done?`<div class="cb-live-controls">
          <div class="cb-speed-row"><button class="${liveAutoTimer?'danger-btn':'primary'}" onclick="toggleLiveAuto()">${liveAutoTimer?'⏸ Pause':'▶ Auto'}</button><button class="soft-btn ${liveAutoSpeed===1?'active':''}" onclick="setLiveSpeed(1)">1x</button><button class="soft-btn ${liveAutoSpeed===2?'active':''}" onclick="setLiveSpeed(2)">2x</button><button class="soft-btn ${liveAutoSpeed===3?'active':''}" onclick="setLiveSpeed(3)">3x</button></div>
          <div class="cb-live-flow-note"><span class="muted micro">Flux direct point par point · pause pour modifier les consignes, puis reprise instantanée.</span></div>
          <div class="cb-save-row"><button class="soft-btn" onclick="quickSaveLiveV1()">💾 Sauvegarder le score</button><button class="danger-btn" onclick="discardLiveMatchV1()">Quitter sans sauvegarder</button></div>
        </div>
        ${changeoverCoach?`<div class="cb-changeover-coach">
          <div class="cb-changeover-coach-head"><div><small>CHANGEMENT DE CÔTÉ</small><b>30 secondes manager</b></div><span>${safe(arenaLabel)}</span></div>
          <div class="cb-changeover-read">
            <div><span>Ton joueur</span><b>Énergie ${Math.round(benchUser)}% · ${mood(userMoodValue)}</b></div>
            <div><span>Adversaire</span><b>Énergie ${Math.round(benchOpp)}% · ${safe(opponentPlan?.adaptation||'Plan naturel')}</b></div>
          </div>
          <div class="cb-changeover-tip">${opponentPlan?'IA adverse : '+safe(opponentPlan.adaptation||'Plan naturel')+' · cible '+safe(opponentPlan.targetWing||'Mixte')+' · '+safe(opponentPlan.tempo||'Neutre'):'Lis le momentum et ajuste tes consignes avant le prochain jeu.'}</div>
          ${coaching(meta)}
        </div>`:''}
        <details class="cb-coach-panel" ${changeoverCoach?'':'open'}><summary>Consignes manager · modifiables pendant le match</summary>${coaching(meta)}</details>`
        :isCommitted?(()=>{
          const r=local.lastCommittedMatchResult||{},out=r.tournament_outcome||{},tid=Number(s.tournament_id||0);
          const next=r.next_match_available&&tid?'<button class="primary" onclick="nextTournamentLiveMatchV1()">Match suivant</button>':'';
          const med=r.retirement||retirement||null,medWrite=r.medical||null;
          const detail=out.terminal
            ?'<p>Parcours terminé · '+safe(out.user_round||'')+' · '+Number(out.user_points||0)+' pts · '+Number(out.user_prize_eur||0).toLocaleString('fr-FR')+' €</p>'
            :'<p>Résultat validé. '+(r.tournament_live?'Le parcours tournoi continue.':'Tu peux maintenant poursuivre ta carrière.')+'</p>';
          const medicalDetail=med?'<p><b>Abandon médical enregistré</b> · '+safe(med.player_name||'Joueur')+' · '+safe(med.injury_type||'incident physique')+(medWrite?.expected_return?' · retour estimé '+safe(medWrite.expected_return):'')+'</p>':'';
          return `<div class="cb-result-box committed"><div><small>Résultat officiel · sauvegardé</small><h3>${safe(setScore)}</h3>${medicalDetail}${detail}</div><div class="cb-result-actions">${next}<button class="soft-btn" onclick="clearLiveMatch()">Fermer</button></div></div>`;
        })()
        :`<div class="cb-result-box"><div><small>${retirement?'Abandon médical · résultat provisoire':'Résultat provisoire'}</small><h3>${safe(setScore)}</h3>${retirement?'<p><b>'+safe(retirement.player_name||'Joueur')+'</b> abandonne · '+safe(retirement.injury_type||'incident physique')+'. La blessure n’existe pas encore dans la carrière.</p>':''}<p>Rien n’est définitif tant que tu ne sauvegardes pas. Sauvegarder rend ce résultat officiel. Le brouillon fige le score sans l’intégrer à la carrière. Ne pas sauvegarder efface le match.</p></div><div class="cb-result-actions"><button class="primary" onclick="commitLiveMatchV1()">💾 Sauvegarder le résultat</button><button class="soft-btn" onclick="quickSaveLiveV1()">Figer comme brouillon</button><button class="danger-btn" onclick="discardLiveMatchV1()">Ne pas sauvegarder / rejouer</button></div></div>`}
      </div></div>`;
  };

  window.quickSaveLiveV1=async()=>{
    if(typeof window.saveLiveCheckpoint==='function')return await window.saveLiveCheckpoint();
    try{
      const d=await saveCareerSlot(9,'quick',true);
      if(d?.ok===false)throw new Error(d.error||d.reason||'Sauvegarde impossible');
      render();
    }catch(e){alert('Sauvegarde impossible : '+e.message)}
  };

  window.saveCommittedLiveV1=async()=>{
    try{
      const d=await saveCareerSlot(9,'quick',true);
      if(d?.ok===false)throw new Error(d.error||d.reason||'Sauvegarde impossible');
      clearPendingLiveRollback();
      alert('Carrière sauvegardée avec ce résultat.');
      render();
    }catch(e){alert('Sauvegarde impossible : '+e.message)}
  };

  window.commitLiveMatchV1=async()=>{
    const current=local.liveMatch;if(!current||!finished(current)||committed(current))return;
    if(typeof window.commitLiveMatch==='function')return await window.commitLiveMatch();
    alert('Sauvegarde sécurisée indisponible.');
  };

  window.nextTournamentLiveMatchV1=async()=>{
    const s=local.liveMatch,tid=Number(s?.tournament_id||0);
    if(!tid)return clearLiveMatch();
    clearLiveMatch();
    await window.startTournamentLiveMatch(tid,false);
  };

  window.discardLiveMatchV1=async()=>{
    const current=local.liveMatch;if(!current)return;
    if(committed(current)){alert('Ce résultat est déjà validé. Recharge une sauvegarde antérieure pour revenir en arrière.');return}
    if(typeof window.discardLiveMatch==='function')return await window.discardLiveMatch();
    alert('Retour au checkpoint indisponible.');
  };

  window.simulatePracticeMatch=async()=>{
    const playerId=activeManagedId()||primaryManagedPlayerId()||0,cr=activePlayerCareerView();
    if(String(cr.career_focus||'mixed')==='doubles_only'){alert('Orientation Double exclusivement : la simulation simple est désactivée.');return}
    if(local.liveMatch&&String(local.liveMatch.status)==='active'){alert('Un match live est déjà en cours pour ce joueur.');return}
    try{
      await ensureLivePreMatchCheckpoint();
      const surface=(local.matchSurface||'Dur')==='Dur'&&local.matchIndoor?'Dur intérieur':(local.matchSurface||'Dur');
      let d=await get('/api/live-match/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({surface,player_id:playerId,tactics:tact()})});
      applyLiveMatchResponse(d);
      if(typeof window.simulateLiveMatch!=='function')throw new Error('Simulateur de match indisponible.');
      await window.simulateLiveMatch();
      d={session:local.liveMatch};
      if(String(local.liveMatch?.status||'')==='active')throw new Error('Simulation interrompue avant la fin du match.');
      persist();render();
      const ss=local.liveMatch,sc=score(ss);
      overlay.innerHTML=`<div class="modal"><div class="sheet cb-quick-result"><div class="eyebrow">Simulation rapide</div><h1>${safe(activePlayerCareerView().player_name||'Joueur')} · ${safe(sc)}</h1><p class="muted">Même moteur que le live. Résultat encore provisoire.</p><div class="cb-result-actions"><button class="primary" onclick="closeOverlay();commitLiveMatchV1()">💾 Sauvegarder ce résultat</button><button class="soft-btn" onclick="closeOverlay();quickSaveLiveV1()">Figer comme brouillon</button><button class="danger-btn" onclick="closeOverlay();discardLiveMatchV1()">Ne pas sauvegarder / rejouer</button></div></div></div>`;
    }catch(e){alert('Simulation rapide impossible : '+e.message)}
  };

  window.setTactic=(k,v)=>window.cbSetMatchTactic(k,v);
  console.info('Court Boss Match Center V12 Living Arena active');
})();