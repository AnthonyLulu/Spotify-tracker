(() => {
  'use strict';

  let cbRecordCategory='Tous';
  const cbBaseHistoryPage=typeof historyPage==='function'?historyPage:null;
  const cbBaseMore=typeof more==='function'?more:null;
  const cbBaseWorldPage=typeof worldPage==='function'?worldPage:null;

  const recordRarityLabel=r=>({
    mythic:'Mythique',legendary:'Légendaire',elite:'Élite',rare:'Rare'
  }[String(r||'').toLowerCase()]||'Record');

  const recordRarityClass=r=>({
    mythic:'mythic',legendary:'legendary',elite:'elite',rare:'rare'
  }[String(r||'').toLowerCase()]||'elite');

  function recordProgressMap(hub){
    return new Map(((hub&&hub.managed&&hub.managed.progress)||[]).map(x=>[String(x.code),x]));
  }

  function recordOccurrenceMap(hub){
    const map=new Map();
    for(const x of (hub&&hub.occurrences)||[]){
      const key=String(x.record_code||'');
      if(!map.has(key))map.set(key,[]);
      map.get(key).push(x);
    }
    for(const rows of map.values()){
      rows.sort((a,b)=>Number(b.value||0)-Number(a.value||0)||Number(b.season||0)-Number(a.season||0)||String(a.player_name||'').localeCompare(String(b.player_name||'')));
    }
    return map;
  }

  function recordStatus(r,p){
    const base=r.baseline_value==null?null:Number(r.baseline_value);
    const val=p&&p.value!=null?Number(p.value):null;
    if(String(r.record_type)==='dynamic'){
      return {label:p&&val>0?'Record de sauvegarde établi':'À établir dans la sauvegarde',cls:'save'};
    }
    if(p&&p.achieved){
      if(!r.baseline_holder)return {label:'Nouveau jalon historique',cls:'record'};
      if(base!=null&&val!=null&&val>base)return {label:'Record battu',cls:'record'};
      if(base!=null&&val!=null&&val===base&&['numeric','dynamic'].includes(String(r.record_type||'')))return {label:'Record égalé',cls:'tied'};
      return {label:'Réalisé',cls:'done'};
    }
    if(String(r.record_type)==='dynamic')return {label:'Record de sauvegarde',cls:'save'};
    if(String(r.record_type)==='challenge')return {label:'Jamais réalisé',cls:'challenge'};
    return {label:'À poursuivre',cls:'open'};
  }

  function recordValueText(r){
    if(r.baseline_holder==null){
      return String(r.record_type)==='challenge'?'Aucun détenteur':'À établir';
    }
    const unit=String(r.unit||'');
    const v=r.baseline_value==null?'':fmt(Number(r.baseline_value));
    return (v?v+' ':'')+unit;
  }

  function recordHistoryNames(rows){
    if(!rows||!rows.length)return '';
    const unique=[];
    const seen=new Set();
    for(const x of rows){
      const k=[x.player_name,x.season,x.label].join('|');
      if(seen.has(k))continue;
      seen.add(k);unique.push(x);
    }
    return unique.slice(0,5).map(x=>'<span class="cb-record-occ-chip">'+(x.country?(flags[x.country]||'🏳️')+' ':'')+esc(x.player_name)+(x.season?' · '+x.season:'')+'</span>').join('');
  }

  function recordCard(r,progress,occurrences,featured=false){
    const p=progress.get(String(r.code))||null;
    const status=recordStatus(r,p);
    const holder=r.baseline_holder
      ?((r.baseline_country?(flags[r.baseline_country]||'🏳️')+' ':'')+esc(r.baseline_holder))
      :'Personne';
    const progressText=p?esc(p.label||String(p.value??0)):'';
    const hasTarget=p&&p.target!=null&&Number(p.target)>0;
    const pct=hasTarget?Math.max(0,Math.min(100,Math.round(Number(p.value||0)/Number(p.target)*100))):0;
    return '<article class="cb-record-card '+recordRarityClass(r.rarity)+(featured?' featured':'')+'">'
      +'<div class="cb-record-top"><div><span class="cb-record-category">'+esc(r.category||'Record')+(r.subcategory?' · '+esc(r.subcategory):'')+'</span><h3>'+esc(r.name)+'</h3></div><span class="cb-record-rarity '+recordRarityClass(r.rarity)+'">'+recordRarityLabel(r.rarity)+'</span></div>'
      +'<p class="cb-record-desc">'+esc(r.description||'')+'</p>'
      +'<div class="cb-record-holder"><span>Référence 01/12/2025</span><b>'+holder+'</b><strong>'+esc(recordValueText(r))+(r.baseline_year?' · '+r.baseline_year:'')+'</strong></div>'
      +(p?'<div class="cb-record-progress '+status.cls+'"><div class="row between"><span>Ta carrière</span><b>'+progressText+'</b></div>'+(hasTarget?'<div class="bar"><i style="width:'+pct+'%"></i></div>':'')+'<small>'+esc(status.label)+'</small></div>':'')
      +(occurrences&&occurrences.length?'<div class="cb-record-occurrences">'+recordHistoryNames(occurrences)+'</div>':'')
      +'<div class="cb-record-actions"><button class="ghost" onclick="openCourtBossRecord(\''+esc(String(r.code))+'\')">Détails</button>'+(r.source_url?'<button class="soft-btn" onclick="openRecordSource(event,\''+esc(String(r.source_url))+'\')">'+esc(r.source_label||'Source')+'</button>':'')+'</div>'
      +'</article>';
  }

  function recordHero(hub,progress,occurrences){
    const byCode=new Map((hub.catalog||[]).map(x=>[String(x.code),x]));
    const codes=['calendar_golden_slam_men','nole_slam','career_golden_masters','sunshine_double_career_record','masters_aces_edition_reference'];
    return '<div class="cb-record-hero-grid">'+codes.map(code=>{
      const r=byCode.get(code);return r?recordCard(r,progress,occurrences.get(code)||[],true):'';
    }).join('')+'</div>';
  }

  function recordHubSection(hub){
    if(!hub||hub.error)return '<section class="card cb-record-error"><div class="eyebrow">Record Hub</div><h2>Records indisponibles</h2><div class="muted">'+esc(hub&&hub.error||'Base non chargée')+'</div></section>';
    const catalog=Array.isArray(hub.catalog)?hub.catalog:[];
    const progress=recordProgressMap(hub),occurrences=recordOccurrenceMap(hub);
    const categories=['Tous',...new Set(catalog.map(x=>String(x.category||'Autres')))];
    const filtered=cbRecordCategory==='Tous'?catalog:catalog.filter(x=>String(x.category||'Autres')===cbRecordCategory);
    const achieved=[...progress.values()].filter(x=>x.achieved).length;
    const mythic=catalog.filter(x=>String(x.rarity)==='mythic').length;
    const historical=((hub.occurrences)||[]).length;
    const managed=hub.managed||{};
    const mainCards=filtered.filter(r=>!['calendar_golden_slam_men','nole_slam','career_golden_masters','sunshine_double_career_record','masters_aces_edition_reference'].includes(String(r.code)));

    return '<section class="cb-record-hub">'
      +'<div class="cb-record-head card"><div><div class="eyebrow">Record Hub · historique + sauvegarde</div><h2>Exploits, séries et records cultes</h2><p class="muted">Records figés sur la référence historique du 1er décembre 2025, puis comparés aux exploits générés dans ta carrière.</p></div>'
      +'<div class="cb-record-kpis"><div><span>Records</span><b>'+fmt(catalog.length)+'</b></div><div><span>Mythiques</span><b>'+fmt(mythic)+'</b></div><div><span>Occurrences historiques</span><b>'+fmt(historical)+'</b></div><div><span>Réalisés par '+esc(managed.name||'ton joueur')+'</span><b>'+fmt(achieved)+'</b></div></div></div>'
      +'<div class="cb-record-tabs">'+categories.map(x=>'<button class="'+(cbRecordCategory===x?'active':'')+'" onclick="setCourtBossRecordCategory(\''+esc(x)+'\')">'+esc(x)+'</button>').join('')+'</div>'
      +(cbRecordCategory==='Tous'?recordHero(hub,progress,occurrences):'')
      +'<div class="cb-record-grid">'+mainCards.map(r=>recordCard(r,progress,occurrences.get(String(r.code))||[],false)).join('')+'</div>'
      +'<div class="notice mini cb-record-note"><b>Aces :</b> Court Boss compare maintenant ta meilleure édition de Masters au benchmark sourcé de <b>98 aces de John Isner à Miami 2019</b>. Cette marque est enregistrée comme référence documentée de cette édition, pas comme affirmation de record absolu sur toute l’histoire des Masters. Les records de sauvegarde restent calculés match par match par le moteur.</div>'
      +'</section>';
  }

  loadHistory=async function(){
    const p=new URLSearchParams({limit:'300'});
    if(historyCountry)p.set('country',historyCountry);
    if(historyContinent)p.set('continent',historyContinent);
    const pid=Number(activeManagedId?.()||primaryManagedPlayerId?.()||0);
    if(pid)p.set('player_id',String(pid));
    try{historyData=await get('/api/history-hub?'+p.toString())}
    catch(e){historyData={rows:[],countryBest:[],continentBest:[],methodology:e.message,coverage:{players:0,countries:0}}}
  };

  const cbBaseSetActiveManagedPlayer=window.setActiveManagedPlayer;
  if(typeof cbBaseSetActiveManagedPlayer==='function'){
    window.setActiveManagedPlayer=async id=>{
      await cbBaseSetActiveManagedPlayer(id);
      historyData=null;
      if(route==='history'){
        await loadHistory();
        render();
      }
    };
  }

  window.setCourtBossRecordCategory=value=>{cbRecordCategory=String(value||'Tous');render()};

  window.openRecordSource=(ev,url)=>{
    if(ev){ev.stopPropagation();ev.preventDefault()}
    if(/^https?:\/\//i.test(String(url||'')))window.open(url,'_blank','noopener,noreferrer');
  };

  window.openCourtBossRecord=code=>{
    const hub=historyData&&historyData.recordHub;
    if(!hub)return;
    const r=(hub.catalog||[]).find(x=>String(x.code)===String(code));
    if(!r)return;
    const p=(hub.managed&&hub.managed.progress||[]).find(x=>String(x.code)===String(code));
    const rows=(hub.occurrences||[]).filter(x=>String(x.record_code)===String(code));
    const status=recordStatus(r,p);
    const historical=rows.length
      ?rows.map(x=>'<div class="list-item row between"><span><b>'+(x.country?(flags[x.country]||'🏳️')+' ':'')+esc(x.player_name)+'</b><div class="muted micro">'+esc(x.label||r.name)+'</div></span><span class="badge">'+(x.season||'—')+(x.value!=null?' · '+fmt(x.value):'')+'</span></div>').join('')
      :'<div class="empty">Aucune occurrence historique détaillée enregistrée pour ce record.</div>';
    overlay.innerHTML='<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet cb-record-sheet"><div class="sheet-head"><div><div class="eyebrow">'+esc(r.category||'Record')+' · '+recordRarityLabel(r.rarity)+'</div><h1>'+esc(r.name)+'</h1><div class="muted">'+esc(r.description||'')+'</div></div><button class="close" onclick="closeOverlay()">✕</button></div>'
      +'<div class="grid g2" style="margin-top:12px"><div class="card"><div class="eyebrow">Référence historique</div><h2>'+(r.baseline_holder?esc(r.baseline_holder):'Aucun détenteur')+'</h2><div class="big">'+esc(recordValueText(r))+'</div><div class="muted mini">'+esc(r.source_label||'Court Boss')+' · référence '+df(r.as_of_date||hub.as_of_date)+'</div></div>'
      +'<div class="card"><div class="eyebrow">Ta sauvegarde</div><h2>'+esc((hub.managed&&hub.managed.name)||'Joueur géré')+'</h2><div class="big">'+esc(p&&p.label||'Non suivi')+'</div><span class="badge '+(status.cls==='record'||status.cls==='done'?'good':status.cls==='challenge'?'warn':'')+'">'+esc(status.label)+'</span></div></div>'
      +'<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Historique</div><h2>Joueurs / saisons recensés</h2></div><span class="badge">'+rows.length+'</span></div><div class="stack" style="margin-top:8px">'+historical+'</div></div>'
      +(r.source_url?'<button class="soft-btn" style="margin-top:12px" onclick="openRecordSource(event,\''+esc(String(r.source_url))+'\')">Ouvrir la source · '+esc(r.source_label||'Source')+'</button>':'')
      +'</div></div>';
  };


  if(cbBaseMore){
    more=function(){
      let html=cbBaseMore();
      html=html.replace('Histoire & nations','Records & exploits');
      html=html.replace('Légendes par pays et continent','Golden Slam, Masters, aces, séries & légendes');
      return html;
    };
  }


  if(cbBaseWorldPage){
    worldPage=function(){
      let html=cbBaseWorldPage();
      html=html.replace(
        '<strong>Histoire & nations</strong><span class="muted">Meilleurs historiques par pays et continent</span>',
        '<strong>Records & Histoire</strong><span class="muted">Record Center · exploits, légendes, pays et continents</span>'
      );
      return html;
    };
  }

  if(cbBaseHistoryPage){
    historyPage=function(){
      const html=cbBaseHistoryPage();
      const block=recordHubSection(historyData&&historyData.recordHub);
      const anchor='<div class="fm-record-grid">';
      return html.includes(anchor)?html.replace(anchor,block+anchor):block+html;
    };
  }
})();