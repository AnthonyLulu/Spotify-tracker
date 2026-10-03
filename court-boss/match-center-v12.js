/* Court Boss Match Center V12.4 · Living Arena + Tactical Memory V4 */
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
    if(!live||!court)return;
    const s=sessionOf(),fx=s?.last_point?.environment_effects||{},plan=fx.opponent_plan||{},read=plan.memory_read||fx.opponent_memory_read||{};
    const confidence=Math.round(Number(read.confidence||0)*100),edge=Number(fx.opponent_memory_edge||0),deception=Number(fx.user_deception_edge||0);
    const deceptionWindow=Math.max(0,Math.round(Number(fx.opponent_deception_window_points??read.deception_window_points||0)));
    const patternAge=Math.max(0,Math.round(Number(read.pattern_age_points||0)));
    const switchAge=read.last_switch_age_points==null?null:Math.max(0,Math.round(Number(read.last_switch_age_points||0)));
    const state=String(fx.opponent_memory_state||(edge>.004?"IA t'a lu":edge<-.004?"Piège tactique réussi":"Lecture contestée"));
    const cls=edge>.004?'reading':edge<-.004?'fooled':'neutral';
    const pct=x=>Math.round(Number(x||0)*100);
    const readValue=x=>x?.value?String(x.value)+' · '+pct(x.share)+'%':'—';
    let card=live.querySelector('.cb-ai-read-v12');
    if(!card){card=el('div','cb-ai-read-v12 '+cls);court.insertAdjacentElement('afterend',card)}
    else{card.className='cb-ai-read-v12 '+cls;card.replaceChildren()}
    const head=el('div','cb-ai-read-head-v12');
    const left=el('div');left.append(el('small','',"ANALYSTE IA · MÉMOIRE V4"),el('b','',state));head.append(left,el('strong','',confidence+'%'));
    card.appendChild(head);
    const meta=el('div','cb-ai-read-meta-v12');
    meta.append(
      el('span','',Math.round(Number(read.total_points||0))+' pts observés'),
      el('span','',read.serve_read_source?'lecture '+read.serve_read_source:'lecture globale'),
      el('span','',patternAge+' pts sur ce schéma'),
      el('span','',Math.round(Number(read.switch_rate||0)*100)+'% changements'),
      el('span','',deception>0?'feinte +'+(deception*100).toFixed(1)+' pt':'contre '+(Math.max(0,edge)*100).toFixed(1)+' pt')
    );
    if(switchAge!==null)meta.appendChild(el('span','',switchAge===0?'switch maintenant':'switch il y a '+switchAge+' pts'));
    if(deceptionWindow>0)meta.appendChild(el('span','',"fenêtre de feinte · "+deceptionWindow+" pts"));
    card.appendChild(meta);
    const grid=el('div','cb-ai-read-grid-v12');
    const item=(label,value)=>{const d=el('div');d.append(el('span','',label),el('b','',value||'—'));return d};
    const seq=read.serve_sequence?.next
      ?'Après '+(read.serve_sequence.previous||'service')+' → '+read.serve_sequence.next+' · '+pct(read.serve_sequence.share)+'%'
      :'—';
    grid.append(
      item('Service attendu',readValue(read.serve_direction)),
      item('Séquence lue',seq),
      item('Cible attendue',readValue(read.target_wing)),
      item('Tempo / effet',(read.tempo?.value||'—')+' · '+(read.spin?.value||'—')),
      item('Risque lu',read.risk_mode||'—'),
      item('Jeu au filet',read.net_mode||'—'),
      item('Position retour',read.return_pos?.value||'—'),
      item('Plan de contre',plan.counterMode||plan.adaptation)
    );
    card.appendChild(grid);
    const note=edge<-.004
      ?(deceptionWindow>0
        ?'Tu as changé de plan alors que sa lecture était encore verrouillée. Pendant cette courte fenêtre, son anticipation part du mauvais côté et ta feinte est renforcée.'
        :'Tu viens de casser sa lecture. Elle s’est préparée au mauvais schéma et son anticipation te donne un petit avantage sur ce point.')
      :edge>.004
        ?'Ton schéma est devenu lisible. Si tu le répètes encore, son contre-plan continuera à gagner en valeur.'
        :confidence<35
          ?'Elle collecte encore les habitudes. Les points sous pression comptent davantage dans sa lecture.'
          :'La lecture existe, mais tu varies assez pour empêcher un contre net.';
    card.appendChild(el('p','',note));
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