/* Court Boss Match Center V13 · Identity, Tactical Lab, H2H & Doubles Replay */
(function(){
  const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=String(text);return n};
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const cap=(v,a,b)=>Math.max(a,Math.min(b,Number(v)||0));
  const live=()=>typeof local!=='undefined'?local.liveMatch:null;
  const meta=()=>live()?.stats?._meta||{};
  const fx=()=>live()?.last_point?.environment_effects||{};
  const visual=()=>live()?.last_point?.visual||{};
  const opp=()=>typeof local!=='undefined'?(local.liveOpponent||{}):{};
  const slug=s=>String(s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,'-');
  let audioOn=localStorage.getItem('cbMatchAudioV13')!=='0',audioCtx=null,lastAudioKey='';
  window.cbToggleMatchAudioV13=()=>{
    audioOn=!audioOn;localStorage.setItem('cbMatchAudioV13',audioOn?'1':'0');
    if(audioOn)ensureAudio();if(typeof render==='function')render();
  };
  const ensureAudio=()=>{
    if(!audioOn)return null;
    try{
      const C=window.AudioContext||window.webkitAudioContext;
      if(!C)return null;
      audioCtx=audioCtx||new C();
      if(audioCtx.state==='suspended')audioCtx.resume().catch(()=>{});
      return audioCtx;
    }catch{return null}
  };
  const crowdCue=(strength=.35,duration=.45)=>{
    const ctx=ensureAudio();if(!ctx||ctx.state!=='running')return;
    const len=Math.max(1,Math.floor(ctx.sampleRate*duration)),buf=ctx.createBuffer(1,len,ctx.sampleRate),d=buf.getChannelData(0);
    for(let i=0;i<len;i++)d[i]=(Math.random()*2-1)*(1-i/len);
    const src=ctx.createBufferSource(),filter=ctx.createBiquadFilter(),gain=ctx.createGain();
    filter.type='bandpass';filter.frequency.value=750;filter.Q.value=.45;
    gain.gain.setValueAtTime(.0001,ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(Math.max(.003,Math.min(.045,.012+strength*.025)),ctx.currentTime+.04);
    gain.gain.exponentialRampToValueAtTime(.0001,ctx.currentTime+duration);
    src.buffer=buf;src.connect(filter);filter.connect(gain);gain.connect(ctx.destination);src.start();
  };
  document.addEventListener('pointerdown',()=>{if(audioOn)ensureAudio()},{passive:true});

  window.cbToggleAutoRuleV13=(key)=>{
    if(typeof local==='undefined')return;
    local.tactics=local.tactics||{};
    local.tactics.autoRules={...(local.tactics.autoRules||{}),[key]:!Boolean(local.tactics.autoRules?.[key])};
    if(typeof persist==='function')persist();
    if(typeof render==='function')render();
  };

  const tournamentSkin=(name,category)=>{
    const n=(String(name||'')+' '+String(category||'')).toLowerCase();
    if(/australian open/.test(n))return 'ao';
    if(/roland|french open/.test(n))return 'rg';
    if(/wimbledon/.test(n))return 'wimbledon';
    if(/us open/.test(n))return 'uso';
    if(/laver/.test(n))return 'laver';
    if(/next gen/.test(n))return 'nextgen';
    if(/atp finals|nitto/.test(n))return 'finals';
    return 'tour';
  };

  const identityClass=p=>{
    const a=slug(p?.archetype||'all-court');
    const hand=/left|gauch/i.test(String(p?.handedness||''))?'lefty':'righty';
    const depth=slug(p?.baseline_depth||'neutre');
    return ['cb-id-'+a,'cb-hand-'+hand,'cb-depth-'+depth].join(' ');
  };

  const addIdentity=()=>{
    const court=document.querySelector('.cb-live-card .cb-court');if(!court)return;
    const v=visual(),profiles=v.profiles||{},m=meta(),t=m.tournament||{};
    const user=court.querySelector('.fm-player-dot.user'),opponent=court.querySelector('.fm-player-dot.opponent');
    if(user){user.classList.add(...identityClass(profiles.user).split(' '));user.dataset.cbIdentity='1'}
    if(opponent){opponent.classList.add(...identityClass(profiles.opponent).split(' '));opponent.dataset.cbIdentity='1'}
    const skin=tournamentSkin(t.name,t.category);
    court.dataset.cbTournamentSkin=skin;
    court.classList.toggle('cb-night',String(m.ambience?.session_of_day||'')==='night');
    court.classList.toggle('cb-day',String(m.ambience?.session_of_day||'')==='day');
    court.style.setProperty('--cb-crowd-intensity',String(cap(m.ambience?.crowd_intensity||45,15,100)/100));
    const stake=String(v.stake||live()?.last_point?.stake||'normal');
    court.classList.toggle('cb-crowd-roar',['break_point','set_point','match_point','tiebreak'].includes(stake));
  };

  const liveDoublesPlanLabel=plan=>({balanced:'Équilibré',poach:'Poach agressif',australian:'Australienne',target_weak:'Cibler faible',safe:'Sécuriser'}[String(plan||'balanced')]||'Équilibré');
  window.cbSetLiveDoublesPlanV13=plan=>{
    if(typeof local==='undefined')return;
    local.tactics={...(local.tactics||{}),doublesPlan:String(plan||'balanced')};
    local.doublesTactics={...(local.doublesTactics||{}),plan:String(plan||'balanced')};
    if(typeof persist==='function')persist();
    if(typeof render==='function')render();
  };
  const liveDoublesFramesCss=(name,frames,key)=>{
    const valid=(Array.isArray(frames)?frames:[]).filter(f=>f&&f[key]);
    if(!valid.length)return '';
    return '@keyframes '+name+'{'+valid.map((f,i)=>{
      const p=f[key]||{},pct=valid.length===1?100:i/(valid.length-1)*100;
      return pct.toFixed(1)+'%{left:'+cap(p.x,0,100)+'%;top:'+cap(p.y,0,100)+'%}';
    }).join('')+'}';
  };
  const dotText=(dot,p)=>{
    if(!dot||!p)return;
    const parts=String(p.name||'JOUEUR').trim().split(/\s+/),last=parts.slice(-1)[0]||'Joueur';
    const initials=parts.map(x=>x[0]||'').join('').slice(0,2).toUpperCase();
    let sp=dot.querySelector('span');if(!sp){sp=el('span');dot.appendChild(sp)}if(sp.textContent!==(initials||'P'))sp.textContent=initials||'P';
    let sm=dot.querySelector('small');if(!sm){sm=el('small');dot.appendChild(sm)}if(sm.textContent!==last)sm.textContent=last;
  };
  const addLiveDoublesDots=()=>{
    const court=document.querySelector('.cb-live-card .cb-court'),sess=live(),m=meta(),v=visual();
    if(!court)return;
    const existing=[...court.querySelectorAll('.cb-live-double-partner-v13')];
    if(String(m.match_type||'')!=='doubles'||!v?.doubles){existing.forEach(x=>x.remove());court.querySelector('style[data-cb-live-doubles-v13]')?.remove();return}
    const players=v.doubles_players||m.doubles||{},u=players.user||m.doubles?.user_players||[],o=players.opponent||m.doubles?.opponent_players||[];
    const frames=Array.isArray(v.frames)?v.frames:[],last=frames[frames.length-1]||{};
    const point=Number(sess?.last_point?.point_no||0),sid=Number(sess?.id||0),ms=Math.max(500,Number(v.duration_ms||1100));
    let style=court.querySelector('style[data-cb-live-doubles-v13]');
    if(!style){style=document.createElement('style');style.dataset.cbLiveDoublesV13='1';court.appendChild(style)}
    const ua='cbDblUa'+sid+'p'+point,ub='cbDblUb'+sid+'p'+point,oa='cbDblOa'+sid+'p'+point,ob='cbDblOb'+sid+'p'+point;
    const nextFrameCss=liveDoublesFramesCss(ua,frames,'user')+liveDoublesFramesCss(ub,frames,'user_b')+liveDoublesFramesCss(oa,frames,'opponent')+liveDoublesFramesCss(ob,frames,'opponent_b');
    if(style.textContent!==nextFrameCss)style.textContent=nextFrameCss;

    const mainU=court.querySelector('.fm-player-dot.user:not(.cb-live-double-partner-v13)');
    const mainO=court.querySelector('.fm-player-dot.opponent:not(.cb-live-double-partner-v13)');
    if(mainU&&u[0]){dotText(mainU,u[0]);if(frames.length)mainU.style.animation=ua+' '+ms+'ms cubic-bezier(.18,.72,.22,1) both'}
    if(mainO&&o[0]){dotText(mainO,o[0]);if(frames.length)mainO.style.animation=oa+' '+ms+'ms cubic-bezier(.18,.72,.22,1) both'}

    const ensure=(cls,team,p,end,keyframe)=>{
      let d=court.querySelector('.cb-live-double-partner-v13.'+cls);
      if(!d){d=el('div','fm-player-dot cb-dot cb-live-double-partner-v13 '+team+' '+cls);court.appendChild(d)}
      dotText(d,p);
      d.style.left=cap(end?.x??50,0,100)+'%';d.style.top=cap(end?.y??50,0,100)+'%';
      if(frames.length)d.style.animation=keyframe+' '+ms+'ms cubic-bezier(.18,.72,.22,1) both';
      const pid=Number(p?.id||0),lp=sess?.last_point||{};
      d.classList.toggle('is-server',pid&&pid===Number(lp.server_player_id||0));
      d.classList.toggle('is-returner',pid&&pid===Number(lp.returner_player_id||0));
      return d;
    };
    ensure('user-b','user',u[1],last.user_b,ub);
    ensure('opponent-b','opponent',o[1],last.opponent_b,ob);
    if(mainU&&u[0]){const pid=Number(u[0].id||0),lp=sess?.last_point||{};mainU.classList.toggle('is-server',pid===Number(lp.server_player_id||0));mainU.classList.toggle('is-returner',pid===Number(lp.returner_player_id||0))}
    if(mainO&&o[0]){const pid=Number(o[0].id||0),lp=sess?.last_point||{};mainO.classList.toggle('is-server',pid===Number(lp.server_player_id||0));mainO.classList.toggle('is-returner',pid===Number(lp.returner_player_id||0))}
    court.classList.add('cb-live-doubles-court-v13');
  };

  const heatStore=()=>{
    const s=live();if(!s)return [];
    window.__cbHeatV13=window.__cbHeatV13||{};
    const key=String(s.id||'live'),store=window.__cbHeatV13[key]||{last:0,rows:[]};
    const p=Number(s.last_point?.point_no||0),shots=Array.isArray(s.last_point?.visual?.shots)?s.last_point.visual.shots:[];
    if(p&&p!==store.last){
      shots.forEach(x=>{if(Number.isFinite(Number(x.target_x))&&Number.isFinite(Number(x.target_y)))store.rows.push({x:Number(x.target_x),y:Number(x.target_y),hitter:x.hitter})});
      store.rows=store.rows.slice(-80);store.last=p;window.__cbHeatV13[key]=store;
    }
    return store.rows;
  };
  const heatHtml=()=>{
    const rows=heatStore(),bins=Array.from({length:25},()=>0);
    rows.forEach(p=>{const x=Math.max(0,Math.min(4,Math.floor(p.x/20))),y=Math.max(0,Math.min(4,Math.floor(p.y/20)));bins[y*5+x]++});
    const mx=Math.max(1,...bins);
    return '<div class="cb-heat-v13">'+bins.map((v,i)=>'<i style="--v:'+(v/mx).toFixed(2)+'" title="'+v+' impacts"></i>').join('')+'</div>';
  };

  const pct=(a,b)=>Number(b||0)>0?Math.round(Number(a||0)/Number(b)*100):0;
  const recommendation=()=>{
    const s=live(),st=s?.stats||{},p=fx().opponent_plan||{},read=p.memory_read||fx().opponent_memory_read||{};
    const userFat=Number(fx().user_condition_detail?.effective_fatigue||0);
    if(userFat>=72)return 'Baisse légèrement l’effort. Ton niveau physique commence à coûter plus que ton agressivité ne rapporte.';
    if(Number(read.confidence||0)>=.62&&Number(fx().opponent_memory_edge||0)>.006)return 'Ton schéma est trop lisible. Change au moins deux paramètres ensemble : service + tempo, ou cible + position de retour.';
    if(p.targetWing==='Revers'&&Number(st.user_errors||0)>Number(st.user_winners||0))return 'L’adversaire insiste sur ton revers. Réduis le risque et joue plus croisé avant de chercher la ligne.';
    if(p.net>=48)return 'Il monte souvent. Passing et lob doivent devenir prioritaires, surtout côté faible.';
    if(p.tempo==='Patient')return 'Il veut t’enfermer dans les échanges. Prends la balle plus tôt ou monte après une balle courte.';
    return 'Le duel reste équilibré. Garde ton plan et change seulement si une tendance devient stable sur plusieurs points.';
  };

  const ruleButton=(key,label)=>{
    const active=Boolean(typeof local!=='undefined'&&local.tactics?.autoRules?.[key]);
    return '<button class="cb-auto-rule-v13 '+(active?'active':'')+'" onclick="cbToggleAutoRuleV13(\''+key+'\')">'+label+'</button>';
  };

  const addTacticalLab=()=>{
    const card=document.querySelector('.cb-live-card');const court=card?.querySelector('.cb-court');if(!card||!court)return;
    const s=live(),st=s?.stats||{},m=meta(),p=fx().opponent_plan||{},h2h=m.h2h_memory||{},profiles=visual().profiles||{};
    const review=s?.last_point?.line_review||null;
    const audioKey=[s?.id||0,s?.last_point?.point_no||0,s?.last_point?.environment_event?.id||'',review?.point_no||''].join('|');
    if(audioKey!==lastAudioKey){
      lastAudioKey=audioKey;
      const stake=String(s?.last_point?.visual?.stake||s?.last_point?.stake||'normal');
      const strength=stake==='match_point'?1:stake==='set_point' ? .78 : stake==='break_point' ? .62 : s?.last_point?.ace ? .68 : .32;
      if(Number(s?.last_point?.point_no||0)>0||s?.last_point?.environment_event)crowdCue(strength,strength>.7?.72:.42);
    }
    let lab=card.querySelector('.cb-tactical-lab-v13');
    if(!lab){lab=el('section','cb-tactical-lab-v13');const ai=card.querySelector('.cb-ai-read-v12');(ai||court).insertAdjacentElement('afterend',lab)}
    const applied=Array.isArray(fx().situational_rules_applied)?fx().situational_rules_applied:[];
    const pending=(Array.isArray(m.event_schedule)?m.event_schedule:[]).filter(e=>!(st._environment_events_handled||[]).includes(String(e.id||'')));
    const event=s?.last_point?.environment_event||fx().ambient_event||null;
    const serveUser=pct(st.user_first_serves_in,st.user_first_serves),serveOpp=pct(st.opp_first_serves_in,st.opp_first_serves);
    const netUser=pct(st.user_net_points_won,st.user_net_points),netOpp=pct(st.opp_net_points_won,st.opp_net_points);
    const u=profiles.user||{},o=profiles.opponent||{};
    const isDoubles=String(m.match_type||'')==='doubles',dm=m.doubles||{},lp=s?.last_point||{};
    const doublesModel=isDoubles
      ?'<div class="cb-double-live-model-v13"><div><span>Modèle paire</span><b>Attributs '+Math.round(Number(dm.attribute_probability||.5)*100)+'% · Elo '+Math.round(Number(dm.elo_probability||.5)*100)+'% · mix '+Math.round(Number(dm.baseline_probability||.5)*100)+'%</b></div><div><span>Elo double/surface</span><b>'+Math.round(Number(dm.user_pair_elo||0))+' vs '+Math.round(Number(dm.opponent_pair_elo||0))+'</b></div><div><span>Point actuel</span><b>'+esc(lp.server_player_name||'—')+' sert · '+esc(lp.returner_player_name||'—')+' retourne</b></div><div><span>Plan</span><b>'+esc(liveDoublesPlanLabel(local?.tactics?.doublesPlan||s?.tactics?.doublesPlan))+'</b></div></div>'
      :'';
    const doublesPlans=isDoubles
      ?'<div class="cb-live-double-plans-v13"><div class="cb-subhead-v13">Plan de paire · modifiable en match</div><div>'+[
        ['balanced','Équilibré'],['poach','Poach'],['australian','Australienne'],['target_weak','Cibler faible'],['safe','Sécuriser']
       ].map(x=>'<button class="'+(String(local?.tactics?.doublesPlan||s?.tactics?.doublesPlan||'balanced')===x[0]?'active':'')+'" onclick="cbSetLiveDoublesPlanV13(\''+x[0]+'\')">'+x[1]+'</button>').join('')+'</div></div>'
      :'';
    const labHtml=
      '<div class="cb-lab-head-v13"><div><small>TACTICAL LAB V13</small><b>Match vivant · lecture + identité</b></div><div class="cb-lab-actions-v13"><span>'+esc(String(m.ambience?.crowd_profile||'Tour'))+' · '+esc(String(m.ambience?.session_of_day||'live'))+' · public '+Math.round(Number(m.ambience?.crowd_intensity||0))+'%</span><button onclick="cbToggleMatchAudioV13()">'+(audioOn?'🔊':'🔇')+'</button></div></div>'+
      (event?'<div class="cb-event-v13"><b>'+esc(event.label||'Événement match')+'</b><span>'+esc(event.type||event.event_type||'')+(event.duration_min?' · '+Number(event.duration_min)+' min':'')+'</span></div>':'')+
      (review?'<div class="cb-event-v13 review"><b>'+esc(review.label||'Review électronique')+'</b><span>'+esc(review.system||'Electronic Line Calling')+' · '+esc(review.decision||'confirmé')+'</span></div>':'')+
      doublesModel+
      '<div class="cb-lab-grid-v13">'+
        '<div class="cb-lab-block-v13"><span>Identité de ton joueur</span><b>'+esc(u.archetype||'All-court')+' · '+esc(u.handedness||'')+'</b><em>'+esc(u.movement_signature||'')+' · '+esc(u.baseline_depth||'')+'</em></div>'+
        '<div class="cb-lab-block-v13"><span>Identité adverse</span><b>'+esc(o.archetype||p.archetype||'All-court')+' · '+esc(o.handedness||'')+'</b><em>'+esc(o.movement_signature||'')+' · retour '+esc(o.return_position||p.returnPos||'Neutre')+'</em></div>'+
        '<div class="cb-lab-block-v13"><span>H2H mémorisé</span><b>'+Number(h2h.encounters||0)+' confrontation(s)</b><em>'+Number(h2h.carryover_points||0)+' points tactiques repris'+(h2h.last_score?' · '+esc(h2h.last_score):'')+'</em></div>'+
        '<div class="cb-lab-block-v13"><span>Pourquoi l’IA ajuste</span><b>'+esc(p.counterMode||p.adaptation||'Plan naturel')+'</b><em>Cible '+esc(p.targetWing||'Mixte')+' · '+esc(p.tempo||'Neutre')+' · '+esc(p.spin||'Mixte')+'</em></div>'+
      '</div>'+
      '<div class="cb-lab-middle-v13"><div><div class="cb-subhead-v13">Heatmap des frappes récentes</div>'+heatHtml()+'</div>'+
        '<div class="cb-live-numbers-v13"><div><span>1res balles</span><b>'+serveUser+'% / '+serveOpp+'%</b></div><div><span>Filet gagné</span><b>'+netUser+'% / '+netOpp+'%</b></div><div><span>Winners / fautes</span><b>'+Number(st.user_winners||0)+' / '+Number(st.user_errors||0)+'</b></div><div><span>Échanges 9+</span><b>'+Number(st.user_long_rallies_won||0)+'-'+Number(st.opp_long_rallies_won||0)+'</b></div></div>'+
      '</div>'+
      '<div class="cb-coach-rec-v13"><small>COACH</small><b>'+esc(recommendation())+'</b></div>'+
      '<div class="cb-auto-v13"><div class="cb-subhead-v13">Règles conditionnelles</div><div>'+ruleButton('attackSecondServe','Attaquer 2e balle')+ruleButton('bigPoints','Points chauds')+ruleButton('frontRun','Protéger avance')+ruleButton('chase','Mode remontée')+'</div>'+(applied.length?'<p>Actif sur ce point : <b>'+applied.map(esc).join(' · ')+'</b></p>':'')+'</div>'+
      doublesPlans+
      (pending.length?'<div class="cb-pending-events-v13">Événements possibles : '+pending.map(e=>esc(e.label||e.type)).join(' · ')+'</div>':'');
    if(lab.innerHTML!==labHtml)lab.innerHTML=labHtml;
  };


  const rawPlayDoubles=typeof window.playDoublesTournament==='function'?window.playDoublesTournament:null;
  window.cbRunDoublesPlanV13=(id,plan,mode='live')=>{
    if(typeof local!=='undefined'){
      local.doublesTactics={plan:String(plan||'balanced')};
      local.tactics={...(local.tactics||{}),doublesPlan:String(plan||'balanced')};
      if(typeof persist==='function')persist();
    }
    if(mode==='sim'){
      if(rawPlayDoubles)rawPlayDoubles(Number(id));
      return;
    }
    if(typeof window.startTournamentLiveDoubles==='function')window.startTournamentLiveDoubles(Number(id),false);
  };
  if(rawPlayDoubles)window.playDoublesTournament=(id)=>{
    const host=document.getElementById('overlay');if(!host)return rawPlayDoubles(Number(id));
    const plans=[
      ['balanced','Équilibré','La paire joue selon ses qualités naturelles, sans biais forcé.'],
      ['poach','Poach agressif','Le joueur au filet coupe davantage. Fort avec volée, réaction et communication.'],
      ['australian','Formation australienne','Décalage au service et au filet pour casser les angles de retour.'],
      ['target_weak','Cibler le plus faible','Insiste sur le retourneur ou volleyeur adverse le plus attaquable.'],
      ['safe','Sécuriser','Plus de discipline, moins de prise de risque, priorité à la communication.']
    ];
    host.innerHTML='<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet cb-double-plan-sheet-v13"><div class="sheet-head"><div><div class="eyebrow">Match Center Double</div><h1>Choisis ton plan de paire</h1><div class="muted">Tu peux le jouer point par point avec 4 joueurs, ou simuler directement. Le même plan agit dans les deux modes.</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="cb-double-plan-grid-v13">'+plans.map(p=>'<div class="cb-double-plan-card-v13"><b>'+p[1]+'</b><span>'+p[2]+'</span><div><button class="primary" onclick="cbRunDoublesPlanV13('+Number(id)+',\''+p[0]+'\',\'live\')">Jouer live</button><button class="ghost" onclick="cbRunDoublesPlanV13('+Number(id)+',\''+p[0]+'\',\'sim\')">Simuler</button></div></div>').join('')+'</div></div></div>';
  };

  const doublesAnim=(id,frames,key)=>{
    const pts=frames.map((f,i)=>{const p=f[key]||{};return (i/(Math.max(1,frames.length-1))*100).toFixed(1)+'%{left:'+cap(p.x,0,100)+'%;top:'+cap(p.y,0,100)+'%}'}).join('');
    return '@keyframes '+id+'{'+pts+'}';
  };
  window.cbDoublesReplayHtmlV13=(matches)=>{
    const rows=(Array.isArray(matches)?matches:[]).filter(m=>m?.visual?.frames?.length);
    if(!rows.length)return '';
    return '<div class="cb-double-replays-v13"><div class="cb-subhead-v13">Double · replay tactique 4 joueurs</div>'+rows.map((m,idx)=>{
      const v=m.visual,fr=v.frames||[],id='cbd'+idx+'_'+Math.abs(String(m.round_name||'').split('').reduce((a,c)=>a+c.charCodeAt(0),0));
      const names=[...(v.user_players||[]),...(v.opponent_players||[])];
      const init=n=>esc(String(n||'?').split(/\s+/).slice(-1)[0].slice(0,3).toUpperCase());
      const last=fr[fr.length-1]||{};
      const style='<style>'+doublesAnim(id+'ua',fr,'user_a')+doublesAnim(id+'ub',fr,'user_b')+doublesAnim(id+'oa',fr,'opp_a')+doublesAnim(id+'ob',fr,'opp_b')+doublesAnim(id+'ball',fr,'ball')+'</style>';
      return '<div class="cb-double-replay-v13">'+style+'<div class="cb-double-head-v13"><b>'+esc(m.round_name)+' · '+esc(m.score)+'</b><span>'+esc(v.formation)+' · '+esc(v.manager_plan||'balanced')+' · poach '+Number(v.poach_intent||0)+'% · com '+Number(v.communication||0)+'%</span></div>'+
        '<div class="cb-double-court-v13"><i class="line net"></i><i class="line base a"></i><i class="line base b"></i>'+
          '<div class="p user a" style="left:'+cap(last.user_a?.x,0,100)+'%;top:'+cap(last.user_a?.y,0,100)+'%;animation:'+id+'ua 3.8s ease-in-out infinite alternate">'+init(names[0]?.name)+'</div>'+
          '<div class="p user b" style="left:'+cap(last.user_b?.x,0,100)+'%;top:'+cap(last.user_b?.y,0,100)+'%;animation:'+id+'ub 3.8s ease-in-out infinite alternate">'+init(names[1]?.name)+'</div>'+
          '<div class="p opp a" style="left:'+cap(last.opp_a?.x,0,100)+'%;top:'+cap(last.opp_a?.y,0,100)+'%;animation:'+id+'oa 3.8s ease-in-out infinite alternate">'+init(names[2]?.name)+'</div>'+
          '<div class="p opp b" style="left:'+cap(last.opp_b?.x,0,100)+'%;top:'+cap(last.opp_b?.y,0,100)+'%;animation:'+id+'ob 3.8s ease-in-out infinite alternate">'+init(names[3]?.name)+'</div>'+
          '<i class="ball" style="left:'+cap(last.ball?.x,0,100)+'%;top:'+cap(last.ball?.y,0,100)+'%;animation:'+id+'ball 3.8s ease-in-out infinite alternate"></i>'+
        '</div><p>Cible prioritaire : <b>'+esc(v.target_player_name||'—')+'</b> · '+esc(v.target_reason||'')+'</p></div>';
    }).join('')+'</div>';
  };

  let queued=false;
  const enhance=()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;addIdentity();addLiveDoublesDots();addTacticalLab()})};
  const root=document.getElementById('app')||document.body;
  new MutationObserver(enhance).observe(root,{childList:true,subtree:true});
  enhance();
  console.info('Court Boss Match Center V13 active');
})();