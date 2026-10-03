/* Court Boss Match Center V7 · Spatial Rally */
(function(){
  const finished=s=>['finished','completed','committed'].includes(String(s?.status||''));
  const committed=s=>String(s?.status||'')==='committed';
  const pct=(n,d)=>Number(d||0)>0?Math.round(Number(n||0)*100/Number(d)):0;
  const score=s=>{
    const sets=(Array.isArray(s?.score_log)?s.score_log:[]).filter(x=>x?.set_finished);
    return sets.length?sets.map(x=>String(x.user_games)+'-'+String(x.opponent_games)).join(' '):'Sets '+Number(s?.user_sets||0)+'-'+Number(s?.opponent_sets||0);
  };
  const safe=v=>typeof esc==='function'?esc(v==null?'':String(v)):String(v==null?'':v);
  const cap=(v,a,b)=>typeof clamp==='function'?clamp(Number(v),a,b):Math.max(a,Math.min(b,Number(v)));
  const wi=c=>{const v=String(c||'').toLowerCase();if(v.includes('vent'))return '≋';if(v.includes('humide'))return '◌';if(v.includes('chaud'))return '☀';if(v.includes('nuage'))return '☁';if(v.includes('indoor'))return '⌂';return '☀'};
  const speed=v=>{const n=Number(v||1);return n<.82?'Lent':n<.96?'Moyen-lent':n<1.08?'Moyen':n<1.2?'Rapide':'Très rapide'};
  const mood=v=>{const n=Number(v||70);return n>=86?'En feu':n>=75?'Confiant':n>=62?'Stable':n>=50?'Tendu':'Fragile'};
  const phaseLabel=v=>({service:'SERVICE',return:'RETOUR',rally:'ÉCHANGE',net:'FILET',game:'JEU',set:'SET'}[String(v||'').toLowerCase()]||'POINT');
  const endingLabel=v=>({
    ace:'Ace',double_fault:'Double faute',unreturned_serve:'Service non retourné',
    return_winner:'Retour gagnant',winner:'Coup gagnant',forced_error:'Faute provoquée',
    unforced_error:'Faute directe',rally_winner:'Point construit'
  }[String(v||'').toLowerCase()]||String(v||'Point').replaceAll('_',' '));
  const pos=(p,f)=>({x:cap(Number(p?.x??f.x),8,92),y:cap(Number(p?.y??f.y),7,93)});
  const ballPos=(p,f)=>({x:cap(Number(p?.x??f.x),3,97),y:cap(Number(p?.y??f.y),3,97)});
  const strokeLabel=v=>String(v||'').toLowerCase()==='coup_droit'?'CD':String(v||'').toLowerCase()==='revers'?'REV':String(v||'').toLowerCase()==='service'?'SERV':'FRAPPE';
  const patternLabel=v=>({crosscourt:'Croisé',down_the_line:'Long de ligne',inside_out:'Inside-out',inside_in:'Inside-in',drop_shot:'Amortie',lob:'Lob',passing:'Passing',approach:'Montée',volley:'Volée',wide:'Extérieur',body:'Corps',t:'T',net_error:'Filet',out:'Dehors'}[String(v||'')]||String(v||''));
  const stakeLabel=v=>({break_point:'BALLE DE BREAK',set_point:'BALLE DE SET',match_point:'BALLE DE MATCH',game_point:'BALLE DE JEU'}[String(v||'')]||'');
  const moveKeyframes=(name,frames,key)=>'@keyframes '+name+'{'+frames.map((f,i)=>{const p=f[key],pct=Math.round(i*100/Math.max(1,frames.length-1));return pct+'%{left:'+p.x+'%;top:'+p.y+'%}'}).join('')+'}';
  const ballKeyframes=(name,frames)=>'@keyframes '+name+'{'+frames.map((f,i)=>{const p=f.ball,pct=Math.round(i*100/Math.max(1,frames.length-1)),scale=cap(Number(f.ball_scale||1),.72,1.4);return pct+'%{left:'+p.x+'%;top:'+p.y+'%;transform:translate(-50%,-50%) scale('+scale+')}'}).join('')+'}';
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
  const tact=()=>({aggression:58,risk:52,net:28,returnPos:'Neutre',servePattern:'Mixte',targetWing:'Mixte',tempo:'Neutre',spin:'Mixte',effort:60,...(local.tactics||{})});

  window.cbSetMatchTactic=(k,v)=>{
    local.tactics=local.tactics||{};
    local.tactics[k]=['aggression','risk','net','effort'].includes(k)?Number(v):v;
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
        <div><small>Format</small><b>Best of ${Number(meta?.best_of||3)}</b></div>
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

  function coaching(){
    const t=tact();
    return `<div class="cb-coach-grid">
      <div class="cb-coach-slider"><div><span>Agressivité</span><b>${t.aggression}%</b></div><input type="range" min="1" max="100" value="${t.aggression}" oninput="cbSetMatchTactic('aggression',this.value)"></div>
      <div class="cb-coach-slider"><div><span>Risque</span><b>${t.risk}%</b></div><input type="range" min="1" max="100" value="${t.risk}" oninput="cbSetMatchTactic('risk',this.value)"></div>
      <div class="cb-coach-slider"><div><span>Filet</span><b>${t.net}%</b></div><input type="range" min="1" max="100" value="${t.net}" oninput="cbSetMatchTactic('net',this.value)"></div>
      <div class="cb-coach-slider"><div><span>Effort</span><b>${t.effort}%</b></div><input type="range" min="20" max="100" value="${t.effort}" oninput="cbSetMatchTactic('effort',this.value)"></div>
      <label>Retour<select onchange="cbSetMatchTactic('returnPos',this.value)"><option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option><option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option></select></label>
      <label>Cible service<select onchange="cbSetMatchTactic('servePattern',this.value)"><option ${t.servePattern==='Mixte'?'selected':''}>Mixte</option><option ${t.servePattern==='T'?'selected':''}>T</option><option ${t.servePattern==='Large'?'selected':''}>Large</option><option ${t.servePattern==='Corps'?'selected':''}>Corps</option></select></label>
      <label>Côté ciblé<select onchange="cbSetMatchTactic('targetWing',this.value)"><option ${t.targetWing==='Mixte'?'selected':''}>Mixte</option><option ${t.targetWing==='Revers'?'selected':''}>Revers</option><option ${t.targetWing==='Coup droit'?'selected':''}>Coup droit</option></select></label>
      <label>Tempo<select onchange="cbSetMatchTactic('tempo',this.value)"><option ${t.tempo==='Patient'?'selected':''}>Patient</option><option ${t.tempo==='Neutre'?'selected':''}>Neutre</option><option ${t.tempo==='Rapide'?'selected':''}>Rapide</option></select></label>
      <label>Effet / variation<select onchange="cbSetMatchTactic('spin',this.value)"><option ${t.spin==='Mixte'?'selected':''}>Mixte</option><option ${t.spin==='Lift'?'selected':''}>Lift</option><option ${t.spin==='Slice'?'selected':''}>Slice</option><option ${t.spin==='Plat'?'selected':''}>Plat</option></select></label>
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
    const done=finished(s),isCommitted=committed(s),visual=lp.visual||{},weather=meta.weather||{};
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
    const momentum=cap(s.momentum||50,10,90),pA=typeof pointLabel==='function'?pointLabel(up,op,'A'):String(up),pB=typeof pointLabel==='function'?pointLabel(up,op,'B'):String(op);
    const call=String(visual.label||lp.visual_label||endingLabel(lp.ending||lp.shot||'')),phase=phaseLabel(visual.phase||lp.phase);
    const target=String(visual.target_zone||lp.zone||'Zone neutre'),setScore=score(s);
    const userWonLast=String(lp.winner||'')==='user',oppWonLast=String(lp.winner||'')==='opponent';
    const eventRows=(Array.isArray(st._visual_events)?st._visual_events:[]).slice(-6).reverse();
    const shotRows=Array.isArray(visual.shots)?visual.shots:[];
    const stake=String(visual.stake||lp.stake||'normal'),stakeText=stakeLabel(stake);
    const category=String(meta?.tournament?.category||'').toLowerCase(),circuit=String(meta?.tournament?.circuit||'').toLowerCase();
    const eventTier=/grand chelem|grand slam/.test(category)?'grand-slam':/masters|1000/.test(category)?'masters':/challenger/.test(category)||circuit.includes('challenger')?'challenger':/itf/.test(category)||circuit.includes('itf')?'itf':'tour';
    const ambienceLabel=eventTier==='grand-slam'?'Grand Chelem · grande arène':eventTier==='masters'?'Masters 1000 · grande affluence':eventTier==='challenger'?'Challenger · court compact':eventTier==='itf'?'ITF · court annexe':'Circuit ATP';
    const specialClass=lp.ace?'cb-special-ace':stake==='match_point'?'cb-special-match':stake==='set_point'?'cb-special-set':stake==='break_point'?'cb-special-break':'';
    const slideUser=Boolean(visual.user_slide)&&courtClass==='clay',slideOpp=Boolean(visual.opponent_slide)&&courtClass==='clay';
    const visualRate=typeof liveAutoSpeed==='number'?liveAutoSpeed:1;
    const visualMs=Math.round(cap(Number(visual.duration_ms||Math.max(820,shotRows.length*190)),650,12000)/Math.max(1,visualRate));
    const motionId='cbm'+Number(s.id||0)+'p'+Number(visual.point_no||lp.point_no||s.rally_no||0);
    const userAnim=motionId+'u',oppAnim=motionId+'o',ballAnim=motionId+'b';
    const motionStyle=hasFlight?'<style>'+moveKeyframes(userAnim,motionFrames,'user')+moveKeyframes(oppAnim,motionFrames,'opponent')+ballKeyframes(ballAnim,motionFrames)+'</style>':'';
    const tracePoints=ballPath.map(p=>p.x+','+p.y).join(' ');
    const styles=visual.profiles||{},styleText=(styles.user?.archetype&&styles.opponent?.archetype)?(styles.user.archetype+' vs '+styles.opponent.archetype):'';

    return `<div class="cb-match-shell">${env({...meta,surface},userName,oppName)}
      <div class="card fm-live-match cb-live-card">
        <div class="fm-match-top"><div><div class="eyebrow">${safe(meta.round||'Match live')} · ${safe(surface)}</div><h2>${safe(userName)} vs ${safe(oppName)}</h2></div><span class="badge ${isCommitted?'good':done?'warn':''}">${isCommitted?'Validé':done?'À valider':'Set '+Number(s.set_no||1)}</span></div>
        <div class="fm-scoreboard cb-scoreboard">
          <div class="fm-score-name">${s.serving_user?'● ':''}${safe(userName)} <small>${flags?.[c.country]||''}</small></div><b>${us}</b><b>${ug}</b><strong>${pA}</strong>
          <div class="fm-score-name">${!s.serving_user?'● ':''}${safe(oppName)} <small>${flags?.[opp.country]||''}</small></div><b>${os}</b><b>${og}</b><strong>${pB}</strong>
        </div>
        <div class="fm-court ${courtClass} ${indoor?'indoor':''} cb-court cb-weather-${weatherClass} cb-event-${eventTier} ${specialClass} ${endsFlipped?'cb-ends-flipped':''}" style="${courtStyle(meta,surface)};--cb-visual-ms:${visualMs}ms">
          ${motionStyle}
          ${tracePoints?`<svg class="cb-rally-trace" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true"><polyline points="${tracePoints}"></polyline></svg>`:''}
          <i class="fm-court-line baseline top"></i><i class="fm-court-line baseline bottom"></i><i class="fm-court-line sideline left"></i><i class="fm-court-line sideline right"></i><i class="fm-court-line service horizontal top"></i><i class="fm-court-line service horizontal bottom"></i><i class="fm-court-line service vertical"></i><i class="fm-net"></i>
          <div class="cb-weather-fx" aria-hidden="true"></div>
          <div class="cb-crowd cb-crowd-top" aria-hidden="true"></div><div class="cb-crowd cb-crowd-bottom" aria-hidden="true"></div>
          <div class="cb-court-hud"><span>${phase}</span><b>${ambienceLabel} · ${wi(weather.condition)} ${Math.round(Number(weather.temperature_c||21))}° · ${Math.round(Number(weather.wind_kph||0))} km/h</b></div>
          ${stakeText?`<div class="cb-stake-banner cb-stake-${safe(stake)}">${safe(stakeText)}</div>`:''}
          ${lp.changeover?'<div class="cb-changeover">↔ Changement de côté</div>':''}
          ${meta?.tournament?.logo_url?`<img class="cb-court-watermark" src="${safe(meta.tournament.logo_url)}" alt="" onerror="this.style.display='none'">`:''}
          ${hasFlight?`<i class="cb-target-zone" style="left:${ballEnd.x}%;top:${ballEnd.y}%"></i>`:''}
          <div class="fm-player-dot opponent cb-dot cb-dot-motion ${slideOpp?'cb-clay-slide':''} ${oppWonLast?'cb-point-winner':userWonLast?'cb-point-loser':''}" style="left:${oppEnd.x}%;top:${oppEnd.y}%;animation:${oppAnim} ${visualMs}ms linear both"><span>${oInit}</span><small>${safe(oppName.split(' ').slice(-1)[0]||'ADV')}</small>${oppWonLast?'<em class="cb-reaction">POINT</em>':''}</div>
          <div class="fm-player-dot user cb-dot cb-dot-motion ${slideUser?'cb-clay-slide':''} ${userWonLast?'cb-point-winner':oppWonLast?'cb-point-loser':''}" style="left:${userEnd.x}%;top:${userEnd.y}%;animation:${userAnim} ${visualMs}ms linear both"><span>${uInit}</span><small>${safe(userName.split(' ').slice(-1)[0]||'MOI')}</small>${userWonLast?'<em class="cb-reaction">POINT</em>':''}</div>
          <i class="fm-ball cb-ball ${hasFlight?'cb-ball-flight':''}" style="left:${ballEnd.x}%;top:${ballEnd.y}%;animation:${ballAnim} ${visualMs}ms linear both"></i>
          ${lp.winner?`<div class="fm-rally-call cb-rally"><span>${phase}</span><b>${safe(call)}</b> · ${Number(lp.rally||0)} coups · ${safe(target)}</div>`:''}
        </div>
        ${shotRows.length?`<div class="cb-shot-strip"><span class="cb-shot-count">${shotRows.length} frappes</span>${shotRows.map((sh,i)=>`<span class="cb-shot-chip ${sh.hitter==='user'?'user':'opponent'} ${String(sh.spin||'').toLowerCase()} ${sh.stretched_receiver?'stretched':''}"><i>${i+1}</i><b>${sh.hitter==='user'?'MOI':'ADV'} · ${strokeLabel(sh.stroke)}</b><em>${safe(sh.spin||'Mixte')} · ${safe(patternLabel(sh.pattern))} · ${Math.round(Number(sh.speed_kph||0))} km/h${sh.stretched_receiver?' · débordé':''}</em></span>`).join('')}</div>`:''}
        <div class="cb-match-story">
          <div class="cb-point-story">
            <span class="badge">${phase}</span>
            <div><b>${lp.winner?safe(call):'Prêt à jouer'}</b><small>${lp.winner?(safe(lp.serve_direction||'mixte')+' · retour '+safe(lp.return_depth||'—')+' · '+shotRows.length+' frappes'+(styleText?' · '+safe(styleText):'')):'Le prochain point utilisera le moteur v5.'}</small></div>
          </div>
          <div class="cb-event-feed">
            ${eventRows.length?eventRows.map(e=>`<div class="cb-event-line ${e.winner==='user'?'user':e.winner==='opponent'?'opponent':''}"><span>${safe(phaseLabel(e.phase||e.kind))}</span><b>${safe(e.label||'Point')}</b><small>${e.kind==='point'?((Number(e.rally||0)+' coups')+(e.speed_kph?' · '+Math.round(Number(e.speed_kph))+' km/h':'')):(e.score||'')}</small></div>`).join(''):'<div class="cb-event-empty">Les événements du match apparaîtront ici.</div>'}
          </div>
        </div>
        <div class="fm-momentum"><span>${safe(oppName)}</span><div><i style="left:${momentum}%"></i></div><span>${safe(userName)}</span></div>
        <div class="cb-stat-grid">
          <div><span>Winners</span><b>${st.user_winners||0} - ${st.opp_winners||0}</b></div><div><span>Fautes</span><b>${st.user_errors||0} - ${st.opp_errors||0}</b></div><div><span>Aces</span><b>${st.user_aces||0} - ${st.opp_aces||0}</b></div>
          <div><span>1res IN</span><b>${pct(st.user_first_serves_in,st.user_first_serves)}% - ${pct(st.opp_first_serves_in,st.opp_first_serves)}%</b></div><div><span>DF</span><b>${st.user_double_faults||0} - ${st.opp_double_faults||0}</b></div><div><span>Filet</span><b>${st.user_net_points_won||0}/${st.user_net_points||0}</b></div>
        </div>
        ${!done?`<div class="cb-live-controls">
          <div class="cb-speed-row"><button class="${liveAutoTimer?'danger-btn':'primary'}" onclick="toggleLiveAuto()">${liveAutoTimer?'Pause':'▶ Live'}</button><button class="soft-btn" onclick="setLiveSpeed(1)">1x</button><button class="soft-btn" onclick="setLiveSpeed(2)">2x</button><button class="soft-btn" onclick="setLiveSpeed(4)">4x</button></div>
          <div class="cb-step-row"><button class="primary" onclick="playLivePoint()">Point</button><button class="soft-btn" onclick="simulateLiveGame()">Jeu</button><button class="soft-btn" onclick="simulateLiveSet()">Set</button><button class="soft-btn" onclick="simulateLiveMatch()">Match</button></div>
          <div class="cb-save-row"><button class="soft-btn" onclick="quickSaveLiveV1()">💾 Sauvegarder le score</button><button class="danger-btn" onclick="discardLiveMatchV1()">Quitter sans sauvegarder</button></div>
        </div><details class="cb-coach-panel" open><summary>Coaching tactique</summary>${coaching()}</details>`
        :isCommitted?(()=>{
          const r=local.lastCommittedMatchResult||{},out=r.tournament_outcome||{},tid=Number(s.tournament_id||0);
          const next=r.next_match_available&&tid?'<button class="primary" onclick="nextTournamentLiveMatchV1()">Match suivant</button>':'';
          const detail=out.terminal
            ?'<p>Parcours terminé · '+safe(out.user_round||'')+' · '+Number(out.user_points||0)+' pts · '+Number(out.user_prize_eur||0).toLocaleString('fr-FR')+' €</p>'
            :'<p>Résultat validé. '+(r.tournament_live?'Le parcours tournoi continue.':'Tu peux maintenant poursuivre ta carrière.')+'</p>';
          return `<div class="cb-result-box committed"><div><small>Résultat officiel · sauvegardé</small><h3>${safe(setScore)}</h3>${detail}</div><div class="cb-result-actions">${next}<button class="soft-btn" onclick="clearLiveMatch()">Fermer</button></div></div>`;
        })()
        :`<div class="cb-result-box"><div><small>Résultat provisoire</small><h3>${safe(setScore)}</h3><p>Rien n’est définitif tant que tu ne sauvegardes pas. Sauvegarder rend ce résultat officiel. Le brouillon fige le score sans l’intégrer à la carrière. Ne pas sauvegarder efface le match.</p></div><div class="cb-result-actions"><button class="primary" onclick="commitLiveMatchV1()">💾 Sauvegarder le résultat</button><button class="soft-btn" onclick="quickSaveLiveV1()">Figer comme brouillon</button><button class="danger-btn" onclick="discardLiveMatchV1()">Ne pas sauvegarder / rejouer</button></div></div>`}
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
      for(let i=0;i<80&&String(local.liveMatch?.status||'')==='active';i++){
        d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:tact()})});
        applyLiveMatchResponse(d);
      }
      persist();render();
      const ss=local.liveMatch,sc=score(ss);
      overlay.innerHTML=`<div class="modal"><div class="sheet cb-quick-result"><div class="eyebrow">Simulation rapide</div><h1>${safe(activePlayerCareerView().player_name||'Joueur')} · ${safe(sc)}</h1><p class="muted">Même moteur que le live. Résultat encore provisoire.</p><div class="cb-result-actions"><button class="primary" onclick="closeOverlay();commitLiveMatchV1()">💾 Sauvegarder ce résultat</button><button class="soft-btn" onclick="closeOverlay();quickSaveLiveV1()">Figer comme brouillon</button><button class="danger-btn" onclick="closeOverlay();discardLiveMatchV1()">Ne pas sauvegarder / rejouer</button></div></div></div>`;
    }catch(e){alert('Simulation rapide impossible : '+e.message)}
  };

  window.setTactic=(k,v)=>window.cbSetMatchTactic(k,v);
  console.info('Court Boss Match Center V7 Spatial Rally active');
})();