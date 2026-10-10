/* Match Center V6: detailed, lightweight live arena and operational tactics.
   A visual layer only: existing game logic owns tactic updates, saves and physics. */
(function(){
 'use strict';
 const NS='http://www.w3.org/2000/svg';
 const el=(tag,klass,text)=>{const e=document.createElement(tag);e.className=klass;if(text!==undefined)e.textContent=text;return e};
 const svgEl=(tag,attrs={})=>{const e=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,String(v));return e};
 const hash=s=>{let h=2166136261>>>0;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)>>>0}return h>>>0};
 const rand=(seed)=>{let s=seed||1;return ()=>{s^=s<<13;s^=s>>>17;s^=s<<5;return(s>>>0)/4294967296}};
 const localMeta=()=>typeof local!=='undefined'?local.liveMatch?.stats?._meta||{}:{};
 const palette=['#d9e3e9','#b7cee1','#8daeca','#a5b4b5','#d7bbb0','#e1d3a8','#789eaf','#c5d2ca','#9a8690','#e2e1d8','#466d92'];
 function crowd(svg,seed,tier){
   const rng=rand(hash(seed));
   const dense=tier==='itf'?.24:tier==='challenger'?.49:tier==='premium'?.78:1;
   const g=svgEl('g',{'class':'cb-v6-spectators'});
   const sections=[
     {type:'top',x0:98,x1:1102,y0:14,y1:155,rows:9,cols:89},
     {type:'left',x0:12,x1:168,y0:135,y1:667,rows:37,cols:11},
     {type:'right',x0:1032,x1:1188,y0:135,y1:667,rows:37,cols:11},
     {type:'bottom',x0:108,x1:1092,y0:657,y1:756,rows:6,cols:88}
   ];
   for(const sect of sections){
     for(let row=0;row<sect.rows;row++)for(let col=0;col<sect.cols;col++){
       if(rng()>dense*(sect.type==='bottom'?.84:1))continue;
       const x=sect.x0+(col+.48+(rng()-.5)*.35)*(sect.x1-sect.x0)/sect.cols;
       const y=sect.y0+(row+.48+(rng()-.5)*.4)*(sect.y1-sect.y0)/sect.rows;
       // Gaps between seat sections read as stairways and venue aisles.
       if(sect.type==='top'||sect.type==='bottom'){
         if([.22,.5,.78].some(v=>Math.abs(col/sect.cols-v)<.011))continue;
       }else if(row%13===0)continue;
       const depth=sect.type==='top'?(1-row/sect.rows):sect.type==='bottom'?row/sect.rows:Math.abs(x-600)/600;
       const radius=sect.type==='top'?2.4+depth*.3:sect.type==='bottom'?2.8+depth*.4:2.1;
       const head=svgEl('circle',{cx:x,cy:y-1.3,r:radius*.67,fill:['#d4aa8c','#deb99a','#ad826a','#efd0ab','#9c7160'][Math.floor(rng()*5)],opacity:.83});
       const jacket=svgEl('path',{d:'M '+(x-radius*1.22).toFixed(1)+' '+(y+radius*.9).toFixed(1)+' Q '+x.toFixed(1)+' '+(y-radius*.2).toFixed(1)+' '+(x+radius*1.22).toFixed(1)+' '+(y+radius*.9).toFixed(1)+' Z',
         fill:palette[Math.floor(rng()*palette.length)],opacity:.68});
       g.append(head,jacket);
     }
   }
   svg.append(g);
 }
 function buildSvg(seed,tier,accent){
   const svg=svgEl('svg',{viewBox:'0 0 1200 760',preserveAspectRatio:'none','aria-hidden':'true','class':'cb-v6-stadium-svg'});
   const defs=svgEl('defs');
   const grad=svgEl('linearGradient',{id:'cb-v6-stands-dark',x1:'0',y1:'0',x2:'0',y2:'1'});
   for(const [offset,color] of [['0%','#061421'],['51%','#233d54'],['100%','#09182a']])grad.append(svgEl('stop',{offset,'stop-color':color}));
   const aisles=svgEl('linearGradient',{id:'cb-v6-aisle',x1:'0',y1:'0',x2:'1',y2:'0'});
   for(const [offset,color] of [['0%','#061320'],['45%','#50677c'],['52%','#b9c9cf'],['100%','#091929']])aisles.append(svgEl('stop',{offset,'stop-color':color}));
   defs.append(grad,aisles);svg.append(defs);
   const base=svgEl('g',{'class':'cb-v6-bowls'});
   [
     'M0 0H1200V154L1057 153L973 94H227L143 153L0 154Z',
     'M0 88L183 159L176 628L0 744Z',
     'M1200 88L1017 159L1024 628L1200 744Z',
     'M0 760H1200L1031 637H169Z'
   ].forEach(d=>base.append(svgEl('path',{d,fill:'url(#cb-v6-stands-dark)',stroke:'#4a6780','stroke-width':2})));
   // Contour lighting and staggered seating sections with grounded risers.
   for(let i=0;i<10;i++){
     const t=i/10;
     const y=15+i*15;
     base.append(svgEl('path',{d:'M '+(60+i*17)+' '+y+' Q 600 '+(y+10)+' '+(1140-i*17)+' '+y,stroke:i%2?'#2a4053':'#5a7188','stroke-width':1.4,opacity:.55,fill:'none'}));
   }
   for(let i=0;i<9;i++){
     const x=9+i*18;
     base.append(svgEl('path',{d:'M '+x+' '+(111+i*4)+' L '+x+' '+(680-i*3),stroke:i%2?'#263f58':'#405a70','stroke-width':2,opacity:.4,fill:'none'}));
     base.append(svgEl('path',{d:'M '+(1200-x)+' '+(111+i*4)+' L '+(1200-x)+' '+(680-i*3),stroke:i%2?'#263f58':'#405a70','stroke-width':2,opacity:.4,fill:'none'}));
   }
   svg.append(base);crowd(svg,seed,tier);
   const fittings=svgEl('g',{'class':'cb-v6-fittings'});
   // Safe stairs and railings, not ad-board obstruction on the playing surface.
   for(const x of [335,601,864]){
     fittings.append(svgEl('path',{d:'M '+x+' 4 l -13 145 l 22 0 l 14 -145Z',fill:'url(#cb-v6-aisle)',opacity:.62}));
     fittings.append(svgEl('path',{d:'M '+(x-12)+' 145 L '+(x+4)+' 4',stroke:'#d4e9f2','stroke-width':1.2,opacity:.35}));
   }
   for(const d of [
     'M 0 174 L 175 174 L 220 118 L 980 118 L 1025 174 L 1200 174',
     'M 0 659 L 174 615 L 1026 615 L 1200 659',
     'M 164 154 L 164 635','M 1036 154 L 1036 635'
   ])fittings.append(svgEl('path',{d,fill:'none',stroke:'#91abc3','stroke-width':3,opacity:.65}));
   for(const [x,y] of [[172,160],[1028,160],[172,636],[1028,636]]){
     fittings.append(svgEl('circle',{cx:x,cy:y,r:6,fill:'#d1e6f7',opacity:.38}));
   }
   // Structural beams suggest a large arena, not a tiled icon wall.
   fittings.append(svgEl('path',{d:'M0 43 Q600 -48 1200 43',stroke:'#6089a9','stroke-width':7,fill:'none',opacity:.4}));
   fittings.append(svgEl('path',{d:'M0 59 Q600 -26 1200 59',stroke:'#09283a','stroke-width':3,fill:'none',opacity:.9}));
   for(let i=0;i<10;i++){
     const x=76+i*116;
     fittings.append(svgEl('path',{d:'M '+x+' 35 L '+(x+20)+' 65',stroke:'#87a9b7','stroke-width':2,opacity:.28}));
   }
   svg.append(fittings);
   return svg;
 }
 function decorateCourt(){
   const card=document.querySelector('.cb-live-card');
   const court=card?.querySelector('.cb-court');
   if(!court)return;
   const meta=localMeta(),t=meta.tournament||{};
   const tier=court.dataset.cbVenueTier||'tour';
   const name=String(t.name||t.tournament_name||'Court Boss Tour');
   const seed=[name,t.city||'',tier].join('|');
   card.dataset.cbV6Live='true';
   court.dataset.cbV6Stadium='true';
   const shell=court.querySelector('.cb-v4-venue-graphics');
   if(!shell)return;
   if(shell.dataset.cbV6Seed!==seed||!shell.querySelector('.cb-v6-stadium-svg')){
     shell.querySelector('.cb-v6-stadium-svg')?.remove();
     shell.prepend(buildSvg(seed,tier));
     shell.dataset.cbV6Seed=seed;
   }
 }
 const buttons=[
   {label:'Revers',key:'targetWing',value:'Revers'},
   {label:'Coup droit',key:'targetWing',value:'Coup droit'},
   {label:'Mixte',key:'targetWing',value:'Mixte'},
   {label:'Avancée',key:'returnPos',value:'Avancée'},
   {label:'Reculée',key:'returnPos',value:'Reculée'}
 ];
 function decorateTactics(){
   const card=document.querySelector('.cb-live-card'),panel=card?.querySelector('.cb-coach-panel');
   if(!panel)return;
   const grid=panel.querySelector('.cb-coach-grid'),plans=panel.querySelector('.cb-plan-strip');
   if(!grid||!plans)return;
   const state=typeof local!=='undefined'?(local.tactics||{}):{};
   let head=panel.querySelector(':scope > .cb-v6-coach-head');
   if(!head){
     head=el('div','cb-v6-coach-head');
     const title=el('strong','', 'Plan de jeu');
     const detail=el('span','', 'Consignes appliquées au moteur');
     head.append(title,detail);
     plans.before(head);
   }
   let quick=panel.querySelector(':scope > .cb-v6-tactic-quick');
   if(!quick){
     quick=el('div','cb-v6-tactic-quick');
     const hdr=el('div','cb-v6-quick-label','Cible prioritaire');
     quick.append(hdr);
     const actions=el('div','cb-v6-quick-actions');
     for(const cfg of buttons.slice(0,3)){
       const btn=el('button','cb-v6-tactic-chip',cfg.label);
       btn.type='button';btn.dataset.cbTacticKey=cfg.key;btn.dataset.cbTacticValue=cfg.value;
       btn.addEventListener('click',()=>{if(typeof window.cbSetMatchTactic==='function')window.cbSetMatchTactic(cfg.key,cfg.value)});
       actions.append(btn);
     }
     quick.append(actions);
     const footer=el('p','cb-v6-coach-note','Les réglages prennent effet sur les prochains points.');
     quick.append(footer);
     grid.before(quick);
   }
   quick.querySelectorAll('[data-cb-tactic-key]').forEach(btn=>{
     const key=btn.dataset.cbTacticKey,value=btn.dataset.cbTacticValue;
     const active=String(state[key]||'Mixte')===value;
     btn.classList.toggle('active',active);btn.setAttribute('aria-pressed',String(active));
   });
   const sliders=grid.querySelectorAll('.cb-coach-slider');
   sliders.forEach(box=>{
     const input=box.querySelector('input[type="range"]');
     if(!input)return;
     const value=Number(input.value||0);
     box.style.setProperty('--cb-v6-progress',value+'%');
   });
   let courtMap=panel.querySelector(':scope > .cb-v6-court-map');
   if(!courtMap){
     courtMap=el('div','cb-v6-court-map');
     const label=el('div','cb-v6-map-label','Zones ciblées');
     const pitch=el('div','cb-v6-mini-court');
     const front=el('div','cb-v6-mini-target left');
     const back=el('div','cb-v6-mini-target right');
     const divider=el('div','cb-v6-mini-net');
     pitch.append(front,back,divider);courtMap.append(label,pitch);
     grid.after(courtMap);
   }
   const target=String(state.targetWing||'Mixte');
   courtMap.dataset.target=target==='Revers'?'backhand':target==='Coup droit'?'forehand':'mixed';
 }
 let queued=false;
 const enhance=()=>{decorateCourt();decorateTactics()};
 const schedule=()=>{
   if(queued)return;queued=true;
   requestAnimationFrame(()=>{queued=false;enhance()});
 };
 const root=document.getElementById('app');
 if(root)new MutationObserver(schedule).observe(root,{childList:true,subtree:true});
 schedule();
 window.cbMatchExperienceV6={enhance};
})();