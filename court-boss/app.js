const API='https://qrsvliliezbiedmaewml.supabase.co/functions/v1/court-boss';
const app=document.getElementById('app'),overlay=document.getElementById('overlay');
const country2={
 AFG:'AF',ALB:'AL',ALG:'DZ',AND:'AD',AGO:'AO',ANG:'AO',AHO:'CW',ANT:'CW',ARG:'AR',ARM:'AM',ARU:'AW',AUS:'AU',AUT:'AT',AZE:'AZ',
 BAH:'BS',BAR:'BB',BDI:'BI',BEL:'BE',BEN:'BJ',BER:'BM',BHR:'BH',BIH:'BA',BIZ:'BZ',BLR:'BY',BOL:'BO',BOT:'BW',BRA:'BR',BRN:'BH',BUL:'BG',
 CAL:'NC',CAM:'KH',CAN:'CA',CHI:'CL',CHL:'CL',CHN:'CN',CIV:'CI',CMR:'CM',COD:'CD',COG:'CG',CGO:'CG',COL:'CO',CRC:'CR',CRO:'HR',CUB:'CU',CUW:'CW',CYP:'CY',CZE:'CZ',
 DEN:'DK',DOM:'DO',ECU:'EC',EGY:'EG',ESA:'SV',ESP:'ES',EST:'EE',ETH:'ET',
 FIJ:'FJ',FIN:'FI',FRA:'FR',GAB:'GA',GAM:'GM',GBR:'GB',GEO:'GE',GER:'DE',GHA:'GH',GRE:'GR',GRN:'GD',GTM:'GT',GUA:'GT',GUD:'GP',GUI:'GN',GUM:'GU',GUY:'GY',
 HAI:'HT',HKG:'HK',HON:'HN',HUN:'HU',INA:'ID',IND:'IN',IRI:'IR',IRL:'IE',IRQ:'IQ',ISL:'IS',ISR:'IL',ITA:'IT',
 JAM:'JM',JOR:'JO',JPN:'JP',KAZ:'KZ',KEN:'KE',KGZ:'KG',KOR:'KR',KSA:'SA',KUW:'KW',
 LAO:'LA',LAT:'LV',LBA:'LY',LBN:'LB',LIB:'LB',LIE:'LI',LTU:'LT',LUX:'LU',
 MAD:'MG',MDG:'MG',MAR:'MA',MAS:'MY',MDA:'MD',MEX:'MX',MKD:'MK',MLI:'ML',MLT:'MT',MNE:'ME',MON:'MC',MOZ:'MZ',MRI:'MU',MYA:'MM',
 NAM:'NA',NCA:'NI',NIC:'NI',NED:'NL',NEP:'NP',NPL:'NP',NGA:'NG',NGR:'NG',NMI:'MP',NOR:'NO',NZL:'NZ',
 PAK:'PK',PAN:'PA',PAR:'PY',PRY:'PY',PER:'PE',PHI:'PH',PNG:'PG',POL:'PL',POR:'PT',PUR:'PR',QAT:'QA',
 REU:'RE',ROU:'RO',RSA:'ZA',RUS:'RU',RWA:'RW',SEN:'SN',SGP:'SG',SIN:'SG',SLO:'SI',SRB:'RS',SRI:'LK',SUD:'SD',SUI:'CH',SUR:'SR',SVK:'SK',SWE:'SE',SWZ:'SZ',SYR:'SY',
 TGO:'TG',TOG:'TG',THA:'TH',TJK:'TJ',TKM:'TM',TPE:'TW',TTO:'TT',TUN:'TN',TUR:'TR',
 UAE:'AE',UGA:'UG',UKR:'UA',URU:'UY',USA:'US',UZB:'UZ',TWN:'TW',BRU:'BN',OMA:'OM',PLE:'PS',MGL:'MN',VAN:'VU',VEN:'VE',VIE:'VN',YEM:'YE',ZAM:'ZM',ZIM:'ZW',
 ASA:'AS',BUR:'BF',CAF:'CF',CPV:'CV',HAW:'US',ISV:'VI',LCA:'LC',LES:'LS',NIG:'NE',SCG:'RS',SEY:'SC',SLE:'SL',SMR:'SM',TRI:'TT',VIN:'VC',URS:'RU',YUG:'RS',TCH:'CZ',FRG:'DE',GDR:'DE',KOS:'XK',SAM:'WS',SOL:'SB',FSM:'FM',MHL:'MH',NRU:'NR',TGA:'TO',TUV:'TV',CHA:'TD',COM:'KM',DJI:'DJ',EQG:'GQ',ERI:'ER',GNB:'GW',LBR:'LR',MAW:'MW',SOM:'SO',SSD:'SS',TAN:'TZ'
};
const emojiFlag=code=>{
 const raw=String(code||'').toUpperCase();
 if(raw==='ITF')return '🌐';
 if(raw==='UNK'||!raw)return '🌐';
 const iso=country2[raw]||(raw.length===2?raw:'');
 if(!/^[A-Z]{2}$/.test(iso))return '🏳️';
 return [...iso].map(c=>String.fromCodePoint(127397+c.charCodeAt(0))).join('');
};
const flags=new Proxy({},{
 get(_target,key){return emojiFlag(String(key||''))}
});
function countryTheme(code){
 const c=String(code||'').toUpperCase();
 const fixed={
  SRB:['#c6363c','#244aa5'],FRA:['#244aa5','#e63946'],ESP:['#aa151b','#f1bf00'],
  ITA:['#16864b','#d33d3d'],USA:['#1d4f91','#b22234'],GBR:['#21468b','#cf142b'],
  GER:['#272727','#d6a700'],SUI:['#d52b1e','#f7f7f7'],AUT:['#d81e35','#f4f4f4'],
  AUS:['#0b6b46','#f1c40f'],CAN:['#d52b1e','#f3f3f3'],ARG:['#64b5e8','#f3f3f3'],
  BRA:['#169b62','#ffdf00'],CZE:['#3155a6','#d51d36'],POL:['#dc143c','#f6f6f6'],
  NED:['#e86a17','#21468b'],BEL:['#202020','#f0c808'],GRE:['#2d5da8','#f5f5f5'],
  JPN:['#f4f4f4','#bc002d'],CHN:['#de2910','#ffde00'],KOR:['#f3f3f3','#2457a5'],
  SWE:['#1769aa','#f5cc18'],NOR:['#ba0c2f','#173b6c'],DEN:['#c60c30','#f5f5f5'],
  RUS:['#f5f5f5','#1c57a7'],UKR:['#1e75bb','#ffd700'],CRO:['#d91e36','#21468b']
 };
 if(fixed[c])return {a:fixed[c][0],b:fixed[c][1]};
 let h=0;for(const ch of c)h=(h*31+ch.charCodeAt(0))%360;
 return {a:`hsl(${h} 55% 34%)`,b:`hsl(${(h+42)%360} 58% 24%)`};
}
const saveKey=(()=>{let k=localStorage.getItem('courtBossSaveKey');if(!k){k=crypto.randomUUID();localStorage.setItem('courtBossSaveKey',k)}return k})();
let accessKey=(localStorage.getItem('courtBossAccessKey')||'').trim();
function courtBossAccessKey(){
  if(!accessKey)accessKey=(prompt('Code d’accès Court Boss')||'').trim();
  return accessKey;
}
const fmt=n=>new Intl.NumberFormat('fr-FR').format(Math.round(Number(n)||0));
const euro=n=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(Number(n)||0);
const money=(n,currency='USD')=>{
 const value=Number(n);if(!Number.isFinite(value))return '—';
 const cur=String(currency||'USD').toUpperCase();
 try{return new Intl.NumberFormat('fr-FR',{style:'currency',currency:cur,maximumFractionDigits:2}).format(value)}catch{return fmt(value)+' '+cur}
};
const tournamentPrizeLabel=t=>{
 if(String(t?.prize_format||'')==='none')return 'Aucun';
 const value=Number(t?.prize_money||0);
 if(!Number.isFinite(value)||value<=0)return '—';
 return money(value,t?.prize_currency||'USD');
};
const df=s=>s?new Date(s+'T12:00:00').toLocaleDateString('fr-FR',{day:'2-digit',month:'short',year:'numeric'}):'—';
const RANKING_SNAPSHOT='2025-12-01';
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const tournamentRoundLabels={W:'Vainqueur',F:'Finaliste',SF:'Demi-finale',QF:'Quart de finale',R16:'Huitième de finale',Q3:'Troisième tour qualifs',Q2:'Deuxième tour qualifs',Q1:'Premier tour qualifs',Q:'Qualification acquise',DQ1:'Premier tour qualifs double',DQF:'Finale qualifs double'};
function tournamentRoundLabel(code,fr={},t={}){
 const k=String(code||'');
 if(tournamentRoundLabels[k])return tournamentRoundLabels[k];
 if(/^R\\d+$/.test(k)){
  const rounds=Array.isArray(fr?.rounds)?fr.rounds:[];
  const idx=rounds.indexOf(k);
  if(idx>=0){
   const names=['Premier tour','Deuxième tour','Troisième tour','Quatrième tour'];
   return (names[idx]||('Tour '+(idx+1)))+' · '+k;
  }
  const draw=Number(fr?.main_draw_size||t?.singles_draw_size||t?.draw_size||0);
  if(draw&&k==='R'+draw)return 'Premier tour · '+k;
  return k;
 }
 return k;
}
function tournamentEconomicsHtml(e,t,fr={}){
 e=e||{};const cur=e.currency||t.prize_currency||'USD';
 const known=e.total_is_estimate===false;
 const order=['W','F','SF','QF','R16','R24','R28','R32','R48','R56','R64','R96','R128','Q3','Q2','Q1'];
 const block=(title,obj,estimated,points)=>{
  obj=obj&&typeof obj==='object'?obj:{};
  const keys=[...new Set([...Object.keys(obj),...Object.keys(points||{}).filter(k=>k!=='Q')])].sort((a,b)=>(order.indexOf(a)<0?999:order.indexOf(a))-(order.indexOf(b)<0?999:order.indexOf(b)));
  const empty=Object.keys(obj).length===0;
  const badge=estimated===false?'Barème officiel':empty?'Gains non renseignés':'Barème estimé';
  return "<div class='card'><div class='row between'><h2>"+esc(title)+"</h2><span class='badge "+(estimated===false?'good':'warn')+"'>"+badge+"</span></div>"+(keys.length?"<div class='table-wrap'><table class='table'><thead><tr><th>Tour atteint</th><th>Gain</th>"+(points?'<th>Points</th>':'')+"</tr></thead><tbody>"+keys.map(k=>"<tr><td><b>"+esc(tournamentRoundLabel(k,fr,t))+"</b></td><td><b>"+(Object.hasOwn(obj,k)?money(obj[k],cur):estimated===false?money(0,cur):'—')+"</b></td>"+(points?'<td>'+(Object.hasOwn(points,k)?fmt(points[k]):'—')+'</td>':'')+"</tr>").join('')+"</tbody></table></div>":"<div class='empty'>"+(estimated===false?'Aucune dotation sur cette phase.':'Barème non renseigné pour cette phase.')+"</div>")+"</div>";
 };
 let html="<div class='card'><div class='row between'><div><div class='eyebrow'>Économie du tournoi</div><h2>Dotation "+esc(String(t.start_date||'').slice(0,4))+"</h2></div><span class='badge "+(known?'good':'warn')+"'>"+(known?'Total officiel':'Total estimé')+"</span></div>";
 html+="<div class='kpi-strip' style='margin-top:10px'><div class='kpi'><span class='muted mini'>Dotation annoncée</span><b>"+money(e.total??t.prize_money??0,cur)+"</b></div><div class='kpi'><span class='muted mini'>Devise</span><b>"+esc(cur)+"</b></div><div class='kpi'><span class='muted mini'>Simple</span><b>"+esc(t.singles_draw_size||t.draw_size||'—')+"</b></div><div class='kpi'><span class='muted mini'>Double</span><b>"+esc(t.doubles?t.doubles_draw_size||'—':'—')+"</b></div></div>";
 if(e.source_url&&/^https?:\/\//i.test(e.source_url))html+="<div style='margin-top:10px'><a class='soft-btn' href='"+esc(e.source_url)+"' target='_blank' rel='noopener noreferrer'>Source dotation ↗</a></div>";
 if(e.source_label)html+="<div class='muted mini' style='margin-top:8px'>"+esc(e.source_label)+"</div>";
 if(e.note)html+="<div class='notice mini' style='margin-top:8px'>"+esc(e.note)+"</div>";
 html+="<p class='muted mini' style='margin-top:10px'>Les montants du double sont indiqués par équipe. Le statut officiel ou estimé est précisé pour chaque barème.</p></div>";
 if(e.format==='round_robin_components'){
  const labels={PARTICIPATION:'Participation',RR_WIN:'Par victoire en poule',SF_WIN:'Victoire en demi-finale',F_WIN:'Victoire en finale'};
  return html+"<div class='grid g2' style='margin-top:12px'>"+[['singles','Simple · par joueur'],['doubles_team','Double · par équipe']].filter(([k])=>k==='singles'||t.doubles).map(([k,title])=>"<div class='card'><h2>"+title+"</h2>"+Object.entries(e.special?.[k]||{}).map(([code,value])=>"<div class='list-item row between'><span>"+esc(labels[code]||code)+"</span><b>"+money(value,cur)+"</b></div>").join('')+"<p class='muted mini'>Ces primes se cumulent selon les matchs joués et gagnés.</p></div>").join('')+'</div>';
 }
 if(e.format==='team_components'){
  const special=e.special||{};
  const stageLabels={GROUP:'Phase de groupes',QF:'Quart de finale',SF:'Demi-finale',F:'Finale'};
  const rankLabels={'1_10':'#1–10','11_20':'#11–20','21_30':'#21–30','31_50':'#31–50','51_100':'#51–100','101_250':'#101–250','251_plus':'#251+'};
  const rows=(obj,labels={})=>Object.entries(obj||{}).map(([code,value])=>"<div class='list-item row between'><span>"+esc(labels[code]||code)+"</span><b>"+money(value,cur)+"</b></div>").join('');
  const participation=[
    ['participation_no1','Joueur n°1 de la sélection'],
    ['participation_no2','Joueur n°2 de la sélection'],
    ['participation_no3','Joueur n°3 de la sélection']
  ].map(([key,title])=>"<div class='card'><h2>"+title+"</h2>"+rows(special[key],rankLabels)+"</div>").join('');
  const performance="<div class='card'><h2>Victoire en simple · joueur n°1</h2>"+rows(special.singles_match_win_no1,stageLabels)+"</div>"
    +"<div class='card'><h2>Victoire en double mixte</h2>"+rows(special.mixed_doubles_match_win,stageLabels)+"</div>"
    +"<div class='card'><h2>Bonus victoire équipe · par joueur</h2>"+rows(special.team_win_per_player,stageLabels)+"</div>";
  return html+"<div class='notice mini' style='margin-top:10px'><b>United Cup :</b> la rémunération est composée d'une prime de participation liée au classement, de primes par victoire individuelle et d'un bonus par victoire de l'équipe.</div><div class='grid g3' style='margin-top:12px'>"+participation+"</div><div class='grid g3' style='margin-top:12px'>"+performance+"</div>";
 }
 if(e.format==='appearance_plus_team_bonus'){
  const special=e.special||{};
  const appearance=String(special.APPEARANCE_FEE||'').includes('not_public')?'Montant exact non public':esc(special.APPEARANCE_FEE||'—');
  return html+"<div class='grid g2' style='margin-top:12px'>"
    +"<div class='card'><h2>Bonus équipe gagnante</h2><div class='list-item row between'><span>Par joueur</span><b>"+money(special.WINNING_TEAM_BONUS_PER_PLAYER||0,cur)+"</b></div><div class='list-item row between'><span>Taille de l'équipe</span><b>"+fmt(special.WINNING_TEAM_SIZE||0)+" joueurs</b></div><div class='list-item row between'><span>Total connu</span><b>"+money(special.KNOWN_WINNING_TEAM_BONUS_TOTAL||e.total||0,cur)+"</b></div></div>"
    +"<div class='card'><h2>Appearance fee</h2><div class='list-item row between'><span>Montant</span><b>"+appearance+"</b></div><p class='muted mini'>La Laver Cup verse également des appearance fees liés au statut/classement. Court Boss ne fabrique pas un faux montant lorsque le détail public n'existe pas.</p></div>"
    +"</div>";
 }
 html+="<div class='grid g2' style='margin-top:12px'>"+block('Simple · par joueur',e.singles,e.singles_is_estimate,fr.points_by_result)+block('Qualifications · par joueur',e.qualifying,e.qualifying_is_estimate,fr.qualifying_points)+(t.doubles?block('Double · par équipe',e.doubles,e.doubles_is_estimate,null):'')+"</div>";
 if(Number(fr.qualifying_points?.Q)>0)html+="<div class='notice mini' style='margin-top:10px'>Qualification acquise : +"+fmt(fr.qualifying_points.Q)+" points en plus du résultat dans le tableau principal.</div>";
 return html;
}
function qualifyingStructureClient(fr,t){
 const qDraw=Math.max(0,Number(t?.qualifying_draw_size||fr?.qualifying_draw_size||0));
 const qSlots=Math.max(0,Number(fr?.qualifier_count||0));
 if(!qDraw||!qSlots)return null;
 let wildcards=0,seeds=Math.min(qDraw,Math.max(qSlots*2,8));
 const circuit=String(t?.circuit||''),cat=String(t?.category||'');
 if(circuit==='ATP'&&cat==='ATP 250'){
  wildcards=qDraw===16?2:Math.max(2,Math.round(qDraw*.125));
  seeds=qDraw===16?8:Math.min(qDraw,Math.max(qSlots*2,8));
 }else if(circuit==='ATP'&&(cat==='ATP 500'||cat==='Masters 1000')){
  wildcards=qDraw===16?3:qDraw===24?4:qDraw===28?4:qDraw===48?5:Math.max(2,Math.round(qDraw*.11));
  seeds=qDraw===16?8:qDraw===24?12:qDraw===28?14:qDraw===48?24:Math.min(qDraw,Math.max(qSlots*2,8));
 }else if(circuit==='Challenger'){
  wildcards=qDraw===24?4:Math.max(2,Math.round(qDraw*.167));
  seeds=qDraw===24?12:Math.min(qDraw,Math.max(qSlots*2,8));
 }else if(circuit==='ITF'&&['M15','M25'].includes(cat)){
  wildcards=qDraw===32?(cat==='M15'?6:5):qDraw===48?7:qDraw===64?8:Math.max(4,Math.round(qDraw*.14));
  seeds=Math.min(16,qDraw);
 }else if(cat==='Grand Chelem'){
  wildcards=0;seeds=Math.min(32,qDraw);
 }else{
  wildcards=Math.max(0,Math.round(qDraw*.125));
 }
 const sectionPlayers=Math.ceil(qDraw/qSlots);
 const sectionBracket=2**Math.ceil(Math.log2(Math.max(2,sectionPlayers)));
 return {
  draw_size:qDraw,qualifier_slots:qSlots,wildcards,
  direct_acceptances:Math.max(0,qDraw-wildcards),seed_count:seeds,
  section_players:sectionPlayers,section_bracket:sectionBracket,
  bracket_total:sectionBracket*qSlots,
  bye_count:Math.max(0,sectionBracket*qSlots-qDraw)
 };
}
function tournamentFormatHtml(fr,t,qs=null){
 if(!Array.isArray(fr.rounds)||fr.format_type!=='knockout')return '';
 const draw=Number(t.singles_draw_size||t.draw_size||fr.main_draw_size||0),bracket=Number(fr.bracket_size||draw),byes=Math.max(0,bracket-draw);
 const qDraw=Number(t.qualifying_draw_size||fr.qualifying_draw_size||0),qSlots=Number(fr.qualifier_count||0),qRounds=qDraw&&qSlots?Math.ceil(Math.log2(qDraw/qSlots)):0;
 const wcMin=Math.max(0,Number(fr.wildcard_count||0)),wcMax=Math.max(wcMin,Number(fr.wildcard_count_max??wcMin));
 const seMax=Math.max(0,Number(fr.special_exempt_slots||0)),le=Math.max(0,Number(t.late_entry_slots||0));
 const pathway=Math.max(0,Number(fr.junior_reserved_slots||0))+Math.max(0,Number(fr.junior_accelerator_slots||0))+Math.max(0,Number(fr.college_accelerator_slots||0));
 const directMin=Math.max(0,draw-qSlots-wcMax-seMax-le-pathway);
 const directMax=Math.max(directMin,draw-qSlots-wcMin-le-pathway);
 const directText=directMin===directMax?String(directMin):directMin+'–'+directMax;
 const wcText=wcMin===wcMax?String(wcMin):wcMin+'–'+wcMax;
 const comp=[
  ['Directs',directText],
  ['Qualifiés',qSlots],
  ['WC',wcText],
  seMax?['SE','0–'+seMax]:null,
  le?['Late Entry',le]:null,
  pathway?['Accelerator / réservés',pathway]:null
 ].filter(Boolean);
 const qWc=qs?.wildcards!=null?Number(qs.wildcards):(t.circuit==='Challenger'?4:t.circuit==='ATP'&&t.category==='ATP 250'&&qDraw===16?2:qDraw===16?3:qDraw===24?4:qDraw===28?4:qDraw===48?5:null);
 const qDirect=qs?.direct_acceptances!=null?Number(qs.direct_acceptances):(qWc!=null?Math.max(0,qDraw-qWc):null);
 const qSeeds=qs?.seed_count!=null?Number(qs.seed_count):null;
 const qByes=qs?.bye_count!=null?Number(qs.bye_count):0;
 const qSections=qs?.qualifier_slots!=null?Number(qs.qualifier_slots):qSlots;
 const qSectionPlayers=qs?.section_players!=null?Number(qs.section_players):null;
 let doubleComp='';
 const dd=Number(t.doubles_draw_size||fr.doubles_draw_size||0);
 if(dd){
  if(t.circuit==='Challenger'&&dd===16)doubleComp='Double : 16 équipes · 10 advance entry + 4 on-site + 2 WC.';
  else if(t.category==='Masters 1000'){
   const dwc=dd===32?3:dd===28?(draw===48?3:3):dd===24?2:null;
   if(dwc!=null)doubleComp='Double : '+dd+' équipes · '+(dd-dwc)+' admissions + '+dwc+' WC.';
  }else if(t.circuit==='ATP'&&String(t.category||'')==='ATP 500'){
   const dwc=2,dq=1,direct=Math.max(0,dd-dwc-dq);
   doubleComp='Double : '+dd+' équipes · '+direct+' admissions directes + '+dq+' qualifiée + '+dwc+' WC. Qualifs : 4 équipes (3 directes + 1 WC), 1 place ; 45 pts au qualifié, 25 au finaliste des qualifs.';
  }else if(t.circuit==='ATP'&&String(t.category||'')==='ATP 250'){
   const dwc=2;
   doubleComp='Double : '+dd+' équipes · '+Math.max(0,dd-dwc)+' admissions directes + '+dwc+' WC.';
  }
 }
 return `<div class="card" style="margin-top:12px">
   <div class="row between"><div><div class="eyebrow">Format officiel / moteur</div><h2>${draw} joueurs · ${fr.rounds.length} tours</h2></div><span class="badge">${Number(fr.seed_count||0)} têtes de série</span></div>
   <div class="kpi-strip" style="margin-top:10px">${comp.map(([label,value])=>`<div class="kpi"><span class="muted mini">${esc(label)}</span><b>${esc(value)}</b></div>`).join('')}</div>
   <p class="muted mini" style="margin-top:10px">${byes?byes+' exemptions au premier tour · '+Math.max(0,draw-bracket/2)+' matchs au premier tour.':'Tous les joueurs disputent le premier tour.'}</p>
   <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px">${fr.rounds.map(r=>`<span class="badge">${esc(tournamentRoundLabels[r]||r)}</span>`).join('<span aria-hidden="true">→</span>')}</div>
   ${qRounds?`<div class="notice mini" style="margin-top:10px"><b>Qualifications :</b> ${qDraw} joueurs · ${qRounds} tours · ${qSlots} places dans le tableau principal.${qDirect!=null?' Composition : '+qDirect+' directs + '+qWc+' WC.':''}${qSeeds!=null?' '+qSeeds+' têtes de série.':''}${qSections?' '+qSections+' sections'+(qSectionPlayers?' de '+qSectionPlayers+' joueurs':'')+'.':''}${qByes?' '+qByes+' bye'+(qByes>1?'s':'')+' répartis dans les sections.':''}</div>`:''}
   ${fr.conditional_wildcard_rule==='ATP500_A_PLUS'?`<div class="notice mini" style="margin-top:8px"><b>WC A+ ATP 500 :</b> la WC supplémentaire n’est utilisée que pour un profil Premier Player admissible ; sinon la place revient à l’entry list.</div>`:''}
   ${le?`<div class="notice mini" style="margin-top:8px"><b>Late Entry :</b> ${le} place réservée jusqu’au ${t.late_entry_deadline?df(t.late_entry_deadline):'deadline réglementaire'} ; si elle n’est pas utilisée, elle revient à l’entry list.</div>`:''}
   ${doubleComp?`<p class="muted mini" style="margin-top:8px">${esc(doubleComp)}</p>`:''}
   ${fr.source_label?`<div class="muted micro" style="margin-top:8px">Référence : ${esc(fr.source_label)}</div>`:''}
  </div>`;
}
function tournamentEntryRowsHtml(rows,isJunior=false){
 const labels={direct:'Admission directe',protected:'Classement protégé',wildcard:'WC',wildcard_a_plus:'WC A+',qualifying:'Qualifications',protected_qualifying:'Qualifs · classement protégé',qualifying_wildcard:'WC qualifs',qualifier:'Qualifié',qualifier_slot:'Qualifié à déterminer',lucky_loser:'Lucky Loser',alternate:'Alternate',special_exempt:'SE',late_entry:'Late Entry',performance_bye:'Performance Bye',junior_accelerator:'Next Gen Accelerator',junior_accelerator_qualifier:'Next Gen Accelerator · Q',college_accelerator:'College Accelerator',junior_reserved:'Place junior réservée',special_exempt_slot:'SE réservé',late_entry_slot:'Late Entry réservé',junior_reserved_slot:'Place junior réservée',junior_accelerator_slot:'Next Gen Accelerator réservé',college_accelerator_slot:'College Accelerator réservé',direct_fallback_slot:'Entry list / alternate'};
 return rows.map(p=>`<tr ${p.id?`class="click" onclick="openPlayer(${Number(p.id)})"`:''}><td>${p.ranking?'#'+fmt(p.ranking):'—'}</td><td>${flags[p.country]||'🎾'} <b>${esc(p.name)}</b><div class="muted micro">${esc(labels[p.entry_method]||'')}${p.seed?' · TDS '+p.seed:''}</div></td><td>${p.points==null?'—':fmt(p.points)}</td><td>${isJunior?esc(p.result||'Engagé'):(p.form??'—')}</td></tr>`).join('');
}

const get=async(path,opts={},retried=false)=>{const key=courtBossAccessKey();const r=await fetch(API+path,{cache:'no-store',...opts,headers:{'X-Save-Key':saveKey,'X-Court-Boss-Key':key,...(opts.headers||{})}});const body=await r.json().catch(()=>({error:'Réponse serveur illisible'}));if(r.status===401&&!retried){localStorage.removeItem('courtBossAccessKey');accessKey='';return get(path,opts,true)}if(r.status===401)throw new Error('Code d’accès Court Boss incorrect.');if(!r.ok)throw new Error(body.error||'Erreur serveur '+r.status);if(key)localStorage.setItem('courtBossAccessKey',key);return body;};
let boot=null,route='home',rankKind='singles',rankOffset=0,rankRows=[],rankCount=0,rankMeta={},rankQuery='',rankCountry='',nextGenAge=21,countryRows=[],historyData=null,historyCountry='',historyContinent='',tourOffset=0,tourRows=[],tourTbc=[],tourCount=0,tourFilters={circuit:'Tous',category:'Toutes',surface:'Toutes',source:'Tous',month:'',q:''},tourShowPast=false,management=null,worldStats=null,rankingLedger=null,seasonSummary=null,scheduleAdvice=null,simulating=false;
let competitionRows=[],competitionCount=0,competitionOffset=0,competitionLoading=false,competitionFilters={q:'',circuit:'Tous',category:'Toutes',surface:'Toutes',country:'',source:'Tous',prestige:'Tous',history:'Tous',holder:'Tous'};
let doublesHubRows=[],juniorDoublesHubRows=[],doublesRaceRows=[],doublesHubLoading=false;
let tmCalFilters={week:'Toutes',country:'Tous',status:'Tous',eligibility:'Tous',environment:'Tous',entry:'Tous',holder:'Tous'};
let ncaaView='singles',ncaaDoublesRows=[],ncaaDoublesMeta={},ncaaUniversities=[],ncaaUniversitiesMeta={},ncaaUniversityDetail=null,ncaaUniversityQuery='',ncaaUniversityConference='',ncaaUniversityFilter='all',ncaaUniversitySort='ita',ncaaUniversityLoading=false;
let liveAutoTimer=null,liveAutoBusy=false,liveAutoSpeed=1;
// Matchs live = état temporaire de la session courante. Ils permettent de switcher
// entre plusieurs joueurs sans devenir une sauvegarde implicite après un ragequit.
let liveMatchSessionsByPlayer=new Map(),liveMatchOpponentsByPlayer=new Map();
let dbRows=[],dbCount=0,dbOffset=0,dbQuery='',dbCountry='',dbCircuit='Tous réels',dbLoaded=false,dbLoading=false;
let staffWorldData=null,staffWorldLoading=false,staffWorldOffset=0,staffWorldFilters={q:'',role:'',country:'',former:'Tous',status:'Tous'};
let trainingPreview=null,trainingPreviewLoading=false;
let saveSlots=[],saveSlotsLoading=false,saveSlotBusy=false,saveSlotQueue=Promise.resolve(),saveSlotQueueDepth=0;
let careerHub=null,careerHubLoading=false,activeManagedContext=null,activeManagedContextLoading=false;
function baseLocalState(){
 return {
  date:'2025-12-01',week:1,
  training:['Service','Retour','Coup droit','Récupération','Déplacements','Match play','Repos'],
  entries:[],entryMeta:{},doublesEntries:[],doublesEntryMeta:{},shortlist:[],career:null,feed:[],
  scoutingBoost:0,partnerId:null,davisRoles:{},fantasy:[],
  tactics:{aggression:58,risk:52,net:28,returnPos:'Neutre'}
 };
}
function cleanCareerLocalState(payload={}){
 const src=payload&&typeof payload==='object'?payload:{};
 const next={...baseLocalState(),...src};
 next.entries=Array.isArray(src.entries)?[...src.entries]:[];
 next.entryMeta=src.entryMeta&&typeof src.entryMeta==='object'?{...src.entryMeta}:{};
 next.doublesEntries=Array.isArray(src.doublesEntries)?[...src.doublesEntries]:[];
 next.doublesEntryMeta=src.doublesEntryMeta&&typeof src.doublesEntryMeta==='object'?{...src.doublesEntryMeta}:{};
 next.shortlist=Array.isArray(src.shortlist)?[...src.shortlist]:[];
 next.feed=Array.isArray(src.feed)?[...src.feed]:[];
 next.training=Array.isArray(src.training)&&src.training.length?[...src.training]:[...baseLocalState().training];
 next.davisRoles=src.davisRoles&&typeof src.davisRoles==='object'?{...src.davisRoles}:{};
 next.fantasy=Array.isArray(src.fantasy)?[...src.fantasy]:[];
 next.tactics=src.tactics&&typeof src.tactics==='object'?{...baseLocalState().tactics,...src.tactics}:{...baseLocalState().tactics};
 delete next.liveSessionId;
 delete next.liveMatch;
 delete next.liveOpponent;
 delete next.liveAuto;
 return next;
}
let local=baseLocalState();
try{local=cleanCareerLocalState(JSON.parse(localStorage.getItem('cbLocal')||'{}'))}catch{local=baseLocalState()}
function persist(){
 // Ne jamais rendre un score live durable par accident. Un refresh/fermeture sans
 // sauvegarde ramène donc la carrière au checkpoint d'avant-match.
 const durableLocal={...local};
 delete durableLocal.liveSessionId;
 delete durableLocal.liveMatch;
 delete durableLocal.liveOpponent;
 delete durableLocal.liveAuto;
 localStorage.setItem('cbLocal',JSON.stringify(durableLocal));
 const key=courtBossAccessKey(),payload=snapshotLocalForSave();
 enqueueSaveSlotWrite(async()=>{
  const r=await fetch(API+'/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Save-Key':saveKey,'X-Court-Boss-Key':key},body:JSON.stringify(payload)});
  if(!r.ok)throw new Error('Legacy save sync '+r.status);
 },false).catch(e=>console.warn('Legacy save sync',e));
}
async function loadSaveSlots(){
 if(saveSlotsLoading)return;
 saveSlotsLoading=true;
 try{const d=await get('/api/save-slots');saveSlots=d.slots||[]}
 catch(e){console.warn('Save slots',e)}
 finally{saveSlotsLoading=false}
}
async function loadCareerHub(force=false){
 if(careerHubLoading)return careerHub;
 if(careerHub&&!force)return careerHub;
 careerHubLoading=true;
 try{
  const playerId=activeManagedId()||primaryManagedPlayerId()||0;
  careerHub=await get('/api/career-hub'+(playerId?'?player_id='+playerId:''));
  return careerHub
 }
 catch(e){careerHub={error:e.message};throw e}
 finally{careerHubLoading=false}
}
function invalidateCareerCaches(){
 rankRows=[];rankCount=0;rankOffset=0;
 tourRows=[];tourTbc=[];tourCount=0;tourOffset=0;
 management=null;rankingLedger=null;seasonSummary=null;scheduleAdvice=null;trainingPreview=null;careerHub=null;
 historyData=null;competitionRows=[];competitionCount=0;competitionOffset=0;
 doublesHubRows=[];juniorDoublesHubRows=[];doublesRaceRows=[];doublesHubLoading=false;
 ncaaDoublesRows=[];ncaaDoublesMeta={};ncaaUniversities=[];ncaaUniversitiesMeta={};ncaaUniversityDetail=null;ncaaUniversityLoading=false;
 dbRows=[];dbCount=0;dbOffset=0;dbLoaded=false;dbLoading=false;
 staffWorldData=null;staffWorldOffset=0;worldStats=null;
}
function snapshotLocalForSave(){
 try{return cleanCareerLocalState(JSON.parse(JSON.stringify(local)))}catch{return cleanCareerLocalState(local)}
}
const LIVE_ROLLBACK_KEY='cbLiveRollbackCheckpointV1';
function pendingLiveRollback(){
 try{return JSON.parse(localStorage.getItem(LIVE_ROLLBACK_KEY)||'null')}catch{return null}
}
function clearPendingLiveRollback(){localStorage.removeItem(LIVE_ROLLBACK_KEY)}
window.hasPendingLiveRollback=()=>!!pendingLiveRollback();
async function ensureLivePreMatchCheckpoint(){
 const existing=pendingLiveRollback();
 if(existing)return existing;
 const checkpoint=await saveCareerSlot(0,'autosave',true,{preMatchCheckpoint:true});
 if(!checkpoint||checkpoint.ok===false)throw new Error('Checkpoint avant-match impossible');
 const marker={
  slot_no:0,
  career_date:checkpoint.slot?.career_date||local.date||null,
  week:checkpoint.slot?.week??local.week??null,
  created_at:new Date().toISOString()
 };
 localStorage.setItem(LIVE_ROLLBACK_KEY,JSON.stringify(marker));
 return marker;
}
async function rollbackUnsavedLiveBatchOnStartup(){
 const marker=pendingLiveRollback();
 if(!marker)return false;
 try{
  const d=await get('/api/load-slot',{
   method:'POST',headers:{'Content-Type':'application/json'},
   body:JSON.stringify({slot_no:Number(marker.slot_no??0)})
  });
  local=cleanCareerLocalState(d.local_payload||{});
  liveMatchSessionsByPlayer.clear();
  liveMatchOpponentsByPlayer.clear();
  clearLiveMatchView();
  const restoredLive=(d.live_match_sessions||[]).filter(x=>['active','finished'].includes(String(x?.status||''))&&Number(x?.managed_player_id||0)>0&&Number(x?.id||0)>0);
  for(const x of restoredLive)liveMatchSessionsByPlayer.set(Number(x.managed_player_id),Number(x.id));
  if(marker.saved_live&&restoredLive.length){
   localStorage.setItem(LIVE_ROLLBACK_KEY,JSON.stringify({...marker,restored_at:new Date().toISOString()}));
  }else{
   clearPendingLiveRollback();
  }
  localStorage.setItem('cbLocal',JSON.stringify(snapshotLocalForSave()));
  return true;
 }catch(e){
  console.warn('Rollback avant-match impossible',e);
  throw e;
 }
}
function enqueueSaveSlotWrite(task,markBusy=true){
 if(markBusy){
  saveSlotQueueDepth++;
  saveSlotBusy=true;
 }
 const run=saveSlotQueue.catch(()=>{}).then(async()=>{
  try{return await task()}
  finally{
   if(markBusy){
    saveSlotQueueDepth=Math.max(0,saveSlotQueueDepth-1);
    saveSlotBusy=saveSlotQueueDepth>0;
   }
  }
 });
 saveSlotQueue=run.catch(()=>{});
 return run;
}
async function saveCareerSlot(slotNo=1,slotType='manual',silent=false,options={}){
 const criticalAutosave=slotType==='autosave'&&silent;
 const preMatchCheckpoint=options?.preMatchCheckpoint===true;
 const hasLive=Boolean(local.liveSessionId||window.hasManagedLiveMatches?.());
 if(simulating&&!criticalAutosave){if(!silent)alert('La semaine est en cours de simulation. L’autosave sera écrit dès validation.');return {ok:false,reason:'simulation_in_progress'};}
 if(saveSlotBusy&&!criticalAutosave)return {ok:false,reason:'save_busy'};
 if(hasLive&&slotType==='autosave'&&!preMatchCheckpoint){if(!silent)alert('Un match est en cours. Utilise une sauvegarde manuelle ou la sauvegarde rapide pour figer exactement le score.');return {ok:false,reason:'live_match_autosave'};}
 const current=saveSlots.find(x=>Number(x.slot_no)===Number(slotNo));
 const defaultName=slotType==='autosave'?'Autosave':slotType==='quick'?'Sauvegarde rapide':current?.slot_name||('Carrière '+slotNo);
 const slotName=silent?defaultName:(prompt('Nom de la sauvegarde',defaultName)||defaultName);
 const localPayload=snapshotLocalForSave();
 return enqueueSaveSlotWrite(async()=>{
  try{
   const d=await get('/api/save-slot',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({slot_no:Number(slotNo),slot_type:slotType,slot_name:slotName,local_payload:localPayload,pre_match_checkpoint:preMatchCheckpoint})});
   local.lastSaveState={status:'ok',slot_no:Number(slotNo),slot_type:slotType,career_date:d.slot?.career_date||localPayload.date||local.date,week:d.slot?.week||localPayload.week||local.week,updated_at:d.slot?.updated_at||new Date().toISOString()};
   localStorage.setItem('cbLocal',JSON.stringify(snapshotLocalForSave()));
   if(!preMatchCheckpoint){
    if(hasLive){
     localStorage.setItem(LIVE_ROLLBACK_KEY,JSON.stringify({
      slot_no:Number(slotNo),
      saved_live:true,
      career_date:d.slot?.career_date||localPayload.date||local.date||null,
      week:d.slot?.week??localPayload.week??local.week??null,
      created_at:new Date().toISOString()
     }));
    }else clearPendingLiveRollback();
   }
   await loadSaveSlots();
   if(!silent)alert('Sauvegarde créée : '+(d.slot?.slot_name||slotName)+(hasLive&&slotType!=='autosave'?' · score(s) live figé(s)':'') );
   if(route==='saves')render();
   return d;
  }catch(e){
   local.lastSaveState={status:'error',slot_no:Number(slotNo),slot_type:slotType,career_date:localPayload.date||local.date,week:localPayload.week||local.week,updated_at:new Date().toISOString(),error:String(e?.message||e)};
   localStorage.setItem('cbLocal',JSON.stringify(snapshotLocalForSave()));
   if(!silent)alert(e.message);else console.warn('Autosave',e);
   return {ok:false,error:String(e?.message||e)};
  }
 });
}
async function loadCareerSlot(slotNo){
 if(simulating){alert('La semaine est en cours de simulation. Le chargement est verrouillé jusqu’à la fin de l’autosave.');return;}
 if(saveSlotBusy){alert('Une opération de sauvegarde ou de chargement est déjà en cours.');return;}
 const slot=saveSlots.find(x=>Number(x.slot_no)===Number(slotNo));
 if(!slot)return;
 const hasLiveNow=Boolean(local.liveSessionId||window.hasManagedLiveMatches?.());
 if(!confirm('Charger « '+slot.slot_name+' » du '+df(slot.career_date)+' ? '+(hasLiveNow?'Les matchs en cours et ':'Les ')+'changements non sauvegardés seront perdus.'))return;
 return enqueueSaveSlotWrite(async()=>{
 try{
  const d=await get('/api/load-slot',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({slot_no:Number(slotNo)})});
  local=cleanCareerLocalState(d.local_payload||{});
  liveMatchSessionsByPlayer.clear();
  liveMatchOpponentsByPlayer.clear();
  clearLiveMatchView();
  const restoredLive=(d.live_match_sessions||[]).filter(x=>['active','finished'].includes(String(x?.status||''))&&Number(x?.managed_player_id||0)>0&&Number(x?.id||0)>0);
  for(const x of restoredLive)liveMatchSessionsByPlayer.set(Number(x.managed_player_id),Number(x.id));
  if(restoredLive.length){
   localStorage.setItem(LIVE_ROLLBACK_KEY,JSON.stringify({slot_no:Number(slotNo),saved_live:true,career_date:d.slot?.career_date||local.date||null,week:d.slot?.week??local.week??null,created_at:new Date().toISOString()}));
  }else clearPendingLiveRollback();
  local.lastSaveState={status:'ok',slot_no:Number(slotNo),slot_type:'load',career_date:d.slot?.career_date||local.date,week:d.slot?.week||local.week,updated_at:new Date().toISOString()};
  localStorage.setItem('cbLocal',JSON.stringify(local));
  invalidateCareerCaches();
  boot=await get('/api/bootstrap');
  if(boot.career){local.career={...(local.career||{}),...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week}
  await Promise.allSettled([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadSaveSlots(),loadCareerHub(true)]);
  const activeLiveId=activeManagedId()||primaryManagedPlayerId()||0;
  if(restoredLive.some(x=>Number(x.managed_player_id)===Number(activeLiveId)))await restoreLiveMatchForPlayer(activeLiveId).catch(()=>{});
  route=local.liveMatch?'match':'home';render();
 }catch(e){alert('Chargement impossible : '+e.message);return {ok:false,error:String(e?.message||e)}}
 return {ok:true,slot_no:Number(slotNo)};
 });
}
async function deleteCareerSlot(slotNo){
 if(simulating){alert('La semaine est en cours de simulation. Attends la validation de l’autosave avant de supprimer un slot.');return;}
 if(saveSlotBusy)return;
 const slot=saveSlots.find(x=>Number(x.slot_no)===Number(slotNo));if(!slot)return;
 if(!confirm('Supprimer « '+slot.slot_name+' » ?'))return;
 try{await get('/api/delete-slot',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({slot_no:Number(slotNo)})});await loadSaveSlots();render()}catch(e){alert(e.message)}
}

function surfaceClass(s){const v=String(s||'');return v==='Terre'?'surface-clay':v==='Gazon'?'surface-grass':/intérieur/i.test(v)?'surface-indoor':'surface-hard'}
function surfaceLabel(t){
 if(typeof t==='string')return t;
 const base=String(t?.surface||'Dur');
 return base==='Dur'?((t?.indoor===true||String(t?.environment||'Outdoor')==='Indoor')?'Dur intérieur':'Dur extérieur'):base;
}
function circuitClass(c){return c==='Challenger'?'tag-challenger':c==='ITF'?'tag-itf':c==='NCAA'?'tag-ncaa':c==='Junior'?'tag-junior':c==='Federation'?'tag-fed':'tag-atp'}
function rankValue(p,k){return k==='doubles'?p.doubles_ranking:k==='junior_doubles'?p.junior_doubles_ranking:k==='race'?p.race_ranking:k==='doubles_race'?p.doubles_race_ranking:k==='junior_race'?p.junior_race_ranking:k==='junior_doubles_race'?p.junior_doubles_race_ranking:k==='nextgen'?p.nextgen_ranking:k==='itf'?p.itf_ranking:k==='junior'?p.junior_ranking:k==='ncaa'?(p.ncaa_official_rank??p.ita_rank_official??p.ncaa_projected_rank??p.projected_rank??p.ncaa_rank):(p.official_ranking??(p.ranking_current?p.ranking:null)??p.game_world_rank??p.world_rank??p.ranking)}
function ncaaRankPresentation(p,row=null){
 const x=row||p||{},base=p||x;
 const type=String(x.ncaa_rank_type||base.ncaa_rank_type||'');
 const official=x.ita_rank_official??x.ncaa_official_rank??base.ncaa_official_rank??base.ita_rank_official??(type==='official'?(x.ita_rank??x.ncaa_rank??base.ncaa_rank):null);
 const projected=x.projected_rank??x.ncaa_projected_rank??base.ncaa_projected_rank??base.projected_rank??(type==='simulated_depth'?(x.ita_rank??x.ncaa_rank??base.ncaa_rank):null);
 if(official!=null)return {kind:'official',rank:Number(official),value:'#'+fmt(official),compact:'#'+fmt(official)+' ITA',label:'ITA officiel #'+fmt(official),source:'ITA officiel'};
 if(projected!=null)return {kind:'simulated_depth',rank:Number(projected),value:'~#'+fmt(projected),compact:'~#'+fmt(projected)+' CB',label:'Projection Court Boss ~#'+fmt(projected),source:'Projection Court Boss'};
 const legacy=x.ncaa_rank??x.ita_rank??base.ncaa_rank;
 if(legacy!=null)return {kind:'unverified',rank:Number(legacy),value:'#'+fmt(legacy)+'?',compact:'#'+fmt(legacy)+' ?',label:'Rang NCAA #'+fmt(legacy)+' · provenance à confirmer',source:'Provenance non certifiée'};
 return {kind:'none',rank:null,value:'—',compact:'NCAA actif',label:'NCAA actif · non classé',source:'Non classé'};
}
function rankCell(p,k){
 if(k==='ncaa')return ncaaRankPresentation(p).value;
 const v=rankValue(p,k);
 return v==null?'<span class="muted">NR</span>':'#'+fmt(v);
}
function rankPoints(p,k){return k==='doubles'?p.doubles_points:k==='junior_doubles'?p.junior_doubles_points:k==='race'?p.race_points:k==='doubles_race'?p.doubles_race_points:k==='junior_race'?p.junior_race_points:k==='junior_doubles_race'?p.junior_doubles_race_points:k==='nextgen'?p.nextgen_points:k==='junior'?(Number(p.junior_points||0)+Number(p.junior_game_points||0)):k==='ncaa'?null:p.points}
function rankSnapshot(p,k){
 return k==='doubles'?p.doubles_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_doubles'?p.junior_doubles_snapshot_date||RANKING_SNAPSHOT:
        k==='doubles_race'?p.doubles_race_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_race'?p.junior_race_snapshot_date||RANKING_SNAPSHOT:
        k==='junior_doubles_race'?p.junior_doubles_race_snapshot_date||RANKING_SNAPSHOT:
        k==='race'?p.race_snapshot_date||RANKING_SNAPSHOT:
        k==='nextgen'?p.nextgen_snapshot_date||RANKING_SNAPSHOT:
        k==='junior'?p.junior_snapshot_date||RANKING_SNAPSHOT:
        k==='ncaa'?p.ncaa_snapshot_date:
        p.ranking_snapshot_date||p.data_snapshot||RANKING_SNAPSHOT
}
function ageAtSnapshot(birth,snapshot){
 if(!birth)return null;
 const b=new Date(birth+'T12:00:00'),d=new Date((snapshot||'2025-12-01')+'T12:00:00');
 let a=d.getFullYear()-b.getFullYear();
 if(d.getMonth()<b.getMonth()||(d.getMonth()===b.getMonth()&&d.getDate()<b.getDate()))a--;
 return a;
}
function displayAge(p,at=RANKING_SNAPSHOT){
 if(!p)return null;
 if(p.birth_date)return ageAtSnapshot(p.birth_date,at);
 if(p.age==null)return null;
 const snap=p.age_snapshot_date||p.data_snapshot||null;
 if(!snap)return Number(p.age);
 const y=Number(String(at).slice(0,4)),sy=Number(String(snap).slice(0,4));
 return Number(p.age)+(Number.isFinite(y)&&Number.isFinite(sy)?y-sy:0);
}
function rankAge(p,k){return p?.is_team?'—':(displayAge(p,RANKING_SNAPSHOT)??'—')}
function ageLabel(p,withUnit=true){
 const age=displayAge(p,RANKING_SNAPSHOT);
 if(age==null)return withUnit?'âge N/V':'N/V';
 const est=/estim/i.test(String(p.age_source||''))||(!p.birth_date&&String(p.age_snapshot_date||'').slice(0,4)!==String(RANKING_SNAPSHOT).slice(0,4));
 return (est?'≈':'')+age+(withUnit?' ans':'');
}


function officialAtpPhotoUrl(p){
 const code=String(p?.atp_code||'').trim().toLowerCase();
 return /^[a-z0-9]{4}$/.test(code)
   ?'https://www.atptour.com/-/media/alias/player-gladiator-headshot/'+encodeURIComponent(code)
   :'';
}
function playerPhotoCandidates(p){
 const out=[];
 const add=(url,source)=>{
   const u=String(url||'').trim();
   if(!u||out.some(x=>x.url===u))return;
   out.push({url:u,source});
 };
 if(p?.is_real)add(officialAtpPhotoUrl(p),'ATP');
 add(p?.itf_photo_url,'ITF');
 const wiki=String(p?.wiki_photo_url||'').trim()
   ||(/wiki|commons/i.test(String(p?.photo_source||''))?String(p?.photo_url||'').trim():'');
 add(wiki,'Wikipedia/Wikimedia');
 if(p?.photo_url&&!/wiki|commons/i.test(String(p?.photo_source||'')))add(p.photo_url,p.photo_source_label||p.photo_source||'Photo joueur');
 return out;
}
function playerPhotoSourceLabel(p){
 return playerPhotoCandidates(p)[0]?.source||'';
}
window.cbPhotoFallback=img=>{
 if(!img)return;
 const fallbacks=String(img.dataset?.fallbacks||'').split('|').filter(Boolean);
 const idx=Number(img.dataset?.fallbackIndex||0);
 if(idx<fallbacks.length){
   img.dataset.fallbackIndex=String(idx+1);
   try{img.src=decodeURIComponent(fallbacks[idx])}catch{img.src=fallbacks[idx]}
   return;
 }
 img.style.display='none';
 const blank=img.nextElementSibling;
 if(blank)blank.style.display='flex';
};
function playerPhotoMarkup(p){
 const candidates=playerPhotoCandidates(p);
 const blank=(visible=false)=>`<div aria-label="Aucune photo officielle disponible" title="Aucune photo officielle disponible" style="display:${visible?'flex':'none'};width:100%;height:100%;align-items:center;justify-content:center;background:linear-gradient(160deg,#10251c,#09150f)"><span style="display:block;width:42px;height:52px;border:2px solid rgba(225,238,231,.18);border-radius:24px 24px 14px 14px;position:relative"></span></div>`;
 if(!candidates.length)return blank(true);
 const primary=candidates[0].url;
 const fallbacks=candidates.slice(1).map(x=>encodeURIComponent(x.url)).join('|');
 return `<img src="${esc(primary)}" data-fallbacks="${esc(fallbacks)}" data-fallback-index="0" alt="${esc(p?.name||'Joueur')}" loading="lazy" decoding="async" style="width:100%;height:100%;object-fit:cover;object-position:center 10%" onerror="cbPhotoFallback(this)">${blank(false)}`;
}

function attrClass(v){return v>=18?'a-elite':v>=15?'a-good':v<=8?'a-low':'a-mid'}
function publicAttributeKnowledge(p,attrs,report){
 const source=(report?.attribute_estimates&&typeof report.attribute_estimates==='object')?report.attribute_estimates:{};
 const rank=Number(p?.ranking??p?.game_world_rank??99999);
 const publicConfidence=rank<=20?92:rank<=100?82:rank<=500?70:rank<=2000?56:42;
 const confidence=Math.max(20,Math.min(100,Number(report?.confidence??publicConfidence)));
 let radius=report
  ?(confidence>=90?1:confidence>=80?2:confidence>=65?3:confidence>=50?4:5)
  :(rank<=20?1:rank<=100?2:rank<=500?3:rank<=2000?4:5);
 if(report?.attribute_uncertainty!=null&&Number.isFinite(Number(report.attribute_uncertainty))){
  radius=Math.max(1,Math.min(5,Math.round(Number(report.attribute_uncertainty))));
 }
 const clamp20=v=>Math.max(1,Math.min(20,Math.round(Number(v)||1)));
 const values={},ranges={};
 Object.entries(attrs||{}).forEach(([key,raw])=>{
  if(key==='player_id'||!Number.isFinite(Number(raw)))return;
  const actual=clamp20(raw),provided=source[key];
  let low=null,high=null,center=null;
  if(provided&&typeof provided==='object'){
   low=Number(provided.min??provided.low??provided.from);
   high=Number(provided.max??provided.high??provided.to);
   center=Number(provided.value??provided.estimate??provided.mid);
  }else if(Number.isFinite(Number(provided))){
   center=Number(provided);
  }
  if(!Number.isFinite(low)||!Number.isFinite(high)){
   const base=clamp20(Number.isFinite(center)?center:actual);
   const hash=(String(p?.id??'0')+'|'+key).split('').reduce((acc,ch)=>(acc*33+ch.charCodeAt(0))>>>0,5381);
   const skew=(hash%3)-1;
   const approx=clamp20(base+skew);
   low=clamp20(approx-radius);
   high=clamp20(approx+radius);
  }else{
   low=clamp20(low);high=clamp20(high);
  }
  if(actual<low)low=actual;
  if(actual>high)high=actual;
  if(low>high){const tmp=low;low=high;high=tmp;}
  values[key]=Math.round((low+high)/2);
  ranges[key]={min:low,max:high};
 });
 return {values,ranges,confidence,radius,source:report?'scouting':'public'};
}
function header(){
 const cr=local.career||boot?.career||{};
 return `<header class="topbar"><div class="logo">COURT <b>BOSS</b></div><span class="top-date">${df(local.date||cr.career_date)}</span><div class="grow"></div><button class="ghost icon-btn" onclick="openGlobalSearch()" aria-label="Recherche">⌕</button><button class="ghost icon-btn" onclick="nav('saves')" aria-label="Sauvegardes">▣</button><button class="ghost" onclick="nav('inbox')">Boîte <span class="badge">${boot?.inbox?.filter(x=>!x.is_read).length||0}</span></button><button class="primary" ${simulating?'disabled':''} onclick="simulateWeek()">${simulating?'Simulation…':'+ 1 semaine'}</button></header>`
}
function navBar(){
 const x=[['home','Accueil'],['rankings','Classements'],['calendar','Calendrier'],['academy','Académie'],['more','Plus']];
 return `<nav class="bottom-nav">${x.map(i=>`<button class="${route===i[0]?'active':''}" onclick="nav('${i[0]}')">${i[1]}</button>`).join('')}</nav>`
}
function managerStrip(){
 const c=career(),fin=boot?.finance||{},ap=activeManagedContext?.player||null;
 const activeId=activeManagedId(),primaryId=primaryManagedPlayerId();
 const view=ap&&Number(ap.id)===activeId?ap:null;
 const squad=(management?.academyRoster||[])
  .filter(x=>String(x.status||'active')==='active')
  .map(x=>({id:Number(x.player_id||x.players?.id||0),name:x.players?.name||'Joueur'}))
  .filter((x,i,a)=>x.id&&a.findIndex(y=>y.id===x.id)===i);
 const doublesOnly=String((view?.career_focus??c.career_focus)||'mixed')==='doubles_only';
 const rank=doublesOnly?Number((view?.doubles_ranking??c.doubles_rank)??0):Number((view?.ranking??c.singles_rank)??0);
 return `<div class="manager-strip">
  <div class="manager-cell"><span>Semaine</span><b>${local.week||1}</b></div>
  <div class="manager-cell"><span>${doublesOnly?'Double':'ATP'}</span><b>#${fmt(rank)}</b></div>
  <div class="manager-cell"><span>Budget</span><b>${euro(c.budget??fin.balance??0)}</b></div>
  ${squad.length>1?`<div class="manager-cell wide"><span>Joueur actif</span><select class="select manager-player-select" onchange="setActiveManagedPlayer(this.value)">${squad.map(p=>`<option value="${p.id}" ${p.id===activeId?'selected':''}>${esc(p.name)}</option>`).join('')}</select></div>`:`<div class="manager-cell wide"><span>Date carrière</span><b>${df(local.date||c.career_date)}</b></div>`}
  <button class="manager-world" onclick="${squad.length>1?"nav('academy')":"nav('world')"}">${squad.length>1?'Groupe ▸':'Monde ▸'}</button>
 </div>`
}
function shell(body){app.innerHTML=`<div class="app-shell">${header()}${managerStrip()}<main class="page">${body}</main>${navBar()}</div>`}
function loading(t='Chargement du monde tennis…'){shell(`<div class="loader">${t}</div>`)}
window.nav=async r=>{
 route=r;
 window.scrollTo({top:0,behavior:'smooth'});
 try{
  if(r==='rankings'&&(!rankRows.length||rankKind==='ncaa')){
   loading('Chargement du classement…');
   await loadRankings();
  }
  if(r==='calendar'&&!tourRows.length){
   loading('Chargement du calendrier…');
   await loadTournaments();
  }
  if(r==='world'&&!worldStats){
   loading('Chargement du monde tennis…');
   worldStats=await get('/api/world');
  }
  if(r==='players'&&!countryRows.length)await loadCountries();
  if(r==='history'&&!historyData){
   loading('Chargement de l’histoire du tennis…');
   await loadHistory();
  }
  if(r==='competitions'&&!competitionRows.length){
   loading('Chargement des compétitions…');
   await loadCompetitions();
  }
  if(r==='staff'&&!staffWorldData){
   loading('Chargement de la base mondiale du staff…');
   await loadStaffWorld();
  }
  if(r==='training'&&!trainingPreview)await loadTrainingPreview();
  if(r==='saves'||r==='launcher')await loadSaveSlots();
  if(['careerhub','season','media','relationships','diagnostics'].includes(r))await loadCareerHub();
  if(r==='medical')await loadActiveManagedContext(true,activeManagedId()||primaryManagedPlayerId()||0);
  if(r==='match')await restoreLiveMatchForPlayer(activeManagedId()||primaryManagedPlayerId()||0);
 }catch(e){
  console.warn('Court Boss route load failed',r,e);
  shell(`<div class="card"><h2>Chargement impossible</h2><p class="muted">${esc(e.message)}</p><div class="row"><button class="primary" onclick="nav('${esc(r)}')">Réessayer</button><button class="ghost" onclick="nav('home')">Accueil</button></div></div>`);
  return;
 }
 await render();
}
async function syncLegacySinglesEntries(serverRows=[]){
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const serverIds=new Set((serverRows||[]).map(x=>Number(x.tournament_id||0)).filter(Boolean));
 const ids=[...(local.entries||[])].map(Number).filter(Boolean);
 for(const id of ids){
  if(serverIds.has(id))continue;
  const meta=local.entryMeta?.[id]||{};
  if(meta.circuit&&!['ATP','Challenger','ITF'].includes(String(meta.circuit)))continue;
  try{
   await get('/api/tournament-entry',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({tournament_id:id,player_id:playerId,action:'enter',entry_method:String(meta.entry_method||'alternate'),legacy:true})
   });
  }catch(e){console.warn('Legacy singles entry sync failed',id,e)}
 }
}
async function syncLegacyDoublesEntries(serverRows=[]){
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const serverIds=new Set((serverRows||[]).map(x=>Number(x.tournament_id||0)).filter(Boolean));
 local.doublesEntries=local.doublesEntries||[];local.doublesEntryMeta=local.doublesEntryMeta||{};
 const ids=[...local.doublesEntries].map(Number).filter(Boolean);
 for(const id of ids){
  if(serverIds.has(id))continue;
  const meta=local.doublesEntryMeta?.[id]||{};
  if(meta.server_entry_id)continue;
  if(meta.circuit&&!['ATP','Challenger','ITF'].includes(String(meta.circuit)))continue;
  try{
   await get('/api/doubles-entry',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({tournament_id:id,player_id:playerId,action:'enter',legacy:true,requested_on:meta.requested_on||local.date})
   });
  }catch(e){console.warn('Legacy doubles entry sync failed',id,e)}
 }
}
function mergeServerDoublesEntries(rows=[]){
 local.doublesEntries=local.doublesEntries||[];local.doublesEntryMeta=local.doublesEntryMeta||{};
 const serverIds=new Set((rows||[]).map(x=>Number(x.tournament_id||0)).filter(Boolean));

 // A local row that once had a server id but no longer exists server-side was
 // withdrawn by a partner/focus change. Do not silently resurrect it.
 local.doublesEntries=local.doublesEntries.filter(id=>{
  const meta=local.doublesEntryMeta?.[id]||{};
  if(meta.server_entry_id&&!serverIds.has(Number(id))){
   delete local.doublesEntryMeta[id];
   return false;
  }
  return true;
 });

 for(const row of rows||[]){
  const id=Number(row.tournament_id||0);if(!id)continue;
  if(!local.doublesEntries.includes(id))local.doublesEntries.push(id);
  const tr=Array.isArray(row.tournaments)?row.tournaments[0]:row.tournaments||{};
  const partner=Array.isArray(row.partner)?row.partner[0]:row.partner||{};
  const q=String(row.entry_method||'').includes('qualifying');
  local.doublesEntryMeta[id]={
   ...(local.doublesEntryMeta[id]||{}),
   entry_start_date:q?(tr.qualifying_start_date||tr.start_date):(tr.main_draw_start_date||tr.start_date),
   entry_method:row.entry_method||'direct',
   entry_phase:row.entry_phase||'advance',
   name:tr.name||local.doublesEntryMeta[id]?.name||'Tournoi',
   start_date:tr.start_date||local.doublesEntryMeta[id]?.start_date||null,
   end_date:tr.end_date||local.doublesEntryMeta[id]?.end_date||tr.start_date||null,
   country:tr.country||local.doublesEntryMeta[id]?.country||null,
   circuit:tr.circuit||local.doublesEntryMeta[id]?.circuit||null,
   category:tr.category||local.doublesEntryMeta[id]?.category||null,
   partner_id:Number(row.partner_id||partner.id||0)||null,
   partner_name:partner.name||local.doublesEntryMeta[id]?.partner_name||'Partenaire',
   status:'Inscription double serveur · '+String(row.entry_method||'entrée'),
   projected_acceptance:row.metadata?.projected_acceptance,
   projected_cut:row.projected_cut,
   qualifying_cut:row.metadata?.qualifying_cut,
   best_combined_rank:row.combined_rank,
   server_entry_id:row.id,
   requested_on:row.requested_on||null
  };
 }
}

function mergeServerSinglesEntries(rows=[]){
 local.entries=local.entries||[];local.entryMeta=local.entryMeta||{};
 for(const row of rows||[]){
  const id=Number(row.tournament_id||0);if(!id)continue;
  if(!local.entries.includes(id))local.entries.push(id);
  const tr=Array.isArray(row.tournaments)?row.tournaments[0]:row.tournaments||{};
  local.entryMeta[id]={
   ...(local.entryMeta[id]||{}),
   entry_start_date:String(row.entry_method||'').includes('qualifying')?(tr.qualifying_start_date||tr.start_date):(tr.main_draw_start_date||tr.start_date),
   entry_method:row.entry_method||local.entryMeta[id]?.entry_method||'alternate',
   qualifying_start_date:tr.qualifying_start_date||null,
   main_draw_start_date:tr.main_draw_start_date||null,
   name:tr.name||local.entryMeta[id]?.name||'Tournoi',
   start_date:tr.start_date||local.entryMeta[id]?.start_date||null,
   end_date:tr.end_date||local.entryMeta[id]?.end_date||tr.start_date||null,
   country:tr.country||local.entryMeta[id]?.country||null,
   circuit:tr.circuit||local.entryMeta[id]?.circuit||null,
   category:tr.category||local.entryMeta[id]?.category||null,
   status:'Inscription serveur · '+String(row.entry_method||'entrée'),
   server_entry_id:row.id,
   requested_on:row.requested_on||null
  };
 }
}

async function init(){
 loading();
 try{
   await rollbackUnsavedLiveBatchOnStartup();
   boot=await get('/api/bootstrap');
   if(boot.save&&typeof boot.save==='object'&&!localStorage.getItem('cbLocal')) local=cleanCareerLocalState(boot.save);
   local.career={...(local.career||{}),...(boot.career||{})};
   local.date=boot.career?.career_date||local.date||RANKING_SNAPSHOT;
   local.week=boot.career?.week??local.week??1;
   const serverSinglesEntries=boot.entries||[];
   const serverDoublesEntries=boot.doublesEntries||[];
   mergeServerSinglesEntries(serverSinglesEntries);
   mergeServerDoublesEntries(serverDoublesEntries);
   if(String(local.career?.career_focus||'mixed')==='doubles_only'){
     rankKind='doubles';
     tmCalFilters.entry='Double';
     local.entries=[];
     local.entryMeta={};
     if(!Array.isArray(local.training)||!local.training.length){
       local.training=['Double','Service','Retour','Double','Match play','Récupération','Repos'];
     }
   }
   localStorage.setItem('cbLocal',JSON.stringify(local));

   // Preserve old browser-only saves, but move them to the server once.
   // In doubles-only careers, active server singles entries are withdrawn instead.
   if(String(local.career?.career_focus||'mixed')==='doubles_only'){
     Promise.allSettled((serverSinglesEntries||[]).map(row=>get('/api/tournament-entry',{
       method:'POST',headers:{'Content-Type':'application/json'},
       body:JSON.stringify({tournament_id:Number(row.tournament_id),action:'withdraw',entry_method:String(row.entry_method||'alternate')})
     }))).catch(()=>{});
   }else{
     syncLegacySinglesEntries(serverSinglesEntries).catch(e=>console.warn('Singles entry migration failed',e));
   }

   if(String(local.career?.career_focus||'mixed')==='singles_only'){
     local.doublesEntries=[];
     local.doublesEntryMeta={};
     Promise.allSettled((serverDoublesEntries||[]).map(row=>get('/api/doubles-entry',{
       method:'POST',headers:{'Content-Type':'application/json'},
       body:JSON.stringify({tournament_id:Number(row.tournament_id),action:'withdraw'})
     }))).catch(()=>{});
   }else{
     syncLegacyDoublesEntries(serverDoublesEntries).catch(e=>console.warn('Doubles entry migration failed',e));
   }

   // Render immediately after the small bootstrap. Heavy world/ranking/calendar data
   // is now lazy-loaded by route instead of hammering Postgres at startup.
   render();

   Promise.allSettled([
     loadManagement(),
     loadRankingLedger(),
     loadSeasonSummary(),
     loadScheduleAdvice(),
     loadCountries()
   ]).then(()=>{if(route==='home'||route==='more')render()});
 }catch(e){
   shell(`<div class="card"><h2>Connexion au monde impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="location.reload()">Réessayer</button></div>`);
 }
}
async function loadManagement(){
 const target=Number(local.activeManagedPlayerId||primaryManagedPlayerId()||0);
 try{
  management=await get('/api/management'+(target?'?player_id='+encodeURIComponent(target):''));
  if(target)await loadActiveManagedContext(true,target).catch(()=>{});
 }catch(e){
  const primary=primaryManagedPlayerId();
  if(target&&primary&&target!==primary){
   local.activeManagedPlayerId=primary;persist();
   try{management=await get('/api/management?player_id='+encodeURIComponent(primary))}
   catch{management={contracts:[],college:[],shortlist:[]}}
  }else management={contracts:[],college:[],shortlist:[]};
 }
}
async function loadStaffWorld(){
 if(staffWorldLoading)return;
 staffWorldLoading=true;
 try{
  const p=new URLSearchParams({offset:String(staffWorldOffset),limit:'50'});
  const f=staffWorldFilters||{};
  if(f.q)p.set('q',f.q);
  if(f.role)p.set('role',f.role);
  if(f.country)p.set('country',f.country);
  if(f.former)p.set('former',f.former);
  if(f.status)p.set('status',f.status);
  staffWorldData=await get('/api/staff-world?'+p.toString());
 }finally{staffWorldLoading=false}
}
const rankPageSize=()=>rankKind==='ncaa'?150:100;
async function loadRankings(){
 const q=rankQuery?'&q='+encodeURIComponent(rankQuery):'';
 const u=rankKind==='nextgen'?'&u='+nextGenAge:'';
 const c=rankCountry?'&country='+encodeURIComponent(rankCountry):'';
 const d=await get(`/api/rankings?kind=${rankKind}&offset=${rankOffset}&limit=${rankPageSize()}${q}${u}${c}`);
 rankRows=d.rows;rankCount=d.count;rankMeta=d;
 if(rankKind==='ncaa'){
  const [doublesResult,universitiesResult]=await Promise.allSettled([
   get('/api/ncaa-doubles?offset=0&limit=100'+(rankQuery?'&q='+encodeURIComponent(rankQuery):'')),
   ncaaUniversities.length?Promise.resolve(ncaaUniversitiesMeta):get('/api/ncaa-universities')
  ]);
  if(doublesResult.status==='fulfilled'){
   ncaaDoublesRows=doublesResult.value.rows||[];ncaaDoublesMeta=doublesResult.value;
  }else{ncaaDoublesRows=[];ncaaDoublesMeta={error:String(doublesResult.reason?.message||doublesResult.reason||'Erreur NCAA double')}}
  if(universitiesResult.status==='fulfilled'){
   ncaaUniversities=universitiesResult.value.rows||[];ncaaUniversitiesMeta=universitiesResult.value;
  }else{ncaaUniversities=[];ncaaUniversitiesMeta={error:String(universitiesResult.reason?.message||universitiesResult.reason||'Erreur universités NCAA')}}
 }
}
async function loadCountries(){
 try{const d=await get('/api/countries');countryRows=d.rows||[]}catch{countryRows=[]}
}
async function loadPlayerDatabase(){
 if(dbLoading)return;
 dbLoading=true;
 try{
  const p=new URLSearchParams({offset:String(dbOffset),limit:'100',circuit:dbCircuit||'Tous'});
  if(dbQuery)p.set('q',dbQuery);
  if(dbCountry)p.set('country',dbCountry);
  const d=await get('/api/search-players?'+p.toString());
  dbRows=d.rows||[];dbCount=d.count||0;dbLoaded=true;
 }finally{dbLoading=false}
}

async function loadHistory(){
 const p=new URLSearchParams({limit:'300'});
 if(historyCountry)p.set('country',historyCountry);
 if(historyContinent)p.set('continent',historyContinent);
 try{historyData=await get('/api/history-hub?'+p.toString())}catch(e){historyData={rows:[],countryBest:[],continentBest:[],methodology:e.message,coverage:{players:0,countries:0}}}
}
async function loadTournaments(){
 const buildParams=(circuitOverride="")=>{
  const p=new URLSearchParams({offset:circuitOverride?"0":String(tourOffset),limit:"150"});
  const tournamentPlayerId=activeManagedId()||primaryManagedPlayerId()||0;
  if(tournamentPlayerId)p.set("player_id",String(tournamentPlayerId));
  if(!tourFilters.month)p.set("from","2025-12-01");
  if(circuitOverride)p.set("circuit",circuitOverride);
  Object.entries(tourFilters).forEach(([k,v])=>{
   if(!v||v==="Tous"||v==="Toutes"||(circuitOverride&&k==="circuit"))return;
   if(k==="source"&&v==="Fictif"&&(circuitOverride==="Junior"||(!circuitOverride&&tourFilters.circuit==="Junior"))){
    p.set("source","Simulation");
   }else{
    p.set(k,String(v));
   }
  });
  return p;
 };

 const base=await get("/api/tournaments?"+buildParams().toString());
 let rows=base.rows||[];
 let tbc=[...(base.tbc||[])];

 const overview=!tourFilters.circuit||tourFilters.circuit==="Tous";
 if(tourOffset===0&&overview){
  const priorityCircuits=["ATP","Junior","NCAA","Federation"];
  const extra=await Promise.all(priorityCircuits.map(async circuit=>{
   try{return await get("/api/tournaments?"+buildParams(circuit).toString())}
   catch{return {rows:[],tbc:[]}}
  }));
  extra.forEach(x=>{
   rows.push(...(x.rows||[]));
   tbc.push(...(x.tbc||[]));
  });
 }

 const byId=new Map();
 rows.forEach(t=>byId.set(Number(t.id),t));
 tourRows=[...byId.values()].sort((a,b)=>
  String(a.start_date||"").localeCompare(String(b.start_date||""))||
  Number(Boolean(b.is_verified))-Number(Boolean(a.is_verified))||
  String(a.name||"").localeCompare(String(b.name||""))
 );
 const tbcKey=x=>[x.id||"",x.name||"",x.start_date||"",x.circuit||""].join("|");
 tourTbc=[...new Map(tbc.map(x=>[tbcKey(x),x])).values()];
 tourCount=base.count||tourRows.length;
}
async function loadCompetitions(){
 competitionLoading=true;
 try{
  const p=new URLSearchParams({offset:String(competitionOffset),limit:'100'});
  Object.entries(competitionFilters).forEach(([k,v])=>{if(v&&v!=='Tous'&&v!=='Toutes')p.set(k,v)});
  const d=await get('/api/competitions?'+p.toString());
  competitionRows=d.rows||[];competitionCount=d.count||0;
 }finally{competitionLoading=false}
}

async function loadRankingLedger(){try{rankingLedger=await get('/api/ranking-ledger?date='+(local.date||RANKING_SNAPSHOT)+'&player_id='+encodeURIComponent(activeManagedId()||primaryManagedPlayerId()||0))}catch(e){const v=activePlayerCareerView();rankingLedger={total:Number(v.points||0),active:[],expired:[],player_id:activeManagedId()}}}
async function loadSeasonSummary(){try{seasonSummary=await get('/api/season-summary?player_id='+encodeURIComponent(activeManagedId()||primaryManagedPlayerId()||0))}catch(e){seasonSummary={stats:{tournaments:0,titles:0,finals:0,prize:0,matches:0,wins:0},singles:[],doubles:[],singles_points:[],doubles_points:[],player_id:activeManagedId()}}}
async function loadScheduleAdvice(){try{scheduleAdvice=await get('/api/schedule-advice?player_id='+encodeURIComponent(activeManagedId()||primaryManagedPlayerId()||0))}catch(e){scheduleAdvice={recommended:[],player_id:activeManagedId()}}}
async function loadDoublesHub(){
 if(doublesHubLoading)return;
 doublesHubLoading=true;
 try{
  const [r,j,t]=await Promise.all([
    get('/api/rankings?kind=doubles&offset=0&limit=200'),
    get('/api/rankings?kind=junior_doubles&offset=0&limit=200'),
    get('/api/doubles-race')
  ]);
  doublesHubRows=r.rows||[];
  juniorDoublesHubRows=j.rows||[];
  doublesRaceRows=(t.rows||[]).map(x=>({
    ...x,
    rank:x.doubles_race_ranking??x.rank,
    points:x.doubles_race_points??x.points,
    snapshot_date:x.doubles_race_snapshot_date??x.snapshot_date
  }));
 }catch(e){console.warn('Double hub',e)}
 finally{doublesHubLoading=false;if(route==='doubles')render()}
}

function career(){
 const c={...(boot?.career||{}),...(local.career||{})};
 c.singles_rank=c.singles_rank??742;c.doubles_rank=c.doubles_rank??1284;c.points=c.points??34;c.player_name=c.player_name||'Anthony';c.country=c.country||'FRA';
 return c;
}
function primaryManagedPlayerId(){return Number((boot?.career||local?.career||{}).managed_player_id||0)}
function managedSquadIds(){
 const primary=primaryManagedPlayerId();
 const ids=[primary,...(management?.academyRoster||[]).filter(x=>String(x.status||'active')==='active').map(x=>Number(x.player_id||x.players?.id||0))].filter(Boolean);
 return [...new Set(ids)];
}
function activeManagedId(){
 const primary=primaryManagedPlayerId();
 const wanted=Number(local.activeManagedPlayerId||primary||0);
 const ids=managedSquadIds();
 return ids.includes(wanted)?wanted:(primary||ids[0]||0);
}
function activePlayerCareerView(){
 const base=career();
 const player=activeManagedContext?.player||null;
 const activeId=activeManagedId();
 if(!player||Number(player.id)!==activeId)return base;
 return {
  ...base,
  managed_player_id:activeId,
  player_name:player.name||base.player_name,
  country:player.country||base.country,
  singles_rank:player.ranking??base.singles_rank,
  doubles_rank:player.doubles_ranking??base.doubles_rank,
  points:player.points??base.points,
  doubles_points:player.doubles_points??base.doubles_points,
  nextgen_rank:player.nextgen_ranking??base.nextgen_rank??base.nextgen_ranking,
  nextgen_ranking:player.nextgen_ranking??base.nextgen_ranking,
  nextgen_points:player.nextgen_points??base.nextgen_points,
  nextgen_finals_status:activeManagedContext?.nextgen_finals_status??base.nextgen_finals_status??null,
  age:player.age??base.age,
  current_ability:player.current_ability??base.current_ability,
  potential:player.potential??base.potential,
  form:player.form??base.form,
  fitness:player.fitness??base.fitness,
  morale:player.morale??base.morale,
  fatigue:player.fatigue??base.fatigue,
  style:player.style??base.style,
  injury_status:player.injury_status??base.injury_status,
  career_focus:player.career_focus??base.career_focus
 };
}
async function loadActiveManagedContext(force=false,requestedId=null){
 const playerId=Number(requestedId||activeManagedId()||primaryManagedPlayerId()||0);
 if(!playerId)return null;
 if(activeManagedContextLoading)return activeManagedContext;
 if(activeManagedContext&&!force&&Number(activeManagedContext.player_id)===playerId)return activeManagedContext;
 activeManagedContextLoading=true;
 try{
  const d=await get('/api/managed-player-context?player_id='+encodeURIComponent(playerId));
  activeManagedContext=d;
  local.activeManagedPlayerId=Number(d.player_id||playerId);
  local.entries=[];local.entryMeta={};
  local.doublesEntries=[];local.doublesEntryMeta={};
  mergeServerSinglesEntries(d.entries||[]);
  mergeServerDoublesEntries(d.doubles_entries||[]);
  persist();
  return d;
 }finally{activeManagedContextLoading=false}
}
window.setActiveManagedPlayer=async id=>{
 const target=Number(id||0);
 if(!target||!managedSquadIds().includes(target))return alert('Ce joueur ne fait pas partie du groupe géré.');
 rememberCurrentLiveMatch();
 clearLiveMatchView();
 local.activeManagedPlayerId=target;
 local.trainingPlayerId=target;
 trainingPreview=null;
 careerHub=null;
 persist();
 try{
  await loadActiveManagedContext(true,target);
  tournamentDetailRows.clear();
  await Promise.all([
   loadRankingLedger().catch(()=>{}),
   loadSeasonSummary().catch(()=>{}),
   loadScheduleAdvice().catch(()=>{}),
   loadTournaments().catch(()=>{}),
   loadManagement().catch(()=>{})
  ]);
  if(route==='training')await loadTrainingPreview(true).catch(()=>{});
  await restoreLiveMatchForPlayer(target).catch(()=>{});
  render();
 }catch(e){alert(e.message)}
};
function home(){
 const c=activePlayerCareerView(),doublesOnly=String(c.career_focus||'mixed')==='doubles_only';
 const activeRecommendations=scheduleAdvice?.recommended||[];
 const next=doublesOnly
  ?(activeRecommendations.find(t=>t.doubles)||tourRows.find(t=>t.doubles)||boot.upcoming?.find(t=>t.doubles)||boot.upcoming?.[0])
  :(activeRecommendations.find(t=>t.singles!==false)||tourRows.find(t=>t.singles!==false)||boot.upcoming?.[0]);
 const academy=boot.academy||{},fin=boot.finance||{};
 const managedSquad=(management?.academyRoster||[])
  .filter(x=>String(x.status||'active')==='active'&&Number(x.player_id||x.players?.id||0)>0)
  .map(x=>({id:Number(x.player_id||x.players?.id||0),name:x.players?.name||'Joueur',country:x.players?.country||'',ranking:x.players?.ranking||null,role:x.squad_role||'Académie'}))
  .filter((x,i,a)=>a.findIndex(y=>y.id===x.id)===i)
  .slice(0,8);
 const urgentDecisions=[...(boot.inbox||[])]
  .filter(x=>x.decision_status==='pending')
  .sort((a,b)=>({urgent:0,high:1,normal:2}[a.priority]??2)-({urgent:0,high:1,normal:2}[b.priority]??2)||String(a.expires_at||'9999-12-31').localeCompare(String(b.expires_at||'9999-12-31')))
  .slice(0,3);
 const msgs=[...(local.feed||[]),...(boot.news||[]).map(x=>x.body)].slice(0,6);
 const quickActions=doublesOnly
  ?[['calendar','Calendrier double','Inscrire la paire'],['competitions','Compétitions','Palmarès & records'],['training','Entraînement','Plan double de la semaine'],['doubles','Hub Double','Partenaire, Race & tournois'],['scouting','Scouting','Chercher des talents'],['contracts','Contrats','Staff & joueurs'],['medical','Médical','Fatigue & blessures'],['davis','Fédération','Coupe Davis'],['world','Monde','Base mondiale & circuits'],['season','Saison','Bilan & points 52 semaines'],['myplayer','Mon joueur','Orientation & progression']]
  :[['calendar','Calendrier','Inscrire le joueur'],['competitions','Compétitions','Palmarès & records'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Chercher des talents'],['match','Match Center','Analyser les matchs'],['tactics','Tactique','Plan de match'],['contracts','Contrats','Staff & joueurs'],['medical','Médical','Fatigue & blessures'],['davis','Fédération','Coupe Davis'],['world','Monde','Base mondiale & circuits'],['season','Saison','Bilan & points 52 semaines']];
 return `<div class="section-head"><div><div class="eyebrow">Carrière · semaine ${local.week}</div><h1>Centre de management</h1><div class="muted">Le monde avance même quand tu ne joues pas.</div></div><span class="pill">ATP · classement réf. ${df(RANKING_SNAPSHOT)}</span></div>
 ${urgentDecisions.length?`<section class="card career-decision-strip"><div class="row between"><div><div class="eyebrow">Décisions manager</div><h2>${urgentDecisions.length} dossier(s) à arbitrer</h2></div><button class="ghost" onclick="nav('inbox')">Boîte complète</button></div><div class="stack" style="margin-top:8px">${urgentDecisions.map(x=>`<div class="list-item"><div class="row between"><div><b>${esc(x.title)}</b><div class="muted mini">${esc(String(x.body||'').slice(0,150))}</div></div><span class="badge ${x.priority==='urgent'||x.priority==='high'?'warn':''}">${esc(x.priority||'normal')}</span></div><div class="row" style="margin-top:8px;flex-wrap:wrap">${inboxActionButton(x,x.action_type,x.action_label||'Ouvrir',x.action_payload,'primary')}${inboxActionButton(x,x.secondary_action_type,x.secondary_action_label,x.secondary_action_payload,'soft-btn')}</div></div>`).join('')}</div></section>`:''}
 <section class="hero">
  <div class="card click" onclick="nav('myplayer')">
   <div class="row between"><div><div class="eyebrow">Joueur géré</div><div class="hero-name">${flags[c.country]||'🏳️'} ${esc(c.player_name)}</div><div class="muted">ATP #${fmt(c.singles_rank)} · Double ${careerDoublesRankText(c)} · ${careerFocusLabel(c.career_focus||'mixed')}</div><div class="row" style="margin-top:6px;gap:6px;flex-wrap:wrap"><span class="badge ${doublesOnly?'good':''}">${doublesOnly?'Circuit principal · Double':'Objectif · '+careerFocusLabel(c.career_focus||'mixed')}</span>${doublesOnly?'<span class="badge">Points simple en extinction naturelle</span>':''}</div></div><div class="progress-ring" style="--p:${c.form||72}"><b>${c.form||72}</b></div></div>
   <div class="kpi-strip" style="margin-top:14px">
    ${[['Forme',c.form||72],['Fitness',c.fitness||91],['Moral',c.morale||78],['Fatigue',c.fatigue||18]].map(x=>`<div class="kpi"><span class="muted mini">${x[0]}</span><b>${x[1]}</b><div class="bar"><i style="width:${x[1]}%"></i></div></div>`).join('')}
   </div>
  </div>
  <div class="card click" onclick="nav('finance')"><div class="eyebrow">Académie</div><h2>${esc(academy.name||'Court Boss Academy')}</h2><div class="statline"><div class="statbox"><span class="muted mini">Budget</span><b>${euro(c.budget??academy.budget??14800)}</b></div><div class="statbox"><span class="muted mini">Board</span><b>${academy.board_confidence||76}%</b></div></div><p class="muted mini" style="margin-top:10px">${esc(academy.philosophy||'Développement complet du joueur')}</p></div>
 </section>
 ${managedSquad.length>1?`<section class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Groupe géré</div><h2>${managedSquad.length} joueurs sous ta responsabilité</h2><div class="muted mini">Choisis le joueur actif pour le calendrier, le plan de saison et l'entraînement.</div></div><button class="ghost" onclick="nav('academy')">Académie</button></div><div class="stack" style="margin-top:8px">${managedSquad.map(p=>`<div class="list-item row between"><span class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted micro">${esc(p.role)}${p.ranking?' · ATP #'+fmt(p.ranking):''}</div></span><div class="row">${activeManagedId()===p.id?'<span class="badge good">Actif</span>':`<button class="soft-btn" onclick="setActiveManagedPlayer(${p.id})">Gérer</button>`}<button class="soft-btn" onclick="openPlayer(${p.id})">Profil</button><button class="primary" onclick="trainAcademyPlayer(${p.id})">Entraîner</button></div></div>`).join('')}</div></section>`:''}
 <div class="quick-grid" style="margin-top:12px">
  ${quickActions.map(x=>`<div class="quick" onclick="nav('${x[0]}')"><span class="muted mini">${x[1]}</span><strong>${x[2]}</strong></div>`).join('')}
 </div>
 <section class="grid g2" style="margin-top:12px">
  <div class="card click home-next-tournament" onclick="openTournament(${next?.id||0})"><div class="eyebrow">Prochain événement</div>${next?`<div class="row" style="align-items:center;gap:12px;margin-top:8px">${tournamentThumb(next)}<div style="min-width:0"><h2 style="margin:0 0 7px">${esc(next.name)}</h2><div class="row" style="gap:6px;flex-wrap:wrap"><span class="badge ${circuitClass(next.circuit)}">${esc(next.category||next.level)}</span><span class="badge ${surfaceClass(next.surface)}">${esc(surfaceLabel(next))}</span></div><p class="muted" style="margin:7px 0 0">${esc(next.city||'')} · ${df(next.start_date)}</p></div></div>`:'<div class="empty">Aucun événement</div>'}</div>
  <div class="card"><div class="row between"><h2>Fil manager</h2><button class="ghost" onclick="nav('inbox')">Tout voir</button></div>${msgs.map(m=>`<div class="news-item">${esc(m)}</div>`).join('')}</div>
 </section>
 <section class="grid g2" style="margin-top:12px">
  <div class="card"><div class="row between"><h2>Objectifs du board</h2><span class="pill">${academy.board_confidence||76}% confiance</span></div>${(boot.board||[]).map(o=>`<div class="list-item"><div class="row between"><b>${esc(o.objective)}</b><span class="mini muted">${o.progress}%</span></div><div class="bar"><i style="width:${o.progress}%"></i></div><div class="mini muted" style="margin-top:5px">${esc(o.target_value||'')} · ${df(o.deadline)}</div></div>`).join('')}</div>
  <div class="card"><div class="row between"><h2>Top mondial</h2><button class="ghost" onclick="nav('rankings')">Classement complet</button></div>${(boot.topPlayers||[]).slice(0,8).map(p=>`<div class="list-item row between click" onclick="openPlayer(${p.id})"><span><b>#${p.ranking}</b> ${flags[p.country]||'🏳️'} ${esc(p.name)}</span><b>${fmt(p.points)}</b></div>`).join('')}</div>
 </section>`
}
function rankings(){
 const kinds=[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['doubles_race','Race Double'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['junior_race','Race Junior'],['junior_doubles','Junior Double'],['junior_doubles_race','Race Junior Dbl'],['itf','ITF WTT'],['ncaa','NCAA / ITA']];
 if(rankKind==='ncaa')return ncaaRanking();
 const startRow=rankCount?rankOffset+1:0,endRow=Math.min(rankOffset+rankRows.length,rankCount);
 const first=rankRows[0]||{},snap=rankSnapshot(first,rankKind);
 const label=rankKind==='singles'?'ATP Ranking':rankKind==='doubles'?'ATP Doubles':rankKind==='doubles_race'?'ATP Doubles Race':rankKind==='junior_doubles'?'Court Boss Junior Doubles':rankKind==='junior_doubles_race'?'Junior Double Race':rankKind==='race'?'ATP Race':rankKind==='junior_race'?'ITF Junior Finals Race':rankKind==='nextgen'?'Next Gen Race U21':rankKind==='junior'?'ITF Juniors':'ITF World Tennis Tour';
 const reference=rankKind==='singles'
   ?'Classement monde Court Boss jusqu’au rang 30 000. Le rang ATP officiel reste identifié séparément quand il est disponible · snapshot '+df(snap||RANKING_SNAPSHOT)+'.'
   :rankKind==='doubles'
     ?'Classement ATP Double officiel Live-Tennis · Top 1000 au '+df(snap||RANKING_SNAPSHOT)+' · '+fmt(worldStats?.indexedDoubles||rankCount)+' profils indexés pour le scouting.'
     :rankKind==='doubles_race'
       ?'Race par équipes vers le Nitto ATP Finals · Top 8 qualifié · '+df(snap||RANKING_SNAPSHOT)
     :rankKind==='race'
       ?'ATP Race · base 01 déc. 2025 · '+df(snap||RANKING_SNAPSHOT)
     :rankKind==='junior_race'
       ?'Qualification ITF World Tennis Tour Junior Finals · Top 8 · points sur 12 mois · '+df(snap||RANKING_SNAPSHOT)
     :rankKind==='junior_doubles_race'
       ?'Course par paires vers le Court Boss Junior Doubles Finals · Top 8 · '+df(snap||RANKING_SNAPSHOT)
       :rankKind==='nextgen'
         ?'ATP Next Gen Race · base 01 déc. 2025 · '+df(snap||RANKING_SNAPSHOT)+' · âge au 01/12/2025'
       :rankKind==='junior'
         ?'ITF Juniors · snapshot '+df(snap||RANKING_SNAPSHOT)
       :rankKind==='junior_doubles'
         ?'Court Boss Junior Double · classement simulé séparé · snapshot '+df(snap||RANKING_SNAPSHOT)
         :'ITF World Tennis Tour · snapshot '+df(snap||RANKING_SNAPSHOT);
 const pill=rankKind==='ncaa'?(snap?df(snap):'NCAA'):df(snap||RANKING_SNAPSHOT);
 return `<div class="section-head"><div><div class="eyebrow">Base mondiale</div><h1>Classements</h1><div class="muted">Ranking, Race, Double et Next Gen sont séparés. Le classement ATP de départ correspond au snapshot officiel du 1er décembre 2025, puis la simulation de ta carrière fait évoluer ce monde.</div></div><span class="pill">${pill}</span></div>
 <div class="tabs rank-tabs">${kinds.map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}<button class="deep-db-tab" onclick="dbCircuit='Tous réels';dbOffset=0;dbLoaded=false;nav('players')">Monde ${fmt(worldStats?.worldRankingCapacity||30000)}</button></div>
 ${rankKind==='nextgen'? `<div class="age-filter"><span class="muted mini">Âge au 01/12/2025</span>${[18,19,20,21].map(a=>`<button class="${nextGenAge===a?'active':''}" onclick="setNextGenAge(${a})">U${a}</button>`).join('')}</div>`:''}
 ${rankKind==='junior'? `<div class="notice mini" style="margin-bottom:12px"><b>Vivier junior Court Boss</b> · <b>classement #1 à #2000 piloté par les points</b> · ${fmt(rankMeta?.officialRealCount||0)} vrais vérifiés + ${fmt(rankMeta?.generatedCount||0)} newgens. <div class="row" style="margin-top:8px;gap:6px;flex-wrap:wrap"><span class="badge">GC 1000</span><span class="badge">J500 500</span><span class="badge">J300 300</span><span class="badge">J200 200</span><span class="badge">J100 100</span><span class="badge">J60 60</span><span class="badge">J30 30</span></div></div>`:''} ${rankKind==='junior_doubles'? `<div class="notice mini" style="margin-bottom:12px"><b>Circuit Junior Double</b> · classement séparé #1 à #2000. <div class="row" style="margin-top:8px;gap:6px;flex-wrap:wrap"><span class="badge">GC 750</span><span class="badge">J500 375</span><span class="badge">J300 225</span><span class="badge">J200 150</span><span class="badge">J100 75</span><span class="badge">J60 45</span><span class="badge">J30 25</span></div></div>`:''} ${rankKind==='doubles_race'? `<div class="notice mini" style="margin-bottom:12px"><b>Race Double ATP</b> · <b>${fmt(rankCount)} paires classées</b> · Top ${rankMeta?.qualificationPlaces||8} → Nitto ATP Finals. Top publié conservé, puis classement estimé Court Boss pour les paires suivantes.</div>`:''}
 ${rankKind==='junior_race'? `<div class="notice mini" style="margin-bottom:12px"><b>Race Junior</b> · <b>${fmt(rankCount)} joueurs classés</b> · Top ${rankMeta?.qualificationPlaces||8} → ITF World Tennis Tour Junior Finals · #9 remplaçant · suite estimée quand la Race officielle n’est pas publiée. Vainqueur Finals : 1000 pts.</div>`:''}
 ${rankKind==='junior_doubles_race'? `<div class="notice mini" style="margin-bottom:12px"><b>Race Junior Double</b> · <b>${fmt(rankCount)} paires classées</b> · Top ${rankMeta?.qualificationPlaces||8} → Court Boss Junior Doubles Finals · #9 remplaçant. Classement de paires simulé/estimé au-delà des données disponibles.</div>`:''} ${rankKind==='singles'? `<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Classement carrière simulé</div><div class="hero-name" style="font-size:25px">ATP #${activePlayerCareerView().singles_rank}</div><div class="muted">${fmt(activePlayerCareerView().points)} points actifs · base initiale ${df(RANKING_SNAPSHOT)}</div></div><div style="text-align:right"><div class="muted mini">Prochaine expiration</div><b>${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?df(rankingLedger.active[0].expiry_date):'—'}</b><div class="muted mini">${rankingLedger&&rankingLedger.active&&rankingLedger.active[0]?'-'+rankingLedger.active[0].points+' pts':''}</div></div></div></div>`:''}
 <div class="card">
  <div class="rank-tools fm-rank-tools"><input class="input" value="${esc(rankQuery)}" placeholder="Rechercher dans les 30 000 joueurs…" onkeydown="if(event.key==='Enter')searchRanking(this.value)"><select class="select" onchange="setRankCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${rankCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select><div class="rank-jump"><input class="input" id="rankJump" type="number" min="1" max="${Math.max(rankCount,1)}" placeholder="Aller au rang"><button class="soft-btn" onclick="jumpRanking()">Aller</button></div></div>
  <div class="notice mini" style="margin-top:10px"><b>${label}</b> · ${reference}. Les valeurs de simulation restent séparées des snapshots historiques.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>${rankKind==='singles'?'# ATP / Monde':'#'}</th>${rankKind==='singles'?'<th>Meilleur carrière</th><th>+/−</th>':''}<th>${rankRows[0]?.is_team?'Paire':'Joueur'}</th><th>Âge 01/12/25</th><th>Pays</th><th>Pts</th><th>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?'Finals':rankKind==='nextgen'?'ATP':'Niv.'}</th><th>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?'Statut':rankKind==='nextgen'?'Statut':'Pot.'}</th></tr></thead><tbody>
  ${rankRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${rankCell(p,rankKind)}</td>${rankKind==='singles'?`<td>${(p.career_high_rank??p.best_rank_2025)?'#'+fmt(p.career_high_rank??p.best_rank_2025):'—'}</td><td>${p.ranking_change==null?'<span class="muted">—</span>':p.ranking_change>0?'<span class="rank-up">▲ '+p.ranking_change+'</span>':p.ranking_change<0?'<span class="rank-down">▼ '+Math.abs(p.ranking_change)+'</span>':'<span class="muted">=</span>'}</td>`:''}<td><b>${esc(p.name)}</b> ${p.game_generated?'<span class="badge">Newgen</span>':''}${rankKind==='junior'&&p.junior_rank_type==='official'?'<span class="badge good">ITF vérifié</span>':rankKind==='junior'&&p.junior_rank_type==='verified_nr'?'<span class="badge">ITF · NR</span>':''}${p.ncaa_current?'<span class="badge tag-ncaa">NCAA</span>':p.ncaa_status==='Alumni'?'<span class="badge tag-ncaa">NCAA Alumni</span>':''}${rankKind==='doubles'?(p.doubles_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Index DB</span>'):''}${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?(p.official_qualification?'<span class="badge good">Rang officiel · pts estimés</span>':/estimated|estimate|estimé/i.test(String(p.source||''))?'<span class="badge">Estimé</span>':/simulated|Court Boss/i.test(String(p.source||''))?'<span class="badge">Simulé</span>':'<span class="badge good">Officiel</span>'):''}<div class="muted micro">${rankKind==='singles'?(p.official_ranking?'ATP officiel #'+fmt(p.official_ranking):p.game_generated?'Joueur généré Court Boss':'Base historique / scouting'):rankKind==='junior'?(p.junior_rank_type==='official'?'Rang jeu #'+fmt(p.junior_ranking)+' · ITF source #'+fmt(p.junior_official_ranking)+(rankSnapshot(p,rankKind)?' · au '+df(rankSnapshot(p,rankKind)):''):p.junior_rank_type==='verified_nr'?'Rang jeu #'+fmt(p.junior_ranking)+' · ITF vérifié, rang estimé':'Rang jeu #'+fmt(p.junior_ranking)+' · Newgen simulé · 13–17 ans'):(rankSnapshot(p,rankKind)?'au '+df(rankSnapshot(p,rankKind)):'')}${p.ncaa_current&&p.ncaa_school?' · '+esc(p.ncaa_school):p.ncaa_status==='Alumni'&&p.ncaa_last_school?' · ex-'+esc(p.ncaa_last_school):''}</div></td><td>${rankAge(p,rankKind)}</td><td>${flags[p.country]||'🏳️'} ${esc(p.country)}</td><td><b>${rankPoints(p,rankKind)==null?'—':fmt(rankPoints(p,rankKind))}</b></td><td>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?'Top '+fmt(rankMeta?.qualificationPlaces||8):rankKind==='nextgen'?(p.ranking?'#'+fmt(p.ranking):'—'):rankingLevelKnowledgeCell(p)}</td><td>${['doubles_race','junior_race','junior_doubles_race'].includes(rankKind)?(p.finals_status==='qualified'?'<span class="badge good">Qualifié</span>':p.finals_status==='alternate'?'<span class="badge warn">Remplaçant</span>':'<span class="badge">En course</span>'):rankKind==='nextgen'?(p.nextgen_status==='withdrawn'?'<span class="badge bad">Retiré</span>':p.nextgen_status==='alternate'?'<span class="badge warn">Remplaçant</span>':p.nextgen_status==='qualified'?'<span class="badge good">Qualifié</span>':rankingPotentialKnowledgeCell(p)):rankingPotentialKnowledgeCell(p)}</td></tr>`).join('')}
  </tbody></table></div>
  <div class="pagination"><button ${rankOffset===0?'disabled':''} onclick="rankPage(-1)">←</button><span class="muted mini">lignes ${fmt(startRow)}–${fmt(endRow)} / ${fmt(rankCount)}</span><button ${rankOffset+rankPageSize()>=rankCount?'disabled':''} onclick="rankPage(1)">→</button></div>
 </div>`
}
window.jumpRanking=async()=>{
 const target=clamp(Number(document.getElementById('rankJump')?.value||1),1,Math.max(1,rankCount));
 rankQuery='';rankOffset=Math.max(0,Math.min(Math.max(0,rankCount-rankPageSize()),target-1));
 await loadRankings();render();
}
function ncaaRanking(){
 const rows=rankRows||[],startRow=rankCount?rankOffset+1:0,endRow=Math.min(rankOffset+rows.length,rankCount);
 const doubleRows=ncaaDoublesRows||[];
 const modeTabs=`<div class="ncaa-hub-menu">
  <button class="ncaa-hub-menu-btn ${ncaaView==='singles'?'active':''}" onclick="setNcaaView('singles')"><span class="ncaa-hub-menu-icon">#</span><span><b>Simple</b><small>${fmt(rankMeta?.verifiedCurrentRanks||0)} ITA officiels</small></span></button>
  <button class="ncaa-hub-menu-btn ${ncaaView==='doubles'?'active':''}" onclick="setNcaaView('doubles')"><span class="ncaa-hub-menu-icon">2</span><span><b>Double</b><small>Top ${fmt(ncaaDoublesMeta?.officialCapacity||90)}</small></span></button>
  <button class="ncaa-hub-menu-btn ${ncaaView==='universities'?'active':''}" onclick="setNcaaView('universities')"><span class="ncaa-hub-menu-icon">U</span><span><b>Universités</b><small>${fmt(ncaaUniversitiesMeta?.count||ncaaUniversities.length||230)} programmes</small></span></button>
 </div>
 <div class="ncaa-university-quick-search">
  <span class="ncaa-search-icon">⌕</span>
  <input class="input" value="${esc(ncaaUniversityQuery)}" placeholder="Rechercher une université, une conférence…" onfocus="openNcaaUniversityHub()" oninput="quickNcaaUniversitySearch(this.value)">
  <button class="soft-btn" onclick="openNcaaUniversityHub()">Universités →</button>
 </div>`;
 const singlesTable=`
  <div class="notice mini" style="margin-top:10px"><b>NCAA / ITA au 01/12/2025</b> · <b>${fmt(rankMeta?.verifiedCurrentRanks||0)} rangs ITA officiels</b> au snapshot du ${df(rankMeta?.officialSnapshotDate||'2025-11-25')} · la profondeur Court Boss est séparée et précédée de <b>~</b>. Un <b>~#126</b> est une projection de gameplay, jamais le vrai ITA #126. L’UTR utilise aussi ~ lorsqu’il est estimé. ${rankMeta?.officialSourceUrl?`<a class="soft-btn" style="margin-left:6px" href="${esc(rankMeta.officialSourceUrl)}" target="_blank" rel="noopener noreferrer">Source ITA</a>`:''}</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>Rang</th><th>Référence</th><th>Joueur</th><th>Âge 01/12/25</th><th>Université</th><th>Division</th><th>UTR</th><th>ATP</th><th>Statut</th></tr></thead><tbody>
   ${rows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${p.ncaa_rank_type==='simulated_depth'?(p.ncaa_projected_rank?'~#'+fmt(p.ncaa_projected_rank):'~'):p.ncaa_rank?'#'+fmt(p.ncaa_rank):'—'}</td><td>${p.ncaa_rank_type==='official'?'<span class="badge good">ITA officiel</span>':p.ncaa_rank_type==='simulated_depth'?'<span class="badge warn">Projection Court Boss</span>':p.ncaa_rank_verified?'<span class="badge good">Vérifié</span>':'<span class="badge">Profil NCAA</span>'}<div class="muted micro">${p.ncaa_snapshot_date?'au '+df(p.ncaa_snapshot_date):''}</div></td><td><b>${esc(p.name)}</b><div class="muted micro">${flags[p.country]||'🏳️'} ${esc(p.country||'')}</div></td><td>${rankAge(p,'ncaa')}</td><td><b>${esc(p.ncaa_school||'—')}</b></td><td>${esc(p.ncaa_division||'NCAA')}</td><td>${p.utr_rating!=null?'<b>'+(p.utr_verified?'':'~')+Number(p.utr_rating).toFixed(2)+'</b><div class="muted micro">'+(p.utr_verified?'UTR vérifié':'UTR estimé Court Boss')+'</div>':'—'}</td><td>${p.ranking_current&&p.ranking?'<b>#'+fmt(p.ranking)+'</b><div class="muted micro">ATP 01/12/25</div>':'<span class="muted">NR</span><div class="muted micro">non classé ATP</div>'}</td><td><span class="badge ${(p.ncaa_current||p.ncaa_current_verified)?'good':''}">${(p.ncaa_current||p.ncaa_current_verified)?'NCAA actif':p.ncaa_status==='Alumni'?'NCAA Alumni':esc(p.ncaa_status||'NCAA historique')}</span></td></tr>`).join('')}
  </tbody></table></div>
  ${rows.length?'' : '<div class="empty">Aucun profil NCAA pour ce filtre.</div>'}
  <div class="pagination"><button ${rankOffset===0?'disabled':''} onclick="rankPage(-1)">←</button><span class="muted mini">lignes ${fmt(startRow)}–${fmt(endRow)} / ${fmt(rankCount)}</span><button ${rankOffset+rankPageSize()>=rankCount?'disabled':''} onclick="rankPage(1)">→</button></div>`;
 const doublesTable=`
  <div class="notice mini" style="margin-top:10px"><b>NCAA Double au 01/12/2025</b> · ${fmt(ncaaDoublesMeta?.count||doubleRows.length)} paire(s) vérifiée(s) disponible(s) au cutoff.</div>
  <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>#</th><th>Paire</th><th>Université</th><th>Référence</th></tr></thead><tbody>
   ${doubleRows.map(x=>`<tr><td class="rank-num">#${fmt(x.ita_rank)}</td><td><b><span class="click" onclick="openPlayer(${x.player_one_id})">${esc(x.player_one_name)}</span> / <span class="click" onclick="openPlayer(${x.player_two_id})">${esc(x.player_two_name)}</span></b></td><td>${esc(x.school||'—')}</td><td><span class="badge good">ITA officiel</span></td></tr>`).join('')}
  </tbody></table></div>
  ${doubleRows.length?'' : '<div class="empty">Aucune paire NCAA pour ce filtre.</div>'}`;
 const universityNeedle=String(ncaaUniversityQuery||'').trim().toLowerCase();
 const universityConferences=[...new Set((ncaaUniversities||[]).map(x=>String(x.conference||'')).filter(Boolean))].sort((a,b)=>a.localeCompare(b));
 let universityRows=(ncaaUniversities||[]).filter(x=>{
  const matchesSearch=!universityNeedle||String(x.name||'').toLowerCase().includes(universityNeedle)||String(x.conference||'').toLowerCase().includes(universityNeedle)||String(x.state||'').toLowerCase().includes(universityNeedle);
  const matchesConference=!ncaaUniversityConference||String(x.conference||'')===ncaaUniversityConference;
  const matchesType=ncaaUniversityFilter==='ita'?Number(x.official_ranked_count||0)>0:ncaaUniversityFilter==='atp'?Number(x.atp_ranked_count||0)>0:true;
  return matchesSearch&&matchesConference&&matchesType;
 });
 universityRows=[...universityRows].sort((a,b)=>{
  if(ncaaUniversitySort==='name')return String(a.name||'').localeCompare(String(b.name||''));
  if(ncaaUniversitySort==='atp'){
   const ar=Number(a.best_atp_rank??999999),br=Number(b.best_atp_rank??999999);
   return ar-br||String(a.name||'').localeCompare(String(b.name||''));
  }
  if(ncaaUniversitySort==='roster')return Number(b.roster_count||0)-Number(a.roster_count||0)||String(a.name||'').localeCompare(String(b.name||''));
  const ar=Number(a.best_ita_rank??999999),br=Number(b.best_ita_rank??999999);
  return ar-br||String(a.name||'').localeCompare(String(b.name||''));
 });
 const universityVisual=(t)=>{
  const label=String(t?.name||'NCAA').trim();
  let h=0;for(const ch of label)h=(h*31+ch.charCodeAt(0))%360;
  return {a:'hsl('+h+' 52% 30%)',b:'hsl('+((h+32)%360)+' 55% 16%)',initials:label.split(/\s+/).slice(0,2).map(x=>x[0]||'').join('').toUpperCase()};
 };
 const universitiesTable=ncaaUniversityDetail?(()=>{
  const d=ncaaUniversityDetail,t=d.university||{},roster=d.rows||[],theme=universityVisual(t);
  const hero=String(t.hero_image_url||'').trim();
  const mark=String(t.logo_url||t.favicon_url||'').trim();
  const location=[t.city,t.state].filter(Boolean).join(', ');
  return `<div class="ncaa-university-detail">
   <button class="soft-btn ncaa-back-btn" onclick="closeNcaaUniversity()">← Universités</button>
   <section class="ncaa-university-hero" style="--school-a:${esc(t.primary_color||theme.a)};--school-b:${esc(t.secondary_color||theme.b)};${hero?'background-image:linear-gradient(180deg,rgba(3,12,8,.16),rgba(3,12,8,.90)),url(\''+esc(hero)+'\');':''}">
    <div class="ncaa-university-hero-inner">
     <div class="ncaa-school-logo-wrap">${mark?`<img src="${esc(mark)}" alt="" class="ncaa-school-logo" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'">`:''}<span class="ncaa-school-monogram" style="${mark?'display:none':''}">${esc(theme.initials)}</span></div>
     <div class="ncaa-university-hero-copy">
      <div class="eyebrow">${esc(t.division||'NCAA Division I')}</div>
      <h2>${esc(t.name||'Université')}</h2>
      <div class="muted mini">${t.conference?esc(t.conference):'Conférence NCAA'}${location?' · '+esc(location):''}</div>
     </div>
     <span class="pill ncaa-hero-rank">${t.best_ita_rank?'ITA #'+fmt(t.best_ita_rank):'NCAA'}</span>
    </div>
   </section>
   <div class="ncaa-university-summary">
    <p>${esc(t.description||'Programme universitaire NCAA suivi dans Court Boss.')}</p>
    ${t.source_url?`<a class="soft-btn" href="${esc(t.source_url)}" target="_blank" rel="noopener noreferrer">Site tennis officiel ↗</a>`:''}
   </div>
   <div class="ncaa-team-stats ncaa-team-stats-detail">
    <span><b>${fmt(t.roster_count||roster.length)}</b><small>joueurs</small></span>
    <span><b>${t.best_ita_rank?'#'+fmt(t.best_ita_rank):'—'}</b><small>meilleur ITA</small></span>
    <span><b>${fmt(t.official_ranked_count||0)}</b><small>classés ITA</small></span>
    <span><b>${fmt(t.atp_ranked_count||0)}</b><small>classés ATP</small></span>
    <span><b>${t.best_atp_rank?'#'+fmt(t.best_atp_rank):'NR'}</b><small>meilleur ATP</small></span>
   </div>
   <div class="row between" style="margin-top:16px"><div><div class="eyebrow">Roster 2025-26</div><h3 style="margin:3px 0">Effectif masculin</h3></div><span class="muted mini">ATP figé au 01/12/2025</span></div>
   <div class="table-wrap live-rank-table" style="margin-top:10px"><table class="table"><thead><tr><th>ITA / NCAA</th><th>Joueur</th><th>Classe</th><th>Âge</th><th>UTR</th><th>ATP</th><th>Statut</th></tr></thead><tbody>
    ${roster.map(p=>`<tr ${p.id?'class="click" onclick="openPlayer('+p.id+')"':''}><td class="rank-num">${p.ita_rank!=null?'#'+fmt(p.ita_rank):p.projected_rank!=null?'~#'+fmt(p.projected_rank):'—'}</td><td><b>${esc(p.name)}</b><div class="muted micro">${flags[p.country]||'🏳️'} ${esc(p.country||'')}</div></td><td>${esc(p.class_standing||'—')}</td><td>${p.age??'—'}</td><td>${p.utr_rating!=null?'<b>'+(p.utr_verified?'':'~')+Number(p.utr_rating).toFixed(2)+'</b>':'—'}</td><td>${p.atp_rank?'<b>#'+fmt(p.atp_rank)+'</b><div class="muted micro">ATP 01/12/25</div>':'<span class="muted">NR</span><div class="muted micro">non classé ATP</div>'}</td><td><span class="badge ${p.ncaa_current?'good':''}">${esc(p.ncaa_status||'NCAA actif')}</span></td></tr>`).join('')}
   </tbody></table></div>
   ${roster.length?'':'<div class="empty">Aucun joueur trouvé dans ce roster.</div>'}
  </div>`;
 })():`<div>
  <div class="notice mini" style="margin-top:10px"><b>Universités NCAA 2025-26</b> · ${fmt(ncaaUniversitiesMeta?.count||ncaaUniversities.length||0)} programmes du référentiel. Recherche une fac, filtre par conférence, puis ouvre sa fiche avec visuel officiel, description et roster.</div>
  <div class="ncaa-university-filters">
   <select class="select" onchange="setNcaaUniversityConference(this.value)"><option value="">Toutes conférences</option>${universityConferences.map(x=>`<option value="${esc(x)}" ${ncaaUniversityConference===x?'selected':''}>${esc(x)}</option>`).join('')}</select>
   <select class="select" onchange="setNcaaUniversityFilter(this.value)"><option value="all" ${ncaaUniversityFilter==='all'?'selected':''}>Toutes les facs</option><option value="ita" ${ncaaUniversityFilter==='ita'?'selected':''}>Avec joueur ITA</option><option value="atp" ${ncaaUniversityFilter==='atp'?'selected':''}>Avec joueur ATP</option></select>
   <select class="select" onchange="setNcaaUniversitySort(this.value)"><option value="ita" ${ncaaUniversitySort==='ita'?'selected':''}>Tri : meilleur ITA</option><option value="atp" ${ncaaUniversitySort==='atp'?'selected':''}>Tri : meilleur ATP</option><option value="roster" ${ncaaUniversitySort==='roster'?'selected':''}>Tri : effectif</option><option value="name" ${ncaaUniversitySort==='name'?'selected':''}>Tri : A → Z</option></select>
  </div>
  <div class="muted mini ncaa-university-result-count">${fmt(universityRows.length)} université(s) affichée(s)</div>
  <div class="ncaa-university-grid">
   ${universityRows.map(t=>{const theme=universityVisual(t),hero=String(t.hero_image_url||'').trim(),mark=String(t.logo_url||t.favicon_url||'').trim();return `<button class="ncaa-team-card ncaa-team-card-visual" data-school="${esc(t.name)}" onclick="openNcaaUniversity(this.dataset.school)" style="--school-a:${esc(t.primary_color||theme.a)};--school-b:${esc(t.secondary_color||theme.b)}">
    <div class="ncaa-team-card-media" ${hero?`style="background-image:linear-gradient(180deg,rgba(4,12,9,.08),rgba(4,12,9,.72)),url('${esc(hero)}')"`:''}>
     <div class="ncaa-card-logo-wrap">${mark?`<img src="${esc(mark)}" alt="" class="ncaa-card-logo" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'">`:''}<span class="ncaa-card-monogram" style="${mark?'display:none':''}">${esc(theme.initials)}</span></div>
     <span class="badge ${t.best_ita_rank?'good':''}">${t.best_ita_rank?'ITA #'+fmt(t.best_ita_rank):'NCAA'}</span>
    </div>
    <div class="ncaa-team-card-body">
     <div class="eyebrow">${esc(t.conference||t.division||'NCAA DI')}</div>
     <b class="ncaa-team-name">${esc(t.name)}</b>
     <div class="muted micro ncaa-team-desc">${esc(t.description||'Programme NCAA masculin · roster 2025-26')}</div>
     <div class="ncaa-team-stats"><span><b>${fmt(t.roster_count||0)}</b><small>joueurs</small></span><span><b>${t.best_ita_rank?'#'+fmt(t.best_ita_rank):'—'}</b><small>meilleur ITA</small></span><span><b>${t.best_atp_rank?'#'+fmt(t.best_atp_rank):'NR'}</b><small>meilleur ATP</small></span></div>
     <div class="muted micro">${fmt(t.official_ranked_count||0)} ITA · ${fmt(t.atp_ranked_count||0)} ATP · ouvrir la fiche →</div>
    </div>
   </button>`}).join('')}
  </div>
  ${universityRows.length?'':'<div class="empty">Aucune université pour ces filtres.</div>'}
 </div>`;

 return `<div class="section-head"><div><div class="eyebrow">NCAA / ITA</div><h1>Joueurs universitaires</h1><div class="muted">Base NCAA figée au 01/12/2025 : rangs, rosters historiques, alumni et transferts disponibles avant le cutoff.</div></div><span class="pill">${ncaaView==='universities'?fmt(ncaaUniversitiesMeta?.count||ncaaUniversities.length||0)+' universités':fmt(rankCount)+' profils NCAA'}</span></div>
 <div class="tabs rank-tabs">${[['singles','ATP Ranking'],['race','ATP Race'],['doubles','ATP Doubles'],['doubles_race','Race Double'],['nextgen','Next Gen U21'],['junior','ITF Juniors'],['junior_race','Race Junior'],['junior_doubles','Junior Double'],['junior_doubles_race','Race Junior Dbl'],['itf','ITF WTT'],['ncaa','NCAA / ITA']].map(k=>`<button class="${rankKind===k[0]?'active':''}" onclick="setRankKind('${k[0]}')">${k[1]}</button>`).join('')}<button class="deep-db-tab" onclick="dbCircuit='Tous réels';dbOffset=0;dbLoaded=false;nav('players')">Monde ${fmt(worldStats?.worldRankingCapacity||30000)}</button></div>
 ${modeTabs}
 <div class="card">
  <div class="rank-tools fm-rank-tools">${ncaaView==='universities'? `<div class="muted mini">Utilise la recherche NCAA juste au-dessus pour filtrer les universités.</div>`: `<input class="input" value="${esc(rankQuery)}" placeholder="${ncaaView==='doubles'?'Rechercher un joueur de double…':'Rechercher un joueur NCAA…'}" onkeydown="if(event.key==='Enter')searchRanking(this.value)">${ncaaView==='singles'? `<select class="select" onchange="setRankCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${rankCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.ncaa_players||0)} NCAA</option>`).join('')}</select><div class="rank-jump"><input class="input" id="rankJump" type="number" min="1" max="${Math.max(rankCount,1)}" placeholder="Aller au rang"><button class="soft-btn" onclick="jumpRanking()">Aller</button></div>`:''}`}</div>
  ${ncaaView==='doubles'?doublesTable:ncaaView==='universities'?universitiesTable:singlesTable}
 </div>`;
}
window.setNcaaView=async v=>{
 ncaaView=v==='doubles'?'doubles':v==='universities'?'universities':'singles';
 rankOffset=0;
 if(ncaaView!=='universities')ncaaUniversityDetail=null;
 if(ncaaView==='universities'&&!ncaaUniversities.length)await loadNcaaUniversities();
 render()
}
async function loadNcaaUniversities(){
 if(ncaaUniversityLoading)return;
 ncaaUniversityLoading=true;
 try{
  const d=await get('/api/ncaa-universities');
  ncaaUniversities=d.rows||[];ncaaUniversitiesMeta=d;
 }finally{ncaaUniversityLoading=false}
}
window.openNcaaUniversity=async school=>{
 ncaaUniversityLoading=true;
 try{
  ncaaUniversityDetail=await get('/api/ncaa-universities?school='+encodeURIComponent(String(school||'')));
  const meta=ncaaUniversityDetail?.university||{};
  const i=ncaaUniversities.findIndex(x=>String(x.name||'')===String(school||''));
  if(i>=0)ncaaUniversities[i]={...ncaaUniversities[i],...meta,name:ncaaUniversities[i].name||meta.name};
 }catch(e){ncaaUniversityDetail={university:{name:String(school||'Université NCAA')},rows:[],error:e.message}}
 finally{ncaaUniversityLoading=false;render();window.scrollTo(0,0)}
}
window.closeNcaaUniversity=()=>{ncaaUniversityDetail=null;render()}
window.setNcaaUniversityQuery=v=>{ncaaUniversityQuery=v||'';ncaaUniversityDetail=null;render()}
window.openNcaaUniversityHub=async()=>{
 ncaaView='universities';ncaaUniversityDetail=null;rankOffset=0;
 if(!ncaaUniversities.length)await loadNcaaUniversities();
 render();setTimeout(()=>document.querySelector('.ncaa-university-grid')?.scrollIntoView({behavior:'smooth',block:'start'}),20)
}
window.quickNcaaUniversitySearch=async v=>{
 ncaaUniversityQuery=v||'';ncaaView='universities';ncaaUniversityDetail=null;rankOffset=0;
 if(!ncaaUniversities.length)await loadNcaaUniversities();
 render()
}
window.setNcaaUniversityConference=v=>{ncaaUniversityConference=v||'';ncaaUniversityDetail=null;render()}
window.setNcaaUniversityFilter=v=>{ncaaUniversityFilter=v||'all';ncaaUniversityDetail=null;render()}
window.setNcaaUniversitySort=v=>{ncaaUniversitySort=v||'ita';ncaaUniversityDetail=null;render()}
window.setRankKind=async k=>{rankKind=k;rankOffset=0;rankQuery='';await loadRankings();render()}
window.setNextGenAge=async a=>{nextGenAge=clamp(Number(a)||21,18,21);rankOffset=0;rankQuery='';await loadRankings();render()}
window.searchRanking=async q=>{rankQuery=q.trim();rankOffset=0;await loadRankings();render()}
window.setRankCountry=async c=>{rankCountry=String(c||'').toUpperCase();rankOffset=0;await loadRankings();render()}
window.rankPage=async d=>{rankOffset=Math.max(0,rankOffset+d*rankPageSize());await loadRankings();render();window.scrollTo(0,0)}
window.jumpRank=async()=>{const n=clamp(Number(document.getElementById('rankJump')?.value||1),1,Math.max(1,rankCount));rankOffset=Math.floor((n-1)/rankPageSize())*rankPageSize();await loadRankings();render();window.scrollTo(0,0)}

function calWeekStart(date){
 const d=new Date(String(date||"2025-12-01")+"T12:00:00"),day=(d.getDay()+6)%7;
 d.setDate(d.getDate()-day);return d.toISOString().slice(0,10);
}
function calWeekEnd(date){const d=new Date(calWeekStart(date)+"T12:00:00");d.setDate(d.getDate()+6);return d.toISOString().slice(0,10)}
function calGameWeek(date){return Math.floor((new Date(calWeekStart(date)+"T12:00:00")-new Date("2025-12-01T12:00:00"))/604800000)+1}
function calShortDate(date){return new Date(String(date)+"T12:00:00").toLocaleDateString("fr-FR",{day:"2-digit",month:"short"}).replace(".","")}
function activeDoublesPartner(){
 const playerId=activeManagedId(),primaryId=primaryManagedPlayerId();
 const rows=management?.partnerships||[];
 const own=rows.find(x=>Number(x.player_a_id)===playerId||Number(x.player_b_id)===playerId);
 if(own){
  const pa=Array.isArray(own.player_a)?own.player_a[0]:own.player_a;
  const pb=Array.isArray(own.player_b)?own.player_b[0]:own.player_b;
  return Number(own.player_a_id)===playerId?(pb||own.partner||null):(pa||null);
 }
 if(playerId!==primaryId)return null;
 const fallback=rows.map(x=>x.partner||x.player_b).find(p=>Number(p?.id)===Number(local.partnerId))
   ||rows.map(x=>x.partner||x.player_b).find(Boolean);
 return fallback||doublesHubRows.find(p=>Number(p.id)===Number(local.partnerId))||null;
}
function tournamentStatus(t){
 const now=String(local.date||"2025-12-01"),start=String(t.start_date||""),end=String(t.end_date||t.start_date||""),deadline=String(t.singles_entry_deadline||t.deadline||"");
 if(end&&end<now)return {label:"Terminé",cls:""};
 if(start&&start<=now&&end>=now)return {label:"En cours",cls:"good"};
 if(deadline&&now>deadline&&now<start)return {label:"Inscriptions closes",cls:"bad"};
 if(deadline&&now<=deadline)return {label:"Inscriptions ouvertes",cls:"good"};
 return {label:"À venir",cls:"warn"};
}
function tmCuts(t){return {direct:Number(t.direct_cut??t.projected_direct_cut??0)||null,qual:Number(t.qual_cut??t.projected_qual_cut??0)||null,projected:t.direct_cut==null&&t.projected_direct_cut!=null}}
function tournamentEntryContext(c=activePlayerCareerView()){return [c.managed_player_id,local.date,c.singles_rank,c.career_focus,c.injury_status].join('|')}
function tournamentEntryRestriction(t,c,method){
 const official=t.entry_rule_context===tournamentEntryContext(c)?t.managed_entry_rules?.[method]:null;
 if(official)return official.eligible?null:official.reason;
 const rank=Number(c.singles_rank||999999),cat=String(t.category||'');
 if(t.circuit==='ITF'&&['M15','M25'].includes(cat)&&rank<=200)return 'itf_play_down_top200';
 if(t.circuit==='ATP'&&['ATP 250','ATP 500','Masters 1000'].includes(cat)&&rank>500&&['direct','qualifying'].includes(method))return 'atp_advanced_entry_top500_required';
 if(t.circuit!=='Challenger')return null;
 if(['Challenger 175','Challenger 125'].includes(cat)&&method==='direct'&&rank>500)return 'challenger_175_125_direct_top500_required';
 if(cat==='Challenger 50'){
  if(rank<=50)return 'ch50_top50_prohibited';
  if(rank<=150&&method!=='wildcard')return 'ch50_top150_no_direct_or_qualifying';
  if(rank<=100&&c.country!==t.country)return 'ch50_wc_51_100_home_nation_only';
 }
 if(['Challenger 75','Challenger 100','Challenger 125'].includes(cat)){
  if(rank<=10)return 'challenger_top10_prohibited';
  if(rank<=50&&cat==='Challenger 75')return 'ch75_11_50_prohibited';
  if(rank<=50&&method!=='wildcard')return 'challenger_11_50_wildcard_only';
 }
 return null;
}
function tournamentEntryReason(reason){
 const labels={itf_play_down_top200:'M15/M25 interdits au Top 200 ATP',ch50_top50_prohibited:'Challenger 50 interdit au Top 50',ch50_top150_no_direct_or_qualifying:'Challenger 50 : wild card obligatoire pour le Top 150',ch50_wc_51_100_home_nation_only:'Wild card réservée à la nation hôte pour les rangs 51–100',challenger_top10_prohibited:'Challenger 75–125 interdit au Top 10',ch75_11_50_prohibited:'Challenger 75 interdit au Top 50',challenger_11_50_wildcard_only:'Wild card obligatoire pour les rangs 11–50',atp_advanced_entry_top500_required:'ATP : Top 500 requis pour l’entrée avancée',challenger_175_125_direct_top500_required:'Challenger 125/175 : Top 500 requis en entrée directe',inactive_player:'Joueur inactif',injured:'Joueur blessé',doubles_only:'Double exclusivement',no_active_entry_protection:'Aucun classement protégé actif'};
 return labels[reason]||'Entrée non autorisée par le règlement';
}
function tournamentParticipationWindow(t,elig={},discipline='singles'){
 const qualifying=discipline==='singles'
  ?(
    ['qualifying','protected_qualifying','alternate'].includes(elig.method)
    ||String(elig.method||'').endsWith('_qualifying')
   )
  :(
    Boolean(elig.requiresQualifying)
    ||String(elig.phase||'')==='qualifying'
    ||['qualifying','protected_qualifying','qualifier','protected_qualifier'].includes(String(elig.method||''))
   );
 const deadline=discipline==='doubles'
  ?(qualifying?(t.doubles_entry_deadline||t.qualifying_entry_deadline):t.doubles_entry_deadline)
  :(qualifying?t.qualifying_entry_deadline:null)||t.singles_entry_deadline||t.main_entry_deadline||t.deadline;
 return {start_date:(qualifying?t.qualifying_start_date:null)||t.main_draw_start_date||t.start_date,end_date:t.end_date||t.start_date,deadline};
}
function existingEntryWindow(id,e,discipline='singles'){
 if(e.entry_start_date)return {start_date:e.entry_start_date,end_date:e.end_date};
 const t=findTournamentById(id)||e;
 const method=e.entry_method||(/qualif|alternate/i.test(e.status||'')?'qualifying':'direct');
 return tournamentParticipationWindow(t,{method},discipline);
}
function specialTeamEventMeta(t){
 const code=String(t?.entry_rule_code||''),category=String(t?.category||'');
 if(code==='UNITED_CUP_TEAM'||/United Cup/i.test(category))return {code:'united_cup',label:'Sélection nationale mixte',teams:18,format:'6 groupes de 3 · 8 équipes en quarts · demi-finales et finale',tie:'1 simple ATP · 1 simple WTA · 1 double mixte',selection:'Qualification du pays + sélection nationale'};
 if(code==='LAVER_CUP_INVITE'||/Laver Cup/i.test(category))return {code:'laver_cup',label:'Invitation / sélection',teams:2,format:'Team Europe vs Team World · premier à 13 points',tie:'12 matches maximum sur 3 jours',scoring:'1 pt vendredi · 2 samedi · 3 dimanche',selection:'Qualification et choix des capitaines'};
 if(code==='JUNIOR_DAVIS_SELECTION'||/Junior Davis Cup/i.test(category))return {code:'junior_davis',label:'Sélection nationale junior',teams:16,format:'4 groupes de 4 · round robin · repos · phase finale',tie:'Rencontres par équipes nationales juniors',selection:'Qualifications régionales + sélection fédérale'};
 return null;
}
function laverCaptainPanel(teamEvent){
 const ctx=teamEvent?.captain_context||null;
 const caps=ctx?.captains||{};
 if(!ctx?.ok||(!caps.europe&&!caps.world))return '';
 const one=(x,label,cls)=>{
  if(!x?.captain)return '';
  const p=x.captain||{},record=x.record||{};
  const photo=String(p.photo_url||'').trim();
  const initials=String(p.name||'?').split(/\s+/).map(v=>v[0]||'').slice(0,2).join('').toUpperCase();
  return `<button class="laver-captain-card ${cls}" onclick="openPlayer(${Number(p.id||0)})">
   <div class="laver-captain-team">${esc(label)}</div>
   <div class="laver-captain-main">
    <div class="laver-captain-photo">${photo?`<img src="${esc(photo)}" alt="${esc(p.name||'Capitaine')}" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'">`:''}<span style="${photo?'display:none':''}">${esc(initials)}</span></div>
    <div class="laver-captain-copy">
     <small>Capitaine · légende retraitée</small>
     <b>${esc(p.name||'—')}</b>
     <span>${flags[p.country]||'🏳️'} ${esc(p.country||'')} · meilleur rang ${p.career_high_rank?'#'+fmt(p.career_high_rank):'—'}</span>
    </div>
   </div>
   <div class="laver-captain-meta">
    <span><small>Style</small><b>${esc(x.style_label||'Leadership')}</b></span>
    <span><small>Mandat</small><b>${fmt(x.term_start_season)}–${fmt(x.term_end_season)}</b></span>
    <span><small>Bilan</small><b>${fmt(record.wins||0)} titre(s) / ${fmt(record.editions||0)} édition(s)</b></span>
   </div>
  </button>`;
 };
 return `<section class="laver-captain-panel">
  <div class="row between laver-captain-head">
   <div><div class="eyebrow">Bancs Laver Cup</div><h2>Les capitaines</h2></div>
   <span class="badge">Mandats de ${fmt(ctx.rotation_years||3)} ans · ${fmt(ctx.term_start)}–${fmt(ctx.term_end)}</span>
  </div>
  <div class="laver-captain-grid">
   ${one(caps.europe,'TEAM EUROPE','is-europe')}
   ${one(caps.world,'TEAM WORLD','is-world')}
  </div>
  <div class="muted mini laver-captain-rule">À chaque nouveau mandat, Court Boss choisit une autre légende retraitée de la région. Les stars de ta carrière peuvent donc devenir capitaines après leur retraite.</div>
 </section>`;
}

function singlesEligibility(t){
 const c=activePlayerCareerView(),rank=Number(c.singles_rank||99999),age=Number(c.age||99),cuts=tmCuts(t);
 const now=String(local.date||c.career_date||'2025-12-01');
 const mainDeadline=String(t.main_entry_deadline||t.singles_entry_deadline||'');
 const qualDeadline=String(t.qualifying_entry_deadline||'');
 const qualSignin=String(t.qualifying_signin_date||t.qualifying_start_date||'');
 const lateDeadline=String(t.late_entry_deadline||'');
 const mainClosed=Boolean(mainDeadline&&now>mainDeadline);
 const qualClosed=Boolean(qualDeadline&&now>qualDeadline);
 const lateWindow=Number(t.late_entry_slots||0)>0&&mainClosed&&lateDeadline&&now<=lateDeadline;
 if(String(c.career_focus||'mixed')==='doubles_only')return {label:"Double exclusivement",cls:"bad",can:false,phase:"career_focus"};
 const teamEvent=specialTeamEventMeta(t);
 if(teamEvent)return {label:teamEvent.label,cls:"info",can:false,phase:"team_selection",teamEvent};
 const isNextGenFinals=String(t?.entry_rule_code||'')==='NEXTGEN_FINALS_2026'||(String(t?.circuit||'')==='ATP'&&/Next Gen Finals/i.test(String(t?.category||'')));
 if(isNextGenFinals){
  const ng=t?.nextgen_finals_status||c.nextgen_finals_status||null;
  if(ng?.selected===true&&String(ng.status||'')==='accepted'){
   return {label:'Sélectionné Next Gen · ATP #'+fmt(ng.atp_rank||rank),method:'selection',cls:'good',can:true,phase:'finals',finals:true};
  }
  if(ng?.selected===true&&String(ng.status||'')==='pending'){
   return {label:'Invitation Next Gen · réponse attendue',method:'selection',cls:'warn',can:false,phase:'finals_selection',canWildcard:false,finals:true};
  }
  if(ng&&ng.eligible_age===false){
   return {label:'Non éligible U21',method:'selection',cls:'bad',can:false,phase:'finals_selection',canWildcard:false,finals:true};
  }
  return {label:'Sélection Next Gen · Top 8 U21 ATP',method:'selection',cls:'info',can:false,phase:'finals_selection',canWildcard:false,finals:true};
 }
 if(String(t.circuit)==="Federation")return {label:"Sélection nationale",cls:"info",can:false};
 if(String(t.circuit)==="NCAA"){
  const mode=String(t.registration_mode||"");
  const label=mode==="ncaa_individual_selection"?"Qualifié NCAA/ITA"
    :mode==="conference_selection"?"Sélection conférence"
    :mode==="school_nomination"?"Nomination université / ITA"
    :mode==="school_selection"?"Roster / lineup université"
    :"Parcours NCAA/ITA";
  return {label,cls:"info",can:false};
 }
 if(String(t.circuit)==="Junior"){
  if(age>18)return {label:"Non éligible U18",cls:"bad",can:false};
  const jr=Number(c.junior_rank||c.junior_ranking||99999);
  if(mainClosed){
    if(cuts.qual&&jr<=cuts.qual&&!qualClosed)return {label:"Qualifs junior",method:"qualifying",cls:"warn",can:true};
    return {label:"Inscriptions juniors closes",method:"closed",cls:"bad",can:false,canWildcard:false};
  }
  if(cuts.direct&&jr<=cuts.direct)return {label:"Tableau direct junior",method:"direct",cls:"good",can:true};
  if(cuts.qual&&jr<=cuts.qual){
    if(qualClosed)return {label:"Qualifs juniors closes",method:"closed",cls:"bad",can:false,canWildcard:false};
    return {label:"Qualifs junior",method:"qualifying",cls:"warn",can:true};
  }
  return {label:"Hors cut junior · wild card requise",method:"alternate",cls:"bad",can:false,canWildcard:!mainClosed};
 }
 if(t.singles===false)return {label:'Pas de simple',can:false,cls:'bad'};

 // Once the real acceptance lists exist, they are the source of truth in the
 // calendar too. Projection logic below is only for tournaments not frozen yet.
 const actualMain=t.managed_acceptance_main||null;
 const actualQ=t.managed_acceptance_qualifying||null;
 const mainActive=actualMain&&['accepted','promoted'].includes(String(actualMain.status||''));
 const qActive=actualQ&&['accepted','promoted'].includes(String(actualQ.status||''));
 if(mainActive){
  return {
   label:String(actualMain.status)==='promoted'?'ALT → tableau principal':'Tableau principal · accepté',
   method:'direct',phase:'main',cls:'good',can:true,frozen:true,acceptance:actualMain
  };
 }
 if(qActive){
  return {
   label:'Qualifications · accepté'+(actualMain?.status==='alternate'?' · ALT MD #'+fmt(actualMain.acceptance_order):''),
   method:'qualifying',phase:'qualifying',cls:'warn',can:true,frozen:true,acceptance:actualQ
  };
 }
 if(actualQ?.status==='alternate'){
  return {
   label:'ALT Q #'+fmt(actualQ.acceptance_order)+(actualMain?.status==='alternate'?' · ALT MD #'+fmt(actualMain.acceptance_order):''),
   method:'alternate',phase:'qualifying_alternate',cls:'warn',can:true,frozen:true,acceptance:actualQ
  };
 }
 if(actualMain?.status==='alternate'){
  return {
   label:'ALT tableau #'+fmt(actualMain.acceptance_order),
   method:'alternate',phase:'main_alternate',cls:'warn',can:true,frozen:true,acceptance:actualMain
  };
 }
 if(actualMain?.status==='withdrawn'||actualQ?.status==='withdrawn'){
  const withdrawn=actualMain?.status==='withdrawn'?actualMain:actualQ;
  return {
   label:'Retiré de la liste figée',method:'withdrawn',phase:'withdrawn',
   cls:'bad',can:false,frozen:true,acceptance:withdrawn
  };
 }

 const authoritative=t.entry_rule_context===tournamentEntryContext(c);
 const rules=authoritative?(t.managed_entry_rules||{}):{};
 const prDirect=rules.protected||null;
 const prQual=rules.protected_qualifying||null;
 const prInfo=prDirect?.protected_ranking||prQual?.protected_ranking||null;
 const protectedRank=Number(prDirect?.ranking||prQual?.ranking||prInfo?.protected_rank||0);
 const protectedAvailable=Boolean(prInfo?.available)&&protectedRank>0&&protectedRank<rank;

 let method=authoritative&&t.managed_wildcard_status==='accepted'
   ?'wildcard'
   :cuts.direct&&rank<=cuts.direct?'direct'
   :cuts.qual&&rank<=cuts.qual?'qualifying'
   :'alternate';

 if(method!=='wildcard'&&protectedAvailable){
  if(!mainClosed&&cuts.direct&&rank>cuts.direct&&prDirect?.eligible!==false&&protectedRank<=cuts.direct){
    method='protected';
  }else if(!qualClosed&&cuts.qual&&rank>cuts.qual&&prQual?.eligible!==false&&protectedRank<=cuts.qual){
    method='protected_qualifying';
  }
 }

 if(lateWindow&&cuts.direct&&rank<cuts.direct){
  const leReason=tournamentEntryRestriction(t,c,'direct');
  if(!leReason){
    return {
      label:'Late Entry'+(lateDeadline?' · '+df(lateDeadline):''),
      method:'late_entry',cls:'good',can:true,phase:'late_entry',
      late_entry_deadline:lateDeadline
    };
  }
 }

 if(mainClosed&&(method==='direct'||method==='protected')){
  if(method==='protected'&&cuts.qual&&protectedRank<=cuts.qual&&!qualClosed&&prQual?.eligible!==false){
    method='protected_qualifying';
  }else if(method==='direct'&&cuts.qual&&rank<=cuts.qual&&!qualClosed){
    method='qualifying';
  }else if(method!=='wildcard'){
    return {
      label:'Entry list close'+(lateDeadline&&Number(t.late_entry_slots||0)>0?' · LE jusqu’au '+df(lateDeadline):''),
      method:'closed',cls:'bad',can:false,phase:'closed',
      canWildcard:!tournamentEntryRestriction(t,c,'wildcard')
    };
  }
 }

 if((method==='qualifying'||method==='protected_qualifying')&&qualClosed){
  return {
    label:'Qualifs closes'+(qualSignin?' · sign-in '+df(qualSignin):''),
    method:'closed',cls:'bad',can:false,phase:'closed',
    canWildcard:!tournamentEntryRestriction(t,c,'wildcard')
  };
 }

 let reason=tournamentEntryRestriction(t,c,method==='late_entry'?'direct':method);
 if(reason==='challenger_175_125_direct_top500_required'&&cuts.qual&&rank<=cuts.qual&&!qualClosed){
  method='qualifying';
  reason=tournamentEntryRestriction(t,c,method);
 }
 if(reason)return {label:tournamentEntryReason(reason),reason,method,cls:'bad',can:false,canWildcard:!tournamentEntryRestriction(t,c,'wildcard')};
 if(method==='wildcard')return {label:'Wild Card accordée',method,cls:'good',can:true};
 if(method==='protected'){
  return {label:'Classement protégé #'+fmt(protectedRank)+' · tableau direct',method,cls:'good',can:true,protectedRanking:prInfo,protectedRank};
 }
 if(method==='protected_qualifying'){
  return {label:'Classement protégé #'+fmt(protectedRank)+' · qualifications',method,cls:'warn',can:true,protectedRanking:prInfo,protectedRank};
 }
 if(method==='direct')return {label:'Tableau direct',method,cls:'good',can:true};
 if(method==='qualifying')return {label:'Qualifications'+(qualDeadline?' · deadline '+df(qualDeadline):''),method,cls:'warn',can:true};
 return {label:t.circuit==='ITF'?'Alternate / WTN':'Alternate / hors cut',method,cls:'warn',can:true};
}

function applyManagedPathwayEligibility(t,rule){
 const p=t?.managed_pathway_status;
 if(!p||p.eligible!==true)return rule;
 const mode=String(p.mode||'');
 if(!mode)return rule;
 if(rule?.can&&mode!=='late_entry')return rule;
 const qualifying=mode.endsWith('_qualifying');
 return {
  ...rule,
  label:String(p.label||mode.replaceAll('_',' ')),
  method:mode,
  phase:qualifying?'qualifying':'main',
  cls:qualifying?'warn':'good',
  can:true,
  canWildcard:false,
  pathway:true,
  pathwayDetails:p
 };
}
function tournamentPathwayReasonLabel(reason){
 const labels={
  no_pathway:'Aucune passerelle spéciale active',
  regular_entry_still_open:'Inscriptions normales encore ouvertes',
  no_late_entry_slot:'Aucune place Late Entry',
  ranking_not_better_than_original_cut:'Classement insuffisant par rapport au cut original',
  no_special_exempt_slots:'Aucune place Special Exempt',
  no_qualified_previous_event:'Pas de résultat qualificatif la semaine précédente',
  already_direct_acceptance:'Déjà admis directement',
  no_performance_bye_rule:'Pas de règle Performance Bye sur cette épreuve',
  not_source_event_finalist:'Résultat requis dans le tournoi source non atteint',
  not_accepted_main_draw:'Pas admis au tableau principal',
  would_be_top16_seed:'Déjà dans la zone des 16 premières têtes de série',
  source_event_finalist_outside_top16_seeds:'Performance Bye disponible',
  still_competing_previous_week:'Special Exempt disponible'
 };
 return labels[String(reason||'')]||String(reason||'Statut réglementaire');
}
function managedRegulatoryPathwaysHtml(t,fr){
 const pathway=t?.managed_pathway_status||null;
 const se=t?.managed_special_exempt_status||null;
 const pb=t?.managed_performance_bye_status||null;
 const rows=[];
 const seSlots=Math.max(0,Number(fr?.special_exempt_slots||0));
 const pbSlots=Math.max(0,Number(t?.performance_bye_slots||0));
 if(se&&(se.eligible===true||seSlots>0)){
  const info=se.eligible===true
   ?('Disponible'+(se.source_tournament?' · via '+se.source_tournament:'')+(se.source_result?' ('+se.source_result+')':''))
   :tournamentPathwayReasonLabel(se.reason);
  rows.push('<div class="list-item row between"><div><b>Special Exempt</b><div class="muted micro">'+esc(info)+'</div></div><span class="badge '+(se.eligible===true?'good':'')+'">'+(se.eligible===true?'Éligible':fmt(seSlots)+' place(s)')+'</span></div>');
 }
 if(pb&&(pb.eligible===true||pbSlots>0)){
  const info=pb.eligible===true
   ?('Bye au 1er tour'+(pb.source_event?' · source '+pb.source_event:''))
   :tournamentPathwayReasonLabel(pb.reason);
  rows.push('<div class="list-item row between"><div><b>Performance Bye</b><div class="muted micro">'+esc(info)+'</div></div><span class="badge '+(pb.eligible===true?'good':'')+'">'+(pb.eligible===true?'Éligible':fmt(pbSlots)+' place(s)')+'</span></div>');
 }
 if(pathway?.eligible===true&&String(pathway.mode||'')!=='special_exempt'){
  rows.push('<div class="list-item row between"><div><b>Passerelle active</b><div class="muted micro">'+esc(pathway.label||String(pathway.mode||'').replaceAll('_',' '))+'</div></div><span class="badge good">'+esc(String(pathway.mode||'').toUpperCase())+'</span></div>');
 }
 return rows.length?'<div style="margin-top:10px"><div class="eyebrow">Passerelles réglementaires</div>'+rows.join('')+'</div>':'';
}

function doublesEligibility(t){
 const partner=activeDoublesPartner(),c=activePlayerCareerView(),myRank=Number(c.doubles_rank||99999),partnerRank=Number(partner?.doubles_ranking||99999);
 const server=t?.managed_doubles_entry_status;
 if(server){
   return {
     label:server.label||"Statut double",cls:server.projected_acceptance===false?"bad":server.phase==="onsite"?"warn":"good",
     can:server.can_schedule!==false,phase:server.phase||"server",projectedAcceptance:server.projected_acceptance,
     projectedCut:server.projected_cut,bestCombinedRank:server.best_combined_rank,composition:server.composition,
     requiresQualifying:Boolean(server.requires_qualifying),qualifyingCut:server.qualifying_cut,
     qualifyingEntryMethod:server.qualifying_entry_method||null,
     qualifyingWildcardCandidate:Boolean(server.qualifying_wildcard_candidate),
     protectedRanking:server.protected_ranking||null,protectedCombinedRank:server.protected_combined_rank,
     useProtectedRanking:Boolean(server.use_protected_ranking)
   };
 }
 const now=String(local.date||"2025-12-01"),advance=String(t.doubles_entry_deadline||""),onsite=String(t.doubles_onsite_deadline||"");
 if(String(c.career_focus||'mixed')==='singles_only')return {label:"Simple exclusivement",cls:"bad",can:false,phase:"career_focus"};
 const teamEvent=specialTeamEventMeta(t);
 if(teamEvent)return {label:teamEvent.label,cls:"info",can:false,phase:"team_selection",teamEvent};
 if(!t.doubles)return {label:"Pas de double",cls:"",can:false,phase:"none"};
 if(String(t.circuit)==="NCAA")return {label:"Via lineup NCAA",cls:"info",can:false,phase:"selection"};
 if(String(t.circuit)==="Federation")return {label:"Par sélection",cls:"info",can:false,phase:"selection"};
 if(!partner)return {label:"Partenaire requis",cls:"warn",can:false,phase:"partner"};
 if(onsite&&now>onsite)return {label:"Double clos",cls:"bad",can:false,phase:"closed"};
 const method=String(t.doubles_entry_method||"");
 if(method==="onsite_only")return {label:"Sign-in sur site"+(onsite?" · "+df(onsite):""),cls:"warn",can:true,phase:"onsite"};
 if(advance&&now>advance&&(!onsite||now<=onsite))return {label:"On-site sign-in"+(onsite?" · "+df(onsite):""),cls:"warn",can:true,phase:"onsite"};
 if(String(t.entry_rule_code)==="ITF_M25"&&(myRank>=99999||partnerRank>=99999))return {label:"Sur site uniquement"+(onsite?" · "+df(onsite):""),cls:"warn",can:true,phase:"onsite"};
 const combined=(myRank>=99999||partnerRank>=99999)?null:myRank+partnerRank;
 return {label:(method.includes("advance")?"Advance entry · ":"")+(combined?"rang combiné "+fmt(combined):"équipe enregistrable"),cls:"good",can:true,phase:"advance"};
}
const MAJOR_TOURNAMENT_LOGOS=[
 {re:/Australian Open/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Australian_Open_Logo_2017.svg",label:"AO",cls:"logo-ao"},
 {re:/Roland[ -]?Garros/i,url:"https://static.cdnlogo.com/logos/r/52/roland-garros.svg",label:"RG",cls:"logo-rg"},
 {re:/Wimbledon/i,url:"https://static.cdnlogo.com/logos/w/73/wimbledon.svg",label:"WIM",cls:"logo-wim"},
 {re:/\bUS Open\b/i,url:"https://upload.wikimedia.org/wikipedia/commons/2/26/Usopen-header-logo.svg",label:"USO",cls:"logo-uso"}
];
const CURATED_TOURNAMENT_LOGOS=[
 {re:/Millennium Estoril Open|Estoril Open/i,url:"https://assets.stickpng.com/images/635644eea54eeda751217031.png",label:"EST"},
 {re:/Mifel Tennis Open|Los Cabos/i,url:"https://assets.stickpng.com/images/63565dd1636d1187068bf55b.png",label:"LCB"},
 {re:/Winston-Salem Open/i,url:"https://assets.stickpng.com/images/626698e22c88722059d5870e.png",label:"WSO"},
 {re:/Plava Laguna Croatia Open Umag|Croatia Open|Umag/i,url:"https://assets.stickpng.com/images/62665b7d1e92f9aac65b5bca.png",label:"UMAG"},
 {re:/BNP Paribas Fortis European Open|European Open/i,url:"https://assets.stickpng.com/images/635659ed636d1187068beaf7.png",label:"EURO"},
 // Current identities for which a clean transparent current asset is not
 // reliably available: render a tournament-specific dark wordmark instead of
 // an inaccurate old logo or a generic ATP 250 tile.
 {re:/BOSS Open/i,url:null,label:"BOSS OPEN"},
 {re:/Lynk & Co Hangzhou Open|Hangzhou Open/i,url:null,label:"HANGZHOU"},
 {re:/Grand Prix Auvergne-Rhone-Alpes|Grand Prix Auvergne-Rhône-Alpes/i,url:null,label:"GP AURA"},
 {re:/Almaty Open/i,url:null,label:"ALMATY"},
 {re:/Bank of China Hong Kong Tennis Open|Hong Kong Tennis Open/i,url:"https://static.hkmenstennisopen.com/wp-content/themes/hkto_2023/template/frontend/images/overview/2025/boc_hkto_logo_long.svg",label:"HKG"},
 {re:/Open Occitanie|Open Sud de France/i,url:"https://trouverlogo.fr/logos/open-occitanie.svg",label:"OCC"},
 {re:/ABN AMRO Open|ABN Amro World Tennis Tournament/i,url:"https://assets.stickpng.com/images/62ba413db3914fd78a171683.png",label:"RTM"},
 {re:/Abierto Mexicano Telcel|Abierto Mexicano de Tenis|Acapulco/i,url:"https://assets.stickpng.com/images/6266539d1e92f9aac65b5b98.png",label:"ACA"},
 {re:/Fayez Sarofim|U\\.S\\. Men'?s Clay Court|Houston/i,url:"https://assets.stickpng.com/images/626696c52c88722059d58707.png",label:"HOU"},
 {re:/Grand Prix Hassan II/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Grand_Prix_Hassan_II_logo.png",label:"MAR"},
 {re:/Tiriac Open|Țiriac Open/i,url:"https://commons.wikimedia.org/wiki/Special:Redirect/file/Tiriac_Open.png",label:"BUC"},
 {re:/BNP Paribas Open|Indian Wells/i,url:"https://assets.stickpng.com/images/626658031e92f9aac65b5bb3.png",label:"IW"},
 {re:/Nexo Dallas Open|Dallas Open/i,url:"https://assets.stickpng.com/images/62665b9e1e92f9aac65b5bcb.png",label:"DAL"},
 {re:/Delray Beach Open/i,url:"https://assets.stickpng.com/images/62665c261e92f9aac65b5bd0.png",label:"DBO"},
 {re:/Dubai Duty Free Tennis Championships|Dubai Tennis Championships/i,url:"https://assets.stickpng.com/images/62665ca61e92f9aac65b5bd4.png",label:"DUB"},
 {re:/Bci Seguros Chile Open|Chile Open/i,url:"https://assets.stickpng.com/images/6266595e1e92f9aac65b5bbb.png",label:"CHI"},
 {re:/Gonet Geneva Open|Geneva Open/i,url:"https://assets.stickpng.com/images/62665d641e92f9aac65b5bd9.png",label:"GVA"},
 {re:/Bitpanda Hamburg Open|Hamburg (?:European )?Open/i,url:"https://assets.stickpng.com/images/62665eb81e92f9aac65b5bdd.png",label:"HAM"},
 {re:/Libema Open|Libéma Open/i,url:"https://assets.stickpng.com/images/62668a2f2c88722059d586d2.png",label:"LIB"},
 {re:/Mallorca Championships/i,url:"https://assets.stickpng.com/images/62668bb32c88722059d586da.png",label:"MAL"},
 {re:/EFG Swiss Open Gstaad|Swiss Open Gstaad/i,url:"https://assets.stickpng.com/images/626693472c88722059d586fb.png",label:"GST"},
 {re:/Nordea Open|B[aå]stad/i,url:"https://assets.stickpng.com/images/62668e752c88722059d586e7.png",label:"NOR"},
 {re:/Qatar ExxonMobil Open|Qatar Open/i,url:"https://assets.stickpng.com/images/6266906e2c88722059d586ee.png",label:"DOH"},
 {re:/Rio Open/i,url:"https://assets.stickpng.com/images/626691042c88722059d586f1.png",label:"RIO"},
 {re:/National Bank Open|Canada Masters|Toronto Masters|Montreal Masters/i,url:"https://assets.stickpng.com/images/62668e322c88722059d586e5.png",label:"CAN"},
 {re:/Cincinnati Open|Western & Southern Open/i,url:"https://en.wikipedia.org/wiki/Special:Redirect/file/Cincinnati_Open_logo.svg",label:"CIN"},
 {re:/Mubadala Citi DC Open|Citi DC Open|Citi Open|Washington Open/i,url:"https://assets.stickpng.com/images/62665a531e92f9aac65b5bc2.png",label:"WAS"},
 {re:/Kinoshita Group Japan Open|Japan Open|Tokyo Open/i,url:"https://assets.stickpng.com/images/626688682c88722059d586c7.png",label:"TOK"},
 {re:/Rolex Shanghai Masters|Shanghai Masters/i,url:"https://assets.stickpng.com/images/626692962c88722059d586f6.png",label:"SHA"},
 {re:/Rolex Paris Masters|Paris Masters/i,url:"https://assets.stickpng.com/images/626691792c88722059d586f4.png",label:"PAR"},
 {re:/Chengdu Open/i,url:"https://assets.stickpng.com/images/6356d0b733e1449e66ee5a2e.png",label:"CHE"},
 {re:/BNP Paribas Nordic Open|Stockholm Open/i,url:"https://assets.stickpng.com/images/6356fa1633e1449e66ee9f4c.png",label:"STO"},
 {re:/Kitzb[uü]hel|Generali Open/i,url:"https://assets.stickpng.com/images/626688b02c88722059d586c9.png",label:"KIT"},
 {re:/Barcelona Open Banc Sabadell|Barcelona Open/i,url:"https://assets.stickpng.com/images/63566131636d1187068c0368.png",label:"BCN"},
 {re:/BMW Open/i,url:"https://assets.stickpng.com/images/626657a81e92f9aac65b5bb0.png",label:"MUN"},
 {re:/Davis Cup/i,url:"https://assets.stickpng.com/images/62665bd01e92f9aac65b5bcd.png",label:"DAVIS"}
];

function tournamentLogoMeta(t={}){
 const name=String(t.name||t.tournament_name||"");
 const explicit=String(t.logo_url||"").trim();
 const major=MAJOR_TOURNAMENT_LOGOS.find(x=>x.re.test(name));
 const curated=CURATED_TOURNAMENT_LOGOS.find(x=>x.re.test(name));
 const category=String(t.category||t.level||"").trim();
 const circuit=String(t.circuit||"").trim();
 if(major)return {url:major.url,label:major.label,cls:"logo-official "+(major.cls||"")};
 if(curated)return {url:curated.url,label:curated.label,cls:"logo-official logo-curated"};
 if(explicit)return {url:explicit,label:String(category||circuit||"TOUR"),cls:"logo-official"};
 if(/Grand Chelem|Grand Slam/i.test(category))return {url:null,label:"GRAND SLAM",sub:"GS",cls:"logo-gs"};
 if(/Masters 1000/i.test(category))return {url:null,label:"ATP 1000",sub:"M1000",cls:"logo-atp"};
 if(/ATP 500|^500$/i.test(category))return {url:null,label:"ATP 500",sub:"500",cls:"logo-atp"};
 if(/ATP 250|^250$/i.test(category))return {url:null,label:"ATP 250",sub:"250",cls:"logo-atp"};
 if(/ATP Finals|Finals/i.test(category)&&circuit==="ATP")return {url:null,label:"ATP FINALS",sub:"FINALS",cls:"logo-finals"};
 if(/Challenger/i.test(category)||circuit==="Challenger")return {url:null,label:"ATP CH",sub:category.replace(/Challenger\\s*/i,"")||"CH",cls:"logo-challenger"};
 if(/Junior Grand Slam/i.test(category))return {url:null,label:"JUNIOR GS",sub:"JGS",cls:"logo-junior"};
 if(/^J\\d+/i.test(category)||circuit==="Junior")return {url:null,label:"ITF JUNIOR",sub:category||"J",cls:"logo-junior"};
 if(/^M\\d+|^W\\d+/i.test(category)||circuit==="ITF")return {url:null,label:"ITF",sub:category||"WTT",cls:"logo-itf"};
 if(circuit==="NCAA")return {url:null,label:"NCAA",sub:"COLLEGE",cls:"logo-ncaa"};
 if(circuit==="Federation"||/Davis/i.test(name+category))return {url:null,label:"DAVIS CUP",sub:"TEAM",cls:"logo-davis"};
 return {url:null,label:circuit||category||"TENNIS",sub:category&&category!==circuit?category:"TOUR",cls:"logo-generic"};
}
function tournamentLogoHtml(t,extraClass=""){
 const m=tournamentLogoMeta(t);
 const fallback="<span class='tm-tour-logo-fallback "+esc(m.cls)+" "+esc(extraClass)+"'><b>"+esc(m.label)+"</b><small>"+esc(m.sub||"")+"</small></span>";
 if(!m.url)return fallback;
 return "<span class='tm-tour-logo-shell "+esc(m.cls)+" "+esc(extraClass)+"'><img class='tm-tour-logo' src='"+esc(m.url)+"' alt='Logo "+esc(t.name||t.tournament_name||m.label)+"' loading='lazy' onerror=\"this.style.display='none';this.parentElement.nextElementSibling.style.display='grid'\"></span>"+fallback.replace("class='tm-tour-logo-fallback","style='display:none' class='tm-tour-logo-fallback");
}
function tournamentLogoByName(name,level="",extraClass=""){
 return tournamentLogoHtml({name,tournament_name:name,category:level,level,circuit:/Challenger/i.test(level)?"Challenger":/^M\d+|^W\d+|ITF/i.test(level)?"ITF":""},extraClass);
}
function slamLogoHtml(keyOrName,extraClass=""){
 const names={AO:"Australian Open",RG:"Roland-Garros",WIM:"Wimbledon",USO:"US Open"};
 return tournamentLogoByName(names[keyOrName]||keyOrName,"Grand Chelem",extraClass);
}
window.tournamentLogoHtml=tournamentLogoHtml;
window.tournamentLogoByName=tournamentLogoByName;
window.slamLogoHtml=slamLogoHtml;
function tournamentPhotoUrl(t){
 const direct=String(t?.image_url||"").trim();
 const weak=/Photo de la ville|Fallback circuit|Fallback compétition|Fallback catégorie|réutilisée/i.test(String(t?.image_source_label||""));
 const hotlinkRisk=/itftennis\.com|ncaa\.com|clvaw-cdnwnd\.com|estrepublicain\.fr/i.test(direct);
 if(t?.id&&(!direct||weak||hotlinkRisk))return API+'/api/tournament-image?id='+encodeURIComponent(t.id)+'&proxy=1';
 return direct;
}
function tournamentThumb(t){
 const photo=tournamentPhotoUrl(t);
 const logo=tournamentLogoMeta(t);
 const fallback=tournamentLogoHtml(t,"tm-list-logo tm-photo-logo-fallback");
 if(!photo)return fallback;
 return '<div class="tm-tour-photo-thumb">'+
  '<img class="tm-tour-photo-img" src="'+esc(photo)+'" alt="" loading="lazy" decoding="async" onload="this.parentElement.classList.add(\'loaded\')" onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'grid\'">'+
  '<div class="tm-tour-photo-fallback" style="display:none">'+fallback+'</div>'+
  (logo?.url?'<span class="tm-tour-photo-mark"><img src="'+esc(logo.url)+'" alt="" loading="lazy" decoding="async" onerror="this.parentElement.style.display=\'none\'"></span>':'')+
 '</div>';
}
function tournamentTmRow(t){
 const st=tournamentStatus(t),se=singlesEligibility(t),de=doublesEligibility(t),joined=(local.entries||[]).includes(t.id),dJoined=(local.doublesEntries||[]).includes(t.id);
 const teamEvent=specialTeamEventMeta(t);
 const window=tournamentParticipationWindow(t,se);
 const deadline=window.deadline;
 const raceFinals=/^(ATP Finals|Next Gen Finals|Junior Finals|Junior Double Finals)$/i.test(String(t.category||''));
 const selectionEvent=Boolean(teamEvent);
 const nextGenFinals=String(t.category||'')==='Next Gen Finals';
 const sBtn=selectionEvent?"<button class='ghost tm-entry-btn' disabled>Sélection</button>":nextGenFinals?"<button class='ghost tm-entry-btn' disabled>Top 8 U21</button>":raceFinals&&t.singles?"<button class='ghost tm-entry-btn' disabled>Race S</button>":se.can?"<button class='"+(joined?"danger-btn":"soft-btn")+" tm-entry-btn' onclick='event.stopPropagation();toggleSinglesEntry("+t.id+")'>"+(joined?"S ✓":"S +")+"</button>":"<button class='ghost tm-entry-btn' disabled>S —</button>";
 const dBtn=selectionEvent?"":raceFinals&&t.doubles?"<button class='ghost tm-entry-btn' disabled>Race D</button>":de.can?"<button class='"+(dJoined?"danger-btn":"soft-btn")+" tm-entry-btn' onclick='event.stopPropagation();toggleDoublesEntry("+t.id+")'>"+(dJoined?"D ✓":"D +")+"</button>":"<button class='ghost tm-entry-btn' disabled>D —</button>";
 return "<tr class='click "+(joined||dJoined?"tm-entered":"")+"' onclick='openTournament("+t.id+")'>"+
  "<td>"+tournamentThumb(t)+"</td>"+
  "<td><b>"+(flags[t.country]||"🏳️")+" "+esc(t.name)+"</b><div class='muted micro'>"+esc(t.city||"")+" · "+df(t.start_date)+"–"+df(t.end_date||t.start_date)+(t.qualifying_start_date?" · Qualifs dès le "+df(t.qualifying_start_date):"")+" · <span class='badge "+circuitClass(t.circuit)+"'>"+esc(t.category||t.circuit)+"</span>"+(t.is_verified?" <span class='badge good'>Officiel</span>":" <span class='badge warn'>Fictif</span>")+"</div></td>"+
  "<td><span class='"+surfaceClass(surfaceLabel(t))+"'>"+esc(surfaceLabel(t))+"</span></td>"+
  "<td>"+(teamEvent?"<b>"+esc(teamEvent.teams)+" équipes</b><div class='muted micro'>"+esc(teamEvent.code==='laver_cup'?'Europe vs Monde':'Compétition par nations')+"</div>":"<b>S "+(t.singles_draw_size||t.draw_size||"—")+"</b><div class='muted micro'>D "+(t.doubles?(t.doubles_draw_size||"—"):"—")+" · Q "+(t.qualifying_draw_size||"—")+"</div>")+"</td>"+
  "<td><b>"+(t.winner_points!=null?fmt(t.winner_points):"—")+"</b></td>"+
  "<td><b>"+(t.prize_money!=null?tournamentPrizeLabel(t):"—")+"</b></td>"+
  "<td>"+(t.defending_champion_name?("<div class='tm-holder' "+(t.defending_champion_player_id?"onclick='event.stopPropagation();openPlayer("+t.defending_champion_player_id+")'":"")+"><span>🏆 "+esc(t.defending_champion_name)+"</span><small>"+esc(String(t.defending_champion_year||""))+"</small></div>"):(t.defending_champion_source&&/première édition/i.test(t.defending_champion_source)?"<span class='muted mini'>Première édition</span>":"<span class='muted'>—</span>"))+"</td>"+
  "<td><span class='badge "+st.cls+"'>"+st.label+"</span><div class='muted micro "+se.cls+"'>"+esc(se.label)+(t.cut_is_projection&&t.projected_direct_cut?" · cut proj.":"")+"</div><div class='muted micro'>"+esc(de.label)+"</div></td>"+
  "<td><b>"+(deadline?df(deadline):"—")+"</b><div class='muted micro'>"+(t.doubles_entry_deadline?"D adv "+df(t.doubles_entry_deadline):"")+(t.doubles_onsite_deadline?" · site "+df(t.doubles_onsite_deadline):"")+"</div></td>"+
  "<td><div class='tm-entry-actions'>"+sBtn+dBtn+"<button class='ghost tm-entry-btn' onclick='event.stopPropagation();openTournament("+t.id+")'>›</button></div></td>"+
 "</tr>";
}
function tmCalendarRows(){
 const focus=String(activePlayerCareerView().career_focus||'mixed');
 const doublesOnly=focus==='doubles_only',singlesOnly=focus==='singles_only';
 return (tourRows||[]).filter(t=>{
  const st=tournamentStatus(t),se=singlesEligibility(t),de=doublesEligibility(t),wk=calWeekStart(t.start_date);
  if(doublesOnly&&!t.doubles)return false;
  if(singlesOnly&&!t.singles)return false;
  if(tmCalFilters.week!=="Toutes"&&wk!==tmCalFilters.week)return false;
  if(tmCalFilters.country!=="Tous"&&String(t.country)!==tmCalFilters.country)return false;
  if(tmCalFilters.status!=="Tous"&&st.label!==tmCalFilters.status)return false;
  if(tmCalFilters.environment==="Indoor"&&!t.indoor)return false;
  if(tmCalFilters.environment==="Outdoor"&&t.indoor)return false;
  if(tmCalFilters.entry==="Simple"&&!t.singles)return false;
  if(tmCalFilters.entry==="Double"&&!t.doubles)return false;
  if(tmCalFilters.entry==="Simple + Double"&&!(t.singles&&t.doubles))return false;
  if(tmCalFilters.holder==="Avec tenant"&&!t.defending_champion_name)return false;
  if(tmCalFilters.holder==="Sans tenant"&&t.defending_champion_name)return false;
  if(tmCalFilters.eligibility==="Éligible simple"&&!se.can)return false;
  if(tmCalFilters.eligibility==="Éligible double"&&!de.can)return false;
  if(tmCalFilters.eligibility==="Tableau direct"&&!/Tableau direct/.test(se.label))return false;
  if(tmCalFilters.eligibility==="Qualifications"&&!/Qualif/.test(se.label))return false;
  if(tmCalFilters.eligibility==="Alternate / WC"&&!/Alternate|WC/.test(se.label))return false;
  if(tmCalFilters.eligibility==="Sélection"&&!/Sélection|université|NCAA/.test(se.label))return false;
  return true;
 });
}
function renderTournamentWeeks(){
 const groups={};tmCalendarRows().forEach(t=>{const k=calWeekStart(t.start_date);(groups[k]??=[]).push(t)});
 return Object.entries(groups).sort((a,b)=>a[0].localeCompare(b[0])).map(([week,rows])=>{
  const current=calWeekStart(local.date||"2025-12-01")===week;
  return "<section class='tm-week "+(current?"current":"")+"'><div class='tm-week-head'><div><span class='tm-week-num'>S"+calGameWeek(week)+"</span><b>"+calShortDate(week)+" → "+calShortDate(calWeekEnd(week))+"</b>"+(current?" <span class='badge good'>Semaine actuelle</span>":"")+"</div><span class='muted mini'>"+rows.length+" tournoi"+(rows.length>1?"s":"")+"</span></div><div class='table-wrap'><table class='table tm-calendar-table'><thead><tr><th></th><th>Pays / tournoi</th><th>Surface</th><th>Tableaux</th><th>Pts</th><th>Prize money</th><th>Tenant</th><th>Statut / accès</th><th>Deadline</th><th>Actions</th></tr></thead><tbody>"+rows.map(tournamentTmRow).join("")+"</tbody></table></div></section>";
 }).join("");
}
window.tmCalendarFilter=(k,v)=>{tmCalFilters[k]=v;render()}
window.resetTmCalendarFilters=()=>{const f=String(activePlayerCareerView().career_focus||'mixed');tmCalFilters={week:'Toutes',country:'Tous',status:'Tous',eligibility:'Tous',environment:'Tous',entry:f==='doubles_only'?'Double':f==='singles_only'?'Simple':'Tous',holder:'Tous'};render()}

function calendar(){
 const cats=['Toutes','Grand Chelem','Masters 1000','ATP 500','ATP 250','ATP Finals','Next Gen Finals','United Cup','Laver Cup','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','Junior Grand Slam','J500','J300','J200','J100','J60','J30','Junior Finals','Junior Davis Cup','ITA Kickoff Weekend','ITA National Team Indoor Championship','ITA All-American Championships','ITA Division I Regionals','ITA Sectional Championships','ITA Conference Masters','NCAA DI Team Championship','NCAA DI Individual Championship','NCAA','Junior','Davis Cup'];
 const circs=['Tous','ATP','Challenger','ITF','NCAA','Junior','Federation'];
 const surfaces=['Toutes','Dur extérieur','Dur intérieur','Terre','Gazon','Moquette'];
 const officialCount=worldStats?.verifiedTournaments||0;
 const coverage=`ATP ${fmt(worldStats?.officialATP||0)} · CH ${fmt(worldStats?.officialChallenger||0)} · ITF ${fmt(worldStats?.officialITF||0)} · Junior ${fmt(worldStats?.officialJunior||0)} · NCAA ${fmt(worldStats?.officialNCAA||0)} · Davis ${fmt(worldStats?.officialFederation||0)}`;
 const cr=activePlayerCareerView(),partner=activeDoublesPartner(),singleEntries=(local.entries||[]).length,doubleEntries=(local.doublesEntries||[]).length;
 return `<div class="fm-page-head tm-calendar-head"><div><div class="eyebrow">Tournament registration · calendrier TM</div><h1>Calendrier mondial</h1><div class="muted">Départ de la base : <b>01/12/2025</b>. Vrais événements 2025-26, semaine par semaine, avec simple, double, qualifs et règles d’accès séparés.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(tourCount)} tournois</div><div class="fm-head-badge subtle">${fmt(officialCount)} officiels</div><div class="fm-head-badge subtle">S ${singleEntries} · D ${doubleEntries}</div></div></div>
 <div class="tm-calendar-tabs"><button class="${tourFilters.circuit==='Tous'?'active':''}" onclick="tourFilter('circuit','Tous')">Tous</button><button class="${tourFilters.circuit==='ATP'?'active':''}" onclick="tourFilter('circuit','ATP')">ATP</button><button class="${tourFilters.circuit==='Challenger'?'active':''}" onclick="tourFilter('circuit','Challenger')">Challenger</button><button class="${tourFilters.circuit==='ITF'?'active':''}" onclick="tourFilter('circuit','ITF')">ITF</button><button class="${tourFilters.circuit==='Junior'?'active':''}" onclick="tourFilter('circuit','Junior')">Junior</button><button class="${tourFilters.circuit==='NCAA'?'active':''}" onclick="tourFilter('circuit','NCAA')">NCAA</button><button class="${tourFilters.circuit==='Federation'?'active':''}" onclick="tourFilter('circuit','Federation')">Davis Cup</button><button onclick="showMyEntries()">Mes inscriptions</button></div>
 <div class="card tm-registration-summary"><div><span>Joueur</span><b>${esc(cr.player_name)}</b><small>ATP #${fmt(cr.singles_rank)} · Double ${careerDoublesRankText(cr)} · ${careerFocusLabel(cr.career_focus||'mixed')}</small></div><div><span>Partenaire double</span><b>${String(cr.career_focus||'mixed')==='singles_only'?'Désactivé':partner?esc(partner.name):'Aucun'}</b><small>${String(cr.career_focus||'mixed')==='singles_only'?'Carrière 100 % simple':partner?'Double #'+fmt(partner.doubles_ranking||0):'Choisir dans le hub Double'}</small></div><div><span>Date carrière</span><b>${df(local.date||'2025-12-01')}</b><small>Semaine ${calGameWeek(local.date||'2025-12-01')}</small></div><div><span>Couverture</span><b>${coverage}</b><small>Officiels + fictifs Challenger/ITF · filtrables</small></div></div>
 <div class="filters fm-calendar-filters"><input class="input" placeholder="Rechercher un tournoi…" value="${esc(tourFilters.q)}" onchange="tourFilter('q',this.value)"><select class="select" onchange="tourFilter('circuit',this.value)">${circs.map(x=>`<option ${x===tourFilters.circuit?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('category',this.value)">${cats.map(x=>`<option ${x===tourFilters.category?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('surface',this.value)">${surfaces.map(x=>`<option ${x===tourFilters.surface?'selected':''}>${x}</option>`).join('')}</select><select class="select" onchange="tourFilter('source',this.value)"><option value="Tous" ${tourFilters.source==='Tous'?'selected':''}>Tous</option><option value="Officiel" ${tourFilters.source==='Officiel'?'selected':''}>Officiels</option><option value="Fictif" ${tourFilters.source==='Fictif'?'selected':''}>Fictifs Challenger/ITF</option></select><input class="input" type="month" min="2025-12" value="${tourFilters.month}" onchange="tourFilter('month',this.value)"></div>
 <div class="surface-legend"><span class="surface-hard">● Dur extérieur</span><span class="surface-indoor">● Dur intérieur</span><span class="surface-clay">● Terre battue</span><span class="surface-grass">● Gazon</span><span class="muted mini">Cut “proj.” = estimation Court Boss, pas une acceptance list officielle.</span></div>
 <div class="card tm-advanced-filters">
  <div class="row between"><div><div class="eyebrow">Filtres TM</div><b>Affiner le calendrier</b></div><button class="ghost" onclick="resetTmCalendarFilters()">Réinitialiser</button></div>
  <div class="tm-filter-grid">
   <select class="select" onchange="tmCalendarFilter('week',this.value)"><option>Toutes</option>${[...new Set((tourRows||[]).map(t=>calWeekStart(t.start_date)))].sort().map(w=>`<option value="${w}" ${tmCalFilters.week===w?'selected':''}>S${calGameWeek(w)} · ${calShortDate(w)}–${calShortDate(calWeekEnd(w))}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('country',this.value)"><option>Tous</option>${[...new Set((tourRows||[]).map(t=>t.country).filter(Boolean))].sort().map(x=>`<option ${tmCalFilters.country===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('status',this.value)">${['Tous','Inscriptions ouvertes','Inscriptions closes','À venir','En cours','Terminé'].map(x=>`<option ${tmCalFilters.status===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('eligibility',this.value)">${['Tous','Éligible simple','Éligible double','Tableau direct','Qualifications','Alternate / WC','Sélection'].map(x=>`<option ${tmCalFilters.eligibility===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('environment',this.value)">${['Tous','Indoor','Outdoor'].map(x=>`<option ${tmCalFilters.environment===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('entry',this.value)">${['Tous','Simple','Double','Simple + Double'].map(x=>`<option ${tmCalFilters.entry===x?'selected':''}>${x}</option>`).join('')}</select>
   <select class="select" onchange="tmCalendarFilter('holder',this.value)">${['Tous','Avec tenant','Sans tenant'].map(x=>`<option ${tmCalFilters.holder===x?'selected':''}>${x}</option>`).join('')}</select>
  </div>
 </div>
 <details class="card tm-calendar-advice"><summary class="row between click"><div><div class="eyebrow">Conseiller calendrier</div><b>Recommandations pour ton joueur</b></div><span class="badge">ouvrir</span></summary><div class="grid g3" style="margin-top:10px">${(scheduleAdvice?.recommended||[]).slice(0,6).map(t=>`<div class="card click" onclick="openTournament(${t.id})"><div class="row between"><div class="row" style="align-items:center;gap:8px">${tournamentThumb(t)}<div><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span><h3 style="margin:6px 0 0">${esc(t.name)}</h3></div></div><b>${t.recommendation_score}/100</b></div><div class="muted mini" style="margin-top:6px">${esc(t.city||'')} · ${df(t.start_date)} · ${esc(surfaceLabel(t))}</div></div>`).join('')||'<div class="empty">Aucune recommandation.</div>'}</div></details>
 <div class="tm-calendar-rulebar"><span><b>ATP Tour</b> : simple 28 j · qualifs 21 j · double 14 j</span><span><b>Finals</b> : qualification automatique via Race</span><span><b>Challenger</b> : double 7 j + sign-in</span><span><b>M25</b> : advance + sur site</span><span><b>M15</b> : double sur site</span><span><b>NCAA</b> : roster/lineup, pas d’inscription libre</span></div>
 <div class="tm-calendar-weeks">${renderTournamentWeeks()||'<div class="card empty">Aucun tournoi daté pour ces filtres.</div>'}</div>
 ${tourTbc.length?`<div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Date à confirmer</div><h2>Événements officiels TBC</h2></div></div><div class="stack">${tourTbc.map(t=>`<div class="card click" onclick="openTournament(${t.id})"><div class="row between" style="gap:12px"><div class="row" style="align-items:center;gap:10px;min-width:0">${tournamentThumb(t)}<div><span class="badge good">Officiel · TBC</span><h2 style="margin:8px 0 4px">${esc(t.name)}</h2><div class="muted">${esc(t.city||'TBC')} · date à confirmer · <span class="surface-indoor">${esc(surfaceLabel(t))}</span></div></div></div><span class="badge">${esc(t.category||'ATP')}</span></div></div>`).join('')}</div>`:''}
 <div class="pagination"><button ${tourOffset===0?'disabled':''} onclick="tourPage(-1)">←</button><span class="muted mini">${tourCount?fmt(tourOffset+1):0}–${fmt(Math.min(tourOffset+tourRows.length,tourCount))} / ${fmt(tourCount)}</span><button ${tourOffset+150>=tourCount?'disabled':''} onclick="tourPage(1)">→</button></div>`
}
function tournamentCard(t){
 const c=activePlayerCareerView(),isJunior=String(t.circuit)==='Junior',isFederation=String(t.circuit)==='Federation',isNcaa=String(t.circuit)==='NCAA';
 const singlesElig=isFederation?'Par sélection nationale':isNcaa?'Championnat universitaire':isJunior?'Circuit Junior ITF':t.direct_cut==null?'Règles spéciales':c.singles_rank<=t.direct_cut?'Tableau direct':c.singles_rank<=t.qual_cut?'Qualifications':'Alternate / hors cut';
 const joined=(local.entries||[]).includes(t.id);
 const target=isFederation?"nav('davis')":isNcaa?"nav('university')":'openTournament('+t.id+')';
 const doublesOnly=String(c.career_focus||'mixed')==='doubles_only',dJoined=(local.doublesEntries||[]).includes(t.id),dRule=doublesEligibility(t);
 const elig=doublesOnly?dRule.label:singlesElig;
 const action=isFederation?'<button class="soft-btn" onclick="event.stopPropagation();nav(\'davis\')">Voir la Coupe Davis</button>':isNcaa?'<button class="soft-btn" onclick="event.stopPropagation();nav(\'university\')">Voir NCAA</button>':doublesOnly?(t.doubles&&dRule.can?`<button class="${dJoined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleDoublesEntry(${t.id})">${dJoined?'Double ✓ · retirer':'Inscrire la paire'}</button>`:'<button class="ghost" disabled>Double indisponible</button>'):`<button class="${joined?'danger-btn':'primary'}" onclick="event.stopPropagation();toggleEntry(${t.id})">${joined?'Inscrit · retirer':'S’inscrire'}</button>`;
 return `<div class="card click tm-tour-card-photo" onclick="${target}">
  <div class="tm-tour-card-photo-media">
   ${(()=>{const photo=tournamentPhotoUrl(t);const m=tournamentLogoMeta(t);return photo?`<img src="${esc(photo)}" alt="${esc(t.name)}" loading="lazy" decoding="async" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'"><div class="tm-tour-card-photo-fallback" style="display:none">${tournamentLogoHtml(t,'tm-card-logo-fallback')}</div>${m?.url?`<span class="tm-tour-card-logo"><img src="${esc(m.url)}" alt="" loading="lazy" decoding="async" onerror="this.parentElement.style.display='none'"></span>`:''}`:`<div class="tm-tour-card-photo-fallback">${tournamentLogoHtml(t,'tm-card-logo-fallback')}</div>`})()}
   <div class="tm-tour-card-photo-shade"></div>
   <div class="tm-tour-card-photo-badges"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.level)}</span>${t.is_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Monde simulé</span>'}</div>
  </div>
  <div class="tm-tour-card-photo-body">
   <div class="row between" style="gap:12px">
    <div style="min-width:0"><h2 style="margin:0 0 5px">${flags[t.country]||'🏳️'} ${esc(t.name)}</h2><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} · <span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span>${t.venue?' · '+esc(t.venue):''}</div></div>
    <div style="text-align:right;flex:0 0 auto"><span class="badge ${elig==='Tableau direct'?'good':elig==='Qualifications'?'warn':''}">${elig}</span><div style="margin-top:8px">${action}</div></div>
   </div>
  </div>
 </div>`
}
window.showMyEntries=()=>{
  const ids=new Set([...(local.entries||[]),...(local.doublesEntries||[])]);
  const known=[...(tourRows||[]),...(boot?.upcoming||[]),...(scheduleAdvice?.recommended||[])];
  const rows=[...new Map(known.filter(t=>ids.has(t.id)).map(t=>[t.id,t])).values()].sort((a,b)=>String(a.start_date).localeCompare(String(b.start_date)));
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Planning manager</div><h1>Mes inscriptions</h1><div class="muted">Simple et double sont suivis séparément.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>${rows.length?rows.map(t=>`<div class="list-item row between"><div class="row" style="align-items:center;gap:10px;min-width:0">${tournamentThumb(t)}<div style="min-width:0"><b>${esc(t.name)}</b><div class="muted mini">${df(t.start_date)} · ${esc(t.category||t.circuit)} · ${esc(surfaceLabel(t))}</div></div></div><div>${(local.entries||[]).includes(t.id)?'<span class="badge good">Simple</span>':''} ${(local.doublesEntries||[]).includes(t.id)?'<span class="badge good">Double</span>':''}</div></div>`).join(''):'<div class="empty">Aucune inscription active.</div>'}</div></div>`;
}
window.tourFilter=async(k,v)=>{tourFilters[k]=v;if(k==='circuit'&&v==='Junior'&&tourFilters.source==='Tous')tourFilters.source='Officiel';tourOffset=0;await loadTournaments();render()}
window.toggleFullCalendar=async()=>{tourShowPast=!tourShowPast;tourOffset=0;await loadTournaments();render()}
window.tourPage=async d=>{tourOffset=Math.max(0,tourOffset+d*150);await loadTournaments();render();window.scrollTo(0,0)}
function datesOverlap(aStart,aEnd,bStart,bEnd){
 const a1=new Date((aStart||aEnd)+'T12:00:00'),a2=new Date((aEnd||aStart)+'T12:00:00'),b1=new Date((bStart||bEnd)+'T12:00:00'),b2=new Date((bEnd||bStart)+'T12:00:00');
 return a1<=b2&&b1<=a2;
}

const tournamentDetailRows=new Map();
function findTournamentById(id){return tournamentDetailRows.get(Number(id))||[...(tourRows||[]),...(boot?.upcoming||[]),...(scheduleAdvice?.recommended||[])].find(x=>Number(x.id)===Number(id))}
window.toggleSinglesEntry=async id=>{
 const playerId=activeManagedId(),activeView=activePlayerCareerView();
 if(String(activeView.career_focus||'mixed')==='doubles_only'){alert('Mode Double exclusivement : les inscriptions simple sont désactivées.');return}
 local.entries=local.entries||[];local.entryMeta=local.entryMeta||{};
 const exists=local.entries.includes(id);
 if(exists){
  try{
   await get('/api/tournament-entry',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({tournament_id:id,player_id:playerId,action:'withdraw',entry_method:String(local.entryMeta?.[id]?.entry_method||'alternate')})
   });
  }catch(e){alert('Retrait impossible : '+e.message);return}
  local.entries=local.entries.filter(x=>x!==id);delete local.entryMeta[id];persist();render();return
 }
 let t=findTournamentById(id);if(!t)return;
 if(['ATP','Challenger','ITF'].includes(String(t.circuit))){
  try{
   const access=await get('/api/tournament-entry-status?id='+encodeURIComponent(id)+'&player_id='+encodeURIComponent(playerId));
   t={...t,...access.tournament,managed_entry_rules:access.entry_rules,managed_pathway_status:access.pathway_status,managed_wildcard_status:access.wildcard_status,entry_rule_context:tournamentEntryContext()};
   tournamentDetailRows.set(Number(id),t)
  }catch(e){alert('Impossible de vérifier l’inscription : '+e.message);return}
 }
 if(local.entries.includes(id))return;
 const elig=applyManagedPathwayEligibility(t,singlesEligibility(t));if(!elig.can){alert(elig.label);return}
 const window=tournamentParticipationWindow(t,elig);
 const deadline=window.deadline;
 if(deadline&&String(local.date||"2025-12-01")>String(deadline)){alert("Deadline simple dépassée : "+df(deadline));return}
 const conflict=Object.entries(local.entryMeta).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(window.start_date,window.end_date,existingEntryWindow(eid,e).start_date,e.end_date));
 if(conflict){alert("Conflit calendrier avec "+conflict[1].name+" ("+df(conflict[1].start_date)+").");return}
 const dConflict=playerId===primaryManagedPlayerId()?Object.entries(local.doublesEntryMeta||{}).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(window.start_date,window.end_date,existingEntryWindow(eid,e,'doubles').start_date,e.end_date)):null;
 if(dConflict){alert("Tu es déjà engagé en double à "+dConflict[1].name+" cette semaine.");return}

 let serverEntry=null;
 if(['ATP','Challenger','ITF'].includes(String(t.circuit))){
  try{
   const saved=await get('/api/tournament-entry',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({tournament_id:id,player_id:playerId,action:'enter',entry_method:String(elig.method||'alternate')})
   });
   serverEntry=saved.entry||null;
  }catch(e){alert('Inscription refusée par le serveur : '+e.message);return}
 }
 local.entryMeta[id]={
   entry_start_date:window.start_date,entry_method:elig.method,
   qualifying_start_date:t.qualifying_start_date,main_draw_start_date:t.main_draw_start_date,
   name:t.name,start_date:t.start_date,end_date:t.end_date,country:t.country,circuit:t.circuit,category:t.category,
   status:elig.label,player_id:playerId,server_entry_id:serverEntry?.id||null,requested_on:serverEntry?.requested_on||local.date||null
 };
 local.entries.push(id);persist();render();
}
window.toggleDoublesEntry=async id=>{
 const playerId=activeManagedId(),activeView=activePlayerCareerView();
 if(String(activeView.career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : les inscriptions double sont désactivées.');return}
 local.doublesEntries=local.doublesEntries||[];local.doublesEntryMeta=local.doublesEntryMeta||{};
 const exists=local.doublesEntries.includes(id);
 if(exists){
  try{
   await get('/api/doubles-entry',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({tournament_id:Number(id),player_id:playerId,action:'withdraw'})
   });
  }catch(e){alert('Retrait double impossible : '+e.message);return}
  local.doublesEntries=local.doublesEntries.filter(x=>x!==id);
  delete local.doublesEntryMeta[id];
  persist();render();return
 }

 let t=findTournamentById(id);if(!t)return;
 let checked=null;
 try{
   checked=await get('/api/doubles-entry-status?id='+encodeURIComponent(id)+'&player_id='+encodeURIComponent(playerId));
   t={...t,...checked.tournament,managed_doubles_entry_status:checked.doubles_entry_status};
   tournamentDetailRows.set(Number(id),t);
 }catch(e){alert('Impossible de vérifier l’inscription double : '+e.message);return}

 const elig=doublesEligibility(t);if(!elig.can){alert(elig.label);return}
 if(elig.projectedAcceptance===false){
   alert(elig.label+' · tu peux rester en alternate, mais la paire n’est pas projetée dans le tableau principal.');
 }
 const onsite=t.doubles_onsite_deadline||t.start_date;
 if(onsite&&String(local.date||"2025-12-01")>String(onsite)){
   alert("Inscriptions double closes : dernier sign-in "+df(onsite)+".");
   return;
 }

 const window=tournamentParticipationWindow(t,elig,'doubles');
 const sConflict=Object.entries(local.entryMeta||{}).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(window.start_date,window.end_date,existingEntryWindow(eid,e).start_date,e.end_date));
 if(sConflict){alert("Tu es déjà engagé en simple à "+sConflict[1].name+" cette semaine.");return}
 const dConflict=Object.entries(local.doublesEntryMeta).find(([eid,e])=>Number(eid)!==Number(id)&&datesOverlap(window.start_date,window.end_date,existingEntryWindow(eid,e,'doubles').start_date,e.end_date));
 if(dConflict){alert("Conflit double avec "+dConflict[1].name+".");return}

 let saved=null;
 try{
  saved=await get('/api/doubles-entry',{
   method:'POST',headers:{'Content-Type':'application/json'},
   body:JSON.stringify({tournament_id:Number(id),player_id:playerId,action:'enter'})
  });
 }catch(e){alert('Inscription double refusée par le serveur : '+e.message);return}

 const partner=saved?.partner||checked?.doubles_entry_status?.partner||activeDoublesPartner();
 const entry=saved?.entry||{};
 local.doublesEntryMeta[id]={
   entry_start_date:window.start_date,
   entry_method:entry.entry_method||(elig.requiresQualifying?(elig.qualifyingEntryMethod||'qualifying'):'direct'),
   entry_phase:entry.entry_phase||elig.phase||'advance',
   name:t.name,start_date:t.start_date,end_date:t.end_date,country:t.country,circuit:t.circuit,category:t.category,
   player_id:playerId,partner_id:entry.partner_id||partner?.id,partner_name:partner?.name,
   status:saved?.doubles_entry_status?.label||elig.label,
   projected_acceptance:saved?.doubles_entry_status?.projected_acceptance??elig.projectedAcceptance,
   projected_cut:entry.projected_cut??elig.projectedCut,
   qualifying_cut:saved?.doubles_entry_status?.qualifying_cut??elig.qualifyingCut,
   best_combined_rank:entry.combined_rank??elig.bestCombinedRank,
   server_entry_id:entry.id||null,requested_on:entry.requested_on||local.date
 };
 local.doublesEntries.push(id);persist();render();
}
window.toggleEntry=window.toggleSinglesEntry;

function academy(){
 const a=boot.academy||{},c=career();
 const roster=management?.academyRoster||[];
 const youth=boot.youth||[];
 const intakeHistory=management?.academyIntakeHistory||[];
 const academyHead=management?.academyHead||null;
 const academyStaffCandidates=(management?.academyStaffCandidates||[]).filter(x=>Number(x.profile?.youth_rating||0)>0);
 const activeYouth=youth.filter(y=>['prospect','signed','academy'].includes(String(y.status||'')));
 const capacity=Number(a.youth_capacity||8),used=activeYouth.length;
 const focuses=['Équilibré','Service','Retour','Fond de court','Déplacements','Physique','Mental','Double'];
 const styles=['Équilibré','Technique','Physique','Mental','Service & attaque','Développement long terme'];
 const monthNames=['','Janvier','Février','Mars','Avril','Mai','Juin','Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
 const potentialRange=y=>{
  const lo=Number(y.potential_floor??Math.max(Number(y.current_ability||0),Number(y.potential||0)-8));
  const hi=Number(y.potential_ceiling??Math.min(99,Number(y.potential||0)+5));
  return starRatingHtml(abilityStarValue(lo),'Plancher estimé')+'–'+starRatingHtml(abilityStarValue(hi),'Plafond estimé');
 };
 return `<div class="section-head"><div><div class="eyebrow">Academy 2.0 · filière jeunes</div><h1>${esc(a.name||'Court Boss Academy')}</h1><div class="muted">Réputation ${a.reputation||48}/100 · jeunes ${a.junior_reputation||40}/100 · Board ${a.board_confidence||76}% · intake annuel en ${monthNames[Number(a.intake_month||3)]}</div></div><div class="row"><button class="soft-btn" onclick="nav('scouting')">Scouting</button><button class="primary" onclick="nav('board')">Board</button></div></div>
 <div class="kpi-strip">
  <div class="kpi"><span class="muted mini">Niveau académie</span><b>${a.academy_level||1}/5</b></div>
  <div class="kpi"><span class="muted mini">Capacité jeunes</span><b>${used}/${capacity}</b><div class="bar"><i style="width:${Math.min(100,Math.round(used/Math.max(1,capacity)*100))}%"></i></div></div>
  <div class="kpi click" onclick="nav('finance')"><span class="muted mini">Budget</span><b>${euro(c.budget??a.budget)}</b></div>
  <div class="kpi"><span class="muted mini">Bourses</span><b>${euro(a.scholarship_budget||10000)}</b></div>
  <div class="kpi"><span class="muted mini">Portée recrutement</span><b>Niv. ${a.recruitment_reach||a.scouting_network||2}</b></div>
  <div class="kpi"><span class="muted mini">Développement</span><b>${a.development_intensity||2}/5</b></div>
 </div>

 <div class="grid g2" style="margin-top:12px">
  <div class="card"><div class="eyebrow">Identité de formation</div><h2>Philosophie</h2>
   <div class="list-item"><span class="muted mini">Style académie</span><select class="select" onchange="setAcademySetting('academy_style',this.value)">${styles.map(x=>`<option ${x===String(a.academy_style||'Équilibré')?'selected':''}>${x}</option>`).join('')}</select></div>
   <div class="list-item row between"><span>Intensité développement</span><select class="select" style="width:auto" onchange="setAcademySetting('development_intensity',this.value)">${[1,2,3,4,5].map(x=>`<option value="${x}" ${Number(a.development_intensity||2)===x?'selected':''}>${x}/5</option>`).join('')}</select></div>
   <div class="list-item row between"><span>Capacité jeunes</span><select class="select" style="width:auto" onchange="setAcademySetting('youth_capacity',this.value)">${[8,10,12,16,20,24].map(x=>`<option value="${x}" ${Number(a.youth_capacity||8)===x?'selected':''}>${x}</option>`).join('')}</select></div>
   <div class="list-item row between"><span>Portée recrutement</span><select class="select" style="width:auto" onchange="setAcademySetting('recruitment_reach',this.value)">${[1,2,3,4,5].map(x=>`<option value="${x}" ${Number(a.recruitment_reach||2)===x?'selected':''}>Niv. ${x}</option>`).join('')}</select></div>
   <div class="list-item row between"><span>Budget bourses / saison</span><select class="select" style="width:auto" onchange="setAcademySetting('scholarship_budget',this.value)">${[5000,10000,15000,25000,40000,60000].map(x=>`<option value="${x}" ${Number(a.scholarship_budget||10000)===x?'selected':''}>${euro(x)}</option>`).join('')}</select></div>
   <div class="muted mini" style="margin-top:8px">Une académie plus intense fait progresser plus vite mais augmente la charge. La portée de recrutement élargit la promotion annuelle et les installations + staff influencent directement la progression.</div>
  </div>
  <div class="card"><div class="eyebrow">Orientation carrière</div><h2>NCAA ↔ Circuit pro</h2>
   <div class="list-item"><div class="row between"><span>Préférence NCAA</span><b>${a.ncaa_pathway||50}%</b></div><input type="range" min="0" max="100" step="5" value="${a.ncaa_pathway||50}" onchange="setAcademySetting('ncaa_pathway',this.value)"></div>
   <div class="list-item"><div class="row between"><span>Préférence pro</span><b>${a.pro_pathway||50}%</b></div><input type="range" min="0" max="100" step="5" value="${a.pro_pathway||50}" onchange="setAcademySetting('pro_pathway',this.value)"></div>
   <div class="notice mini" style="margin-top:8px">À partir de 18 ans, le jeu crée une vraie décision manager. Un départ NCAA génère une projection Court Boss, jamais un faux rang ITA officiel.</div>
  </div>
 </div>


 <div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Direction de la formation</div><h2>${academyHead?esc(academyHead.name):'Poste à attribuer'}</h2><div class="muted mini">${academyHead?`${esc(academyHead.primary_role||'Staff')} · jeunes ${academyHead.youth_rating||0}/20 · développement ${academyHead.development_rating||0}/20 · communication ${academyHead.communication_rating||0}/20`:'Choisis dans ton staff la personne qui pilote la filière jeunes.'}</div></div>${academyHead?`<span class="badge good">Responsable jeunes</span>`:'<span class="badge warn">Vacant</span>'}</div>
  <div class="row" style="margin-top:10px;gap:8px;flex-wrap:wrap">
   <select id="academyHeadSelect" class="select" style="min-width:240px;flex:1">
    <option value="">Choisir un membre du staff…</option>
    ${academyStaffCandidates.map(x=>{const p=x.profile||{};return `<option value="${p.id}" ${Number(p.id)===Number(academyHead?.id||0)?'selected':''}>${esc(p.name||x.name)} · Jeunes ${p.youth_rating||0}/20 · Dev ${p.development_rating||0}/20</option>`}).join('')}
   </select>
   <button class="primary" onclick="assignHeadOfYouth()">Nommer</button>
  </div>
  <div class="muted micro" style="margin-top:8px">Le responsable jeunes est un vrai membre de ton staff. Ses contrats, sa fatigue et son évolution continuent d’exister dans le système staff.</div>
 </div>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Promotion & intake</div><h2>Jeunes de l’académie</h2><div class="muted">Le potentiel reste volontairement incertain et se resserre avec le scouting.</div></div><button class="ghost" onclick="nav('scouting')">Améliorer la connaissance</button></div>
 <div class="grid g2">${youth.map(y=>`<div class="card academy-youth-card">
   <div class="row between"><div class="click" onclick="openYouth(${y.id})"><div class="eyebrow">${esc(y.region||'Académie')} · ${esc(y.personality||'Profil en observation')}</div><h2>${flags[y.country]||'🏳️'} ${esc(y.name)}</h2><div class="muted mini">${y.age} ans · ${esc(y.handedness||'—')} · revers ${esc(y.backhand||'—')} · ${esc(y.style||'')}</div></div><span class="badge ${y.status==='signed'?'good':y.status==='ncaa'?'tag-ncaa':''}">${esc(y.status||'prospect')}</span></div>
   <div class="grid g3" style="margin-top:10px"><div class="kpi"><span class="muted micro">Niveau</span><b>${starRatingHtml(abilityStarValue(y.current_ability||0),'Niveau actuel')}</b></div><div class="kpi"><span class="muted micro">Potentiel scout</span><b style="font-size:12px">${potentialRange(y)}</b></div><div class="kpi"><span class="muted micro">Confiance</span><b>${y.scouting_confidence||45}%</b></div></div>
   <div class="row" style="margin-top:9px;gap:6px;flex-wrap:wrap"><span class="badge">Moral ${y.morale||70}</span><span class="badge">Charge ${y.training_load||50}</span><span class="badge ${y.injury_status==='Fit'?'good':'bad'}">${esc(y.injury_status||'Fit')}</span><span class="badge">Préférence ${esc(y.pathway_preference||'undecided')}</span></div>
   ${Number(y.age)>=18&&String(y.status)==='prospect'?`<div class="row" style="margin-top:10px"><button class="primary" onclick="decideYouthPathway(${y.id},'pro')">Passer pro</button><button class="soft-btn" onclick="decideYouthPathway(${y.id},'ncaa')">Envoyer en NCAA</button><button class="ghost" onclick="decideYouthPathway(${y.id},'release')">Libérer</button></div>`:''}
  </div>`).join('')||'<div class="card empty">Aucun jeune dans la promotion.</div>'}</div>


 <div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Historique des promotions</div><h2>Intakes de l’académie</h2></div><span class="badge">${intakeHistory.length} dossier${intakeHistory.length>1?'s':''}</span></div>
  ${intakeHistory.length?`<div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>Année</th><th>Jeune</th><th>Pays</th><th>Niveau entrée</th><th>Potentiel initial</th><th>Destination</th></tr></thead><tbody>${intakeHistory.map(x=>`<tr><td class="rank-num">${x.intake_year}</td><td><b>${esc(x.youth?.name||'Prospect')}</b></td><td>${flags[x.country]||'🏳️'} ${esc(x.country||'—')}</td><td>${x.initial_ca??'—'}</td><td>${x.potential_floor??'—'}–${x.potential_ceiling??'—'}</td><td><span class="badge ${x.destination==='ncaa'?'tag-ncaa':x.destination==='pro'?'good':''}">${esc(x.destination||x.youth?.status||'Académie')}</span></td></tr>`).join('')}</tbody></table></div>`:'<div class="empty">La première promotion annuelle alimentera cet historique.</div>'}
 </div>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Effectif professionnel</div><h2>Joueurs sous contrat</h2></div><button class="ghost" onclick="nav('contracts')">Contrats</button></div>
 <div class="stack">${roster.map(r=>{const p=r.players||{};return `<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">${esc(r.squad_role||'Académie')}</div><h2>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</h2><div class="muted mini">ATP #${fmt(p.ranking||2001)} · ${starRatingHtml(abilityStarValue(p.current_ability||0),'Niveau')} / ${starRatingHtml(abilityStarValue(p.potential||0),'Potentiel')} · ${p.age||'—'} ans</div></div><span class="badge ${p.injury_status==='Fit'?'good':'bad'}">${esc(p.injury_status||'Fit')}</span></div>
 <div class="grid g3" style="margin-top:10px"><div class="kpi"><span class="muted mini">Contrat</span><b style="font-size:13px">${df(r.contract_end)}</b></div><div class="kpi"><span class="muted mini">Coût / sem.</span><b>${euro(r.weekly_cost)}</b></div><div class="kpi"><span class="muted mini">Forme</span><b>${p.form||'—'}</b></div></div>
 <div class="row" style="margin-top:10px;flex-wrap:wrap"><button class="primary" onclick="event.stopPropagation();trainAcademyPlayer(${p.id})">Entraîner</button><select class="select" style="width:auto" onchange="setAcademyFocus(${r.id},this.value)">${focuses.map(x=>`<option ${x===r.development_focus?'selected':''}>${x}</option>`).join('')}</select><button class="soft-btn" onclick="renewAcademyPlayer(${r.id})">Renouveler +1 an</button>${r.squad_role!=='Joueur principal'?`<button class="danger-btn" onclick="releaseAcademyPlayer(${r.id},'${esc(p.name||'Joueur')}')">Libérer</button>`:''}</div></div>`}).join('')||'<div class="card empty">Aucun joueur sous contrat.</div>'}</div>

 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Installations</h2>${(boot.facilities||[]).map(f=>`<div class="list-item row between"><span>${esc(f.name)}</span><div class="row"><b>Niveau ${facilityLevel(f)}/5</b><button class="soft-btn" onclick="upgradeFacility(${f.id},'${esc(f.name)}',${f.level})">Améliorer</button></div></div>`).join('')}</div>
  <div class="card"><h2>Objectifs du board</h2>${(boot.board||[]).map(o=>`<div class="list-item"><div class="row between"><b>${esc(o.objective)}</b><span>${o.progress}%</span></div><div class="bar"><i style="width:${o.progress}%"></i></div></div>`).join('')}</div>
 </div>`;
}

window.setAcademySetting=async(field,value)=>{try{await managerAction('academy_setting',0,{field,value});boot=await get('/api/bootstrap');render()}catch(e){alert(e.message)}}
window.assignHeadOfYouth=async()=>{
 const select=document.getElementById('academyHeadSelect');
 const id=Number(select?.value||0);
 if(!id){alert('Choisis un membre du staff.');return}
 try{
  await managerAction('assign_head_of_youth',id);
  boot=await get('/api/bootstrap');await loadManagement();render();
 }catch(e){alert(e.message)}
}
window.decideYouthPathway=async(id,decision)=>{
 const question=decision==='ncaa'?'Envoyer ce jeune vers la NCAA ?':decision==='release'?'Libérer ce jeune de l’académie ?':'Lancer son passage professionnel ?';
 if(!confirm(question))return;
 try{
  const d=await managerAction('academy_pathway',id,{decision});
  boot=await get('/api/bootstrap');await loadManagement();
  alert(decision==='ncaa'?'Destination : '+d.destination:decision==='release'?'Le jeune a été libéré.':'Passage pro confirmé.');
  render();
 }catch(e){alert(e.message)}
}

window.setAcademyFocus=async(id,focus)=>{try{await managerAction('academy_focus',id,{focus});await loadManagement();render()}catch(e){alert(e.message)}}
window.renewAcademyPlayer=async id=>{try{await managerAction('renew_academy_player',id);await loadManagement();render()}catch(e){alert(e.message)}}
window.releaseAcademyPlayer=async(id,name)=>{if(!confirm('Libérer '+name+' de l’académie ?'))return;try{await managerAction('release_academy_player',id);await loadManagement();render()}catch(e){alert(e.message)}}
async function loadTrainingPreview(force=false){
 if(trainingPreviewLoading)return trainingPreview;
 if(trainingPreview&&!force)return trainingPreview;
 trainingPreviewLoading=true;
 try{
  trainingPreview=await get('/api/training-preview',{
   method:'POST',
   headers:{'Content-Type':'application/json'},
   body:JSON.stringify({training:local.training})
  });
  return trainingPreview;
 }catch(e){
  trainingPreview={error:e.message};
  return trainingPreview;
 }finally{
  trainingPreviewLoading=false;
 }
}
function training(){
 const sessions=['Service','Retour','Coup droit','Revers','Déplacements','Endurance','Match play','Double','Récupération','Repos'];
 const p=trainingPreview&&!trainingPreview.error?trainingPreview:null;
 const load=p?.load??trainingLoad();
 const min=p?.recommended_load?.min??9,max=p?.recommended_load?.max??12;
 const inRange=load>=min&&load<=max;
 const risk=String(p?.risk||((career().fatigue||18)>=65?'Élevé':(career().fatigue||18)>=50?'Modéré':'Maîtrisé'));
 const riskClass=risk==='Élevé'?'bad':risk==='Modéré'?'warn':'good';
 const mult=p?.multiplier!=null?Number(p.multiplier):null;
 const dev=p?.development||{};
 const topTargets=(p?.targets||[]).slice(0,5);
 const report=local.lastTrainingReport||null;
 const reportLabels={serve_power:'Puissance service',serve_precision:'Précision service',first_serve_quality:'1re balle',second_serve_quality:'2e balle',serve_variety:'Variété service',serve_spin:'Effet service',serve_consistency:'Régularité service',serve_plus_one:'Service +1',return_game:'Retour',return_aggression:'Retour agressif',return_consistency:'Régularité retour',counter_skill:'Contre',shot_control:'Contrôle de balle',timing:'Timing',forehand:'Coup droit',forehand_power:'Puissance CD',forehand_accuracy:'Précision CD',forehand_consistency:'Régularité CD',topspin:'Lift',backhand:'Revers',backhand_power:'Puissance revers',backhand_accuracy:'Précision revers',backhand_consistency:'Régularité revers',volley:'Volée',touch:'Toucher',movement:'Déplacements',speed:'Vitesse',acceleration:'Accélération',agility:'Agilité',balance:'Équilibre',footwork:'Jeu de jambes',athleticism:'Capacités physiques',stamina:'Endurance',strength:'Force',recovery:'Récupération',tactics:'Tactique',decision_making:'Décisions',shot_selection:'Choix de coups',big_points:'Points importants',concentration:'Concentration',composure:'Sang-froid',fighting_spirit:'Combativité',tenacity:'Ténacité',doubles:'Double',net_positioning:'Placement filet',doubles_communication:'Communication double',poaching:'Interceptions'};
 return `<div class="section-head"><div><div class="eyebrow">Performance · development-v3</div><h1>Entraînement hebdomadaire</h1><div class="muted">Chaque séance est pondérée par l’âge, le potentiel, la personnalité de développement, le staff, les installations, la fatigue et l’orientation simple/double.</div></div><button class="soft-btn" onclick="refreshTrainingPreview()">↻ Réanalyser</button></div>
 ${trainingPreviewLoading?'<div class="card"><div class="loader">Analyse du plan par le staff…</div></div>':''}
 ${trainingPreview?.error?`<div class="card"><span class="badge bad">Analyse indisponible</span><div class="muted" style="margin-top:8px">${esc(trainingPreview.error)}</div></div>`:''}
 <div class="grid g3">
  <div class="card"><div class="eyebrow">Charge</div><div class="big">${load}</div><div class="muted">Conseillé : ${min}–${max}</div><div style="margin-top:8px"><span class="badge ${inRange?'good':'warn'}">${inRange?'Zone optimale':'À ajuster'}</span></div></div>
  <div class="card"><div class="eyebrow">Risque physique</div><div class="big">${esc(risk)}</div><div style="margin-top:8px"><span class="badge ${riskClass}">Fatigue ${p?.fatigue??career().fatigue??18}% · forme ${p?.fitness??career().fitness??90}%</span></div></div>
  <div class="card"><div class="eyebrow">Qualité progression</div><div class="big">${mult==null?'—':'×'+mult.toFixed(2)}</div><div class="muted">Staff ${p?.staff_score??Math.round((boot.staff||[]).reduce((a,x)=>a+x.skill,0)/Math.max(1,(boot.staff||[]).length))}/20 · installations ${p?.facility_score??'—'}</div></div>
 </div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><div class="row between"><div><div class="eyebrow">Plan de la semaine</div><h2>7 jours</h2></div><span class="pill">${esc(p?.player_name||career().player_name||'Joueur')} · ${p?.age??career().age??'—'} ans</span></div><div class="stack" style="margin-top:10px">${local.training.map((x,i)=>`<div class="list-item row between"><div><b>Jour ${i+1}</b><div class="muted mini">${i<5?'Séance principale':'Week-end'}</div></div><select class="select" style="width:auto" onchange="setTraining(${i},this.value)">${sessions.map(s=>`<option ${s===x?'selected':''}>${s}</option>`).join('')}</select></div>`).join('')}</div></div>
  <div class="card"><div class="row between"><div><div class="eyebrow">Profil de développement</div><h2>${esc(dev.type||'standard')}</h2></div>${dev.phase?`<span class="badge good">${esc(dev.phase)}</span>`:''}</div>
   <div class="kpi-strip" style="margin-top:10px">
    <div class="kpi"><span class="muted micro">Niveau</span><b>${p?starRatingHtml(p.current_stars):'—'}</b><small class="muted micro">CA ${p?.current_ability??career().current_ability??'—'}</small></div>
    <div class="kpi"><span class="muted micro">Potentiel</span><b>${p?starRatingHtml(p.potential_stars):'—'}</b><small class="muted micro">Évaluation interne</small></div>
   </div>
   <div class="list-item row between"><span>Vitesse de développement</span><b>${dev.development_rate??'—'}/20</b></div>
   <div class="list-item row between"><span>Professionnalisme</span><b>${dev.professionalism??'—'}/20</b></div>
   <div class="list-item row between"><span>Réceptivité au coaching</span><b>${dev.coachability??'—'}/20</b></div>
   <div class="list-item row between"><span>Résilience</span><b>${dev.resilience??'—'}/20</b></div>
   <div class="list-item row between"><span>Discipline</span><b>${dev.discipline??'—'}/20</b></div>
   <div class="list-item row between"><span>Drive compétitif</span><b>${dev.competitive_drive??'—'}/20</b></div>
   <div class="list-item row between"><span>Pic théorique</span><b>${dev.peak_age??'—'} ans</b></div>
   <div class="list-item row between"><span>Déclin à partir de</span><b>${dev.decline_start_age??'—'} ans</b></div>
  </div>
 </div>
 ${topTargets.length?`<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Rendement estimé</div><h2>Meilleures séances pour ce joueur</h2></div><span class="badge">Orientation ${esc(p?.career_focus||career().career_focus||'mixed')}</span></div><div class="stack" style="margin-top:8px">${topTargets.map((t,i)=>`<div class="list-item row between"><span><b>#${i+1} ${esc(t.session)}</b></span><span class="badge ${i<2?'good':''}">indice ${Number(t.score).toFixed(2)}</span></div>`).join('')}</div></div>`:''}
 ${p?.warnings?.length?`<div class="card" style="margin-top:12px"><div class="eyebrow">Alertes du staff</div><h2>À surveiller</h2><div class="stack" style="margin-top:8px">${p.warnings.map(w=>`<div class="list-item"><span class="badge warn">!</span> ${esc(w)}</div>`).join('')}</div></div>`:''}
 ${report?`<div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Dernière semaine simulée</div><h2>Bilan d’entraînement</h2></div><span class="badge good">${report.attribute_improvements??(report.improvements||[]).length} attribut(s) amélioré(s)</span></div>
  ${(report.improvements||[]).length?`<div class="grid g3" style="margin-top:10px">${report.improvements.slice(0,9).map(x=>`<div class="statbox"><span class="muted mini">${esc(reportLabels[x.attribute]||x.attribute)}</span><b>${x.from} → ${x.to}</b></div>`).join('')}</div>`:'<div class="muted">Pas de +1 visible cette semaine. L’XP est conservée pour les prochaines séances.</div>'}
  ${report.xp_gains?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px">${Object.entries(report.xp_gains).sort((a,b)=>Number(b[1])-Number(a[1])).slice(0,6).map(([a,v])=>`<span class="badge">${esc(reportLabels[a]||a)} +${Number(v).toFixed(2)} XP</span>`).join('')}</div>`:''}
  <div class="muted mini" style="margin-top:10px">Le niveau global et les étoiles sont recalculés par le cycle mensuel. Pas de +1 CA automatique chaque semaine.</div>
 </div>`:''}`
}
function trainingLoad(){return local.training.reduce((a,s)=>a+(['Endurance','Match play','Déplacements'].includes(s)?3:['Service','Retour','Coup droit','Revers','Double'].includes(s)?2:s==='Récupération'?0:-1),0)}
window.refreshTrainingPreview=async()=>{trainingPreview=null;await loadTrainingPreview(true);render()}
window.setTraining=async(i,v)=>{local.training[i]=v;trainingPreview=null;persist();render();await loadTrainingPreview(true);render()}
function scouting(){
 const shortlist=management?.shortlist||[];
 const reports=boot.scoutingReports||[];
 const missions=['U23 potentiel','Top 300 immédiat','Serveurs puissants','Spécialistes terre battue','Double & volée','NCAA / université'];
 const scoutingRegions=['France','Europe de l’Ouest','Europe de l’Est','Amérique du Nord','Amérique du Sud','Afrique','Asie','Océanie','NCAA / USA','Monde'];
 const ownScouts=(boot.staff||[]).filter(s=>Number(s.profile?.scouting_rating||0)>0).sort((a,b)=>Number(b.profile?.scouting_rating||0)-Number(a.profile?.scouting_rating||0));
 const academyPlayerIds=new Set((management?.academyRoster||[]).map(x=>Number(x.player_id||x.players?.id||0)).filter(Boolean));
 return `<div class="section-head"><div><div class="eyebrow">Recrutement</div><h1>Scouting</h1><div class="muted">Missions régionales, recruteurs réels de ton staff, précision des rapports et shortlist.</div></div><button class="primary" onclick="nav('players')">Chercher joueur</button></div>
 <div class="grid g3">${(boot.scouting||[]).map(s=>{const sp=s.staff||null;const missionReports=reports.filter(r=>Number(r.assignment_id)===Number(s.id));return `<div class="card">
  <div class="row between"><div><div class="eyebrow">${esc(s.region)}</div><h2>${esc(sp?.name||s.scout_name||'Réseau scouting')}</h2><div class="muted mini">Scouting ${sp?.scouting_rating??'—'}/20 · réputation ${sp?.reputation??'—'}/20</div></div><span class="badge ${s.status==='completed'?'good':Number(s.progress)>=75?'warn':''}">${esc(s.status)}</span></div>
  <div class="list-item"><span class="muted mini">Zone suivie</span><select id="scoutRegion_${s.id}" class="select" onchange="changeScoutAssignment(${s.id},document.querySelector('[data-scout-focus=\'${s.id}\']')?.value||'${esc(s.focus)}',document.getElementById('scoutStaff_${s.id}')?.value,this.value)">${scoutingRegions.map(r=>`<option ${r===s.region?'selected':''}>${r}</option>`).join('')}</select></div>
  <div class="list-item"><span class="muted mini">Mission</span><select class="select" onchange="changeScoutAssignment(${s.id},this.value,document.getElementById('scoutStaff_${s.id}')?.value,document.getElementById('scoutRegion_${s.id}')?.value)">${missions.map(m=>`<option ${m===s.focus?'selected':''}>${m}</option>`).join('')}</select></div>
  <div class="list-item"><span class="muted mini">Recruteur affecté</span><select id="scoutStaff_${s.id}" class="select" onchange="changeScoutAssignment(${s.id},document.querySelector('[data-scout-focus=\'${s.id}\']')?.value||'${esc(s.focus)}',this.value,document.getElementById('scoutRegion_${s.id}')?.value)">${ownScouts.map(x=>`<option value="${x.profile?.id||''}" ${Number(x.profile?.id)===Number(s.staff_profile_id)?'selected':''}>${esc(x.profile?.name||x.name||x.role)} · ${x.profile?.scouting_rating||0}/20</option>`).join('')}</select></div>
  <input data-scout-focus="${s.id}" type="hidden" value="${esc(s.focus||'')}">
  <div class="bar" style="margin-top:12px"><i style="width:${s.progress}%"></i></div>
  <div class="row between mini muted" style="margin-top:5px"><span>${s.progress}% · confiance ${s.confidence??50}%</span><span>${s.eta_date?'ETA '+df(s.eta_date):''}</span></div>
  <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge">Qualité ${s.report_quality??50}/100</span>${sp?.burnout>=60?`<span class="badge bad">Scout fatigué ${sp.burnout}/100</span>`:''}${missionReports.length?`<span class="badge good">${missionReports.length} rapport(s)</span>`:''}</div>
 </div>`}).join('')}</div>
 ${reports.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Rapports terminés</div><h2>Joueurs détectés</h2><div class="muted">Les fourchettes CA/PA dépendent du niveau du recruteur. Elles ne révèlent pas la valeur réelle exacte.</div></div><span class="pill">${reports.length} rapports</span></div>
 <div class="grid g2">${reports.slice(0,24).map(r=>{const p=r.player||{},already=academyPlayerIds.has(Number(p.id)),age=Number(p.age||99),canRecruit=!already&&age<=21&&!p.ncaa_current&&Number(r.confidence||0)>=60;return `<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><div><div class="eyebrow">${esc(r.recommendation||'Rapport')}</div><h2>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</h2><div class="muted mini">ATP/Monde #${fmt(p.game_world_rank||p.ranking||0)} · ${p.age??'—'} ans · ${esc(r.archetype_read||r.style_read||p.style||'')}</div></div><span class="badge ${Number(r.confidence)>=85?'good':Number(r.confidence)>=70?'warn':''}">${esc(r.knowledge_level||'Rapport')} · ${r.confidence}%</span></div><div class="kpi-strip" style="margin-top:9px"><div class="kpi"><span class="muted micro">Niveau</span><b>${starRatingHtml(r.estimated_current_stars??abilityStarValue((Number(r.estimated_ca_min)+Number(r.estimated_ca_max))/2))}</b><small class="muted micro">${r.estimated_ca_min}–${r.estimated_ca_max}</small></div><div class="kpi"><span class="muted micro">Potentiel</span><b>${starRatingHtml(r.estimated_potential_stars??abilityStarValue((Number(r.estimated_pa_min)+Number(r.estimated_pa_max))/2))}</b><small class="muted micro">${r.estimated_potential_star_min??'?'}–${r.estimated_potential_star_max??'?'} ★</small></div></div><div class="row" style="gap:5px;flex-wrap:wrap;margin-top:8px"><span class="badge">${esc(r.personality_read||'Personnalité ?')}</span><span class="badge">${esc(r.development_type_read||'Courbe ?')}</span><span class="badge">${esc(r.injury_risk_read||'Risque ?')}</span>${(r.strengths||[]).slice(0,4).map(x=>`<span class="badge good">${esc(x)}</span>`).join('')}${(r.weaknesses||[]).slice(0,3).map(x=>`<span class="badge bad">${esc(x)}</span>`).join('')}</div><div class="muted micro" style="margin-top:7px">${esc(r.trajectory_read||'')}</div><div class="row" style="margin-top:10px;gap:6px;flex-wrap:wrap">${already?'<span class="badge good">Déjà dans l’académie</span>':p.ncaa_current?'<span class="badge tag-ncaa">Joueur NCAA · filière universitaire</span>':age>21?'<span class="badge">Hors filière académie U21</span>':Number(r.confidence||0)<60?'<span class="badge warn">Connaissance insuffisante pour approcher</span>':canRecruit?`<button class="primary" onclick="event.stopPropagation();recruitScoutedPlayer(${Number(p.id)},${Number(r.id)})">Approcher pour l’académie</button>`:''}</div></div>`}).join('')}</div>`:''}
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Shortlist</h2>${shortlist.length?shortlist.map(s=>`<div class="list-item row between click" onclick="openPlayer(${s.players?.id})"><div><b>${flags[s.players?.country]||'🏳️'} ${esc(s.players?.name||'Joueur')}</b><div class="muted mini">ATP #${s.players?.ranking||'—'} · potentiel ${(()=>{const r=reports.find(x=>Number(x.player_id)===Number(s.players?.id));return r?starRatingHtml(Number(r.estimated_potential_stars||0)):'? ★'})()}</div></div><span class="badge">${esc(s.priority||'Normal')}</span></div>`).join(''):'<div class="empty">Aucun joueur suivi. Ajoute-en depuis un profil.</div>'}</div>
  <div class="card"><h2>Prospects académie</h2><div class="table-wrap"><table class="table"><thead><tr><th>Joueur</th><th>Âge</th><th>Potentiel</th></tr></thead><tbody>${(boot.youth||[]).map(y=>`<tr class="click" onclick="openYouth(${y.id})"><td><b>${esc(y.name)}</b></td><td>${y.age}</td><td class="a-good"><b>${starRatingHtml(abilityStarValue(y.potential||0),'Potentiel académie')}</b></td></tr>`).join('')}</tbody></table></div></div>
 </div>`
}
window.changeScoutAssignment=async(id,focus,scoutProfileId,region)=>{try{await managerAction('set_scouting_assignment',id,{focus,region,scout_profile_id:Number(scoutProfileId||0)||null});boot=await get('/api/bootstrap');render()}catch(e){alert(e.message)}}
window.recruitScoutedPlayer=async(playerId,reportId)=>{
 if(!confirm('Proposer un contrat académie à ce joueur ?'))return;
 try{
  const d=await managerAction('recruit_scouted_player',Number(playerId),{report_id:Number(reportId)});
  if(local.career)local.career.budget=d.budget;
  boot=await get('/api/bootstrap');
  await Promise.allSettled([loadManagement(),loadCareerHub(true)]);
  alert((d.already?'Déjà dans l’académie : ':'Recrutement confirmé : ')+(d.player_name||'joueur')+(d.signing_cost!=null?' · prime '+euro(d.signing_cost):''));
  render();
 }catch(e){alert(e.message)}
}

function competitionPrestige(p){
 const n=Number(p||50);return Math.max(1,Math.min(5,Math.round(n/20)));
}
function competitionsPage(){
 const circuits=['Tous','ATP','Challenger','ITF','Junior','NCAA','Federation'];
 const cats=['Toutes','Grand Chelem','ATP Finals','Masters 1000','ATP 500','ATP 250','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15','Junior Grand Slam','NCAA DI Team Championship','NCAA DI Individual Championship'];
 const surfaces=['Toutes','Dur extérieur','Dur intérieur','Terre','Gazon'];
 const start=competitionCount?competitionOffset+1:0,end=Math.min(competitionOffset+competitionRows.length,competitionCount);
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Competition database · FM style</div><h1>Compétitions</h1><div class="muted">Une fiche permanente par tournoi : prestige, tenant du titre, éditions, palmarès annuel, finalistes et records. Le Calendrier reste dédié aux inscriptions.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(competitionCount)} compétitions</div><div class="fm-head-badge subtle">Open Era</div><button class="soft-btn" onclick="nav('calendar')">Calendrier →</button></div></div>
  <div class="card fm-db-toolbar">
   <div class="fm-db-filters">
    <input class="input" value="${esc(competitionFilters.q)}" placeholder="Rechercher une compétition…" onkeydown="if(event.key==='Enter')setCompetitionFilter('q',this.value)">
    <select class="select" onchange="setCompetitionFilter('circuit',this.value)">${circuits.map(x=>`<option ${x===competitionFilters.circuit?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('category',this.value)">${cats.map(x=>`<option ${x===competitionFilters.category?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('surface',this.value)">${surfaces.map(x=>`<option ${x===competitionFilters.surface?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('country',this.value)"><option value="">Tous pays</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${competitionFilters.country===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('prestige',this.value)">${['Tous','5 étoiles','4+ étoiles','3+ étoiles'].map(x=>`<option ${x===competitionFilters.prestige?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('history',this.value)">${['Tous','Avec historique','Sans historique'].map(x=>`<option ${x===competitionFilters.history?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('holder',this.value)">${['Tous','Avec tenant','Sans tenant'].map(x=>`<option ${x===competitionFilters.holder?'selected':''}>${x}</option>`).join('')}</select>
    <select class="select" onchange="setCompetitionFilter('source',this.value)">${['Tous','Officiel','Fictif'].map(x=>`<option ${x===competitionFilters.source?'selected':''}>${x}</option>`).join('')}</select>
    <button class="primary" onclick="loadCompetitions().then(render)">Filtrer</button>
   </div>
  </div>
  <div class="card fm-panel" style="margin-top:12px">
   <div class="row between"><div><div class="eyebrow">Base compétitions</div><h2>${competitionFilters.circuit==='Tous'?'Toutes les compétitions':esc(competitionFilters.circuit)}</h2></div><span class="pill">${fmt(competitionCount)}</span></div>
   ${competitionLoading?'<div class="loader">Chargement des compétitions…</div>':`<div class="table-wrap"><table class="table fm-competition-table"><thead><tr><th></th><th>Compétition</th><th>Niveau</th><th>Surface</th><th>Prestige</th><th>Tenant</th><th>Historique</th><th>Prochaine édition</th></tr></thead><tbody>${competitionRows.map(t=>`<tr class="click" onclick="openCompetition(${t.id})"><td>${tournamentThumb(t)}</td><td><b>${flags[t.country]||'🏳️'} ${esc(t.name)}</b><div class="muted micro">${esc(t.city||'')} · ${t.is_verified?'<span class="badge good">Officiel</span>':'<span class="badge">Fictif</span>'}</div></td><td><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.circuit)}</span></td><td><span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span></td><td><b class="competition-stars">${'★'.repeat(competitionPrestige(t.prestige))}${'☆'.repeat(5-competitionPrestige(t.prestige))}</b><div class="muted micro">${fmt(t.prestige||50)}/100</div></td><td>${t.defending_champion_name?`<b>${esc(t.defending_champion_name)}</b><div class="muted micro">${t.defending_champion_year||2025}</div>`:'<span class="muted">Aucun tenant connu</span>'}</td><td><b>${fmt(t.history_count||0)} finale(s)</b><div class="muted micro">${t.latest_history?'Dernier : '+esc(t.latest_history.winner_name):'À enrichir'}</div></td><td><b>${df(t.start_date)}</b><div class="muted micro">${esc(t.country||'')}</div></td></tr>`).join('')}</tbody></table></div>`}
   ${!competitionLoading&&!competitionRows.length?'<div class="empty">Aucune compétition avec ces filtres.</div>':''}
   <div class="pagination"><button ${competitionOffset===0?'disabled':''} onclick="competitionPage(-1)">←</button><span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(competitionCount)}</span><button ${competitionOffset+100>=competitionCount?'disabled':''} onclick="competitionPage(1)">→</button></div>
  </div>
 </div>`;
}
window.setCompetitionFilter=async(k,v)=>{competitionFilters[k]=v;competitionOffset=0;await loadCompetitions();render()}
window.competitionPage=async d=>{competitionOffset=Math.max(0,competitionOffset+d*100);await loadCompetitions();render();window.scrollTo(0,0)}
window.openCompetition=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement de la compétition…</div></div></div>';
 try{
  const d=await get('/api/competition?id='+id),t=d.tournament,h=d.history||[],records=d.records||[];
  const image=tournamentPhotoUrl(t);
  const photoLabel=t.image_source_label||'Photo du tournoi';
  const holder=t.defending_champion_name||h[0]?.winner_name||null;
  const holderId=t.defending_champion_player_id||h[0]?.winner_player_id||null;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet competition-sheet">
   <div class="sheet-head"><div class="tm-title-with-logo">${tournamentLogoHtml(t,'tm-detail-logo')}<div><div class="eyebrow">Fiche compétition · ${esc(t.circuit||'Tour')}</div><h1>${flags[t.country]||'🏳️'} ${esc(t.name)}</h1><div class="muted">${esc(t.city||'')} · ${esc(t.category||'')} · ${esc(surfaceLabel(t))}</div></div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="competition-hero" style="margin-top:12px"><div class="competition-cover"><img src="${esc(image)}" alt="${esc(t.name)}" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'"><div class="tm-tour-fallback competition-fallback" style="display:none">${flags[t.country]||'🎾'}<small>${esc(t.city||'')}</small></div><span class="tm-photo-label">${esc(photoLabel)}</span></div><div class="competition-main"><div class="row between"><div><div class="eyebrow">Prestige</div><div class="competition-stars big-stars">${'★'.repeat(competitionPrestige(t.prestige))}${'☆'.repeat(5-competitionPrestige(t.prestige))}</div></div><span class="badge ${t.is_verified?'good':''}">${t.is_verified?'Compétition officielle':'Compétition fictive'}</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Tenant</span><b class="${holderId?'click':''}" ${holderId?`onclick="openPlayer(${holderId})"`:''}>${holder?esc(holder):'—'}</b></div><div class="kpi"><span class="muted mini">Points vainqueur</span><b>${t.winner_points!=null?fmt(t.winner_points):'—'}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${t.prize_money!=null?tournamentPrizeLabel(t):'—'}</b></div><div class="kpi"><span class="muted mini">Historique</span><b>${d.historyStart&&d.historyEnd?d.historyStart+'–'+d.historyEnd:'—'}</b></div></div></div></div>
   <div class="tabs" style="margin-top:12px"><button class="active" data-comp-tab="overview" onclick="competitionSection('overview')">Vue d'ensemble</button><button data-comp-tab="history" onclick="competitionSection('history')">Palmarès</button><button data-comp-tab="records" onclick="competitionSection('records')">Records</button><button data-comp-tab="editions" onclick="competitionSection('editions')">Éditions</button></div>
   <div id="competitionBody">
    <section data-comp-section="overview"><div class="grid g2"><div class="card"><h2>Identité</h2><div class="list-item row between"><span>Niveau</span><b>${esc(t.category||t.level||'—')}</b></div><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Lieu</span><b>${esc(t.city||'—')}, ${esc(t.country||'')}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.singles_draw_size||t.draw_size||'—'}</b></div><div class="list-item row between"><span>Double</span><b>${t.doubles?t.doubles_draw_size||'Oui':'Non'}</b></div></div><div class="card"><h2>Édition ${String(t.start_date||'').slice(0,4)}</h2><div class="list-item row between"><span>Dates</span><b>${df(t.start_date)} → ${df(t.end_date||t.start_date)}</b></div><div class="list-item row between"><span>Tenant simple</span><b>${holder?esc(holder):'—'}</b></div><div class="list-item row between"><span>Tenant double</span><b>${t.defending_doubles_champion_name?esc(t.defending_doubles_champion_name)+(t.defending_doubles_partner_name?' / '+esc(t.defending_doubles_partner_name):''):'—'}</b></div><div class="list-item row between"><span>Source</span><b>${t.source_url?'<a href="'+esc(t.source_url)+'" target="_blank" rel="noopener">Officielle ↗</a>':'Simulation Court Boss'}</b></div></div></div></section>
    <section data-comp-section="history" style="display:none"><div class="card"><div class="row between"><div><div class="eyebrow">Finales</div><h2>Palmarès année par année</h2></div><span class="pill">${h.length} éditions</span></div>${h.length?`<div class="table-wrap"><table class="table"><thead><tr><th>Année</th><th>Vainqueur</th><th>Finaliste</th><th>Score</th><th>Surface</th></tr></thead><tbody>${h.map(x=>`<tr><td class="rank-num">${x.season}</td><td class="${x.winner_player_id?'click':''}" ${x.winner_player_id?`onclick="openPlayer(${x.winner_player_id})"`:''}><b>${flags[x.winner_country]||''} ${esc(x.winner_name)}</b></td><td class="${x.runner_up_player_id?'click':''}" ${x.runner_up_player_id?`onclick="openPlayer(${x.runner_up_player_id})"`:''}>${flags[x.runner_up_country]||''} ${esc(x.runner_up_name)}</td><td>${esc(x.score||'—')}</td><td>${esc(x.surface||'—')}</td></tr>`).join('')}</tbody></table></div>`:'<div class="empty">Historique en cours d’import.</div>'}</div></section>
    <section data-comp-section="records" style="display:none"><div class="card"><div class="row between"><div><div class="eyebrow">Open Era</div><h2>Records de la compétition</h2></div><span class="badge">${records.length} joueurs</span></div><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Titres</th><th>Finales</th></tr></thead><tbody>${records.map((r,i)=>`<tr class="${r.player_id?'click':''}" ${r.player_id?`onclick="openPlayer(${r.player_id})"`:''}><td class="rank-num">${i+1}</td><td><b>${esc(r.name)}</b></td><td><b>${r.wins}</b></td><td>${r.finals}</td></tr>`).join('')}</tbody></table></div></div></section>
    <section data-comp-section="editions" style="display:none"><div class="card"><h2>Éditions Court Boss</h2>${(d.editions||[]).map(x=>`<div class="list-item row between click" onclick="openCompetition(${x.id})"><div><b>${String(x.start_date||'').slice(0,4)} · ${esc(x.name)}</b><div class="muted mini">${df(x.start_date)} · ${esc(x.city||'')} · ${esc(surfaceLabel(x))}</div></div><span class="badge ${x.is_verified?'good':''}">${x.is_verified?'Officiel':'Fictif'}</span></div>`).join('')||'<div class="empty">Une seule édition référencée.</div>'}</div></section>
   </div>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="card"><h2>Compétition indisponible</h2><p class="muted">${esc(e.message)}</p></div></div></div>`}
}
window.competitionSection=name=>{document.querySelectorAll('[data-comp-section]').forEach(x=>x.style.display=x.getAttribute('data-comp-section')===name?'block':'none');document.querySelectorAll('[data-comp-tab]').forEach(x=>x.classList.toggle('active',x.getAttribute('data-comp-tab')===name))}
function more(){
 const items=[['players','Base joueurs',fmt(worldStats?.searchableRealPlayers||22000)+' profils réels · classement monde jusqu’au #30000 + ITF + Juniors + NCAA + Double'],['training','Entraînement','Planifier la semaine'],['scouting','Scouting','Réseau et prospects'],['staff','Staff','Coach, fitness, physio, agent'],['contracts','Contrats','Salaires et échéances'],['finance','Finances','Budget et dépenses'],['medical','Médical','Blessures, fatigue, récupération'],['match','Match Center','Historique et données match'],['tactics','Tactique','Plan de match & coaching'],['fantasy','Fantasy Court','Créer un tournoi personnalisé'],['doubles','Double','Partenaires et compatibilité'],['university','Universitaire','NCAA / ITA'],['davis','Coupe Davis','Choisir et gérer une fédération'],['board','Board','Objectifs et confiance'],['world','Monde','Circuits et profondeur'],['competitions','Compétitions','Fiches, palmarès et records des tournois'],['history','Histoire & nations','Légendes par pays et continent'],['myplayer','Mon joueur','Identité, style et carrière'],['careerhub','Bureau manager','Saison, sponsors, relations, médias et journal'],['season','Saison','Planification, charge et objectifs'],['relationships','Relations','Affinités, rivalités et double'],['media','Médias','Actualité de ta carrière'],['inbox','Boîte de réception','Décisions et alertes'],['saves','Sauvegardes','Autosave, slots manuels & reprise de carrière'],['launcher','Menu carrière','Continuer, charger ou démarrer une nouvelle partie'],['diagnostics','Diagnostic','Santé du Career OS']];
 return `<div class="section-head"><div><div class="eyebrow">Centre manager</div><h1>Tous les modules</h1></div></div><div class="grid g2">${items.map(x=>`<div class="card click" onclick="nav('${x[0]}')"><div class="eyebrow">${x[1]}</div><h2>${x[2]}</h2></div>`).join('')}</div>`
}
function playersPage(){
 if(!dbLoaded&&!dbLoading)setTimeout(()=>loadPlayerDatabase().then(()=>{if(route==='players')render()}).catch(()=>{}),0);
 const circuits=['Tous','Tous réels','ATP classés','ATP profond','ITF','Junior','Junior Double','NCAA','Double','Race','Next Gen'];
 const start=dbCount?dbOffset+1:0,end=Math.min(dbOffset+dbRows.length,dbCount);
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Scouting database · ${fmt(worldStats?.searchableRealPlayers||dbCount||20000)} profils réels</div><h1>Base joueurs mondiale</h1><div class="muted">Classement mondial jusqu’au #30000, puis recherche complète : ITF, NCAA, juniors, anciens joueurs et prospects réels.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(worldStats?.searchableRealPlayers||dbCount||20000)} joueurs</div><div class="fm-head-badge subtle">${fmt(worldStats?.realPlayersWithDob||0)} DOB sourcées</div><div class="fm-head-badge subtle">${fmt(worldStats?.estimatedAgeReal||0)} âges estimés</div></div></div>
  <div class="card fm-db-toolbar">
   <div class="fm-db-filters">
    <input id="dbSearch" class="input" value="${esc(dbQuery)}" placeholder="Nom du joueur…" onkeydown="if(event.key==='Enter')searchPlayerDatabase(this.value)">
    <select class="select" onchange="setDbCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${dbCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select>
    <select class="select" onchange="setDbCircuit(this.value)">${circuits.map(x=>`<option ${dbCircuit===x?'selected':''}>${x}</option>`).join('')}</select>
    <button class="primary" onclick="searchPlayerDatabase(document.getElementById('dbSearch').value)">Rechercher</button>
   </div>
   <div class="row" style="margin-top:9px;flex-wrap:wrap"><span class="badge good">ATP/ITF réels</span><span class="badge tag-ncaa">NCAA</span><span class="badge tag-junior">Junior</span><span class="badge">Double</span><span class="muted mini">Âge affiché partout : âge au 01/12/2025. Quand une donnée manque, Court Boss génère une valeur fictive stable (DOB jour/mois, taille, poids, main, revers, style) et la marque estimée. Les vraies données sourcées restent prioritaires.</span></div>
  </div>
  <div class="card fm-panel" style="margin-top:12px">
   <div class="row between"><div><div class="eyebrow">Résultats scouting</div><h2>${dbQuery?'Recherche : '+esc(dbQuery):dbCountry?'Nationalité '+esc(dbCountry):dbCircuit!=='Tous'?esc(dbCircuit):'Base complète'}</h2></div><span class="pill">${fmt(dbCount)} profils</span></div>
   ${dbLoading?'<div class="loader">Recherche dans la base…</div>':`<div class="table-wrap"><table class="table fm-db-table"><thead><tr><th>Joueur</th><th>Âge 01/12/25</th><th>Pays</th><th>ATP</th><th>Double</th><th>Junior Dbl</th><th>ITF</th><th>Revers</th><th>NCAA</th><th>Niveau</th><th>Potentiel</th></tr></thead><tbody>${dbRows.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td><b>${esc(p.name)}</b><div class="muted micro">${p.is_real?'Réel':'Newgen'}${p.style?' · '+esc(p.style):''}</div></td><td>${displayAge(p)==null?'<span class="muted">N/V</span>':`<span title="${esc(p.age_source||'')}">${esc(ageLabel(p,false))}</span>`}</td><td>${flags[p.country]||'🌐'} ${esc(p.country||'—')}</td><td>${p.ranking?'#'+fmt(p.ranking)+(p.ranking>2000?' <span class="muted micro">ATP profond</span>':''):'—'}</td><td>${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'—'}</td><td>${p.junior_doubles_ranking?'#'+fmt(p.junior_doubles_ranking):'—'}</td><td>${p.itf_ranking?'#'+fmt(p.itf_ranking):'—'}</td><td><span class="badge ${p.backhand_verified?'good':''}">${esc(p.backhand||'2 mains')}${p.backhand_verified?'':' · estimé'}</span></td><td>${p.ncaa_current?'<span class="badge tag-ncaa">'+esc(ncaaRankPresentation(p).compact)+'</span>':p.ncaa_verified?'<span class="badge">'+(p.ncaa_status==='Alumni'?'NCAA Alumni':'NCAA historique')+'</span>':'—'}</td><td>${(()=>{const own=Number(p.id)===Number(career().managed_player_id||0),r=(boot.scoutingReports||[]).find(x=>Number(x.player_id)===Number(p.id));return own?starRatingHtml(abilityStarValue(p.current_ability),'Niveau connu')+`<div class="muted micro">Connu</div>`:r?starRatingHtml(Number(r.estimated_current_stars||publicLevelStars(p)),'Rapport scout')+`<div class="muted micro">${r.estimated_ca_min}–${r.estimated_ca_max} · ${r.confidence}%</div>`:starRatingHtml(publicLevelStars(p),'Estimation publique')+`<div class="muted micro">Public</div>`})()}</td><td>${(()=>{const own=Number(p.id)===Number(career().managed_player_id||0),r=(boot.scoutingReports||[]).find(x=>Number(x.player_id)===Number(p.id));return own?starRatingHtml(abilityStarValue(p.potential),'Potentiel connu')+`<div class="muted micro">Dynamique</div>`:r?starRatingHtml(Number(r.estimated_potential_stars||0),'Potentiel scout')+`<div class="muted micro">${r.estimated_potential_star_min??'?'}–${r.estimated_potential_star_max??'?'} ★</div>`:'<span class="muted">À scout­er</span>'})()}</td></tr>`).join('')}</tbody></table></div>`}
   ${!dbLoading&&!dbRows.length?'<div class="empty">Aucun joueur trouvé avec ces filtres.</div>':''}
   <div class="pagination"><button ${dbOffset===0?'disabled':''} onclick="dbPage(-1)">←</button><span class="muted mini">${fmt(start)}–${fmt(end)} / ${fmt(dbCount)}</span><button ${dbOffset+100>=dbCount?'disabled':''} onclick="dbPage(1)">→</button></div>
  </div>
 </div>`
}
window.searchPlayerDatabase=async q=>{dbQuery=String(q||'').trim();dbOffset=0;await loadPlayerDatabase();render()}
window.setDbCountry=async c=>{dbCountry=String(c||'').toUpperCase();dbOffset=0;await loadPlayerDatabase();render()}
window.setDbCircuit=async c=>{dbCircuit=String(c||'Tous');dbOffset=0;await loadPlayerDatabase();render()}
window.dbPage=async d=>{dbOffset=Math.max(0,dbOffset+d*100);await loadPlayerDatabase();render();window.scrollTo(0,0)}

function staffFormerLabel(p){
 if(!p)return '';
 if(p.former_player_status==='yes'){
   if(p.verified)return 'Ancien joueur pro · sourcé';
   if(String(p.source_label||'').includes('reconversion dynamique'))return 'Ancien joueur Court Boss reconverti';
   return 'Ancien joueur probable · base simulée';
 }
 if(p.former_player_status==='no')return 'Spécialiste staff';
 return 'Parcours joueur non confirmé';
}
function staffMetaBadges(p){
 if(!p)return '';
 const langs=Array.isArray(p.languages)?p.languages.slice(0,3):[];
 return `<div class="row" style="gap:6px;flex-wrap:wrap">
  ${p.staff_personality?`<span class="badge">${esc(p.staff_personality)}</span>`:''}
  ${p.coaching_style?`<span class="badge">${esc(p.coaching_style)}</span>`:''}
  ${p.preferred_surface?`<span class="badge">${esc(p.preferred_surface)}</span>`:''}
  ${p.workload!=null?`<span class="badge ${Number(p.workload)>=85?'bad':Number(p.workload)>=70?'warn':'good'}">Charge ${p.workload}/100</span>`:''}
  ${p.energy!=null?`<span class="badge ${Number(p.energy)<45?'bad':Number(p.energy)<65?'warn':'good'}">Énergie ${p.energy}/100</span>`:''}
  ${p.burnout!=null&&Number(p.burnout)>0?`<span class="badge ${Number(p.burnout)>=70?'bad':Number(p.burnout)>=45?'warn':''}">Burnout ${p.burnout}/100</span>`:''}
  ${p.travel_fatigue!=null&&Number(p.travel_fatigue)>0?`<span class="badge">Voyage ${p.travel_fatigue}/100</span>`:''}
  ${langs.map(x=>`<span class="badge">${esc(x)}</span>`).join('')}
 </div>`;
}
function staffRatingGrid(p){
 if(!p)return '';
 const rows=[
  ['Coach',p.coach_rating],['Technique',p.technical_rating],['Tactique',p.tactical_rating],['Mental',p.mental_rating],
  ['Physique',p.fitness_rating],['Médical',p.medical_rating],['Scouting',p.scouting_rating],['Jeunes',p.youth_rating],
  ['Motivation',p.motivation_rating],['Communication',p.communication_rating],['Adaptation',p.adaptability_rating],['Réputation',p.reputation],
  ['Ambition',p.ambition],['Loyauté',p.loyalty],['Discipline',p.discipline],['Pression',p.pressure_handling],
  ['Négociation',p.negotiation_rating],['Professionnalisme',p.professionalism],['Développement',p.development_rating],
  ['Coach double',p.doubles_coaching_rating],['Service',p.serve_coaching_rating],['Retour',p.return_coaching_rating]
 ].filter(x=>x[1]!=null);
 return `<div class="kpi-strip staff-rating-grid">${rows.map(x=>`<div class="kpi"><span class="muted micro">${esc(x[0])}</span><b>${x[1]}/20</b><div class="bar"><i style="width:${Number(x[1])*5}%"></i></div></div>`).join('')}</div>`;
}

function staffWorldSection(){
 const d=staffWorldData||null;
 const rows=d?.rows||[],roles=d?.roles||[],countries=d?.countries||[];
 if(!d)return `<div class="card loader" style="margin-top:14px">Chargement de la base mondiale du staff…</div>`;
 return `<div class="section-head" style="margin-top:22px"><div><div class="eyebrow">Base mondiale</div><h2>Staff mondial</h2><div class="muted mini">Base complète paginée : coachs, kinés, préparateurs, recruteurs, agents et anciens joueurs reconvertis.</div></div><span class="pill">${fmt(d.total||0)} profils</span></div>
 <div class="card staff-world-filter"><div class="row" style="gap:8px;flex-wrap:wrap">
  <input id="staffWorldQ" value="${esc(staffWorldFilters.q||'')}" placeholder="Nom, spécialité, style…" style="flex:1;min-width:200px">
  <select id="staffWorldRole"><option value="">Tous les rôles</option>${roles.map(x=>`<option value="${esc(x.role)}" ${staffWorldFilters.role===x.role?'selected':''}>${esc(x.role)} (${fmt(x.count)})</option>`).join('')}</select>
  <select id="staffWorldCountry"><option value="">Tous les pays</option>${countries.map(x=>`<option value="${esc(x.country)}" ${staffWorldFilters.country===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} (${fmt(x.count)})</option>`).join('')}</select>
  <select id="staffWorldFormer"><option value="Tous">Tous parcours</option><option value="Oui" ${staffWorldFilters.former==='Oui'?'selected':''}>Anciens joueurs</option><option value="Non" ${staffWorldFilters.former==='Non'?'selected':''}>Spécialistes staff</option></select>
  <select id="staffWorldStatus"><option value="Tous">Tous statuts</option><option value="available" ${staffWorldFilters.status==='available'?'selected':''}>Disponibles</option><option value="contracted" ${staffWorldFilters.status==='contracted'?'selected':''}>Sous contrat</option><option value="user_staff" ${staffWorldFilters.status==='user_staff'?'selected':''}>Ton staff</option></select>
  <button class="primary" onclick="applyStaffWorldFilters()">Rechercher</button>
 </div></div>
 <div class="grid g3" style="margin-top:10px">
  <div class="card"><div class="eyebrow">Agences majeures</div>${(d.agencies||[]).slice(0,5).map(x=>`<div class="list-item"><div class="row between"><b>${esc(x.name)}</b><span class="badge">${x.reputation}/20</span></div><div class="muted micro">${flags[x.country]||'🏳️'} ${esc(x.specialty||'')} · ${fmt(x.members)} membres · réseau ${x.network_strength}/20</div></div>`).join('')}</div>
  <div class="card"><div class="eyebrow">Académies de coachs</div>${(d.academies||[]).slice(0,5).map(x=>`<div class="list-item"><div class="row between"><b>${esc(x.name)}</b><span class="badge">${x.prestige}/20</span></div><div class="muted micro">${flags[x.country]||'🏳️'} ${esc(x.specialty||'')} · ${fmt(x.members)} membres</div></div>`).join('')}</div>
  <div class="card"><div class="eyebrow">Instituts de formation</div>${(d.training_centers||[]).slice(0,5).map(x=>`<div class="list-item"><div class="row between"><b>${esc(x.name)}</b><span class="badge">${x.reputation}/20</span></div><div class="muted micro">${esc(x.specialty||'')} · ${fmt(x.active_enrollments)}/${fmt(x.capacity)} places actives</div></div>`).join('')}</div>
 </div>
 <div class="grid g2" style="margin-top:10px">${rows.map(x=>`<div class="card">
   <div class="row between"><div class="click" onclick="openStaffProfile(${x.id})"><div class="eyebrow">${esc(x.primary_role)}</div><h2>${flags[x.nationality]||'🏳️'} ${esc(x.name)}</h2><div class="muted mini">${esc(x.specialty||'')} · réputation ${x.reputation}/20</div></div><div class="progress-ring" style="--p:${Number(x.managed_fit||0)}"><b>${x.managed_fit??'—'}</b></div></div>
   <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge">${esc(staffFormerLabel(x))}</span><span class="badge">${esc(x.market_status||'')}</span>${x.top_license?`<span class="badge">${esc(x.top_license)}</span>`:''}</div>
   <div class="row between muted mini" style="margin-top:8px"><span>${esc(x.coaching_style||x.staff_personality||'Profil complet')}</span><span>${x.current_clients||0}/${x.max_clients||1} client(s)</span></div>
   ${x.agency_name?`<div class="muted micro" style="margin-top:5px">Agence : ${esc(x.agency_name)}</div>`:''}
   ${x.academy_name?`<div class="muted micro">Formation : ${esc(x.academy_name)}</div>`:''}
   <div class="row" style="gap:7px;margin-top:9px;flex-wrap:wrap"><button class="ghost" onclick="openStaffProfile(${x.id})">Dossier</button>${x.market_status==='available'?`<button class="primary" onclick="approachStaffProfile(${x.id})">Approcher</button>`:'<button class="ghost" disabled>Sous contrat</button>'}</div>
  </div>`).join('')||'<div class="card empty">Aucun profil ne correspond à ces filtres.</div>'}</div>
 <div class="row between" style="margin-top:10px"><button class="ghost" ${staffWorldOffset<=0?'disabled':''} onclick="staffWorldPage(-1)">← Précédent</button><span class="muted mini">${fmt(staffWorldOffset+1)}–${fmt(Math.min(staffWorldOffset+50,d.total||0))} / ${fmt(d.total||0)}</span><button class="ghost" ${staffWorldOffset+50>=Number(d.total||0)?'disabled':''} onclick="staffWorldPage(1)">Suivant →</button></div>`;
}
function staffPage(){
 const cand=management?.candidates||[];
 const roles=[...new Set(cand.map(x=>String(x.role||'')).filter(Boolean))].sort();
 const rels=management?.ownStaffRelations||[],agent=management?.managedAgency||null,agencyNetwork=management?.agencyNetwork||[],staffLeaders=management?.staffLeaders||[];
 const activeTraining=(management?.userStaffTraining||[]).filter(x=>x.status==='active');
 const trainingByProfile=new Map(activeTraining.map(x=>[Number(x.staff_profile_id),x]));
 const avgConflict=rels.length?Math.round(rels.reduce((s,x)=>s+Number(x.conflict_score||0),0)/rels.length):0;
 const avgAffinity=rels.length?Math.round(rels.reduce((s,x)=>s+Number(x.affinity||0),0)/rels.length):75;
 const highConflicts=rels.filter(x=>Number(x.conflict_score||0)>=60);
 return `<div class="section-head"><div><div class="eyebrow">Équipe</div><h1>Staff</h1><div class="muted">Coachs, préparateurs, kinés, analystes et recruteurs avec attributs 1–20 façon FM.</div></div></div>
 <div class="grid g2" style="margin-bottom:12px">
  <div class="card"><div class="row between"><div><div class="eyebrow">Cohésion staff</div><h2>Vestiaire technique</h2></div><span class="badge ${avgConflict>=60?'bad':avgConflict>=35?'warn':'good'}">${100-avgConflict}/100</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Affinité moyenne</span><b>${avgAffinity}</b></div><div class="kpi"><span class="muted micro">Conflit moyen</span><b>${avgConflict}</b></div><div class="kpi"><span class="muted micro">Tensions fortes</span><b>${highConflicts.length}</b></div></div>${highConflicts.slice(0,4).map(x=>`<div class="list-item"><div class="row between"><span>${esc(x.staff_a?.name||'Staff')} ↔ ${esc(x.staff_b?.name||'Staff')}</span><span class="badge bad">${x.conflict_score}/100</span></div><div class="row between" style="margin-top:5px"><div class="muted micro">${esc(x.relation_type||'Tension')} · rivalité ${x.rivalry||0}</div><button class="soft-btn" onclick="mediateStaffConflict(${x.staff_a_id},${x.staff_b_id})">Médiation</button></div></div>`).join('')||'<div class="muted mini" style="margin-top:8px">Aucune tension majeure dans ton équipe.</div>'}</div>
  <div class="card"><div class="row between"><div><div class="eyebrow">Agent & réseau</div><h2>${esc(agent?.agent?.name||'Aucun agent actif')}</h2></div><span class="badge">${agent?'Confiance '+(agent.trust??'—')+'/100':'À recruter'}</span></div>${agent?`<div class="list-item row between"><span>Agence</span><b>${esc(agent.agency?.name||'—')}</b></div><div class="list-item row between"><span>Commission</span><b>${agent.commission_pct??'—'}%</b></div><div class="list-item row between"><span>Négociation</span><b>${agent.agent?.negotiation_rating??'—'}/20</b></div><button class="ghost" onclick="openStaffProfile(${agent.agent?.id})">Voir le dossier agent</button>`:'<div class="empty">Recrute un agent dans le marché du staff pour débloquer un vrai réseau de représentation.</div>'}</div>
 </div>
 ${staffLeaders.length?`<div class="card" style="margin-bottom:12px">
  <div class="row between"><div><div class="eyebrow">Monde du staff</div><h2>Réputation & palmarès</h2><div class="muted mini">Indice Court Boss basé sur palmarès, réputation, niveau des clients et expertise.</div></div><span class="badge">Top ${Math.min(20,staffLeaders.length)}</span></div>
  <div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>#</th><th>Staff</th><th>Rôle</th><th>Score</th><th>Titres</th><th>GC</th><th>Meilleur client</th></tr></thead><tbody>
   ${staffLeaders.slice(0,20).map((x,i)=>`<tr class="click" onclick="openStaffProfile(${x.staff_profile_id})"><td><b>${i+1}</b></td><td><b>${flags[x.nationality]||'🏳️'} ${esc(x.name)}</b><div class="muted micro">réputation ${x.reputation}/20</div></td><td>${esc(x.primary_role||'Staff')}</td><td><b>${fmt(x.world_staff_score||0)}</b></td><td>${fmt(x.titles_total||0)}</td><td>${fmt(x.grand_slams||0)}</td><td>${x.best_client_rank?'#'+fmt(x.best_client_rank):'—'}</td></tr>`).join('')}
  </tbody></table></div>
 </div>`:''}
 ${agencyNetwork.length?`<div class="card" style="margin-bottom:12px">
  <div class="row between"><div><div class="eyebrow">Représentation mondiale</div><h2>Réseaux d’agents</h2></div><span class="badge">${agencyNetwork.reduce((s,x)=>s+Number(x.clients||0),0).toLocaleString('fr-FR')} clients</span></div>
  <div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>Agence</th><th>Clients</th><th>Agents</th><th>Top client</th><th>Réseau</th></tr></thead><tbody>
   ${agencyNetwork.slice(0,8).map(x=>`<tr><td><b>${esc(x.name)}</b><div class="muted micro">${esc(x.country||'INT')} · ${esc(x.specialty||'')}</div></td><td>${fmt(x.clients||0)}</td><td>${fmt(x.agents||0)}</td><td>#${fmt(x.top_client_rank||0)}</td><td>${x.network_strength}/20</td></tr>`).join('')}
  </tbody></table></div>
 </div>`:''}
 ${(management?.ownStaffOffers||[]).length?`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Marché</div><h2>Approches sur ton staff</h2></div><span class="badge warn">${management.ownStaffOffers.length}</span></div>${management.ownStaffOffers.map(o=>`<div class="list-item"><div class="row between"><div><b>${esc(o.staff?.name||'Staff')}</b><div class="muted mini">${esc(o.staff?.primary_role||'')} · offre de ${esc(o.competitor?.name||'un joueur rival')}</div></div><div style="text-align:right"><b>${euro(o.offered_weekly)}/sem.</b><div class="muted micro">échéance ${df(o.deadline)}</div></div></div><div class="row" style="gap:8px;margin-top:7px"><button class="primary" onclick="matchStaffOffer(${o.id})">S’aligner</button><button class="ghost" onclick="releaseStaffOffer(${o.id})">Le laisser partir</button></div></div>`).join('')}</div>`:''}
 <div class="grid g2">${(boot.staff||[]).map(s=>{const p=s.profile||null,n=s.name||p?.name||s.role,course=p?.id?trainingByProfile.get(Number(p.id)):null;return `<div class="card click" onclick="openStaff(${s.id})"><div class="row between"><div><div class="eyebrow">${esc(s.role)}</div><h2>${esc(n)}</h2><div class="row" style="margin-top:5px;flex-wrap:wrap">${p?`<span class="badge">${esc(staffFormerLabel(p))}</span>`:''}${p?.verified?'<span class="badge good">Profil sourcé</span>':''}${course?`<span class="badge warn">Formation ${course.progress||0}%</span>`:''}</div></div><div class="progress-ring" style="--p:${s.skill*5}"><b>${s.skill}/20</b></div></div><p class="muted">${esc(p?.specialty||'Staff performance')} · ${euro(s.weekly_cost)}/sem.</p>${p?staffMetaBadges(p):''}${p?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge ${Number(p.workload||0)>=85?'warn':''}">Charge ${p.workload??0}/100</span><span class="badge ${Number(p.burnout||0)>=65?'bad':''}">Burnout ${p.burnout??0}/100</span><span class="badge">Énergie ${p.energy??100}/100</span>${p.operational_status==='rest'? `<span class="badge warn">Repos jusqu’au ${df(p.rest_until)}</span>`:''}</div>`:''}${course?`<div class="bar" style="margin-top:8px"><i style="width:${Number(course.progress||0)}%"></i></div><div class="muted micro" style="margin-top:4px">${esc(course.focus||'Formation')} · ${esc(course.center?.name||'Centre')} · fin prévue ${df(course.expected_end)}</div>`:''}</div>`}).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Marché du staff</div><h2>Candidats disponibles</h2><div class="muted mini">Entretien obligatoire avant signature. Les profils ont leurs exigences, leur réseau et parfois des offres concurrentes.</div></div></div>
 <div class="card staff-market-filter"><div class="row" style="gap:8px;flex-wrap:wrap"><input id="staffMarketSearch" placeholder="Rechercher un coach, kiné, recruteur…" oninput="filterStaffMarket()" style="flex:1;min-width:210px"><select id="staffMarketRole" onchange="filterStaffMarket()"><option value="">Tous les rôles</option>${roles.map(r=>`<option value="${esc(r)}">${esc(r)}</option>`).join('')}</select><span class="badge">${cand.length} profils visibles</span></div></div>
 <div class="grid g2" id="staffMarketGrid">${cand.map(x=>{
   const p=x.profile||null,available=x.status==='available',done=x.interview_status==='completed',rejected=x.interview_status==='rejected';
   return `<div class="card click staff-market-card" data-name="${esc(String(x.name||'').toLowerCase())}" data-role="${esc(String(x.role||''))}" onclick="openStaffCandidate(${x.id})">
    <div class="row between"><div><div class="eyebrow">${esc(x.role)}</div><h2>${esc(x.name)}</h2><div class="row" style="margin-top:5px;flex-wrap:wrap">${p?`<span class="badge">${esc(staffFormerLabel(p))}</span>`:''}${p?.former_player_id&&!p?.verified?'<span class="badge">Reconversion simulée</span>':''}${p?.nationality?`<span class="badge">${flags[p.nationality]||'🏳️'} ${esc(p.nationality)}</span>`:''}${Number(x.competing_offers||0)>0?`<span class="badge warn">${x.competing_offers} offre(s) concurrente(s)</span>`:''}</div></div><div class="progress-ring" style="--p:${x.skill*5}"><b>${x.skill}/20</b></div></div>
    <p class="muted">${esc(x.specialty||p?.specialty||'')} · ${euro(done?(x.requested_weekly||x.weekly_cost):x.weekly_cost)}/sem.</p>
    ${p?staffMetaBadges(p):''}
    <div class="row between" style="margin-top:7px"><span class="mini muted">Compatibilité</span><b>${x.managed_fit!=null?x.managed_fit+'/100':'—'}</b></div>
    <div class="row" style="gap:6px;flex-wrap:wrap;margin:7px 0">${done?`<span class="badge good">Intérêt ${x.interest??'—'}/100</span>`:rejected?'<span class="badge bad">Entretien refusé</span>':'<span class="badge">Entretien requis</span>'}</div>
    <div class="row between"><span class="mini muted">Prime ${euro(done?(x.requested_signing||x.signing_cost):x.signing_cost)}</span><div class="row" style="gap:6px">${available&&!done&&!rejected?`<button class="primary" onclick="event.stopPropagation();interviewStaff(${x.id})">Entretien</button>`:''}${available&&done?`<button class="primary" onclick="event.stopPropagation();hireStaff(${x.id})">Recruter</button>`:''}${rejected?'<button class="ghost" disabled>Refus</button>':''}${x.status==='hired'?'<button class="ghost" disabled>Recruté</button>':''}${!available&&x.status!=='hired'?'<button class="ghost" disabled>Indisponible</button>':''}</div></div>
   </div>`;
 }).join('')}</div>${staffWorldSection()}`
}
function contractsPage(){
 const rows=management?.contracts||[];
 return `<div class="section-head"><div><div class="eyebrow">Négociations</div><h1>Contrats</h1><div class="muted">Échéances, salaires et renouvellements.</div></div></div><div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>Personne</th><th>Rôle</th><th>Salaire/sem.</th><th>Fin</th><th>Statut</th><th></th></tr></thead><tbody>${rows.map(x=>{const active=x.status==='active';return `<tr><td class="click" onclick="openContract(${x.id})"><b>${esc(x.subject_name)}</b></td><td>${esc(x.role||x.subject_type)}</td><td>${euro(x.weekly_salary)}</td><td>${df(x.end_date)}</td><td><span class="badge ${active?'good':'muted'}">${esc(x.status)}</span></td><td>${active?`<button class="soft-btn" onclick="renewContract(${x.id})">+ 1 an</button>`:''}</td></tr>`}).join('')}</tbody></table></div></div>`
}
function financePage(){
 const cr=career(),f=boot.finance||{},offers=management?.sponsors||[];
 const transactions=management?.financeTransactions||[];
 const seasonYear=Number(String(local.date||cr.career_date||RANKING_SNAPSHOT).slice(0,4));
 const seasonTx=transactions.filter(x=>Number(String(x.game_date||'').slice(0,4))===seasonYear&&x.category!=='opening');
 const seasonIncome=seasonTx.filter(x=>Number(x.amount||0)>0).reduce((sum,x)=>sum+Number(x.amount||0),0);
 const seasonExpense=Math.abs(seasonTx.filter(x=>Number(x.amount||0)<0).reduce((sum,x)=>sum+Number(x.amount||0),0));
 const accepted=offers.filter(x=>x.status==='accepted');
 const sponsorWeekly=accepted.reduce((sum,x)=>sum+Number(x.weekly_value||0),0);
 const staffWeekly=(boot.staff||[]).reduce((sum,x)=>sum+Number(x.weekly_cost||0),0);
 const playerWeekly=(management?.academyRoster||[]).reduce((sum,x)=>sum+Number(x.weekly_cost||0),0);
 return `<div class="section-head"><div><div class="eyebrow">Comptabilité</div><h1>Finances & sponsors</h1></div></div>
 <div class="kpi-strip"><div class="kpi"><span class="muted mini">Solde</span><b>${euro(cr.budget)}</b></div><div class="kpi"><span class="muted mini">Revenus ${seasonYear}</span><b class="good">+${euro(seasonIncome)}</b></div><div class="kpi"><span class="muted mini">Dépenses ${seasonYear}</span><b class="bad">-${euro(seasonExpense)}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${euro(f.prize_money)}</b></div><div class="kpi"><span class="muted mini">Sponsors / sem.</span><b>${euro(sponsorWeekly)}</b></div><div class="kpi"><span class="muted mini">Masse salariale</span><b>${euro(staffWeekly+playerWeekly)}</b></div></div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Offres commerciales</h2>${offers.map(x=>{const paid=Number(x.weeks_paid||0),duration=Math.max(1,Number(x.duration_weeks||52)),remaining=Math.max(0,duration-paid),active=x.status==='accepted';return `<div class="list-item"><div class="row between"><div><b>${esc(x.brand)}</b><div class="muted mini">${euro(x.weekly_value)}/sem. · bonus ${euro(x.signing_bonus)} · ${duration} sem.</div></div><span class="badge ${active?'good':x.status==='locked'?'bad':x.status==='expired'?'muted':''}">${esc(x.status)}</span></div><div class="muted mini" style="margin-top:5px">${esc(x.requirement||'')}</div>${active?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge good">${paid}/${duration} versements</span><span class="badge">${remaining} sem. restante${remaining>1?'s':''}</span>${x.ends_on?`<span class="badge">Fin ${df(x.ends_on)}</span>`:''}</div>`:x.status==='expired'?`<div class="muted mini" style="margin-top:7px">Contrat terminé${x.ended_on?' le '+df(x.ended_on):''} · ${paid} versement${paid>1?'s':''} reçu${paid>1?'s':''}.</div>`:''}${x.status==='available'?`<div class="row" style="gap:8px;margin-top:8px"><button class="primary" onclick="acceptSponsor(${x.id})">Accepter</button><button class="soft-btn" onclick="declineSponsor(${x.id})">Refuser</button></div>`:''}</div>`}).join('')||'<div class="empty">Aucune offre.</div>'}</div>
  <div class="card"><h2>Projection hebdomadaire</h2><div class="list-item row between"><span>Revenus sponsors</span><b class="good">+${euro(sponsorWeekly)}</b></div><div class="list-item row between"><span>Staff</span><b class="bad">-${euro(staffWeekly)}</b></div><div class="list-item row between"><span>Joueurs académie</span><b class="bad">-${euro(playerWeekly)}</b></div><div class="list-item row between"><span>Net hebdomadaire</span><b class="${sponsorWeekly-staffWeekly-playerWeekly>=0?'good':'bad'}">${sponsorWeekly-staffWeekly-playerWeekly>=0?'+':''}${euro(sponsorWeekly-staffWeekly-playerWeekly)}</b></div><div class="list-item row between"><span>Voyage moyen</span><b class="bad">-${euro(Number(f.travel_cost||0)/4)}</b></div><div class="notice" style="margin-top:10px">Les sponsors signés alimentent le budget à chaque semaine simulée.</div></div>
 </div>
 <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Économie carrière</div><h2>Coûts de représentation & performance</h2></div><span class="badge">Évolutif</span></div><div class="list-item row between"><span>Voyages cumulés</span><b class="bad">-${euro(f.travel_cost||0)}</b></div><div class="list-item row between"><span>Commissions agent cumulées</span><b class="bad">-${euro(f.agent_commission||0)}</b></div><div class="list-item row between"><span>Primes de titres au staff</span><b class="bad">-${euro(f.staff_bonus||0)}</b></div><div class="muted mini" style="margin-top:8px">Les commissions suivent ton contrat d’agence. Les membres du staff qui exigent un bonus de performance touchent leur prime quand tu remportes un titre.</div></div>
 <div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Ledger carrière</div><h2>Journal des transactions</h2></div><span class="badge">${transactions.length} mouvement${transactions.length>1?'s':''}</span></div>
  ${transactions.length?`<div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>Date</th><th>Catégorie</th><th>Description</th><th>Montant</th></tr></thead><tbody>${transactions.slice(0,80).map(x=>{
    const labels={opening:'Ouverture',sponsor_income:'Sponsors',sponsor_bonus:'Prime sponsor',staff_payroll:'Staff',academy_payroll:'Académie',academy_signing:'Signature jeune',medical:'Médical',staff_training:'Formation staff',facility_upgrade:'Installations',prize_money:'Prize money',travel:'Voyage',agent_commission:'Agent',staff_bonus:'Prime staff'};
    const amount=Number(x.amount||0);
    return `<tr><td>${df(x.game_date)}</td><td><span class="badge">${esc(labels[x.category]||x.category||'Autre')}</span></td><td><b>${esc(x.description||'Mouvement')}</b>${x.week?`<div class="muted micro">Semaine ${x.week}</div>`:''}</td><td><b class="${amount>=0?'good':'bad'}">${amount>=0?'+':''}${euro(amount)}</b></td></tr>`;
   }).join('')}</tbody></table></div>`:'<div class="empty">Les mouvements apparaîtront ici au fil de la carrière.</div>'}
 </div>`
}
function injuryRisk(){
 const c=activePlayerCareerView();
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const activeTraining=playerId===primaryManagedPlayerId()?(local.training||[]):((local.playerTraining||{})[String(playerId)]||[]);
 const load=(activeTraining||[]).reduce((a,s)=>a+(['Endurance','Match play','Déplacements'].includes(s)?3:['Service','Retour','Coup droit','Revers','Double'].includes(s)?2:s==='Récupération'?0:-1),0);
 let r=12+(c.fatigue||18)*.45+(100-(c.fitness||91))*.35+Math.max(0,65-(c.form||72))*.2+Math.max(0,load-9)*4;
 if(local.injuryTreatment==='Prudent')r-=10;if(local.injuryTreatment==='Agressif')r+=8;
 return Math.round(clamp(r,2,95));
}
function medicalPage(){
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const c=activePlayerCareerView(),inj=boot.injuries||[];
 const managed=(activeManagedContext&&Number(activeManagedContext.player_id)===playerId)?(activeManagedContext.injury||null):(playerId===primaryManagedPlayerId()?boot.managedInjury||null:null);
 const plan=(activeManagedContext&&Number(activeManagedContext.player_id)===playerId&&activeManagedContext.medical_plan)
  ?activeManagedContext.medical_plan
  :(playerId===primaryManagedPlayerId()?boot.medicalPlan:null)||{protocol:'Récupération active',physio_hours:2,weekly_cost:250};
 const activeTraining=playerId===primaryManagedPlayerId()
  ?(local.training||[])
  :((local.playerTraining||{})[String(playerId)]||[]);
 const activeLoad=(activeTraining||[]).reduce((a,s)=>a+(['Endurance','Match play','Déplacements'].includes(s)?3:['Service','Retour','Coup droit','Revers','Double'].includes(s)?2:s==='Récupération'?0:-1),0);
 const risk=managed?Number(managed.aggravation_risk||0):clamp(Math.round((c.fatigue||18)*.75+(activeLoad*3)),0,100);
 const protocols=[
  ['Repos complet','Fatigue ↓↓↓ · retour accéléré · forme légèrement en baisse','0 € / semaine'],
  ['Physio intensive','Risque ↓↓↓ · retour le plus rapide · coût élevé','900 € / semaine'],
  ['Récupération active','Équilibre récupération / fitness','250 € / semaine'],
  ['Maintien de forme','Fitness préservée · risque de rechute plus élevé','120 € / semaine']
 ];
 return `<div class="section-head"><div><div class="eyebrow">Centre médical</div><h1>Condition & blessures</h1><div class="muted">Diagnostic, protocole, récupération et risque de rechute.</div></div><button class="primary" onclick="setMedicalProtocol('Récupération active')">Récupération active</button></div>
 <div class="grid g4"><div class="card"><h3>Fitness</h3><div class="big">${c.fitness||91}%</div><div class="bar"><i style="width:${c.fitness||91}%"></i></div></div><div class="card"><h3>Fatigue</h3><div class="big">${c.fatigue||18}%</div><div class="bar"><i style="width:${c.fatigue||18}%"></i></div></div><div class="card"><h3>Risque</h3><div class="big ${risk>65?'bad':risk>35?'warn':'good'}">${risk}%</div></div><div class="card"><h3>Statut</h3><div class="big" style="font-size:20px">${esc(c.injury_status||'Fit')}</div></div></div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card"><h2>Dossier du joueur géré</h2>${managed?`
    <div class="notice ${managed.severity==='Sévère'?'bad':''}"><b>${esc(managed.injury_type)}</b> · ${esc(managed.severity)}</div>
    <div class="list-item row between"><span>Début</span><b>${df(managed.started_at)}</b></div>
    <div class="list-item row between"><span>Retour estimé</span><b>${df(managed.expected_return)}</b></div>
    <div class="list-item row between"><span>Risque d’aggravation</span><b class="${Number(managed.aggravation_risk)>50?'bad':Number(managed.aggravation_risk)>25?'warn':'good'}">${managed.aggravation_risk}%</b></div>
    <div class="list-item row between"><span>Traitement actuel</span><b>${esc(managed.treatment||plan.protocol)}</b></div>
    <button class="soft-btn" style="margin-top:10px" onclick="openInjury(${managed.id})">Voir le dossier complet</button>
  `:`<div class="notice good"><b>Aucune blessure active.</b><br><span class="muted mini">Le plan médical agit quand même sur la fatigue et la prévention.</span></div>`}</div>
  <div class="card"><h2>Plan médical actuel</h2>
    <div class="list-item row between"><span>Protocole</span><b>${esc(plan.protocol)}</b></div>
    <div class="list-item row between"><span>Physio</span><b>${plan.physio_hours||0} h / semaine</b></div>
    <div class="list-item row between"><span>Coût</span><b>${euro(plan.weekly_cost||0)} / semaine</b></div>
    <div class="muted mini" style="margin-top:8px">${esc(plan.notes||'')}</div>
  </div>
 </div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Traitement</div><h2>Choisir le protocole</h2></div></div>
 <div class="grid g2">${protocols.map(x=>`<div class="card ${plan.protocol===x[0]?'selected-card':''}"><div class="row between"><div><h3>${x[0]}</h3><div class="muted mini">${x[1]}</div></div><span class="badge">${x[2]}</span></div><button class="${plan.protocol===x[0]?'ghost':'soft-btn'}" style="margin-top:10px" onclick="setMedicalProtocol('${x[0]}')">${plan.protocol===x[0]?'Actif':'Appliquer'}</button></div>`).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Monde</div><h2>Blessures connues</h2></div></div>
 <div class="card">${inj.length?inj.map(i=>`<div class="list-item click" onclick="openInjury(${i.id})"><div class="row between"><b>${esc(i.players?.name||'Joueur')} · ${esc(i.injury_type)}</b><span class="badge ${i.status==='Active'?'bad':'good'}">${esc(i.status)}</span></div><div class="muted mini">Sévérité ${esc(i.severity)} · retour ${df(i.expected_return)} · rechute ${i.aggravation_risk}%</div></div>`).join(''):'<div class="empty">Aucune blessure enregistrée.</div>'}</div>`
}
function pointLabel(a,b,side){
 if(a>=3&&b>=3){
  if(a===b)return '40';
  if(side==='A'&&a>b)return 'AV';
  if(side==='B'&&b>a)return 'AV';
  return '40';
 }
 return ['0','15','30','40'][side==='A'?Math.min(a,3):Math.min(b,3)];
}
function liveMatchPanel(){
 const s=local.liveMatch;
 const selectedSurface=local.matchSurface||'Dur';
 const selectedIndoor=!!local.matchIndoor;
 if(!s)return `<div class="card fm-match-launch"><div class="row between"><div><div class="eyebrow">CB Match Engine v2</div><h2>Match Center manager</h2><div class="muted">Joue point par point ou simule. Le score reste provisoire tant que tu ne l’as pas validé.</div></div><span class="badge">FM dots · TM tactics</span></div>
  <div class="match-surface-pills">
   <button class="${selectedSurface==='Dur'&&!selectedIndoor?'active':''}" onclick="setMatchSurface('Dur',false)">Dur ext.</button>
   <button class="${selectedSurface==='Dur'&&selectedIndoor?'active':''}" onclick="setMatchSurface('Dur',true)">Dur int.</button>
   <button class="${selectedSurface==='Terre'?'active':''}" onclick="setMatchSurface('Terre',false)">Terre</button>
   <button class="${selectedSurface==='Gazon'?'active':''}" onclick="setMatchSurface('Gazon',false)">Gazon</button>
  </div>
  <button class="primary fm-start-match" onclick="startLiveMatch()">Lancer un match libre</button>
 </div>`;

 const c=activePlayerCareerView(),opp=local.liveOpponent||{},lp=s.last_point||{},st=s.stats||{},meta=st._meta||{};
 const tour=meta.tournament||null,weather=meta.weather||{},mood=meta.mood||{},formMeta=meta.form||{};
 const userFormBonus=Number(formMeta.user_bonus||0),oppFormBonus=Number(formMeta.opponent_bonus||0);
 const signedForm=n=>(n>0?'+':'')+String(n);
 const userName=c.player_name||'Joueur',oppName=opp.name||'Adversaire';
 const us=Number(s.user_sets||0),os=Number(s.opponent_sets||0),ug=Number(s.user_games||0),og=Number(s.opponent_games||0);
 const up=Number(s.user_points||0),op=Number(s.opponent_points||0);
 const finished=['finished','completed'].includes(String(s.status||'')),committed=String(s.status||'')==='committed';
 const done=finished||committed;
 const ux=clamp(Number(lp.user_x??(48+(Number(s.rally_no||0)%3)*6)),12,88);
 const uy=clamp(Number(lp.user_y??78),55,90);
 const ox=clamp(Number(lp.opp_x??(52-(Number(s.rally_no||0)%3)*6)),12,88);
 const oy=clamp(Number(lp.opp_y??22),10,45);
 const bx=clamp(Number(lp.ball_x??50),10,90),by=clamp(Number(lp.ball_y??50),8,92);
 const surface=String(s.surface||'Dur'),courtClass=surface==='Terre'?'clay':surface==='Gazon'?'grass':'hard';
 const indoor=/intérieur|indoor/i.test(surface)||meta.indoor===true;
 const uInit=esc(userName.split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase());
 const oInit=esc(oppName.split(/\s+/).map(x=>x[0]).slice(0,2).join('').toUpperCase());
 const momentum=clamp(Number(s.momentum||50),10,90);
 const pointText=(a,b,side)=>pointLabel(a,b,side);
 const pctStat=(num,den)=>Number(den||0)>0?Math.round(Number(num||0)/Number(den)*100):0;
 const userFirstPct=pctStat(st.user_first_serves_in,st.user_first_serves);
 const oppFirstPct=pctStat(st.opp_first_serves_in,st.opp_first_serves);
 const pointEnding=String(lp.ending||lp.shot||'').replaceAll('_',' ');
 const pointServe=lp.serve_number?`${lp.serve_number}e balle · ${esc(lp.serve_direction||'')}`:'';
 const pointReturn=lp.return_depth?`retour ${esc(lp.return_depth)}`:'';
 const speed=Number(meta.court_speed||1);
 const speedLabel=speed>=1.16?'Très rapide':speed>=1.05?'Rapide':speed<=.78?'Lent':speed<=.92?'Plutôt lent':'Moyen';
 const wind=Number(weather.wind_kph||0),temp=Number(weather.temperature_c||0),humid=Number(weather.humidity_pct||0);
 const logo=tour?.logo_url?`<img class="match-event-logo" src="${esc(tour.logo_url)}" alt="${esc(tour.name||'Tournoi')}" onerror="this.style.display='none'">`:'';
 const statusLabel=committed?'Validé':finished?'À valider':'Set '+(s.set_no||1);
 const statusClass=committed?'good':finished?'warn':'';

 return `<div class="card fm-live-match match-engine-v2">
  ${tour?`<div class="match-event-banner">${logo}<div><div class="eyebrow">${esc(tour.circuit||'Tournoi')} · ${esc(tour.category||'')} · ${esc(meta.round||'Match')}</div><h2>${esc(tour.name||'Tournoi')}</h2><div class="muted mini">${esc([tour.venue,tour.city,tour.country].filter(Boolean).join(' · '))}</div></div><span class="badge">${esc(surface)}</span></div>`:''}

  <div class="fm-match-top">
   <div><div class="eyebrow">${tour?'Match officiel':'Match libre'} · ${esc(surface)}${indoor?' · indoor':''}</div><h2>${esc(userName)} vs ${esc(oppName)}</h2></div>
   <span class="badge ${statusClass}">${statusLabel}</span>
  </div>

  <div class="match-conditions-grid">
   <div><span>Conditions</span><b>${esc(weather.condition|| (indoor?'Indoor':'Standard'))}</b></div>
   <div><span>Temp.</span><b>${temp?temp+'°C':'—'}</b></div>
   <div><span>Vent</span><b>${wind?wind+' km/h':indoor?'0 km/h':'—'}</b></div>
   <div><span>Humidité</span><b>${humid?humid+'%':'—'}</b></div>
   <div><span>Vitesse court</span><b>${speedLabel} · ${speed.toFixed(2)}</b></div>
   <div><span>Altitude</span><b>${Number(meta.altitude_m||0)?fmt(meta.altitude_m)+' m':'—'}</b></div>
   <div><span>Humeur ${esc(userName.split(' ').slice(-1)[0])}</span><b class="${Number(mood.user||70)>=76?'good':Number(mood.user||70)<58?'bad':''}">${fmt(mood.user||70)}/100</b></div>
   <div><span>Humeur adverse</span><b>${fmt(mood.opponent||70)}/100</b></div>
   <div class="match-form-box"><span>Forme ${esc(userName.split(' ').slice(-1)[0])}</span><b class="${userFormBonus>0?'good':userFormBonus<0?'bad':''}">${fmt(formMeta.user??c.form??70)}/100 · ${signedForm(userFormBonus)} stats</b></div>
   <div class="match-form-box"><span>Forme adverse</span><b class="${oppFormBonus>0?'good':oppFormBonus<0?'bad':''}">${fmt(formMeta.opponent??opp.form??70)}/100 · ${signedForm(oppFormBonus)} stats</b></div>
  </div>

  <div class="fm-scoreboard">
   <div class="fm-score-name">${s.serving_user?'● ':''}${esc(userName)} <small>${flags[c.country]||''}</small></div><b>${us}</b><b>${ug}</b><strong>${pointText(up,op,'A')}</strong>
   <div class="fm-score-name">${!s.serving_user?'● ':''}${esc(oppName)} <small>${flags[opp.country]||''}</small></div><b>${os}</b><b>${og}</b><strong>${pointText(up,op,'B')}</strong>
  </div>

  <div class="fm-court ${courtClass} ${indoor?'indoor':''}" data-surface="${esc(surface)}">
    ${tour?.name?`<div class="court-event-watermark">${esc(tour.name)}</div>`:''}
    <i class="fm-court-line baseline top"></i><i class="fm-court-line baseline bottom"></i>
    <i class="fm-court-line sideline left"></i><i class="fm-court-line sideline right"></i>
    <i class="fm-court-line service horizontal top"></i><i class="fm-court-line service horizontal bottom"></i>
    <i class="fm-court-line service vertical"></i><i class="fm-net"></i>
    <div class="fm-player-dot opponent" style="left:${ox}%;top:${oy}%"><span>${oInit}</span><small>${esc(oppName.split(' ').slice(-1)[0]||'ADV')}</small></div>
    <div class="fm-player-dot user" style="left:${ux}%;top:${uy}%"><span>${uInit}</span><small>${esc(userName.split(' ').slice(-1)[0]||'MOI')}</small></div>
    <i class="fm-ball" style="left:${bx}%;top:${by}%"></i>
    ${lp.shot?`<div class="fm-rally-call"><b>${esc(pointEnding)}</b> · ${Number(lp.rally||0)} coups${lp.rally_band?' · '+esc(lp.rally_band):''}${pointServe?' · '+pointServe:''}${pointReturn?' · '+pointReturn:''}${lp.at_net?' · filet':''}</div>`:''}
  </div>

  <div class="fm-momentum"><span>${esc(oppName)}</span><div><i style="left:${momentum}%"></i></div><span>${esc(userName)}</span></div>
  <div class="fm-match-stats">
   <div><span>Winners</span><b>${st.user_winners||0}–${st.opp_winners||0}</b></div>
   <div><span>Fautes</span><b>${st.user_errors||0}–${st.opp_errors||0}</b></div>
   <div><span>Aces</span><b>${st.user_aces||0}–${st.opp_aces||0}</b></div>
   <div><span>1res IN</span><b>${userFirstPct}%–${oppFirstPct}%</b></div>
   <div><span>DF</span><b>${st.user_double_faults||0}–${st.opp_double_faults||0}</b></div>
   <div><span>Non retournés</span><b>${st.user_unreturned_serves||0}–${st.opp_unreturned_serves||0}</b></div>
   <div><span>Filet</span><b>${st.user_net_points_won||0}/${st.user_net_points||0}</b></div>
   <div><span>Points</span><b>${s.rally_no||0}</b></div>
  </div>

  ${lp.model?`<div class="muted micro match-model-line">Moteur : ${esc(lp.model)} · P(point) serveur ${lp.server_win_probability??'—'}% · Elo surface ${Math.round(Number(lp.server_surface_elo||0))} vs ${Math.round(Number(lp.returner_surface_elo||0))}</div>`:''}

  ${committed?`<div class="notice good match-result-actions"><b>Résultat validé et intégré à la carrière.</b></div><button class="ghost" style="width:100%;margin-top:10px" onclick="clearLiveMatch()">Fermer le match</button>`
  :finished?`<div class="notice warn match-result-actions"><b>Score final provisoire.</b><br><span class="muted mini">Sauvegarder le rend officiel. Tu peux aussi figer ce score comme brouillon, ou ne pas sauvegarder et revenir au checkpoint.</span></div>
   <div class="fm-result-controls">
    <button class="primary" onclick="commitLiveMatch()">💾 Sauvegarder le résultat</button>
    <button class="soft-btn" onclick="saveLiveCheckpoint()">Figer comme brouillon</button>
    <button class="danger-btn" onclick="discardLiveMatch()">Ne pas sauvegarder / rejouer</button>
   </div>`
  :`<div class="fm-live-toolbar">
   <button class="${liveAutoTimer?'danger-btn':'primary'}" onclick="toggleLiveAuto()">${liveAutoTimer?'Pause':'▶ Live'}</button>
   <button class="soft-btn ${liveAutoSpeed===1?'active':''}" onclick="setLiveSpeed(1)">1x</button>
   <button class="soft-btn ${liveAutoSpeed===2?'active':''}" onclick="setLiveSpeed(2)">2x</button>
   <button class="soft-btn ${liveAutoSpeed===4?'active':''}" onclick="setLiveSpeed(4)">4x</button>
   <button class="soft-btn" onclick="saveLiveCheckpoint()">Sauvegarde rapide</button>
  </div>
  <div class="fm-sim-controls"><button class="primary" onclick="playLivePoint()">Point</button><button class="soft-btn" onclick="simulateLiveGame()">Jeu</button><button class="soft-btn" onclick="simulateLiveSet()">Set</button><button class="soft-btn" onclick="simulateLiveMatch()">Match</button></div>`}
 </div>`;
}
function matchPage(){
 const t=local.tactics||{aggression:58,risk:52,net:28,returnPos:'Neutre'};
 const activeId=activeManagedId()||primaryManagedPlayerId()||0;
 const localMatches=(local.practiceMatches||[]).filter(m=>!m.managed_player_id||Number(m.managed_player_id)===activeId);
 const serverMatches=(boot.matches||[]).filter(m=>{
  const mid=Number(m.managed_player_id||0);
  return mid?mid===activeId:activeId===primaryManagedPlayerId();
 });
 const all=[...localMatches,...serverMatches],doublesOnly=String(activePlayerCareerView().career_focus||'mixed')==='doubles_only';
 return `<div class="section-head"><div><div class="eyebrow">Analyse & coaching</div><h1>Match Center</h1><div class="muted">Prépare le plan de jeu, coache point par point et analyse les tendances.</div></div><button class="ghost" ${doublesOnly?'disabled':''} onclick="simulatePracticeMatch()">Simulation rapide</button></div>
 <div class="notice"><b>Mode manager</b> · changer de joueur fige son score. Une sauvegarde manuelle/quicksave fige aussi les matchs live. Fermer ou recharger sans sauvegarder revient au dernier checkpoint : avant-match, ou au score exact de ta dernière sauvegarde.</div>
 ${doublesOnly?'<div class="notice good"><b>Carrière Double exclusivement</b> · les matchs simples sont coupés. Utilise le hub Double et les fiches tournoi pour jouer.</div>':liveMatchPanel()}
 <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Plan de jeu</h2>
 <div class="list-item"><div class="row between"><span>Agressivité</span><b>${t.aggression}%</b></div><input class="range" type="range" min="1" max="100" value="${t.aggression}" oninput="setTactic('aggression',this.value)"></div>
 <div class="list-item"><div class="row between"><span>Prise de risque</span><b>${t.risk}%</b></div><input class="range" type="range" min="1" max="100" value="${t.risk}" oninput="setTactic('risk',this.value)"></div>
 <div class="list-item"><div class="row between"><span>Montées au filet</span><b>${t.net}%</b></div><input class="range" type="range" min="1" max="100" value="${t.net}" oninput="setTactic('net',this.value)"></div>
 <div class="list-item row between"><span>Position retour</span><select class="select" style="width:auto" onchange="setTactic('returnPos',this.value)"><option ${t.returnPos==='Avancée'?'selected':''}>Avancée</option><option ${t.returnPos==='Neutre'?'selected':''}>Neutre</option><option ${t.returnPos==='Reculée'?'selected':''}>Reculée</option></select></div></div>
 <div class="card"><h2>Lecture tactique</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Intensité</span><b>${Math.round((t.aggression+t.risk)/2)}</b></div><div class="kpi"><span class="muted mini">Jeu avant</span><b>${t.net}</b></div><div class="kpi"><span class="muted mini">Retour</span><b style="font-size:15px">${esc(t.returnPos)}</b></div></div><p class="muted mini" style="margin-top:10px">Les changements de tactique influencent les points suivants du match live et les simulations de tournoi.</p></div></div>
 <div class="section-head" style="margin-top:16px"><div><div class="eyebrow">Historique</div><h2>Matchs analysés</h2></div></div>
 <div class="stack">${all.map((m,idx)=>`<div class="card click" onclick="openMatch(${idx})"><div class="row between"><div><div class="eyebrow">${esc(m.tournament_name||'Match entraînement')} · ${esc(m.round||'Exhibition')}</div><h2>${esc(m.player_a)} vs ${esc(m.player_b)}</h2><div class="muted">${df(m.match_date||local.date)} · <span class="${surfaceClass(m.surface||'Dur')}">${esc(m.surface||'Dur')}</span></div></div><div><div class="big">${esc(m.score||'—')}</div><span class="badge ${m.winner===(activePlayerCareerView().player_name||'Joueur')?'good':'bad'}">${m.winner===(activePlayerCareerView().player_name||'Joueur')?'Victoire':'Défaite'}</span></div></div><div class="kpi-strip" style="margin-top:12px">${Object.entries(m.match_data||{}).filter(([k,v])=>k!=='tactical_plan'&&typeof v!=='object').slice(0,4).map(([k,v])=>`<div class="kpi"><span class="muted mini">${esc(k.replaceAll('_',' '))}</span><b>${v}</b></div>`).join('')}</div></div>`).join('')||'<div class="card empty">Aucun match enregistré.</div>'}</div>`
}
window.setMatchSurface=(surface,indoor=false)=>{local.matchSurface=surface;local.matchIndoor=!!indoor;persist();render()}
function liveMatchOwnerId(session=local.liveMatch){
 return Number(session?.managed_player_id||activeManagedId()||primaryManagedPlayerId()||0);
}
function rememberCurrentLiveMatch(){
 const s=local.liveMatch;
 if(!s)return;
 const playerId=liveMatchOwnerId(s),sessionId=Number(s.id||0);
 if(playerId&&sessionId&&['active','finished'].includes(String(s.status||''))){
  liveMatchSessionsByPlayer.set(playerId,sessionId);
  if(local.liveOpponent)liveMatchOpponentsByPlayer.set(playerId,local.liveOpponent);
 }else if(playerId){
  liveMatchSessionsByPlayer.delete(playerId);
  liveMatchOpponentsByPlayer.delete(playerId);
 }
}
function clearLiveMatchView(){
 if(liveAutoTimer){clearInterval(liveAutoTimer);liveAutoTimer=null}
 delete local.liveMatch;
 delete local.liveOpponent;
 local.liveSessionId=null;
}
async function restoreLiveMatchForPlayer(playerId){
 const target=Number(playerId||0);
 if(!target)return null;
 if(local.liveMatch&&Number(local.liveMatch.managed_player_id||0)===target)return local.liveMatch;
 clearLiveMatchView();
 const sessionId=Number(liveMatchSessionsByPlayer.get(target)||0);
 if(!sessionId)return null;
 try{
  const d=await get('/api/live-match/state?id='+encodeURIComponent(sessionId));
  const session=d?.session||null;
  if(!session||Number(session.managed_player_id||0)!==target||!['active','finished'].includes(String(session.status||''))){
   liveMatchSessionsByPlayer.delete(target);
   liveMatchOpponentsByPlayer.delete(target);
   return null;
  }
  local.liveMatch=session;
  local.liveSessionId=sessionId;
  local.liveOpponent=session.opponent||liveMatchOpponentsByPlayer.get(target)||null;
  if(local.liveOpponent)liveMatchOpponentsByPlayer.set(target,local.liveOpponent);
  return session;
 }catch(e){
  liveMatchSessionsByPlayer.delete(target);
  liveMatchOpponentsByPlayer.delete(target);
  return null;
 }
}
function applyLiveMatchResponse(d){
 if(!d?.session)return;
 local.liveMatch=d.session;
 if(d.opponent)local.liveOpponent=d.opponent;
 const playerId=liveMatchOwnerId(d.session),sessionId=Number(d.session.id||0);
 if(['active','finished'].includes(String(d.session.status||''))&&playerId&&sessionId){
  local.liveSessionId=sessionId;
  liveMatchSessionsByPlayer.set(playerId,sessionId);
  if(local.liveOpponent)liveMatchOpponentsByPlayer.set(playerId,local.liveOpponent);
 }else{
  local.liveSessionId=null;
  if(playerId){
   liveMatchSessionsByPlayer.delete(playerId);
   liveMatchOpponentsByPlayer.delete(playerId);
  }
  // Finir le match ne vaut pas sauvegarde. Le checkpoint reste armé jusqu'à
  // une vraie sauvegarde manuelle/quicksave ou un autosave explicite hors match.
 }
}
window.hasManagedLiveMatches=()=>liveMatchSessionsByPlayer.size>0;
window.startLiveMatch=async()=>{
 const livePlayer=activePlayerCareerView();
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 if(String(livePlayer.career_focus||'mixed')==='doubles_only'){alert('Orientation Double exclusivement : le Match Center simple est désactivé pour ce joueur.');return}
 if(liveMatchSessionsByPlayer.has(playerId)){
  await restoreLiveMatchForPlayer(playerId);
  render();
  return;
 }
 try{
  await ensureLivePreMatchCheckpoint();
  const surface=(local.matchSurface||'Dur')==='Dur'&&local.matchIndoor?'Dur intérieur':(local.matchSurface||'Dur');
  const d=await get('/api/live-match/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({surface,player_id:playerId,tactics:local.tactics||{}})});
  applyLiveMatchResponse(d);persist();render();
 }catch(e){alert(e.message)}
}
window.startTournamentLiveMatch=async(id,quick=false)=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 if(!playerId)return alert('Joueur géré introuvable.');
 if(liveMatchSessionsByPlayer.has(playerId))return alert('Ce joueur a déjà un match en attente. Termine, valide ou annule-le d’abord.');
 try{
  await ensureLivePreMatchCheckpoint();
  const d=await get('/api/live-match/start',{
   method:'POST',headers:{'Content-Type':'application/json'},
   body:JSON.stringify({tournament_id:Number(id),player_id:playerId,tactics:local.tactics||{}})
  });
  applyLiveMatchResponse(d);
  closeOverlay();
  route='match';persist();render();
  if(quick)await simulateLiveMatch();
 }catch(e){alert(e.message)}
};
window.saveLiveCheckpoint=async()=>{
 if(!local.liveMatch)return;
 const d=await saveCareerSlot(9,'quick',true);
 if(d?.ok===false)return alert('Sauvegarde impossible : '+(d.error||d.reason||'erreur'));
 localStorage.setItem(LIVE_ROLLBACK_KEY,JSON.stringify({
  slot_no:9,saved_live:true,career_date:d.slot?.career_date||local.date||null,
  week:d.slot?.week??local.week??null,created_at:new Date().toISOString()
 }));
 alert('Score sauvegardé. Tu reprendras exactement ici.');
};
async function reloadAfterRollback(){
 invalidateCareerCaches();
 boot=await get('/api/bootstrap');
 if(boot.career){local.career={...(local.career||{}),...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week}
 await Promise.allSettled([loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadTournaments(),loadCareerHub(true)]);
 route='home';closeOverlay();render();
}
window.discardLiveMatch=async()=>{
 if(!local.liveMatch)return;
 if(!confirm('Annuler ce match et revenir au dernier checkpoint sauvegardé ?'))return;
 try{
  const id=Number(local.liveMatch.id||0);
  if(id)await get('/api/live-match/discard',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:id})});
  rememberCurrentLiveMatch();
  clearLiveMatchView();
  await rollbackUnsavedLiveBatchOnStartup();
  await reloadAfterRollback();
 }catch(e){alert('Retour checkpoint impossible : '+e.message)}
};
window.commitLiveMatch=async(saveAfter=true)=>{
 if(!local.liveMatch||!['finished','completed'].includes(String(local.liveMatch.status||'')))return;
 try{
  const d=await get('/api/live-match/commit',{
   method:'POST',headers:{'Content-Type':'application/json'},
   body:JSON.stringify({session_id:Number(local.liveMatch.id)})
  });
  local.lastCommittedMatchResult=d;
  applyLiveMatchResponse(d);
  boot=await get('/api/bootstrap');
  if(boot.career&&activeManagedId()===primaryManagedPlayerId())local.career={...(local.career||{}),...boot.career};
  else await loadActiveManagedContext(true,activeManagedId()).catch(()=>{});
  await Promise.allSettled([loadManagement(),loadSeasonSummary(),loadRankingLedger(),loadCareerHub(true)]);
  if(saveAfter){
   const save=await saveCareerSlot(9,'quick',true);
   if(save?.ok===false)throw new Error('Résultat validé, mais sauvegarde rapide impossible : '+(save.error||save.reason||'erreur'));
   clearPendingLiveRollback();
   alert('Résultat validé et sauvegardé.');
  }else{
   // Keep the rollback marker armed: the committed result belongs to the current
   // unsaved session and a quit/reload before the next real save restores pre-match.
   alert('Résultat validé dans la session, mais pas sauvegardé. Quitter ou recharger avant une sauvegarde reviendra au checkpoint.');
  }
  render();
 }catch(e){alert(e.message)}
};

function liveVisualDelayMs(session=local.liveMatch){
 const raw=Number(session?.last_point?.visual?.duration_ms||900);
 return Math.max(220,Math.min(12500,Math.round(raw/Math.max(1,liveAutoSpeed)+140)));
}
const liveSleep=ms=>new Promise(resolve=>setTimeout(resolve,Math.max(0,ms)));
window.playLivePoint=async()=>{
 if(!local.liveMatch||liveAutoBusy)return;
 liveAutoBusy=true;
 try{
  const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
  applyLiveMatchResponse(d);if(local.liveMatch?.status!=='active'&&liveAutoTimer){clearTimeout(liveAutoTimer);liveAutoTimer=null}persist();render();
  await liveSleep(liveVisualDelayMs());
 }catch(e){alert(e.message)}
 finally{liveAutoBusy=false}
}
window.simulateLiveGame=async()=>{
 if(!local.liveMatch||local.liveMatch.status!=='active'||liveAutoBusy)return;
 try{
  const d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
  applyLiveMatchResponse(d);persist();render();
 }catch(e){alert(e.message)}
}
function liveSimulationProgressKey(session=local.liveMatch){
 if(!session)return 'none';
 return [
  session.status,session.user_sets,session.opponent_sets,session.set_no,
  session.user_games,session.opponent_games,session.user_points,session.opponent_points,
  session.serving_user,session.rally_no
 ].join('|');
}
async function simulateLiveGamesUntil(stopWhen){
 while(local.liveMatch&&local.liveMatch.status==='active'&&!stopWhen(local.liveMatch)){
  const before=liveSimulationProgressKey(local.liveMatch);
  const d=await get('/api/live-match/game',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
  applyLiveMatchResponse(d);
  const after=liveSimulationProgressKey(local.liveMatch);
  if(local.liveMatch?.status==='active'&&after===before)throw new Error('Simulation bloquée : le score n’a pas progressé.');
 }
 return local.liveMatch;
}
window.simulateLiveSet=async()=>{
 if(!local.liveMatch||local.liveMatch.status!=='active'||liveAutoBusy)return;
 const startSets=Number(local.liveMatch.user_sets||0)+Number(local.liveMatch.opponent_sets||0);
 try{
  await simulateLiveGamesUntil(s=>Number(s.user_sets||0)+Number(s.opponent_sets||0)!==startSets);
  persist();render();
 }catch(e){alert(e.message)}
}
window.simulateLiveMatch=async()=>{
 if(!local.liveMatch||local.liveMatch.status!=='active'||liveAutoBusy)return local.liveMatch;
 try{
  await simulateLiveGamesUntil(()=>false);
  persist();render();
  return local.liveMatch;
 }catch(e){alert(e.message);return local.liveMatch}
}
window.setLiveSpeed=speed=>{
 liveAutoSpeed=[1,2,4].includes(Number(speed))?Number(speed):1;
 if(liveAutoTimer){clearTimeout(liveAutoTimer);liveAutoTimer=setTimeout(liveAutoTick,80)}
 render();
}
async function liveAutoTick(){
 if(liveAutoBusy||!local.liveMatch||local.liveMatch.status!=='active'){
   if(local.liveMatch?.status!=='active'&&liveAutoTimer){clearTimeout(liveAutoTimer);liveAutoTimer=null;render()}
   return;
 }
 liveAutoBusy=true;
 try{
   const d=await get('/api/live-match/point',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})});
   applyLiveMatchResponse(d);persist();render();
   if(local.liveMatch?.status!=='active'&&liveAutoTimer){clearTimeout(liveAutoTimer);liveAutoTimer=null;render()}
 }catch(e){
   if(liveAutoTimer){clearTimeout(liveAutoTimer);liveAutoTimer=null}
   alert(e.message);
 }finally{
   liveAutoBusy=false;
   if(liveAutoTimer&&local.liveMatch?.status==='active')liveAutoTimer=setTimeout(liveAutoTick,liveVisualDelayMs());
 }
}
window.toggleLiveAuto=()=>{
 if(liveAutoTimer){clearTimeout(liveAutoTimer);liveAutoTimer=null;render();return}
 if(!local.liveMatch||local.liveMatch.status!=='active')return;
 liveAutoTimer=setTimeout(liveAutoTick,0);
 render();
}
window.clearLiveMatch=()=>{
 const playerId=liveMatchOwnerId();
 if(playerId){liveMatchSessionsByPlayer.delete(playerId);liveMatchOpponentsByPlayer.delete(playerId)}
 clearLiveMatchView();
 persist();
 render();
}
function doublesPage(){
 const c=activePlayerCareerView(),activeId=activeManagedId(),primaryId=primaryManagedPlayerId(),singlesOnly=String(c.career_focus||'mixed')==='singles_only';
 if(!doublesHubRows.length&&!doublesHubLoading)setTimeout(loadDoublesHub,0);
 const pool=doublesHubRows;
 const juniorPool=juniorDoublesHubRows;
 const serverPartner=activeDoublesPartner();
 const partner=singlesOnly?null:(serverPartner||(activeId===primaryId?(pool.find(p=>p.id===local.partnerId)||juniorPool.find(p=>p.id===local.partnerId)):null)||null);
 const offers=management?.doublesPartnerOffers||[];
 const managedCommitment=management?.managedDoublesCommitment||null;
 const ownPartnership=(management?.partnerships||[]).find(x=>{
   const a=Number(x.player_a_id||0),b=Number(x.player_b_id||0);
   return a===activeId||b===activeId;
 })||null;
 const incomingOffers=offers.filter(x=>x.direction==='incoming'&&x.status==='pending');
 const recentOutgoing=offers.filter(x=>x.direction==='outgoing').slice(0,6);
 const candidates=pool.filter(p=>p.name!==c.player_name).slice(0,30);
 const exact=pool.filter(p=>p.doubles_source).length;
 return `<div class="section-head"><div><div class="eyebrow">Circuit Double</div><h1>Double & partenariats</h1><div class="muted">Classement individuel officiel jusqu’au Top 1000, index scouting double profond, Race par équipes et gestion du partenaire. La base double étendue contient ${fmt(worldStats?.indexedDoubles||rankCount||0)} profils.</div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge ${String(c.career_focus||'mixed')==='doubles_only'?'good':''}">Orientation · ${careerFocusLabel(c.career_focus||'mixed')}</span>${String(c.career_focus||'mixed')==='doubles_only'?'<span class="badge good">Circuit principal</span>':''}</div></div><span class="pill">${fmt(worldStats?.sourcedDoubles||exact)} officiels · ${fmt(worldStats?.indexedDoubles||0)} indexés</span></div>
 ${singlesOnly?'<div class="notice"><b>Simple exclusivement</b> · consultation du circuit double uniquement. Les paires, propositions et inscriptions double sont verrouillées.</div>':''}
 <div class="tabs rank-tabs"><button class="active">Partenariat</button><button onclick="setRankKind('doubles');nav('rankings')">Classement Double</button><button onclick="setRankKind('doubles_race');nav('rankings')">Race Double</button><button onclick="setRankKind('junior_doubles');nav('rankings')">Junior Double</button><button onclick="setRankKind('junior_doubles_race');nav('rankings')">Race Junior Double</button><button onclick="dbCircuit='Double';dbOffset=0;dbQuery='';loadPlayerDatabase().then(()=>nav('players'))">Base double complète</button><button onclick="document.getElementById('dblRace').scrollIntoView({behavior:'smooth'})">Race équipes</button></div>
 <div class="grid g2" style="margin-top:10px">
  <div class="card"><div class="row between"><h2>Partenaire actuel</h2><span class="badge">Ton rang ${careerDoublesRankText(c)}</span></div>
   ${partner?`<div class="row between click" onclick="openPlayer(${partner.id})"><div><h2>${flags[partner.country]||'🏳️'} ${esc(partner.name)}</h2><div class="muted">Double #${fmt(partner.doubles_ranking)} ${partner.ranking?'· ATP #'+partner.ranking:''}</div><div class="muted mini">${partner.doubles_snapshot_date?'réf. '+df(partner.doubles_snapshot_date):''}</div></div><span class="badge good">Partenaire principal</span></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Chimie</span><b>${pairScore(partner,'chem')}%</b></div><div class="kpi"><span class="muted mini">Compatibilité</span><b>${pairScore(partner,'comp')}%</b></div><div class="kpi"><span class="muted mini">Force paire</span><b>${pairScore(partner,'power')}%</b></div><div class="kpi"><span class="muted mini">Engagement</span><b>${managedCommitment?.commitment??'—'}%</b></div></div>${managedCommitment?`<div class="row between muted mini" style="margin-top:8px"><span>Affinité ${managedCommitment.affinity}/100 · depuis ${df(managedCommitment.started_at)}</span><span>${managedCommitment.switches||0} changement${Number(managedCommitment.switches||0)>1?'s':''}</span></div><div class="muted micro" style="margin-top:5px">Le partenaire peut aussi décider de quitter la paire si le projet sportif ou l'engagement se dégrade.</div>`:''}`:'<div class="empty">Choisis un spécialiste dans le classement Double.</div>'}
  </div>
  <div class="card"><div class="row between"><h2>Top double vérifié</h2><button class="ghost" onclick="setRankKind('doubles');nav('rankings')">Voir tout</button></div>
   ${pool.slice(0,12).map(p=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>#${p.doubles_ranking} ${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${p.doubles_points==null?'points non publiés dans ce snapshot':fmt(p.doubles_points)+' pts'} · ${df(p.doubles_snapshot_date)}</div></div>${singlesOnly?'<button class="ghost" disabled>Verrouillé</button>':`<button class="soft-btn" onclick="approachPartner(${p.id})">Approcher</button>`}</div>`).join('')||'<div class="loader">Chargement du classement double…</div>'}
  </div>
 </div>
 ${ownPartnership&&partner?`<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Vie de la paire</div><h2>${esc(c.player_name||'Joueur')} / ${esc(partner.name)}</h2></div><span class="badge ${Number(ownPartnership.momentum||50)>=70?'good':Number(ownPartnership.momentum||50)<45?'bad':''}">Momentum ${fmt(ownPartnership.momentum??50)}%</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Tournois</span><b>${fmt(ownPartnership.events_played||0)}</b></div><div class="kpi"><span class="muted mini">Finales</span><b>${fmt(ownPartnership.finals||0)}</b></div><div class="kpi"><span class="muted mini">Titres</span><b>${fmt(ownPartnership.titles||0)}</b></div><div class="kpi"><span class="muted mini">Dernier match</span><b style="font-size:13px">${ownPartnership.last_played?df(ownPartnership.last_played):'—'}</b></div></div><div class="muted mini" style="margin-top:8px">Les résultats font évoluer la chimie, l’engagement et la force de la paire. Une série de gros résultats stabilise le duo, une mauvaise période peut pousser l’un des deux à partir.</div></div>`:''}
 ${incomingOffers.length||recentOutgoing.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Marché des partenaires</div><h2>Propositions & négociations</h2><div class="muted">Les joueurs peuvent accepter, refuser ou quitter une paire selon leur projet et leur engagement actuel.</div></div><span class="pill">${incomingOffers.length} proposition${incomingOffers.length>1?'s':''} reçue${incomingOffers.length>1?'s':''}</span></div>
 <div class="grid g2">
  ${incomingOffers.length?`<div class="card"><div class="row between"><h2>Ils veulent jouer avec toi</h2><span class="badge good">${incomingOffers.length}</span></div>${incomingOffers.map(x=>{const p=x.from_player||{};return `<div class="list-item"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</b><div class="muted mini">Double ${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'NR'} · ${careerFocusLabel(p.career_focus||'mixed')}</div></div><div style="text-align:right"><b>${x.interest_score}/100</b><div class="muted micro">intérêt</div></div></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:6px"><span class="badge">Chimie ${x.chemistry||'—'}</span><span class="badge">Compat. ${x.compatibility||'—'}</span><span class="badge">Engagement ${x.proposed_commitment||'—'}</span></div><div class="muted micro" style="margin-top:5px">${esc(x.reason||'Proposition de partenariat')}</div><div class="row" style="gap:7px;margin-top:8px"><button class="primary" onclick="respondPartnerOffer(${x.id},'accept')">Accepter</button><button class="ghost" onclick="respondPartnerOffer(${x.id},'decline')">Refuser</button></div></div>`}).join('')}</div>`:''}
  ${recentOutgoing.length?`<div class="card"><div class="row between"><h2>Tes approches récentes</h2><span class="badge">${recentOutgoing.length}</span></div>${recentOutgoing.map(x=>{const p=x.to_player||{};return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name||'Joueur')}</b><div class="muted mini">${esc(x.reason||'Approche partenaire')} · ${df(x.offer_date)}</div></div><span class="badge ${x.status==='accepted'?'good':x.status==='declined'?'bad':''}">${x.status==='accepted'?'Acceptée':x.status==='declined'?'Refusée':esc(x.status)}</span></div>`}).join('')}</div>`:''}
 </div>`:''}
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Circuit Junior</div><h2>Top Junior Double</h2><div class="muted">Classement individuel séparé #1–#2000. Les joueurs peuvent former une paire et jouer le double dans les tournois juniors.</div></div><button class="ghost" onclick="setRankKind('junior_doubles');nav('rankings')">Voir les 2000</button></div>
 <div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Joueur</th><th>Âge 01/12/25</th><th>Pts</th><th></th></tr></thead><tbody>
 ${juniorPool.slice(0,20).map(p=>`<tr><td class="rank-num">#${fmt(p.junior_doubles_ranking)}</td><td class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted micro">Junior simple #${p.junior_ranking||'—'}</div></td><td>${rankAge(p,'junior_doubles')}</td><td>${fmt(p.junior_doubles_points||0)}</td><td>${singlesOnly?'<button class="ghost" disabled>Verrouillé</button>':`<button class="soft-btn" onclick="choosePartner(${p.id})">Associer</button>`}</td></tr>`).join('')}
 </tbody></table></div></div>
 <div id="dblRace" class="section-head" style="margin-top:18px"><div><div class="eyebrow">ATP Finals</div><h2>Race double par équipes</h2><div class="muted">Race double · ${doublesRaceRows[0]?.snapshot_date?df(doublesRaceRows[0].snapshot_date):"snapshot courant"} · ${fmt(doublesRaceRows.length)} équipes chargées.</div></div></div>
 <div class="card"><div class="row between" style="margin-bottom:8px"><span class="muted mini">Historique équipes importé : ${fmt(doublesRaceRows.length)} équipes</span><button class="ghost" onclick="setRankKind(\'doubles\');nav(\'rankings\')">Classement individuel</button></div><div class="table-wrap"><table class="table"><thead><tr><th>#</th><th>Équipe</th><th>Points</th><th>Référence</th></tr></thead><tbody>
 ${doublesRaceRows.map(x=>`<tr><td class="rank-num">#${x.rank}</td><td><b><span class="click" onclick="openPlayerByName('${esc(String(x.player_one||'').replace(/'/g,"\\'"))}')">${esc(x.player_one)}</span> / <span class="click" onclick="openPlayerByName('${esc(String(x.player_two||'').replace(/'/g,"\\'"))}')">${esc(x.player_two)}</span></b></td><td>${fmt(x.points)}</td><td>${df(x.snapshot_date)}</td></tr>`).join('')}
 </tbody></table></div>${!doublesRaceRows.length?'<div class="loader">Chargement de la Race équipes…</div>':''}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Scouting double</div><h2>Spécialistes disponibles</h2></div></div>
 <div class="grid g2">${candidates.slice(0,20).map(p=>`<div class="card"><div class="row between"><div class="click" onclick="openPlayer(${p.id})"><div class="eyebrow">Double #${p.doubles_ranking}</div><h3>${flags[p.country]||'🏳️'} ${esc(p.name)}</h3><div class="muted mini">${p.ranking?'ATP #'+p.ranking+' · ':''}${starRatingHtml(listCurrentStars(p),'Niveau')}${listPotentialStars(p)?' · '+starRatingHtml(listPotentialStars(p),'Potentiel'):' · potentiel à scouter'}</div></div>${singlesOnly?'<button class="ghost" disabled>Verrouillé</button>':`<button class="primary" onclick="approachPartner(${p.id})">Approcher</button>`}</div></div>`).join('')}</div>`
}
function universityPage(){
 const teams=management?.college||[],offers=management?.collegeOffers||[],state=management?.collegeState||{},duals=management?.collegeDuals||[],collegeStaff=management?.collegeTeamStaff||[];
 const collegePlayer=activePlayerCareerView(),committed=state.status==='committed',alumni=state.status==='pro';
 return `<div class="section-head"><div><div class="eyebrow">Circuit universitaire · ${esc(collegePlayer.player_name||'Joueur actif')}</div><h1>NCAA / ITA</h1><div class="muted">Dossier de ${esc(collegePlayer.player_name||'ce joueur')} · recrutement, bourses, team duals, progression académique et passage pro. Chaque joueur géré possède désormais son propre parcours universitaire.</div></div><span class="pill">${committed?'NCAA actif':alumni?'NCAA Alumni':'Recrutement ouvert'}</span></div>
 <div class="grid g2">
  <div class="card"><h2>Ta situation</h2>${committed?`<div class="hero-name" style="font-size:24px">${esc(state.team?.name||'Université')}</div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Bourse</span><b>${state.scholarship_pct}%</b></div><div class="kpi"><span class="muted mini">Confiance coach</span><b>${state.coach_trust}%</b></div><div class="kpi"><span class="muted mini">Académique</span><b>${state.academic_progress}%</b></div><div class="kpi"><span class="muted mini">Éligibilité</span><b>${state.eligibility_years} ans</b></div></div><p class="muted mini" style="margin-top:10px">Position actuelle : #${state.lineup_position||6} dans le lineup équipe.</p><button class="primary" style="margin-top:10px" onclick="turnProCollege()">Passer professionnel</button><div class="muted micro" style="margin-top:6px">Le passage pro archive et certifie cette carrière NCAA dans la sauvegarde.</div>`:alumni?`<div class="hero-name" style="font-size:24px">${esc(state.team?.name||'Université')}</div><span class="badge good">NCAA Alumni · passage pro enregistré</span><p class="muted mini" style="margin-top:10px">La carrière universitaire et les titres restent visibles dans la fiche joueur.</p>`:'<div class="empty">Tu n’as pas encore choisi d’université. Compare les offres avant de t’engager.</div>'}</div>
  <div class="card"><h2>Top équipes ITA</h2>${teams.slice(0,10).map(t=>`<div class="list-item row between click" onclick="openCollegeTeam(${t.id})"><div><b>#${t.ita_rank} ${esc(t.name)}</b><div class="muted mini">Bilan ${esc(t.record)}</div></div><span class="badge">Voir</span></div>`).join('')}</div>
 </div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Recrutement</div><h2>Offres de bourse</h2></div></div>
 <div class="grid g2">${offers.map(o=>`<div class="card"><div class="row between"><div><div class="eyebrow">ITA #${o.team?.ita_rank||'—'}</div><h2>${esc(o.team?.name||'Université')}</h2></div><span class="badge ${o.status==='accepted'?'good':o.status==='declined'?'bad':''}">${esc(o.status)}</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Bourse</span><b>${o.scholarship_pct}%</b></div><div class="kpi"><span class="muted mini">Fit sportif</span><b>${o.development_fit}</b></div><div class="kpi"><span class="muted mini">Fit académique</span><b>${o.academic_fit}</b></div><div class="kpi"><span class="muted mini">Rôle</span><b style="font-size:12px">${esc(o.role)}</b></div></div>${!committed&&!alumni&&o.status==='available'?`<button class="primary" style="margin-top:10px" onclick="commitCollege(${o.id})">S’engager</button>`:''}</div>`).join('')}</div>
 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Saison équipe</div><h2>Team duals</h2></div></div>
 <div class="stack">${duals.map(d=>`<div class="card"><div class="row between"><div><div class="eyebrow">${df(d.match_date)}</div><h2>${esc(d.home?.name||'Home')} vs ${esc(d.away?.name||'Away')}</h2></div>${d.status==='completed'?`<div class="big" style="font-size:25px">${d.home_score}-${d.away_score}</div>`:alumni?'<span class="badge">Archive NCAA</span>':`<button class="primary" onclick="playCollegeDual(${d.id})">Jouer le dual</button>`}</div><div class="muted mini">${d.status==='completed'?'Rencontre terminée':'Lineup simple + double avant la rencontre'}</div></div>`).join('')||'<div class="card empty">Aucun dual programmé.</div>'}</div>`
}
window.openPlayerByName=async name=>{
 try{
  const d=await get('/api/search-players?q='+encodeURIComponent(name)+'&limit=1');
  const p=(d.rows||[])[0];
  if(p)openPlayer(p.id);
 }catch(e){console.warn(e)}
}
window.openCollegeTeam=id=>{
 const t=(management?.college||[]).find(x=>x.id===id);if(!t)return;
 const offers=(management?.collegeOffers||[]).filter(x=>x.team_id===id);
 const staff=(management?.collegeTeamStaff||[]).filter(x=>Number(x.team_id)===Number(id));
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Programme NCAA</div><h1>#${t.ita_rank} ${esc(t.name)}</h1><div class="muted">Bilan ${esc(t.record)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
 <div class="card"><div class="row between"><h2>Staff du programme</h2><span class="badge">${staff.length}</span></div>${staff.length?staff.map(x=>{const sp=x.staff||{};return `<div class="list-item click" onclick="openStaffProfile(${sp.id})"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)} · ${esc(sp.coaching_style||sp.primary_role||'')}</div></div><div style="text-align:right"><b>${sp.reputation??'—'}/20</b><div class="muted micro">réputation</div></div></div><div class="row between muted micro"><span>Coach ${sp.coach_rating??'—'}</span><span>Tact ${sp.tactical_rating??'—'}</span><span>Jeunes ${sp.youth_rating??'—'}</span><span>Physique ${sp.fitness_rating??'—'}</span></div></div>`}).join(''):'<div class="empty">Staff en cours de génération.</div>'}</div>
 <div class="card" style="margin-top:10px"><h2>Recrutement</h2>${offers.length?offers.map(o=>`<div class="list-item"><div class="row between"><span>Bourse</span><b>${o.scholarship_pct}%</b></div><div class="muted mini">${esc(o.role)} · fit sportif ${o.development_fit}/100</div></div>`).join(''):'<div class="empty">Pas d’offre active.</div>'}</div></div></div>`;
}
window.commitCollege=async id=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 try{
  await managerAction('commit_college',id,{player_id:playerId});
  await Promise.all([loadManagement(),loadActiveManagedContext(true,playerId)]);
  render()
 }catch(e){alert(e.message)}
}
window.turnProCollege=async()=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 try{
  if(!confirm('Passer professionnel et quitter la NCAA ? Le dossier universitaire restera archivé.'))return;
  await managerAction('turn_pro_college',1,{player_id:playerId});
  await Promise.all([loadManagement(),loadActiveManagedContext(true,playerId)]);
  render()
 }catch(e){alert(e.message)}
}
window.playCollegeDual=async id=>{try{await managerAction('play_college_dual',id);await loadManagement();render()}catch(e){alert(e.message)}}
function davisPage(){
 const f=boot.federation||{},sq=boot.davisSquad||[],ties=management?.davisTies||[],history=management?.davisHistory||[],allDavisStaff=management?.davisTeamStaff||[];
 const federations=boot.federations||[];
 const nation=String(boot.selectedFederation||f.nation||career().country||'FRA').toUpperCase();
 const roles=['Simple 1','Simple 2','Double A','Double B','Réserve'];
 const doublesOnlyManaged=String(career().career_focus||'mixed')==='doubles_only';
 const singlesOnlyManaged=String(career().career_focus||'mixed')==='singles_only';
 const managedId=Number(career().managed_player_id||0);
 const nationStaff=allDavisStaff.filter(x=>String(x.nation||'').toUpperCase()===nation);
 const today=String(local.date||RANKING_SNAPSHOT);
 const nationTies=ties.filter(t=>t.home_nation===nation||t.away_nation===nation).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const nextTie=nationTies.find(t=>t.status!=='completed'&&String(t.tie_date)>=today)||null;
 const lastTie=[...nationTies].reverse().find(t=>t.status==='completed'||String(t.tie_date)<today)||null;
 const focusTie=nextTie||lastTie||nationTies[0]||null;
 const final8=ties.filter(t=>String(t.stage||'').includes('Final 8')).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const worldQualifiers=ties.filter(t=>!String(t.stage||'').includes('Final 8')).sort((a,b)=>String(a.tie_date).localeCompare(String(b.tie_date)));
 const nationAlive=final8.some(t=>t.home_nation===nation||t.away_nation===nation);
 const seniorHistory=history.filter(x=>x.competition==='senior').sort((a,b)=>b.season-a.season);
 const juniorHistory=history.filter(x=>x.competition==='junior').sort((a,b)=>b.season-a.season);
 const scoreFor=t=>t.home_score!=null&&t.away_score!=null?`${t.home_score}-${t.away_score}`:'vs';
 const tieCard=t=>{const unresolved=/^(TBD|Winner )/i.test(String(t.home_nation||''))||/^(TBD|Winner )/i.test(String(t.away_nation||''));const ready=t.status!=='completed'&&!unresolved;return `<div class="davis-tie-card ${t.status==='completed'?'completed':''} ${ready?'click':''}" ${ready?`onclick="playDavisTie(${t.id})"`:''}>
   <div class="row between"><span class="badge tag-fed">${esc(t.stage||'Coupe Davis')}</span><span class="muted mini">${df(t.tie_date)}</span></div>
   <div class="davis-matchup"><b>${flags[t.home_nation]||'🏳️'} ${esc(t.home_nation)}</b><strong>${scoreFor(t)}</strong><b>${flags[t.away_nation]||'🏳️'} ${esc(t.away_nation)}</b></div>
   <div class="row between" style="margin-top:7px"><div class="muted mini">${esc(t.venue||'Lieu à confirmer')} · <span class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</span></div>${ready?'<span class="badge warn">Simuler</span>':t.status==='completed'?'<span class="badge good">Terminé</span>':'<span class="badge">En attente</span>'}</div>
 </div>`};
 const historyRows=rows=>rows.map(x=>`<div class="list-item row between"><div><b>${x.season}</b> · ${flags[x.winner_country]||'🏳️'} ${esc(x.winner_country||'Non disputé')}</div><div style="text-align:right"><b>${esc(x.score||'—')}</b><div class="muted micro">${x.runner_up_country?(flags[x.runner_up_country]||'🏳️')+' '+esc(x.runner_up_country):esc(x.venue||'')}</div></div></div>`).join('');
 const selector=`<select class="select" style="min-width:190px" onchange="selectFederation(this.value)">${federations.map(x=>`<option value="${esc(x.nation)}" ${x.nation===nation?'selected':''}>${flags[x.nation]||'🏳️'} ${esc(x.nation)} · ${x.reputation}/100</option>`).join('')}</select>`;
 return `<div class="fm-dashboard">
 <div class="fm-page-head"><div><div class="eyebrow">Équipe nationale</div><h1>Coupe Davis</h1><div class="muted">Fédération sélectionnable · calendrier mondial figé au 01/12/2025 puis simulé par la carrière.</div></div><div class="fm-head-stack">${selector}<div class="fm-head-badge">${flags[nation]||'🏳️'} ${nation} ${f.reputation||'—'}/100</div><div class="fm-head-badge subtle">${nationAlive?'Final 8':'Parcours / qualifications'}</div></div></div>

 <div class="grid g2">
  <div class="card davis-focus">
   <div class="row between"><div><div class="eyebrow">${nextTie?'Prochaine rencontre '+nation:'Dernière rencontre '+nation}</div><h2>${focusTie?`${flags[focusTie.home_nation]||'🏳️'} ${esc(focusTie.home_nation)} ${scoreFor(focusTie)} ${esc(focusTie.away_nation)} ${flags[focusTie.away_nation]||'🏳️'}`:'Aucune rencontre chargée'}</h2></div>${nextTie?'<span class="badge warn">À venir</span>':'<span class="badge">Archive</span>'}</div>
   ${focusTie?`<div class="list-item row between"><span>Date</span><b>${df(focusTie.tie_date)}</b></div><div class="list-item row between"><span>Phase</span><b>${esc(focusTie.stage||'—')}</b></div><div class="list-item row between"><span>Terrain</span><b class="${surfaceClass(surfaceLabel(focusTie))}">${esc(surfaceLabel(focusTie))}</b></div><div class="list-item row between"><span>Lieu</span><b>${esc(focusTie.venue||'—')}</b></div>`:''}
   ${nextTie?'<button class="primary" style="margin-top:10px" onclick="playDavisTie('+nextTie.id+')">Jouer la rencontre</button>':'<div class="notice" style="margin-top:10px">Aucune rencontre future connue pour cette fédération dans le calendrier actuellement chargé.</div>'}
  </div>
  <div class="card"><div class="row between"><div><div class="eyebrow">Sélection</div><h2>${flags[nation]||'🏳️'} ${nation}</h2></div><span class="pill">${sq.length} joueurs</span></div>
   ${sq.map(sqRow=>{const p=sqRow.players;if(!p)return'';const role=local.davisRoles[p.id]||sqRow.role||'Réserve';const ownDoubleOnly=doublesOnlyManaged&&Number(p.id)===managedId;const ownSinglesOnly=singlesOnlyManaged&&Number(p.id)===managedId;const allowedRoles=ownDoubleOnly?roles.filter(r=>!/^Simple/.test(r)):ownSinglesOnly?roles.filter(r=>!/^Double/.test(r)):roles;return `<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${esc(p.name)} ${ownDoubleOnly?'<span class="badge good">Double uniquement</span>':ownSinglesOnly?'<span class="badge good">Simple uniquement</span>':''}</b><div class="muted mini">ATP #${p.ranking||'—'} · Double #${fmt(p.doubles_ranking||9999)}</div></div><select class="select" style="width:auto" onchange="setDavisRole(${p.id},this.value)">${allowedRoles.map(r=>`<option ${r===role?'selected':''}>${r}</option>`).join('')}</select></div>`}).join('')||'<div class="empty">Aucun joueur sélectionné. La sélection sera générée depuis les meilleurs joueurs du pays.</div>'}
  </div>
 </div>

 <div class="card" style="margin-top:14px"><div class="row between"><div><div class="eyebrow">Encadrement national</div><h2>Staff Coupe Davis</h2></div><span class="pill">${nationStaff.length} membres</span></div>
  <div class="grid g2" style="margin-top:8px">${nationStaff.map(x=>{const sp=x.staff||{};return `<div class="list-item click" onclick="openStaffProfile(${sp.id})"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)}${x.part_time?' · temps partiel':''}</div></div><span class="badge">${sp.reputation??'—'}/20</span></div><div class="row between muted micro"><span>Tact ${sp.tactical_rating??'—'}</span><span>Mental ${sp.mental_rating??'—'}</span><span>Physique ${sp.fitness_rating??'—'}</span><span>Médical ${sp.medical_rating??'—'}</span></div></div>`}).join('')||'<div class="empty">Staff fédéral en cours de génération.</div>'}</div>
 </div>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Parcours ${nation}</div><h2>Rencontres de la fédération</h2></div></div>
 <div class="davis-timeline">${nationTies.map(tieCard).join('')||'<div class="card empty">Aucune rencontre chargée pour cette fédération.</div>'}</div>

 <details class="card davis-world-qualifiers" style="margin-top:16px">
  <summary class="row between"><div><div class="eyebrow">Monde</div><h2>Qualifications Coupe Davis 2025</h2></div><span class="pill">${worldQualifiers.length} rencontres</span></summary>
  <div class="davis-bracket" style="margin-top:10px">${worldQualifiers.map(tieCard).join('')||'<div class="empty">Aucune rencontre mondiale chargée.</div>'}</div>
 </details>

 <div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Bologne</div><h2>Final 8 2025</h2><div class="muted">Parcours archivé jusqu’au 01/12/2025.</div></div><span class="badge good">Dur intérieur</span></div>
 <div class="davis-bracket">${final8.map(tieCard).join('')||'<div class="card empty">Tableau Final 8 indisponible.</div>'}</div>

 <div class="grid g2" style="margin-top:18px">
  <details class="card" open><summary><div class="eyebrow">Palmarès officiel</div><h2>Coupe Davis senior · 1900–2025</h2></summary><div class="stack" style="margin-top:10px">${historyRows(seniorHistory)}</div></details>
  <details class="card" open><summary><div class="eyebrow">Palmarès U16</div><h2>Junior Davis Cup · 1985–2025</h2></summary><div class="stack" style="margin-top:10px">${historyRows(juniorHistory)}</div></details>
 </div>

 ${focusTie?.davis_rubbers?.length?`<div class="section-head" style="margin-top:18px"><div><div class="eyebrow">Détail</div><h2>Rubbers de la rencontre ${nation}</h2></div></div><div class="stack">${focusTie.davis_rubbers.sort((x,y)=>x.rubber_no-y.rubber_no).map(r=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(r.rubber_type)} · Rubber ${r.rubber_no}</div><h2>${esc(r.home_names)} vs ${esc(r.away_names)}</h2></div><div style="text-align:right"><div class="big" style="font-size:22px">${esc(r.score||'—')}</div><span class="badge ${r.winner_nation===nation?'good':'bad'}">${esc(r.winner_nation||'—')}</span></div></div></div>`).join('')}</div>`:''}
 </div>`
}
window.selectFederation=async nation=>{
 try{
  await managerAction('select_federation',1,{nation});
  boot=await get('/api/bootstrap');
  local.career={...(local.career||{}),...(boot.career||{})};
  await loadManagement();
  render();
 }catch(e){alert(e.message)}
}
window.playDavisTie=async id=>{
 try{
  const d=await managerAction('play_davis_tie',id);
  await refreshManagerState();
  if(d.tie&&management?.davisTies){
    const ix=management.davisTies.findIndex(x=>x.id===id);
    if(ix>=0)management.davisTies[ix]={...d.tie,davis_rubbers:d.rubbers||[]};
  }
  render();
 }catch(e){alert(e.message)}
}
function boardPage(){const a=boot.academy||{};return `<div class="section-head"><div><div class="eyebrow">Direction</div><h1>Board</h1><div class="muted">Confiance : ${a.board_confidence||76}%</div></div></div><div class="stack">${(boot.board||[]).map(o=>`<div class="card"><div class="row between"><div><h2>${esc(o.objective)}</h2><div class="muted">${esc(o.target_value||'')} · échéance ${df(o.deadline)}</div></div><b>${o.progress}%</b></div><div class="bar"><i style="width:${o.progress}%"></i></div></div>`).join('')}</div>`}
function worldPage(){
 const w=worldStats||{};
 return `<div class="section-head"><div><div class="eyebrow">Écosystème</div><h1>Monde du tennis</h1><div class="muted">Base mondiale, circuits séparés et simulation persistante.</div></div><button class="ghost" onclick="get('/api/world').then(x=>{worldStats=x;render()})">Actualiser</button></div>
 <div class="kpi-strip">
  <div class="kpi click" onclick="nav('players')"><span class="muted mini">Joueurs réels recherchables</span><b>${fmt(w.searchableRealPlayers||w.realPlayersTotal||w.playersTotal||10000)}</b></div>
  <div class="kpi click" onclick="setRankKind('singles');nav('rankings')"><span class="muted mini">Classés ATP</span><b>${fmt(w.atpRanked??0)}</b></div>
  <div class="kpi click" onclick="nav('calendar')"><span class="muted mini">Tournois</span><b>${fmt(w.tournaments||0)}</b></div>
  <div class="kpi"><span class="muted mini">Tournois vérifiés</span><b>${fmt(w.verifiedTournaments||0)}</b></div>
 </div>
 <div class="menu-grid" style="margin-top:14px">
  <div class="menu-card" onclick="setRankKind('singles');nav('rankings')"><div class="menu-icon">🎾</div><strong>ATP</strong><span class="muted">${fmt(w.atpRanked??0)} joueurs classés</span></div>
  <div class="menu-card" onclick="setRankKind('doubles');nav('rankings')"><div class="menu-icon">◉◉</div><strong>ATP Double</strong><span class="muted">${fmt(w.sourcedDoubles||0)} sourcés · ${fmt(w.indexedDoubles||0)} indexés</span></div>
  <div class="menu-card" onclick="setRankKind('itf');nav('rankings')"><div class="menu-icon">🌍</div><strong>ITF WTT</strong><span class="muted">${fmt(w.itfPlayers||0)} profils avec rang ITF</span></div>
  <div class="menu-card" onclick="setRankKind('junior');nav('rankings')"><div class="menu-icon">🌱</div><strong>Junior</strong><span class="muted">${fmt(w.juniorPlayers||0)} profils juniors</span></div>
  <div class="menu-card" onclick="rankKind='ncaa';rankOffset=0;rankQuery='';loadRankings().then(()=>nav('rankings'))"><div class="menu-icon">🎓</div><strong>NCAA / ITA</strong><span class="muted">${fmt(w.ncaaProfilesTotal||w.ncaaPlayers||0)} profils · ${fmt(w.ncaaActiveProfiles||w.ncaaPlayers||0)} actifs</span></div>
  <div class="menu-card" onclick="nav('scouting')"><div class="menu-icon">🔎</div><strong>Newgens</strong><span class="muted">${fmt(w.gameGenerated||0)} joueurs générés par Court Boss</span></div>
  <div class="menu-card" onclick="nav('competitions')"><div class="menu-icon">🏆</div><strong>Compétitions</strong><span class="muted">ATP, Challenger, ITF, Junior, NCAA, Davis</span></div>
  <div class="menu-card" onclick="nav('history')"><div class="menu-icon">🏛️</div><strong>Histoire & nations</strong><span class="muted">Meilleurs historiques par pays et continent</span></div>
 </div>
 <div class="card" style="margin-top:14px"><div class="row between"><div><div class="eyebrow">Couverture réelle</div><h2>Base de données</h2></div><span class="badge good">${fmt(w.searchableRealPlayers||0)} joueurs</span></div>
 <div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Âges connus</span><b>${fmt(w.realPlayersWithAge||0)}</b></div><div class="kpi"><span class="muted mini">ATP officiel</span><b>${fmt(w.officialATP||0)}</b></div><div class="kpi"><span class="muted mini">Challenger</span><b>${fmt(w.officialChallenger||0)}</b></div><div class="kpi"><span class="muted mini">ITF M15/M25</span><b>${fmt(w.officialITF||0)}</b></div><div class="kpi"><span class="muted mini">Junior vérifié</span><b>${fmt(w.officialJunior||0)}</b></div><div class="kpi"><span class="muted mini">NCAA vérifié</span><b>${fmt(w.officialNCAA||0)}</b></div></div>
 <div class="muted mini" style="margin-top:9px">${w.currentRankedMissingAge?'Il reste '+fmt(w.currentRankedMissingAge)+' âge(s) non renseigné(s) dans le classement ATP courant.':'Classement ATP courant : âge renseigné pour chaque joueur.'} ${w.currentRankedMissingDob?fmt(w.currentRankedMissingDob)+' joueur(s) ont un âge vérifié mais pas encore de date de naissance exacte, donc la date reste N/V.':'Les dates de naissance du classement ATP courant sont complètes.'}</div></div>
 <div class="card" style="margin-top:14px"><h2>Comment le monde évolue</h2><p class="muted">À chaque semaine, les tournois arrivés à terme sont simulés, les points bougent, les classements sont recalculés, les joueurs vieillissent, les blessures évoluent et les palmarès se remplissent. À l'intersaison, retraites et newgens maintiennent le vivier mondial.</p></div>`
}

function historyPage(){
 const d=historyData||{rows:[],countryBest:[],continentBest:[],hallOfFame:[],grandSlamRecords:[],u18:[],u21:[],coverage:{players:0,countries:0,ncaaProfiles:0}};
 const rows=d.rows||[],global=rows[0]||null,rec=d.nationalRecords||{};
 const continents=['','Europe','North America','South America','Asia','Africa','Oceania'];
 const recordCard=(label,x,field,suffix='')=>x?`<div class="fm-record click" onclick="openPlayer(${x.id})"><span>${label}</span><b>${flags[x.country]||'🏳️'} ${esc(x.name)}</b><strong>${fmt(x[field]||0)}${suffix}</strong></div>`:'';
 const youth=(arr,title)=>`<div class="card fm-squad-card"><div class="row between"><div><div class="eyebrow">Prospects</div><h2>${title}</h2></div><span class="badge">${arr.length}</span></div>${arr.slice(0,12).map((p,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${p.id})"><div class="fm-rank-dot">#${i+1}</div><div class="grow"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${p.age} ans · ${p.ranking?'ATP #'+fmt(p.ranking):p.junior_ranking?'Junior #'+fmt(p.junior_ranking):'Non classé'} ${p.game_generated?'· Newgen '+p.generated_year:''}</div></div><div style="text-align:right"><b>${starRatingHtml(publicLevelStars(p),'Niveau public')}</b><div class="muted mini">Potentiel à scouter</div></div></div>`).join('')||'<div class="empty">Aucun joueur.</div>'}</div>`;
 return `<div class="fm-dashboard">
  <div class="fm-page-head"><div><div class="eyebrow">Data hub historique · Open Era</div><h1>Histoire, records & nations</h1><div class="muted">Finales ATP indexées depuis 1968, légendes, Hall of Fame, records de Grand Chelem et générations U18/U21 dans la même base.</div></div><div class="fm-head-stack"><div class="fm-head-badge">${fmt(d.coverage?.historicalPlayers||0)} historiques</div><div class="fm-head-badge subtle">${fmt(d.coverage?.countries||0)} nations</div><div class="fm-head-badge subtle">${fmt(d.coverage?.ncaaProfiles||0)} NCAA</div></div></div>
  <div class="fm-filterbar">
   <select class="select" onchange="setHistoryCountry(this.value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}" ${historyCountry===x.country?'selected':''}>${flags[x.country]||'🏳️'} ${esc(x.country)} · ${fmt(x.players)}</option>`).join('')}</select>
   <select class="select" onchange="setHistoryContinent(this.value)">${continents.map(x=>`<option value="${esc(x)}" ${historyContinent===x?'selected':''}>${x||'Tous continents'}</option>`).join('')}</select>
   <button class="primary" onclick="openHistoryArchive()">Base historique complète</button>
   <button class="ghost" onclick="historyCountry='';historyContinent='';loadHistory().then(render)">Réinitialiser</button>
  </div>
  ${global?`<div class="fm-history-hero card click" onclick="openPlayer(${global.id})"><div><div class="eyebrow">Référence de la sélection</div><div class="hero-name">${flags[global.country]||'🏳️'} ${esc(global.name)}</div><div class="muted">${esc(global.country)} · ${esc(global.continent)} · ${global.career_status==='retired'?'Retraité':'Actif'}</div></div><div class="fm-history-score"><span>Indice historique</span><b>${fmt(global.history_score)}</b></div><div class="fm-history-stats"><div><span>Grand Chelem</span><b>${global.grand_slams}</b></div><div><span>Titres</span><b>${global.titles}</b></div><div><span>Victoires</span><b>${fmt(global.wins)}</b></div><div><span>% victoires</span><b>${global.win_pct==null?'—':global.win_pct+'%'}</b></div></div></div>`:''}

  <div class="fm-record-grid">
   ${recordCard('Record Grand Chelem',rec.grand_slams,'grand_slams',' GC')}
   ${recordCard('Record titres',rec.titles,'titles','')}
   ${recordCard('Record victoires',rec.wins,'wins','')}
   ${recordCard('Semaines n°1 mondial',rec.weeks_at_no1,'weeks_at_no1',' sem.')}
   ${recordCard('Semaines Top 10',rec.weeks_top10,'weeks_top10',' sem.')}
   ${recordCard('Semaines Top 100',rec.weeks_top100,'weeks_top100',' sem.')}
   ${rec.win_pct?`<div class="fm-record click" onclick="openPlayer(${rec.win_pct.id})"><span>Meilleur % victoires</span><b>${flags[rec.win_pct.country]||'🏳️'} ${esc(rec.win_pct.name)}</b><strong>${rec.win_pct.win_pct}%</strong></div>`:''}
  </div>

  <div class="grid g2" style="margin-top:12px">
   <div class="card"><div class="row between"><div><div class="eyebrow">Court Boss Hall of Fame</div><h2>Légendes majeures</h2></div><span class="badge">${(d.hallOfFame||[]).length}</span></div>${(d.hallOfFame||[]).slice(0,40).map((x,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">${i+1}</div><div class="grow"><b>${flags[x.country]||'🏳️'} ${esc(x.name)}</b><div class="muted mini">${x.grand_slams} GC · ${x.titles} titres · ${fmt(x.wins)} victoires</div></div><b>${fmt(x.history_score)}</b></div>`).join('')}</div>
   <div class="card"><div class="row between"><div><div class="eyebrow">Records majeurs</div><h2>Grand Chelem</h2></div><span class="badge">Historique</span></div>${(d.grandSlamRecords||[]).slice(0,24).map((x,i)=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">${i+1}</div><div class="grow"><b>${esc(x.name)}</b><div class="muted mini">${flags[x.country]||'🏳️'} ${esc(x.country)} · ${x.titles} titres</div></div><strong class="a-good">${x.grand_slams} GC</strong></div>`).join('')}</div>
  </div>

  <div class="grid g2" style="margin-top:12px">${youth(d.u18||[],'Top U18')}${youth(d.u21||[],'Top U21')}</div>

  <div class="grid g2" style="margin-top:12px">
   <div class="card"><div class="row between"><div><div class="eyebrow">Par continent</div><h2>Références historiques</h2></div><span class="badge">Top par zone</span></div>${(d.continentBest||[]).filter(x=>x.continent!=='Other').map(x=>`<div class="fm-scout-row click" onclick="openPlayer(${x.id})"><div class="fm-rank-dot">#1</div><div class="grow"><b>${esc(x.continent)} · ${esc(x.name)}</b><div class="muted mini">${flags[x.country]||'🏳️'} ${esc(x.country)} · ${x.grand_slams} GC · ${x.titles} titres</div></div><b>${fmt(x.history_score)}</b></div>`).join('')||'<div class="empty">Pas assez de données historiques.</div>'}</div>
   <div class="card"><div class="row between"><div><div class="eyebrow">Par nationalité</div><h2>Meilleur de chaque pays</h2></div><span class="badge">${fmt((d.countryBest||[]).length)} pays</span></div><div class="fm-country-grid">${(d.countryBest||[]).slice(0,32).map(x=>`<button class="fm-country-tile" onclick="historyContinent='';setHistoryCountry('${esc(x.country)}')"><span>${flags[x.country]||'🏳️'} ${esc(x.country)}</span><b>${esc(x.name)}</b><small>${x.grand_slams} GC · ${x.titles} titres</small></button>`).join('')}</div></div>
  </div>

  <div class="card fm-panel" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Classement historique</div><h2>${historyCountry?'Nationalité '+esc(historyCountry):historyContinent?esc(historyContinent):'Monde'}</h2></div><span class="pill">${fmt(rows.length)} profils</span></div>
   <div class="table-wrap"><table class="table fm-history-table"><thead><tr><th>#</th><th>Joueur</th><th>Pays</th><th>Peak</th><th>Sem. #1</th><th>Top 10</th><th>Top 100</th><th>GC</th><th>Titres</th><th>Indice</th></tr></thead><tbody>${rows.map((x,i)=>`<tr class="click" onclick="openPlayer(${x.id})"><td class="rank-num">#${i+1}</td><td><b>${esc(x.name)}</b><div class="muted micro">${x.career_status==='retired'?'Retraité':'Actif'}</div></td><td>${flags[x.country]||'🏳️'} ${esc(x.country)}</td><td><b>${x.career_high_rank?'#'+fmt(x.career_high_rank):'—'}</b></td><td>${fmt(x.weeks_at_no1||0)}</td><td>${fmt(x.weeks_top10||0)}</td><td>${fmt(x.weeks_top100||0)}</td><td><b>${x.grand_slams}</b></td><td>${x.titles}</td><td class="a-good"><b>${fmt(x.history_score)}</b></td></tr>`).join('')}</tbody></table></div>
  </div>
  <div class="notice mini" style="margin-top:12px">${esc(d.methodology||'Indice historique Court Boss calculé sur les données de carrière importées.')} Le Hall of Fame est une vue du jeu, pas un classement officiel.</div>
 </div>`
}
window.setHistoryCountry=async c=>{historyCountry=String(c||'').toUpperCase();if(c)historyContinent='';await loadHistory();render()}
window.setHistoryContinent=async c=>{historyContinent=String(c||'');if(c)historyCountry='';await loadHistory();render()}
window.openHistoryArchive=()=>{
 overlay.innerHTML="<div class='modal' onclick='if(event.target===this)closeOverlay()'><div class='sheet'><div class='sheet-head'><div><div class='eyebrow'>Open Era 1968–2025</div><h1>Base historique complète</h1><div class='muted'>13 000+ profils historiques, pas seulement le Hall of Fame.</div></div><button class='close' onclick='closeOverlay()'>✕</button></div><div class='filters' style='margin-top:12px'><input id='historyArchiveInput' class='input' placeholder='Connors, Borg, McEnroe, Lendl…' value='"+esc(historyQuery)+"' onkeydown='if(event.key===\"Enter\")runHistoryArchiveSearch(this.value,0)'><select id='historyArchiveCountry' class='select' onchange='runHistoryArchiveSearch(document.getElementById(\"historyArchiveInput\").value,0)'><option value=''>Toutes nationalités</option>"+countryRows.map(x=>"<option value='"+esc(x.country)+"' "+(historyCountry===x.country?"selected":"")+">"+(flags[x.country]||"🏳️")+" "+esc(x.country)+"</option>").join("")+"</select><button class='primary' onclick='runHistoryArchiveSearch(document.getElementById(\"historyArchiveInput\").value,0)'>Rechercher</button></div><div id='historyArchiveResults' style='margin-top:12px'><div class='loader'>Chargement de l’archive…</div></div></div></div>";
 runHistoryArchiveSearch(historyQuery||"",historyDbOffset||0);
}
window.runHistoryArchiveSearch=async(q,offset=0)=>{
 historyQuery=String(q||"").trim();historyDbOffset=Math.max(0,Number(offset)||0);
 const box=document.getElementById("historyArchiveResults");if(!box)return;
 box.innerHTML="<div class='loader'>Recherche historique…</div>";
 try{
  const country=document.getElementById("historyArchiveCountry")?.value||"";
  const p=new URLSearchParams({offset:String(historyDbOffset),limit:"100"});
  if(historyQuery)p.set("q",historyQuery);
  if(country)p.set("country",country);
  const d=await get("/api/history-players?"+p.toString());
  historyDbRows=d.rows||[];historyDbCount=d.count||0;
  const body=historyDbRows.map((x,i)=>"<tr class='click' onclick='openPlayer("+x.id+")'><td class='rank-num'>#"+fmt(historyDbOffset+i+1)+"</td><td><b>"+esc(x.name)+"</b><div class='muted micro'>"+(x.career_status==="retired"?"Retraité":"Actif")+"</div></td><td>"+(flags[x.country]||"🏳️")+" "+esc(x.country||"—")+"</td><td><b>"+(x.career_high_rank?"#"+fmt(x.career_high_rank):"—")+"</b></td><td>"+fmt(x.weeks_at_no1||0)+"</td><td>"+fmt(x.weeks_top10||0)+"</td><td>"+fmt(x.weeks_top100||0)+"</td><td><b>"+fmt(x.grand_slams||0)+"</b></td><td>"+fmt(x.titles||0)+"</td><td>"+fmt(x.wins||0)+"</td><td class='a-good'><b>"+fmt(x.history_score||0)+"</b></td></tr>").join("");
  box.innerHTML="<div class='row between'><div><div class='eyebrow'>Résultats</div><h2>"+(historyQuery?"Recherche : "+esc(historyQuery):"Archive complète")+"</h2></div><span class='pill'>"+fmt(historyDbCount)+" profils</span></div><div class='table-wrap'><table class='table fm-history-table'><thead><tr><th>#</th><th>Joueur</th><th>Pays</th><th>Peak</th><th>Sem. #1</th><th>Top 10</th><th>Top 100</th><th>GC</th><th>Titres</th><th>Victoires</th><th>Indice</th></tr></thead><tbody>"+body+"</tbody></table></div><div class='pagination'><button "+(historyDbOffset===0?"disabled":"")+" onclick='historyArchivePage(-1)'>←</button><span class='muted mini'>"+(historyDbCount?fmt(historyDbOffset+1):0)+"–"+fmt(Math.min(historyDbOffset+historyDbRows.length,historyDbCount))+" / "+fmt(historyDbCount)+"</span><button "+(historyDbOffset+100>=historyDbCount?"disabled":"")+" onclick='historyArchivePage(1)'>→</button></div>";
 }catch(e){box.innerHTML="<div class='empty'>Recherche impossible : "+esc(e.message)+"</div>"}
}
window.historyArchivePage=d=>runHistoryArchiveSearch(historyQuery,Math.max(0,historyDbOffset+Number(d)*100));


function abilityStarValue(score){
 const n=Math.max(0,Math.min(100,Number(score||0)));
 if(n>=94)return 5;
 if(n>=89)return 4.5;
 if(n>=83)return 4;
 if(n>=77)return 3.5;
 if(n>=70)return 3;
 if(n>=63)return 2.5;
 if(n>=56)return 2;
 if(n>=49)return 1.5;
 if(n>=42)return 1;
 return .5;
}
function starRatingHtml(value,label=''){
 const v=Math.max(.5,Math.min(5,Number(value||0)));
 const full=Math.floor(v),half=v-full>=.5;
 const glyph='★'.repeat(full)+(half?'◐':'')+'☆'.repeat(Math.max(0,5-full-(half?1:0)));
 return `<span class="player-star-rating" title="${esc(label||'')}"><span class="player-star-glyph">${glyph}</span><b>${v.toFixed(1)}</b></span>`;
}
function renderPlayerRolePanel(roleFit,dev,p,scoutReport,isManaged){
 if(roleFit){
  const defs=[
   ['Serveur-volée','serve_volley'],['Serveur-attaquant','serve_attacker'],
   ['Attaquant fond de court','attacking_baseliner'],['Contreur','counterpuncher'],
   ['All-court','all_court'],['Défenseur de fond','clay_grinder'],
   ['Spécialiste double','doubles_specialist']
  ];
  const rows=defs.map(x=>({name:x[0],score:Number(roleFit[x[1]]||0)})).sort((x,y)=>y.score-x.score);
  let out='<div class="card" style="margin-bottom:12px">';
  out+='<div class="row between"><div><div class="eyebrow">Rôles dynamiques</div><h2>'+esc(roleFit.preferred_role||dev.preferred_archetype||p.style||'Profil')+'</h2>';
  out+='<div class="muted mini">Secondaire : '+esc(roleFit.secondary_role||'—')+' · le rôle évolue avec le profil technique, tactique, physique et la carrière.</div></div>';
  out+='<span class="badge">'+starRatingHtml(roleFit.role_stars||abilityStarValue(roleFit.preferred_role_score||0),'Adéquation au rôle')+'</span></div>';
  out+='<div class="grid g2" style="margin-top:10px">';
  for(const x of rows){
   const stars=abilityStarValue(x.score);
   out+='<div class="attr-row"><div class="row between"><span>'+esc(x.name)+'</span><b>'+starRatingHtml(stars)+' <span class="muted micro">'+Math.round(x.score)+'/100</span></b></div>';
   out+='<div class="bar"><i style="width:'+Math.max(0,Math.min(100,x.score))+'%"></i></div></div>';
  }
  out+='</div><div class="muted micro" style="margin-top:8px">Ces étoiles décrivent l’adéquation au rôle, pas le niveau global du joueur. Un 5★ mondial peut être moins naturel dans un rôle particulier.</div></div>';
  return out;
 }
 if(scoutReport){
  return '<div class="card" style="margin-bottom:12px"><div class="eyebrow">Rôle estimé par le scout</div><h2>'+esc(scoutReport.archetype_read||p.style||'À préciser')+'</h2><div class="muted mini">Les compatibilités détaillées par rôle nécessitent une connaissance très élevée du joueur.</div></div>';
 }
 return '<div class="card" style="margin-bottom:12px"><div class="eyebrow">Rôle</div><h2>'+esc(p.style||'À observer')+'</h2><div class="muted mini">Mission de scouting requise pour mesurer précisément les rôles naturels.</div></div>';
}
function publicLevelStars(p){
 const r=Number(p?.ranking||p?.game_world_rank||999999);
 if(r<=5)return 5;
 if(r<=20)return 4.5;
 if(r<=60)return 4;
 if(r<=150)return 3.5;
 if(r<=350)return 3;
 if(r<=800)return 2.5;
 if(r<=1800)return 2;
 return 1.5;
}

function scoutingReportForPlayer(id){
 return (boot?.scoutingReports||[]).find(x=>Number(x.player_id)===Number(id))||null;
}
function listCurrentStars(p){
 const own=Number(p?.id)===Number(career().managed_player_id||0),r=scoutingReportForPlayer(p?.id);
 if(own)return Number(p?.current_ability!=null?abilityStarValue(p.current_ability):publicLevelStars(p));
 if(r)return Number(r.estimated_world_current_stars??r.estimated_current_stars??publicLevelStars(p));
 return publicLevelStars(p);
}
function listPotentialStars(p){
 const own=Number(p?.id)===Number(career().managed_player_id||0),r=scoutingReportForPlayer(p?.id);
 if(own)return Number(p?.potential!=null?abilityStarValue(p.potential):0);
 if(r)return Number(r.estimated_world_potential_stars??r.estimated_potential_stars??0)||null;
 return null;
}
function rankingLevelKnowledgeCell(p){
 const own=Number(p?.id)===Number(career().managed_player_id||0),r=scoutingReportForPlayer(p?.id);
 const stars=listCurrentStars(p);
 const note=own?(p.current_ability!=null?'CA '+p.current_ability:'Connu'):r?((r.estimated_ca_min??'?')+'–'+(r.estimated_ca_max??'?')+' · '+(r.confidence??0)+'%'):'Public';
 return starRatingHtml(stars,own?'Niveau connu':r?'Estimation scout':'Estimation publique')+'<div class="muted micro">'+note+'</div>';
}
function rankingPotentialKnowledgeCell(p){
 const own=Number(p?.id)===Number(career().managed_player_id||0),r=scoutingReportForPlayer(p?.id),stars=listPotentialStars(p);
 if(own)return starRatingHtml(stars||.5,'Potentiel connu')+'<div class="muted micro">PA dynamique</div>';
 if(r&&stars)return starRatingHtml(stars,'Potentiel scout')+'<div class="muted micro">'+(r.estimated_potential_star_min??'?')+'–'+(r.estimated_potential_star_max??'?')+' ★</div>';
 return '<span class="muted">À scouter</span>';
}
function playerKnowledgeLabel(isManaged,report){
 if(isManaged)return 'Connaissance complète';
 if(report){
  const level=String(report.knowledge_level||(
    Number(report.confidence||0)>=85?'Étendue':
    Number(report.confidence||0)>=70?'Raisonnable':
    Number(report.confidence||0)>=55?'Minimale':'Très faible'
  ));
  return level+' · '+Number(report.confidence||0)+'%';
 }
 return 'Connaissance publique · fourchettes';
}
function attrTrendMarkup(key,trend){
 const d=Number(trend?.deltas?.[key]||0);
 if(!d)return '';
 return `<small class="${d>0?'good':'bad'}" style="margin-left:5px;font-weight:800">${d>0?'▲ +':'▼ '}${d}</small>`;
}
function developmentTypeLabel(v){
 return v==='early'?'Précoce':v==='late'?'Tardif':'Standard';
}
function developmentTypeDescription(v){
 return v==='early'?'Progression rapide et pic plus jeune.'
  :v==='late'?'Progression plus lente avec marge de développement plus tardive.'
  :'Courbe de progression équilibrée, pic généralement au milieu de la vingtaine.';
}
function estimatedTacticalProfileFromScouting(attrs={},report=null){
 const v=k=>Number(attrs?.[k]);
 const ok=k=>Number.isFinite(v(k));
 if(!Object.keys(attrs||{}).length)return {};
 const clamp=n=>Math.max(1,Math.min(20,Math.round(n)));
 const val=(k,f=10)=>ok(k)?v(k):f;
 return {
   baseline_depth:clamp(12+val('patience')*.25-val('aggression')*.20+val('court_positioning')*.12),
   net_frequency:clamp(val('volley')*.30+val('net_positioning')*.30+val('transition_game')*.20+val('touch')*.20),
   rally_length_preference:clamp(val('rally_tolerance')*.45+val('patience')*.25+val('stamina')*.20+val('consistency')*.10),
   aggression_bias:clamp(val('aggression')*.42+val('forehand_power')*.20+val('killer_instinct')*.18+val('serve_plus_one')*.20),
   risk_tolerance:clamp(val('aggression')*.28+val('confidence')*.20+val('killer_instinct')*.20+Math.max(1,21-val('patience'))*.12+val('shot_selection')*.20),
   serve_plus_one_bias:clamp(val('serve_plus_one')*.60+val('first_serve_quality')*.20+val('forehand_power')*.20),
   return_position:val('return_aggression')>=16&&val('reaction')>=15?'Agressive':val('return_consistency')>=16&&val('patience')>=14?'Reculée':'Neutre',
   forehand_bias:clamp(val('forehand_power')*.35+val('forehand_accuracy')*.25+val('aggression')*.20+val('shot_selection')*.20),
   drop_shot_frequency:clamp(val('drop_shot')*.55+val('touch')*.25+val('decision_making')*.20),
   slice_frequency:clamp(val('slice')*.55+val('touch')*.20+val('patience')*.15+val('decision_making')*.10),
   pace_preference:clamp(val('forehand_power')*.22+val('backhand_power')*.22+val('serve_power')*.18+val('aggression')*.18+val('acceleration')*.20),
   defense_to_attack_bias:clamp(val('defense_to_attack')*.60+val('acceleration')*.20+val('decision_making')*.20),
   tactical_identity:report?.archetype_read||report?.style_read||'Profil estimé'
 };
}
function estimatedTacticalTraitsFromScouting(attrs={},profile={}){
 const val=(k,f=10)=>Number.isFinite(Number(attrs?.[k]))?Number(attrs[k]):f;
 const rows=[
  ['Construit autour du service + 1',42+(Number(profile.serve_plus_one_bias||10)-10)*4+(val('first_serve_quality')-10)*1.2],
  ['Attaque la deuxième balle adverse',40+(val('return_aggression')-10)*4+(val('reaction')-10)*1.5],
  ['Cherche régulièrement le filet',40+(Number(profile.net_frequency||10)-10)*4+(val('transition_game')-10)*1.3],
  ['Contourne pour jouer son coup droit',40+(Number(profile.forehand_bias||10)-10)*4+(val('forehand_power')-10)*1.2],
  ['Accepte les longs échanges',40+(Number(profile.rally_length_preference||10)-10)*4+(val('rally_tolerance')-10)*1.2],
  ['Utilise souvent l’amortie',38+(Number(profile.drop_shot_frequency||10)-10)*4.5+(val('touch')-10)],
  ['Casse le rythme avec le slice',38+(Number(profile.slice_frequency||10)-10)*4.5+(val('touch')-10)],
  ['Transforme la défense en attaque',40+(Number(profile.defense_to_attack_bias||10)-10)*4+(val('defensive_skill')-10)*1.4],
  ['Recherche une cadence élevée',40+(Number(profile.pace_preference||10)-10)*4+(val('acceleration')-10)*1.2],
  ['Hausse l’agressivité sur les grands points',40+(val('big_points')-10)*3.5+(Number(profile.aggression_bias||10)-10)*1.5],
  ['Coupe beaucoup au filet en double',40+(val('poaching')-10)*4+(val('doubles_communication')-10)*1.2],
  ['Varie fortement les zones et effets au service',40+(val('serve_variety')-10)*4.5]
 ].map(([trait_name,intensity])=>({trait_name,intensity:Math.max(0,Math.min(96,Math.round(Number(intensity))))}))
  .filter(x=>x.intensity>=72)
  .sort((x,y)=>y.intensity-x.intensity)
  .slice(0,5);
 return rows;
}
function playerTraitBadges(attrs={},dev={},focus='mixed',report=null){
 const n=k=>Number(attrs?.[k]);
 const ok=k=>Number.isFinite(n(k));
 const out=[];
 const add=(label,kind='')=>{if(!out.some(x=>x.label===label))out.push({label,kind})};
 if(ok('serve_power')&&ok('first_serve_quality')&&n('serve_power')>=17&&n('first_serve_quality')>=16)add('Gros serveur','good');
 if(ok('second_serve_quality')&&n('second_serve_quality')>=16)add('2e balle fiable','good');
 if(ok('return_aggression')&&n('return_aggression')>=16)add('Agressif en retour','good');
 if(ok('return_consistency')&&n('return_consistency')>=17)add('Mur en retour','good');
 if(ok('forehand_power')&&n('forehand_power')>=17)add('Coup droit destructeur','good');
 if(ok('backhand_accuracy')&&n('backhand_accuracy')>=17)add('Revers très sûr','good');
 if(ok('drop_shot')&&ok('touch')&&n('drop_shot')>=16&&n('touch')>=15)add('Amortie naturelle','good');
 if(ok('volley')&&ok('net_positioning')&&n('volley')>=16&&n('net_positioning')>=15)add('Instinct au filet','good');
 if(ok('poaching')&&n('poaching')>=16)add('Poaching agressif','good');
 if(ok('big_points')&&n('big_points')>=17)add('Clutch','good');
 if(ok('consistency')&&n('consistency')>=17)add('Très régulier','good');
 if(ok('decision_making')&&ok('shot_selection')&&n('decision_making')>=16&&n('shot_selection')>=16)add('Lecture tactique','good');
 if(ok('speed')&&ok('agility')&&n('speed')>=17&&n('agility')>=16)add('Déplacements explosifs','good');
 if(ok('stamina')&&ok('natural_fitness')&&n('stamina')>=17&&n('natural_fitness')>=15)add('Endurance élite','good');
 if(ok('aggression')&&n('aggression')>=17)add('Prend l’initiative');
 if(ok('patience')&&n('patience')>=17)add('Construit les points');
 if(ok('consistency')&&n('consistency')<=8)add('Irrégulier','bad');
 if(ok('second_serve_quality')&&n('second_serve_quality')<=8)add('2e balle attaquable','bad');
 if(ok('big_points')&&n('big_points')<=8)add('Fragile sous pression','bad');
 if(focus==='doubles_only')add('Spécialiste double','good');
 if(String(dev?.development_type||'')==='late')add('Éclosion tardive');
 if(String(dev?.development_type||'')==='early')add('Précoce');
 if(report?.injury_risk_read==='Élevé')add('Risque physique élevé','bad');
 return out.slice(0,10);
}
function careerFocusLabel(v){
 return v==='singles_only'?'Simple exclusivement':v==='doubles_only'?'Double exclusivement':v==='singles_priority'?'Simple prioritaire':'Simple + double';
}
function careerFocusDescription(v){
 return v==='singles_only'
  ?'Aucun tableau de double. Toute la saison, le staff et les objectifs sont construits autour du simple.'
  :v==='doubles_only'
    ?'Aucune inscription en simple. Le classement simple décroît naturellement et ton calendrier se construit autour du double.'
    :v==='singles_priority'
      ?'Le simple reste l’objectif principal, mais tu peux jouer du double ponctuellement.'
      :'Simple et double sont menés en parallèle avec deux classements actifs.';
}
function careerDoublesRankText(c=career()){
 const strict=String(c?.career_focus||'mixed')==='singles_only';
 const pts=Number(c?.doubles_points||0);
 return strict&&pts<=0?'NR':(c?.doubles_rank?'#'+fmt(c.doubles_rank):'NR');
}
function myPlayerPage(){
 const c=activePlayerCareerView(),focus=String(c.career_focus||'mixed');
 const modes=[
  ['singles_only','Simple exclusivement','Aucun double : calendrier, objectifs et sélection centrés à 100 % sur le simple.'],
  ['singles_priority','Simple prioritaire','ATP simple au centre du projet, double occasionnel.'],
  ['mixed','Simple + double','Deux carrières menées en parallèle.'],
  ['doubles_only','Double exclusivement','Plus aucun tableau simple, carrière construite autour des paires et de la Race double, avec une longévité potentiellement supérieure.']
 ];
 return `<div class="section-head"><div><div class="eyebrow">Carrière</div><h1>Mon joueur</h1><div class="muted">Personnalise ton joueur géré et définis sa trajectoire sportive.</div></div></div>
 <div class="card" style="margin-bottom:12px">
  <div class="row between"><div><div class="eyebrow">Orientation de carrière</div><h2>${careerFocusLabel(focus)}</h2><div class="muted mini">${careerFocusDescription(focus)}</div></div><span class="badge ${focus==='doubles_only'?'good':focus==='singles_priority'?'warn':''}">${careerFocusLabel(focus)}</span></div>
  <div class="grid g2 career-focus-grid" style="margin-top:10px">
   ${modes.map(m=>`<button class="card click career-focus-card ${focus===m[0]?'career-focus-active':''}" onclick="setCareerFocus('${m[0]}')"><div class="eyebrow">${focus===m[0]?'Actif':'Choisir'}</div><h3>${m[1]}</h3><div class="muted mini">${m[2]}</div></button>`).join('')}
  </div>
  <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px">
   <span class="badge">Dernier changement : ${df(c.career_focus_changed_at||'2025-12-01')}</span>
   <span class="badge">${fmt(c.career_focus_switches||0)} changement(s)</span>
   ${focus==='doubles_only'?'<span class="badge good">Inscriptions simple verrouillées</span>':focus==='singles_only'?'<span class="badge good">Inscriptions double verrouillées</span>':''}
  </div>
 </div>
 <div class="grid g2"><div class="card"><h2>Identité</h2><label class="mini muted">Nom</label><input class="input" value="${esc(c.player_name)}" onchange="editCareer('player_name',this.value)"><label class="mini muted">Pays</label><input class="input" value="${esc(c.country)}" onchange="editCareer('country',this.value)"><label class="mini muted">Style</label><select class="select" onchange="editCareer('style',this.value)">${['Attaquant polyvalent','Attaquant fond de court','Contreur','All-court','Serveur-volée'].map(x=>`<option ${x===c.style?'selected':''}>${x}</option>`).join('')}</select></div>
 <div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">ATP</span><b>#${fmt(c.singles_rank)}</b></div><div class="statbox"><span class="muted mini">Double</span><b>${careerDoublesRankText(c)}</b></div><div class="statbox"><span class="muted mini">Niveau</span><b>${starRatingHtml(abilityStarValue(c.current_ability||56),'Niveau actuel')}</b><small class="muted micro">CA ${c.current_ability||56}</small></div><div class="statbox"><span class="muted mini">Potentiel</span><b>${starRatingHtml(abilityStarValue(c.potential||82),'Potentiel')}</b><small class="muted micro">PA ${c.potential||82}</small></div></div><div class="list-item row between"><span>Âge</span><input class="input" style="max-width:100px" type="number" value="${c.age||19}" onchange="editCareer('age',Number(this.value))"></div><div class="list-item row between"><span>Taille</span><input class="input" style="max-width:100px" type="number" value="${c.height_cm||184}" onchange="editCareer('height_cm',Number(this.value))"></div><div class="list-item row between"><span>Poids</span><input class="input" style="max-width:100px" type="number" value="${c.weight_kg||78}" onchange="editCareer('weight_kg',Number(this.value))"></div></div></div>`
}
function fantasyPage(){
 const rows=local.fantasy||[];
 return `<div class="section-head"><div><div class="eyebrow">Mode créatif</div><h1>Fantasy Court</h1><div class="muted">Crée ton propre tournoi, surface et format.</div></div><button class="primary" onclick="createFantasy()">Nouveau tournoi</button></div><div class="stack">${rows.map((t,i)=>`<div class="card click" onclick="openFantasy(${i})"><div class="row between"><div><div class="eyebrow">${esc(t.category)}</div><h2>${esc(t.name)}</h2><div class="muted">${esc(surfaceLabel(t))} · ${t.draw} joueurs</div></div><button class="danger-btn" onclick="event.stopPropagation();deleteFantasy(${i})">Supprimer</button></div></div>`).join('')||'<div class="card empty">Aucun tournoi personnalisé. Crée le premier.</div>'}</div>`
}
function saveCenterPage(){
 const byNo=new Map((saveSlots||[]).map(x=>[Number(x.slot_no),x]));
 const cards=[0,1,2,3,4,5,9].map(n=>{
  const x=byNo.get(n),auto=n===0,quick=n===9;
  const slotLabel=auto?'Autosave':quick?'Quicksave':'Slot '+n;
  const scopeLabel=x?.snapshot_scope==='managed_squad_college_exact_v7'?'v7 · groupe + NCAA + médical':x?.snapshot_scope==='managed_squad_ledgers_exact_v6'?'v6 · groupe + ATP simple/double':x?.snapshot_scope==='managed_squad_ledger_exact_v5'?'v5 · groupe + ledger ATP':x?.snapshot_scope==='managed_squad_exact_v4'?'v4 · groupe exact':x?.snapshot_scope==='managed_academy_exact_v3'?'v3 · multi-joueurs':x?.snapshot_scope==='managed_world_exact_v2'?'v2 · joueur principal':x?'legacy':'';
  return `<div class="card save-slot ${x?'has-save':''} ${auto?'is-autosave':''} ${quick?'is-quicksave':''}">
    <div class="row between"><div><div class="eyebrow">${slotLabel}</div><h2>${esc(x?.slot_name||(auto?'Autosave hebdomadaire':quick?'Sauvegarde rapide':'Slot vide'))}</h2></div><div class="row" style="gap:6px"><span class="badge ${x?'good':''}">${x?'Disponible':'Vide'}</span>${x&&scopeLabel?`<span class="badge">${esc(scopeLabel)}</span>`:''}</div></div>
    ${x?`<div class="list-item row between"><span>Date carrière</span><b>${df(x.career_date)}</b></div><div class="list-item row between"><span>Semaine</span><b>${fmt(x.week||1)}</b></div><div class="list-item row between"><span>Joueur</span><b>${esc(x.player_name||'—')}</b></div><div class="muted micro" style="margin-top:7px">Dernière écriture : ${new Date(x.updated_at).toLocaleString('fr-FR')}</div>`:auto?'<div class="muted">L’autosave sera créé après la prochaine semaine simulée.</div>':'<div class="empty">Aucune sauvegarde dans ce slot.</div>'}
    <div class="row" style="margin-top:12px;flex-wrap:wrap">
      ${x?`<button class="primary" onclick="loadCareerSlot(${n})">Charger</button>`:''}
      <button class="soft-btn" ${saveSlotBusy?'disabled':''} onclick="saveCareerSlot(${n},'${auto?'autosave':quick?'quick':'manual'}')">${x?'Écraser':'Sauvegarder ici'}</button>
      ${x&&!auto?`<button class="danger-btn" onclick="deleteCareerSlot(${n})">Supprimer</button>`:''}
    </div>
   </div>`;
 }).join('');
 return `<div class="section-head"><div><div class="eyebrow">Career OS</div><h1>Sauvegardes</h1><div class="muted">Autosave hebdomadaire + 5 slots manuels + quicksave. Le snapshot V6 conserve le groupe géré complet : joueurs, entraînements, médical, relations, staff, sponsors, inscriptions, résultats et ledgers ATP simple + double par joueur.</div></div><button class="primary" onclick="saveCareerSlot(9,'quick')">Sauvegarde rapide</button></div>
 <div class="notice mini"><b>Snapshot groupe V6 exact :</b> les 1 à 8 joueurs sont figés ensemble avec attributs, progression, fatigue, blessures, plans, relations, sponsors, staff perso, inscriptions, runs simple/double et leurs deux ledgers de classement 52 semaines. Charger un slot remet toute la timeline managée au même instant.</div>
 ${local.lastSaveState?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Dernière opération de sauvegarde</div><b>${local.lastSaveState.slot_type==='autosave'?'Autosave':local.lastSaveState.slot_type==='quick'?'Quicksave':'Sauvegarde manuelle'} · semaine ${fmt(local.lastSaveState.week||1)}</b></div><span class="badge ${local.lastSaveState.status==='ok'?'good':'bad'}">${local.lastSaveState.status==='ok'?'Sécurisée':'Échec'}</span></div><div class="muted mini" style="margin-top:6px">${df(local.lastSaveState.career_date)} · ${new Date(local.lastSaveState.updated_at).toLocaleString('fr-FR')}${local.lastSaveState.error?' · '+esc(local.lastSaveState.error):''}</div></div>`:''}
 <div class="row" style="margin-top:10px"><button class="ghost" onclick="nav('launcher')">Menu carrière</button></div>
 <div class="grid g2" style="margin-top:12px">${cards}</div>`;
}
function launcherPage(){
 const ordered=[...(saveSlots||[])].sort((x,y)=>new Date(y.updated_at||0)-new Date(x.updated_at||0));
 const latest=ordered[0]||null,auto=(saveSlots||[]).find(x=>Number(x.slot_no)===0)||null;
 const c=career();
 return `<div class="section-head"><div><div class="eyebrow">Court Boss · Career OS</div><h1>Menu carrière</h1><div class="muted">Continuer ta partie, revenir sur une sauvegarde ou repartir du 01/12/2025.</div></div><button class="ghost" onclick="nav('home')">Retour au jeu</button></div>
 <div class="grid g2">
  <div class="card"><div class="eyebrow">Carrière active</div><h2>${esc(c.player_name||'Joueur')} · semaine ${fmt(local.week||1)}</h2><div class="muted">${df(local.date||c.career_date)} · ATP #${fmt(c.singles_rank||0)} · Double #${fmt(c.doubles_rank||0)}</div><button class="primary" style="width:100%;margin-top:14px" onclick="nav('home')">Continuer</button></div>
  <div class="card"><div class="eyebrow">Dernière sauvegarde</div><h2>${latest?esc(latest.slot_name):'Aucune sauvegarde'}</h2>${latest?`<div class="muted">${df(latest.career_date)} · semaine ${fmt(latest.week||1)}</div><button class="soft-btn" style="width:100%;margin-top:14px" onclick="loadCareerSlot(${Number(latest.slot_no)})">Charger</button>`:'<div class="muted">Le premier autosave sera créé après une semaine simulée.</div>'}</div>
 </div>
 <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Nouvelle partie</div><h2>Repartir sur le monde de référence</h2><div class="muted">Réinitialise la carrière gérée au 01/12/2025, puis ouvre la base mondiale pour choisir le joueur à manager. Tes slots manuels restent disponibles.</div></div><span class="badge warn">Reset carrière</span></div><div class="row" style="gap:8px;flex-wrap:wrap;margin-top:12px"><button class="danger-btn" onclick="startNewCareer()">Choisir un joueur réel</button><button class="soft-btn" onclick="openCustomCareerCreator()">Créer mon joueur</button></div></div>
 <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Sauvegardes</div><h2>Slots & reprise</h2></div><button class="soft-btn" onclick="nav('saves')">Ouvrir le Save Center</button></div><div class="muted mini">${auto?'Autosave : '+df(auto.career_date)+' · semaine '+fmt(auto.week||1):'Aucun autosave pour le moment.'}</div></div>`;
}
window.startNewCareer=async()=>{
 if(simulating||saveSlotBusy){alert('Une simulation ou une opération de sauvegarde est en cours. Termine-la avant de démarrer une nouvelle carrière.');return;}
 if(local.liveSessionId){alert('Termine le match en cours avant de démarrer une nouvelle carrière.');return;}
 if(!confirm('Démarrer une nouvelle carrière au 01/12/2025 ? Les changements non sauvegardés de la carrière active seront perdus.'))return;
 saveSlotBusy=true;
 try{
  const d=await get('/api/new-career',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
  local=cleanCareerLocalState(d.local_payload||{});
  localStorage.setItem('cbLocal',JSON.stringify(local));
  invalidateCareerCaches();
  boot=await get('/api/bootstrap');
  local.career={...(local.career||{}),...(boot.career||{})};
  local.date=boot.career?.career_date||local.date;
  local.week=boot.career?.week??local.week;
  await Promise.allSettled([loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadSaveSlots(),loadCareerHub(true)]);
  saveSlotBusy=false;
  await saveCareerSlot(0,'autosave',true);
  route='players';
  if(!countryRows.length)await loadCountries();
  await loadPlayerDatabase();
  render();
  alert('Nouvelle carrière prête. Choisis maintenant le joueur que tu veux gérer dans la base mondiale.');
 }catch(e){alert('Nouvelle carrière impossible : '+e.message)}
 finally{saveSlotBusy=false}
}

window.startCareerWithPlayer=async(id,name='ce joueur')=>{
 if(simulating||saveSlotBusy){alert('Une simulation ou une opération de sauvegarde est en cours.');return;}
 const targetId=Number(id||0);if(!targetId)return;
 if(!confirm('Gérer '+name+' ? La carrière active sera réinitialisée autour de ce joueur au 01/12/2025. Tes sauvegardes manuelles restent disponibles.'))return;
 saveSlotBusy=true;
 try{
  await managerAction('take_over_player',targetId,{date:'2025-12-01'});
  local.date='2025-12-01';local.week=1;local.entries=[];local.entryMeta={};local.doublesEntries=[];local.doublesEntryMeta={};local.partnerId=null;local.shortlist=[];
  local.playedTournaments={};local.liveSessionId=null;
  localStorage.setItem('cbLocal',JSON.stringify(local));
  rankRows=[];tourRows=[];management=null;rankingLedger=null;seasonSummary=null;scheduleAdvice=null;trainingPreview=null;careerHub=null;historyData=null;competitionRows=[];
  boot=await get('/api/bootstrap');
  local.career={...(local.career||{}),...(boot.career||{})};
  local.date=boot.career?.career_date||local.date;local.week=boot.career?.week??1;
  await Promise.all([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadCareerHub(true)]);
  saveSlots=[];await saveCareerSlot(0,'autosave',true);await loadSaveSlots();
  persist();closeOverlay();route='home';render();
 }catch(e){alert('Prise en main impossible : '+e.message)}
 finally{saveSlotBusy=false}
}

window.openCustomCareerCreator=()=>{
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Nouvelle partie</div><h1>Créer ton joueur</h1><div class="muted">Profil fictif Court Boss, intégré au même monde que les joueurs réels.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  <div class="grid g2" style="margin-top:12px">
   <label class="field"><span>Nom</span><input id="customCareerName" class="input" placeholder="Prénom Nom"></label>
   <label class="field"><span>Pays</span><input id="customCareerCountry" class="input" value="FRA" maxlength="3"></label>
   <label class="field"><span>Âge</span><input id="customCareerAge" class="input" type="number" min="15" max="35" value="18"></label>
   <label class="field"><span>Niveau de départ</span><select id="customCareerTier" class="select"><option>Débutant</option><option selected>ITF</option><option>Challenger</option><option>Espoir</option></select></label>
   <label class="field"><span>Main</span><select id="customCareerHand" class="select"><option>Droitier</option><option>Gaucher</option></select></label>
   <label class="field"><span>Revers</span><select id="customCareerBackhand" class="select"><option>2 mains</option><option>1 main</option></select></label>
   <label class="field"><span>Style</span><select id="customCareerStyle" class="select"><option>All-court</option><option>Serveur</option><option>Contreur</option><option>Attaquant</option><option>Terre battue</option></select></label>
   <label class="field"><span>Potentiel</span><input id="customCareerPotential" class="input" type="number" min="55" max="99" value="82"></label>
  </div>
  <button class="primary" style="width:100%;margin-top:14px" onclick="createCustomCareerPlayer()">Créer et démarrer la carrière</button>
 </div></div>`;
}
window.createCustomCareerPlayer=async()=>{
 const name=String(document.getElementById('customCareerName')?.value||'').trim();
 if(name.length<2){alert('Entre un nom de joueur.');return}
 if(local.liveSessionId){alert('Termine le match en cours avant de démarrer une nouvelle carrière.');return}
 try{
  const reset=await get('/api/new-career',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
  local=cleanCareerLocalState(reset.local_payload||{});
  localStorage.setItem('cbLocal',JSON.stringify(local));
  const d=await managerAction('create_custom_player',0,{
   name,country:String(document.getElementById('customCareerCountry')?.value||'FRA').toUpperCase(),
   age:Number(document.getElementById('customCareerAge')?.value||18),
   tier:document.getElementById('customCareerTier')?.value||'ITF',
   handedness:document.getElementById('customCareerHand')?.value||'Droitier',
   backhand:document.getElementById('customCareerBackhand')?.value||'2 mains',
   style:document.getElementById('customCareerStyle')?.value||'All-court',
   potential:Number(document.getElementById('customCareerPotential')?.value||82)
  });
  closeOverlay();
  await startCareerWithPlayer(Number(d.player?.id||0),String(d.player?.name||name));
 }catch(e){alert('Création impossible : '+e.message)}
}

function inboxActionButton(x,type,label,payload,cls='primary'){
 if(!type||!label)return '';
 const p=JSON.stringify(payload||{}).replace(/'/g,'&#39;');
 return `<button class="${cls}" onclick='event.stopPropagation();runInboxDecision(${Number(x.id)},${JSON.stringify(String(type))},${p})'>${esc(label)}</button>`;
}
function inboxEventVisual(x){
 const hay=[x?.title,x?.body,x?.related_entity_type,x?.action_type].filter(Boolean).join(' ');
 const isLaver=String(x?.related_entity_type||'')==='laver_cup_invitation'
  ||String(x?.action_type||'')==='respond_laver_cup_invitation'
  ||/Laver Cup/i.test(hay);
 if(!isLaver)return '';
 const payload=x?.action_payload||x?.secondary_action_payload||{};
 const tournamentId=Number(payload?.tournament_id||0);
 const found=tournamentId?findTournamentById(tournamentId):null;
 const t=found||{
  id:tournamentId||null,
  name:'Laver Cup',
  category:'Laver Cup',
  circuit:'ATP',
  logo_url:'https://commons.wikimedia.org/wiki/Special:Redirect/file/Laver_Cup_logo.png'
 };
 const team=/Team World/i.test(hay)?'Team World':/Team Europe/i.test(hay)?'Team Europe':'Team Europe vs Team World';
 const teamClass=team==='Team World'?'is-world':team==='Team Europe'?'is-europe':'is-neutral';
 const dateText=t?.start_date?(df(t.start_date)+(t.end_date?' → '+df(t.end_date):'')):'';
 const location=[t?.venue,t?.city].filter(Boolean).join(' · ');
 return `<div class="inbox-event-brand inbox-event-laver ${teamClass}">
  ${tournamentLogoHtml(t,'tm-inbox-event-logo')}
  <div class="inbox-event-copy"><span>Invitation officielle</span><b>Laver Cup</b><small>${esc(team)}${dateText?' · '+esc(dateText):''}${location?' · '+esc(location):''}</small></div>
 </div>`;
}

function inboxPage(){
 const rows=[...(boot.inbox||[])].sort((a,b)=>Number(a.is_read)-Number(b.is_read)||({urgent:0,high:1,normal:2}[a.priority]??2)-({urgent:0,high:1,normal:2}[b.priority]??2)||String(b.created_at||'').localeCompare(String(a.created_at||'')));
 const unread=rows.filter(x=>!x.is_read).length,decisions=rows.filter(x=>x.decision_status==='pending'&&x.action_type&&!['open_route'].includes(x.action_type)).length;
 return `<div class="section-head"><div><div class="eyebrow">Communication</div><h1>Boîte de réception</h1><div class="muted">${unread} non lu(s) · ${decisions} décision(s) en attente</div></div><button class="soft-btn" onclick="markAllInboxRead()">Tout marquer lu</button></div>
 <div class="inbox-layout"><div class="stack">${rows.map(x=>`<div class="card inbox-card ${x.is_read?'':'is-unread'} ${x.priority==='high'||x.priority==='urgent'?'is-priority':''}" onclick="openInboxItem(${x.id},'${esc(x.action_route||'home')}')">
   <div class="row between"><div class="eyebrow">${esc(x.kind||'info')} · ${x.game_date?df(x.game_date):new Date(x.created_at).toLocaleDateString('fr-FR')}</div><div class="row"><span class="badge ${x.priority==='high'||x.priority==='urgent'?'warn':''}">${esc(x.priority||'normal')}</span><span class="badge ${x.is_read?'':'good'}">${x.is_read?'Lu':'Nouveau'}</span></div></div>
   ${inboxEventVisual(x)}
   <h2>${esc(x.title)}</h2><p class="muted">${esc(x.body)}</p>
   ${x.decision_status==='resolved'?'<span class="badge good">Décision prise</span>':x.decision_status==='expired'?'<span class="badge warn">Expiré</span>':''}
   ${x.action_type&&!['resolved','expired'].includes(String(x.decision_status||''))?`<div class="row" style="margin-top:10px;flex-wrap:wrap">${inboxActionButton(x,x.action_type,x.action_label||'Ouvrir',x.action_payload,'primary')}${inboxActionButton(x,x.secondary_action_type,x.secondary_action_label,x.secondary_action_payload,'soft-btn')}</div>`:''}
  </div>`).join('')||'<div class="card empty">Aucun message.</div>'}</div></div>`;
}
window.runInboxDecision=async(id,type,payload={})=>{
 try{
  const targetPlayerId=Number(payload?.player_id||0);
  if(targetPlayerId&&targetPlayerId!==activeManagedId()&&managedSquadIds().includes(targetPlayerId)){
    await window.setActiveManagedPlayer(targetPlayerId);
  }
  if(type==='open_route'){
    try{await managerAction('mark_inbox_read',id)}catch{}
    if(payload?.player_id){
      const target=Number(payload.player_id||0);
      if(target&&managedSquadIds().includes(target)){
        local.activeManagedPlayerId=target;
        activeManagedContext=null;
        if(String(payload.route||'')==='training'){
          local.trainingPlayerId=target;
          trainingPreview=null;
        }
        persist();
        await loadActiveManagedContext(true,target).catch(()=>{});
        await loadManagement().catch(()=>{});
      }
    }
    boot=await get('/api/bootstrap');
    await nav(payload.route||'home');
    return;
  }
  if(type==='academy_pathway'){
    const youthId=Number(payload.youth_id||0);
    const d=await managerAction('academy_pathway',youthId,{decision:payload.decision});
    boot=await get('/api/bootstrap');await loadManagement();
    alert(payload.decision==='ncaa'?'Départ NCAA confirmé : '+d.destination:'Passage professionnel confirmé.');
    render();return;
  }
  if(type==='accept_sponsor'){
    await managerAction('accept_sponsor',Number(payload.offer_id||0));
    careerHub=null;boot=await get('/api/bootstrap');await Promise.all([loadManagement(),loadCareerHub(true)]);render();return;
  }
  if(type==='decline_sponsor'){
    await managerAction('decline_sponsor',Number(payload.offer_id||0));
    careerHub=null;boot=await get('/api/bootstrap');await Promise.all([loadManagement(),loadCareerHub(true)]);render();return;
  }
  if(type==='renew_contract'){
    const d=await managerAction('renew_contract',Number(payload.contract_id||0));
    careerHub=null;boot=await get('/api/bootstrap');await Promise.allSettled([loadManagement(),loadCareerHub(true)]);
    alert('Contrat renouvelé jusqu’au '+df(d.end_date)+' · '+euro(d.weekly_salary)+'/sem.');
    render();return;
  }
  if(type==='medical_protocol'){
    await managerAction('set_medical_protocol',Number(payload.injury_id||0),{protocol:payload.protocol,player_id:Number(payload.player_id||activeManagedId()||primaryManagedPlayerId()||0)});
    careerHub=null;boot=await get('/api/bootstrap');await loadCareerHub(true);render();return;
  }
  if(type==='respond_partner_offer'){
    await managerAction('respond_partner_offer',Number(payload.offer_id||0),{decision:payload.decision||'decline',player_id:Number(payload.player_id||activeManagedId()||primaryManagedPlayerId()||0)});
    careerHub=null;boot=await get('/api/bootstrap');await Promise.all([loadManagement(),loadCareerHub(true)]);render();return;
  }
  if(type==='respond_laver_cup_invitation'){
    const invitationId=Number(payload?.invitation_id||0);
    if(!invitationId)throw new Error('Invitation Laver Cup introuvable.');
    await managerAction('respond_laver_cup_invitation',invitationId,{
      invitation_id:invitationId,
      decision:String(payload?.decision||'decline'),
      player_id:Number(payload?.player_id||activeManagedId()||primaryManagedPlayerId()||0),
      tournament_id:Number(payload?.tournament_id||0)
    });
    careerHub=null;
    boot=await get('/api/bootstrap');
    await Promise.allSettled([loadManagement(),loadCareerHub(true)]);
    render();return;
  }
  if(type==='match_staff_offer'||type==='release_staff_offer'){
    await managerAction(type,Number(payload.offer_id||0));
    careerHub=null;boot=await get('/api/bootstrap');await Promise.all([loadManagement(),loadCareerHub(true)]);render();return;
  }
  await managerAction('mark_inbox_read',id);boot=await get('/api/bootstrap');render();
 }catch(e){alert(e.message)}
}
window.markAllInboxRead=async()=>{
 const unread=(boot.inbox||[]).filter(x=>!x.is_read);
 for(const x of unread){try{await managerAction('mark_inbox_read',x.id)}catch{}}
 boot=await get('/api/bootstrap');render();
}


function careerHubPage(){
 const h=careerHub||{},cr=h.career||career(),plan=h.seasonPlan||h.season_plan||null;
 const sponsors=h.sponsors||management?.sponsors||[],available=sponsors.filter(x=>['available','pending'].includes(String(x.status))),accepted=sponsors.filter(x=>x.status==='accepted');
 const rel=(h.relationships||[]).slice(0,4),media=(h.media||[]).slice(0,4),events=(h.events||h.timeline||[]).slice(0,6),objectives=h.objectives||h.board||boot.board||[];
 const decisions=[...(boot.inbox||[])].filter(x=>x.decision_status==='pending'&&x.action_type&&x.action_type!=='open_route').sort((a,b)=>({urgent:0,high:1,normal:2}[a.priority]??2)-({urgent:0,high:1,normal:2}[b.priority]??2)).slice(0,5);
 return '<div class="section-head"><div><div class="eyebrow">Career OS</div><h1>Bureau manager</h1><div class="muted">Le centre de décision entre deux tournois : saison, sponsors, entourage sportif, médias et journal de carrière.</div></div><div class="row" style="gap:8px"><button class="soft-btn" onclick="loadCareerHub(true).then(render)">↻ Actualiser</button><button class="primary" onclick="saveCareerSlot(9,\'quick\')">Quicksave</button></div></div>'+
 '<div class="quick-grid"><div class="quick" onclick="nav(\'season\')"><span class="muted mini">Saison</span><strong>Planifier le calendrier</strong></div><div class="quick" onclick="nav(\'finance\')"><span class="muted mini">Sponsors</span><strong>'+available.length+' offre(s) à décider</strong></div><div class="quick" onclick="nav(\'relationships\')"><span class="muted mini">Relations</span><strong>'+rel.length+' relation(s) en tête</strong></div><div class="quick" onclick="nav(\'media\')"><span class="muted mini">Médias</span><strong>'+fmt((h.media||[]).length)+' sujet(s)</strong></div></div>'+
 (decisions.length?'<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">À traiter</div><h2>'+decisions.length+' décision(s) manager</h2></div><button class="ghost" onclick="nav(\'inbox\')">Tout voir</button></div>'+decisions.map(x=>'<div class="list-item"><div class="row between"><div><b>'+esc(x.title)+'</b><div class="muted mini">'+esc(String(x.body||'').slice(0,160))+'</div></div><span class="badge '+(x.priority==='urgent'||x.priority==='high'?'warn':'')+'">'+esc(x.priority||'normal')+'</span></div><div class="row" style="margin-top:8px;flex-wrap:wrap">'+inboxActionButton(x,x.action_type,x.action_label||'Ouvrir',x.action_payload,'primary')+inboxActionButton(x,x.secondary_action_type,x.secondary_action_label,x.secondary_action_payload,'soft-btn')+'</div></div>').join('')+'</div>':'')+
 '<div class="grid g2" style="margin-top:12px">'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Plan annuel</div><h2>'+(plan?esc(String(plan.plan_type||'Plan manager').replaceAll('_',' ')):'À définir')+'</h2></div><button class="soft-btn" onclick="nav(\'season\')">Modifier</button></div>'+
   (plan?'<div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Tournois</span><b>'+fmt(plan.target_events)+'</b></div><div class="kpi"><span class="muted mini">Surface</span><b>'+esc(plan.preferred_surface||'—')+'</b></div><div class="kpi"><span class="muted mini">Repos</span><b>'+fmt(plan.rest_bias||0)+'/20</b></div></div><div class="muted mini" style="margin-top:8px">'+esc(plan.reason||'')+'</div>':'<div class="empty">Aucun plan créé pour cette saison.</div>')+
  '</div>'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Commercial</div><h2>Sponsors</h2></div><button class="soft-btn" onclick="nav(\'finance\')">Négocier</button></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Actifs</span><b>'+accepted.length+'</b></div><div class="kpi"><span class="muted mini">Disponibles</span><b>'+available.length+'</b></div></div>'+
   (available[0]?'<div class="notice" style="margin-top:10px"><b>'+esc(available[0].brand)+'</b> · '+euro(available[0].weekly_value)+'/sem. · bonus '+euro(available[0].signing_bonus)+'</div>':'<div class="muted mini" style="margin-top:9px">Aucune offre en attente.</div>')+
  '</div>'+
 '</div>'+
 '<div class="grid g2" style="margin-top:12px"><div class="card"><div class="row between"><h2>Relations sportives</h2><button class="ghost" onclick="nav(\'relationships\')">Tout voir</button></div>'+
  (rel.map(r=>{const o=Array.isArray(r.other)?r.other[0]:r.other||{};return '<div class="list-item click" onclick="openPlayer('+Number(o.id||0)+')"><div class="row between"><span><b>'+(flags[o.country]||'🏳️')+' '+esc(o.name||'Joueur')+'</b><br><span class="muted micro">'+esc(r.relation_type||'Affinité')+'</span></span><b>'+fmt(r.affinity||0)+'/100</b></div></div>'}).join('')||'<div class="empty">Aucune relation active.</div>')+
 '</div><div class="card"><div class="row between"><h2>Médias récents</h2><button class="ghost" onclick="nav(\'media\')">Tout voir</button></div>'+
  (media.map(x=>'<div class="list-item"><div class="row between"><b>'+esc(x.headline||'Actualité')+'</b><span class="muted micro">'+df(x.event_date)+'</span></div><div class="muted mini">'+esc(String(x.body||'').slice(0,140))+'</div></div>').join('')||'<div class="empty">Aucune storyline récente.</div>')+
 '</div></div>'+
 '<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Direction & journal</div><h2>Ce qui compte maintenant</h2></div><button class="ghost" onclick="nav(\'diagnostics\')">Journal complet</button></div><div class="grid g2" style="margin-top:8px"><div>'+
  (objectives.slice(0,4).map(o=>'<div class="list-item"><div class="row between"><b>'+esc(o.objective)+'</b><span>'+fmt(o.progress||0)+'%</span></div><div class="bar"><i style="width:'+Number(o.progress||0)+'%"></i></div></div>').join('')||'<div class="empty">Aucun objectif.</div>')+
 '</div><div>'+(events.map(e=>'<div class="list-item"><div class="row between"><b>'+esc(e.summary||e.event_type||'Événement')+'</b><span class="muted micro">'+df(e.event_date)+'</span></div><div class="muted micro">'+esc(e.system||'career')+'</div></div>').join('')||'<div class="empty">Le journal se remplira au fil des semaines.</div>')+'</div></div></div>';
}
function seasonPage(){
 const h=careerHub||{},cr=activePlayerCareerView(),p=(activeManagedContext&&Number(activeManagedContext.player_id)===activeManagedId()?activeManagedContext.season_plan:null)||h.seasonPlan||{},up=(scheduleAdvice?.recommended||boot.upcoming||[]).slice(0,10);
 const plans=[['balanced','Équilibré'],['elite_selective','Élite sélective'],['tour_regular','Circuit principal'],['challenger_push','Objectif Challenger'],['itf_build','Construction ITF'],['singles_specialist','Spécialiste simple'],['doubles_specialist','Spécialiste double'],['junior_transition','Transition junior'],['ncaa_pathway','Voie NCAA']];
 const surfaces=['Mixte','Dur','Terre','Gazon','Indoor'];
 const option=(v,l,cur)=>'<option value="'+esc(v)+'" '+(String(cur)===String(v)?'selected':'')+'>'+esc(l)+'</option>';
 const slider=(id,label,val,min=1,max=20)=>'<div class="list-item"><div class="row between"><span>'+esc(label)+'</span><b id="'+id+'_v">'+fmt(val)+'</b></div><input id="'+id+'" type="range" min="'+min+'" max="'+max+'" value="'+Number(val)+'" oninput="document.getElementById(\''+id+'_v\').textContent=this.value"></div>';
 return '<div class="section-head"><div><div class="eyebrow">Planning annuel</div><h1>Plan de saison '+String(local.date||'').slice(0,4)+'</h1><div class="muted">Le plan pilote les choix de tournois, le repos, les déplacements, la priorité simple/double et la prise de risque du calendrier.</div></div><button class="primary" onclick="saveManagedSeasonPlan()">Enregistrer le plan</button></div>'+
 '<div class="grid g4"><div class="card"><div class="eyebrow">Simple</div><div class="big">#'+fmt(cr.singles_rank||0)+'</div></div><div class="card"><div class="eyebrow">Double</div><div class="big">#'+fmt(cr.doubles_rank||0)+'</div></div><div class="card"><div class="eyebrow">Fatigue</div><div class="big '+(Number(cr.fatigue||0)>=70?'bad':Number(cr.fatigue||0)>=50?'warn':'good')+'">'+fmt(cr.fatigue||0)+'%</div></div><div class="card"><div class="eyebrow">Orientation</div><div class="big" style="font-size:17px">'+esc(careerFocusLabel(cr.career_focus||'mixed'))+'</div></div></div>'+
 '<div class="grid g2" style="margin-top:12px"><div class="card"><h2>Identité de saison</h2>'+
 '<div class="list-item"><span class="muted mini">Type de plan</span><select id="seasonPlanType" class="select">'+plans.map(x=>option(x[0],x[1],p.plan_type||'tour_regular')).join('')+'</select></div>'+
 '<div class="list-item"><span class="muted mini">Surface prioritaire</span><select id="seasonPreferredSurface" class="select">'+surfaces.map(x=>option(x,x,p.preferred_surface||'Mixte')).join('')+'</select></div>'+
 '<div class="list-item"><span class="muted mini">Surface secondaire</span><select id="seasonSecondarySurface" class="select">'+surfaces.map(x=>option(x,x,p.secondary_surface||'Terre')).join('')+'</select></div>'+
 '<div class="list-item row between"><span>Tournois cibles</span><input id="seasonTargetEvents" class="input" type="number" min="8" max="38" value="'+Number(p.target_events||22)+'" style="width:90px"></div>'+
 '<div class="list-item row between"><span>Semaines consécutives max</span><input id="seasonMaxWeeks" class="input" type="number" min="1" max="8" value="'+Number(p.max_consecutive_weeks||3)+'" style="width:90px"></div>'+
 '<div class="list-item row between"><span>Seuil repos fatigue</span><input id="seasonFatigueTrigger" class="input" type="number" min="35" max="90" value="'+Number(p.rest_trigger_fatigue||62)+'" style="width:90px"></div></div>'+
 '<div class="card"><h2>Priorités manager</h2>'+slider('seasonRestBias','Repos',p.rest_bias||10)+slider('seasonTravel','Tolérance voyages',p.travel_tolerance||10)+slider('seasonPrestige','Prestige',p.prestige_bias||10)+slider('seasonDevelopment','Développement',p.development_bias||10)+slider('seasonDoubles','Double',p.doubles_bias||10)+slider('seasonRisk','Risque calendrier',p.schedule_risk_tolerance||10)+slider('seasonMental','Charge mentale cible',p.mental_load_target||10)+'</div></div>'+
 '<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Calendrier conseillé</div><h2>Prochains objectifs</h2></div><button class="ghost" onclick="nav(\'calendar\')">Calendrier complet</button></div>'+
 (up.length?'<div class="table-wrap"><table class="table"><thead><tr><th>Date</th><th>Tournoi</th><th>Niveau</th><th>Surface</th></tr></thead><tbody>'+up.map(t=>'<tr class="click" onclick="openTournament('+Number(t.id)+')"><td>'+df(t.start_date)+'</td><td><b>'+esc(t.name)+'</b></td><td>'+esc(t.category||t.level||t.circuit||'—')+'</td><td>'+esc(surfaceLabel(t))+'</td></tr>').join('')+'</tbody></table></div>':'<div class="empty">Aucune recommandation de calendrier.</div>')+'</div>'+
 '<div class="card" style="margin-top:12px"><h2>Objectifs du board</h2>'+((h.objectives||boot.board||[]).map(o=>'<div class="list-item"><div class="row between"><b>'+esc(o.objective)+'</b><span>'+fmt(o.progress||0)+'%</span></div><div class="bar"><i style="width:'+Number(o.progress||0)+'%"></i></div><div class="muted micro">'+esc(o.target_value||'')+' · '+df(o.deadline)+'</div></div>').join('')||'<div class="empty">Aucun objectif.</div>')+'</div>';
}
window.saveManagedSeasonPlan=async()=>{
 try{
  const payload={
   plan_type:document.getElementById('seasonPlanType')?.value,
   preferred_surface:document.getElementById('seasonPreferredSurface')?.value,
   secondary_surface:document.getElementById('seasonSecondarySurface')?.value,
   target_events:Number(document.getElementById('seasonTargetEvents')?.value||22),
   max_consecutive_weeks:Number(document.getElementById('seasonMaxWeeks')?.value||3),
   rest_trigger_fatigue:Number(document.getElementById('seasonFatigueTrigger')?.value||62),
   rest_bias:Number(document.getElementById('seasonRestBias')?.value||10),
   travel_tolerance:Number(document.getElementById('seasonTravel')?.value||10),
   prestige_bias:Number(document.getElementById('seasonPrestige')?.value||10),
   development_bias:Number(document.getElementById('seasonDevelopment')?.value||10),
   doubles_bias:Number(document.getElementById('seasonDoubles')?.value||10),
   schedule_risk_tolerance:Number(document.getElementById('seasonRisk')?.value||10),
   mental_load_target:Number(document.getElementById('seasonMental')?.value||10)
  };
  await managerAction('update_season_plan',0,{plan:payload,player_id:activeManagedId()});
  careerHub=null;activeManagedContext=null;await Promise.all([loadCareerHub(true),loadScheduleAdvice(),loadActiveManagedContext(true)]);
  alert('Plan de saison enregistré.');render();
 }catch(e){alert(e.message)}
}
function relationshipsPage(){
 const rows=careerHub?.relationships||[];
 const groups={friend:0,rival:0,other:0};
 rows.forEach(r=>{const t=String(r.relation_type||'').toLowerCase();if(t.includes('rival'))groups.rival++;else if(Number(r.affinity||0)>=65)groups.friend++;else groups.other++});
 return '<div class="section-head"><div><div class="eyebrow">Monde social simulé</div><h1>Relations & rivalités</h1><div class="muted">Affinité, confiance, respect et proximité sportive évoluent avec les matchs, le double et les parcours de carrière.</div></div><span class="pill">'+rows.length+' relations</span></div>'+
 '<div class="grid g3"><div class="card"><div class="eyebrow">Affinités fortes</div><div class="big">'+groups.friend+'</div></div><div class="card"><div class="eyebrow">Rivalités</div><div class="big">'+groups.rival+'</div></div><div class="card"><div class="eyebrow">Autres relations</div><div class="big">'+groups.other+'</div></div></div>'+
 '<div class="card" style="margin-top:12px"><div class="stack">'+(rows.map(r=>{const o=Array.isArray(r.other)?r.other[0]:r.other||{};return '<div class="list-item click" onclick="openPlayer('+Number(o.id||0)+')"><div class="row between"><div><b>'+(flags[o.country]||'🏳️')+' '+esc(o.name||'Joueur')+'</b><div class="muted mini">'+esc(r.relation_type||'Affinité sportive')+' · ATP '+(o.ranking?'#'+fmt(o.ranking):'NR')+'</div></div><div style="text-align:right"><b>'+fmt(r.affinity||0)+'/100</b><div class="muted micro">'+(r.is_simulated?'Simulation Court Boss':'Sourcé')+'</div></div></div><div class="bar" style="margin-top:6px"><i style="width:'+Number(r.affinity||0)+'%"></i></div><div class="row between muted micro" style="margin-top:4px"><span>Confiance '+fmt(r.trust||0)+'</span><span>Respect '+fmt(r.respect||0)+'</span><span>Proximité '+fmt(r.closeness||0)+'</span></div></div>'}).join('')||'<div class="empty">Aucune relation connue.</div>')+'</div><div class="muted micro" style="margin-top:10px">Les relations simulées sont des mécaniques de jeu, pas des affirmations sur la vie privée réelle des joueurs.</div></div>';
}
function mediaPage(){
 const media=careerHub?.media||[],events=careerHub?.events||[];
 const choiceButtons=x=>String(x.response_status||'pending')==='resolved'
  ?'<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px"><span class="badge good">Réponse : '+esc(x.response_choice||'prise')+'</span><span class="badge">Moral '+(Number(x.morale_delta||0)>=0?'+':'')+fmt(x.morale_delta||0)+'</span><span class="badge">Réputation '+(Number(x.reputation_delta||0)>=0?'+':'')+fmt(x.reputation_delta||0)+'</span></div>'
  :'<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px"><button class="soft-btn" onclick="respondMedia('+Number(x.id)+',\'professionnel\')">Professionnel</button><button class="soft-btn" onclick="respondMedia('+Number(x.id)+',\'ambitieux\')">Ambitieux</button><button class="soft-btn" onclick="respondMedia('+Number(x.id)+',\'combatif\')">Combatif</button><button class="ghost" onclick="respondMedia('+Number(x.id)+',\'calme\')">Calme</button></div>';
 return '<div class="section-head"><div><div class="eyebrow">Narration carrière</div><h1>Médias & actualité</h1><div class="muted">Les storylines sont maintenant interactives : ta façon de répondre influence le moral, la pression médiatique et la réputation de jeu.</div></div><span class="pill">'+media.length+' sujet(s)</span></div>'+
 '<div class="grid g2"><div class="stack">'+(media.map(x=>'<div class="card"><div class="row between"><div class="eyebrow">'+df(x.event_date)+' · '+esc(x.kind)+'</div><span class="badge '+(x.tone==='positive'?'good':x.tone==='concern'?'warn':'')+'">'+esc(x.tone||'neutral')+'</span></div><h2>'+esc(x.headline)+'</h2><p class="muted">'+esc(x.body)+'</p>'+choiceButtons(x)+(x.action_route?'<button class="ghost" style="margin-top:8px" onclick="nav(\''+esc(x.action_route)+'\')">Voir le contexte</button>':'')+'</div>').join('')||'<div class="card empty">Les premiers sujets apparaîtront au fil des semaines.</div>')+'</div>'+
 '<div class="card"><div class="row between"><div><div class="eyebrow">Journal Career OS</div><h2>Événements récents</h2></div><span class="badge">'+events.length+'</span></div>'+events.slice(0,30).map(x=>'<div class="list-item"><div class="row between"><b>'+esc(x.summary)+'</b><span class="muted micro">'+df(x.event_date)+'</span></div><div class="muted mini">'+esc(x.system)+' · '+esc(x.event_type)+'</div></div>').join('')+'</div></div>';
}
window.respondMedia=async(id,choice)=>{
 try{
  await managerAction('respond_media',Number(id),{choice});
  careerHub=null;boot=await get('/api/bootstrap');await loadCareerHub(true);render();
 }catch(e){alert(e.message)}
}
function diagnosticsPage(){
 const x=careerHub?.health||{},i=careerHub?.integrity||{};
 const baseChecks=[
  ['Carrière',x.career_exists],['Joueur géré',x.managed_player_exists],['Académie',x.academy_exists],
  ['Plan saison',Number(i.missing_season_plan||0)===0],['Inbox',Number(i.duplicate_pending_inbox||0)===0&&Number(i.expired_pending_decisions||0)===0],
  ['Académie capacité',Number(i.academy_overflow||0)===0],['Contrats',Number(i.overdue_active_contracts||0)===0],
  ['Sauvegardes',Boolean(i.baseline_template_integrity)&&Number(i.invalid_save_snapshots||0)===0&&Number(i.save_metadata_mismatches||0)===0&&Number(i.save_local_payload_mismatches||0)===0&&Number(i.invalid_save_slot_shape||0)===0],
  ['Sponsors',Number(i.sponsor_missing_lifecycle||0)===0&&Number(i.sponsor_overpaid||0)===0&&Number(i.sponsor_expired_still_active||0)===0&&Number(i.sponsor_ledger_mismatches||0)===0],
  ['Staff',Number(i.duplicate_staff_profiles||0)===0],['Relations',Number(i.self_relationships||0)===0]
 ];
 const metric=(l,v,alert=false)=>'<div class="statbox"><span class="muted mini">'+esc(l)+'</span><b class="'+(alert&&Number(v)>0?'bad':'')+'">'+fmt(v||0)+'</b></div>';
 const issue=(label,value)=>Number(value||0)>0?'<div class="list-item row between"><span>'+esc(label)+'</span><span class="badge bad">'+fmt(value)+'</span></div>':'';
 const issues=[
  issue('Plans de saison manquants',i.missing_season_plan),
  issue('Décisions inbox dupliquées',i.duplicate_pending_inbox),
  issue('Décisions expirées encore actives',i.expired_pending_decisions),
  issue('Jeunes au-dessus de la capacité',i.academy_overflow),
  issue('Blessures actives multiples du joueur géré',Math.max(0,Number(i.managed_active_injuries||0)-1)),
  issue('Engagements double principaux multiples',Math.max(0,Number(i.active_doubles_commitments||0)-1)),
  issue('Profils staff dupliqués',i.duplicate_staff_profiles),
  issue('Joueurs académie orphelins',i.orphan_academy_roster),
  issue('Contrats actifs déjà périmés',i.overdue_active_contracts),
  issue('Snapshots de sauvegarde invalides',i.invalid_save_snapshots),
  issue('Métadonnées de sauvegarde incohérentes',i.save_metadata_mismatches),
  issue('Payloads locaux de sauvegarde incohérents',i.save_local_payload_mismatches),
  issue('Forme de slot de sauvegarde invalide',i.invalid_save_slot_shape),
  issue('Sponsors acceptés sans cycle contractuel',i.sponsor_missing_lifecycle),
  issue('Sponsors payés au-delà de la durée',i.sponsor_overpaid),
  issue('Sponsors terminés encore actifs',i.sponsor_expired_still_active),
  issue('Divergences sponsor / ledger',i.sponsor_ledger_mismatches),
  issue('Relations avec soi-même',i.self_relationships)
 ].filter(Boolean).join('');
 return '<div class="section-head"><div><div class="eyebrow">QA carrière</div><h1>Diagnostic Career OS</h1><div class="muted">Audit automatique de la sauvegarde, des décisions, de l’académie et des systèmes manager.</div></div><button class="primary" onclick="refreshCareerDiagnostics()">Réanalyser</button></div>'+
 '<div class="notice '+(i.ok===false?'bad':'good')+'"><b>'+(i.ok===false?'Anomalies détectées':'Intégrité carrière OK')+'</b><br><span class="muted mini">'+esc(i.model||'CB-CAREER-INTEGRITY-v3')+' · '+df(i.date||local.date)+'</span></div>'+
 '<div class="grid g3" style="margin-top:12px">'+baseChecks.map(c=>'<div class="card"><div class="eyebrow">'+esc(c[0])+'</div><div class="big '+(c[1]?'good':'bad')+'">'+(c[1]?'OK':'KO')+'</div></div>').join('')+'</div>'+
 '<div class="grid g2" style="margin-top:12px">'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Santé générale</div><h2>'+esc(x.model||'CB-CAREER-OS-v1')+'</h2></div><span class="badge good">'+df(x.date||local.date)+'</span></div><div class="statline">'+metric('Staff actif',x.active_staff)+metric('Contrats actifs',x.active_contracts)+metric('Prospects académie',x.academy_prospects)+metric('Joueurs académie',x.academy_active_players)+metric('Scouting actif',x.active_scouting)+metric('Sponsors dispo',x.available_sponsors)+metric('Relations',x.relationships)+metric('Plans saison',x.season_plans)+metric('Inbox non lue',x.unread_inbox)+metric('Blessures actives',x.active_injuries)+'</div></div>'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Intégrité durable</div><h2>Contrôles de cohérence</h2></div><span class="badge '+(i.ok===false?'bad':'good')+'">'+(i.ok===false?'À corriger':'0 erreur bloquante')+'</span></div>'+
   (issues||'<div class="notice good" style="margin-top:10px">Aucune anomalie bloquante détectée.</div>')+
   '<div class="statline" style="margin-top:10px">'+metric('Capacité académie',i.academy_capacity)+metric('Jeunes actifs',i.academy_active_youth)+metric('Slots',i.save_slots_total)+metric('Slots legacy',i.legacy_save_slots,true)+metric('Snapshots invalides',i.invalid_save_snapshots,true)+metric('Métadonnées save',i.save_metadata_mismatches,true)+metric('Payloads save',i.save_local_payload_mismatches,true)+metric('Cycle sponsor',i.sponsor_missing_lifecycle,true)+metric('Sponsor / ledger',i.sponsor_ledger_mismatches,true)+metric('Questions média anciennes',i.stale_media_questions,true)+'</div>'+
   '<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:9px"><span class="badge '+(i.baseline_template_integrity?'good':'bad')+'">Template nouvelle partie '+(i.baseline_template_integrity?'intègre':'à réparer')+'</span><span class="badge '+(Number(i.invalid_save_slot_shape||0)===0?'good':'bad')+'">Structure slots '+(Number(i.invalid_save_slot_shape||0)===0?'OK':'KO')+'</span><span class="badge">Double principal '+fmt(i.active_doubles_commitments||0)+'</span></div>'+
  '</div>'+
 '</div>';
}
window.refreshCareerDiagnostics=async()=>{careerHub=null;await loadCareerHub(true);render()}

function render(){
 if(!boot)return;
 const views={home,rankings,calendar,competitions:competitionsPage,academy,more,players:playersPage,training,scouting,staff:staffPage,contracts:contractsPage,finance:financePage,medical:medicalPage,match:matchPage,tactics:tacticsPage,fantasy:fantasyPage,doubles:doublesPage,university:universityPage,davis:davisPage,board:boardPage,world:worldPage,history:historyPage,myplayer:myPlayerPage,fantasy:fantasyPage,inbox:inboxPage,saves:saveCenterPage,careerhub:careerHubPage,season:seasonPage,media:mediaPage,relationships:relationshipsPage,diagnostics:diagnosticsPage,launcher:launcherPage};
 shell((views[route]||more)());
}


function playerStatsAdvancedSections(st,p){
 const exact=st?.elite_exact||{top10_wins:st?.elite_by_rank?.top10?.wins||0,top10_losses:st?.elite_by_rank?.top10?.losses||0,top10_matches:st?.elite_by_rank?.top10?.matches||0,top20_wins:st?.elite_by_rank?.top20?.wins||0,top20_losses:st?.elite_by_rank?.top20?.losses||0,top20_matches:st?.elite_by_rank?.top20?.matches||0,top50_wins:st?.elite_by_rank?.top50?.wins||0,top50_losses:st?.elite_by_rank?.top50?.losses||0,top50_matches:st?.elite_by_rank?.top50?.matches||0,top100_wins:st?.elite_by_rank?.top100?.wins||0,top100_losses:st?.elite_by_rank?.top100?.losses||0,top100_matches:st?.elite_by_rank?.top100?.matches||0},bands=Array.isArray(st?.rank_bands)?st.rank_bands:[],levels=Array.isArray(st?.competition_levels)?st.competition_levels:[],seasons=Array.isArray(st?.season_records)?st.season_records:[],countries=Array.isArray(st?.country_records)?st.country_records:[],hand=st?.handedness_records||{},pressure=st?.pressure_records||{},longest=st?.longest_streaks||{},last10=st?.last10||{},upset=st?.largest_upset||null,worst=st?.worst_ranked_loss||null,leaders=st?.leaders||{},rivalry=st?.rivalry_summary||{};
 const eliteRank=st?.elite_by_rank||{};
 const pct=r=>{const m=Number(r?.matches||0),w=Number(r?.wins||0);return m?Math.round(w/m*1000)/10:0};
 const wl=r=>'<b>'+Number(r?.wins||0)+'-'+Number(r?.losses||0)+'</b> · '+pct(r)+'%';
 const mini=(label,r)=>'<div class="statbox"><span class="muted mini">'+esc(label)+'</span><b>'+Number(r?.wins||0)+'-'+Number(r?.losses||0)+'</b><small class="muted micro">'+Number(r?.matches||0)+' matchs · '+pct(r)+'%</small></div>';
 const event=x=>x?'<span class="click" onclick="openPlayer('+x.opponent_id+')"><b>#'+fmt(x.opponent_rank)+' '+esc(x.opponent_name||'—')+'</b></span><div class="muted micro">'+df(x.date)+' · '+esc(x.tournament_name||'')+' · '+esc(x.round||'')+' · '+esc(x.score||'')+(x.rank_gap?' · écart '+fmt(x.rank_gap):'')+'</div>':'<span class="muted">—</span>';
 const bandsRows=bands.map(r=>'<tr><td><b>'+esc(r.band)+'</b></td><td>'+Number(r.matches||0)+'</td><td class="a-good">'+Number(r.wins||0)+'</td><td class="a-bad">'+Number(r.losses||0)+'</td><td><b>'+Number(r.win_pct||0).toFixed(1)+'%</b></td></tr>').join('');
 const levelRows=levels.map(r=>'<tr><td><b>'+esc(r.level)+'</b></td><td>'+Number(r.matches||0)+'</td><td>'+Number(r.wins||0)+'-'+Number(r.losses||0)+'</td><td><b>'+Number(r.win_pct||0).toFixed(1)+'%</b></td></tr>').join('');
 const seasonRows=seasons.map(r=>'<tr><td class="rank-num">'+r.season+'</td><td>'+Number(r.matches||0)+'</td><td>'+Number(r.wins||0)+'-'+Number(r.losses||0)+'</td><td><b>'+Number(r.win_pct||0).toFixed(1)+'%</b></td></tr>').join('');
 const countryRows=countries.map(r=>'<div class="list-item row between"><span>'+(flags[r.country]||'🏳️')+' '+esc(r.country||'—')+'</span><span><b>'+Number(r.wins||0)+'-'+Number(r.losses||0)+'</b> · '+Number(r.win_pct||0).toFixed(1)+'%</span></div>').join('');
 return ''+
 '<div class="grid g2" style="margin-top:12px">'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Leaders & Classes</div><h2>Rang analytique mondial</h2></div><span class="badge">'+fmt(leaders.population||0)+' joueurs</span></div>'+
   '<div class="statline" style="margin-top:8px">'+
    '<div class="statbox"><span class="muted mini">Service</span><b>#'+fmt(leaders.serve?.rank||0)+'</b><small class="muted micro">'+(leaders.serve?.value==null?'—':Number(leaders.serve.value).toFixed(1))+'</small></div>'+
    '<div class="statbox"><span class="muted mini">Retour</span><b>#'+fmt(leaders.return?.rank||0)+'</b><small class="muted micro">'+(leaders.return?.value==null?'—':Number(leaders.return.value).toFixed(1))+'</small></div>'+
    '<div class="statbox"><span class="muted mini">Pression</span><b>#'+fmt(leaders.pressure?.rank||0)+'</b><small class="muted micro">'+(leaders.pressure?.value==null?'—':Number(leaders.pressure.value).toFixed(1))+'</small></div>'+
    '<div class="statbox"><span class="muted mini">Hold</span><b>#'+fmt(leaders.hold?.rank||0)+'</b><small class="muted micro">'+(leaders.hold?.value==null?'—':Number(leaders.hold.value).toFixed(1)+'%')+'</small></div>'+
    '<div class="statbox"><span class="muted mini">Break</span><b>#'+fmt(leaders.break?.rank||0)+'</b><small class="muted micro">'+(leaders.break?.value==null?'—':Number(leaders.break.value).toFixed(1)+'%')+'</small></div>'+
    '<div class="statbox"><span class="muted mini">Tie-break</span><b>#'+fmt(leaders.tiebreak?.rank||0)+'</b><small class="muted micro">'+(leaders.tiebreak?.value==null?'—':Number(leaders.tiebreak.value).toFixed(1)+'%')+'</small></div>'+
   '</div><div class="muted micro" style="margin-top:8px">Comparaison dynamique avec les joueurs actifs disposant d\'un profil analytique Court Boss.</div></div>'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Rivalités</div><h2>Carte H2H</h2></div><span class="badge">historique + simulation</span></div>'+
   '<div class="statline" style="margin-top:8px">'+
    '<div class="statbox"><span class="muted mini">H2H positifs</span><b>'+Number(rivalry.winning_h2h||0)+'</b></div>'+
    '<div class="statbox"><span class="muted mini">H2H négatifs</span><b>'+Number(rivalry.losing_h2h||0)+'</b></div>'+
    '<div class="statbox"><span class="muted mini">H2H à égalité</span><b>'+Number(rivalry.tied_h2h||0)+'</b></div>'+
    '<div class="statbox"><span class="muted mini">N°1 mondiaux battus</span><b>'+Number(rivalry.unique_no1_defeated||0)+'</b></div>'+
    '<div class="statbox"><span class="muted mini">Top 5 battus</span><b>'+Number(rivalry.unique_top5_defeated||0)+'</b></div>'+
    '<div class="statbox"><span class="muted mini">Top 20 battus</span><b>'+Number(rivalry.unique_top20_defeated||0)+'</b></div>'+
   '</div>'+
   (rivalry.most_played?'<div class="list-item row between"><span>Rivalité la plus longue</span><span style="text-align:right"><span class="click" onclick="openPlayer('+rivalry.most_played.opponent_id+')"><b>'+esc(rivalry.most_played.opponent_name||'—')+'</b></span><div class="muted micro">'+Number(rivalry.most_played.wins||0)+'-'+Number(rivalry.most_played.losses||0)+' · '+Number(rivalry.most_played.matches||0)+' matchs</div></span></div>':'<div class="empty">Les rivalités se construiront au fil des matchs.</div>')+
   (rivalry.closest_rivalry?'<div class="list-item row between"><span>Rivalité la plus serrée</span><span style="text-align:right"><span class="click" onclick="openPlayer('+rivalry.closest_rivalry.opponent_id+')"><b>'+esc(rivalry.closest_rivalry.opponent_name||'—')+'</b></span><div class="muted micro">'+Number(rivalry.closest_rivalry.wins||0)+'-'+Number(rivalry.closest_rivalry.losses||0)+' · '+Number(rivalry.closest_rivalry.matches||0)+' matchs</div></span></div>':'')+
  '</div>'+
 '</div>'+
 '<div class="grid g2" style="margin-top:12px">'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Opposition</div><h2>Classement des adversaires</h2></div><span class="badge">rang au jour J</span></div>'+
   '<div class="statline" style="margin-top:8px">'+
    mini('N°1 mondial',eliteRank.top1)+mini('Top 5',eliteRank.top5)+mini('Top 10',eliteRank.top10||{matches:exact.top10_matches,wins:exact.top10_wins,losses:exact.top10_losses})+mini('Top 20',eliteRank.top20||{matches:exact.top20_matches,wins:exact.top20_wins,losses:exact.top20_losses})+mini('Top 50',eliteRank.top50||{matches:exact.top50_matches,wins:exact.top50_wins,losses:exact.top50_losses})+mini('Top 100',eliteRank.top100||{matches:exact.top100_matches,wins:exact.top100_wins,losses:exact.top100_losses})+
   '</div>'+
   (bandsRows?'<div class="table-wrap" style="margin-top:9px"><table class="table"><thead><tr><th>Tranche</th><th>M</th><th>V</th><th>D</th><th>%</th></tr></thead><tbody>'+bandsRows+'</tbody></table></div>':'<div class="empty">Les tranches se rempliront à partir des matchs de la sauvegarde.</div>')+
  '</div>'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Matchs à pression</div><h2>Moments qui comptent</h2></div><span class="badge">simulation</span></div>'+
   '<div class="statline" style="margin-top:8px">'+
    mini('Finales',pressure.finals)+mini('Demi-finales',pressure.semifinals)+mini('Quarts',pressure.quarterfinals)+mini('Qualifications',pressure.qualifying)+mini('Best of 5',pressure.best_of_five)+mini('Avec tie-break',pressure.matches_with_tiebreak)+mini('Set décisif',pressure.deciding_set_matches)+mini('Comeback après 1er set',pressure.comeback_after_losing_first_set)+mini('10 derniers',last10)+
   '</div>'+
   '<div class="list-item row between"><span>Victoires en sets secs</span><b>'+Number(pressure.straight_set_wins||0)+'</b></div>'+
   '<div class="list-item row between"><span>Bagels gagnés / concédés</span><b>'+Number(pressure.bagel_sets_won||0)+' / '+Number(pressure.bagel_sets_lost||0)+'</b></div>'+
   '<div class="list-item row between"><span>Défaites après gain du 1er set</span><b>'+Number(pressure.lost_after_winning_first_set||0)+'</b></div>'+
   '<div class="list-item row between"><span>Défaites en sets secs</span><b>'+Number(pressure.straight_set_losses||0)+'</b></div>'+
   '<div class="list-item row between"><span>Plus longue série de victoires</span><b>'+Number(longest.win||0)+'</b></div>'+
   '<div class="list-item row between"><span>Plus longue série de défaites</span><b>'+Number(longest.loss||0)+'</b></div>'+
  '</div>'+
 '</div>'+
 '<div class="grid g2" style="margin-top:12px">'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Tournois</div><h2>Bilan par niveau</h2></div><span class="badge">carrière simulée</span></div>'+
   (levelRows?'<div class="table-wrap" style="margin-top:9px"><table class="table"><thead><tr><th>Niveau</th><th>M</th><th>V-D</th><th>%</th></tr></thead><tbody>'+levelRows+'</tbody></table></div>':'<div class="empty">Aucun match détaillé encore joué.</div>')+
   '<div class="list-item row between"><span>Plus gros upset</span><span style="text-align:right">'+event(upset)+'</span></div>'+
   '<div class="list-item row between"><span>Pire défaite au classement</span><span style="text-align:right">'+event(worst)+'</span></div>'+
  '</div>'+
  '<div class="card"><div class="row between"><div><div class="eyebrow">Profil d’opposition</div><h2>Qui il affronte</h2></div><span class="badge">scouting carrière</span></div>'+
   '<div class="statline" style="margin-top:8px">'+mini('Vs gauchers',hand.left)+mini('Vs droitiers',hand.right)+'</div>'+
   (countryRows?'<div style="margin-top:8px">'+countryRows+'</div>':'<div class="empty">Aucun bilan par pays encore disponible.</div>')+
  '</div>'+
 '</div>'+
 '<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Évolution</div><h2>Saison par saison</h2></div><span class="badge">'+seasons.length+' saison(s)</span></div>'+
  (seasonRows?'<div class="table-wrap" style="margin-top:9px"><table class="table"><thead><tr><th>Saison</th><th>Matchs</th><th>V-D</th><th>%</th></tr></thead><tbody>'+seasonRows+'</tbody></table></div>':'<div class="empty">La première ligne apparaîtra dès les premiers matchs de la carrière.</div>')+
 '</div>';
}

function playerStatsTemplate(st,p,fin={}){
 const career=st?.career||{},elite=st?.elite_wins||{},adv=st?.advanced||{},surfaces=st?.surfaces||{},streaks=st?.streaks||{};
 const h2h=Array.isArray(st?.h2h)?st.h2h:[],recent=Array.isArray(st?.recent_matches)?st.recent_matches:[],matchHistory=Array.isArray(st?.match_history)?st.match_history:recent;
 const pctRec=r=>{const w=Number(r?.wins||0),l=Number(r?.losses||0);return w+l?Math.round(w/(w+l)*1000)/10:0};
 const num=v=>v==null||v===''?'—':fmt(Number(v));
 const one=v=>v==null||Number.isNaN(Number(v))?'—':Number(v).toFixed(1);
 const metric=(label,v,suffix='')=>'<div class="statbox"><span class="muted mini">'+esc(label)+'</span><b>'+one(v)+(v==null?'':suffix)+'</b></div>';
 const surfaceRow=(label,r,tag='')=>{const w=Number(r?.wins||0),l=Number(r?.losses||0),pc=pctRec(r);return '<div class="attr-row"><div class="row between"><span>'+esc(label)+(tag?' <span class="muted micro">'+esc(tag)+'</span>':'')+'</span><span><b>'+w+'-'+l+'</b> · '+pc+'%</span></div><div class="bar"><i style="width:'+pc+'%"></i></div></div>'};
 const best=elite.best_ranked_win||null,fav=st?.favorite_opponent||null,nem=st?.nemesis||null;
 const exactFrom=st?.coverage?.match_level_ranked_stats_from?df(st.coverage.match_level_ranked_stats_from):'début de carrière simulée';
 const rival=x=>x?'<span class="click" onclick="openPlayer('+x.opponent_id+')"><b>'+esc(x.opponent_name||'—')+'</b></span><div class="muted micro">'+Number(x.wins||0)+'-'+Number(x.losses||0)+(x.career_high_rank?' · meilleur #'+fmt(x.career_high_rank):'')+'</div>':'<span class="muted">—</span>';
 const h2hRows=h2h.map(r=>{
   const search=String((r.opponent_name||'')+' '+(r.country||'')).toLowerCase();
   return '<tr data-h2h-search="'+esc(search)+'" data-h2h-opponent-id="'+Number(r.opponent_id||0)+'"><td><span class="click" onclick="openPlayer('+r.opponent_id+')"><b>'+esc(r.opponent_name||'—')+'</b></span><div class="muted micro">'+esc(r.country||'')+(r.current_rank?' · ATP #'+fmt(r.current_rank):'')+(r.career_high_rank?' · peak #'+fmt(r.career_high_rank):'')+'</div></td><td><b>'+Number(r.wins||0)+'-'+Number(r.losses||0)+'</b></td><td>'+Number(r.hard_wins||0)+'-'+Number(r.hard_losses||0)+'</td><td>'+Number(r.clay_wins||0)+'-'+Number(r.clay_losses||0)+'</td><td>'+Number(r.grass_wins||0)+'-'+Number(r.grass_losses||0)+'</td><td>'+(r.last_match_date?df(r.last_match_date):'—')+'<div class="muted micro">'+esc(r.last_surface||'')+'</div></td><td><span class="badge">'+Number(r.real_matches||0)+' réel</span> <span class="badge good">'+Number(r.simulated_matches||0)+' sim</span></td><td><button class="ghost" onclick="filterPlayerMatchHistory('+Number(r.opponent_id||0)+')">Matchs</button></td></tr>';
 }).join('');
 const recentRows=recent.map(r=>'<tr><td>'+df(r.date)+'</td><td><span class="click" onclick="openTournament('+r.tournament_id+')"><b>'+esc(r.tournament_name||'—')+'</b></span><div class="muted micro">'+esc(r.category||'')+' · '+esc(r.round||'')+'</div></td><td><span class="click" onclick="openPlayer('+r.opponent_id+')">'+esc(r.opponent_name||'—')+'</span><div class="muted micro">'+(r.opponent_rank?'ATP #'+fmt(r.opponent_rank):'NR')+'</div></td><td><span class="badge '+(r.won?'good':'bad')+'">'+(r.won?'V':'D')+'</span></td><td><b>'+esc(r.score||'—')+'</b></td></tr>').join('');
 const matchHistoryRows=matchHistory.map(r=>{const search=String((r.opponent_name||'')+' '+(r.tournament_name||'')+' '+(r.category||'')+' '+(r.surface||'')+' '+(r.round||'')).toLowerCase();return '<tr data-match-opponent-id="'+Number(r.opponent_id||0)+'" data-match-search="'+esc(search)+'"><td>'+df(r.date)+'</td><td><span class="click" onclick="openTournament('+r.tournament_id+')"><b>'+esc(r.tournament_name||'—')+'</b></span><div class="muted micro">'+esc(r.category||'')+' · '+esc(r.round||'')+' · '+esc(r.surface||'')+'</div></td><td><span class="click" onclick="openPlayer('+r.opponent_id+')"><b>'+esc(r.opponent_name||'—')+'</b></span><div class="muted micro">'+(r.opponent_rank?'ATP #'+fmt(r.opponent_rank):'NR')+(r.player_rank?' · joueur #'+fmt(r.player_rank):'')+'</div></td><td><span class="badge '+(r.won?'good':'bad')+'">'+(r.won?'V':'D')+'</span></td><td><b>'+esc(r.score||'—')+'</b><div class="muted micro">'+(r.had_tiebreak?'tie-break · ':'')+(r.first_set_won===false&&r.won?'comeback · ':'')+(Number(r.bagels_for||0)?Number(r.bagels_for)+' bagel gagné · ':'')+(Number(r.bagels_against||0)?Number(r.bagels_against)+' bagel subi':'')+'</div></td></tr>'}).join('');
 const streakLabel=Number(streaks.current_win_streak||0)>0?Number(streaks.current_win_streak)+' V':Number(streaks.current_loss_streak||0)>0?Number(streaks.current_loss_streak)+' D':'—';
 return `
 <div class="notice"><b>Statistiques de match</b> · Inspiré de la page Statistics / H2H de Tennis Manager, avec une couche Court Boss plus précise sur le classement de l’adversaire au jour du match. <span class="muted micro">${esc(st?.coverage?.note||'')}</span></div>
 <div class="kpi-strip" style="margin-top:12px">
   <div class="kpi"><span class="muted mini">Matchs carrière</span><b>${num(career.matches)}</b><small class="muted micro">${num(career.wins)} V · ${num(career.losses)} D</small></div>
   <div class="kpi"><span class="muted mini">Taux de victoire</span><b>${one(career.win_pct)}%</b></div>
   <div class="kpi"><span class="muted mini">Adversaires affrontés</span><b>${num(career.opponents_faced)}</b></div>
   <div class="kpi"><span class="muted mini">Série actuelle</span><b>${streakLabel}</b></div>
   <div class="kpi"><span class="muted mini">10 derniers</span><b>${Number(st?.last10?.wins||0)}-${Number(st?.last10?.losses||0)}</b></div>
   <div class="kpi"><span class="muted mini">Prize money sauvegarde</span><b>${euro(fin.total_prize_eur||0)}</b><small class="muted micro">depuis le 01/12/2025</small></div>
 </div>
 <div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Économie de carrière simulée</div><h2>Prize money</h2></div><span class="badge">${esc(fin.base_currency||'EUR')}</span></div>
  <div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Simple</span><b>${euro(fin.singles_prize_eur||0)}</b></div><div class="kpi"><span class="muted micro">Double</span><b>${euro(fin.doubles_prize_eur||0)}</b></div><div class="kpi"><span class="muted micro">Total</span><b>${euro(fin.total_prize_eur||0)}</b></div><div class="kpi"><span class="muted micro">Tournois comptés</span><b>${fmt(fin.events||0)}</b></div></div>
  ${Array.isArray(fin.seasons)&&fin.seasons.length?'<div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>Saison</th><th>Simple</th><th>Double</th><th>Total</th></tr></thead><tbody>'+fin.seasons.slice(0,12).map(x=>'<tr><td><b>'+x.season+'</b></td><td>'+euro(x.singles_eur||0)+'</td><td>'+euro(x.doubles_eur||0)+'</td><td><b>'+euro(x.total_eur||0)+'</b></td></tr>').join('')+'</tbody></table></div>':''}
  <div class="muted micro" style="margin-top:8px">Gains de la sauvegarde uniquement. Double = part individuelle (50% du prize money équipe). Conversion en EUR avec le taux de référence Court Boss du 01/12/2025. ${Number(fin.estimated_events||0)?fmt(fin.estimated_events)+' tournoi(s) utilisent un barème estimé.':''}</div>
 </div>
 <div class="grid g2" style="margin-top:12px">
  <div class="card">
   <div class="row between"><div><div class="eyebrow">Niveau des adversaires</div><h2>Victoires de référence</h2></div><span class="badge">classement match</span></div>
   <div class="statline" style="margin-top:8px">
    <div class="statbox"><span class="muted mini">Top 10 déjà battus</span><b>${num(elite.unique_top10_players_defeated)}</b><small class="muted micro">joueurs ayant atteint le Top 10</small></div>
    <div class="statbox"><span class="muted mini">Victoires vs Top 10</span><b>${num(elite.top10_wins_exact)}</b><small class="muted micro">classés Top 10 le jour J · depuis ${exactFrom}</small></div>
    <div class="statbox"><span class="muted mini">Victoires vs Top 50</span><b>${num(elite.top50_wins_exact)}</b></div>
    <div class="statbox"><span class="muted mini">Upsets</span><b>${num(elite.wins_vs_higher_ranked)}</b><small class="muted micro">victoires contre mieux classé</small></div>
   </div>
   <div class="list-item row between"><span>Meilleure victoire classée</span><span style="text-align:right">${best?'<span class="click" onclick="openPlayer('+best.opponent_id+')"><b>#'+fmt(best.opponent_rank)+' '+esc(best.opponent_name)+'</b></span><div class="muted micro">'+df(best.date)+' · '+esc(best.tournament_name||'')+' · '+esc(best.score||'')+'</div>':'<span class="muted">À construire dans la carrière simulée</span>'}</span></div>
   <div class="list-item row between"><span>Adversaire le plus battu</span><span style="text-align:right">${rival(fav)}</span></div>
   <div class="list-item row between"><span>Bête noire</span><span style="text-align:right">${rival(nem)}</span></div>
  </div>
  <div class="card"><div class="eyebrow">Bilan</div><h2>Par surface</h2>
   ${surfaceRow('Dur',surfaces.hard)}
   ${surfaceRow('Terre battue',surfaces.clay)}
   ${surfaceRow('Gazon',surfaces.grass)}
   ${surfaceRow('Indoor',surfaces.indoor,'détail exact depuis la simulation')}
  </div>
 </div>
 <div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Leaders & Classes</div><h2>Performance match</h2></div><span class="badge">${num(adv.sample_matches)} match(s) échantillon</span></div>
  <div class="statline" style="margin-top:8px">
   ${metric('Serve rating',adv.serve_rating)}
   ${metric('Return rating',adv.return_rating)}
   ${metric('Pressure rating',adv.clutch_rating)}
   ${metric('1res balles',adv.first_serve_in_pct,'%')}
   ${metric('Jeux de service tenus',adv.hold_pct,'%')}
   ${metric('Jeux de retour gagnés',adv.break_pct,'%')}
   ${metric('Tie-breaks gagnés',adv.tiebreak_win_pct,'%')}
   ${metric('Sets décisifs',adv.deciding_set_win_pct,'%')}
   ${metric('Comebacks',adv.comeback_win_pct,'%')}
   ${metric('En tête → victoire',adv.front_runner_win_pct,'%')}
   ${metric('BP sauvées',adv.break_points_saved_pct,'%')}
   ${metric('BP converties',adv.break_points_converted_pct,'%')}
  </div>
  <div class="muted micro" style="margin-top:8px">Source performance : ${esc(adv.source_label||'Court Boss analytics')} · ces métriques évoluent avec les matchs réellement simulés.</div>
 </div>
 ${playerStatsAdvancedSections(st,p)}
 <div class="card" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Face-à-face</div><h2>H2H complet</h2></div><span class="badge">${h2h.length} adversaire(s)</span></div>
  <div style="margin-top:9px"><input class="input" placeholder="Chercher un adversaire…" oninput="const q=this.value.toLowerCase();document.querySelectorAll('#playerH2HRows tr').forEach(r=>r.style.display=(r.dataset.h2hSearch||'').includes(q)?'':'none')" /></div>
  ${h2hRows?'<div class="table-wrap" style="margin-top:9px"><table class="table"><thead><tr><th>Adversaire</th><th>H2H</th><th>Dur</th><th>Terre</th><th>Gazon</th><th>Dernier duel</th><th>Couverture</th><th></th></tr></thead><tbody id="playerH2HRows">'+h2hRows+'</tbody></table></div>':'<div class="empty">Aucun face-à-face enregistré.</div>'}
 </div>
 <div class="card" id="playerMatchHistoryCard" style="margin-top:12px">
  <div class="row between"><div><div class="eyebrow">Statistics / H2H history</div><h2>Historique match par match</h2><div class="muted micro" id="playerMatchHistoryLabel">Tous les matchs détaillés de la sauvegarde</div></div><span class="badge">${matchHistory.length} match(s)</span></div>
  <div class="row" style="gap:8px;margin-top:9px;flex-wrap:wrap"><input id="playerMatchHistorySearch" class="input" style="flex:1;min-width:220px" placeholder="Adversaire, tournoi, surface, tour…" oninput="searchPlayerMatchHistory(this.value)"><button class="ghost" onclick="resetPlayerMatchHistory()">Tous les matchs</button></div>
  ${matchHistoryRows?'<div class="table-wrap" style="margin-top:9px"><table class="table"><thead><tr><th>Date</th><th>Tournoi</th><th>Adversaire</th><th>Rés.</th><th>Score / contexte</th></tr></thead><tbody id="playerMatchHistoryRows">'+matchHistoryRows+'</tbody></table></div>':'<div class="empty">Le journal détaillé commencera avec les matchs joués après le 01/12/2025. Les H2H historiques agrégés restent disponibles au-dessus.</div>'}
 </div>`;
}

window.filterPlayerMatchHistory=id=>{
 const target=Number(id||0),rows=[...document.querySelectorAll('#playerMatchHistoryRows tr')];
 rows.forEach(r=>r.style.display=Number(r.dataset.matchOpponentId||0)===target?'':'none');
 const h=[...document.querySelectorAll('#playerH2HRows tr')].find(r=>Number(r.dataset.h2hOpponentId||0)===target);
 const name=h?.querySelector('b')?.textContent||'cet adversaire';
 const label=document.getElementById('playerMatchHistoryLabel');if(label)label.textContent='H2H détaillé vs '+name+' · matchs de la sauvegarde';
 const input=document.getElementById('playerMatchHistorySearch');if(input)input.value='';
 document.getElementById('playerMatchHistoryCard')?.scrollIntoView({behavior:'smooth',block:'start'});
};
window.resetPlayerMatchHistory=()=>{
 document.querySelectorAll('#playerMatchHistoryRows tr').forEach(r=>r.style.display='');
 const label=document.getElementById('playerMatchHistoryLabel');if(label)label.textContent='Tous les matchs détaillés de la sauvegarde';
 const input=document.getElementById('playerMatchHistorySearch');if(input)input.value='';
};
window.searchPlayerMatchHistory=q=>{
 const s=String(q||'').trim().toLowerCase();
 document.querySelectorAll('#playerMatchHistoryRows tr').forEach(r=>r.style.display=!s||(r.dataset.matchSearch||'').includes(s)?'':'none');
 const label=document.getElementById('playerMatchHistoryLabel');if(label)label.textContent=s?'Filtre · '+q:'Tous les matchs détaillés de la sauvegarde';
};
window.openPlayer=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du dossier joueur…</div></div></div>';
 try{
  const managedContextId=activeManagedId()||primaryManagedPlayerId()||0;
  const d=await get('/api/player?id='+id+'&managed_context_player_id='+encodeURIComponent(managedContextId)),p=d.player;if(!p)throw new Error('Joueur introuvable');
  const a=p.player_attributes||{},dev=d.developmentProfile||{},devHistory=d.developmentHistory||[],devTraitHistory=d.developmentTraitHistory||[],psych=d.psychologyState||{},hiddenTraitHistory=d.hiddenTraitHistory||[],roleFit=d.roleSuitability||null,attributeCeilings=d.attributeCeilings?.ceilings||{},attributeTrend=d.attributeTrend||null,mentorship=d.mentorship||{},mentor=mentorship.mentor||null,mentees=mentorship.mentees||[],mentorshipEvents=mentorship.events||[],advanced=d.advancedMetrics||{},elo=d.eloRating||{},dynamicRatings=d.dynamicRatings||{},surfacePref=d.surfacePreference||{},contextProfile=d.contextProfile||{},h2hManaged=d.h2hWithManaged||null,matchupPreviews=d.matchupPreviews||{},styleHistory=d.styleHistory||[],tacticalProfile=d.tacticalProfile||{},tacticalTraits=d.tacticalTraits||[],seasonPlan=d.seasonPlan||null,trainingLoad=d.trainingLoad||null,scoutReport=d.scoutingReport||null,isManaged=managedSquadIds().includes(Number(p.id)),knownContext=isManaged?contextProfile:(scoutReport?.context_estimates||{}),ncaaRows=d.ncaa||[],ncaaCareer=d.ncaaCareer||null,legend=d.legend||null,playerStaff=d.staff||[],playerStaffHistory=d.staffHistory||[],playerStaffBonds=d.staffBonds||[],relationships=d.relationships||[],agencyRepresentation=d.agencyRepresentation||null,agencyHistory=d.agencyHistory||[],careerFocusHistory=d.careerFocusHistory||[],primaryDoubles=d.primaryDoublesCommitment||null,doublesPartnerHistory=d.doublesPartnerHistory||[];
  const attrKnowledge=isManaged?{values:a,ranges:{},confidence:100,source:'managed'}:publicAttributeKnowledge(p,a,scoutReport);
  const knownAttrs=attrKnowledge.values||{},attrRanges=attrKnowledge.ranges||{};
  const attrDisplayValue=key=>isManaged?(knownAttrs[key]??'?'):(attrRanges[key]?attrRanges[key].min+'–'+attrRanges[key].max:(knownAttrs[key]??'?'));
  const currentStars=isManaged?Number(dev.world_current_stars??dev.current_star_rating??abilityStarValue(p.current_ability)):Number(scoutReport?.estimated_world_current_stars??scoutReport?.estimated_current_stars??publicLevelStars(p));
  const potentialStars=isManaged?Number(dev.world_potential_stars??dev.potential_star_rating??abilityStarValue(p.potential)):(scoutReport?.estimated_world_potential_stars!=null?Number(scoutReport.estimated_world_potential_stars):scoutReport?.estimated_potential_stars!=null?Number(scoutReport.estimated_potential_stars):null);
  const circuitCurrentStars=isManaged?Number(dev.circuit_current_stars??currentStars):Number(scoutReport?.estimated_circuit_current_stars??currentStars);
  const circuitPotentialStars=isManaged?Number(dev.circuit_potential_stars??potentialStars??currentStars):(scoutReport?.estimated_circuit_potential_stars!=null?Number(scoutReport.estimated_circuit_potential_stars):potentialStars);
  const starContext=String((isManaged?dev.star_context:scoutReport?.star_context)||dev.star_context||'Monde');
  const potentialMin=isManaged?Number(dev.potential_star_min??abilityStarValue(p.potential)):(scoutReport?.estimated_potential_star_min!=null?Number(scoutReport.estimated_potential_star_min):null);
  const potentialMax=isManaged?Number(dev.potential_star_max??abilityStarValue(p.potential)):(scoutReport?.estimated_potential_star_max!=null?Number(scoutReport.estimated_potential_star_max):null);
  const developmentContextText=typeof dev.development_context==='string'?dev.development_context:'';
  const computedPhase=Number(p.age||24)>Number(dev.decline_start_age||30)?'decline':Number(p.current_ability||0)>=Number(p.potential||0)-2?'plateau':Number(p.age||24)<=21&&Number(p.potential||0)-Number(p.current_ability||0)>=12?'prospect':Number(p.age||24)<Number(dev.peak_age||25)?'developing':'prime';
  const devPhase=String(dev.development_phase||computedPhase);
  const devPhaseLabels={prospect:'Espoir',developing:'En développement',maturing:'Maturation',prime:'Pic / prime',plateau:'Plateau',decline:'Déclin'};
  const potentialMargin=isManaged?Math.max(0,Number(p.potential||0)-Number(p.current_ability||0)):null;
  const potentialFloor=isManaged?Math.max(Number(p.current_ability||0),Number(dev.potential_floor??p.current_ability??0)):null;
  const potentialCeiling=isManaged?Math.max(Number(p.potential||0),Number(dev.potential_ceiling??p.potential??0)):null;
  const potentialMomentum=isManaged?Number(dev.potential_momentum||0):null;
  const traitDev=isManaged?dev:{development_type:String(scoutReport?.development_type_read||'').includes('late')?'late':String(scoutReport?.development_type_read||'').includes('early')?'early':''};
  const playerTraits=playerTraitBadges(knownAttrs,traitDev,String(p.career_focus||'mixed'),scoutReport);
  const visibleTacticalProfile=isManaged?tacticalProfile:estimatedTacticalProfileFromScouting(knownAttrs,scoutReport);
  const visibleTacticalTraits=isManaged?tacticalTraits:estimatedTacticalTraitsFromScouting(knownAttrs,visibleTacticalProfile);
  const hiddenTraitChanges=hiddenTraitHistory.filter(x=>
    Number(x.old_important_matches)!==Number(x.new_important_matches)
    ||Number(x.old_pressure)!==Number(x.new_pressure)
    ||Number(x.old_consistency)!==Number(x.new_consistency)
    ||Number(x.old_resilience)!==Number(x.new_resilience)
  );
  const hiddenTraitCard=isManaged?`<div class="card" style="margin-top:12px">
    <div class="row between"><div><div class="eyebrow">Expérience compétitive</div><h2>Apprentissage des grands matchs</h2></div><span class="badge">${hiddenTraitChanges.length} évolution${hiddenTraitChanges.length>1?'s':''}</span></div>
    <div class="muted mini" style="margin-top:5px">Ces attributs cachés ne progressent pas à l'entraînement classique. Ils apprennent surtout des finales et des grands rendez-vous réellement joués dans la sauvegarde.</div>
    ${hiddenTraitChanges.length?hiddenTraitChanges.slice(0,10).map(x=>{
      const changes=[];
      if(Number(x.old_important_matches)!==Number(x.new_important_matches))changes.push('Grands matchs '+x.old_important_matches+'→'+x.new_important_matches);
      if(Number(x.old_pressure)!==Number(x.new_pressure))changes.push('Pression '+x.old_pressure+'→'+x.new_pressure);
      if(Number(x.old_consistency)!==Number(x.new_consistency))changes.push('Régularité '+x.old_consistency+'→'+x.new_consistency);
      if(Number(x.old_resilience)!==Number(x.new_resilience))changes.push('Résilience '+x.old_resilience+'→'+x.new_resilience);
      return `<div class="list-item"><div class="row between"><div><b>${esc(x.tournament_name)}</b><div class="muted micro">${df(x.event_date)} · ${esc(x.level||x.event_type||'Tournoi')} · ${esc(x.result||'')}</div></div><span class="badge">${changes.length} changement${changes.length>1?'s':''}</span></div><div class="row" style="gap:5px;flex-wrap:wrap;margin-top:6px">${changes.map(c=>`<span class="badge good">${esc(c)}</span>`).join('')}</div><div class="muted micro" style="margin-top:5px">${esc(x.reason||'Expérience compétitive')}</div></div>`;
    }).join(''):`<div class="empty">Pas encore d'évolution cachée issue d'un grand match dans cette sauvegarde.</div>`}
  </div>`:'';
  const ncaa=p.ncaa_current?(ncaaRows.find(x=>String(x.status||'')==='Active')||null):null;
  const ncaaRankInfo=ncaaRankPresentation(p,ncaa);
  const ncaaIsAlumni=String(p.ncaa_status||'')==='Alumni'||String(ncaaCareer?.status||'')==='Alumni';
  const ncaaHistorical=!p.ncaa_current&&!!p.ncaa_verified&&!ncaaIsAlumni;
  const allTitles=d.titles||[];
  const hasCanonicalSingles=allTitles.some(t=>t.origin==='sackmann_atp_canonical'&&t.event_type==='singles');
  const singlesTitles=allTitles.filter(t=>(!t.event_type||t.event_type==='singles')&&(!hasCanonicalSingles||t.origin==='sackmann_atp_canonical'||t.origin==='game'));
  const doublesTitles=allTitles.filter(t=>t.event_type==='doubles');
  const juniorSinglesTitles=allTitles.filter(t=>t.event_type==='junior_singles');
  const juniorDoublesTitles=allTitles.filter(t=>t.event_type==='junior_doubles');
  const collegeTitles=allTitles.filter(t=>/^ncaa_|^college_/.test(String(t.event_type||'')));
  const titleCount=hasCanonicalSingles?singlesTitles.length:(legend?.titles??singlesTitles.length);
  const slamCount=legend?.grand_slams??singlesTitles.filter(t=>/Grand Chelem|Grand Slam/i.test(String(t.level||''))).length;
  const mastersCount=legend?.masters??singlesTitles.filter(t=>/Masters 1000|Masters/i.test(String(t.level||''))).length;
  const hardTitles=singlesTitles.filter(t=>/Hard|Dur/i.test(String(t.surface||''))).length;
  const clayTitles=singlesTitles.filter(t=>/Clay|Terre/i.test(String(t.surface||''))).length;
  const grassTitles=singlesTitles.filter(t=>/Grass|Gazon/i.test(String(t.surface||''))).length;
  const cs=d.careerStats||{};
  const titleYears=Object.entries((d.titles||[]).reduce((acc,t)=>{
    const y=String(t.title_date||'').slice(0,4)||'—';
    acc[y]=(acc[y]||0)+1;return acc;
  },{})).sort((a,b)=>Number(b[0])-Number(a[0]));
  const levelCounts=(d.titles||[]).reduce((acc,t)=>{
    const raw=String(t.level||'ATP');
    const key=/Grand Chelem|Grand Slam/i.test(raw)?'Grand Chelem':/Masters 1000|Masters/i.test(raw)?'Masters 1000':/Finals/i.test(raw)?'ATP Finals':/Challenger/i.test(raw)?'Challenger':/Davis/i.test(raw)?'Coupe Davis':'ATP Tour';
    acc[key]=(acc[key]||0)+1;return acc;
  },{});
  const historicalSeasonRows=d.historicalSeasons||[];
  const weightedSeason=x=>Number(x?.grand_slams||0)*100+Number(x?.masters||0)*35+Number(x?.tour_finals||0)*30+Number(x?.titles||0)*5;
  const bestHistoricalSeason=historicalSeasonRows.length
    ?historicalSeasonRows.filter(x=>Number(x.season)<=2025).sort((a,b)=>weightedSeason(b)-weightedSeason(a)||Number(b.season)-Number(a.season))[0]||null
    :null;
  const bestSeason=bestHistoricalSeason
    ?[String(bestHistoricalSeason.season),Number(bestHistoricalSeason.titles||0)]
    :(titleYears.length?titleYears.reduce((best,x)=>Number(x[1])>Number(best[1])?x:best,titleYears[0]):null);
  const personalityLabel=String(p.personality||'Profil à découvrir');
  const personalityText=String(p.personality_description||'La personnalité de jeu sera affinée avec le scouting et l’évolution de carrière.');
  const personalityKind=String(p.personality_kind||'simulated');
  const personalitySource=String(p.personality_source||'Court Boss · profil de jeu simulé');
  const finalRows=d.finals||[];
  const runnerUpCount=finalRows.filter(x=>x.result==='Finaliste').length;
  const finalsWon=finalRows.filter(x=>x.result==='Champion').length;
  const finalConversion=finalRows.length?Math.round(finalsWon/finalRows.length*100):0;
  const firstTitle=(d.titles||[]).length?(d.titles||[])[(d.titles||[]).length-1]:null;
  const lastTitle=(d.titles||[])[0]||null;
  const realMatches=Number(cs.wins||0)+Number(cs.losses||0);
  const realWinPct=realMatches?Math.round(Number(cs.wins||0)/realMatches*100):0;
  const pct=(w,l)=>Number(w||0)+Number(l||0)?Math.round(Number(w||0)/(Number(w||0)+Number(l||0))*100):0;
  const surfacePct=(w,l)=>w==null||l==null?'Non renseigné':pct(w,l)+'%';
  const groups=[
   ['Service',[['Puissance service','serve_power'],['Effet service','serve_spin'],['Régularité service','serve_consistency'],['Précision','serve_precision'],['1re balle','first_serve_quality'],['2e balle','second_serve_quality'],['Variété','serve_variety']]],
   ['Fond de court',[['Coup droit','forehand'],['Puissance CD','forehand_power'],['Régularité CD','forehand_consistency'],['Précision CD','forehand_accuracy'],['Revers','backhand'],['Puissance RV','backhand_power'],['Régularité RV','backhand_consistency'],['Précision RV','backhand_accuracy'],['Lift','topspin'],['Coupé / slice','slice']]],
   ['Contrôle & retour',[['Retour','return_game'],['Contre','counter_skill'],['Retour agressif','return_aggression'],['Régularité retour','return_consistency'],['Contrôle','shot_control'],['Timing','timing'],['Passing-shot','passing_shot'],['Réaction','reaction'],['Toucher','touch'],['Amortie','drop_shot'],['Lob','lob']]],
   ['Jeu au filet',[['Volée','volley'],['Demi-volée','half_volley'],['Smash','smash'],['Placement filet','net_positioning'],['Poaching','poaching']]],
   ['Physique',[['Déplacements','movement'],['Jeu de jambes','footwork'],['Capacités physiques','athleticism'],['Vitesse','speed'],['Accélération','acceleration'],['Agilité','agility'],['Équilibre','balance'],['Endurance','stamina'],['Force','strength'],['Défense','defensive_skill'],['Tolérance rallye','rally_tolerance'],['Fitness naturel','natural_fitness'],['Récupération','recovery'],['Souplesse','flexibility']]],
   ['Mental',[['Anticipation','anticipation'],['Concentration','concentration'],['Sens tactique','tactics'],['Sang-froid','composure'],['Instinct de tueur','killer_instinct'],['Ténacité','tenacity'],['Combativité','fighting_spirit'],['Détermination','determination'],['Confiance','confidence'],['Grands points','big_points'],['Régularité globale','consistency'],['Volume de travail','work_rate']]],
   ['Décision & identité',[['Décisions','decision_making'],['Sélection de coups','shot_selection'],['Position court','court_positioning'],['Transition','transition_game'],['Défense → attaque','defense_to_attack'],['Service +1','serve_plus_one'],['Agressivité','aggression'],['Patience','patience'],['Adaptabilité','adaptability'],['Leadership','leadership']]],
   ['Double & surfaces',[['Aptitude double','doubles'],['Communication','doubles_communication'],['Terre battue','clay_affinity'],['Dur','hard_affinity'],['Gazon','grass_affinity']]]
  ];
  const nat=countryTheme(p.country);
  const races=d.races||{};
  const rankBits=[];
  if(p.ranking_current&&p.ranking!=null)rankBits.push('ATP #'+fmt(p.ranking));
  if(p.doubles_ranking!=null&&p.doubles_source)rankBits.push('Double #'+fmt(p.doubles_ranking)+(p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''));
  if(p.race_ranking!=null&&p.race_source)rankBits.push('Race #'+fmt(p.race_ranking)+(p.race_snapshot_date?' · '+df(p.race_snapshot_date):''));
  if(p.nextgen_ranking!=null&&p.nextgen_source)rankBits.push('Next Gen #'+fmt(p.nextgen_ranking)+(p.nextgen_snapshot_date?' · '+df(p.nextgen_snapshot_date):''));
  if(p.junior_doubles_ranking!=null)rankBits.push('Junior Double #'+fmt(p.junior_doubles_ranking));
  if(races.junior?.rank!=null)rankBits.push('Race Junior #'+fmt(races.junior.rank)+(races.junior.status==='qualified'?' · Qualifié Finals':''));
  if(races.doubles?.rank!=null)rankBits.push('Race Double #'+fmt(races.doubles.rank)+(races.doubles.status==='qualified'?' · Qualifié Finals':''));
  if(races.juniorDoubles?.rank!=null)rankBits.push('Race Junior Double #'+fmt(races.juniorDoubles.rank)+(races.juniorDoubles.status==='qualified'?' · Qualifié Finals':''));
  if(p.junior_ranking!=null){const jx=p.junior_rank_type==='official'&&p.junior_official_ranking!=null?' · ITF officiel #'+fmt(p.junior_official_ranking):p.junior_rank_type==='verified_nr'?' · rang estimé':p.game_generated?' · simulé':'';rankBits.push('Junior #'+fmt(p.junior_ranking)+jx);}
  if(p.ncaa_current)rankBits.push('NCAA actif · '+ncaaRankInfo.label+(ncaa?.utr_rating!=null?' · UTR '+(ncaa.utr_verified?'':'~')+Number(ncaa.utr_rating).toFixed(2):'')+(ncaa?.school?' · '+ncaa.school:p.ncaa_school?' · '+p.ncaa_school:''));
  else if(ncaaIsAlumni)rankBits.push('NCAA Alumni'+((ncaaCareer?.verified||p.ncaa_verified)?' certifié':'')+' · '+(ncaaCareer?.school||p.ncaa_last_school||'Université'));
  else if(ncaaHistorical)rankBits.push((p.ncaa_status||'NCAA historique')+(p.ncaa_last_school?' · '+p.ncaa_last_school:''));
  const isRetired=String(p.career_status||'active')==='retired';
  const rankSummary=isRetired?'Retraité · historique carrière':(rankBits.length?rankBits.join(' · '):'Non classé actuellement');
  const matchupPct=x=>x?.player_a_probability!=null?Math.round(Number(x.player_a_probability)*100)+'%':'—';
  const surfaceAnalyticsPanel=(()=>{
    const sp=surfacePref||{};
    let h2hHtml='<div class="empty">Aucune rencontre enregistrée avec ton joueur.</div>';
    if(isManaged)h2hHtml='<div class="empty">Cette fiche est celle du joueur géré.</div>';
    else if(h2hManaged){
      const selfA=Number(p.id)===Number(h2hManaged.player_a_id);
      const w=selfA?Number(h2hManaged.a_wins||0):Number(h2hManaged.b_wins||0);
      const l=selfA?Number(h2hManaged.b_wins||0):Number(h2hManaged.a_wins||0);
      const hw=selfA?Number(h2hManaged.hard_a_wins||0):Number(h2hManaged.hard_b_wins||0);
      const hl=selfA?Number(h2hManaged.hard_b_wins||0):Number(h2hManaged.hard_a_wins||0);
      const cw=selfA?Number(h2hManaged.clay_a_wins||0):Number(h2hManaged.clay_b_wins||0);
      const cl=selfA?Number(h2hManaged.clay_b_wins||0):Number(h2hManaged.clay_a_wins||0);
      const gw=selfA?Number(h2hManaged.grass_a_wins||0):Number(h2hManaged.grass_b_wins||0);
      const gl=selfA?Number(h2hManaged.grass_b_wins||0):Number(h2hManaged.grass_a_wins||0);
      h2hHtml=`<div class="big">${w} - ${l}</div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:7px"><span class="badge">Dur ${hw}-${hl}</span><span class="badge clay">Terre ${cw}-${cl}</span><span class="badge grass">Gazon ${gw}-${gl}</span></div><div class="muted micro" style="margin-top:7px">Dernier duel : ${h2hManaged.last_match_date?df(h2hManaged.last_match_date):'—'} · ${esc(h2hManaged.source_label||'Court Boss H2H')}</div>`;
    }
    const learning=matchupPreviews.hard?.opponent_learning||null;
    const learningFamiliarity=Number(learning?.familiarity||0);
    const learningLabel=learning?.active?(learningFamiliarity>=17?'Très forte':learningFamiliarity>=11?'Installée':'En construction'):'Aucune';
    const learningBadge=learning?.active?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge good">Mémoire H2H · ${esc(learningLabel)}</span><span class="badge">${learning.matches||0} confrontation(s) apprises</span></div><div class="muted micro" style="margin-top:6px">Les joueurs et leur staff adaptent progressivement le plan de match aux habitudes observées. L’effet reste plafonné pour ne pas écraser le niveau réel.</div>`:'';
    const projection=isManaged?'':`<div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted micro">Chance sur dur</span><b>${matchupPct(matchupPreviews.hard)}</b></div><div class="kpi"><span class="muted micro">Sur terre</span><b>${matchupPct(matchupPreviews.clay)}</b></div><div class="kpi"><span class="muted micro">Sur gazon</span><b>${matchupPct(matchupPreviews.grass)}</b></div></div>${learningBadge}<div class="muted micro" style="margin-top:7px">Le H2H nuance le duel sans écraser Elo, forme, surface, service/retour, tactique, psychologie et adaptation à l’adversaire.</div>`;
    return `<div class="grid g2" style="margin-top:12px"><div class="card"><div class="row between"><div><div class="eyebrow">Surface de prédilection</div><h2>${esc(sp.preferred_surface||'À déterminer')}</h2></div><span class="badge">2e · ${esc(sp.secondary_surface||'—')}</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Dur</span><b>${sp.hard_score!=null?Number(sp.hard_score).toFixed(1):'—'}</b></div><div class="kpi"><span class="muted micro">Terre</span><b>${sp.clay_score!=null?Number(sp.clay_score).toFixed(1):'—'}</b></div><div class="kpi"><span class="muted micro">Gazon</span><b>${sp.grass_score!=null?Number(sp.grass_score).toFixed(1):'—'}</b></div><div class="kpi"><span class="muted micro">Indoor</span><b>${sp.indoor_score!=null?Number(sp.indoor_score).toFixed(1):'—'}</b></div></div><div class="list-item row between"><span>Vitesse de court préférée</span><b>${sp.preferred_court_speed!=null?Number(sp.preferred_court_speed).toFixed(3):'—'}</b></div><div class="list-item row between"><span>Tolérance vitesse</span><b>${sp.pace_tolerance!=null?Number(sp.pace_tolerance).toFixed(3):'—'}</b></div><div class="list-item row between"><span>Rallyes courts</span><b>${sp.short_rally_preference??'—'}/100</b></div><div class="list-item row between"><span>Rallyes longs</span><b>${sp.long_rally_preference??'—'}/100</b></div><div class="muted micro" style="margin-top:7px">Le moteur combine Elo de surface, qualités techniques, longueur des échanges et vitesse du court.</div></div><div class="card"><div class="row between"><div><div class="eyebrow">Match-up vs joueur géré</div><h2>H2H & projections</h2></div><span class="badge">${h2hManaged?fmt(Number(h2hManaged.real_matches||0)+Number(h2hManaged.simulated_matches||0))+' match(s)':'Aucun H2H'}</span></div>${h2hHtml}${projection}</div></div>`;
  })();
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier joueur ${isRetired?'· Légende':''}</div><h1>${flags[p.country]||'🏳️'} ${esc(p.name)} ${isRetired?'<span class="badge">Retraité</span>':''}</h1><div class="muted">${esc(rankSummary)}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="tabs" style="margin-top:12px"><button class="active" data-player-tab="profile" onclick="playerSection('profile')">Profil</button><button data-player-tab="attrs" onclick="playerSection('attrs')">Attributs</button><button data-player-tab="analytics" onclick="playerSection('analytics')">Analytics</button><button data-player-tab="stats" onclick="playerSection('stats')">Statistiques</button><button data-player-tab="development" onclick="playerSection('development')">Développement</button><button data-player-tab="matches" onclick="playerSection('matches')">Matchs</button><button data-player-tab="double" onclick="playerSection('double')">Double</button><button data-player-tab="career" onclick="playerSection('career')">Palmarès</button><button data-player-tab="commercial" onclick="playerSection('commercial')">Commercial</button><button data-player-tab="history" onclick="playerSection('history')">Historique</button></div>
   <div id="playerBody">
    <div class="card fm-player-header" style="margin-bottom:12px;border-left:5px solid ${nat.a};background:linear-gradient(125deg,${nat.a}24,${nat.b}18 46%,rgba(7,25,17,.96) 78%)"><div class="row" style="align-items:center;gap:16px"><div style="width:142px;height:166px;border-radius:18px;overflow:hidden;background:#10251c;display:flex;align-items:center;justify-content:center;flex:0 0 auto;border:2px solid ${nat.a};box-shadow:0 0 0 3px ${nat.b}40">${playerPhotoMarkup(p)}</div><div><div class="eyebrow">${flags[p.country]||'🏳️'} ${esc(p.country||'')} · ${p.is_real?'Identité réelle':'Joueur généré Court Boss'}</div><h2 style="margin:2px 0 5px">${esc(p.name)}</h2><div class="muted">${p.birth_date?'Né le '+df(p.birth_date)+' · '+ageLabel(p,true):p.age!=null?(ageLabel(p,true)+' · date de naissance non vérifiée'):'Âge non vérifié'}</div><div class="row" style="margin-top:8px;flex-wrap:wrap">${!isRetired?`<span class="badge ${String(p.career_focus||'mixed')==='doubles_only'?'good':''}">${careerFocusLabel(p.career_focus||'mixed')}</span>`:''}${playerPhotoSourceLabel(p)?`<span class="badge">${esc(playerPhotoSourceLabel(p))}</span>`:''}${ncaa?`<span class="badge good">NCAA actif · ${esc(ncaa.school||p.ncaa_school||'Université')} · ${esc(ncaaRankInfo.label)}</span>`:ncaaIsAlumni?`<span class="badge">NCAA Alumni${ncaaCareer?.verified||p.ncaa_verified?' certifié':''} · ${esc(ncaaCareer?.school||p.ncaa_last_school||'Université')}</span>`:ncaaHistorical?`<span class="badge">NCAA historique · ${esc(p.ncaa_last_school||ncaaCareer?.school||'Université')} · statut actuel non vérifié</span>`:''}${Array.isArray(p.circuits_2025)&&p.circuits_2025.map(c=>`<span class="badge">${esc(c)}</span>`).join('')}</div></div></div></div>
    <div class="grid g2"><div class="card"><h2>Profil</h2><div class="statline"><div class="statbox"><span class="muted mini">Âge au 01/12/2025</span><b>${esc(ageLabel(p,false))}</b><small class="muted micro">${/estim/i.test(String(p.age_source||''))?'estimé':'sourcé'}</small></div><div class="statbox"><span class="muted mini">Taille</span><b>${p.height_cm?p.height_cm+' cm':'—'}</b><small class="muted micro">${p.height_cm?(p.height_verified?'sourcée':'estimée'):''}</small></div><div class="statbox"><span class="muted mini">Main</span><b style="font-size:15px">${esc(p.handedness||'—')}</b></div><div class="statbox"><span class="muted mini">Revers</span><b style="font-size:15px">${esc(p.backhand||'2 mains')}</b><small class="muted micro">${p.backhand_verified?'sourcé':'estimé'}</small></div><div class="statbox"><span class="muted mini">Style</span><b style="font-size:15px">${esc(p.style||'—')}</b></div></div><div class="muted micro" style="margin-top:8px">Revers : ${esc(p.backhand_source||'Estimation Court Boss · non sourcée')}${p.birth_date_source?' · DOB : '+esc(p.birth_date_source):''}${p.age_source?' · Âge : '+esc(p.age_source):''}${p.height_source?' · Taille : '+esc(p.height_source):''}${p.weight_source?' · Poids : '+esc(p.weight_source):''}</div>
<div class="player-bio-grid" style="margin-top:10px">
 ${p.weight_kg?`<div class="list-item row between"><span>Poids</span><span><b>${p.weight_kg} kg</b> <span class="muted micro">${p.weight_verified?'sourcé':'estimé'}</span></span></div>`:''}
 ${p.birthplace?`<div class="list-item row between"><span>Lieu de naissance</span><b>${esc(p.birthplace)}</b></div>`:''}
 ${p.turned_pro_year?`<div class="list-item row between"><span>Passage pro</span><b>${p.turned_pro_year}</b></div>`:''}
 ${p.coaches&&!playerStaff.length?`<div class="list-item row between"><span>Coach(s)</span><b>${esc(p.coaches)}</b></div>`:''}
</div>
${!isRetired?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Orientation de carrière</div><h3 style="margin:2px 0">${careerFocusLabel(p.career_focus||'mixed')}</h3></div><span class="badge ${String(p.career_focus||'mixed')==='doubles_only'?'good':''}">${p.career_focus_source==='Utilisateur'?'Choix joueur':'Simulation Court Boss'}</span></div>
 <div class="muted mini">${esc(p.career_focus_reason||careerFocusDescription(p.career_focus||'mixed'))}</div>
 ${careerFocusHistory.length?`<div style="margin-top:8px">${careerFocusHistory.slice(0,5).map(x=>`<div class="list-item row between"><div><b>${careerFocusLabel(x.to_focus)}</b><div class="muted micro">${esc(x.reason||'Changement de trajectoire')}</div></div><div style="text-align:right"><span class="badge">${df(x.changed_at)}</span><div class="muted micro">${esc(x.source||'Court Boss')}</div></div></div>`).join('')}</div>`:''}
</div>`:''}
${agencyRepresentation?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Représentation</div><h3 style="margin:2px 0">Agent & agence</h3></div><span class="badge">Confiance ${agencyRepresentation.trust??'—'}/100</span></div>
 <div class="list-item"><div class="row between"><div><b>${esc(agencyRepresentation.agency?.name||'Agence')}</b><div class="muted mini">Commission ${agencyRepresentation.commission_pct??'—'}% · depuis ${df(agencyRepresentation.start_date)}</div></div><div style="text-align:right"><b class="click" onclick="openStaffProfile(${agencyRepresentation.agent?.id})">${esc(agencyRepresentation.agent?.name||'Agent')}</b><div class="muted micro">Négociation ${agencyRepresentation.agent?.negotiation_rating??'—'}/20 · rep ${agencyRepresentation.agent?.reputation??'—'}/20</div></div></div></div>
 ${agencyHistory.length?`<div class="muted micro" style="margin:6px 0">Historique de représentation</div>${agencyHistory.slice(0,4).map(x=>`<div class="list-item row between"><div><b>${esc(x.agency?.name||'Agence')}</b><div class="muted micro">${df(x.start_date)} → ${df(x.end_date)} · ${esc(x.ended_reason||'Changement')}</div></div><span class="badge">${esc(x.agent?.name||'Agent')}</span></div>`).join('')}`:''}
 </div>`:''}
${playerStaff.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Entourage professionnel</div><h3 style="margin:2px 0">Staff du joueur</h3></div><span class="badge">${playerStaff.length} membre(s)</span></div>
 <div class="stack" style="margin-top:8px">${playerStaff.map(x=>{const sp=x.staff||{};return `<div class="list-item"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)} · ${esc(sp.specialty||sp.primary_role||'')}</div></div><div style="text-align:right"><span class="badge ${x.verified?'good':''}">${x.verified?'Sourcé':'Base Court Boss'}</span><div class="muted micro">${esc(staffFormerLabel(sp))}</div></div></div><div class="row" style="margin-top:6px;gap:6px;flex-wrap:wrap"><span class="badge">Affinité ${x.affinity??'—'}/100</span><span class="badge">Confiance ${x.trust??'—'}/100</span><span class="badge">Fit ${x.role_fit??'—'}/100</span><span class="badge">Satisfaction ${x.satisfaction??'—'}/100</span><span class="badge">Cohésion ${x.team_chemistry??'—'}/100</span><span class="badge">Coach ${sp.coach_rating??'—'}/20</span><span class="badge">Tech ${sp.technical_rating??'—'}/20</span><span class="badge">Tact ${sp.tactical_rating??'—'}/20</span><span class="badge">Mental ${sp.mental_rating??'—'}/20</span><span class="badge">Physique ${sp.fitness_rating??'—'}/20</span><span class="badge">Médical ${sp.medical_rating??'—'}/20</span></div>${sp.former_player_id?`<button class="ghost" style="margin-top:6px" onclick="openPlayer(${sp.former_player_id})">Voir sa carrière de joueur</button>`:''}<div class="muted micro" style="margin-top:5px">${esc(x.source_label||sp.source_label||'Court Boss')}</div></div>`}).join('')}</div>
 </div>`:''}
${playerStaffHistory.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Historique staff</div><h3 style="margin:2px 0">Anciens membres de l'équipe</h3></div><span class="badge">${playerStaffHistory.length}</span></div>
 <div class="stack" style="margin-top:8px">${playerStaffHistory.slice(0,8).map(x=>{const sp=x.staff||{};return `<div class="list-item"><div class="row between"><div><b>${esc(sp.name||x.role)}</b><div class="muted mini">${esc(x.role)} · ${df(x.start_date)} → ${df(x.end_date)}</div></div><span class="badge">${esc(x.ended_reason||'Fin de collaboration')}</span></div><div class="muted micro" style="margin-top:4px">Affinité finale ${fmt(x.affinity||0)}/100 · Confiance ${fmt(x.trust||0)}/100</div></div>`}).join('')}</div>
 </div>`:''}
${playerStaffBonds.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Relations staff persistantes</div><h3 style="margin:2px 0">Coachs favoris & liens de carrière</h3></div><span class="badge">FM · ${playerStaffBonds.length}</span></div>
 <div class="muted micro" style="margin:4px 0 8px">Ces liens sont des mécaniques de simulation Court Boss sauf mention sourcée. Ils peuvent influencer une future réunion ou négociation.</div>
 <div class="stack">${playerStaffBonds.slice(0,12).map(x=>{const sp=x.staff||{};return `<div class="list-item click" onclick="openStaffProfile(${sp.id})"><div class="row between"><div><b>${flags[sp.nationality]||'🏳️'} ${esc(sp.name||'Staff')}</b><div class="muted mini">${esc(sp.primary_role||'Staff')} · ${esc(x.bond_type||'Relation professionnelle')}</div></div><span class="badge ${x.bond_type==='Joueur favori'?'good':x.bond_type==='Relation difficile'?'bad':''}">${x.affinity}/100</span></div><div class="row between muted micro"><span>Confiance ${x.trust}</span><span>Respect ${x.respect}</span><span>${x.is_simulated?'Simulation':'Sourcé'}</span></div></div>`}).join('')}</div>
 </div>`:''}
${mentor||mentees.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Développement social</div><h3 style="margin:2px 0">Mentorat</h3></div><span class="badge">Simulation carrière</span></div>
 ${mentor?`<div class="list-item click" onclick="openPlayer(${mentor.player?.id})"><div class="row between"><div><b>${flags[mentor.player?.country]||'🏳️'} ${esc(mentor.player?.name||'Mentor')}</b><div class="muted mini">${esc(mentor.focus||'Développement')} · depuis ${df(mentor.start_date)}</div></div><span class="badge good">${mentor.compatibility}/100</span></div><div class="row between muted micro" style="margin-top:5px"><span>Influence ${mentor.influence}/100</span><span>${esc(mentor.reason||'Mentorat')}</span></div></div>`:''}
 ${mentees.length?`<div class="muted micro" style="margin:8px 0 5px">Joueurs accompagnés</div>${mentees.slice(0,6).map(x=>`<div class="list-item row between click" onclick="openPlayer(${x.player?.id})"><div><b>${flags[x.player?.country]||'🏳️'} ${esc(x.player?.name||'Joueur')}</b><div class="muted micro">${esc(x.focus||'Développement')}</div></div><span class="badge">${x.compatibility}/100</span></div>`).join('')}`:''}
 ${isManaged&&mentorshipEvents.length?`<div class="muted micro" style="margin:8px 0 5px">Transmission récente</div>${mentorshipEvents.slice(0,6).map(x=>`<div class="list-item row between"><div><b>${esc(String(x.trait_code||'trait').replaceAll('_',' '))}</b><div class="muted micro">${df(x.event_date)}</div></div><span class="badge good">${x.old_value} → ${x.new_value}</span></div>`).join('')}`:''}
 <div class="muted micro" style="margin-top:7px">Mécanique Court Boss. Elle représente la transmission d’habitudes de travail et d’expérience, pas une relation privée réelle.</div>
</div>`:''}
${relationships.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Relations FM</div><h3 style="margin:2px 0">Affinités & proches</h3></div><span class="badge">Évolutif</span></div>
 <div class="muted micro" style="margin:4px 0 8px">Les relations marquées Simulation sont des mécaniques de jeu Court Boss, pas des affirmations sur la vie privée réelle des joueurs.</div>
 <div class="stack">${relationships.map(r=>{const o=r.other||{};return `<div class="list-item click" onclick="openPlayer(${o.id})"><div class="row between"><div><b>${flags[o.country]||'🏳️'} ${esc(o.name||'Joueur')}</b><div class="muted mini">${esc(r.relation_type||'Affinité sportive')} · ATP ${o.ranking?'#'+fmt(o.ranking):'NR'}</div></div><div style="text-align:right"><b>${fmt(r.affinity||0)}/100</b><div class="muted micro">${r.is_simulated?'Simulation':'Sourcé'}</div></div></div><div class="bar" style="margin-top:6px"><i style="width:${Number(r.affinity||0)}%"></i></div><div class="row between muted micro" style="margin-top:4px"><span>Confiance ${fmt(r.trust||0)}</span><span>Respect ${fmt(r.respect||0)}</span><span>Proximité ${fmt(r.closeness||0)}</span></div></div>`}).join('')}</div>
 </div>`:''}
${playerTraits.length?`<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Traits de jeu</div><h3 style="margin:2px 0">Tendances FM/TM</h3></div><span class="badge">${playerKnowledgeLabel(isManaged,scoutReport)}</span></div>
 <div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${playerTraits.map(t=>`<span class="badge ${t.kind||''}">${esc(t.label)}</span>`).join('')}</div>
 <div class="muted micro" style="margin-top:7px">${isManaged?'Traits dérivés du profil complet et susceptibles d’évoluer avec les attributs.':'Traits estimés à partir du rapport de scouting disponible.'}</div>
</div>`:''}
<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div class="eyebrow">Classements du joueur</div><span class="badge">${p.career_high_rank?'Pic carrière #'+fmt(p.career_high_rank):'Historique'}</span></div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">ATP actuel</span><b>${p.ranking_current&&p.ranking!=null?'#'+fmt(p.ranking):'NR'}</b></div>
  <div class="kpi"><span class="muted mini">Meilleur simple</span><b>${p.career_high_rank?'#'+fmt(p.career_high_rank):'—'}</b><small class="muted micro">${p.career_high_rank_date?df(p.career_high_rank_date):''}</small></div>
  <div class="kpi"><span class="muted mini">Double actuel</span><b>${p.doubles_ranking!=null?'#'+fmt(p.doubles_ranking):'NR'}</b></div>
  <div class="kpi"><span class="muted mini">Meilleur double</span><b>${p.career_high_doubles_rank?'#'+fmt(p.career_high_doubles_rank):'—'}</b><small class="muted micro">${p.career_high_doubles_rank_date?df(p.career_high_doubles_rank_date):p.career_high_doubles_source?'meilleur connu':''}</small></div>
 </div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">Meilleure saison</span><b>${p.best_season_year||bestHistoricalSeason?.season||'—'}</b><small class="muted micro">${p.best_season_summary?esc(p.best_season_summary):bestHistoricalSeason?fmt(bestHistoricalSeason.titles||0)+' titres · '+fmt(bestHistoricalSeason.grand_slams||0)+' GC':''}</small></div>
  <div class="kpi"><span class="muted mini">Semaines n°1</span><b>${fmt(p.weeks_at_no1||0)}</b></div>
  <div class="kpi"><span class="muted mini">Junior</span><b>${p.junior_ranking!=null?'#'+fmt(p.junior_ranking):'—'}</b><small class="muted micro">${p.junior_rank_type==='official'&&p.junior_official_ranking!=null?'ITF officiel #'+fmt(p.junior_official_ranking):p.junior_rank_type==='verified_nr'?'ITF NR':p.game_generated&&p.junior_ranking!=null?'simulé':''}</small></div>
  <div class="kpi"><span class="muted mini">NCAA / ITA</span><b>${esc(ncaaRankInfo.value)}</b><small class="muted micro">${esc(ncaaRankInfo.source)}${ncaa?.utr_rating!=null?' · UTR '+(ncaa.utr_verified?'':'~')+Number(ncaa.utr_rating).toFixed(2):''}${(ncaa?.school||p.ncaa_school)?' · '+esc(ncaa?.school||p.ncaa_school||''):''}</small></div>
 </div>
 <div class="kpi-strip" style="margin-top:8px">
  <div class="kpi"><span class="muted mini">Race Junior</span><b>${races.junior?.rank!=null?'#'+fmt(races.junior.rank):'—'}</b><small class="muted micro">${races.junior?.points!=null?fmt(races.junior.points)+' pts · ':''}${races.junior?.status==='qualified'?'Qualifié Finals':races.junior?.status==='alternate'?'Remplaçant':races.junior?.rank!=null?'En course':''}</small></div>
  <div class="kpi"><span class="muted mini">Race Double</span><b>${races.doubles?.rank!=null?'#'+fmt(races.doubles.rank):'—'}</b><small class="muted micro">${races.doubles?.points!=null?fmt(races.doubles.points)+' pts · ':''}${races.doubles?.status==='qualified'?'Qualifié Finals':races.doubles?.status==='alternate'?'Remplaçant':races.doubles?.rank!=null?'En course':''}${races.doubles?.team?' · '+esc(races.doubles.team):''}</small></div>
  <div class="kpi"><span class="muted mini">Race Junior Double</span><b>${races.juniorDoubles?.rank!=null?'#'+fmt(races.juniorDoubles.rank):'—'}</b><small class="muted micro">${races.juniorDoubles?.points!=null?fmt(races.juniorDoubles.points)+' pts · ':''}${races.juniorDoubles?.status==='qualified'?'Qualifié Finals':races.juniorDoubles?.status==='alternate'?'Remplaçant':races.juniorDoubles?.rank!=null?'En course':''}${races.juniorDoubles?.team?' · '+esc(races.juniorDoubles.team):''}</small></div>
  <div class="kpi"><span class="muted mini">Statut Finals</span><b>${[races.junior,races.doubles,races.juniorDoubles].some(x=>x?.status==='qualified')?'Qualifié':[races.junior,races.doubles,races.juniorDoubles].some(x=>x?.status==='alternate')?'Remplaçant':'—'}</b></div>
 </div>
</div>
<div class="card" style="margin-top:10px;padding:12px">
 <div class="row between"><div><div class="eyebrow">Personnalité FM</div><h3 style="margin:2px 0 4px">${esc(personalityLabel)}</h3></div><span class="badge ${personalityKind==='curated'?'good':''}">${personalityKind==='curated'?'Profil éditorial':'Simulation'}</span></div>
 <div class="muted" style="line-height:1.45">${esc(personalityText)}</div>
 <div class="muted micro" style="margin-top:7px">${esc(personalitySource)}</div>
</div>
${p.bio_source?`<div class="muted micro" style="margin-top:6px">Bio : ${esc(p.bio_source)}${p.bio_verified?' · sourcée':''}</div>`:''}${Array.isArray(p.circuits_2025)&&p.circuits_2025.length?`<div class="row" style="margin-top:10px;flex-wrap:wrap">${p.circuits_2025.map(c=>`<span class="badge">${esc(c)} 2025</span>`).join('')}</div>`:''}${ncaa?`<div class="list-item row between"><span>NCAA / ITA · UTR</span><b>${esc(ncaaRankInfo.label)} · UTR ${ncaa.utr_rating!=null?(ncaa.utr_verified?'':'~')+Number(ncaa.utr_rating).toFixed(2):'—'} · ${esc(ncaa.school||p.ncaa_school||'Université')}</b></div>`:ncaaIsAlumni?`<div class="list-item row between"><span>Carrière NCAA</span><b>${esc(ncaaCareer?.school||p.ncaa_last_school||'Université')} · Alumni${ncaaCareer?.verified||p.ncaa_verified?' · certifié':''}</b></div>`:ncaaHistorical?`<div class="list-item row between"><span>NCAA historique</span><b>${esc(p.ncaa_last_school||ncaaCareer?.school||'Université')} · ${esc(p.ncaa_status||'Roster historique')}</b></div>`:''}</div><div class="card"><div class="row between"><div><div class="eyebrow">Évaluation FM/TM</div><h2>Niveau & potentiel</h2></div><span class="badge">${playerKnowledgeLabel(isManaged,scoutReport)}</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Monde actuel</span><b>${starRatingHtml(currentStars,'Niveau mondial actuel')}</b><small class="muted micro">${isManaged?'CA '+p.current_ability+'/100':scoutReport?'CA estimée '+scoutReport.estimated_ca_min+'–'+scoutReport.estimated_ca_max:'Estimation publique'}</small></div><div class="kpi"><span class="muted mini">Monde potentiel</span><b>${potentialStars!=null?starRatingHtml(potentialStars,'Potentiel mondial'):'☆☆☆☆☆ ?'}</b><small class="muted micro">${isManaged?'PA '+p.potential+'/100 · dynamique':scoutReport?'PA estimé '+scoutReport.estimated_pa_min+'–'+scoutReport.estimated_pa_max:'À scouter'}</small></div><div class="kpi"><span class="muted mini">${esc(starContext)} actuel</span><b>${starRatingHtml(circuitCurrentStars,'Niveau relatif au circuit')}</b><small class="muted micro">Évaluation relative</small></div><div class="kpi"><span class="muted mini">${esc(starContext)} potentiel</span><b>${circuitPotentialStars!=null?starRatingHtml(circuitPotentialStars,'Potentiel relatif au circuit'):'☆☆☆☆☆ ?'}</b><small class="muted micro">Contexte ${esc(starContext)}</small></div></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:9px"><span class="badge">${isManaged?developmentTypeLabel(dev.development_type||'standard'):scoutReport?esc(scoutReport.development_type_read||'Courbe ?'):'Courbe ?'}</span><span class="badge">Fourchette PA ${potentialMin!=null?potentialMin.toFixed(1):'?'}–${potentialMax!=null?potentialMax.toFixed(1):'?'} ★</span><span class="badge">Confiance ${isManaged?100:scoutReport?.confidence??Math.min(45,p.scouting_confidence??35)}%</span></div></div></div><div class="card"><h2>Données historiques</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Titres simple</span><b>${titleCount}</b></div><div class="kpi"><span class="muted mini">Titres double</span><b>${doublesTitles.length}</b></div><div class="kpi"><span class="muted mini">NCAA / College</span><b>${collegeTitles.length}</b></div><div class="kpi"><span class="muted mini">Grand Chelem</span><b>${slamCount}</b></div></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${hardTitles}</span><span class="badge clay">Terre ${clayTitles}</span><span class="badge grass">Gazon ${grassTitles}</span></div></div></div>
    <div class="grid g2" style="margin-top:12px"><div class="card"><h2>Bilan historique</h2>${realMatches?`<div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${fmt(realMatches)}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${fmt(cs.wins||0)}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${fmt(cs.losses||0)}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${realWinPct}%</b></div></div><div class="list-item row between"><span>Dur</span><b>${cs.hard_wins==null||cs.hard_losses==null?'Non renseigné':cs.hard_wins+'-'+cs.hard_losses+' · '+surfacePct(cs.hard_wins,cs.hard_losses)}</b></div><div class="list-item row between"><span>Terre battue</span><b>${cs.clay_wins==null||cs.clay_losses==null?'Non renseigné':cs.clay_wins+'-'+cs.clay_losses+' · '+surfacePct(cs.clay_wins,cs.clay_losses)}</b></div><div class="list-item row between"><span>Gazon</span><b>${cs.grass_wins==null||cs.grass_losses==null?'Non renseigné':cs.grass_wins+'-'+cs.grass_losses+' · '+surfacePct(cs.grass_wins,cs.grass_losses)}</b></div><div class="muted mini" style="margin-top:8px">Source : ${esc(cs.source||'Archives de matchs')} · relevé du ${cs.source_snapshot?df(cs.source_snapshot):'—'}${String(cs.source||'').startsWith('https://')?' · <a href="'+esc(cs.source)+'" target="_blank" rel="noopener noreferrer">Consulter la source</a>':' · Agrégat importé, périmètre non certifié ATP'}</div>`:'<div class="empty">Historique match réel non disponible pour ce joueur.</div>'}</div><div class="card"><h2>Scouting</h2><div class="notice">Les notes 1–20 sont des évaluations de jeu, pas des statistiques officielles ATP.</div><p class="muted mini" style="margin-top:10px">Confiance : ${p.scouting_confidence}% · Source : ${esc(p.data_source||'Court Boss')} ${p.data_snapshot?'· snapshot '+df(p.data_snapshot):''}</p><div class="row" style="margin-top:10px;flex-wrap:wrap"><button class="soft-btn" onclick="toggleShortlist(${p.id})">${(d.shortlist||(local.shortlist||[]).includes(p.id))?'Retirer de la shortlist':'Ajouter à la shortlist'}</button><button class="soft-btn" onclick="addComparePlayerV2(${p.id})">Comparer</button>${p.doubles_ranking!=null&&!isRetired?`<button class="soft-btn" onclick="approachPartner(${p.id});closeOverlay()">Approcher en double</button>`:''}${p.is_real&&!isRetired?`<button class="primary" onclick="startCareerWithPlayer(${p.id},'${esc(p.name).replaceAll("'","&#39;")}')">Gérer ce joueur</button>`:isRetired?'<span class="badge">Carrière terminée</span>':''}</div></div></div>
   </div>
   <template id="statsTpl">${playerStatsTemplate(d.statisticsDashboard||{},p,d.careerFinancials||{})}</template>
   <template id="attrsTpl"><div class="notice"><b>${playerKnowledgeLabel(isManaged,scoutReport)}</b> · ${isManaged?'Ton joueur est connu précisément : les notes 1–20 sont exactes dans la sauvegarde.':'Comme dans TM24, les joueurs que tu ne gères pas sont affichés en fourchettes. Au début d’une nouvelle partie, elles viennent de la connaissance publique ; le scouting les resserre progressivement sans révéler immédiatement la note exacte.'} Pour ton joueur, « plafond » représente la limite naturelle actuelle de la compétence : elle peut encore bouger avec le potentiel et la courbe de développement.</div><div class="attr-sections" style="margin-top:12px">${groups.map(g=>`<div class="attr-group"><h3>${g[0]}</h3>${g[1].map(x=>{const v=knownAttrs[x[1]],range=!isManaged?attrRanges[x[1]]:null,display=attrDisplayValue(x[1]),barValue=isManaged?Number(v):(range?(Number(range.min)+Number(range.max))/2:Number(v)),cap=isManaged?attributeCeilings[x[1]]:null;return `<div class="attr-row"><div class="row"><span>${x[0]}</span><span><b class="${Number.isFinite(barValue)?attrClass(barValue):''}">${display}</b>${isManaged?attrTrendMarkup(x[1],attributeTrend):''}${cap!=null?`<small class="muted micro"> / plafond ${cap}</small>`:''}</span></div><div class="bar"><i style="width:${Number.isFinite(barValue)?barValue*5:0}%"></i></div></div>`}).join('')}</div>`).join('')}</div></template>
   <template id="analyticsTpl">
    <div class="notice"><b>Analytics avancées</b> · Le moteur utilise les mêmes familles de lecture que Tennis Abstract / Match Charting Project : service, retour, pression, rally length, filet, directions et Elo. Ici, les valeurs « modelled » sont calculées par Court Boss à partir du profil joueur et évoluent ensuite dans la sauvegarde.</div>
    <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">État mental dynamique</div><h2>${esc(psych.status_label||'Stable')}</h2></div><span class="badge ${String(psych.status_label||'').includes('feu')||String(psych.status_label||'').includes('confiant')?'good':String(psych.status_label||'').includes('crise')||String(psych.status_label||'').includes('doute')?'bad':'warn'}">${psych.last_result?esc(psych.last_result):'Forme mentale'}</span></div>${psych.confidence!=null?`<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Confiance</span><b>${psych.confidence}</b></div><div class="kpi"><span class="muted micro">Momentum</span><b>${psych.momentum}</b></div><div class="kpi"><span class="muted micro">Rythme</span><b>${psych.match_rhythm}</b></div><div class="kpi"><span class="muted micro">Motivation</span><b>${psych.motivation}</b></div><div class="kpi"><span class="muted micro">Pression</span><b>${psych.pressure_load}</b></div><div class="kpi"><span class="muted micro">Burnout</span><b>${psych.burnout}</b></div></div>`:`<div class="muted mini" style="margin-top:8px">Les métriques mentales détaillées nécessitent une connaissance complète ou un rapport scout de haute confiance.</div>`}<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge">Série V ${psych.win_streak??0}</span><span class="badge">Série D ${psych.loss_streak??0}</span>${psych.hot_streak!=null?`<span class="badge good">Hot streak ${psych.hot_streak}</span><span class="badge ${Number(psych.slump||0)>=40?'bad':''}">Slump ${psych.slump}</span>`:''}</div><div class="muted micro" style="margin-top:7px">Confiance, momentum, pression et fatigue mentale influencent légèrement les matchs. Ils ne remplacent jamais le niveau, l’Elo ou la surface.</div></div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><div class="row between"><div><div class="eyebrow">Force contextuelle</div><h2>Elo Court Boss</h2></div><span class="badge">Confiance ${elo.confidence??'—'}%</span></div>
        <div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Global</span><b>${elo.overall_elo?Math.round(elo.overall_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Dur</span><b>${elo.hard_elo?Math.round(elo.hard_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Terre</span><b>${elo.clay_elo?Math.round(elo.clay_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Gazon</span><b>${elo.grass_elo?Math.round(elo.grass_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Indoor</span><b>${elo.indoor_elo?Math.round(elo.indoor_elo):'—'}</b></div><div class="kpi"><span class="muted mini">Double</span><b>${elo.doubles_elo?Math.round(elo.doubles_elo):'—'}</b></div></div>
        <div class="muted micro" style="margin-top:8px">${esc(elo.source_label||'Court Boss Elo')} · l’Elo bouge après les matchs joués.</div>
      </div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Indices synthétiques</div><h2>Profil analytique</h2></div><span class="badge">${esc(advanced.source_kind||'modelled')}</span></div>
        <div class="kpi-strip"><div class="kpi"><span class="muted mini">Service</span><b>${advanced.serve_rating??'—'}</b></div><div class="kpi"><span class="muted mini">Retour</span><b>${advanced.return_rating??'—'}</b></div><div class="kpi"><span class="muted mini">Clutch</span><b>${advanced.clutch_rating??'—'}</b></div><div class="kpi"><span class="muted mini">Aggression</span><b>${advanced.aggression_index??'—'}</b></div></div>
        <div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Pression moteur</span><b>${dynamicRatings.pressure_rating!=null?Math.round(Number(dynamicRatings.pressure_rating)):'—'}</b></div><div class="kpi"><span class="muted micro">Athlétique</span><b>${dynamicRatings.athletic_rating!=null?Math.round(Number(dynamicRatings.athletic_rating)):'—'}</b></div><div class="kpi"><span class="muted micro">Tactique</span><b>${dynamicRatings.tactical_rating!=null?Math.round(Number(dynamicRatings.tactical_rating)):'—'}</b></div><div class="kpi"><span class="muted micro">Volatilité</span><b>${dynamicRatings.volatility!=null?Math.round(Number(dynamicRatings.volatility)):'—'}</b></div></div>
        <div class="muted micro" style="margin-top:7px">Indices vivants du moteur : Elo, forme, pression, athlétisme, tactique et volatilité sont recalculés au fil de la sauvegarde.</div>
      </div>
    </div>
    ${surfaceAnalyticsPanel}
    <div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Identité tactique</div><h2>${esc(visibleTacticalProfile.tactical_identity||dev.preferred_archetype||p.style||'À préciser')}</h2></div><span class="badge">Évolutif</span></div>
      <div class="kpi-strip" style="margin-top:8px">
       <div class="kpi"><span class="muted micro">Agressivité</span><b>${visibleTacticalProfile.aggression_bias??'—'}/20</b></div>
       <div class="kpi"><span class="muted micro">Prise de risque</span><b>${visibleTacticalProfile.risk_tolerance??'—'}/20</b></div>
       <div class="kpi"><span class="muted micro">Montées filet</span><b>${visibleTacticalProfile.net_frequency??'—'}/20</b></div>
       <div class="kpi"><span class="muted micro">Rallyes longs</span><b>${visibleTacticalProfile.rally_length_preference??'—'}/20</b></div>
      </div>
      <div class="grid g2" style="margin-top:8px">
       <div>
        <div class="list-item row between"><span>Profondeur de position</span><b>${visibleTacticalProfile.baseline_depth??'—'}/20</b></div>
        <div class="list-item row between"><span>Service + 1</span><b>${visibleTacticalProfile.serve_plus_one_bias??'—'}/20</b></div>
        <div class="list-item row between"><span>Retour</span><b>${esc(visibleTacticalProfile.return_position||'—')}</b></div>
        <div class="list-item row between"><span>Recherche coup droit</span><b>${visibleTacticalProfile.forehand_bias??'—'}/20</b></div>
       </div>
       <div>
        <div class="list-item row between"><span>Amorties</span><b>${visibleTacticalProfile.drop_shot_frequency??'—'}/20</b></div>
        <div class="list-item row between"><span>Slice</span><b>${visibleTacticalProfile.slice_frequency??'—'}/20</b></div>
        <div class="list-item row between"><span>Cadence</span><b>${visibleTacticalProfile.pace_preference??'—'}/20</b></div>
        <div class="list-item row between"><span>Défense → attaque</span><b>${visibleTacticalProfile.defense_to_attack_bias??'—'}/20</b></div>
       </div>
      </div>
      <div class="muted micro" style="margin-top:8px">Ces tendances évoluent avec le profil. ${isManaged?'Lecture interne complète':scoutReport?'Estimation du recruteur':'Données tactiques masquées sans scouting'}.</div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card">
       <div class="row between"><div><div class="eyebrow">Traits préférés</div><h2>Comportements récurrents</h2></div><span class="badge">${visibleTacticalTraits.length}</span></div>
       ${visibleTacticalTraits.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${visibleTacticalTraits.map(x=>`<span class="badge ${Number(x.intensity)>=85?'good':Number(x.intensity)>=72?'warn':''}">${esc(x.trait_name)} · ${x.intensity}%</span>`).join('')}</div>`:'<div class="empty">Aucun trait dominant détecté.</div>'}
       <div class="muted micro" style="margin-top:8px">Les traits ne sont pas figés : un changement technique, physique ou tactique peut les faire apparaître ou disparaître.</div>
      </div>
      <div class="card">
       <div class="row between"><div><div class="eyebrow">${isManaged?'IA calendrier':'Projection calendrier'}</div><h2>${seasonPlan?esc(String(seasonPlan.plan_type||'').replaceAll('_',' ')):'Plan non généré'}</h2></div>${seasonPlan?`<span class="badge">${seasonPlan.season}</span>`:''}</div>
       ${seasonPlan?`<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Tournois cible</span><b>${seasonPlan.target_events}</b></div><div class="kpi"><span class="muted micro">Surface</span><b>${esc(seasonPlan.preferred_surface||'—')}</b></div><div class="kpi"><span class="muted micro">Repos</span><b>${seasonPlan.rest_bias}/20</b></div><div class="kpi"><span class="muted micro">Prestige</span><b>${seasonPlan.prestige_bias}/20</b></div></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge">Voyage ${seasonPlan.travel_tolerance}/20</span><span class="badge">Développement ${seasonPlan.development_bias}/20</span><span class="badge">Double ${seasonPlan.doubles_bias}/20</span></div><div class="muted mini" style="margin-top:8px">${esc(seasonPlan.reason||'')}</div>`:'<div class="empty">Le plan apparaîtra au prochain cycle de planification.</div>'}
      </div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Service</h2>
        ${[['1res balles IN','first_serve_in_pct'],['Aces / pts service','ace_pct'],['Doubles fautes','double_fault_pct'],['Services non retournés','unreturned_serve_pct'],['Pts gagnés 1re','first_serve_points_won_pct'],['Pts gagnés 2e','second_serve_points_won_pct'],['Pts service gagnés','service_points_won_pct'],['Jeux service tenus','hold_pct'],['Service +1 gagné','serve_plus_one_win_pct']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+'%':'—'}</b></div>`).join('')}
      </div>
      <div class="card"><h2>Retour</h2>
        ${[['Pts retour gagnés','return_points_won_pct'],['Retour 1re gagné','first_return_points_won_pct'],['Retour 2e gagné','second_return_points_won_pct'],['Jeux retour breakés','break_pct'],['Retours remis en jeu','return_in_play_pct'],['Pts gagnés après retour remis','return_in_play_server_win_pct'],['Profondeur retour','return_depth_score']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+(k==='return_depth_score'?'/100':'%'):'—'}</b></div>`).join('')}
      </div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Pression & qualité de point</h2>
        ${[['Balles de break sauvées','break_points_saved_pct'],['Balles de break converties','break_points_converted_pct'],['Tie-breaks','tiebreak_win_pct'],['Set décisif','deciding_set_win_pct'],['Comeback','comeback_win_pct'],['En tête → victoire','front_runner_win_pct'],['Winners','winner_rate_pct'],['Erreurs forcées provoquées','forced_error_induced_pct'],['Erreurs non forcées','unforced_error_pct']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+'%':'—'}</b></div>`).join('')}
      </div>
      <div class="card"><h2>Filet & rally length</h2>
        ${[['Montées au filet','net_approach_pct'],['Pts gagnés au filet','net_points_won_pct'],['Serve & volley','serve_volley_pct'],['Rally moyen','avg_rally_shots'],['Rally 1–3','rally_1_3_win_pct'],['Rally 4–6','rally_4_6_win_pct'],['Rally 7–9','rally_7_9_win_pct'],['Rally 10+','rally_10plus_win_pct']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${advanced[k]!=null?Number(advanced[k]).toFixed(1)+(k==='avg_rally_shots'?' coups':'%'):'—'}</b></div>`).join('')}
      </div>
    </div>
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Direction du service</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Large</span><b>${advanced.serve_wide_pct!=null?Number(advanced.serve_wide_pct).toFixed(1)+'%':'—'}</b></div><div class="kpi"><span class="muted mini">Corps</span><b>${advanced.serve_body_pct!=null?Number(advanced.serve_body_pct).toFixed(1)+'%':'—'}</b></div><div class="kpi"><span class="muted mini">T</span><b>${advanced.serve_t_pct!=null?Number(advanced.serve_t_pct).toFixed(1)+'%':'—'}</b></div></div></div>
      <div class="card"><h2>Directions de frappe</h2><div class="list-item row between"><span>CD croisé / ligne / inside-out</span><b>${advanced.forehand_cross_pct??'—'} / ${advanced.forehand_dtl_pct??'—'} / ${advanced.forehand_insideout_pct??'—'}%</b></div><div class="list-item row between"><span>RV croisé / ligne / slice</span><b>${advanced.backhand_cross_pct??'—'} / ${advanced.backhand_dtl_pct??'—'} / ${advanced.backhand_slice_pct??'—'}%</b></div><div class="list-item row between"><span>Potency coup droit</span><b>${advanced.forehand_potency!=null?Number(advanced.forehand_potency).toFixed(1)+'/100':'—'}</b></div><div class="list-item row between"><span>Potency revers</span><b>${advanced.backhand_potency!=null?Number(advanced.backhand_potency).toFixed(1)+'/100':'—'}</b></div><div class="list-item row between"><span>First-strike index</span><b>${advanced.first_strike_index!=null?Number(advanced.first_strike_index).toFixed(1)+'/100':'—'}</b></div><div class="list-item row between"><span>Serve Impact</span><b>${advanced.serve_impact!=null?Number(advanced.serve_impact).toFixed(1):'—'}</b></div></div>
    </div>
    <div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Contexte & grands matchs</div><h2>Profil situationnel</h2></div><span class="badge">${isManaged?'Interne':scoutReport?'Scouté':'Masqué'}</span></div>
      <div class="grid g2" style="margin-top:8px">
       <div>
        ${[['Best of 5','best_of_five'],['Tie-break','tiebreak_skill'],['Set décisif','deciding_set_skill'],['Comeback','comeback_mentality'],['Gestion avantage','front_runner'],['Grande scène','big_stage']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${knownContext[k]??'?'}/20</b></div>`).join('')}
       </div>
       <div>
        ${[['Voyage','travel_resilience'],['Jet lag','jet_lag_resistance'],['Chaleur','heat_tolerance'],['Vent','wind_adaptation'],['Altitude','altitude_adaptation'],['Indoor','indoor_affinity'],['Vs gauchers','lefty_handling']].map(([n,k])=>`<div class="list-item row between"><span>${n}</span><b>${knownContext[k]??'?'}/20</b></div>`).join('')}
       </div>
      </div>
      <div class="muted micro" style="margin-top:8px">Ces notes influencent maintenant les projections de match. En Grand Chelem, le Best of 5 et la gestion des grands rendez-vous peuvent déplacer un duel serré.</div>
    </div>
    ${styleHistory.length?`<div class="card" style="margin-top:12px"><div class="row between"><h2>Évolution tactique</h2><span class="badge">${styleHistory.length}</span></div>${styleHistory.slice(0,8).map(x=>`<div class="list-item row between"><div><b>${esc(x.old_style||'—')} → ${esc(x.new_style)}</b><div class="muted micro">${esc(x.reason||'Évolution du profil')}</div></div><span class="badge">${df(x.changed_at)}</span></div>`).join('')}</div>`:''}
   </template>
   <template id="developmentTpl">${renderPlayerRolePanel(roleFit,dev,p,scoutReport,isManaged)}${isManaged?`<div class="grid g3" style="margin-bottom:12px">
  <div class="card"><div class="eyebrow">Phase de carrière</div><h2>${esc(devPhaseLabels[devPhase]||devPhase)}</h2><div class="muted mini">Âge ${p.age??'—'} · pic théorique ${dev.peak_age??25} · déclin estimé ${dev.decline_start_age??30}</div><div style="margin-top:8px"><span class="badge ${devPhase==='prospect'||devPhase==='developing'?'good':devPhase==='decline'?'bad':'warn'}">${esc(dev.trajectory_outlook||devPhaseLabels[devPhase]||devPhase)}</span></div></div>
  <div class="card"><div class="eyebrow">Marge de progression</div><div class="big">+${potentialMargin}</div><div class="muted">CA ${p.current_ability} → PA actuel ${p.potential}</div><div class="bar" style="margin-top:9px"><i style="width:${Math.max(0,Math.min(100,potentialMargin*6))}%"></i></div></div>
  <div class="card"><div class="eyebrow">Potentiel dynamique</div><div class="big">${potentialMomentum>0?'+':''}${potentialMomentum}</div><div class="muted">Momentum · floor ${potentialFloor} · plafond ${potentialCeiling}</div><div style="margin-top:8px"><span class="badge ${potentialMomentum>1?'good':potentialMomentum<-1?'bad':''}">${potentialMomentum>1?'Tendance haussière':potentialMomentum<-1?'Tendance baissière':'Stable'}</span></div></div>
 </div>`:''}<div class="grid g2"><div class="card"><div class="row between"><div><div class="eyebrow">Niveau actuel</div><h2>${starRatingHtml(currentStars,'Capacité actuelle')}</h2></div><b>${isManaged?'CA '+p.current_ability+'/100':scoutReport?scoutReport.estimated_ca_min+'–'+scoutReport.estimated_ca_max:'Public'}</b></div><div class="bar"><i style="width:${Math.round(currentStars/5*100)}%"></i></div><div class="row between" style="margin-top:14px"><div><div class="eyebrow">Potentiel estimé</div><h2>${potentialStars!=null?starRatingHtml(potentialStars,'Potentiel'):'☆☆☆☆☆ ?'}</h2></div><b>${isManaged?'PA '+p.potential+'/100':scoutReport?scoutReport.estimated_pa_min+'–'+scoutReport.estimated_pa_max:'Inconnu'}</b></div><div class="bar"><i style="width:${potentialStars!=null?Math.round(potentialStars/5*100):0}%"></i></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:10px"><span class="badge">Fourchette ${potentialMin!=null?potentialMin.toFixed(1):'?'}–${potentialMax!=null?potentialMax.toFixed(1):'?'} ★</span><span class="badge">Confiance ${isManaged?100:scoutReport?.confidence??35}%</span></div><p class="muted mini" style="margin-top:9px">Le potentiel est dynamique et l’estimation dépend du recruteur. Un joueur peut dépasser ou manquer son plafond prévu.</p></div><div class="card"><div class="row between"><div><div class="eyebrow">Courbe & personnalité</div><h2>${isManaged?developmentTypeLabel(dev.development_type||'standard'):esc(scoutReport?.development_type_read||'À observer')}</h2></div><span class="badge">${isManaged?'Pic ~'+(dev.peak_age??25)+' ans':esc(scoutReport?.trajectory_read||'Inconnu')}</span></div>${isManaged?`<p class="muted mini">${developmentTypeDescription(dev.development_type||'standard')}</p><div class="list-item row between"><span>Personnalité</span><b>${esc(dev.personality_label||'Équilibré')}</b></div><div class="list-item row between"><span>Mentalité</span><b>${esc(dev.mentality_profile||'Stable')}</b></div><div class="list-item row between"><span>Attitude entraînement</span><b>${esc(dev.training_attitude||'Correcte')}</b></div><div class="list-item row between"><span>Vitesse développement</span><b>${dev.development_rate??10}/20</b></div><div class="list-item row between"><span>Coachabilité</span><b>${dev.coachability??10}/20</b></div><div class="list-item row between"><span>Résilience</span><b>${dev.resilience??10}/20</b></div><div class="list-item row between"><span>Professionnalisme</span><b>${dev.professionalism??10}/20</b></div><div class="list-item row between"><span>Ambition</span><b>${dev.ambition??10}/20</b></div><div class="list-item row between"><span>Fragilité</span><b>${dev.injury_proneness??10}/20</b></div>
<div class="list-item row between"><span>Discipline</span><b>${dev.discipline??10}/20</b></div>
<div class="list-item row between"><span>Gestion pression</span><b>${dev.pressure??10}/20</b></div>
<div class="list-item row between"><span>Stabilité confiance</span><b>${21-Number(dev.confidence_volatility??10)}/20</b></div><div class="list-item row between"><span>Grands matchs</span><b>${dev.important_matches>=16?'Excellent':dev.important_matches>=13?'Fort':dev.important_matches>=9?'Correct':'À développer'}</b></div><div class="list-item row between"><span>Tempérament</span><b>${dev.temperament>=16?'Très stable':dev.temperament>=12?'Stable':dev.temperament>=8?'Variable':'Volatile'}</b></div><div class="list-item row between"><span>Drive compétitif</span><b>${dev.competitive_drive>=16?'Très élevé':dev.competitive_drive>=12?'Élevé':dev.competitive_drive>=8?'Moyen':'Faible'}</b></div>`:`<div class="list-item row between"><span>Personnalité lue</span><b>${esc(scoutReport?.personality_read||'À préciser')}</b></div><div class="list-item row between"><span>Archétype</span><b>${esc(scoutReport?.archetype_read||p.style||'À préciser')}</b></div><div class="list-item row between"><span>Risque physique</span><b>${esc(scoutReport?.injury_risk_read||'Incertain')}</b></div><div class="list-item row between"><span>Trajectoire</span><b>${esc(scoutReport?.trajectory_read||'À préciser')}</b></div><p class="muted mini">${esc(scoutReport?.detailed_notes||'Lance une mission de scouting pour préciser le profil.')}</p>`}</div></div><div class="grid g2" style="margin-top:12px"><div class="card"><h2>${isManaged?'Axes à travailler':'Lecture scout'}</h2>${Object.entries(knownAttrs).filter(([k,v])=>k!=='player_id'&&Number.isFinite(Number(v))).sort((x,y)=>Number(x[1])-Number(y[1])).slice(0,8).map(([k,v])=>`<div class="list-item row between"><span>${esc(k.replaceAll('_',' '))}</span><b>${v}/20</b></div>`).join('')||'<div class="empty">Rapport insuffisant pour identifier les faiblesses.</div>'}</div>${isManaged?`<div class="card"><div class="row between"><div><div class="eyebrow">Impact du staff</div><h2>Environnement de développement</h2></div><span class="badge ${Number(dev.coaching_environment||8)>=15?'good':''}">${dev.coaching_environment??8}/20</span></div>
<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Technique</span><b>${dev.technical_environment??8}</b></div><div class="kpi"><span class="muted micro">Tactique</span><b>${dev.tactical_environment??8}</b></div><div class="kpi"><span class="muted micro">Physique</span><b>${dev.physical_environment??8}</b></div><div class="kpi"><span class="muted micro">Mental</span><b>${dev.mental_environment??8}</b></div></div>
<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Médical</span><b>${dev.medical_environment??8}</b></div><div class="kpi"><span class="muted micro">Stabilité staff</span><b>${dev.staff_stability??8}</b></div><div class="kpi"><span class="muted micro">Coachabilité</span><b>${dev.coachability??10}</b></div><div class="kpi"><span class="muted micro">Résilience</span><b>${dev.resilience??10}</b></div></div>
<p class="muted mini" style="margin-top:8px">${esc(developmentContextText||('Phase '+(devPhaseLabels[devPhase]||devPhase)+' · environnement recalculé à chaque cycle mensuel.'))}</p></div>`:''}
${seasonPlan&&(isManaged||Number(scoutReport?.confidence||0)>=75)?`<div class="card"><div class="row between"><div><div class="eyebrow">${isManaged?'Conseil IA calendrier':'Planification IA'}</div><h2>Plan de saison adaptatif</h2></div><span class="badge ${Number(psych.burnout||0)>=60?'bad':Number(psych.confidence||50)>=70?'good':'warn'}">${esc(psych.status_label||'Stable')}</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Tournois cibles</span><b>${seasonPlan.target_events??'—'}</b></div><div class="kpi"><span class="muted micro">Semaines max</span><b>${seasonPlan.max_consecutive_weeks??'—'}</b></div><div class="kpi"><span class="muted micro">Seuil repos fatigue</span><b>${seasonPlan.rest_trigger_fatigue??70}</b></div><div class="kpi"><span class="muted micro">Risque calendrier</span><b>${seasonPlan.schedule_risk_tolerance??10}/20</b></div></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Charge mentale cible</span><b>${seasonPlan.mental_load_target??55}</b></div><div class="kpi"><span class="muted micro">Voyage</span><b>${seasonPlan.travel_tolerance??10}/20</b></div><div class="kpi"><span class="muted micro">Prestige</span><b>${seasonPlan.prestige_bias??10}/20</b></div><div class="kpi"><span class="muted micro">Développement</span><b>${seasonPlan.development_bias??10}/20</b></div></div><div class="muted mini" style="margin-top:8px">${esc(seasonPlan.reason||'Le calendrier est recalculé selon la trajectoire du joueur.')}</div><div class="muted micro" style="margin-top:5px">Dernière adaptation : ${seasonPlan.last_adapted_date?df(seasonPlan.last_adapted_date):'début de saison'}. Burnout, pression, récupération et fragilité peuvent alléger la saison automatiquement.</div></div>`:''}
${!isManaged&&trainingLoad?`<div class="card"><div class="row between"><div><div class="eyebrow">Préparation IA</div><h2>${trainingLoad.phase?esc(String(trainingLoad.phase).replaceAll('_',' ')):'Charge inconnue'}</h2></div>${trainingLoad.intensity!=null?`<span class="badge ${Number(trainingLoad.intensity)>=16?'warn':Number(trainingLoad.intensity)<=8?'good':''}">Intensité ${trainingLoad.intensity}/20</span>`:'<span class="badge">Lecture partielle</span>'}</div>${trainingLoad.intensity!=null?`<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Technique</span><b>${trainingLoad.technical_share}%</b></div><div class="kpi"><span class="muted micro">Tactique</span><b>${trainingLoad.tactical_share}%</b></div><div class="kpi"><span class="muted micro">Physique</span><b>${trainingLoad.physical_share}%</b></div><div class="kpi"><span class="muted micro">Récupération</span><b>${trainingLoad.recovery_share}%</b></div></div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px"><span class="badge">Focus ${esc(dev.primary_training_focus||'Adaptatif')}</span><span class="badge">Secondaire ${esc(dev.secondary_training_focus||'—')}</span><span class="badge">${trainingLoad.recovery_days??1} j récupération</span></div><div class="muted mini" style="margin-top:8px">${esc(trainingLoad.reason||'Charge ajustée au calendrier, à la forme et à la psychologie.')}</div>`:`<div class="muted mini" style="margin-top:8px">Le scout identifie la phase générale, mais pas encore les détails de charge.</div>`}</div>`:''}
${isManaged&&attributeTrend?`<div class="card"><div class="row between"><div><div class="eyebrow">Dernier cycle</div><h2>Tendance des attributs</h2></div><span class="badge">${attributeTrend.changed_count||0} changement(s)</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">En hausse</span><b class="good">${attributeTrend.improved_count||0}</b></div><div class="kpi"><span class="muted micro">En baisse</span><b class="bad">${attributeTrend.declined_count||0}</b></div><div class="kpi"><span class="muted micro">Dernier relevé</span><b style="font-size:13px">${df(attributeTrend.last_update)}</b></div></div><div class="muted micro" style="margin-top:7px">Les flèches de l’onglet Attributs montrent uniquement les variations du dernier cycle, sans stocker des milliers de snapshots inutiles.</div></div>`:''}<div class="card"><div class="row between"><h2>Historique développement</h2><span class="badge">${devHistory.length}</span></div>${devHistory.length?devHistory.slice(0,12).map(x=>`<div class="list-item"><div class="row between"><b>${df(x.event_date)}</b><span class="badge">${esc(x.event_type)}</span></div><div class="muted mini">CA ${x.old_current_ability??'—'} → ${x.new_current_ability??'—'} · PA ${x.old_potential??'—'} → ${x.new_potential??'—'}</div>${x.old_development_type!==x.new_development_type?`<div class="muted micro">${developmentTypeLabel(x.old_development_type)} → ${developmentTypeLabel(x.new_development_type)}</div>`:''}<div class="muted micro">${esc(x.reason||'Évolution')}</div></div>`).join(''):'<div class="empty">Aucun changement dynamique enregistré depuis le début de la sauvegarde.</div>'}</div></div>${isManaged?`<div class="card" style="margin-top:12px">
 <div class="row between"><div><div class="eyebrow">Development-v3</div><h2>Historique des traits cachés</h2></div><span class="badge">${devTraitHistory.length} changement${devTraitHistory.length>1?'s':''}</span></div>
 <div class="muted mini" style="margin-top:5px">Ces valeurs évoluent lentement avec le coaching, la discipline, les blessures, la fatigue et la phase de carrière. Elles ne sont pas réinitialisées chaque saison.</div>
 ${devTraitHistory.length?devTraitHistory.slice(0,24).map(x=>{const labels={professionalism:'Professionnalisme',coachability:'Coachabilité',resilience:'Résilience',discipline:'Discipline',competitive_drive:'Drive compétitif',development_rate:'Vitesse de développement',confidence_volatility:'Volatilité confiance',potential_volatility:'Volatilité potentiel',potential_momentum:'Momentum potentiel',decline_start_age:'Âge de déclin',phase:'Phase de carrière'};return `<div class="list-item"><div class="row between"><div><b>${esc(labels[x.trait_code]||x.trait_code)}</b><div class="muted micro">${df(x.event_date)} · ${esc(x.reason||'Évolution du profil')}</div></div><span class="badge ${Number(x.new_value)>Number(x.old_value)?'good':Number(x.new_value)<Number(x.old_value)?'warn':''}">${esc(x.old_value??'—')} → ${esc(x.new_value??'—')}</span></div></div>`}).join(''):'<div class="empty">Aucun trait caché n’a encore évolué depuis le début de cette sauvegarde.</div>'}
 </div>`:''}${hiddenTraitCard}</template>
   <template id="matchesTpl">${(d.juniorEntries||[]).length?`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Circuit ITF Junior</div><h2>Tournois juniors vérifiés</h2></div><span class="badge">Junior #${p.junior_ranking||'—'}</span></div>${(d.juniorEntries||[]).map(e=>{const t=Array.isArray(e.tournaments)?e.tournaments[0]:e.tournaments;return `<div class="list-item row between"><div><b>${esc(t?.name||'Tournoi junior')}</b><div class="muted mini">${t?.city?esc(t.city)+' · ':''}${t?.start_date?df(t.start_date):''} · ${esc(t?.category||'Junior')} · ${esc(surfaceLabel(t||{}))}</div></div><div style="text-align:right"><b>${esc(e.result||'Engagé')}</b><div class="muted mini">${e.seed?'TDS '+esc(e.seed):''}</div></div></div>`}).join('')}</div>`:''}<div class="grid g2"><div class="card"><h2>Historique importé</h2>${realMatches?`<div class="big">${fmt(cs.wins||0)} - ${fmt(cs.losses||0)}</div><div class="muted">${realWinPct}% de victoires · ${fmt(realMatches)} matchs</div><div class="bar" style="margin-top:10px"><i style="width:${realWinPct}%"></i></div><div class="row" style="margin-top:10px;flex-wrap:wrap"><span class="badge">Dur ${pct(cs.hard_wins,cs.hard_losses)}%</span><span class="badge clay">Terre ${pct(cs.clay_wins,cs.clay_losses)}%</span><span class="badge grass">Gazon ${pct(cs.grass_wins,cs.grass_losses)}%</span></div>`:'<div class="empty">Pas de données historiques.</div>'}</div><div class="card"><h2>Bilan dans la sauvegarde</h2><div class="kpi-strip"><div class="kpi"><span class="muted mini">Matchs</span><b>${(d.matches||[]).length}</b></div><div class="kpi"><span class="muted mini">Victoires</span><b>${(d.matches||[]).filter(m=>m.winner_id===p.id).length}</b></div><div class="kpi"><span class="muted mini">Défaites</span><b>${(d.matches||[]).filter(m=>m.winner_id!==p.id).length}</b></div><div class="kpi"><span class="muted mini">% victoires</span><b>${(d.matches||[]).length?Math.round((d.matches||[]).filter(m=>m.winner_id===p.id).length/(d.matches||[]).length*100):0}%</b></div></div></div><div class="card"><h2>Forme actuelle</h2><div class="row between"><span>Forme</span><b>${p.form}/100</b></div><div class="bar"><i style="width:${p.form}%"></i></div><div class="row between" style="margin-top:10px"><span>Fitness</span><b>${p.fitness}/100</b></div><div class="bar"><i style="width:${p.fitness}%"></i></div></div></div><div class="card" style="margin-top:12px"><h2>Historique des matchs</h2>${(d.matches||[]).length?(d.matches||[]).map(m=>{const oppId=m.player_a_id===p.id?m.player_b_id:m.player_a_id;const opp=m.player_a_id===p.id?m.player_b_name:m.player_a_name;const won=m.winner_id===p.id;const tour=m.tournament_runs?.tournaments;return `<div class="list-item row between"><div class="click" onclick="openPlayer(${oppId})"><div><b class="${won?'good':'bad'}">${won?'V':'D'}</b> vs ${esc(opp)}</div><div class="muted mini">${esc(tour?.name||'Tournoi')} · ${esc(m.round_name)} · ${esc(surfaceLabel(tour||{}))}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="muted mini">${df(tour?.start_date)}</div></div></div>`}).join(''):'<div class="empty">Aucun match simulé pour ce joueur dans cette sauvegarde.</div>'}</div></template>
   <template id="doubleTpl">
    <div class="grid g2">
      <div class="card"><div class="row between"><div><div class="eyebrow">Classement individuel</div><h2>ATP Double</h2></div><span class="badge ${p.doubles_source?'good':''}">${p.doubles_source?'Sourcé':'Index DB'}</span></div>
        <div class="statline"><div class="statbox"><span class="muted mini">Rang actuel</span><b>${p.doubles_ranking?'#'+fmt(p.doubles_ranking):'NR'}</b></div><div class="statbox"><span class="muted mini">Meilleur carrière</span><b>${p.career_high_doubles_rank?'#'+fmt(p.career_high_doubles_rank):'—'}</b><small class="muted micro">${p.career_high_doubles_rank_date?df(p.career_high_doubles_rank_date):''}</small></div><div class="statbox"><span class="muted mini">Points</span><b>${p.doubles_points==null?'—':fmt(p.doubles_points)}</b></div><div class="statbox"><span class="muted mini">Aptitude double</span><b>${attrDisplayValue('doubles')}/20</b></div></div>
        <div class="muted mini" style="margin-top:8px">${p.doubles_source?esc(p.doubles_source):'Classement indexé Court Boss'}${p.doubles_snapshot_date?' · '+df(p.doubles_snapshot_date):''}</div>
        ${p.doubles_ranking!=null&&!isRetired?`<button class="primary" style="width:100%;margin-top:10px" onclick="approachPartner(${p.id});closeOverlay()">Approcher comme partenaire</button>`:''}
      </div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Race par équipes</div><h2>Paires ${String(local.date||RANKING_SNAPSHOT).slice(0,4)}</h2></div><span class="badge">${(d.doublesTeams||[]).length}</span></div>
        ${(d.doublesTeams||[]).length?(d.doublesTeams||[]).map(x=>{const partner=x.player_one===p.name?x.player_two:x.player_one;return `<div class="list-item row between"><div><b>#${fmt(x.rank)} · ${esc(partner)}</b><div class="muted mini">${esc(x.player_one)} / ${esc(x.player_two)} · ${x.snapshot_date?df(x.snapshot_date):''}</div></div><b>${fmt(x.points)} pts</b></div>`}).join(''):'<div class="empty">Aucune paire Race actuelle trouvée pour ce joueur.</div>'}
      </div>
    </div>
    ${primaryDoubles?`<div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Projet double</div><h2>Partenaire principal</h2></div><span class="badge good">Engagement ${primaryDoubles.commitment}/100</span></div>
      <div class="list-item click" onclick="openPlayer(${primaryDoubles.partner?.id})"><div class="row between"><div><b>${flags[primaryDoubles.partner?.country]||'🏳️'} ${esc(primaryDoubles.partner?.name||'Partenaire')}</b><div class="muted mini">Double ${primaryDoubles.partner?.doubles_ranking?'#'+fmt(primaryDoubles.partner.doubles_ranking):'NR'} · depuis ${df(primaryDoubles.started_at)}</div></div><div style="text-align:right"><b>${primaryDoubles.affinity}/100</b><div class="muted micro">affinité</div></div></div></div>
      <div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Saison</span><b>${primaryDoubles.season}</b></div><div class="kpi"><span class="muted mini">Changements</span><b>${primaryDoubles.switches||0}</b></div><div class="kpi"><span class="muted mini">Affinité</span><b>${primaryDoubles.affinity}/100</b></div><div class="kpi"><span class="muted mini">Engagement</span><b>${primaryDoubles.commitment}/100</b></div></div>
      <div class="muted mini" style="margin-top:8px">${esc(primaryDoubles.reason||'Partenariat principal de double.')}</div>
      ${doublesPartnerHistory.length?`<div style="margin-top:8px"><div class="muted micro">Anciens partenaires principaux</div>${doublesPartnerHistory.slice(0,5).map(x=>`<div class="list-item row between"><div class="click" onclick="openPlayer(${x.partner?.id})"><b>${esc(x.partner?.name||'Partenaire')}</b><div class="muted micro">${df(x.start_date)} → ${df(x.end_date)}</div></div><span class="badge">${x.affinity_end??x.affinity_start??'—'}/100</span></div>`).join('')}</div>`:''}
    </div>`:''}
    <div class="card" style="margin-top:12px">
      <div class="row between"><div><div class="eyebrow">Palmarès</div><h2>Titres en double</h2></div><span class="badge good">${doublesTitles.length} titre${doublesTitles.length>1?'s':''}</span></div>
      ${doublesTitles.length?doublesTitles.map(t=>`<div class="list-item row between"><div><b>${esc(t.tournament_name)}</b><div class="muted mini">${df(t.title_date)} · ${esc(t.level||'Double')} · ${esc(t.surface||'—')}</div>${t.partner_name?`<div class="muted mini">Partenaire : ${t.partner_player_id?`<span class="click" onclick="openPlayer(${t.partner_player_id})">${esc(t.partner_name)}</span>`:esc(t.partner_name)}</div>`:''}</div><div style="text-align:right">${t.verified?'<span class="badge good">Vérifié</span>':'<span class="badge">Carrière</span>'}${t.source_url?`<div style="margin-top:5px"><a class="soft-btn" href="${esc(t.source_url)}" target="_blank" rel="noopener noreferrer">Source</a></div>`:''}</div></div>`).join(''):'<div class="empty">Aucun titre double enregistré.</div>'}
    </div>
    <div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Scouting double</div><h2>Lecture du profil</h2></div><button class="ghost" onclick="closeOverlay();nav('doubles')">Hub Double</button></div>
      <div class="kpi-strip"><div class="kpi"><span class="muted mini">Volée</span><b>${attrDisplayValue('volley')}</b></div><div class="kpi"><span class="muted mini">Retour</span><b>${attrDisplayValue('return_game')}</b></div><div class="kpi"><span class="muted mini">Service</span><b>${attrDisplayValue('serve_power')}</b></div><div class="kpi"><span class="muted mini">Toucher</span><b>${attrDisplayValue('touch')}</b></div></div><div class="muted micro" style="margin-top:7px">${playerKnowledgeLabel(isManaged,scoutReport)}</div>
    </div>
   </template>
   <template id="careerTpl">
    ${window.renderPalmaresHtml?window.renderPalmaresHtml(d,p):'<div class="card empty">Module palmarès indisponible.</div>'}
    <div class="card fm-panel" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Carrière saison par saison</div><h2>Palmarès annuel</h2></div><span class="badge">${(d.historicalSeasons||[]).length} saisons</span></div>
      ${(d.historicalSeasons||[]).length?`<div class="table-wrap"><table class="table"><thead><tr><th>Saison</th><th>Rang</th><th>Titres</th><th>GC</th><th>Masters</th><th>Finals</th><th>Score saison</th><th>Source</th></tr></thead><tbody>${d.historicalSeasons.map(y=>{const score=weightedSeason(y);const best=Number(y.season)===Number(p.best_season_year||bestHistoricalSeason?.season);return `<tr ${best?'style="background:rgba(92,222,145,.08)"':''}><td class="rank-num">${y.season}${best?' <span class="badge good">BEST</span>':''}</td><td>${y.best_rank?'#'+fmt(y.best_rank):'—'}</td><td>${y.titles==null?'—':y.titles}</td><td><b>${y.grand_slams||0}</b></td><td>${y.masters||0}</td><td>${y.tour_finals||0}</td><td><b>${fmt(score)}</b></td><td class="muted mini">${esc(y.source_label||'Archive')}</td></tr>`}).join('')}</tbody></table></div>`:'<div class="empty">Pas encore de découpage annuel disponible.</div>'}
    </div>
   </template>
   <template id="commercialTpl"><div class="card"><h2>Sponsors vérifiés</h2>${d.sponsors.filter(s=>s.verified).length?d.sponsors.filter(s=>s.verified).map(s=>`<span class="badge good" style="margin:4px">${esc(s.sponsor)}</span>`).join(''):'<div class="empty">Non vérifié</div>'}<p class="muted mini" style="margin-top:10px">Aucune marque n'est inventée quand la donnée n'est pas vérifiée.</p></div></template>
   <template id="historyTpl"><div class="card"><div class="row between"><div><div class="eyebrow">Records classement</div><h2>Historique ATP</h2></div><span class="badge">au 01/12/2025</span></div><div class="kpi-strip" style="margin-top:10px"><div class="kpi"><span class="muted mini">Meilleur simple</span><b>${p.career_high_rank?'#'+fmt(p.career_high_rank):'—'}</b><small class="muted micro">${p.career_high_rank_date?df(p.career_high_rank_date):''}</small></div><div class="kpi"><span class="muted mini">Meilleur double</span><b>${p.career_high_doubles_rank?'#'+fmt(p.career_high_doubles_rank):'—'}</b><small class="muted micro">${p.career_high_doubles_source?esc(p.career_high_doubles_source):''}</small></div><div class="kpi"><span class="muted mini">Meilleure saison</span><b>${p.best_season_year||bestHistoricalSeason?.season||'—'}</b><small class="muted micro">${p.best_season_summary?esc(p.best_season_summary):''}</small></div><div class="kpi"><span class="muted mini">Semaines n°1</span><b>${fmt(p.weeks_at_no1||0)}</b></div></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Semaines Top 10</span><b>${fmt(p.weeks_top10||0)}</b></div><div class="kpi"><span class="muted mini">Semaines Top 100</span><b>${fmt(p.weeks_top100||0)}</b></div><div class="kpi"><span class="muted mini">Titres</span><b>${titleCount}</b></div><div class="kpi"><span class="muted mini">Grand Chelem</span><b>${slamCount}</b></div></div><div class="muted micro" style="margin-top:8px">${esc(p.ranking_history_source||'Archive ATP')} · ${fmt(p.ranking_history_weeks||0)} semaines indexées.</div></div><div class="card" style="margin-top:12px"><h2>Snapshots de la sauvegarde</h2>${d.history.length?d.history.map(h=>`<div class="list-item row between"><span>${df(h.snapshot_date)}</span><b>#${h.ranking} · ${fmt(h.points)} pts</b></div>`).join(''):'<div class="empty">Pas encore assez de snapshots dans la sauvegarde.</div>'}</div></template>
  </div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur</h2><p>${esc(e.message)}</p></div></div>`}
}
window.playerSection=s=>{const body=document.getElementById('playerBody');if(!body)return;if(!body.dataset.profile)body.dataset.profile=body.innerHTML;const map={attrs:'attrsTpl',analytics:'analyticsTpl',stats:'statsTpl',development:'developmentTpl',matches:'matchesTpl',double:'doubleTpl',career:'careerTpl',commercial:'commercialTpl',history:'historyTpl'};const t=document.getElementById(map[s]);if(s==='profile')body.innerHTML=body.dataset.profile;else if(t)body.innerHTML=t.innerHTML;overlay.querySelectorAll('[data-player-tab]').forEach(b=>{b.classList.toggle('active',b.dataset.playerTab===s);b.setAttribute('aria-selected',String(b.dataset.playerTab===s))});}
window.closeOverlay=()=>{overlay.innerHTML='';};
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeOverlay();});
window.toggleShortlist=async id=>{
 local.shortlist=local.shortlist||[];
 const active=!local.shortlist.includes(id);
 try{await get('/api/shortlist',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({player_id:id,active,priority:'Normal'})})}catch(e){console.warn(e)}
 local.shortlist=active?[...new Set([...local.shortlist,id])]:local.shortlist.filter(x=>x!==id);
 persist();await loadManagement();closeOverlay();render();
}
function tournamentDoublesHistoryHtml(rows){
 if(!Array.isArray(rows)||!rows.length)return '';
 const team=(aId,aName,bId,bName,champ)=>{
  if(!aName)return '—';
  const a=aId?"<span class='click' onclick='openPlayer("+aId+")'>"+esc(aName)+"</span>":esc(aName);
  const b=bName?(bId?"<span class='click' onclick='openPlayer("+bId+")'>"+esc(bName)+"</span>":esc(bName)):'—';
  return (champ?'🏆 ':'')+a+' / '+b;
 };
 return "<div style='margin-top:14px'><div class='row between'><div><div class='eyebrow'>Archive double</div><h2>Palmarès double documenté</h2></div><span class='badge'>"+rows.length+" édition"+(rows.length>1?'s':'')+"</span></div>"+
  "<div class='notice mini' style='margin-top:8px'><b>Couverture source :</b> le double est documenté partiellement entre 2000 et 2020. Les années absentes ne sont pas inventées.</div>"+
  "<div class='table-wrap' style='margin-top:8px'><table class='table'><thead><tr><th>Année</th><th>Champions</th><th>Finalistes</th><th>Surface</th></tr></thead><tbody>"+
  rows.map(h=>"<tr><td class='rank-num'>"+h.season+"</td><td><b>"+team(h.winner_a_id,h.winner_a_name,h.winner_b_id,h.winner_b_name,true)+"</b></td><td>"+team(h.runner_a_id,h.runner_a_name,h.runner_b_id,h.runner_b_name,false)+"</td><td>"+esc(h.surface||'—')+"</td></tr>").join('')+
  "</tbody></table></div></div>";
}


function tournamentEntryCode(method){
 const m=String(method||'direct').toLowerCase();
 const map={direct:'DA',wildcard:'WC',qualifying:'Q',qualifier:'Q',qualifier_slot:'Q',lucky_loser:'LL',alternate:'ALT',special_exempt:'SE',performance_bye:'PB',bye:'BYE',direct_fallback_slot:'ALT',withdrawn_pending:'VAC'};
 return map[m]||String(method||'DA').toUpperCase().slice(0,4);
}
function tournamentTimelineHtml(rows,phase){
 if(!Array.isArray(rows)||!rows.length)return '';
 const phaseLabel={entry_list:'Entry list',qualifying:'Qualifications',draw:'Tirage',live:'Tournoi en cours',completed:'Terminé'}[phase]||phase;
 return "<div class='card' style='margin-bottom:12px'><div class='row between'><div><div class='eyebrow'>Calendrier réel du tableau</div><h2>WC · Q · LL · ALT · tirage</h2></div><span class='badge "+(phase==='live'?'good':phase==='qualifying'||phase==='draw'?'warn':'')+"'>"+esc(phaseLabel||'Préparation')+"</span></div><div style='display:flex;gap:8px;overflow-x:auto;padding:8px 0 2px'>"+
  rows.map(x=>"<div style='min-width:150px;padding:9px;border:1px solid var(--border);border-radius:10px'><div class='muted micro'>"+df(x.date)+"</div><b style='font-size:12px'>"+esc(x.label)+"</b><div style='margin-top:5px'><span class='badge "+(x.status==='done'?'good':x.status==='today'?'warn':'')+"'>"+(x.status==='done'?'Fait':x.status==='today'?'Aujourd’hui':'À venir')+"</span></div></div>").join('')+
 "</div></div>";
}
function projectedTournamentR1(entries,byeSlots,bracketSize){
 const drawPos=x=>Number(x?.draw_slot||x?.draw_pos||0);
 const xs=(entries||[]).filter(x=>drawPos(x)>0);
 if(!xs.length)return [];
 const slotMap=new Map(xs.map(x=>[drawPos(x),x.withdrawn_pending?{...x,id:null,name:'Vacance · LL/ALT à déterminer',entry_method:'withdrawn_pending'}:x]));
 const byes=new Set((byeSlots||[]).map(Number));
 let size=Number(bracketSize||0);
 if(!size)size=Math.pow(2,Math.ceil(Math.log2(Math.max(2,...xs.map(x=>Number(x.draw_slot)||0)))));
 const out=[];
 for(let s=1;s<=size;s+=2){
  const a=slotMap.get(s)||{id:null,name:byes.has(s)?'BYE':'À déterminer',entry_method:byes.has(s)?'bye':null,draw_slot:s};
  const b=slotMap.get(s+1)||{id:null,name:byes.has(s+1)?'BYE':'À déterminer',entry_method:byes.has(s+1)?'bye':null,draw_slot:s+1};
  out.push({round_no:1,round_name:'1er tour',match_no:(s+1)/2,player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
    player_a_seed:a.seed,player_b_seed:b.seed,player_a_entry:tournamentEntryCode(a.entry_method),player_b_entry:tournamentEntryCode(b.entry_method),
    scheduled_date:null,status:'scheduled',score:null});
 }
 return out;
}
function tournamentBracketHtml(matches,entries,byeSlots,bracketSize,title,options={}){
 const opts=options||{};
 let rows=Array.isArray(matches)?matches.filter(Boolean):[];
 const normalizedEntries=(entries||[]).map(x=>({...x,draw_slot:Number(x?.draw_slot||x?.draw_pos||0)||null}));
 if(!rows.length)rows=projectedTournamentR1(normalizedEntries,byeSlots,bracketSize);
 if(!rows.length)return "<div class='tm-bracket-card'><div class='tm-bracket-empty'><div class='eyebrow'>Tirage</div><h2>"+esc(title||'Tableau')+"</h2><div class='empty'>Le tirage n’est pas encore publié.</div></div></div>";

 const entryById=new Map(normalizedEntries.filter(x=>Number(x.id)>0).map(x=>[Number(x.id),x]));
 const managedIds=[...new Set((Array.isArray(opts.managedIds)?opts.managedIds:[opts.managedId??career()?.managed_player_id]).map(Number).filter(Boolean))];
 const sections=Math.max(1,Number(opts.sectionCount||1));
 let sectionBracket=Math.max(0,Number(opts.sectionBracket||0));
 let size=Math.max(0,Number(bracketSize||0));
 if(sectionBracket>0)size=sections*sectionBracket;
 if(!size){
  const maxSlot=Math.max(2,...normalizedEntries.map(x=>Number(x.draw_slot)||0));
  size=Math.pow(2,Math.ceil(Math.log2(maxSlot)));
 }
 if(!sectionBracket)sectionBracket=Math.max(2,size);
 size=Math.max(2,size);

 let totalRounds=Math.max(0,Number(opts.roundCount||0));
 if(!totalRounds)totalRounds=Math.max(1,Math.round(Math.log2(Math.max(2,sectionBracket))));

 const existingKeys=[...new Set(rows.map(m=>String(m.round_no??m.round_code??m.round_name??'')))];
 const keyed=existingKeys.map(key=>({
  key,
  rows:rows.filter(m=>String(m.round_no??m.round_code??m.round_name??'')===key)
 })).sort((a,b)=>b.rows.length-a.rows.length||Number(a.key)-Number(b.key));
 const displayRows=[];

 const roundLabel=r=>{
  if(r===totalRounds)return 'Finale';
  if(r===totalRounds-1)return 'Demi-finales';
  if(r===totalRounds-2)return 'Quarts de finale';
  if(r===totalRounds-3)return 'Huitièmes';
  const drawAtRound=Math.round(sectionBracket/Math.pow(2,r-1));
  return drawAtRound>=16?'R'+drawAtRound:(r===1?'1er tour':r+'e tour');
 };

 for(let r=1;r<=totalRounds;r++){
  const existing=keyed[r-1]?.rows||[];
  const matchesPerSection=Math.max(1,Math.round(sectionBracket/Math.pow(2,r)));
  const expected=Math.max(1,sections*matchesPerSection);
  if(existing.length){
   existing.slice().sort((a,b)=>Number(a.match_no||0)-Number(b.match_no||0)).forEach((m,i)=>displayRows.push({...m,_display_round:r,_display_match:Number(m.match_no||i+1)}));
  }else{
   for(let m=1;m<=expected;m++)displayRows.push({
    round_no:r,round_name:roundLabel(r),match_no:m,_display_round:r,_display_match:m,
    player_a_id:null,player_b_id:null,player_a_name:'À déterminer',player_b_name:'À déterminer',
    scheduled_date:null,status:'scheduled',score:null,placeholder:true
   });
  }
 }

 const sideIds=(id,ids)=>Array.isArray(ids)&&ids.length?ids.map(Number).filter(Boolean):(id?[Number(id)]:[]);
 const playerLine=(id,ids,name,seed,code,winnerId)=>{
  const idsList=sideIds(id,ids);
  const meta=id?entryById.get(Number(id))||{}:{};
  const country=meta.country||null;
  const ranking=Number(meta.ranking||meta.ranking_at_entry||0);
  const ec=tournamentEntryCode(code||meta.entry_method||'');
  const managed=idsList.some(x=>managedIds.includes(x));
  const won=(winnerId&&idsList.includes(Number(winnerId)))||String(name||'')==='BYE';
  const empty=!name||String(name)==='À déterminer'||String(name)==='—';
  const seedText=seed?'['+seed+']':'';
  const rankText=ranking>0&&ranking<999999?'#'+fmt(ranking):'';
  const click=id&&idsList.length===1?" onclick='openPlayer("+Number(id)+")'":'';
  return "<div class='tm-bracket-player"+(managed?' is-managed':'')+(won?' is-winner':'')+(empty?' is-empty':'')+(id&&idsList.length===1?' click':'')+"'"+click+">"+
   "<span class='tm-bracket-seed'>"+esc(seedText)+"</span>"+
   "<span class='tm-bracket-name'>"+(country?(flags[country]||'🏳️')+' ':'')+esc(String(name||'À déterminer'))+"</span>"+
   (ec&&ec!=='DA'?"<span class='tm-bracket-entry'>"+esc(ec)+"</span>":"<span class='tm-bracket-entry'></span>")+
   "<span class='tm-bracket-rank'>"+esc(rankText)+"</span>"+
  "</div>";
 };

 const rowHeight=Number(opts.rowHeight||32);
 const gridHeight=Math.max(230,size*rowHeight);
 const gridCols="repeat("+totalRounds+", minmax(218px,236px))";
 const played=displayRows.filter(m=>m.status==='completed'&&!m.placeholder&&m.score!=='BYE').length;
 const hasManaged=displayRows.some(m=>sideIds(m.player_a_id,m.player_a_ids).some(x=>managedIds.includes(x))||sideIds(m.player_b_id,m.player_b_ids).some(x=>managedIds.includes(x)));
 const sectionBadge=sections>1?" · "+sections+" sections":'';

 const cards=displayRows.map(m=>{
  const r=Number(m._display_round||1);
  const matchNo=Math.max(1,Number(m._display_match||m.match_no||1));
  const perSection=Math.max(1,Math.round(sectionBracket/Math.pow(2,r)));
  const sectionNo=Math.min(sections-1,Math.floor((matchNo-1)/perSection));
  const within=(matchNo-1)%perSection;
  const span=Math.max(2,Math.pow(2,r));
  const start=sectionNo*sectionBracket+within*span+1;
  const aIds=sideIds(m.player_a_id,m.player_a_ids),bIds=sideIds(m.player_b_id,m.player_b_ids);
  const managed=aIds.some(x=>managedIds.includes(x))||bIds.some(x=>managedIds.includes(x));
  const completed=m.status==='completed'||Boolean(m.winner_id)||Boolean(m.winner_pair_id);
  const winnerId=m.winner_id||m.winner_pair_id||null;
  const status=m.score==='BYE'?'BYE':completed?'Terminé':'À jouer';
  return "<div class='tm-bracket-match"+(managed?' is-managed':'')+(completed?' is-completed':'')+(m.placeholder?' is-placeholder':'')+"' style='grid-column:"+r+";grid-row:"+start+" / span "+span+"'>"+
    "<div class='tm-bracket-match-meta'><span>"+(m.scheduled_date?df(m.scheduled_date):esc(String(m.round_name||roundLabel(r))))+"</span><b>"+status+"</b></div>"+
    playerLine(m.player_a_id,m.player_a_ids,m.player_a_name,m.player_a_seed,m.player_a_entry,winnerId)+
    playerLine(m.player_b_id,m.player_b_ids,m.player_b_name,m.player_b_seed,m.player_b_entry,winnerId)+
    (m.score&&m.score!=='BYE'?"<div class='tm-bracket-score'>"+esc(m.score)+(m.winner_name?" · "+esc(m.winner_name):m.winner_pair_name?" · "+esc(m.winner_pair_name):"")+"</div>":"")+
   "</div>";
 }).join('');

 return "<div class='tm-bracket-card'>"+
  "<div class='tm-bracket-toolbar'><div><div class='eyebrow'>Tableau</div><h2>"+esc(title||'Tableau principal')+"</h2><div class='muted mini'>"+played+" match"+(played>1?'s':'')+" joué"+(played>1?'s':'')+" · "+size+" lignes"+sectionBadge+"</div></div>"+
  "<div class='tm-bracket-actions'>"+(hasManaged?"<button class='soft-btn' onclick='focusManagedDraw()'>Mon joueur</button>":"")+"<span class='badge'>"+totalRounds+" tours</span></div></div>"+
  "<div class='tm-bracket-scroll'>"+
   "<div class='tm-bracket-round-heads' style='grid-template-columns:"+gridCols+"'>"+
    Array.from({length:totalRounds},(_,i)=>"<div class='tm-bracket-round-title'>"+esc(roundLabel(i+1))+"</div>").join('')+
   "</div>"+
   "<div class='tm-bracket-grid' style='grid-template-columns:"+gridCols+";grid-template-rows:repeat("+size+", "+rowHeight+"px);min-height:"+gridHeight+"px'>"+cards+"</div>"+
  "</div>"+
 "</div>";
}

function luckyLoserHtml(rows){
 if(!Array.isArray(rows)||!rows.length)return "<div class='notice mini'><b>Lucky Losers :</b> l’ordre sera généré après les qualifications si une place se libère.</div>";
 return "<div class='card' style='margin-top:12px'><div class='row between'><h2>Ordre Lucky Loser</h2><span class='badge'>LL</span></div><div class='table-wrap'><table class='table'><thead><tr><th>Ordre</th><th>Joueur</th><th>Rang</th><th>Statut</th></tr></thead><tbody>"+
  rows.map(x=>"<tr "+(x.player_id?"class='click' onclick='openPlayer("+x.player_id+")'":"")+"><td>#"+fmt(x.ll_order||'—')+"</td><td>"+(flags[x.country]||'🏳️')+" <b>"+esc(x.name)+"</b></td><td>#"+fmt(x.ranking||'—')+"</td><td><span class='badge "+(x.selected?'good':'')+"'>"+(x.selected?'Repêché LL':'Réserve LL')+"</span></td></tr>").join('')+
  "</tbody></table></div></div>";
}

window.openTournament=async id=>{
 const fallback=[...(tourRows||[]),...(boot.upcoming||[]),...(scheduleAdvice?.recommended||[])].find(x=>x.id===id);if(!id)return;
 overlay.innerHTML='<div class="modal"><div class="sheet tm-tournament-sheet"><div class="loader">Chargement du tournoi…</div></div></div>';
 try{
  const activeTournamentPlayerId=activeManagedId()||primaryManagedPlayerId()||0;
  let d=await get('/api/tournament-detail?id='+id+'&player_id='+encodeURIComponent(activeTournamentPlayerId)),t=d.tournament||fallback;if(!t)throw new Error('Tournoi introuvable');
  if(['ATP','Challenger','ITF'].includes(String(t.circuit||''))){
   try{
    const access=await get('/api/tournament-entry-status?id='+encodeURIComponent(id)+'&player_id='+encodeURIComponent(activeManagedId()));
    d={...d,entry_rules:access.entry_rules??d.entry_rules,pathway_status:access.pathway_status??d.pathway_status,special_exempt_status:access.special_exempt_status??d.special_exempt_status,performance_bye_status:access.performance_bye_status??d.performance_bye_status};
    t={...t,...(access.tournament||{})};
   }catch{}
  }
  if(t.doubles){
   try{
    const dAccess=await get('/api/doubles-entry-status?id='+encodeURIComponent(id)+'&player_id='+encodeURIComponent(activeTournamentPlayerId));
    d={...d,doubles_entry_status:dAccess.doubles_entry_status??d.doubles_entry_status,managed_doubles_entry:dAccess.managed_doubles_entry??d.managed_doubles_entry};
   }catch{}
  }
  t.entry_rule_context=tournamentEntryContext();
  t.managed_entry_rules=d.entry_rules||null;
  t.managed_pathway_status=d.pathway_status||null;
  t.managed_special_exempt_status=d.special_exempt_status||null;
  t.managed_performance_bye_status=d.performance_bye_status||null;
  t.managed_wildcard_status=d.wildcard?.status||null;
  t.managed_doubles_entry_status=d.doubles_entry_status||null;
  t.nextgen_finals_status=d.nextgen_finals_status||null;
  tournamentDetailRows.set(Number(id),t);
  const cr=activePlayerCareerView(),wc=d.wildcard||null,isJunior=String(t.circuit)==='Junior',isNcaa=String(t.circuit)==='NCAA',isFed=String(t.circuit)==='Federation';
  const teamEvent=d.special_team_event||specialTeamEventMeta(t);
  const joined=(local.entries||[]).includes(t.id),dJoined=(local.doublesEntries||[]).includes(t.id);
  let singleRule=applyManagedPathwayEligibility(t,singlesEligibility(t)),doubleRule=doublesEligibility(t);
  const serverRun=d.run||null,doublesRun=d.doubles_run||null;
  const activePartner=activeDoublesPartner();
  const playedKey=String(activeTournamentPlayerId)+':'+String(t.id);
  const played=local.playedTournaments?.[playedKey]||(activeTournamentPlayerId===primaryManagedPlayerId()?local.playedTournaments?.[t.id]:null)||(serverRun?{user_round:serverRun.user_round,user_points:serverRun.user_points,user_prize:serverRun.user_prize}:null);
  const formatRule=d.format_rule||{};
  const qStructure=d.qualifying_structure||qualifyingStructureClient(formatRule,t);
  const pairs=[...(d.main||[])];
  if(formatRule.format_type==='knockout'&&['ATP','Challenger','ITF'].includes(String(t.circuit||''))){
    const expected=Math.max(0,Number(t.singles_draw_size||t.draw_size||formatRule.main_draw_size||0));
    let missing=Math.max(0,expected-pairs.length);
    const reserved=[
      [Math.max(0,Number(formatRule.special_exempt_slots||0)),'special_exempt_slot','Special Exempt / direct fallback'],
      [Math.max(0,Number(t.late_entry_slots||0)),'late_entry_slot','Late Entry / direct fallback'],
      [Math.max(0,Number(formatRule.junior_reserved_slots||0)),'junior_reserved_slot','Place junior réservée'],
      [Math.max(0,Number(formatRule.junior_accelerator_slots||0)),'junior_accelerator_slot','Next Gen Accelerator'],
      [Math.max(0,Number(formatRule.college_accelerator_slots||0)),'college_accelerator_slot','College Accelerator']
    ];
    for(const [count,method,label] of reserved){
      for(let i=1;i<=Number(count)&&missing>0;i++,missing--){
        pairs.push({id:null,name:String(label)+(Number(count)>1?' '+i:''),country:null,ranking:null,points:null,entry_method:String(method),projected:true,reserved_slot:true});
      }
    }
    while(missing>0){
      pairs.push({id:null,name:'Entry list / alternate',country:null,ranking:null,points:null,entry_method:'direct_fallback_slot',projected:true,reserved_slot:true});
      missing--;
    }
  }
  const ncaaPlayers=d.ncaa_players||[];
  const forfeits=d.forfeits||[];
  const completedDraw=d.completed_draw||[];
  const userQualifyingDraw=completedDraw.filter(m=>/^Q\d+$/.test(String(m.round_name||'')));
  const userMainDraw=completedDraw.filter(m=>!/^Q\d+$/.test(String(m.round_name||'')));
  const mainDrawMatches=userMainDraw.length?userMainDraw:(d.main_draw_bracket||d.main_draw_matches||d.world_completed_draw||[]);
  const qualifyingDraw=userQualifyingDraw.length?userQualifyingDraw:(d.qualifying_draw||[]);
  const luckyLosers=d.lucky_losers||[];
  const acceptanceList=d.acceptance_list||{};
  const acceptanceState=acceptanceList.state||null;
  const acceptanceMain=acceptanceList.main||[];
  const acceptanceAlternates=acceptanceList.alternates||[];
  const acceptanceWithdrawn=acceptanceList.withdrawn||[];
  const qualifyingAcceptanceList=d.qualifying_acceptance_list||{};
  const qualifyingAcceptanceState=qualifyingAcceptanceList.state||null;
  const qualifyingAcceptanceMain=qualifyingAcceptanceList.accepted||[];
  const qualifyingAcceptanceAlternates=qualifyingAcceptanceList.alternates||[];
  const qualifyingAcceptanceWithdrawn=qualifyingAcceptanceList.withdrawn||[];
  const drawTimeline=d.draw_timeline||[];
  const drawPhase=d.draw_phase||'entry_list';
  const projectedByeSlots=d.projected_bye_slots||[];
  const projectedBracketSize=Number(d.projected_bracket_size||t.singles_draw_size||t.draw_size||pairs.length||0);
  const doublesProjection=d.doubles_main||[],doublesCompleted=d.doubles_completed_draw||[];
  const worldDoublesEntries=d.doubles_world_entries||[],worldDoublesBracket=d.doubles_draw_bracket||[];
  const drawRounds=[...new Set(completedDraw.map(m=>m.round_name))];
  const editionHistory=d.tournament_history||[],doublesEditionHistory=d.tournament_doubles_history||[],historyRecords=d.tournament_history_records||{};
  const historyMajor=['Grand Chelem','Masters 1000','ATP 500','ATP 250','ATP Finals','Challenger 175','Challenger 125'].includes(String(t.category||''));
  const economics=d.economics||{currency:t.prize_currency||'USD',total:Number(t.prize_money||0),total_is_estimate:t.prize_money_is_estimate,format:t.prize_format,special:t.special_prize_components||{},singles_is_estimate:t.singles_prize_is_estimate,qualifying_is_estimate:t.qualifying_prize_is_estimate,doubles_is_estimate:t.doubles_prize_is_estimate,singles:t.singles_prize_by_result||{},qualifying:t.qualifying_prize_by_result||{},doubles:t.doubles_prize_by_result||{},source_label:t.prize_source_label||null,source_url:t.prize_source_url||null,note:t.prize_note||null};
  const entryProtection=t.managed_entry_rules?.protected?.protected_ranking||t.managed_entry_rules?.protected_qualifying?.protected_ranking||null;

  const managedId=Number(cr.managed_player_id||boot?.career?.managed_player_id||0);
  const managedJunior=pairs.find(p=>Number(p.id)===managedId);
  const isJuniorFinals=isJunior&&/Junior Finals/i.test(String(t.category||''))&&!/Double/i.test(String(t.category||''));
  const isJuniorDoubleFinals=/Junior Double Finals/i.test(String(t.category||''));
  const isAtpSinglesFinals=String(t.circuit)==='ATP'&&/ATP Finals/i.test(String(t.category||''))&&!/Next Gen/i.test(String(t.category||''))&&Boolean(t.singles);
  const isAtpDoubleFinals=String(t.circuit)==='ATP'&&/ATP Finals/i.test(String(t.category||''))&&Boolean(t.doubles);
  const isSinglesFinals=isJuniorFinals||isAtpSinglesFinals;
  const isDoublesFinals=isJuniorDoubleFinals||isAtpDoubleFinals;
  if(isJuniorFinals){
    const raceEntry=pairs.find(p=>Number(p.id)===managedId);
    singleRule=raceEntry
      ?{label:'Qualifié Race Junior #'+fmt(raceEntry.ranking||raceEntry.seed||'—'),cls:'good',can:true,phase:'finals'}
      :{label:'Non qualifié · Top 8 Race Junior requis',cls:'bad',can:false,phase:'finals'};
  }else if(isAtpSinglesFinals){
    const raceEntry=pairs.find(p=>Number(p.id)===managedId);
    singleRule=raceEntry
      ?{label:'Qualifié ATP Race #'+fmt(raceEntry.ranking||raceEntry.seed||'—'),cls:'good',can:true,phase:'finals'}
      :{label:'Non qualifié · Top 8 ATP Race requis',cls:'bad',can:false,phase:'finals'};
  }
  if(isDoublesFinals){
    const partnerId=Number(activePartner?.id||0);
    const racePair=doublesProjection.find(x=>{
      const a=Number(x.player_a?.id||0),b=Number(x.player_b?.id||0);
      return (a===managedId&&b===partnerId)||(a===partnerId&&b===managedId);
    });
    doubleRule=racePair
      ?{label:'Qualifié Race #'+fmt(racePair.race_rank||racePair.seed||'—'),cls:'good',can:true,phase:'finals'}
      :{label:'Non qualifié · Top 8 Race requis',cls:'bad',can:false,phase:'finals'};
  }
  const managedMainAccepted=acceptanceMain.find(p=>Number(p.id)===managedId);
  const managedMainAlt=acceptanceAlternates.find(p=>Number(p.id)===managedId);
  const managedQAccepted=qualifyingAcceptanceMain.find(p=>Number(p.id)===managedId);
  const managedQAlt=qualifyingAcceptanceAlternates.find(p=>Number(p.id)===managedId);
  const managedSelectedLL=luckyLosers.find(p=>Number(p.player_id||p.id)===managedId&&p.selected);
  const managedFrozenWithdrawn=[...acceptanceWithdrawn,...qualifyingAcceptanceWithdrawn].find(p=>Number(p.id)===managedId);
  const gameDate=String(local.date||cr.career_date||'2025-12-01');
  const mainPlayableOn=String(t.main_draw_start_date||t.start_date||gameDate);
  const qualifyingPlayableOn=String(t.qualifying_start_date||mainPlayableOn);
  const frozenCircuit=['ATP','Challenger','ITF'].includes(String(t.circuit||''));
  if(!isJunior&&!isSinglesFinals){
    if(managedSelectedLL){
      singleRule={...singleRule,label:'Lucky Loser · sélectionné'+(gameDate<mainPlayableOn?' · débute '+df(mainPlayableOn):''),method:'lucky_loser',phase:'main',cls:'good',can:gameDate>=mainPlayableOn,frozen:true};
    }else if(managedMainAccepted){
      singleRule={...singleRule,label:(managedMainAccepted.status==='promoted'?'ALT → tableau principal':'Tableau principal · accepté')+(gameDate<mainPlayableOn?' · débute '+df(mainPlayableOn):''),method:managedMainAccepted.status==='promoted'?'alternate':'direct',phase:'main',cls:'good',can:gameDate>=mainPlayableOn,frozen:true};
    }else if(managedQAccepted){
      singleRule={...singleRule,label:'Qualifications · accepté'+(managedMainAlt?' · ALT MD #'+fmt(managedMainAlt.acceptance_order):'')+(gameDate<qualifyingPlayableOn?' · débute '+df(qualifyingPlayableOn):''),method:'qualifying',phase:'qualifying',cls:'warn',can:gameDate>=qualifyingPlayableOn,frozen:true};
    }else if(managedQAlt){
      singleRule={...singleRule,label:'ALT Q #'+fmt(managedQAlt.acceptance_order)+(managedMainAlt?' · ALT MD #'+fmt(managedMainAlt.acceptance_order):'')+' · en attente de promotion',method:'alternate',phase:'qualifying_alternate',cls:'warn',can:false,frozen:true};
    }else if(managedMainAlt){
      singleRule={...singleRule,label:'ALT tableau #'+fmt(managedMainAlt.acceptance_order)+' · en attente de promotion',method:'alternate',phase:'main_alternate',cls:'warn',can:false,frozen:true};
    }else if(managedFrozenWithdrawn){
      singleRule={...singleRule,label:'Retiré de la liste figée',method:'withdrawn',phase:'withdrawn',cls:'bad',can:false,frozen:true};
    }
  }
  const rawElig=managedJunior&&!isSinglesFinals?(managedJunior.entry_method==='direct'?'Tableau direct junior':'Engagé junior'):singleRule.label;
  const elig=rawElig;
  const phasePlayableOn=singleRule.phase==='qualifying'?qualifyingPlayableOn:mainPlayableOn;
  const calendarReady=!frozenCircuit||gameDate>=phasePlayableOn;
  const canAttempt=!teamEvent&&(isSinglesFinals||(!isNcaa&&!isFed))&&singleRule.can&&calendarReady;
  const playWaitLabel=joined&&!played&&!canAttempt?(String(singleRule.phase||'').includes('alternate')?singleRule.label:(gameDate<phasePlayableOn?'Disponible à partir du '+df(phasePlayableOn):singleRule.label)):'';
  const cuts=tmCuts(t);

  const rankTitle=isJunior?'Junior':'ATP';
  const drawIntro=isJunior
    ?((d.junior_entries||[]).length?'Engagés/résultats vérifiés pour ce tournoi junior.':'Projection ITF Junior : admissions directes, places issues des qualifs et wild cards séparées.')
    :acceptanceState
      ?"Liste d’acceptation figée : les DA et ALT suivent maintenant l’ordre enregistré à la deadline."
      :"Avant la deadline, Court Boss affiche une projection à partir du classement et du cut.";
  const sourceLink=t.source_url?'<a class="soft-btn" href="'+esc(t.source_url)+'" target="_blank" rel="noopener noreferrer">Source officielle</a>':'';
  const detailPhoto=tournamentPhotoUrl(t);
  const detailPhotoLabel=t.image_source_label||'Photo du tournoi';

  const juniorResults=(d.junior_entries||[]).map(e=>{
    const p=Array.isArray(e.players)?e.players[0]:e.players;
    return p?`<div class="list-item row between"><div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">Junior #${p.junior_ranking||'—'} ${e.seed?'· TDS '+esc(e.seed):''}</div></div><b>${esc(e.result||'Engagé')}</b></div>`:'';
  }).join('');

  const acceptanceSnapshotHtml=!acceptanceState?"":`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Entry list figée · ${df(acceptanceState.frozen_on)}</div><h2>Acceptances & alternates</h2></div><span class="badge good">${acceptanceMain.length} DA · ${acceptanceAlternates.length} ALT</span></div><p class="muted mini">Dernier rafraîchissement ${df(acceptanceState.last_refreshed_on)}. Un ALT promu reste tracé, et un retrait post-qualifs alimente la route Lucky Loser.</p><div class="table-wrap"><table class="table"><thead><tr><th>Ordre</th><th>Entrée</th><th>Joueur</th><th>Rang entry</th><th>Statut</th></tr></thead><tbody>${acceptanceMain.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${fmt(p.acceptance_order)}</td><td><span class="badge ${p.status==="promoted"?"good":""}">${p.status==="promoted"?"ALT→DA":"DA"}</span></td><td>${flags[p.country]||"🏳️"} <b>${esc(p.name)}</b></td><td>${p.ranking&&p.ranking<999999?"#"+fmt(p.ranking):"—"}</td><td>${p.status==="promoted"?"Promu "+df(p.promoted_on):"Accepté"}</td></tr>`).join("")}</tbody></table></div><details style="margin-top:10px"><summary><b>Alternates (${acceptanceAlternates.length})</b></summary><div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>ALT</th><th>Joueur</th><th>Rang entry</th><th>Snapshot</th></tr></thead><tbody>${acceptanceAlternates.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${fmt(p.acceptance_order)}</td><td>${flags[p.country]||"🏳️"} <b>${esc(p.name)}</b></td><td>${p.ranking&&p.ranking<999999?"#"+fmt(p.ranking):"—"}</td><td>${df(p.snapshot_date)}</td></tr>`).join("")}</tbody></table></div></details>${acceptanceWithdrawn.length?`<details style="margin-top:10px"><summary><b>Retraits (${acceptanceWithdrawn.length})</b></summary>${acceptanceWithdrawn.map(p=>`<div class="list-item row between click" onclick="openPlayer(${p.id})"><div>${flags[p.country]||"🏳️"} <b>${esc(p.name)}</b><div class="muted mini">${esc(p.withdrawal_phase||"retrait")} · #${fmt(p.ranking)}</div></div><b>${p.withdrawn_on?df(p.withdrawn_on):"—"}</b></div>`).join("")}</details>`:""}</div>`;
  const qualifyingAcceptanceSnapshotHtml=!qualifyingAcceptanceState?"":`<div class="card" style="margin-bottom:12px"><div class="row between"><div><div class="eyebrow">Q entry list figée · ${df(qualifyingAcceptanceState.created_on)}</div><h2>Acceptés qualifs & ALT Q</h2></div><span class="badge good">${qualifyingAcceptanceMain.length} DA Q · ${qualifyingAcceptanceAlternates.length} ALT Q</span></div><p class="muted mini">Mouvements jusqu’au ${df(qualifyingAcceptanceState.movement_closes_on)}. Les wild cards Q restent séparées de cette liste. Un joueur promu dans le main draw est retiré de la Q-list et le prochain ALT Q monte.</p><div class="table-wrap"><table class="table"><thead><tr><th>Ordre</th><th>Entrée</th><th>Joueur</th><th>Rang entry</th><th>Statut</th></tr></thead><tbody>${qualifyingAcceptanceMain.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${fmt(p.acceptance_order)}</td><td><span class="badge ${p.status==="promoted"?"good":""}">${tournamentEntryCode(p.entry_method||"qualifying")}</span></td><td>${flags[p.country]||"🏳️"} <b>${esc(p.name)}</b></td><td>${p.ranking&&p.ranking<999999?"#"+fmt(p.ranking):"—"}</td><td>${p.status==="promoted"?"ALT Q → DA Q · "+df(p.promoted_on):"Accepté Q"}</td></tr>`).join("")}</tbody></table></div><details style="margin-top:10px"><summary><b>Alternates Q (${qualifyingAcceptanceAlternates.length})</b></summary><div class="table-wrap" style="margin-top:8px"><table class="table"><thead><tr><th>ALT Q</th><th>Joueur</th><th>Rang entry</th><th>Snapshot</th></tr></thead><tbody>${qualifyingAcceptanceAlternates.map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${fmt(p.acceptance_order)}</td><td>${flags[p.country]||"🏳️"} <b>${esc(p.name)}</b></td><td>${p.ranking&&p.ranking<999999?"#"+fmt(p.ranking):"—"}</td><td>${df(p.snapshot_date)}</td></tr>`).join("")}</tbody></table></div></details>${qualifyingAcceptanceWithdrawn.length?`<details style="margin-top:10px"><summary><b>Retraits Q (${qualifyingAcceptanceWithdrawn.length})</b></summary>${qualifyingAcceptanceWithdrawn.map(p=>`<div class="list-item row between click" onclick="openPlayer(${p.id})"><div>${flags[p.country]||"🏳️"} <b>${esc(p.name)}</b><div class="muted mini">${esc(p.withdrawal_reason||p.withdrawal_phase||"retrait Q")} · #${fmt(p.ranking)}</div></div><b>${p.withdrawn_on?df(p.withdrawn_on):"—"}</b></div>`).join("")}</details>`:""}</div>`;


  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet tm-tournament-sheet"><div class="sheet-head"><div class="tm-title-with-logo">${tournamentLogoHtml(t,'tm-detail-logo')}<div><div class="eyebrow">${esc(t.circuit||'Circuit')} · ${esc(t.category||t.level)}</div><h1>${flags[t.country]||'🏳️'} ${esc(t.name)}</h1><div class="muted">${esc(t.city||'')} · ${df(t.start_date)} → ${df(t.end_date)}</div></div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   ${detailPhoto?`<div class="tm-tour-hero"><img src="${esc(detailPhoto)}" alt="${esc(t.name)}" onerror="this.parentElement.style.display='none'"><div class="tm-tour-hero-overlay"><span class="badge ${circuitClass(t.circuit)}">${esc(t.category||t.circuit)}</span><span class="badge good">${esc(detailPhotoLabel)}</span></div></div>`:''}
   <div class="tm-tour-nav">
    <div class="tm-tour-tabs tm-tour-tabs-primary">
     ${!teamEvent&&!isNcaa&&t.singles?`<button data-tour-section="draw" onclick="tourSection('draw',this)">Simple</button>`:""}
     ${!teamEvent&&!isNcaa&&Number(t.qualifying_draw_size||0)>0?`<button data-tour-section="qual" onclick="tourSection('qual',this)">Qualifications</button>`:""}
     ${!teamEvent&&!isNcaa&&t.doubles?`<button data-tour-section="double" onclick="tourSection('double',this)">Double</button>`:""}
     ${isNcaa?`<button data-tour-section="ncaa" onclick="tourSection('ncaa',this)">NCAA / ITA</button>`:""}
    </div>
    <div class="tm-tour-tabs tm-tour-tabs-secondary">
     <button data-tour-section="overview" onclick="tourSection('overview',this)">Infos</button>
     ${(Number(economics.total||0)>0||economics.format==="none"||economics.note)?`<button data-tour-section="prize" onclick="tourSection('prize',this)">Dotations</button>`:""}
     ${editionHistory.length?`<button data-tour-section="history" onclick="tourSection('history',this)">Histoire</button>`:""}
     ${!teamEvent&&!isNcaa?`<button data-tour-section="forfeits" onclick="tourSection('forfeits',this)">Forfaits ${forfeits.length}</button>`:""}
     ${(completedDraw.length||juniorResults)?`<button data-tour-section="results" onclick="tourSection('results',this)">Résultats</button>`:""}
    </div>
   </div>
   <div id="tourBody">
    ${teamEvent?`<div class="notice"><b>${esc(teamEvent.label)}</b> · ${esc(teamEvent.format)}<br><span class="muted mini">${esc(teamEvent.tie||"")}${teamEvent.scoring?" · "+esc(teamEvent.scoring):""} · ${esc(teamEvent.selection||"")}</span></div>`:""}
    ${teamEvent?.code==='laver_cup'?laverCaptainPanel(teamEvent):''}
    <div class="grid g2">
      <div class="card"><div class="row between"><h2>${isNcaa?'Accès NCAA':isFed?'Sélection':isJunior?'Circuit Junior':'Inscription simple'}</h2><span class="badge ${singleRule.cls}">${esc(elig)}</span></div>
        <div class="list-item row between"><span>Cut tableau</span><b>${cuts.direct?'#'+fmt(cuts.direct)+(cuts.projected?' · projeté':''):'—'}</b></div>
        <div class="list-item row between"><span>Cut qualifs</span><b>${cuts.qual?'#'+fmt(cuts.qual)+(cuts.projected?' · projeté':''):'—'}</b></div>
        <div class="list-item row between"><span>Deadline simple</span><b>${t.singles_entry_deadline?df(t.singles_entry_deadline):'—'}</b></div>
        <div class="list-item row between"><span>Deadline qualifs</span><b>${t.qualifying_entry_deadline?df(t.qualifying_entry_deadline):'—'}</b></div>
        ${Number(t.late_entry_slots||0)>0?`<div class="list-item row between"><span>Late Entry</span><b>${t.late_entry_deadline?df(t.late_entry_deadline):'—'} · ${fmt(t.late_entry_slots)} slot</b></div>`:''}
        ${wc&&!isNcaa&&!isFed?`<div class="list-item row between"><span>Wild card</span><span class="badge ${wc.status==='accepted'?'good':wc.status==='declined'?'bad':''}">${esc(wc.status)}</span></div>`:''}
        ${t.entry_rule_note?`<div class="notice mini" style="margin-top:9px"><b>Règle :</b> ${esc(t.entry_rule_note)}</div>`:''}
        <div class="row" style="margin-top:10px;flex-wrap:wrap">${sourceLink}${isNcaa?`<button class="soft-btn" onclick="closeOverlay();nav('university')">Voir mon université</button>`:isFed?`<button class="soft-btn" onclick="closeOverlay();nav('davis')">Voir la sélection</button>`:isSinglesFinals?(singleRule.can?`${!played?`<button class="primary" onclick="openTournamentPlayMode(${t.id})">Jouer / simuler les Finals</button>`:''}<span class="badge good">Qualification automatique par la Race</span>`:`<span class="badge bad">${esc(singleRule.label)}</span>`):(singleRule.can||joined)?`<button class="${joined?'danger-btn':'primary'}" onclick="toggleSinglesEntry(${t.id}).then(()=>closeOverlay())">${joined?'Retirer le simple':'Inscription simple'}</button>${joined&&!played&&canAttempt?`<button class="primary" onclick="openTournamentPlayMode(${t.id})">Jouer / simuler</button>`:''}`:`<span class="badge bad">${esc(singleRule.label)}</span>${singleRule.canWildcard?`<button class="soft-btn" onclick="requestWildcard(${t.id})">Demander une wild card</button>`:''}`}</div>
        ${played?`<div class="notice" style="margin-top:10px"><b>Résultat :</b> ${esc(played.user_round)} · +${played.user_points} pts · +${money(played.user_prize,t.prize_currency||'USD')}</div>`:''}
      </div>
      <div class="card"><h2>Format & calendrier</h2><div class="list-item row between"><span>Surface</span><b class="${surfaceClass(surfaceLabel(t))}">${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Tableau simple</span><b>${t.singles_draw_size||t.draw_size||'—'}</b></div><div class="list-item row between"><span>Qualifs</span><b>${isSinglesFinals?'Top 8 Race · qualification automatique':t.qualifying_draw_size||'—'}</b></div>${t.qualifying_start_date?`<div class="list-item row between"><span>Dates qualifs</span><b>${df(t.qualifying_start_date)} → ${df(t.qualifying_end_date||t.qualifying_start_date)}</b></div>`:''}<div class="list-item row between"><span>Début tableau principal</span><b>${df(t.main_draw_start_date||t.start_date)}</b></div><div class="list-item row between"><span>Tableau double</span><b>${t.doubles?t.doubles_draw_size||t.draw_size||'—':'Non'}</b></div>${(isSinglesFinals||isDoublesFinals)?'<div class="list-item row between"><span>Format Finals</span><b>2 groupes de 4 · demi-finales · finale</b></div>':''}<div class="list-item row between"><span>Points vainqueur</span><b>${isJuniorFinals?'1 000':t.winner_points!=null?fmt(t.winner_points):'—'}</b></div><div class="list-item row between"><span>Prize money</span><b>${t.prize_money!=null?tournamentPrizeLabel(t):'—'}</b></div><div class="list-item row between"><span>Donnée</span><b>${t.is_verified?'Officielle':'Fictive Court Boss'}</b></div></div>
      <div class="card"><div class="row between"><div><div class="eyebrow">Historique</div><h2>Tenant du titre</h2></div><span class="badge">${t.defending_champion_year||'—'}</span></div>
       ${t.defending_champion_name?`<div class="list-item row between"><span>Simple</span><b class="click" ${t.defending_champion_player_id?`onclick="openPlayer(${t.defending_champion_player_id})"`:''}>🏆 ${esc(t.defending_champion_name)}</b></div>`:`<div class="list-item row between"><span>Simple</span><b>${t.defending_champion_source&&/première édition/i.test(t.defending_champion_source)?'Première édition':'—'}</b></div>`}
       ${t.defending_doubles_champion_name?`<div class="list-item row between"><span>Double</span><b>🏆 ${esc(t.defending_doubles_champion_name)} / ${esc(t.defending_doubles_partner_name||'')}</b></div>`:''}
       ${t.defending_champion_source?`<div class="muted micro" style="margin-top:8px">${esc(t.defending_champion_source)}</div>`:''}
      </div>
    </div>
    ${t.doubles&&!isNcaa?`<div class="card" style="margin-top:12px"><div class="row between"><div><div class="eyebrow">Inscription double</div><h2>${activePartner?esc(activePartner.name):'Partenaire requis'}</h2></div><span class="badge ${doubleRule.cls}">${esc(doubleRule.label)}</span></div><div class="list-item row between"><span>Ton rang double</span><b>#${fmt(cr.doubles_rank||0)}</b></div>${activePartner?`<div class="list-item row between"><span>Partenaire</span><b>#${fmt(activePartner.doubles_ranking||0)} · ${esc(activePartner.name)}</b></div>`:''}<div class="list-item row between"><span>Advance entry double</span><b>${t.doubles_entry_deadline?df(t.doubles_entry_deadline):String(t.entry_rule_code)==='ITF_M15'?'Aucune':'—'}</b></div><div class="list-item row between"><span>On-site sign-in</span><b>${t.doubles_onsite_deadline?df(t.doubles_onsite_deadline):'—'}</b></div>${doubleRule.bestCombinedRank?`<div class="list-item row between"><span>Rang combiné best-of</span><b>${fmt(doubleRule.bestCombinedRank)}</b></div><div class="list-item row between"><span>Cut projeté</span><b>${doubleRule.projectedCut?fmt(doubleRule.projectedCut):'—'}</b></div>`:''}${doubleRule.protectedRanking?.available?`<div class="list-item row between"><span>PR double</span><b>#${fmt(doubleRule.protectedRanking.protected_rank)} · ${fmt(doubleRule.protectedRanking.uses_remaining)} utilisation(s)</b></div>${doubleRule.useProtectedRanking?`<div class="notice good mini" style="margin-top:6px"><b>PR utilisé pour cette entrée.</b> Rang combiné protégé : ${fmt(doubleRule.protectedCombinedRank||0)}.</div>`:''}`:''}${doublesRun?`<div class="notice good"><b>Déjà joué :</b> ${esc(doublesRun.user_round)} · +${doublesRun.user_points||0} pts · +${euro(doublesRun.user_prize||0)}</div>`:isDoublesFinals?(doubleRule.can?`<button class="primary" style="width:100%;margin-top:8px" onclick="playDoublesTournament(${t.id})">Jouer / simuler les Finals double</button><div class="notice good mini" style="margin-top:8px">Qualification automatique par la Race de la paire.</div>`:`<div class="notice bad mini" style="margin-top:8px">${esc(doubleRule.label)}</div><button class="soft-btn" style="width:100%;margin-top:8px" onclick="closeOverlay();nav('doubles')">Voir la Race Double</button>`):doubleRule.can?`<button class="${dJoined?'danger-btn':'primary'}" style="width:100%;margin-top:8px" onclick="toggleDoublesEntry(${t.id});closeOverlay()">${dJoined?'Retirer le double':'Inscrire la paire'}</button>`:`<button class="soft-btn" style="width:100%;margin-top:8px" onclick="closeOverlay();nav('doubles')">${activePartner?'Voir le hub Double':'Choisir un partenaire'}</button>`}</div>`:''}
   </div>

   <template id="tourOverviewTpl"><div class="grid g2"><div class="card"><h2>${isNcaa?'Accès NCAA / ITA':isJunior?'Circuit Junior':'Entrée'}</h2>${isNcaa?`<div class="list-item row between"><span>Mode d’accès</span><b>${esc(singleRule.label)}</b></div><div class="list-item row between"><span>Inscription libre</span><b>Non</b></div><div class="list-item row between"><span>Profils NCAA indexés</span><b>${fmt(ncaaPlayers.length)}</b></div>${t.entry_rule_note?`<div class="notice mini" style="margin-top:8px">${esc(t.entry_rule_note)}</div>`:''}`:isJunior?`<div class="list-item row between"><span>Classement</span><b>ITF Junior</b></div><div class="list-item row between"><span>Engagés connus</span><b>${pairs.length}</b></div>`:`<div class="list-item row between"><span>Cut tableau</span><b>${cuts.direct?'#'+fmt(cuts.direct)+(cuts.projected?' · proj.':''):'—'}</b></div><div class="list-item row between"><span>Cut qualifs</span><b>${cuts.qual?'#'+fmt(cuts.qual)+(cuts.projected?' · proj.':''):'—'}</b></div><div class="list-item row between"><span>Ton statut</span><b>${elig}</b></div>${entryProtection?.available?`<div class="list-item row between"><span>Classement protégé</span><b>#${fmt(entryProtection.protected_rank)} · ${fmt(entryProtection.uses_remaining)} utilisation(s)</b></div><div class="muted micro">Activation jusqu’au ${entryProtection.activation_deadline?df(entryProtection.activation_deadline):'—'}${entryProtection.active_until?' · actif jusqu’au '+df(entryProtection.active_until):''}</div>`:''}`}${managedRegulatoryPathwaysHtml(t,formatRule)}</div><div class="card"><h2>Format</h2><div class="list-item row between"><span>Tableau / champ</span><b>${t.singles_draw_size||t.draw_size||'—'}</b></div><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Référence</span><b>${t.is_verified?'Officielle':'Simulation'}</b></div><div class="list-item row between"><span>Simple / Double</span><b>${t.singles?'S':''}${t.singles&&t.doubles?' + ':''}${t.doubles?'D':''}</b></div></div></div></template>

   <template id="tourPrizeTpl">${tournamentEconomicsHtml(economics,t,d.format_rule||{})}</template>

   <template id="tourNcaaTpl"><div class="card"><div class="row between"><div><div class="eyebrow">Circuit universitaire</div><h2>Vivier NCAA · ITA + profondeur Court Boss + UTR</h2></div><span class="badge">${fmt(ncaaPlayers.length)} profils</span></div><p class="muted mini">Le classement ITA officiel est affiché sans préfixe. La profondeur simulée Court Boss commence après le Top 125 et reste précédée de <b>~</b> : <b>~#126 CB</b> n’est jamais présenté comme ITA #126. L’UTR reste une mesure séparée.</p><div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>Classement</th><th>Source rang</th><th>Joueur</th><th>Université</th><th>UTR</th><th>ATP</th></tr></thead><tbody>${ncaaPlayers.slice(0,150).map(p=>{const rp=ncaaRankPresentation(p);return `<tr class="click" onclick="openPlayer(${p.id})"><td class="rank-num">${esc(rp.value)}</td><td><span class="badge ${rp.kind==='official'?'good':rp.kind==='simulated_depth'?'warn':''}">${rp.kind==='official'?'ITA officiel':rp.kind==='simulated_depth'?'Projection CB':'NCAA'}</span></td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${esc(p.school||p.ncaa_school||'—')}</td><td>${p.utr_rating!=null?'<b>'+(p.utr_verified?'':'~')+Number(p.utr_rating).toFixed(2)+'</b>':'—'}</td><td>${p.ranking?'#'+fmt(p.ranking):'—'}</td></tr>`}).join('')}</tbody></table></div>${!ncaaPlayers.length?'<div class="empty">Aucun profil NCAA relié à ce snapshot.</div>':''}</div></template>

   <template id="tourDrawTpl">
    ${tournamentBracketHtml(mainDrawMatches,pairs,projectedByeSlots,projectedBracketSize,isJunior?'Tableau Junior':'Tableau principal',{managedId})}
    <details class="card tm-tour-detail-drawer" style="margin-top:12px">
     <summary><b>Entry list, calendrier et format</b><span class="muted mini">DA · WC · Q · LL · ALT · SE · PB</span></summary>
     <div style="margin-top:12px">${tournamentTimelineHtml(drawTimeline,drawPhase)}${acceptanceSnapshotHtml}</div>
     <div class="table-wrap"><table class="table"><thead><tr><th>Slot</th><th>TDS</th><th>Entrée</th><th>Joueur</th><th>Rang</th></tr></thead><tbody>${pairs.slice().sort((a,b)=>Number(a.draw_slot||9999)-Number(b.draw_slot||9999)).map(p=>`<tr ${p.id?`class="click" onclick="openPlayer(${p.id})"`:''}><td>${p.draw_slot||'—'}</td><td>${p.seed?'#'+p.seed:'—'}</td><td><span class="badge ${p.withdrawn_pending?'bad':''}">${tournamentEntryCode(p.entry_method)}</span></td><td>${p.withdrawn_pending?'<span class="bad"><b>Vacance · remplacement en attente</b></span>':(flags[p.country]||'🏳️')+' <b>'+esc(p.name)+'</b>'}</td><td>${p.ranking&&p.ranking<999999?'#'+fmt(p.ranking):'—'}</td></tr>`).join('')}</tbody></table></div>
     ${tournamentFormatHtml(formatRule,t,qStructure)}
    </details>
   </template>

   <template id="tourQualTpl">
    ${tournamentBracketHtml(qualifyingDraw,d.qualifying||[],[],Number(qStructure?.bracket_total||0),'Tableau des qualifications',{managedId,sectionCount:Number(qStructure?.qualifier_slots||1),sectionBracket:Number(qStructure?.section_bracket||0),roundCount:Math.max(1,Math.round(Math.log2(Math.max(2,Number(qStructure?.section_bracket||2))))),rowHeight:30})}
    <details class="card tm-tour-detail-drawer" style="margin-top:12px">
     <summary><b>Liste des qualifs et Lucky Losers</b><span class="muted mini">${qStructure?.seed_count!=null?fmt(qStructure.seed_count)+' TDS':''}</span></summary>
     <div style="margin-top:12px">${tournamentTimelineHtml(drawTimeline,drawPhase)}${qualifyingAcceptanceSnapshotHtml}</div>
     ${t.qualifying_start_date?`<p class="muted mini">Du ${df(t.qualifying_start_date)} au ${df(t.qualifying_end_date||t.qualifying_start_date)}. Les Q gagnent leur place dans le main draw, les perdants éligibles alimentent l’ordre LL.</p>`:''}
     <div class="table-wrap"><table class="table"><thead><tr><th>Rang</th><th>Entrée</th><th>Joueur</th><th>Statut</th></tr></thead><tbody>${(d.qualifying||[]).map(p=>`<tr class="click" onclick="openPlayer(${p.id})"><td>#${fmt(p.ranking)}</td><td><span class="badge">${tournamentEntryCode(p.entry_method)}</span></td><td>${flags[p.country]||'🏳️'} <b>${esc(p.name)}</b></td><td>${p.qualified?'<span class="badge good">Q</span>':esc(p.result||((p.fitness??'—')+'% / fatigue '+(p.fatigue??'—')+'%'))}</td></tr>`).join('')}</tbody></table></div>
     ${luckyLoserHtml(luckyLosers)}
     ${tournamentFormatHtml(formatRule,t,qStructure)}
    </details>
   </template>

   <template id="tourDoubleTpl">
    ${worldDoublesBracket.length?tournamentBracketHtml(worldDoublesBracket,worldDoublesEntries,[],Number(t.doubles_draw_size||worldDoublesEntries.length||0),'Tableau double',{managedIds:[managedId,Number(activePartner?.id||0)].filter(Boolean)}):`<div class="tm-bracket-card"><div class="tm-bracket-empty"><div class="eyebrow">Tableau double</div><h2>Tirage à publier</h2><div class="muted">La projection des paires est disponible ci-dessous. Le bracket complet apparaîtra dès que le moteur mondial publie les positions.</div></div></div>`}
    <div class="grid g2" style="margin-top:12px">
     <div class="card"><div class="eyebrow">Partenariat</div><h2>${activePartner?flags[activePartner.country]||'🏳️':''} ${activePartner?esc(activePartner.name):'Aucun partenaire'}</h2><div class="list-item row between"><span>Ton classement</span><b>#${fmt(cr.doubles_rank||0)}</b></div>${activePartner?`<div class="list-item row between"><span>Partenaire</span><b>#${fmt(activePartner.doubles_ranking||0)}</b></div><div class="list-item row between"><span>Chimie</span><b>${pairScore(activePartner,'chem')}%</b></div>`:''}</div>
     <div class="card"><div class="eyebrow">Tournoi</div><h2>${esc(t.name)} · Double</h2><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Catégorie</span><b>${esc(t.category||t.level||'—')}</b></div>${doublesRun?`<div class="notice good"><b>Résultat :</b> ${esc(doublesRun.user_round)} · +${doublesRun.user_points||0} pts</div>`:isDoublesFinals?(doubleRule.can&&activePartner?`<button class="primary" style="width:100%;margin-top:10px" onclick="playDoublesTournament(${t.id})">Jouer / simuler les Finals double</button>`:`<div class="notice bad mini" style="margin-top:8px">${esc(doubleRule.label)}</div>`):activePartner?(dJoined?`<button class="primary" style="width:100%;margin-top:10px" onclick="playDoublesTournament(${t.id})">Jouer / simuler le double</button>`:`<button class="soft-btn" style="width:100%;margin-top:10px" onclick="toggleDoublesEntry(${t.id})">Inscrire la paire avant de jouer</button>`):`<button class="soft-btn" style="width:100%;margin-top:10px" onclick="closeOverlay();nav('doubles')">Choisir un partenaire</button>`}</div>
    </div>
    <details class="card tm-tour-detail-drawer" style="margin-top:12px">
     <summary><b>Paires engagées / projection</b><span class="muted mini">${doublesProjection.length}/${t.doubles_draw_size||doublesProjection.length} équipes</span></summary>
     <div class="table-wrap" style="margin-top:10px"><table class="table"><thead><tr><th>TDS</th><th>Équipe</th><th>Rangs double</th><th>Source</th></tr></thead><tbody>${doublesProjection.map(x=>`<tr><td>${x.seed?'#'+x.seed:'—'}</td><td><b>${flags[x.player_a?.country]||'🏳️'} ${esc(x.player_a?.name)} / ${flags[x.player_b?.country]||'🏳️'} ${esc(x.player_b?.name)}</b></td><td>#${fmt(x.player_a?.doubles_ranking||0)} / #${fmt(x.player_b?.doubles_ranking||0)}</td><td><span class="badge">${esc(x.source||'Projection')}</span></td></tr>`).join('')}</tbody></table></div>
    </details>
   </template>

   <template id='tourHistoryTpl'>
    <div class='card'>
      <div class='row between'><div><div class='eyebrow'>Archives du tournoi</div><h2>Palmarès année par année</h2></div><span class='badge'>${editionHistory.length} édition${editionHistory.length>1?'s':''}</span></div>
      <div class='kpi-strip' style='margin-top:10px'>
        <div class='kpi'><span class='muted mini'>Record de titres</span><b style='font-size:14px'>${historyRecords.most_titles_name?esc(historyRecords.most_titles_name):'—'}</b><small class='muted micro'>${historyRecords.most_titles?fmt(historyRecords.most_titles)+' titre(s)':''}</small></div>
        <div class='kpi'><span class='muted mini'>Dernier vainqueur</span><b style='font-size:14px'>${historyRecords.latest_winner?esc(historyRecords.latest_winner):'—'}</b><small class='muted micro'>${historyRecords.latest_season||''}</small></div>
        <div class='kpi'><span class='muted mini'>Couverture</span><b>${editionHistory.length?editionHistory[editionHistory.length-1].season+'–'+editionHistory[0].season:'—'}</b></div>
        <div class='kpi'><span class='muted mini'>Niveau</span><b style='font-size:13px'>${esc(t.category||t.level||'—')}</b></div>
      </div>
      ${historyMajor?'<div class="notice mini" style="margin-top:10px"><b>Historique FM :</b> vainqueurs et finalistes issus des archives Court Boss / Tennis Abstract quand disponibles. Les changements de sponsor sont regroupés sous le même tournoi.</div>':''}
      <div class='table-wrap' style='margin-top:10px'><table class='table'><thead><tr><th>Année</th><th>Vainqueur</th><th>Finaliste</th><th>Score</th><th>Surface</th></tr></thead><tbody>
       ${editionHistory.map(h=>'<tr><td class="rank-num">'+h.season+'</td><td>'+(h.winner_player_id?'<b class="click" onclick="openPlayer('+h.winner_player_id+')">🏆 '+esc(h.winner_name)+'</b>':'<b>🏆 '+esc(h.winner_name||'—')+'</b>')+'</td><td>'+(h.runner_up_player_id?'<span class="click" onclick="openPlayer('+h.runner_up_player_id+')">'+esc(h.runner_up_name||'—')+'</span>':esc(h.runner_up_name||'—'))+'</td><td class="muted mini">'+esc(h.score||'—')+'</td><td>'+esc(h.surface||'—')+'</td></tr>').join('')}
      </tbody></table></div>
      ${tournamentDoublesHistoryHtml(doublesEditionHistory)}
    </div>
   </template>
   <template id="tourForfeitsTpl"><div class="card"><h2>Forfaits</h2>${forfeits.length?forfeits.map(x=>{const p=Array.isArray(x.players)?x.players[0]:x.players;return `<div class="list-item row between">${p?`<div class="click" onclick="openPlayer(${p.id})"><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${isJunior?'Junior':'ATP'} #${p.junior_ranking||p.ranking||'—'}</div></div>`:'<div>Joueur indisponible</div>'}<span class="badge bad">${esc(x.reason||'Blessure')}</span></div>`}).join(''):'<div class="empty">Aucun forfait enregistré.</div>'}</div></template>

   <template id="tourResultsTpl">${isJunior&&juniorResults?`<div class="card"><h2>Résultats / statut des engagés</h2>${juniorResults}</div>`:''}<div class="stack">${drawRounds.map(r=>`<div class="card"><h2>${esc(r)}</h2>${completedDraw.filter(m=>m.round_name===r).map(m=>`<div class="list-item"><div class="row between"><div><div ${m.player_a_id?`class="click" onclick="openPlayer(${m.player_a_id})"`:''}>${esc(m.player_a_name)}</div><div ${m.player_b_id?`class="click" onclick="openPlayer(${m.player_b_id})"`:''}>${esc(m.player_b_name)}</div></div><div style="text-align:right"><b>${esc(m.score)}</b><div class="muted mini">Vainqueur : ${esc(m.winner_name)}</div></div></div></div>`).join('')}</div>`).join('')}</div></template>
  </div></div>`;
  requestAnimationFrame(()=>window.tourSection(isNcaa?'ncaa':teamEvent?'overview':'draw'));
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Erreur tournoi</h2><p>${esc(e.message)}</p></div></div>`}
}
window.requestWildcard=async id=>{
 try{
   const d=await managerAction('request_wildcard',id,{player_id:activeManagedId()});
   alert(d.status==='accepted'?'Wild card accordée. Tu peux entrer dans le tableau.':'Wild card refusée pour ce tournoi.');
   await openTournament(id);
 }catch(e){alert(e.message)}
}
window.openTournamentPlayMode=id=>{
 const t=(tourRows||[]).find(x=>Number(x.id)===Number(id))||{};
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet tournament-play-mode">
  <div class="sheet-head"><div><div class="eyebrow">Mode de match</div><h1>${esc(t.name||'Tournoi')}</h1><div class="muted">Choisis ton niveau d’implication. Le Match Center garde le résultat provisoire jusqu’à validation.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  <div class="match-mode-grid">
   <button class="match-mode-card live" onclick="startTournamentLiveMatch(${Number(id)},false)"><span>JOUER</span><b>Match Center live</b><small>Point par point, coaching, météo, surface, humeur et terrain du tournoi.</small></button>
   <button class="match-mode-card quick" onclick="startTournamentLiveMatch(${Number(id)},true)"><span>SIMULER</span><b>Prochain match</b><small>Résultat rapide avec le même moteur. Tu valides ou annules ensuite.</small></button>
   <button class="match-mode-card tournament" onclick="playTournament(${Number(id)})"><span>TOURNOI</span><b>Simulation complète</b><small>Simule tout le tableau comme avant, avec checkpoint avant simulation.</small></button>
  </div>
 </div></div>`;
};
window.rollbackTournamentSimulation=async()=>{
 if(!confirm('Annuler cette simulation et revenir exactement avant le tournoi ?'))return;
 try{await rollbackUnsavedLiveBatchOnStartup();await reloadAfterRollback()}catch(e){alert(e.message)}
};
window.saveTournamentSimulation=async()=>{
 const d=await saveCareerSlot(9,'quick',true);
 if(d?.ok===false)return alert('Sauvegarde impossible : '+(d.error||d.reason||'erreur'));
 clearPendingLiveRollback();closeOverlay();alert('Simulation validée et sauvegardée.');
};

window.playTournament=async id=>{
  overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Création du checkpoint puis simulation du tournoi…</div></div></div>';
  try{
    await ensureLivePreMatchCheckpoint();
    const playPlayerId=activeManagedId()||primaryManagedPlayerId()||0;
    const d=await get('/api/play-tournament',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tournament_id:id,player_id:playPlayerId,tactics:local.tactics||{}})});
    local.playedTournaments=local.playedTournaments||{};local.playedTournaments[String(playPlayerId)+':'+String(id)]=d;
    boot=await get('/api/bootstrap');
    if(boot.career){
      local.career={...(local.career||{}),budget:boot.career.budget};
      if(playPlayerId===primaryManagedPlayerId()){
        local.career={...local.career,points:boot.career.points,singles_rank:boot.career.singles_rank,fatigue:boot.career.fatigue,fitness:boot.career.fitness,form:boot.career.form,morale:boot.career.morale};
      }
    }
    local.entries=(local.entries||[]).filter(x=>Number(x)!==Number(id));
    if(local.entryMeta)delete local.entryMeta[id];
    if(playPlayerId===primaryManagedPlayerId())mergeServerSinglesEntries(boot.entries||[]);else await loadActiveManagedContext(true,playPlayerId).catch(()=>{});
    tournamentDetailRows.clear();
    await Promise.all([loadRankings(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadTournaments()]);
    persist();
    const playedName=String(d.managed_player_name||activePlayerCareerView().player_name||'Joueur');
    overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(d.tournament?.name||'Tournoi')}</div><h1>${d.user_round==='Champion'?'🏆 Champion':esc(d.user_round)}</h1><div class="muted">${esc(playedName)} · Champion du tournoi : ${esc(d.champion?.name||'—')}</div><div class="row" style="margin-top:6px">${d.wildcard?'<span class="badge good">Wild Card</span>':''}${d.alternate?'<span class="badge warn">Alternate entré</span>':''}${d.lucky_loser?'<span class="badge warn">Lucky Loser</span>':''}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
      <div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Tour atteint</span><b style="font-size:16px">${esc(d.user_round)}</b></div><div class="kpi"><span class="muted mini">Points</span><b>+${d.user_points}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${money(d.user_prize,d.tournament?.prize_currency||'USD')}</b><small class="muted">${d.user_prize_eur!=null?'Crédit budget '+euro(d.user_prize_eur):''}</small></div><div class="kpi"><span class="muted mini">Voyage</span><b>-${euro(d.travel_cost||0)}</b></div></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">Fatigue ajoutée</span><b>+${d.fatigue_added||0}</b></div><div class="kpi"><span class="muted mini">Fitness après</span><b>${d.fitness||activePlayerCareerView().fitness}%</b></div><div class="kpi"><span class="muted mini">Matchs tableau</span><b>${d.draw_matches}</b></div><div class="kpi"><span class="muted mini">Décision</span><b style="font-size:13px">${(d.fatigue_added||0)>20?'Récupération conseillée':'Charge gérable'}</b></div></div>
      <div class="notice warn" style="margin-top:12px"><b>Simulation non sauvegardée.</b> Valide-la pour la garder, ou annule pour revenir exactement avant le tournoi.</div>
      <div class="fm-result-controls"><button class="primary" onclick="saveTournamentSimulation()">Valider & sauvegarder</button><button class="danger-btn" onclick="rollbackTournamentSimulation()">Annuler la simulation</button></div>
      <div class="card" style="margin-top:12px"><h2>Parcours de ${esc(playedName)}</h2>${(d.matches||[]).map(m=>`<div class="list-item"><div class="row between"><b>${esc(m.round_name)}</b><span class="badge ${m.winner_name===playedName?'good':'bad'}">${m.winner_name===playedName?'Victoire':'Défaite'}</span></div><div>${esc(m.player_a_name)} vs ${esc(m.player_b_name)}</div><div class="muted mini">${esc(m.score)}</div>${m.stats?`<div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted mini">1res balles</span><b>${m.stats.first_serve_pct}%</b></div><div class="kpi"><span class="muted mini">Winners</span><b>${m.stats.winners}</b></div><div class="kpi"><span class="muted mini">Fautes</span><b>${m.stats.unforced_errors}</b></div><div class="kpi"><span class="muted mini">Filet</span><b>${m.stats.net_points_won_pct}%</b></div></div>`:''}</div>`).join('')||'<div class="empty">Aucun match utilisateur.</div>'}</div>
    </div></div>`;
  }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Tournoi impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`}
}
window.playDoublesTournament=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Simulation du tableau double…</div></div></div>';
 try{
  const playPlayerId=activeManagedId()||primaryManagedPlayerId()||0;
  const d=await get('/api/play-doubles',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tournament_id:id,player_id:playPlayerId,doubles_tactics:local.doublesTactics||{plan:'balanced'}})});
  boot=await get('/api/bootstrap');
  if(boot.career){
   local.career={...(local.career||{}),budget:boot.career.budget};
   if(playPlayerId===primaryManagedPlayerId())local.career={...local.career,doubles_rank:boot.career.doubles_rank,doubles_points:boot.career.doubles_points,fatigue:boot.career.fatigue,fitness:boot.career.fitness};
  }
  local.doublesEntries=(local.doublesEntries||[]).filter(x=>Number(x)!==Number(id));
  if(local.doublesEntryMeta)delete local.doublesEntryMeta[id];
  if(playPlayerId===primaryManagedPlayerId())mergeServerDoublesEntries(boot.doublesEntries||[]);else await loadActiveManagedContext(true,playPlayerId).catch(()=>{});
  tournamentDetailRows.clear();
  await Promise.all([loadManagement(),loadSeasonSummary(),loadDoublesHub(),loadTournaments()]);
  persist();
  const doublesPlayedName=String(d.managed_player_name||activePlayerCareerView().player_name||'Joueur');
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(d.tournament?.name||'Double')}</div><h1>${d.round==='Champion'?'🏆 Champions':esc(d.round)}</h1><div class="muted">${esc(doublesPlayedName)} avec ${esc(d.partner?.name||'partenaire')} · nouveau rang double ${d.rank?'#'+fmt(d.rank):'NR'}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="kpi-strip" style="margin-top:12px"><div class="kpi"><span class="muted mini">Tour</span><b>${esc(d.round)}</b></div><div class="kpi"><span class="muted mini">Points double</span><b>+${d.points||0}</b></div><div class="kpi"><span class="muted mini">Prize money</span><b>${money(d.prize||0,d.tournament?.prize_currency||'USD')}</b><small class="muted">${d.prize_eur!=null?'Crédit budget '+euro(d.prize_eur):''}</small></div><div class="kpi"><span class="muted mini">Fatigue</span><b>+${d.fatigue_added||0}</b></div></div><div class="card" style="margin-top:12px"><h2>Parcours</h2>${(d.matches||[]).map(m=>`<div class="list-item"><div class="row between"><b>${esc(m.round_name)}</b><b>${esc(m.score)}</b></div><div class="muted mini">${esc(m.user_pair)} vs ${esc(m.opponent_pair)} · vainqueur ${esc(m.winner_pair)}</div></div>`).join('')||'<div class="empty">Aucun match.</div>'}</div>${typeof window.cbDoublesReplayHtmlV13==='function'?window.cbDoublesReplayHtmlV13(d.matches||[]):''}</div></div>`;
 }catch(e){overlay.innerHTML=`<div class="modal" onclick="closeOverlay()"><div class="sheet"><h2>Double impossible</h2><p class="muted">${esc(e.message)}</p><button class="primary" onclick="closeOverlay()">OK</button></div></div>`}
}
window.tourSection=(s,btn)=>{const m={overview:'tourOverviewTpl',prize:'tourPrizeTpl',history:'tourHistoryTpl',ncaa:'tourNcaaTpl',draw:'tourDrawTpl',qual:'tourQualTpl',double:'tourDoubleTpl',forfeits:'tourForfeitsTpl',results:'tourResultsTpl'},t=document.getElementById(m[s]),body=document.getElementById('tourBody');if(!t||!body)return;body.innerHTML=t.innerHTML;document.querySelectorAll('.tm-tour-tabs [data-tour-section]').forEach(x=>x.classList.toggle('active',x.dataset.tourSection===s));if(btn)btn.classList.add('active');const sc=body.querySelector('.tm-bracket-scroll');if(sc)sc.scrollLeft=0}
window.focusManagedDraw=()=>{const el=document.querySelector('#tourBody .tm-bracket-match.is-managed');if(el)el.scrollIntoView({behavior:'smooth',block:'center',inline:'center'})}

async function managerAction(action,id,extra={}){
  return get('/api/manager-action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,id,...extra})});
}
async function refreshManagerState(){
  boot=await get('/api/bootstrap');
  await loadManagement();
  if(boot.career){
    local.career={...(local.career||{}),budget:boot.career.budget};
    persist();
  }
}
window.openYouth=id=>{
  const y=(boot.youth||[]).find(x=>x.id===id);if(!y)return;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Prospect académie</div><h1>${flags[y.country]||'🏳️'} ${esc(y.name)}</h1><div class="muted">${y.age} ans · ${esc(y.style||'')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  <div class="grid g2" style="margin-top:12px"><div class="card"><div class="big">${starRatingHtml(abilityStarValue(y.potential||0),'Potentiel estimé')}</div><div class="muted">Potentiel estimé par l’académie</div></div><div class="card"><div class="big">${starRatingHtml(abilityStarValue(y.current_ability||0),'Niveau actuel')}</div><div class="muted">Niveau actuel observé</div></div></div>
  <div class="card" style="margin-top:12px"><div class="list-item row between"><span>Coût académie</span><b>${euro(y.scholarship_cost)}</b></div><div class="list-item row between"><span>Statut</span><b>${esc(y.status||'prospect')}</b></div>${y.status==='signed'?'<div class="notice">Ce joueur est déjà sous contrat avec ton académie.</div>':`<button class="primary" style="margin-top:10px" onclick="signYouth(${y.id})">Signer le prospect</button>`}</div></div></div>`;
}
window.signYouth=async id=>{try{const d=await managerAction('sign_youth',id);if(local.career)local.career.budget=d.budget;await refreshManagerState();closeOverlay();render()}catch(e){alert(e.message)}}
window.openStaff=id=>{
  const s=(boot.staff||[]).find(x=>x.id===id);if(!s)return;
  const p=s.profile||null,n=s.name||p?.name||s.role;
  const course=p?.id?(management?.userStaffTraining||[]).find(x=>Number(x.staff_profile_id)===Number(p.id)&&x.status==='active'):null;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">${esc(s.role)}</div><h1>${esc(n)}</h1><div class="muted">${esc(p?.specialty||'Membre du staff')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="row between"><span>Niveau poste</span><b>${s.skill}/20</b></div><div class="bar"><i style="width:${s.skill*5}%"></i></div><div class="list-item row between"><span>Coût hebdomadaire</span><b>${euro(s.weekly_cost)}</b></div>${p?`<div class="list-item row between"><span>Charge</span><b>${p.workload??0}/100</b></div><div class="list-item row between"><span>Burnout</span><b class="${Number(p.burnout||0)>=65?'bad':''}">${p.burnout??0}/100</b></div><div class="list-item row between"><span>Énergie</span><b>${p.energy??100}/100</b></div>${p.operational_status==='rest'?`<div class="notice warn">Au repos jusqu’au ${df(p.rest_until)}.</div>`:''}`:''}${p?`<div class="list-item row between"><span>Parcours</span><b>${esc(staffFormerLabel(p))}</b></div>`:''}${p?.former_player_id?`<button class="ghost" onclick="openPlayer(${p.former_player_id})">Voir la carrière joueur</button>`:''}</div>${p?`<div class="card" style="margin-top:10px"><h2>Attributs staff</h2>${staffMetaBadges(p)}${staffRatingGrid(p)}<p class="muted mini" style="margin-top:8px">${esc(p.notes||'Notes de gameplay Court Boss.')}</p><div class="muted micro">${esc(p.source_label||'Court Boss')}</div><button class="ghost" style="margin-top:8px" onclick="openStaffProfile(${p.id})">Dossier carrière complet</button></div>`:''}<div class="row" style="gap:8px;margin-top:10px;flex-wrap:wrap">${course?`<div class="card" style="width:100%"><div class="row between"><span>Formation active · ${esc(course.focus||'')}</span><b>${course.progress||0}%</b></div><div class="bar" style="margin-top:6px"><i style="width:${Number(course.progress||0)}%"></i></div><div class="muted micro" style="margin-top:4px">${esc(course.center?.name||'Centre')} · fin ${df(course.expected_end)}</div></div>`:p?`<button class="primary" onclick="openStaffTraining(${s.id})">Former / certifier</button>`:''}${p&&p.operational_status!=='rest'&&Number(p.burnout||0)>=35?`<button class="ghost" onclick="restStaff(${s.id})">Repos 2 semaines</button>`:''}<button class="danger-btn" onclick="fireStaff(${s.id})">Se séparer</button></div></div></div>`;
}
window.openStaffTraining=id=>{
 const member=(boot.staff||[]).find(x=>Number(x.id)===Number(id));if(!member)return;
 const centers=management?.staffTrainingCenters||[];
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Formation staff</div><h1>${esc(member.name||member.profile?.name||member.role)}</h1><div class="muted">Choisis une spécialisation. La progression se fait chaque mois de jeu.</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
 <div class="grid g2">${centers.map(c=>`<div class="card"><div class="row between"><div><div class="eyebrow">${esc(c.specialty||'Formation')}</div><h2>${esc(c.name)}</h2><div class="muted mini">${esc(c.country||'INT')} · réputation ${c.reputation}/20</div></div><span class="badge">${c.course_weeks||10} sem.</span></div><div class="list-item row between"><span>Coût</span><b>${euro(c.course_cost||0)}</b></div><div class="list-item row between"><span>Capacité</span><b>${c.capacity||'—'}</b></div><button class="primary" style="margin-top:8px" onclick="enrollStaffTraining(${member.id},${c.id})">Inscrire</button></div>`).join('')||'<div class="card empty">Aucun centre disponible.</div>'}</div>
 </div></div>`;
}
window.enrollStaffTraining=async(staffId,centerId)=>{
 try{
  const d=await managerAction('enroll_staff_training',staffId,{center_id:centerId});
  if(local.career)local.career.budget=d.budget;
  await refreshManagerState();
  render();
  closeOverlay();
  alert('Formation lancée jusqu’au '+df(d.expected_end)+'.');
 }catch(e){alert(e.message)}
}
window.openStaffCandidate=id=>{
 const x=(management?.candidates||[]).find(v=>Number(v.id)===Number(id));if(!x)return;
 const p=x.profile||null,available=x.status==='available',done=x.interview_status==='completed',rejected=x.interview_status==='rejected';
 const demands=x.demands||{};
 const demandRows=[
  demands.lead_role?'Rôle principal exigé':null,
  demands.shared_role?'Rôle partagé accepté':null,
  demands.performance_bonus?'Bonus de performance demandé':null,
  demands.release_clause?'Clause de sortie demandée':null,
  Array.isArray(demands.preferred_circuits)&&demands.preferred_circuits.length?'Circuits : '+demands.preferred_circuits.join(' / '):null
 ].filter(Boolean);
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet">
  <div class="sheet-head"><div><div class="eyebrow">${esc(x.role)}</div><h1>${esc(x.name)}</h1><div class="muted">${esc(x.specialty||p?.specialty||'Candidat staff')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
  <div class="card">
   <div class="row between"><span>Niveau poste</span><b>${x.skill}/20</b></div>
   <div class="list-item row between"><span>Compatibilité avec ton joueur</span><b>${x.managed_fit??'—'}/100</b></div>
   <div class="list-item row between"><span>Salaire ${done?'demandé':'estimé'}</span><b>${euro(done?(x.requested_weekly||x.weekly_cost):x.weekly_cost)}/sem.</b></div>
   <div class="list-item row between"><span>Prime ${done?'demandée':'estimée'}</span><b>${euro(done?(x.requested_signing||x.signing_cost):x.signing_cost)}</b></div>
   ${done?`<div class="list-item row between"><span>Durée souhaitée</span><b>${x.desired_years||2} an(s)</b></div><div class="list-item row between"><span>Intérêt</span><b class="${Number(x.interest||0)>=70?'good':Number(x.interest||0)>=50?'warn':'bad'}">${x.interest??'—'}/100</b></div>`:''}
   <div class="list-item row between"><span>Offres concurrentes</span><b>${Number(x.competing_offers||0)}</b></div>
   ${p?`<div class="list-item row between"><span>Parcours</span><b>${esc(staffFormerLabel(p))}</b></div>`:''}
   ${p?.former_player_id?`<button class="ghost" onclick="openPlayer(${p.former_player_id})">Voir sa carrière joueur</button>`:''}
  </div>
  ${done&&demandRows.length?`<div class="card" style="margin-top:10px"><div class="eyebrow">Exigences contractuelles</div><div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${demandRows.map(v=>`<span class="badge">${esc(v)}</span>`).join('')}</div></div>`:''}
  ${p?`<div class="card" style="margin-top:10px"><div class="row between"><h2>Profil FM</h2><b>${x.managed_fit!=null?x.managed_fit+'/100':''}</b></div>${staffMetaBadges(p)}<div class="list-item row between"><span>Ambition / Loyauté</span><b>${p.ambition??'—'} / ${p.loyalty??'—'}</b></div><h3>Attributs 1–20</h3>${staffRatingGrid(p)}<button class="ghost" onclick="openStaffProfile(${p.id})">Dossier carrière complet</button></div>`:''}
  ${available&&!done&&!rejected?`<button class="primary" style="margin-top:10px" onclick="interviewStaff(${x.id})">Passer l'entretien</button>`:''}
  ${available&&done?`<div class="card" style="margin-top:10px"><div class="eyebrow">Négociation</div><div class="grid g3" style="margin-top:8px"><label class="mini muted">Salaire / sem.<input id="staffOfferWeekly" class="input" type="number" min="0" value="${Number(x.requested_weekly||x.weekly_cost||0)}"></label><label class="mini muted">Prime<input id="staffOfferSigning" class="input" type="number" min="0" value="${Number(x.requested_signing||x.signing_cost||0)}"></label><label class="mini muted">Durée<input id="staffOfferYears" class="input" type="number" min="1" max="5" value="${Number(x.desired_years||2)}"></label></div><div class="row" style="gap:8px;margin-top:10px;flex-wrap:wrap"><button class="ghost" onclick="counterStaffOffer(${x.id})">Proposer ces conditions</button><button class="primary" onclick="hireStaff(${x.id})">Signer aux conditions actuelles</button></div>${demands.negotiation_status==='counter'?'<div class="notice warn" style="margin-top:8px">Le candidat a fait une contre-proposition. Ajuste les conditions ou signe sur cette base.</div>':demands.negotiation_status==='agreed'?'<div class="notice good" style="margin-top:8px">Accord de principe trouvé.</div>':''}</div>`:''}
  ${rejected?'<div class="notice bad" style="margin-top:10px">Le candidat n’est pas suffisamment intéressé pour rejoindre ton projet actuellement.</div>':''}
 </div></div>`;
}
window.filterStaffMarket=()=>{
 const q=String(document.getElementById('staffMarketSearch')?.value||'').trim().toLowerCase();
 const role=String(document.getElementById('staffMarketRole')?.value||'');
 document.querySelectorAll('.staff-market-card').forEach(el=>{
  const okName=!q||String(el.dataset.name||'').includes(q);
  const okRole=!role||String(el.dataset.role||'')===role;
  el.style.display=okName&&okRole?'':'none';
 });
}
window.counterStaffOffer=async id=>{
 try{
  const weekly=Number(document.getElementById('staffOfferWeekly')?.value||0);
  const signing=Number(document.getElementById('staffOfferSigning')?.value||0);
  const years=Number(document.getElementById('staffOfferYears')?.value||2);
  const d=await managerAction('counter_staff_offer',id,{weekly,signing,years});
  await refreshManagerState();
  render();
  openStaffCandidate(id);
  if(d.status==='counter')alert('Le candidat fait une contre-proposition.');
  if(d.status==='accepted')alert('Accord de principe trouvé.');
 }catch(e){alert(e.message)}
}
window.applyStaffWorldFilters=async()=>{
 staffWorldFilters={
  q:String(document.getElementById('staffWorldQ')?.value||'').trim(),
  role:String(document.getElementById('staffWorldRole')?.value||''),
  country:String(document.getElementById('staffWorldCountry')?.value||''),
  former:String(document.getElementById('staffWorldFormer')?.value||'Tous'),
  status:String(document.getElementById('staffWorldStatus')?.value||'Tous')
 };
 staffWorldOffset=0;
 await loadStaffWorld();
 render();
}
window.staffWorldPage=async dir=>{
 const total=Number(staffWorldData?.total||0);
 const lastOffset=Math.max(0,Math.floor(Math.max(0,total-1)/50)*50);
 staffWorldOffset=Math.max(0,Math.min(lastOffset,staffWorldOffset+Number(dir||0)*50));
 await loadStaffWorld();
 render();
 const el=document.querySelector('.staff-world-filter');
 if(el)window.scrollTo({top:el.getBoundingClientRect().top+window.scrollY-90,behavior:'smooth'});
}
window.approachStaffProfile=async profileId=>{
 try{
  const d=await managerAction('approach_staff',profileId,{player_id:activeManagedId()||primaryManagedPlayerId()||0});
  await loadManagement();
  await loadStaffWorld();
  render();
  if(d?.candidate_id)openStaffCandidate(d.candidate_id);
 }catch(err){alert(err.message)}
}
window.interviewStaff=async id=>{
 try{
  const d=await managerAction('interview_staff',id,{player_id:activeManagedId()||primaryManagedPlayerId()||0});
  await refreshManagerState();
  render();
  openStaffCandidate(id);
  if(d.status==='rejected')alert("Le candidat n'est pas suffisamment intéressé pour le moment.");
 }catch(e){alert(e.message)}
}
window.hireStaff=async id=>{try{const d=await managerAction('hire_staff',id,{player_id:activeManagedId()||primaryManagedPlayerId()||0});if(local.career)local.career.budget=d.budget;await refreshManagerState();render()}catch(e){alert(e.message)}}
window.openStaffProfile=async id=>{
 overlay.innerHTML='<div class="modal"><div class="sheet"><div class="loader">Chargement du dossier staff…</div></div></div>';
 try{
  const d=await get('/api/staff-profile?id='+id),p=d.profile||{},active=d.activeAssignments||[],hist=d.history||[],events=d.events||[],agency=d.agency?.agency||null,licenses=d.licenses||[],pref=d.preferences||null,scope=d.scopeReputation||[],peers=d.peers||[],recs=d.recommendations||{from:[],to:[]},college=d.collegeStaff||[],davis=d.davisStaff||[],training=d.training||[],coachAcademy=d.coachAcademy||null,playerBonds=d.playerBonds||[],careerStats=d.careerStats||null,achievements=d.achievements||[],awards=d.awards||[],agentClients=d.agentClients||[],agentClientCount=Number(d.agentClientCount||0);
  const playerLink=x=>x?.player?.id?`<span class="click" onclick="openPlayer(${x.player.id})"><b>${esc(x.player.name)}</b></span>`:'—';
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet">
   <div class="sheet-head"><div><div class="eyebrow">${esc(p.primary_role||'Staff')}</div><h1>${esc(p.name||'Profil staff')}</h1><div class="muted">${esc(p.specialty||'')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
   <div class="card"><div class="row between"><div><b>${esc(staffFormerLabel(p))}</b><div class="muted mini">${esc(p.nationality||'')} · Réputation ${p.reputation??'—'}/20</div></div><span class="badge">${esc(p.market_status||'')}</span></div><div style="margin-top:8px">${staffMetaBadges(p)}</div><div class="kpi-strip" style="margin-top:9px"><div class="kpi"><span class="muted micro">Charge</span><b>${p.workload??0}</b></div><div class="kpi"><span class="muted micro">Burnout</span><b>${p.burnout??0}</b></div><div class="kpi"><span class="muted micro">Énergie</span><b>${p.energy??100}</b></div><div class="kpi"><span class="muted micro">Voyage</span><b>${p.travel_fatigue??0}</b></div></div>${p.operational_status==='rest'?`<div class="notice warn" style="margin-top:8px">Repos programmé jusqu’au ${df(p.rest_until)}.</div>`:''}</div>
   ${agency||licenses.length||pref||scope.length||coachAcademy?`<div class="card" style="margin-top:10px"><h2>Réseau, formation & licences</h2>
    ${agency?`<div class="list-item row between"><span>Agence</span><b>${esc(agency.name)}</b></div><div class="muted micro">Commission ${agency.commission_pct}% · force réseau ${agency.network_strength}/20</div>`:''}
    ${coachAcademy?.academy?`<div class="list-item"><div class="row between"><span>Académie de coachs</span><b>${esc(coachAcademy.academy.name)}</b></div><div class="muted micro">${esc(coachAcademy.academy.philosophy||'')} · prestige ${coachAcademy.academy.prestige}/20</div>${coachAcademy.mentor?`<div class="micro">Mentor : <span class="click" onclick="openStaffProfile(${coachAcademy.mentor.id})">${esc(coachAcademy.mentor.name)}</span></div>`:''}</div>`:''}
    ${licenses.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${licenses.slice(0,5).map(l=>`<span class="badge">${esc(l.license_code)} · niv. ${l.license_level}</span>`).join('')}</div>`:''}
    ${pref?`<div class="list-item row between"><span>Style préféré</span><b>${esc(pref.preferred_style||'—')}</b></div><div class="list-item row between"><span>Classement visé</span><b>#${pref.preferred_min_rank||'—'} à #${pref.preferred_max_rank||'—'}</b></div><div class="list-item row between"><span>Rôle principal</span><b>${pref.wants_lead_role?'Oui':'Non'}</b></div><div class="list-item row between"><span>Partage de rôle</span><b>${pref.willing_shared_role?'Oui':'Non'}</b></div><div class="list-item row between"><span>Tolérance voyage</span><b>${pref.travel_tolerance}/20</b></div>`:''}
    ${scope.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${scope.slice(0,8).map(x=>`<span class="badge">${esc(x.scope_code)} ${x.rating}/20</span>`).join('')}</div>`:''}
   </div>`:''}
   <div class="card" style="margin-top:10px"><h2>Attributs</h2>${staffRatingGrid(p)}</div>
   ${careerStats?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Palmarès staff</div><h2>Carrière d'encadrement</h2></div><span class="badge">${careerStats.titles_total||0} titres</span></div><div class="kpi-strip" style="margin-top:8px"><div class="kpi"><span class="muted micro">Grand Chelem</span><b>${careerStats.grand_slams||0}</b></div><div class="kpi"><span class="muted micro">Masters 1000</span><b>${careerStats.masters1000||0}</b></div><div class="kpi"><span class="muted micro">Double</span><b>${careerStats.doubles_titles||0}</b></div><div class="kpi"><span class="muted micro">Meilleur client</span><b>${careerStats.best_client_rank?'#'+fmt(careerStats.best_client_rank):'—'}</b></div></div>${awards.length?`<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:8px">${awards.map(x=>`<span class="badge good">${x.season} · ${esc(x.award_name)}</span>`).join('')}</div>`:''}${achievements.length?`<div style="margin-top:8px">${achievements.slice(0,8).map(x=>`<div class="list-item"><div class="row between"><div><b>${esc(x.tournament_name)}</b><div class="muted micro">${df(x.achievement_date)} · ${esc(x.level||x.event_type||'Titre')}</div></div><span class="badge">+${x.achievement_points}</span></div>${x.player?.name?`<div class="muted micro">avec <span class="click" onclick="openPlayer(${x.player.id})">${esc(x.player.name)}</span></div>`:''}</div>`).join('')}</div>`:''}</div>`:''}
   ${agentClientCount?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Portefeuille agent</div><h2>Joueurs représentés</h2></div><span class="badge">${agentClientCount} clients</span></div>
    ${agentClients.slice(0,20).map(x=>{const pl=x.player||{};return `<div class="list-item click" onclick="openPlayer(${pl.id})"><div class="row between"><div><b>${flags[pl.country]||'🏳️'} ${esc(pl.name||'Joueur')}</b><div class="muted micro">Depuis ${df(x.start_date)} · commission ${x.commission_pct}%</div></div><div style="text-align:right"><b>#${fmt(pl.game_world_rank||pl.ranking||0)}</b><div class="muted micro">confiance ${x.trust}/100</div></div></div></div>`}).join('')}
    ${agentClientCount>20?`<div class="muted mini" style="margin-top:7px">+${agentClientCount-20} autres clients dans le réseau.</div>`:''}
   </div>`:''}
   <div class="card" style="margin-top:10px"><div class="row between"><h2>Équipe actuelle</h2><span class="badge">${active.length}</span></div>${active.length?active.map(x=>`<div class="list-item"><div class="row between"><div>${playerLink(x)}<div class="muted mini">${esc(x.role)} · depuis ${df(x.start_date)}</div></div><div style="text-align:right"><b>${x.role_fit??'—'}/100</b><div class="muted micro">fit</div></div></div><div class="row between muted micro"><span>Affinité ${x.affinity??'—'}</span><span>Confiance ${x.trust??'—'}</span><span>Satisfaction ${x.satisfaction??'—'}</span><span>Cohésion ${x.team_chemistry??'—'}</span></div></div>`).join(''):'<div class="empty">Disponible sur le marché.</div>'}</div>
   ${playerBonds.length?`<div class="card" style="margin-top:10px"><div class="row between"><div><div class="eyebrow">Relations FM</div><h2>Joueurs favoris & anciennes relations</h2></div><span class="badge">${playerBonds.length}</span></div>${playerBonds.slice(0,16).map(x=>{const pl=x.player||{};return `<div class="list-item click" onclick="openPlayer(${pl.id})"><div class="row between"><div><b>${flags[pl.country]||'🏳️'} ${esc(pl.name||'Joueur')}</b><div class="muted micro">${esc(x.bond_type)} · depuis ${df(x.formed_date)}</div></div><span class="badge ${x.bond_type==='Joueur favori'?'good':x.bond_type==='Relation difficile'?'bad':''}">${x.affinity}/100</span></div><div class="row between muted micro"><span>Confiance ${x.trust}</span><span>Respect ${x.respect}</span><span>${x.is_simulated?'Simulation Court Boss':'Sourcé'}</span></div></div>`}).join('')}</div>`:''}
   ${college.length||davis.length?`<div class="card" style="margin-top:10px"><h2>Fonctions institutionnelles</h2>${college.map(x=>`<div class="list-item row between"><span>NCAA · ${esc(x.team?.name||'Université')}</span><b>${esc(x.role)}</b></div>`).join('')}${davis.map(x=>`<div class="list-item row between"><span>Coupe Davis · ${esc(x.nation)}</span><b>${esc(x.role)}${x.part_time?' · temps partiel':''}</b></div>`).join('')}</div>`:''}
   ${training.length?`<div class="card" style="margin-top:10px"><h2>Formation continue</h2>${training.map(x=>`<div class="list-item"><div class="row between"><span>${esc(x.center?.name||'Institut')}</span><b>${x.progress??0}%</b></div><div class="muted micro">${esc(x.focus||'Formation')} · ${esc(x.status||'')}</div></div>`).join('')}</div>`:''}
   ${peers.length?`<div class="card" style="margin-top:10px"><h2>Réseau & relations staff</h2>${peers.slice(0,12).map(x=>`<div class="list-item"><div class="row between"><b class="click" onclick="openStaffProfile(${x.other?.id})">${esc(x.other?.name||'Staff')}</b><span class="badge ${Number(x.conflict_score||0)>=60?'bad':''}">${esc(x.relation_type)}</span></div><div class="row between muted micro"><span>Affinité ${x.affinity}</span><span>Confiance ${x.trust}</span><span>Rivalité ${x.rivalry}</span><span>Conflit ${x.conflict_score}</span></div></div>`).join('')}</div>`:''}
   ${(recs.from?.length||recs.to?.length)?`<div class="card" style="margin-top:10px"><h2>Recommandations professionnelles</h2>${(recs.from||[]).slice(0,6).map(x=>`<div class="list-item"><div class="row between"><span>Recommande <b class="click" onclick="openStaffProfile(${x.other?.id})">${esc(x.other?.name||'un collègue')}</b></span><b>${x.strength}/100</b></div>${x.other?.market_status==='available'?`<div class="row between" style="margin-top:5px"><span class="muted micro">${esc(x.other?.primary_role||'Staff')} · ${esc(x.other?.specialty||'')}</span><button class="soft-btn" onclick="approachStaffProfile(${x.other?.id})">Contacter</button></div>`:''}</div>`).join('')}${(recs.to||[]).slice(0,6).map(x=>`<div class="list-item row between"><span>Recommandé par <b class="click" onclick="openStaffProfile(${x.other?.id})">${esc(x.other?.name||'un collègue')}</b></span><b>${x.strength}/100</b></div>`).join('')}</div>`:''}
   ${hist.length?`<div class="card" style="margin-top:10px"><div class="row between"><h2>Historique carrière</h2><span class="badge">${hist.length}</span></div>${hist.slice(0,20).map(x=>`<div class="list-item"><div class="row between"><div>${playerLink(x)}<div class="muted mini">${esc(x.role)} · ${df(x.start_date)} → ${df(x.end_date)}</div></div><span class="badge">${esc(x.ended_reason||'Fin de collaboration')}</span></div></div>`).join('')}</div>`:''}
   ${events.length?`<div class="card" style="margin-top:10px"><h2>Événements de carrière</h2>${events.slice(0,20).map(x=>`<div class="list-item"><div class="row between"><b>${df(x.event_date)}</b><span class="badge">${esc(x.event_type)}</span></div><div class="muted mini">${esc(x.description||'')}</div></div>`).join('')}</div>`:''}
  </div></div>`;
 }catch(err){overlay.innerHTML=`<div class="modal"><div class="sheet"><div class="notice bad">${esc(err.message||'Erreur')}</div><button class="primary" onclick="closeOverlay()">Fermer</button></div></div>`}
}
window.matchStaffOffer=async id=>{
 if(!confirm("S'aligner sur l'offre concurrente ? Une prime de fidélité de 2 semaines sera payée."))return;
 try{
  const d=await managerAction('match_staff_offer',id);
  if(local.career)local.career.budget=d.budget;
  await refreshManagerState();render();
 }catch(e){alert(e.message)}
}
window.releaseStaffOffer=async id=>{
 if(!confirm("Laisser ce membre du staff rejoindre l'autre joueur ?"))return;
 try{await managerAction('release_staff_offer',id);await refreshManagerState();render()}catch(e){alert(e.message)}
}
window.mediateStaffConflict=async(aId,bId)=>{
 try{
  const d=await managerAction('mediate_staff_conflict',0,{staff_a_id:aId,staff_b_id:bId});
  await refreshManagerState();render();
  alert('Médiation réussie : conflit '+d.conflict_score+'/100.');
 }catch(e){alert(e.message)}
}
window.restStaff=async id=>{
 if(!confirm('Mettre ce membre du staff au repos pendant 2 semaines ? Son impact sportif sera fortement réduit pendant cette période.'))return;
 try{
  const d=await managerAction('rest_staff',id);
  await refreshManagerState();render();closeOverlay();
  alert('Repos programmé jusqu’au '+df(d.rest_until)+'.');
 }catch(e){alert(e.message)}
}
window.fireStaff=async id=>{
 if(!confirm('Se séparer de ce membre du staff ? Une indemnité de 4 semaines sera versée.'))return;
 try{
  const d=await managerAction('fire_staff',id);
  if(local.career)local.career.budget=d.budget;
  closeOverlay();
  await refreshManagerState();
  render();
 }catch(e){alert(e.message)}
}
window.openContract=id=>{
  const x=(management?.contracts||[]).find(v=>v.id===id);if(!x)return;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Contrat</div><h1>${esc(x.subject_name)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Rôle</span><b>${esc(x.role||x.subject_type)}</b></div><div class="list-item row between"><span>Salaire</span><b>${euro(x.weekly_salary)}/sem.</b></div><div class="list-item row between"><span>Échéance</span><b>${df(x.end_date)}</b></div><button class="primary" onclick="renewContract(${x.id});closeOverlay()">Proposer +1 an</button></div></div></div>`;
}
window.renewContract=async id=>{try{await managerAction('renew_contract',id);await loadManagement();render()}catch(e){alert(e.message)}}
window.acceptSponsor=async id=>{try{const d=await managerAction('accept_sponsor',id);if(local.career)local.career.budget=d.budget;careerHub=null;await refreshManagerState();await loadCareerHub(true);render()}catch(e){alert(e.message)}}
window.declineSponsor=async id=>{try{await managerAction('decline_sponsor',id);careerHub=null;await Promise.all([loadManagement(),loadCareerHub(true)]);render()}catch(e){alert(e.message)}}
window.openInjury=id=>{
  const i=(boot.injuries||[]).find(x=>x.id===id);if(!i)return;
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Dossier médical</div><h1>${esc(i.injury_type)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Sévérité</span><b>${esc(i.severity)}</b></div><div class="list-item row between"><span>Retour estimé</span><b>${df(i.expected_return)}</b></div><div class="list-item row between"><span>Risque aggravation</span><b>${i.aggravation_risk}%</b></div><div class="list-item"><span class="muted mini">Traitement</span><p>${esc(i.treatment||'Repos et suivi médical')}</p></div></div></div></div>`;
}
window.setMedicalProtocol=async protocol=>{
  const playerId=activeManagedId()||primaryManagedPlayerId()||0;
  const injuryId=(activeManagedContext&&Number(activeManagedContext.player_id)===playerId)?Number(activeManagedContext.injury?.id||0):0;
  try{
    const d=await managerAction('set_medical_protocol',injuryId,{protocol,player_id:playerId});
    const restPlan=protocol==='Repos complet'
      ?['Repos','Repos','Récupération','Repos','Récupération','Repos','Repos']
      :protocol==='Récupération active'
        ?['Récupération','Repos','Récupération','Repos','Récupération','Repos','Repos']
        :null;
    if(restPlan){
      if(playerId===primaryManagedPlayerId())local.training=[...restPlan];
      else{
        local.playerTraining=local.playerTraining||{};
        local.playerTraining[String(playerId)]=[...restPlan];
      }
      if(Number(local.trainingPlayerId||0)===playerId)trainingPreview=null;
    }
    boot=await get('/api/bootstrap');
    await loadActiveManagedContext(true,playerId).catch(()=>{});
    persist();render();
  }catch(e){alert(e.message)}
}
window.setRecovery=mode=>{
  const map={Repos:'Repos complet','Récupération':'Récupération active',mix:'Récupération active'};
  return setMedicalProtocol(map[mode]||'Récupération active');
}
window.applyRecovery=()=>setMedicalProtocol('Récupération active');
window.setTactic=(k,v)=>{local.tactics=local.tactics||{};local.tactics[k]=['aggression','risk','net'].includes(k)?Number(v):v;persist();render()}
window.simulatePracticeMatch=async()=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const cr=activePlayerCareerView();
 if(String(cr.career_focus||'mixed')==='doubles_only'){
  alert('Orientation Double exclusivement : la simulation simple est désactivée pour ce joueur.');
  return;
 }
 if(local.liveMatch&&['active','finished','completed'].includes(String(local.liveMatch.status||''))){
  alert('Tu as déjà un match en attente. Valide, sauvegarde ou annule-le avant une nouvelle simulation.');
  return;
 }
 try{
  await ensureLivePreMatchCheckpoint();
  const surface=(local.matchSurface||'Dur')==='Dur'&&local.matchIndoor?'Dur intérieur':(local.matchSurface||'Dur');
  const started=await get('/api/live-match/start',{
   method:'POST',headers:{'Content-Type':'application/json'},
   body:JSON.stringify({surface,player_id:playerId,tactics:local.tactics||{}})
  });
  applyLiveMatchResponse(started);
  if(typeof window.simulateLiveMatch!=='function')throw new Error('Simulateur de match indisponible.');
  await window.simulateLiveMatch();
  route='match';persist();render();
  if(local.liveMatch?.status==='active')alert('La simulation s’est interrompue avant la fin du match.');
 }catch(e){alert('Simulation rapide impossible : '+e.message)}
}
window.openMatch=idx=>{
  const all=[...(local.practiceMatches||[]),...(boot.matches||[])],m=all[idx];if(!m)return;
  const d=m.match_data||{};
  const firstServe=d.first_serve_pct??d.premieres_balles??'—';
  const winners=d.winners??'—';
  const errors=d.unforced_errors??d.fautes_directes??'—';
  const net=d.net_points_won_pct??'—';
  const rally=d.avg_rally??d.rallye_moyen??'—';
  const bp=d.break_points_won??'—';
  const plan=d.tactical_plan||local.tactics||{};
  const mc=d.matchup_components_user||{};
  const matchupRows=[
    ['Service / retour',mc.service_return],['Mental',mc.mental],['Physique',mc.physical],
    ['Surface',mc.surface_fit],['Style',mc.style_matchup],['Match-up tactique',mc.tactical_matchup],
    ['Contexte',mc.context_skill],['Grands matchs',mc.big_match],['Best of 5',mc.best_of_five],
    ['Confiance',mc.confidence],['H2H',mc.h2h],['Forme',mc.form_delta],['Tes consignes',mc.user_tactics]
  ].filter(x=>Number.isFinite(Number(x[1]))&&Math.abs(Number(x[1]))>.0005);
  const result=m.winner===(career().player_name||'Anthony')||m.winner===(activePlayerCareerView().player_name||'Joueur');
  const efficiency=(()=>{
    const w=Number(winners)||0,e=Number(errors)||0,n=Number(net)||50,r=Number(rally)||5;
    return clamp(Math.round(50+(w-e)*1.2+(n-50)*.25-(r>8?3:0)),20,95);
  })();
  overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet">
    <div class="sheet-head"><div><div class="eyebrow">${esc(m.tournament_name||'Match')}</div><h1>${esc(m.player_a)} vs ${esc(m.player_b)}</h1><div class="muted">${df(m.match_date||local.date)} · ${esc(m.surface||'Dur')}</div></div><button class="close" onclick="closeOverlay()">✕</button></div>
    <div class="score-hero" style="margin-top:12px">${esc(m.score||'—')}</div><div class="row" style="justify-content:center;margin-top:7px"><span class="badge ${result?'good':'bad'}">${result?'Victoire':'Défaite'}</span></div>
    <div class="kpi-strip" style="margin-top:14px">
      <div class="kpi"><span class="muted mini">1res balles</span><b>${typeof firstServe==='number'?firstServe+'%':esc(firstServe)}</b></div>
      <div class="kpi"><span class="muted mini">Winners</span><b>${winners}</b></div>
      <div class="kpi"><span class="muted mini">Fautes directes</span><b>${errors}</b></div>
      <div class="kpi"><span class="muted mini">Filet gagné</span><b>${net==='—'?'—':net+'%'}</b></div>
    </div>
    ${d.expected_win_probability!=null?`<div class="card" style="margin-top:12px">
<div class="row between"><div><div class="eyebrow">Moteur de match</div><h2>Pourquoi ce duel penchait d’un côté</h2></div><span class="badge">${Math.round(Number(d.expected_win_probability)*100)}%</span></div>
${matchupRows.length?`<div class="grid g2" style="margin-top:8px">${matchupRows.map(([name,val])=>{const n=Number(val);const pct=Math.round(n*100);return `<div class="list-item row between"><span>${esc(name)}</span><b class="${pct>1?'good':pct<-1?'bad':''}">${pct>0?'+':''}${pct}</b></div>`}).join('')}</div>`:''}
<div class="muted micro" style="margin-top:8px">Valeur positive = avantage pour ton joueur. Le moteur combine Elo, service/retour, surface, style, contexte, grands matchs, Best of 5, confiance, H2H, forme et consignes.</div>
</div>`:''}
    <div class="grid g2" style="margin-top:12px">
      <div class="card"><h2>Lecture du match</h2>
        <div class="list-item row between"><span>Longueur moyenne des échanges</span><b>${rally} coups</b></div>
        <div class="list-item row between"><span>Break points gagnés</span><b>${bp}</b></div>
        <div class="list-item row between"><span>Efficacité globale</span><b>${efficiency}/100</b></div>
        <div class="bar"><i style="width:${efficiency}%"></i></div>
      </div>
      <div class="card"><h2>Plan tactique utilisé</h2>
        <div class="list-item row between"><span>Agressivité</span><b>${plan.aggression??'—'}${plan.aggression!=null?'%':''}</b></div>
        <div class="list-item row between"><span>Prise de risque</span><b>${plan.risk??'—'}${plan.risk!=null?'%':''}</b></div>
        <div class="list-item row between"><span>Montées au filet</span><b>${plan.net??'—'}${plan.net!=null?'%':''}</b></div>
        <div class="list-item row between"><span>Position au retour</span><b>${esc(plan.return_position??plan.returnPos??'Neutre')}</b></div>
      </div>
    </div>
    <div class="card" style="margin-top:12px"><h2>Recommandation coach</h2><p class="muted">${errors!=='—'&&Number(errors)>Number(winners)?'Réduire légèrement la prise de risque sur le prochain match.':net!=='—'&&Number(net)>65?'Le jeu vers l’avant a été efficace. Conserver les montées au filet sur surface rapide.':rally!=='—'&&Number(rally)>7?'Les échanges sont longs : surveiller la fatigue et privilégier les schémas service + 1.':'Plan de jeu équilibré. Ajuster surtout selon le prochain adversaire.'}</p></div>
  </div></div>`;
}
window.pairScore=(p,k)=>{
 const rows=management?.partnerships||[],activeId=activeManagedId();
 const rel=rows.find(x=>{
   const a=Number(x.player_a_id||0),b=Number(x.player_b_id||0),pid=Number(p?.id||0);
   return (a===activeId&&b===pid)||(b===activeId&&a===pid);
 });
 if(rel){
   if(k==='chem')return Number(rel.chemistry||60);
   if(k==='comp')return Number(rel.compatibility||60);
   return Number(rel.pair_strength||60);
 }
 const cr=activePlayerCareerView();
 const rankFit=Math.max(0,18-Math.min(18,Math.abs(Number(p?.doubles_ranking||1500)-Number(cr.doubles_rank||1500))/100));
 const nation=String(p?.country||'')===String(cr.country||'')?6:0;
 const level=Math.max(0,Math.min(18,(Number(p?.current_ability||55)-45)*.9));
 const base=54+rankFit+nation+level;
 return clamp(Math.round(k==='power'?base+3:k==='comp'?base:base-2),40,94)
}
window.approachPartner=async id=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 if(String(activePlayerCareerView().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : les partenariats double sont désactivés.');return}
 try{
  const d=await managerAction('approach_partner',id,{player_id:playerId});
  if(d.accepted){
   if(playerId===primaryManagedPlayerId()){local.partnerId=id;persist()}
   alert('Proposition acceptée. Cette paire devient le partenariat principal de ce joueur.');
  }else{
   alert('Proposition refusée : '+(d.reason||'le joueur ne souhaite pas changer de projet actuellement.'));
  }
  await Promise.all([loadManagement(),loadActiveManagedContext(true,playerId)]);render();
 }catch(e){alert(e.message)}
}
window.respondPartnerOffer=async(id,decision)=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 if(String(activePlayerCareerView().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : les propositions de double sont désactivées.');return}
 try{
  const d=await managerAction('respond_partner_offer',id,{decision,player_id:playerId});
  if(decision==='accept'&&d.partnership?.partner_id&&playerId===primaryManagedPlayerId()){
   local.partnerId=Number(d.partnership.partner_id);persist();
  }
  await Promise.all([loadManagement(),loadActiveManagedContext(true,playerId)]);render();
 }catch(e){alert(e.message)}
}
window.choosePartner=async id=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const isPrimary=playerId===primaryManagedPlayerId();
 if(String(activePlayerCareerView().career_focus||'mixed')==='singles_only'){alert('Mode Simple exclusivement : change d’orientation avant de former une paire.');return}
 try{
  await managerAction('choose_partner',id,{player_id:playerId});
  if(isPrimary){
   local.partnerId=id;local.doublesEntries=[];local.doublesEntryMeta={};persist();
   boot=await get('/api/bootstrap');mergeServerDoublesEntries(boot.doublesEntries||[]);
  }
  await loadManagement();
  await loadActiveManagedContext(true,playerId).catch(()=>{});
  render()
 }catch(e){alert(e.message)}
}
window.setDavisRole=async(id,role)=>{local.davisRoles=local.davisRoles||{};for(const [pid,r] of Object.entries(local.davisRoles)){if(r===role&&role!=='Réserve')delete local.davisRoles[pid]}local.davisRoles[id]=role;persist();try{await managerAction('davis_role',id,{role});boot=await get('/api/bootstrap')}catch(e){alert(e.message)}render()}
window.setCareerFocus=async focus=>{
 const labels={singles_only:'Simple exclusivement',singles_priority:'Simple prioritaire',mixed:'Simple + double',doubles_only:'Double exclusivement'};
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const isPrimary=playerId===primaryManagedPlayerId();
 const cr=activePlayerCareerView();
 if(String(cr.career_focus||'mixed')===focus)return;
 const warning=focus==='doubles_only'
  ?'Passer en Double exclusivement ? Tes inscriptions simple futures seront retirées et tu ne pourras plus jouer de tableau simple tant que ce mode reste actif.'
  :focus==='singles_only'
    ?'Passer en Simple exclusivement ? Ta paire active sera rompue et tu ne pourras plus jouer de tableau double tant que ce mode reste actif.'
    :'Passer en '+labels[focus]+' ?';
 if(!confirm(warning))return;
 try{
  const d=await managerAction('set_career_focus',0,{focus,player_id:playerId});
  if(focus==='doubles_only'){
    if(isPrimary){
      local.entries=[];local.entryMeta={};
      local.training=['Double','Service','Retour','Double','Match play','Récupération','Repos'];
    }
    tmCalFilters.entry='Double';rankKind='doubles';
  }else if(focus==='singles_only'){
    if(isPrimary){
      local.partnerId=null;local.doublesEntries=[];local.doublesEntryMeta={};
      local.training=['Service','Retour','Coup droit','Revers','Match play','Déplacements','Récupération'];
    }
    tmCalFilters.entry='Simple';rankKind='singles';
  }else if(['doubles_only','singles_only'].includes(String(cr.career_focus||'mixed'))){
    tmCalFilters.entry='Tous';
  }
  boot=await get('/api/bootstrap');
  if(isPrimary&&boot.career)local.career={...(local.career||{}),...boot.career};
  await loadActiveManagedContext(true,playerId).catch(()=>{});
  tournamentDetailRows.clear();
  await Promise.all([loadScheduleAdvice(),loadTournaments(),loadManagement(),loadSeasonSummary(),loadRankingLedger()]);
  persist();render();
  if(focus==='doubles_only'&&d.needs_partner){
    alert('Orientation active : '+(d.label||labels[focus])+'. Il te faut maintenant un partenaire.');
    nav('doubles');
    return;
  }
  alert('Orientation active : '+(d.label||labels[focus])+'.');
 }catch(e){alert(e.message)}
}
window.editCareer=async(k,v)=>{
 const playerId=activeManagedId()||primaryManagedPlayerId()||0;
 const isPrimary=playerId===primaryManagedPlayerId();
 const map={player_name:'name',country:'country',style:'style',age:'age',height_cm:'height_cm',weight_kg:'weight_kg'};
 if(isPrimary){
  const cr=career();cr[k]=v;local.career=cr;persist();
 }else if(activeManagedContext?.player&&Number(activeManagedContext.player.id)===playerId){
  activeManagedContext.player={...activeManagedContext.player,[map[k]||k]:v};
 }
 render();
 try{
  await managerAction('edit_career',0,{field:k,value:v,player_id:playerId});
  if(isPrimary){
   boot=await get('/api/bootstrap');
   if(boot.career)local.career={...local.career,...boot.career};
  }else{
   await loadActiveManagedContext(true,playerId);
  }
  persist();render()
 }catch(e){
  if(!isPrimary)await loadActiveManagedContext(true,playerId).catch(()=>{});
  alert(e.message);render()
 }
}
window.createFantasy=()=>{const name=prompt('Nom du tournoi ?','Court Boss Invitational');if(!name)return;const surface=prompt('Surface ? Dur / Terre / Gazon','Dur')||'Dur';const draw=Number(prompt('Taille du tableau ?','32'))||32;local.fantasy=local.fantasy||[];local.fantasy.push({name,surface,draw,category:'Fantasy'});persist();render()}
window.deleteFantasy=i=>{local.fantasy.splice(i,1);persist();render()}
window.openFantasy=i=>{const t=local.fantasy[i];if(!t)return;overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Fantasy Court</div><h1>${esc(t.name)}</h1></div><button class="close" onclick="closeOverlay()">✕</button></div><div class="card"><div class="list-item row between"><span>Surface</span><b>${esc(surfaceLabel(t))}</b></div><div class="list-item row between"><span>Tableau</span><b>${t.draw} joueurs</b></div></div></div></div>`}
window.facilityLevel=f=>local.facilityLevels?.[f.id]??f.level
window.upgradeFacility=async(id,name,base)=>{try{const d=await managerAction('upgrade_facility',id);boot=await get('/api/bootstrap');if(boot.career)local.career={...local.career,...boot.career};local.facilityLevels=local.facilityLevels||{};local.facilityLevels[id]=d.level;persist();render()}catch(e){alert(e.message)}}
window.openInboxItem=async(id,r)=>{
 const item=(boot?.inbox||[]).find(x=>Number(x.id)===Number(id));
 const targetRoute=String(r||item?.action_route||'home');
 if(targetRoute==='training'&&item?.action_payload?.player_id){
  local.trainingPlayerId=Number(item.action_payload.player_id);
  trainingPreview=null;
  persist();
 }
 try{await managerAction('mark_inbox_read',id);boot=await get('/api/bootstrap')}catch{}
 await nav(targetRoute)
}
window.simulateWeek=async()=>{
 if(simulating)return;
 if(saveSlotBusy){alert('Une opération de sauvegarde ou de chargement est en cours. Termine-la avant de simuler la semaine.');return;}
 if(local.liveSessionId){alert('Termine le match en cours avant de passer à la semaine suivante.');nav('match');return;}
 simulating=true;render();
 try{
  const cr=career(),load=trainingLoad();
  cr.fatigue=clamp((cr.fatigue||18)+Math.max(0,load-5)-Math.floor(Math.random()*6),0,100);
  cr.fitness=clamp((cr.fitness||91)+(load<=10?1:-3),40,100);
  cr.form=clamp((cr.form||72)+Math.floor(Math.random()*7)-2,35,100);
  cr.morale=clamp((cr.morale||78)+Math.floor(Math.random()*5)-1,35,100);
  const diffRisk=({discovery:.86,normal:.72,manager:.65,hardcore:.58})[local.difficulty||'normal']??.72;
  if(load>13&&Math.random()>diffRisk){cr.injury_status='Gêne musculaire';cr.fitness=clamp(cr.fitness-9,0,100);local.feed=local.feed||[];local.feed.unshift('Alerte médicale : la charge élevée a provoqué une gêne musculaire.')}
  else if(cr.injury_status&&cr.injury_status!=='Fit'&&Math.random()>.45)cr.injury_status='Fit';
  const d=new Date((local.date||RANKING_SNAPSHOT)+'T12:00:00');d.setDate(d.getDate()+7);
  const nextDate=d.toISOString().slice(0,10),nextWeek=(local.week||1)+1;
  const currentYear=Number(String(local.date||RANKING_SNAPSHOT).slice(0,4)),nextYear=Number(nextDate.slice(0,4));
  if(nextYear>currentYear){
    const roll=await get('/api/rollover-season',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({new_year:nextYear})});
    local.date=String(nextYear)+'-01-05';local.week=1;if(nextYear>Number(String(RANKING_SNAPSHOT).slice(0,4)))tourFilters.source='Tous';
    if(roll.userRanking){cr.singles_rank=roll.userRanking.rank;cr.points=roll.userRanking.points}
    if(roll.userDoublesRanking){cr.doubles_rank=roll.userDoublesRanking.rank;cr.doubles_points=roll.userDoublesRanking.points}
    local.feed=local.feed||[];
    const ng=roll.rollover?.newgens||{};
    local.feed.unshift(`Nouvelle saison ${nextYear} : ${roll.rollover?.retired_players||0} retraite(s), ${ng.created||0} jeunes générés, ${ng.promoted||0} promu(s) vers le circuit pro.`);
    local.career=cr;persist();
    boot=await get('/api/bootstrap');
    if(boot.career){local.career={...cr,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??1;}
    const rolloverActiveId=activeManagedId();
    if(rolloverActiveId&&rolloverActiveId!==primaryManagedPlayerId())await loadActiveManagedContext(true,rolloverActiveId).catch(()=>{});
    trainingPreview=null;careerHub=null;
    const autosave=await saveCareerSlot(0,'autosave',true);
    if(!autosave?.ok)throw new Error('La semaine a été validée côté serveur mais l’autosave a échoué. Ouvre le Save Center et sauvegarde avant de continuer.');
    await Promise.allSettled([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadCareerHub(true)]);
    if(route==='training')await loadTrainingPreview(true).catch(()=>{});
    if(route==='history')await loadHistory().catch(()=>{});
    return;
  }
  const sim=await get('/api/simulate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({week:nextWeek,date:nextDate,career_state:{form:cr.form,fitness:cr.fitness,morale:cr.morale,fatigue:cr.fatigue,injury_status:cr.injury_status},training:local.training,difficulty:local.difficulty||'normal',player_training:local.playerTraining||{}})});
  local.lastTrainingReport=sim.training||null;local.lastAcademyTrainingReport=sim.academyPlayerTraining||null;
  local.date=sim.date||nextDate;local.week=sim.week||nextWeek;local.career=cr;local.scoutingBoost=Math.min(50,(local.scoutingBoost||0)+4);
  if(sim.userRanking){cr.singles_rank=sim.userRanking.rank;cr.points=sim.userRanking.points}
  if(sim.userDoublesRanking){cr.doubles_rank=sim.userDoublesRanking.rank;cr.doubles_points=sim.userDoublesRanking.points}
  if(sim.training?.current_ability)cr.current_ability=sim.training.current_ability;
  if(sim.training?.improvements?.length){
    const labels={serve_power:'Puissance service',serve_precision:'Précision service',forehand:'Coup droit',backhand:'Revers',return_game:'Retour',volley:'Volée',touch:'Toucher',movement:'Déplacements',speed:'Vitesse',stamina:'Endurance',strength:'Force',anticipation:'Anticipation',concentration:'Concentration',composure:'Sang-froid',fighting_spirit:'Combativité',tactics:'Tactique',doubles:'Double'};
    local.feed=local.feed||[];
    local.feed.unshift('Progression entraînement : '+sim.training.improvements.map(x=>(labels[x.attribute]||x.attribute)+' '+x.from+'→'+x.to).join(', '));
  }
  else if(sim.training?.xp_gains&&Object.keys(sim.training.xp_gains).length){
    local.feed=local.feed||[];
    local.feed.unshift('Entraînement : XP technique accumulée, conservée jusqu’au prochain palier d’attribut.');
  }
  local.feed=local.feed||[];if(sim.medical){local.feed.unshift(sim.medical.recovered?'Centre médical : retour à 100%, le joueur est déclaré apte.':`Centre médical : ${sim.medical.protocol}, risque ${sim.medical.risk_delta>=0?'+':''}${sim.medical.risk_delta}, retour gagné ${sim.medical.return_days_gained||0} jour(s).`)}if(sim.weeklyFinance)local.feed.unshift(`Finances semaine : sponsors +${euro(sim.weeklyFinance.sponsors||0)}, staff -${euro(sim.weeklyFinance.staff||0)}, joueurs -${euro(sim.weeklyFinance.players||0)}, médical -${euro(sim.weeklyFinance.medical||0)} · net ${sim.weeklyFinance.net>=0?'+':''}${euro(sim.weeklyFinance.net||0)}.`);if((sim.weeklyFinance?.expired_contracts||0)>0)local.feed.unshift(`${sim.weeklyFinance.expired_contracts} contrat(s) joueur arrivé(s) à échéance.`);if((sim.academyDevelopment?.ability_progressions||0)>0)local.feed.unshift(`Académie : ${sim.academyDevelopment.ability_progressions} jeune(s) ont progressé en niveau global, ${sim.academyDevelopment.attribute_improvements||0} attribut(s) amélioré(s).`);if((sim.injuries?.new_injuries||0)>0)local.feed.unshift(`${sim.injuries.new_injuries} nouvelle(s) blessure(s) dans le monde cette semaine.`);if((sim.forfeits?.forfeits||0)>0)local.feed.unshift(`${sim.forfeits.forfeits} place(s) libérée(s) par forfait sur les tournois à venir.`);if((sim.worldDoublesTournaments?.tournaments_simulated||0)>0)local.feed.unshift(`Circuit double mondial : ${sim.worldDoublesTournaments.tournaments_simulated} tournoi(s) simulé(s), avec palmarès et points de paire mis à jour.`);local.feed.unshift(`Semaine simulée : ${cr.player_name||'Joueur'} est ${String(cr.career_focus||'mixed')==='doubles_only'?'Double #'+cr.doubles_rank:'ATP #'+cr.singles_rank} · Monde mis à jour : ${sim.world?.updated_players||0} joueurs.`);local.feed=local.feed.slice(0,8);
  local.career=cr;persist();
  boot=await get('/api/bootstrap');
  if(boot.career){local.career={...cr,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week;}
  const weeklyActiveId=activeManagedId();
  if(weeklyActiveId&&weeklyActiveId!==primaryManagedPlayerId())await loadActiveManagedContext(true,weeklyActiveId).catch(()=>{});
  trainingPreview=null;careerHub=null;
  const autosave=await saveCareerSlot(0,'autosave',true);
  if(!autosave?.ok)throw new Error('La semaine a été validée côté serveur mais l’autosave a échoué. Ouvre le Save Center et sauvegarde avant de continuer.');
  await Promise.allSettled([loadRankings(),loadTournaments(),loadManagement(),loadRankingLedger(),loadSeasonSummary(),loadScheduleAdvice(),loadCountries(),loadCareerHub(true)]);
  if(route==='training')await loadTrainingPreview(true).catch(()=>{});
  if(route==='history')await loadHistory().catch(()=>{});
 }catch(e){try{boot=await get('/api/bootstrap');if(boot.career){local.career={...local.career,...boot.career};local.date=boot.career.career_date||local.date;local.week=boot.career.week??local.week;localStorage.setItem('cbLocal',JSON.stringify(local));}}catch{}alert('Simulation incomplète : '+e.message)}
 finally{simulating=false;render()}
}
window.openGlobalSearch=()=>{
 overlay.innerHTML=`<div class="modal" onclick="if(event.target===this)closeOverlay()"><div class="sheet"><div class="sheet-head"><div><div class="eyebrow">Base mondiale · ${fmt(worldStats?.searchableRealPlayers||20000)} joueurs réels · classement mondial #1–#30000 + base profonde</div><h1>Recherche joueurs</h1></div><button class="close" onclick="closeOverlay()">✕</button></div>
 <input id="globalSearchInput" class="input" style="margin-top:12px" placeholder="Nom du joueur…" oninput="runGlobalSearch(this.value)" autofocus>
 <div class="filters" style="margin-top:8px">
  <select id="globalSearchCountry" class="select" onchange="runGlobalSearch(document.getElementById('globalSearchInput').value)"><option value="">Toutes nationalités</option>${countryRows.map(x=>`<option value="${esc(x.country)}">${flags[x.country]||'🏳️'} ${esc(x.country)}</option>`).join('')}</select>
  <select id="globalSearchCircuit" class="select" onchange="runGlobalSearch(document.getElementById('globalSearchInput').value)">
   <option>Tous</option><option>Tous réels</option><option>ATP classés</option><option>ATP profond</option><option>Double</option><option>Junior Double</option><option>Race</option><option>Next Gen</option><option>ITF</option><option>Junior</option><option>NCAA</option>
  </select>
  <select id="globalSearchAge" class="select" onchange="runGlobalSearch(document.getElementById('globalSearchInput').value)">
   <option value="99">Tous âges</option><option value="18">U18</option><option value="21">U21</option><option value="23">U23</option><option value="30">30 ans max</option>
  </select>
 </div>
 <div id="globalSearchResults" class="stack" style="margin-top:12px"><div class="empty">Tape au moins 2 caractères, ou choisis une nationalité/circuit.</div></div></div></div>`;
 setTimeout(()=>document.getElementById('globalSearchInput')?.focus(),20);
}
window.runGlobalSearch=async q=>{
 const box=document.getElementById('globalSearchResults');if(!box)return;
 const country=document.getElementById('globalSearchCountry')?.value||'';
 const circuit=document.getElementById('globalSearchCircuit')?.value||'Tous';
 const age=document.getElementById('globalSearchAge')?.value||'99';
 if(q.trim().length<2&&!country&&circuit==='Tous'&&age==='99'){box.innerHTML='<div class="empty">Tape au moins 2 caractères, ou utilise un filtre.</div>';return}
 try{
  const p=new URLSearchParams({offset:'0',limit:'60',q:q.trim(),country,circuit,age_max:age});
  const d=await get('/api/search-players?'+p.toString());
  box.innerHTML=`<div class="row between"><span class="muted mini">${fmt(d.count||0)} résultat(s)</span><span class="badge">${esc(circuit==='Tous'?'Base mondiale':circuit)}</span></div>`+
  (d.rows.map(p=>{
   const tags=[];
   if(p.ranking)tags.push('ATP #'+fmt(p.ranking));
   if(p.doubles_ranking)tags.push('Double #'+fmt(p.doubles_ranking));
   if(p.junior_doubles_ranking)tags.push('Junior Double #'+fmt(p.junior_doubles_ranking));
   if(p.itf_ranking)tags.push('ITF #'+fmt(p.itf_ranking));
   if(p.ncaa_current){const nr=ncaaRankPresentation(p);tags.push('NCAA · '+nr.label+(p.ncaa_school?' · '+p.ncaa_school:''));}
   if(p.junior_ranking&&p.birth_date&&String(p.birth_date)>='2007-01-01')tags.push('Junior #'+fmt(p.junior_ranking));
   const ageText=ageLabel(p,true);
   const bh=p.backhand?(p.backhand+(p.backhand_verified?'':' (estimé)')):'revers N/V';
   return `<div class="card click" onclick="openPlayer(${p.id})"><div class="row between"><div><b>${flags[p.country]||'🏳️'} ${esc(p.name)}</b><div class="muted mini">${esc(ageText)} · ${esc(bh)} · ${esc(tags.join(' · ')||'Joueur réel')}</div></div><span class="badge">Profil</span></div></div>`;
  }).join('')||'<div class="empty">Aucun joueur trouvé.</div>');
 }catch(e){box.innerHTML=`<div class="empty">${esc(e.message)}</div>`}
}

init();
