/* Court Boss Match Center V12 · Living Arena */
(function(){
  const plans={
    balanced:{label:'Équilibré',aggression:56,risk:50,net:28,effort:60,returnPos:'Neutre',servePattern:'Mixte',targetWing:'Mixte',tempo:'Neutre',spin:'Mixte'},
    pressure:{label:'Mettre la pression',aggression:70,risk:61,net:38,effort:72,returnPos:'Avancée',servePattern:'Large',targetWing:'Revers',tempo:'Rapide',spin:'Plat'},
    patient:{label:'Faire jouer',aggression:46,risk:36,net:18,effort:58,returnPos:'Reculée',servePattern:'Mixte',targetWing:'Revers',tempo:'Patient',spin:'Lift'},
    net:{label:'Prendre le filet',aggression:66,risk:54,net:72,effort:68,returnPos:'Avancée',servePattern:'Large',targetWing:'Revers',tempo:'Rapide',spin:'Slice'},
    protect:{label:'Fermer le jeu',aggression:44,risk:30,net:16,effort:50,returnPos:'Neutre',servePattern:'Corps',targetWing:'Mixte',tempo:'Patient',spin:'Mixte'},
    redline:{label:'Tout donner',aggression:82,risk:74,net:46,effort:88,returnPos:'Avancée',servePattern:'Large',targetWing:'Revers',tempo:'Rapide',spin:'Plat'}
  };
  const el=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!=null)node.textContent=String(text);return node};
  const lastName=name=>String(name||'Joueur').trim().split(/\s+/).slice(-1)[0]||'Joueur';
  const metaOf=()=>typeof local!=='undefined'&&local.liveMatch?((local.liveMatch.stats||{})._meta||{}):{};
  const sessionOf=()=>typeof local!=='undefined'?local.liveMatch:null;
  const opponentOf=()=>typeof local!=='undefined'?(local.liveOpponent||{}):{};
  window.cbApplyMatchPlanV12=(key)=>{
    if(typeof local==='undefined')return;
    const p=plans[String(key||'balanced')]||plans.balanced;
    local.tactics={...(local.tactics||{}),...p};
    delete local.tactics.label;
    local.lastMatchPlan=String(key||'balanced');
    if(typeof persist==='function')persist();
    if(typeof render==='function')render();
  };
  const arenaLevel=(meta,opp)=>{
    const round=String(meta.round||'').toUpperCase();
    const category=String(meta.tournament?.category||'').toLowerCase();
    const major=/grand chelem|grand slam/.test(category),masters=/masters|1000/.test(category);
    const rank=Number(opp?.ranking||9999);
    if(/(^|\b)(F|SF)(\b|$)|FINALE|DEMI/.test(round)||(major&&(/QF|QUART/.test(round)||rank<=10))||(masters&&/QF|QUART/.test(round)))return 'center';
    if(major||masters||rank<=32)return 'show';
    return 'outer';
  };
  const addArena=()=>{
    const court=document.querySelector('.cb-court');
    if(!court||court.dataset.livingArena==='1')return;
    court.dataset.livingArena='1';
    const s=sessionOf(),meta=metaOf(),opp=opponentOf(),level=arenaLevel(meta,opp),t=meta.tournament||{};
    court.classList.add('cb-arena-'+level);
    const label=level==='center'?'Court central':level==='show'?'Show court':'Court annexe';
    const shell=el('div','cb-arena-shell-v12');
    ['north','south','west','east'].forEach(side=>shell.appendChild(el('div','cb-stand-v12 cb-stand-'+side)));
    const tower=el('div','cb-score-tower-v12');tower.append(el('small','',String(meta.round||'LIVE')),el('b','',label));shell.appendChild(tower);
    const boardTexts=[t.name||'COURT BOSS',t.circuit||t.category||'TENNIS',t.city||'TOUR',t.category||'MATCH CENTER'];
    ['nw','ne','sw','se'].forEach((pos,i)=>shell.appendChild(el('div','cb-ad-board-v12 cb-ad-'+pos,boardTexts[i])));
    const ump=el('div','cb-umpire-v12');ump.append(el('i'),el('small','','ARBITRE'));shell.appendChild(ump);
    shell.append(el('i','cb-ballkid-v12 cb-ballkid-a'),el('i','cb-ballkid-v12 cb-ballkid-b'));
    const playerName=(typeof activePlayerCareerView==='function'?activePlayerCareerView()?.player_name:null)||'Joueur';
    const uc=s?.last_point?.environment_effects?.user_condition_detail||{},oc=s?.last_point?.environment_effects?.opponent_condition_detail||{};
    const bench=(side,name,cond)=>{
      const b=el('div','cb-bench-v12 cb-bench-'+side);b.append(el('span','',lastName(name)));
      const meter=el('i'),fill=el('b');fill.style.width=Math.max(0,Math.min(100,100-Number(cond.effective_fatigue||20)))+'%';meter.appendChild(fill);b.appendChild(meter);return b;
    };
    shell.append(bench('user',playerName,uc),bench('opp',opp.name||'ADV',oc));court.prepend(shell);
    const hud=court.querySelector('.cb-court-hud b');if(hud&&!hud.textContent.includes(label))hud.textContent=label+' · '+hud.textContent;
  };
  const addPlans=()=>{
    document.querySelectorAll('.cb-coach-panel').forEach(panel=>{
      if(panel.querySelector('.cb-plan-strip-v12'))return;
      const strip=el('div','cb-plan-strip-v12');
      Object.entries(plans).forEach(([key,p])=>{
        const active=typeof local!=='undefined'&&local.lastMatchPlan===key;
        const b=el('button','cb-plan-v12'+(active?' active':''),p.label);b.type='button';b.addEventListener('click',()=>window.cbApplyMatchPlanV12(key));strip.appendChild(b);
      });
      const grid=panel.querySelector('.cb-coach-grid');if(grid)panel.insertBefore(strip,grid);else panel.appendChild(strip);
    });
  };
  const addAIRead=()=>{
    const live=document.querySelector('.cb-live-card'),court=live?.querySelector('.cb-court');
    if(!live||!court||live.querySelector('.cb-ai-read-v12'))return;
    const s=sessionOf(),fx=s?.last_point?.environment_effects||{},plan=fx.opponent_plan||{},read=plan.memory_read||fx.opponent_memory_read||{};
    const confidence=Math.round(Number(read.confidence||0)*100),edge=Number(fx.opponent_memory_edge||0);
    const state=edge>.004?'Lecture juste':edge<-.004?'IA piégée':'Lecture incertaine';
    const cls=edge>.004?'reading':edge<-.004?'fooled':'neutral';
    const card=el('div','cb-ai-read-v12 '+cls);
    const head=el('div','cb-ai-read-head-v12');
    const left=el('div');left.append(el('small','',"LECTURE IA"),el('b','',state));head.append(left,el('strong','',confidence+'%'));
    card.appendChild(head);
    const grid=el('div','cb-ai-read-grid-v12');
    const item=(label,value)=>{const d=el('div');d.append(el('span','',label),el('b','',value||'—'));return d};
    grid.append(
      item('Service attendu',read.serve_direction?.value),
      item('Cible attendue',read.target_wing?.value),
      item('Tempo attendu',read.tempo?.value),
      item('Plan de contre',plan.counterMode||plan.adaptation)
    );
    card.appendChild(grid);
    const note=edge<-.004
      ?'Tu as cassé un pattern que l’IA pensait fiable. Son anticipation devient un handicap sur ce point.'
      :edge>.004
        ?'Tu répètes un schéma qu’elle a identifié. Elle bénéficie de son anticipation.'
        :'Elle n’a pas encore assez de données fiables ou tu varies suffisamment.';
    card.appendChild(el('p','',note));
    court.insertAdjacentElement('afterend',card);
  };

  const addChangeoverCoach=()=>{
    const change=document.querySelector('.cb-changeover'),live=document.querySelector('.cb-live-card');
    if(!change||!live||live.querySelector('.cb-changeover-coach-v12'))return;
    const s=sessionOf(),opp=opponentOf(),plan=s?.last_point?.environment_effects?.opponent_plan||{};
    const uc=s?.last_point?.environment_effects?.user_condition_detail||{},oc=s?.last_point?.environment_effects?.opponent_condition_detail||{};
    const userEnergy=Math.max(0,Math.min(100,100-Number(uc.effective_fatigue||20)));
    const oppEnergy=Math.max(0,Math.min(100,100-Number(oc.effective_fatigue||20)));
    const box=el('div','cb-changeover-coach-v12'),head=el('div','cb-changeover-head-v12');
    head.append(el('div','','CHANGEMENT DE CÔTÉ'),el('b','','Fenêtre manager'));box.appendChild(head);
    const read=el('div','cb-changeover-read-v12');
    read.append(el('span','','Ton joueur · énergie '+Math.round(userEnergy)+'%'),el('span','',lastName(opp.name||'Adversaire')+' · énergie '+Math.round(oppEnergy)+'%'));box.appendChild(read);
    const tip=plan.adaptation?'IA adverse : '+plan.adaptation+' · cible '+(plan.targetWing||'Mixte')+' · tempo '+(plan.tempo||'Neutre'):'Lis le momentum et ajuste ton plan avant le prochain jeu.';
    box.appendChild(el('p','',tip));
    const strip=el('div','cb-plan-strip-v12');
    Object.entries(plans).forEach(([key,p])=>{const b=el('button','cb-plan-v12',p.label);b.type='button';b.onclick=()=>window.cbApplyMatchPlanV12(key);strip.appendChild(b)});
    box.appendChild(strip);
    const court=live.querySelector('.cb-court');if(court)court.insertAdjacentElement('afterend',box);
  };
  let queued=false;
  const enhance=()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;addArena();addPlans();addAIRead();addChangeoverCoach()})};
  const root=document.getElementById('app')||document.body;new MutationObserver(enhance).observe(root,{childList:true,subtree:true});enhance();
  console.info('Court Boss Match Center V12 Living Arena active');
})();