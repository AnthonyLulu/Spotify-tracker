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
  const tournamentLabel=()=>{
    const t=meta().tournament||{};
    return String(t.name||t.category||t.circuit||'Court Boss');
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
    const m=meta(),v=visual(),lp=point(),w=m.weather||{},a=m.ambience||{},tier=venueTier();
    court.dataset.cbVenueTier=tier;
    court.dataset.cbWeather=slug(w.condition||'stable');
    court.style.setProperty('--cb-v14-crowd',String(cap(a.crowd_intensity||45,10,100)/100));
    court.style.setProperty('--cb-v14-wind',String(cap(w.wind_kph||0,0,35)/35));
    court.style.setProperty('--cb-v14-heat',String(cap((Number(w.temperature_c||21)-18)/20,0,1)));

    let shell=court.querySelector('.cb-atmosphere-v14');
    if(!shell){shell=el('div','cb-atmosphere-v14');court.prepend(shell)}
    const indoor=Boolean(m.indoor)||/indoor|toit|climatis/i.test(String(w.condition||''));
    const rain=Number(w.rain_risk_pct||0)>=45&&!indoor;
    shell.innerHTML=
      '<div class="cb-stands-v14 back"><i></i><i></i><i></i><i></i><i></i><i></i></div>'+
      '<div class="cb-stands-v14 front"><i></i><i></i><i></i><i></i></div>'+
      '<div class="cb-venue-board-v14"><span>'+esc(tournamentLabel())+'</span><b>'+esc(tier==='slam'?'CENTRE COURT':tier==='premium'?'SHOW COURT':tier==='challenger'?'CHALLENGER ARENA':tier==='itf'?'ITF COURT':'TOUR COURT')+'</b></div>'+
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