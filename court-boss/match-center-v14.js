/* Court Boss Match Center V14 · Spectacle, weather, reactions & venue identity */
(function(){
  const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=String(text);return n};
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const cap=(v,a,b)=>Math.max(a,Math.min(b,Number(v)||0));
  const live=()=>typeof local!=='undefined'?local.liveMatch:null;
  const meta=()=>live()?.stats?._meta||{};
  const visual=()=>live()?.last_point?.visual||{};
  const point=()=>live()?.last_point||{};
  const slug=s=>String(s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,'-');
  let lastPointKey='';

  const venueTier=()=>{
    const t=meta().tournament||{},n=(String(t.name||'')+' '+String(t.category||'')+' '+String(t.circuit||'')).toLowerCase();
    if(/grand chelem|australian open|roland|wimbledon|us open/.test(n))return 'slam';
    if(/masters 1000|atp finals|laver|next gen/.test(n))return 'premium';
    if(/atp 500|atp 250/.test(n))return 'tour';
    if(/challenger/.test(n))return 'challenger';
    if(/itf|m25|m15/.test(n))return 'itf';
    return 'tour';
  };

  const themeHash=s=>{
    let h=2166136261>>>0;
    for(const ch of String(s||'court-boss')){h^=ch.charCodeAt(0);h=Math.imul(h,16777619)>>>0}
    return h>>>0;
  };
  const signatureTheme=t=>{
    const n=(String(t?.name||'')+' '+String(t?.competition_key||'')+' '+String(t?.city||'')).toLowerCase();
    const rows=[
      [/australian open|grand-slam:australian-open/,{key:'ao',courtA:'#2f86c9',courtB:'#1f5d95',board:'#0b3158',accent:'#78d8ff',scene:'summer-city',label:'Melbourne summer'}],
      [/roland|french open|grand-slam:roland-garros/,{key:'rg',courtA:'#cf7948',courtB:'#a64f2f',board:'#173653',accent:'#f2c58d',scene:'paris-clay',label:'Paris clay'}],
      [/wimbledon|grand-slam:wimbledon/,{key:'wimbledon',courtA:'#69934f',courtB:'#416d36',board:'#28482d',accent:'#d8c6ef',scene:'heritage',label:'London heritage'}],
      [/us open|grand-slam:us-open/,{key:'uso',courtA:'#315f9e',courtB:'#23477f',board:'#102b55',accent:'#f5df61',scene:'ny-night',label:'New York night'}],
      [/indian wells|bnp paribas|masters:indian-wells/,{key:'indian-wells',courtA:'#3b82a4',courtB:'#285f77',board:'#5c4630',accent:'#e8c68c',scene:'desert',label:'Desert stadium'}],
      [/miami open|masters:miami/,{key:'miami',courtA:'#28a2a7',courtB:'#1d6f7d',board:'#153d59',accent:'#ff78be',scene:'tropical',label:'Miami nights'}],
      [/monte[- ]carlo|masters:monte-carlo/,{key:'monte-carlo',courtA:'#c56f46',courtB:'#9f4d32',board:'#19435d',accent:'#75d5ef',scene:'coast',label:'Riviera clay'}],
      [/madrid|masters:madrid/,{key:'madrid',courtA:'#b86542',courtB:'#8f402d',board:'#391d4d',accent:'#e59cff',scene:'city',label:'Madrid show court'}],
      [/internazionali|rome|roma|masters:rome/,{key:'rome',courtA:'#c27349',courtB:'#97452e',board:'#38513c',accent:'#e6c980',scene:'classic',label:'Roman clay'}],
      [/canada|toronto|montreal|masters:canada/,{key:'canada',courtA:'#2e6f9f',courtB:'#214d78',board:'#722c34',accent:'#f2e9db',scene:'city',label:'Canadian summer'}],
      [/cincinnati|masters:cincinnati/,{key:'cincinnati',courtA:'#397a83',courtB:'#285761',board:'#1d3947',accent:'#a8e2ca',scene:'summer-city',label:'Midwest hard court'}],
      [/shanghai|masters:shanghai/,{key:'shanghai',courtA:'#287b7c',courtB:'#1f565a',board:'#59252b',accent:'#f76b61',scene:'city',label:'Shanghai lights'}],
      [/paris masters|paris la defense|masters:paris/,{key:'paris',courtA:'#4d466f',courtB:'#2e2c4c',board:'#151622',accent:'#9e8cff',scene:'indoor',label:'Paris indoor'}],
      [/atp finals|nitto|atp:finals/,{key:'finals',courtA:'#384f68',courtB:'#202f42',board:'#0b1725',accent:'#62d7ef',scene:'indoor',label:'Finals arena'}],
      [/laver/,{key:'laver',courtA:'#2c506e',courtB:'#182d42',board:'#0c1520',accent:'#f05d63',scene:'indoor',label:'Team arena'}],
      [/next gen/,{key:'nextgen',courtA:'#674f92',courtB:'#3c315c',board:'#21182f',accent:'#90ffbd',scene:'neon-indoor',label:'Next Gen stage'}],
      [/doha|qatar/,{key:'doha',courtA:'#2e6e8a',courtB:'#204a63',board:'#5d482b',accent:'#e8cb78',scene:'desert-night',label:'Doha night'}],
      [/dubai/,{key:'dubai',courtA:'#2f7f82',courtB:'#22585b',board:'#5c4529',accent:'#f0ca72',scene:'desert-night',label:'Dubai lights'}],
      [/rotterdam/,{key:'rotterdam',courtA:'#274d69',courtB:'#173448',board:'#17212b',accent:'#f39a4b',scene:'indoor',label:'Rotterdam indoor'}],
      [/acapulco/,{key:'acapulco',courtA:'#248b9b',courtB:'#176274',board:'#4e3033',accent:'#ff9d6d',scene:'coast-night',label:'Pacific night'}],
      [/barcelona/,{key:'barcelona',courtA:'#c47046',courtB:'#99472f',board:'#233e5c',accent:'#e8c177',scene:'club-clay',label:'Barcelona clay club'}],
      [/queen|queens club/,{key:'queens',courtA:'#63884d',courtB:'#405f38',board:'#233850',accent:'#f1e8cc',scene:'heritage',label:'London grass club'}],
      [/halle/,{key:'halle',courtA:'#5f8749',courtB:'#3d6336',board:'#27475e',accent:'#bde3ff',scene:'grass-arena',label:'German grass'}],
      [/washington|citi open/,{key:'washington',courtA:'#315a87',courtB:'#244263',board:'#652b34',accent:'#f0e5d4',scene:'city',label:'DC hard court'}],
      [/beijing|china open/,{key:'beijing',courtA:'#356b97',courtB:'#274d72',board:'#5c252d',accent:'#efcf77',scene:'city',label:'Beijing show court'}],
      [/tokyo|rakuten|japan open/,{key:'tokyo',courtA:'#355a78',courtB:'#253c55',board:'#351f28',accent:'#ef6c6c',scene:'city',label:'Tokyo arena'}],
      [/vienna/,{key:'vienna',courtA:'#384b5c',courtB:'#222f3d',board:'#241d1d',accent:'#d8b56d',scene:'indoor',label:'Vienna indoor'}],
      [/basel/,{key:'basel',courtA:'#43515c',courtB:'#293540',board:'#3f2026',accent:'#e45c65',scene:'indoor',label:'Basel indoor'}],
      [/rio/,{key:'rio',courtA:'#c37645',courtB:'#9b4d31',board:'#3b5738',accent:'#edce57',scene:'tropical',label:'Rio clay'}],
      [/dallas/,{key:'dallas',courtA:'#30566f',courtB:'#213d52',board:'#17212b',accent:'#62d5e8',scene:'indoor',label:'Dallas indoor'}],
      [/brisbane/,{key:'brisbane',courtA:'#3287a6',courtB:'#24617c',board:'#17425a',accent:'#8fe2e4',scene:'summer-city',label:'Brisbane summer'}],
      [/adelaide/,{key:'adelaide',courtA:'#39749e',courtB:'#275778',board:'#234056',accent:'#f4be73',scene:'summer-city',label:'Adelaide summer'}],
      [/auckland/,{key:'auckland',courtA:'#397f83',courtB:'#285d65',board:'#284b44',accent:'#b9e6d0',scene:'coast',label:'Auckland summer'}],
      [/buenos aires/,{key:'buenos-aires',courtA:'#c6784a',courtB:'#9d4f32',board:'#35546e',accent:'#9ed9f1',scene:'club-clay',label:'Buenos Aires clay'}],
      [/marseille/,{key:'marseille',courtA:'#31566f',courtB:'#223b52',board:'#173146',accent:'#68d5ed',scene:'indoor',label:'Marseille indoor'}],
      [/delray/,{key:'delray',courtA:'#2e7e9a',courtB:'#205b75',board:'#28445a',accent:'#ff9d7c',scene:'coast',label:'Florida coast'}],
      [/houston/,{key:'houston',courtA:'#b96f48',courtB:'#914832',board:'#293c51',accent:'#dcb47c',scene:'club-clay',label:'Houston clay'}],
      [/bucharest|bucuresti/,{key:'bucharest',courtA:'#c07849',courtB:'#984c31',board:'#334a69',accent:'#f1ca58',scene:'classic',label:'Bucharest clay'}],
      [/geneva|geneve/,{key:'geneva',courtA:'#c27649',courtB:'#984b31',board:'#5a2d31',accent:'#eee7dc',scene:'alpine',label:'Geneva clay'}],
      [/stuttgart/,{key:'stuttgart',courtA:'#61884b',courtB:'#3e6537',board:'#54292e',accent:'#f4dfb6',scene:'grass-arena',label:'Stuttgart grass'}],
      [/eastbourne/,{key:'eastbourne',courtA:'#668b4d',courtB:'#436838',board:'#233d5a',accent:'#d9eaf7',scene:'coast',label:'English coast grass'}],
      [/mallorca/,{key:'mallorca',courtA:'#648a4f',courtB:'#426a3c',board:'#205160',accent:'#91deef',scene:'coast',label:'Island grass'}],
      [/los cabos/,{key:'los-cabos',courtA:'#357e91',courtB:'#265968',board:'#5a4330',accent:'#f2b775',scene:'desert-night',label:'Baja night'}],
      [/kitzbuhel|kitzbühel/,{key:'kitzbuhel',courtA:'#bf7448',courtB:'#94482f',board:'#374b3a',accent:'#d7e4c1',scene:'alpine',label:'Alpine clay'}],
      [/gstaad/,{key:'gstaad',courtA:'#bf7447',courtB:'#93482f',board:'#39483b',accent:'#e1e2d3',scene:'alpine',label:'Swiss alpine clay'}],
      [/umag/,{key:'umag',courtA:'#c27447',courtB:'#994a2f',board:'#214c61',accent:'#82d7e7',scene:'coast',label:'Adriatic clay'}],
      [/winston[- ]salem/,{key:'winston-salem',courtA:'#34688d',courtB:'#264b6a',board:'#28394b',accent:'#d6b96e',scene:'summer-city',label:'Carolina hard court'}],
      [/metz/,{key:'metz',courtA:'#414c66',courtB:'#2a334a',board:'#281f39',accent:'#bd9bea',scene:'indoor',label:'Metz indoor'}]
    ];
    for(const [re,theme] of rows)if(re.test(n))return theme;
    return null;
  };
  const generatedTheme=(t,m)=>{
    const surface=String(m?.surface||t?.surface||'Dur').toLowerCase();
    const h=themeHash([t?.competition_key,t?.name,t?.city,t?.country].filter(Boolean).join('|'));
    const hard=[
      ['#326f98','#244f74'],['#367f8e','#265d6b'],['#395f91','#29466e'],['#3a7896','#28566f'],
      ['#426888','#2d4b67'],['#2d7482','#205765'],['#486a8a','#304d6a'],['#336d84','#254f64']
    ];
    const clay=[
      ['#c67648','#9d4c31'],['#be7047','#93452f'],['#cc7d4e','#a25434'],['#b96945','#8e422f'],
      ['#c27a51','#985138'],['#b8734c','#905039']
    ];
    const grass=[
      ['#668b4f','#42693b'],['#5e8349','#3d6237'],['#6b9053','#486f3f'],['#63884c','#405f38'],
      ['#5b7e47','#3b5d35'],['#709358','#496f41']
    ];
    const pool=/terre|clay/.test(surface)?clay:/gazon|grass/.test(surface)?grass:hard;
    const pair=pool[h%pool.length];
    const hue=(h>>>8)%360;
    const indoor=Boolean(m?.indoor)||/indoor|interieur|intérieur/.test(surface);
    const tier=venueTier();
    const scenes=indoor?['indoor','neon-indoor','arena']:tier==='challenger'?['club','regional','city']:tier==='itf'?['local','regional','club']:['city','summer-city','club'];
    const scene=scenes[(h>>>16)%scenes.length];
    return {
      key:'event-'+(h%9973).toString(36),
      courtA:pair[0],courtB:pair[1],
      board:'hsl('+hue+' 32% '+(indoor?'15%':'20%')+')',
      accent:'hsl('+((hue+52)%360)+' 72% 66%)',
      scene,label:t?.city?String(t.city)+' identity':'Tour identity'
    };
  };
  const tournamentTheme=()=>{
    const m=meta(),t=m.tournament||{};
    return signatureTheme(t)||generatedTheme(t,m);
  };
  const themeVenueMood=theme=>{
    const s=String(theme?.scene||'');
    if(/desert/.test(s))return 'dry';
    if(/coast|tropical/.test(s))return 'coastal';
    if(/heritage|club/.test(s))return 'club';
    if(/alpine/.test(s))return 'alpine';
    if(/indoor|arena|neon/.test(s))return 'indoor';
    if(/night|city/.test(s))return 'city';
    return 'tour';
  };

  const tournamentLabel=()=>{
    const t=meta().tournament||{};
    return String(t.name||t.category||t.circuit||'Court Boss');
  };
  const venueLabel=()=>{
    const t=meta().tournament||{};
    if(t.venue)return String(t.venue);
    const k=String(t.competition_key||'').toLowerCase(),n=String(t.name||'').toLowerCase();
    if(k==='grand-slam:australian-open'||/australian open/.test(n))return 'Rod Laver Arena';
    if(k==='grand-slam:roland-garros'||/roland/.test(n))return 'Court Philippe-Chatrier';
    if(k==='grand-slam:wimbledon'||/wimbledon/.test(n))return 'Centre Court';
    if(k==='grand-slam:us-open'||/us open/.test(n))return 'Arthur Ashe Stadium';
    if(k==='masters:indian-wells'||/indian wells|bnp paribas/.test(n))return 'Stadium 1';
    if(k==='masters:miami'||/miami open/.test(n))return 'Hard Rock Stadium';
    if(k==='masters:monte-carlo'||/monte-carlo/.test(n))return 'Court Rainier III';
    if(k==='masters:madrid'||/madrid open/.test(n))return 'Manolo Santana Stadium';
    if(k==='masters:rome'||/internazionali|rome/.test(n))return 'Campo Centrale';
    if(k==='masters:canada')return String(t.city||'Canada')+' · Centre Court';
    if(k==='masters:cincinnati'||/cincinnati/.test(n))return 'Center Court';
    if(k==='masters:shanghai'||/shanghai/.test(n))return 'Stadium Court';
    if(k==='masters:paris'||/paris masters/.test(n))return 'Paris La Défense Arena';
    if(k==='atp:finals'||/atp finals|nitto/.test(n))return 'Inalpi Arena';
    const city=String(t.city||'').trim();
    return venueTier()==='slam'?'Centre Court':
      venueTier()==='premium'?(city?city+' · Show Court':'Show Court'):
      venueTier()==='challenger'?(city?city+' · Challenger Centre Court':'Challenger Centre Court'):
      venueTier()==='itf'?(city?city+' · ITF Court 1':'ITF Court 1'):
      (city?city+' · Centre Court':'Tour Centre Court');
  };
  const weatherIcon=w=>{
    const c=String(w?.condition||'').toLowerCase();
    if(/pluie|rain/.test(c))return '☔';
    if(/nuage|cloud/.test(c))return '☁';
    if(/vent|wind/.test(c))return '≋';
    if(/chaud|hot/.test(c)||Number(w?.temperature_c||0)>=29)return '☀';
    if(/toit|indoor|climatis/.test(c))return '⌂';
    return '◉';
  };
  const strokeLabel=s=>({
    service:'Service',coup_droit:'Coup droit',revers:'Revers',volee:'Volée',volley:'Volée',
    smash:'Smash',lob:'Lob',amortie:'Amortie',drop_shot:'Amortie',slice:'Slice'
  }[String(s||'').toLowerCase()]||String(s||'').replaceAll('_',' '));
  const reactionLabel=r=>({
    celebrate:'Célébration',frustrated:'Frustration',reset:'Recentrage',pain:'Douleur',
    pumped:'Poing serré',calm:'Calme'
  }[String(r||'').toLowerCase()]||'');

  const ensureAtmosphere=()=>{
    const court=document.querySelector('.cb-live-card .cb-court');if(!court)return;
    const m=meta(),v=visual(),lp=point(),w=m.weather||{},a=m.ambience||{},tier=venueTier(),theme=tournamentTheme();
    const card=court.closest('.cb-live-card');
    court.dataset.cbVenueTier=tier;
    court.dataset.cbWeather=slug(w.condition||'stable');
    court.dataset.cbTournamentSkin=theme.key;
    court.dataset.cbScene=slug(theme.scene||'tour');
    court.dataset.cbVenueMood=themeVenueMood(theme);
    court.style.setProperty('--cb-v14-crowd',String(cap(a.crowd_intensity||45,10,100)/100));
    court.style.setProperty('--cb-v14-wind',String(cap(w.wind_kph||0,0,35)/35));
    court.style.setProperty('--cb-v14-heat',String(cap((Number(w.temperature_c||21)-18)/20,0,1)));
    for(const host of [court,card].filter(Boolean)){
      host.style.setProperty('--cb-theme-court-a',theme.courtA);
      host.style.setProperty('--cb-theme-court-b',theme.courtB);
      host.style.setProperty('--cb-theme-board',theme.board);
      host.style.setProperty('--cb-theme-accent',theme.accent);
    }
    if(card){card.dataset.cbTournamentSkin=theme.key;card.dataset.cbScene=slug(theme.scene||'tour');card.dataset.cbVenueTier=tier}

    let shell=court.querySelector('.cb-atmosphere-v14');
    if(!shell){shell=el('div','cb-atmosphere-v14');court.prepend(shell)}
    const indoor=Boolean(m.indoor)||/indoor|toit|climatis/i.test(String(w.condition||''));
    const rain=Number(w.rain_risk_pct||0)>=45&&!indoor;
    shell.innerHTML=
      '<div class="cb-stands-v14 back"><i></i><i></i><i></i><i></i><i></i><i></i></div>'+
      '<div class="cb-stands-v14 front"><i></i><i></i><i></i><i></i></div>'+
      '<div class="cb-venue-board-v14"><span>'+esc(tournamentLabel())+'</span><b>'+esc(venueLabel())+'</b><em>'+esc(theme.label||'Tournament identity')+'</em></div>'+
      '<div class="cb-theme-ribbon-v14"><span>'+esc(String(m.tournament?.category||m.tournament?.circuit||tier).toUpperCase())+'</span><i></i><b>'+esc(String(m.surface||m.tournament?.surface||'Tennis'))+'</b></div>'+
      '<div class="cb-weather-v14"><span>'+weatherIcon(w)+'</span><b>'+esc(w.condition||'Stable')+'</b><em>'+Math.round(Number(w.temperature_c||21))+'° · vent '+Math.round(Number(w.wind_kph||0))+' km/h · '+Math.round(Number(w.humidity_pct||50))+'%</em></div>'+
      (rain?'<div class="cb-rain-v14">'+Array.from({length:18},(_,i)=>'<i style="--i:'+i+'"></i>').join('')+'</div>':'')+
      (indoor?'<div class="cb-roof-v14"></div>':'')+
      '<div class="cb-crowd-wave-v14"></div>';

    const shots=Array.isArray(v.shots)?v.shots:[];
    const last=shots[shots.length-1]||{};
    court.dataset.cbLastStroke=slug(last.stroke||last.pattern||lp.ending||'neutral');
    court.dataset.cbLastPattern=slug(last.pattern||lp.ending||'neutral');
    court.classList.toggle('cb-v14-medical',String(lp.phase||'')==='medical'||Boolean(v.medical)||Boolean(lp.medical));
    court.classList.toggle('cb-v14-big-point',['break_point','set_point','match_point','tiebreak'].includes(String(v.stake||lp.stake||'')));
  };

  const setReaction=(dot,reaction,won)=>{
    if(!dot)return;
    [...dot.classList].filter(x=>x.startsWith('cb-react-')||x.startsWith('cb-hit-')).forEach(x=>dot.classList.remove(x));
    if(reaction)dot.classList.add('cb-react-'+slug(reaction));
    if(won===true)dot.classList.add('cb-point-winner-v14');
    if(won===false)dot.classList.add('cb-point-loser-v14');
  };
  const ensurePlayerReactions=()=>{
    const court=document.querySelector('.cb-live-card .cb-court');if(!court)return;
    const v=visual(),lp=point(),shots=Array.isArray(v.shots)?v.shots:[],last=shots[shots.length-1]||{};
    const u=court.querySelector('.fm-player-dot.user:not(.cb-live-double-partner-v13)');
    const o=court.querySelector('.fm-player-dot.opponent:not(.cb-live-double-partner-v13)');
    const winner=String(lp.winner||'');
    setReaction(u,v.user_reaction,winner?winner==='user':null);
    setReaction(o,v.opponent_reaction,winner?winner==='opponent':null);
    const hitter=String(last.hitter||'');
    const target=hitter==='user'?u:hitter==='opponent'?o:null;
    if(target){
      target.classList.add('cb-hit-'+slug(last.stroke||last.pattern||'groundstroke'));
      target.dataset.cbShot=strokeLabel(last.stroke||last.pattern||'');
    }

    const doubles=[...court.querySelectorAll('.cb-live-double-partner-v13')];
    doubles.forEach(d=>{
      d.classList.toggle('cb-react-celebrate',Boolean(winner)&&d.classList.contains(winner==='user'?'user':'opponent'));
    });
  };

  const ensurePointCinema=()=>{
    const card=document.querySelector('.cb-live-card');const court=card?.querySelector('.cb-court');if(!card||!court)return;
    const s=live(),v=visual(),lp=point(),m=meta(),shots=Array.isArray(v.shots)?v.shots:[],last=shots[shots.length-1]||{};
    const key=[s?.id||0,lp?.point_no||0,lp?.phase||'',lp?.visual_label||''].join('|');
    let hud=card.querySelector('.cb-cinema-v14');
    if(!hud){hud=el('div','cb-cinema-v14');court.insertAdjacentElement('afterend',hud)}
    const momentum=cap(Number(s?.momentum??50),0,100);
    const reactionU=reactionLabel(v.user_reaction),reactionO=reactionLabel(v.opponent_reaction);
    const weather=m.weather||{};
    const stroke=strokeLabel(last.stroke||last.pattern||lp.ending||'Point');
    const speed=Number(last.visual_speed_kph||last.speed_kph||last.physics?.speed_kph||0);
    const spin=String(last.spin||'');
    hud.innerHTML=
      '<div class="cb-cinema-head-v14"><div><small>MATCH CENTER V14</small><b>'+esc(lp.visual_label||stroke||'Point en cours')+'</b></div><span>'+weatherIcon(weather)+' '+Math.round(Number(weather.temperature_c||21))+'° · '+esc(String(weather.condition||'stable'))+'</span></div>'+
      '<div class="cb-cinema-grid-v14">'+
        '<div><span>Dernier geste</span><b>'+esc(stroke)+(spin?' · '+esc(spin):'')+'</b><em>'+(speed?Math.round(speed)+' km/h':'cinématique attribut-dépendante')+'</em></div>'+
        '<div><span>Réaction</span><b>'+esc(reactionU||'Concentré')+' / '+esc(reactionO||'Concentré')+'</b><em>joueur / adversaire</em></div>'+
        '<div><span>Momentum</span><b>'+Math.round(momentum)+' / 100</b><em>'+(momentum>=62?'tu imposes le rythme':momentum<=38?'pression adverse':'équilibre')+'</em></div>'+
        '<div><span>Atmosphère</span><b>'+esc(String(m.ambience?.crowd_profile||'Tour'))+'</b><em>public '+Math.round(Number(m.ambience?.crowd_intensity||45))+'%</em></div>'+
      '</div>'+
      '<div class="cb-momentum-v14"><i style="width:'+momentum+'%"></i><strong style="left:'+momentum+'%"></strong></div>';

    if(String(lp.phase||'')==='medical'||v.medical||lp.medical){
      let med=card.querySelector('.cb-medical-scene-v14');
      if(!med){med=el('div','cb-medical-scene-v14');court.appendChild(med)}
      const md=v.medical||lp.medical||{};
      const isRetirement=Boolean(md.winner||lp.match_winner||lp.retirement||/abandon|ret\b/i.test(String(lp.visual_label||'')));
      med.className='cb-medical-scene-v14'+(isRetirement?' cb-retirement-scene-v14':'');
      if(isRetirement){
        const retiredSide=String(md.side||lp.retired_side||'');
        const winnerSide=String(md.winner||lp.match_winner||'');
        const injured=md.player_name||'Joueur';
        const detail=[md.injury_type,md.severity].filter(Boolean).join(' · ')||'Le match ne peut pas continuer';
        med.innerHTML='<div><small>ABANDON · RET</small><b>'+esc(injured)+'</b><span>'+esc(detail)+'</span><em>Victoire '+esc(winnerSide==='user'?'joueur géré':winnerSide==='opponent'?'adversaire':'sur abandon')+'</em></div>';
        court.classList.add('cb-v14-retirement');
        court.querySelectorAll('.fm-player-dot').forEach(d=>d.classList.remove('cb-retired-v14','cb-ret-winner-v14'));
        const userDots=[...court.querySelectorAll('.fm-player-dot.user')];
        const oppDots=[...court.querySelectorAll('.fm-player-dot.opponent')];
        (retiredSide==='user'?userDots:retiredSide==='opponent'?oppDots:[]).forEach(d=>d.classList.add('cb-retired-v14'));
        (winnerSide==='user'?userDots:winnerSide==='opponent'?oppDots:[]).forEach(d=>d.classList.add('cb-ret-winner-v14'));
      }else{
        med.innerHTML='<div><small>ARRÊT MÉDICAL</small><b>'+esc(md.player_name||'Joueur')+'</b><span>'+esc(md.injury_type||lp.visual_label||'Intervention du kiné')+'</span></div>';
        court.classList.remove('cb-v14-retirement');
      }
    }else{
      card.querySelector('.cb-medical-scene-v14')?.remove();
      court.classList.remove('cb-v14-retirement');
      court.querySelectorAll('.fm-player-dot').forEach(d=>d.classList.remove('cb-retired-v14','cb-ret-winner-v14'));
    }

    if(key!==lastPointKey){
      lastPointKey=key;
      court.classList.remove('cb-v14-point-pop');
      void court.offsetWidth;
      court.classList.add('cb-v14-point-pop');
      setTimeout(()=>court.classList.remove('cb-v14-point-pop'),900);
    }
  };

  const enhance=()=>{ensureAtmosphere();ensurePlayerReactions();ensurePointCinema()};
  let queued=false;
  const schedule=()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;enhance()})};
  const root=document.getElementById('app')||document.body;
  new MutationObserver(schedule).observe(root,{childList:true,subtree:true,attributes:false});
  schedule();
  console.info('Court Boss Match Center V14 spectacle active');
})();