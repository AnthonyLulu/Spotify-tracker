/* Court Boss V5 - tilted playing surface, not a static screenshot.
   We group the original DOM court primitives (lines, net, players, ball,
   shadows, point trace) under one CSS perspective plane. The original
   percentage coordinates / animation values stay untouched; the visual
   coordinate system is transformed *together*. The plane becomes layout-
   transparent when users switch back to classic mode.
 */
(function(){
  'use strict';
  const selectors=[
    '.fm-court-line','.fm-net','.fm-player-dot','.fm-ball',
    '.cb-ball-shadow','.cb-target-zone','.cb-serve-origin',
    '.cb-rally-trace','.cb-court-watermark'
  ].join(',');
  const make=(name,klass)=>{const node=document.createElement(name);node.className=klass;return node};
  const liveMeta=()=>typeof local==='undefined'?{}:(local.liveMatch?.stats?._meta||{});
  const shortMark=(name,skin)=>{
    const s=(name+' '+skin).toLowerCase();
    if(/australian|\bao\b/.test(s))return 'AO';
    if(/roland|garros|\brg\b/.test(s))return 'RG';
    if(/wimbledon/.test(s))return 'W';
    if(/us open|\buso\b/.test(s))return 'US';
    if(/monte.carlo/.test(s))return 'MC';
    if(/finals/.test(s))return 'FINALS';
    if(/next.?gen/.test(s))return 'NEXT GEN';
    if(/laver/.test(s))return 'LAVER';
    const words=name.trim().split(/\s+/).filter(Boolean);
    return words.slice(0,3).map(w=>w[0]).join('').toUpperCase().slice(0,5)||'CB';
  };
  function enhance(){
    const card=document.querySelector('.cb-live-card');
    const court=card?.querySelector('.cb-court');
    if(!court)return;
    court.dataset.cbV5Court='perspective';
    const meta=liveMeta(),tour=meta.tournament||{};
    const name=String(tour.name||tour.tournament_name||'Court Boss Tour');
    const skin=court.dataset.cbTournamentSkin||'tour';
    let plane=court.querySelector(':scope > .cb-v5-playing-plane');
    if(!plane){plane=make('div','cb-v5-playing-plane');court.appendChild(plane)}
    let emblem=plane.querySelector(':scope > .cb-v5-court-emblem');
    if(!emblem){emblem=make('span','cb-v5-court-emblem');plane.prepend(emblem)}
    const mark=shortMark(name,skin);
    if(emblem.textContent!==mark)emblem.textContent=mark;
    // Extra singles alleys are rendering aids; they do not enter match physics.
    for(const edge of ['left','right']){
      const cls='.cb-v5-singles-sideline.'+edge;
      if(!plane.querySelector(cls))plane.appendChild(make('i','cb-v5-singles-sideline '+edge));
    }
    // Move only the tennis physics/visual primitives, not any coach buttons,
    // ambient weather, benches, court HUD, score, branding or stadium.
    for(const child of Array.from(court.children)){
      if(child===plane)continue;
      if(child.matches(selectors))plane.appendChild(child);
    }
    // V13 adds doubles partner markers after the court was already created.
    // Subsequent mutation scans migrate those circles into the same plane.
  }
  let pending=false;
  const schedule=()=>{
    if(pending)return;
    pending=true;
    requestAnimationFrame(()=>{pending=false;enhance()});
  };
  const root=document.getElementById('app');
  if(root)new MutationObserver(schedule).observe(root,{subtree:true,childList:true});
  schedule();
  window.cbCourtPerspectiveV5={enhance};
})();