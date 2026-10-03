/* Court Boss Medical V15 · play hurt / withdraw + long-term injury visibility */
(function(){
  const x=s=>typeof esc==='function'?esc(s):String(s??'');
  const date=s=>typeof df==='function'?df(s):(s||'—');
  const n=v=>Math.max(0,Number(v)||0);
  const currentPlayerId=()=>Number((typeof activeManagedId==='function'&&activeManagedId())||(typeof primaryManagedPlayerId==='function'&&primaryManagedPlayerId())||0);

  window.openMedicalPlayDecisionV15=function(mode,tournamentId=0,quick=false,data={}){
    const inj=data?.injury||{};
    const risk=n(inj.aggravation_risk);
    const playerId=currentPlayerId();
    const can=Boolean(data?.can_play_hurt);
    const veto=Boolean(data?.medical_veto)||!can;
    const tour=(typeof tourRows!=='undefined'?tourRows:[]).find(t=>Number(t.id)===Number(tournamentId));
    const context=tournamentId?(tour?.name||'ce tournoi'):'ce match';
    overlay.innerHTML='<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet cb-medical-decision-v15">'+
      '<div class="sheet-head"><div><div class="eyebrow">Décision médicale</div><h1>'+x(inj.injury_type||'Joueur diminué')+'</h1><div class="muted">'+x(context)+' · '+x(inj.severity||'gravité non précisée')+'</div></div><button class="close" onclick="closeOverlay()">✕</button></div>'+
      '<div class="cb-med-risk-v15"><div><span>Risque d’aggravation</span><b>'+Math.round(risk)+'%</b></div><i><em style="width:'+Math.min(100,risk)+'%"></em></i></div>'+
      '<div class="grid g3" style="margin-top:10px">'+
        '<div class="kpi"><span class="muted mini">Retour estimé</span><b>'+x(date(inj.expected_return))+'</b></div>'+
        '<div class="kpi"><span class="muted mini">Sévérité</span><b>'+x(inj.severity||'—')+'</b></div>'+
        '<div class="kpi"><span class="muted mini">Statut</span><b>'+(veto?'Veto médical':'Jouable diminué')+'</b></div>'+
      '</div>'+
      (veto
       ?'<div class="notice bad" style="margin-top:12px"><b>Le staff médical bloque le match.</b> La blessure ou le risque de rechute est trop important.</div>'
       :'<div class="notice warn" style="margin-top:12px"><b>Jouer diminué a de vraies conséquences.</b> CA effective, fitness et forme baissent pour le match, la fatigue monte et le moteur augmente réellement la probabilité d’aggravation ou d’abandon.</div>')+
      '<div class="cb-medical-actions-v15">'+
        (tournamentId?'<button class="danger-btn" onclick="medicalWithdrawV15('+Number(tournamentId)+','+playerId+')">Déclarer forfait</button>':'<button class="ghost" onclick="closeOverlay();route=\'medical\';render()">Repos / centre médical</button>')+
        (!veto?'<button class="primary" onclick="medicalPlayHurtV15(\''+x(mode)+'\','+Number(tournamentId)+','+(quick?'true':'false')+')">Jouer diminué</button>':'')+
      '</div>'+
    '</div></div>';
  };

  window.medicalPlayHurtV15=async function(mode,tournamentId,quick){
    closeOverlay();
    if(mode==='tournament')return playTournament(Number(tournamentId),'play_hurt');
    if(mode==='live-tournament')return startTournamentLiveMatch(Number(tournamentId),Boolean(quick),'play_hurt');
    return startLiveMatch('play_hurt');
  };

  window.medicalWithdrawV15=async function(tournamentId,playerId){
    if(!confirm('Déclarer forfait pour raison médicale ? La place sera rendue au tableau / aux alternates.'))return;
    try{
      await get('/api/tournament-entry',{
        method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({tournament_id:Number(tournamentId),player_id:Number(playerId)||currentPlayerId(),action:'withdraw',entry_method:'alternate',medical_reason:true})
      });
      if(typeof invalidateCareerCaches==='function')invalidateCareerCaches();
      if(typeof loadTournaments==='function')await loadTournaments();
      if(typeof loadActiveManagedContext==='function')await loadActiveManagedContext(true,currentPlayerId()).catch(()=>{});
      closeOverlay();
      alert('Forfait enregistré. Le tournoi peut maintenant promouvoir un alternate / Lucky Loser selon la phase.');
      if(typeof render==='function')render();
    }catch(e){alert(e.message)}
  };

  const injuryHistoryHtml=ctx=>{
    const history=Array.isArray(ctx?.injury_history)?ctx.injury_history:[];
    const vulns=Array.isArray(ctx?.injury_vulnerabilities)?ctx.injury_vulnerabilities:[];
    const effects=Array.isArray(ctx?.recovery_effects)?ctx.recovery_effects:[];
    const vulnRows=vulns.map(v=>'<div class="list-item"><div class="row between"><div><b>'+x(v.body_area||'Zone')+'</b><div class="muted micro">'+n(v.episodes)+' épisode(s)'+(v.chronic?' · chronique':'')+'</div></div><span class="badge '+(n(v.recurrence_risk)>=60?'bad':n(v.recurrence_risk)>=35?'warn':'good')+'">'+Math.round(n(v.recurrence_risk))+'% rechute</span></div></div>').join('');
    const histRows=history.slice(0,12).map(h=>'<tr><td>'+x(date(h.started_at))+'</td><td><b>'+x(h.injury_type||'Blessure')+'</b><div class="muted micro">'+x(h.treatment||'')+'</div></td><td>'+x(h.severity||'—')+'</td><td>'+x(date(h.expected_return))+'</td><td><span class="badge '+(String(h.status||'').toLowerCase()==='active'?'bad':'good')+'">'+x(h.status||'—')+'</span></td></tr>').join('');
    const effectRows=effects.slice(0,10).map(e=>{
      const penalties=e.attribute_penalties&&typeof e.attribute_penalties==='object'?Object.entries(e.attribute_penalties).map(([k,v])=>k+' '+v).join(' · '):'';
      const potential=(e.potential_before!=null&&e.potential_after!=null&&Number(e.potential_after)!==Number(e.potential_before))?'Potentiel '+e.potential_before+' → '+e.potential_after:'';
      return '<div class="list-item"><div><b>'+x(e.body_area||'Récupération')+' · '+n(e.days_out)+' j</b><div class="muted mini">'+x(e.note||'Effet post-blessure')+'</div><div class="muted micro">'+x([potential,penalties].filter(Boolean).join(' · ')||'Aucune séquelle permanente détectée')+'</div></div><span class="badge">'+Math.round(n(e.recurrence_risk_before))+' → '+Math.round(n(e.recurrence_risk_after))+'%</span></div>';
    }).join('');
    return '<div class="card cb-medical-history-v15" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Médical long terme V15</div><h2>Historique, zones fragiles & séquelles</h2></div><span class="badge">'+history.length+' blessure(s)</span></div>'+
      '<div class="grid g2" style="margin-top:10px"><div><h3>Zones à surveiller</h3>'+(vulnRows||'<div class="empty">Aucune vulnérabilité chronique enregistrée.</div>')+'</div><div><h3>Effets après récupération</h3>'+(effectRows||'<div class="empty">Aucune séquelle enregistrée.</div>')+'</div></div>'+
      (histRows?'<div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>Début</th><th>Blessure</th><th>Gravité</th><th>Retour prévu</th><th>Statut</th></tr></thead><tbody>'+histRows+'</tbody></table></div>':'<div class="empty">Aucun historique médical.</div>')+
      '</div>';
  };

  try{
    if(typeof medicalPage==='function'){
      const originalMedicalPageV15=medicalPage;
      medicalPage=function(){
        const base=originalMedicalPageV15();
        const ctx=typeof activeManagedContext!=='undefined'?activeManagedContext:null;
        return base+injuryHistoryHtml(ctx);
      };
    }
  }catch(e){console.warn('Medical V15 page hook',e)}

  console.info('Court Boss Medical V15 active');
})();