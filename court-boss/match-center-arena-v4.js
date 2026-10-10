/* Court Boss Match Center V4: broadcast arena artwork.
 * Decorative-only DOM; gameplay geometry, ball positions, tactics and saves untouched.
 * Every event inherits V14 tournament identity and V3's official logo/fallback.
 */
(function(){
  'use strict';
  const short=(v,n)=>String(v??'').trim().slice(0,n);
  const make=(tag,cls,txt)=>{
    const node=document.createElement(tag);
    node.className=cls;
    if(txt!==undefined)node.textContent=txt;
    return node;
  };
  const abbrev=(t,skin)=>{
    const v=String(t.name||'').toLowerCase();
    const k=String(skin||'').toLowerCase();
    if(k==='ao'||/australian open/.test(v))return 'AO';
    if(k==='rg'||/roland/.test(v))return 'RG';
    if(k==='wimbledon'||/wimbledon/.test(v))return 'W';
    if(k==='uso'||/us open/.test(v))return 'US';
    if(k==='monte-carlo'||/monte.carlo/.test(v))return 'MC';
    if(k==='finals'||/atp finals/.test(v))return 'FINALS';
    if(k==='nextgen'||/next gen/.test(v))return 'NEXT GEN';
    if(k==='laver'||/laver/.test(v))return 'LAVER';
    const initials=String(t.name||'CB').split(/\s+/).filter(Boolean).slice(0,3).map(x=>x[0]).join('');
    return initials.toUpperCase().slice(0,6);
  };
  const newPiece=(parent,cls,txt)=>{
    const div=make('div','cb-v4-'+cls,txt);parent.appendChild(div);return div;
  };
  function enhance(){
    const card=document.querySelector('.cb-live-card');
    const court=card?.querySelector('.cb-court');
    if(!court)return;
    const data=typeof local!=='undefined'?local.liveMatch?.stats?._meta||{}:{};
    const t=data.tournament||{};
    const name=short(t.name||t.tournament_name||'COURT BOSS TOUR',96);
    const city=short(t.city||t.country||'',52);
    const location=short(t.venue||city||'COURT CENTRAL',72);
    const level=short(t.category||t.circuit||'TENNIS',56);
    const theme=court.dataset.cbTournamentSkin||card.dataset.cbTournamentSkin||'tour';
    const tier=court.dataset.cbVenueTier||card.dataset.cbVenueTier||'tour';
    const key=[name,city,location,level,theme,tier].join('|');
    court.dataset.cbV4Arena='enabled';
    card.dataset.cbV4Arena='enabled';
    if(court.dataset.cbV4Key===key&&court.querySelector(':scope > .cb-v4-venue-graphics'))return;
    court.dataset.cbV4Key=key;
    const label=abbrev(t,theme);
    let root=court.querySelector(':scope > .cb-v4-venue-graphics');
    if(!root){root=make('div','cb-v4-venue-graphics');root.setAttribute('aria-hidden','true');court.prepend(root)}
    root.replaceChildren();
    for(const edge of ['back','front','west','east']){
      const grand=newPiece(root,'grandstand cb-v4-grandstand-'+edge);
      for(let i=0;i<4;i++)grand.appendChild(make('i','cb-v4-seat-row'));
    }
    const boardN=newPiece(root,'led cb-v4-led-north');
    boardN.append(make('strong','',label),make('span','',name.toUpperCase()));
    newPiece(root,'led cb-v4-led-south',(city||location).toUpperCase());
    newPiece(root,'led cb-v4-led-west','COURT BOSS');
    newPiece(root,'led cb-v4-led-east',level.toUpperCase());
    const mark1=newPiece(root,'floor-mark cb-v4-floor-mark-left',label);
    mark1.setAttribute('data-label',label);
    const mark2=newPiece(root,'floor-mark cb-v4-floor-mark-right',label);
    mark2.setAttribute('data-label',label);
    const courtSign=newPiece(root,'floor-location',city||location);
    courtSign.title=location;
    const ump=newPiece(root,'umpire-scene');
    ump.append(make('i','cb-v4-umpire-seat'),make('i','cb-v4-umpire-shadow'));
    newPiece(root,'broadcast-camera cb-v4-camera-left');
    newPiece(root,'broadcast-camera cb-v4-camera-right');
    newPiece(root,'arena-lights');
    // Existing V14 and V3 layers continue to own the changing weather,
    // scoreboard, real official logos, and tennis animations.
  }
  let queued=false;
  function schedule(){
    if(queued)return;
    queued=true;
    requestAnimationFrame(()=>{queued=false;enhance()});
  }
  const app=document.getElementById('app');
  if(app)new MutationObserver(schedule).observe(app,{childList:true,subtree:true});
  schedule();
  window.cbMatchArenaV4={enhance};
})();
