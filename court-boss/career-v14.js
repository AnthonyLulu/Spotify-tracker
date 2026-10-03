/* Court Boss Career V14 · Contract Negotiation */
(function(){
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  window.openContract=function(id){
    const x=(management?.contracts||[]).find(v=>Number(v.id)===Number(id));if(!x)return;
    const weekly=Math.max(1,Math.round(Number(x.weekly_salary||0)));
    overlay.innerHTML='<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Négociation V14</div><h1>'+esc(x.subject_name)+'</h1><div class="muted">Salaire, prime et durée sont réellement négociés selon le profil et la concurrence.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>'+
      '<div class="grid g2"><div class="card"><div class="list-item row between"><span>Rôle</span><b>'+esc(x.role||x.subject_type)+'</b></div><div class="list-item row between"><span>Salaire actuel</span><b>'+euro(weekly)+'/sem.</b></div><div class="list-item row between"><span>Échéance</span><b>'+df(x.end_date)+'</b></div></div>'+
      '<div class="card"><label class="field"><span>Salaire proposé / semaine</span><input id="cbContractWeeklyV14" class="input" type="number" min="0" step="10" value="'+Math.round(weekly*1.08)+'"></label>'+
      '<label class="field"><span>Prime de signature</span><input id="cbContractSigningV14" class="input" type="number" min="0" step="100" value="'+Math.round(weekly*2)+'"></label>'+
      '<label class="field"><span>Durée</span><select id="cbContractYearsV14" class="select"><option value="1">1 an</option><option value="2" selected>2 ans</option><option value="3">3 ans</option></select></label>'+
      '<button class="primary" style="margin-top:10px" onclick="negotiateContractV14('+Number(id)+')">Envoyer l’offre</button></div></div>'+
      '<div id="cbContractReplyV14" class="notice" style="margin-top:10px">Une durée longue ou une prime peuvent compenser une offre salariale plus serrée. Les offres concurrentes durcissent la négociation.</div></div></div>';
  };

  window.negotiateContractV14=async function(id){
    const weekly=Number(document.getElementById('cbContractWeeklyV14')?.value||0);
    const signing=Number(document.getElementById('cbContractSigningV14')?.value||0);
    const years=Number(document.getElementById('cbContractYearsV14')?.value||1);
    const reply=document.getElementById('cbContractReplyV14');
    try{
      const d=await managerAction('negotiate_contract',Number(id),{weekly_salary:weekly,signing_bonus:signing,years});
      if(d.status==='counter'){
        if(reply)reply.innerHTML='<b>Contre-offre</b> · '+euro(d.counter_weekly)+'/sem. · prime '+euro(d.counter_signing)+' · '+d.counter_years+' an(s).';
        const w=document.getElementById('cbContractWeeklyV14'),s=document.getElementById('cbContractSigningV14');
        if(w)w.value=String(d.counter_weekly);if(s)s.value=String(d.counter_signing);
        return;
      }
      if(reply)reply.innerHTML='<b>Accord trouvé.</b> Nouveau contrat jusqu’au '+df(d.end_date)+' · '+euro(d.weekly_salary)+'/sem.';
      await loadManagement();
      if(typeof refreshManagerState==='function')await refreshManagerState();
      render();
    }catch(e){if(reply)reply.textContent=e?.message||String(e)}
  };
  console.info('Court Boss Career V14 contract negotiation active');
})();