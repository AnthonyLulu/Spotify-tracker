/* Court Boss V7 - production responsive match UX.
   Uses real V1 engine setters: targetWing, aggression, tempo, effort.
   No gameplay rules, persistence, score or outcome logic is replaced.
 */
(function(){
 'use strict';
 let expanded=false;
 const specs=[
   {id:'aggression',title:'Agressivité',key:'aggression',choices:[['Défensive',40],['Équilibrée',58],['Agressive',78]]},
   {id:'tempo',title:'Rythme',key:'tempo',choices:[['Lent','Patient'],['Normal','Neutre'],['Rapide','Rapide']]},
   {id:'effort',title:'Intensité',key:'effort',choices:[['Basse',45],['Standard',60],['Haute',82]]}
 ];
 const element=(tag,klass,text)=>{
   const item=document.createElement(tag);
   item.className=klass;
   if(text!==undefined)item.textContent=text;
   return item;
 };
 const tactics=()=>typeof local==='undefined'?{}:(local.tactics||{});
 function choose(spec,choice){
   if(typeof window.cbSetMatchTactic==='function')window.cbSetMatchTactic(spec.key,choice[1]);
 }
 function update(){
   const card=document.querySelector('.cb-live-card'),panel=card?.querySelector(':scope > .cb-coach-panel');
   if(!panel)return;
   const quick=panel.querySelector('.cb-v6-tactic-quick');
   if(!quick)return;
   card.dataset.cbV7Mobile='ready';
   let shell=panel.querySelector(':scope > .cb-v7-mobile-tactics');
   if(!shell){
     shell=element('section','cb-v7-mobile-tactics');
     shell.setAttribute('aria-label','Consignes rapides du manager');
     for(const spec of specs){
       const row=element('div','cb-v7-choice-row');
       row.dataset.tactic=spec.key;
       const head=element('span','cb-v7-choice-name',spec.title);
       const choices=element('div','cb-v7-segmented');
       for(const choice of spec.choices){
         const btn=element('button','cb-v7-choice',choice[0]);
         btn.type='button';
         btn.dataset.value=String(choice[1]);
         btn.addEventListener('click',()=>choose(spec,choice));
         choices.append(btn);
       }
       row.append(head,choices);shell.append(row);
     }
     const expand=element('button','cb-v7-expand', 'Réglages avancés');
     expand.type='button';
     expand.setAttribute('aria-controls','cb-v7-advanced-zone');
     expand.addEventListener('click',()=>{
       expanded=!expanded;
       update();
     });
     shell.append(expand);
     quick.after(shell);
   }
   panel.dataset.cbV7Expanded=expanded?'true':'false';
   const expand=shell.querySelector('.cb-v7-expand');
   if(expand){
     expand.textContent=expanded?'Masquer les réglages avancés':'Réglages avancés';
     expand.setAttribute('aria-expanded',String(expanded));
   }
   const grid=panel.querySelector('.cb-coach-grid');
   if(grid)grid.id='cb-v7-advanced-zone';
   const state=tactics();
   for(const spec of specs){
     const row=shell.querySelector('[data-tactic="'+spec.key+'"]');
     if(!row)continue;
     const current=state[spec.key]===undefined?(spec.id==='aggression'?58:spec.id==='tempo'?'Neutre':60):state[spec.key];
     let selected=spec.choices.findIndex(x=>String(x[1])===String(current));
     if(selected<0){
       if(spec.key==='tempo')selected=1;
       else selected=spec.choices.reduce((best,c,i)=>Math.abs(Number(c[1])-Number(current))<Math.abs(Number(spec.choices[best][1])-Number(current))?i:best,0);
     }
     row.querySelectorAll('button').forEach((btn,i)=>{
       const yes=i===selected;
       btn.classList.toggle('active',yes);
       btn.setAttribute('aria-pressed',String(yes));
     });
   }
   // The match engine opens tactics as a details panel, sometimes collapsed
   // on a changeover. Keep instant controls accessible on smaller screens.
   if(window.innerWidth<=919&&document.documentElement.classList.contains('cb-match-layout-v2')&&!panel.open)panel.open=true;
 }
 let queued=false;
 const schedule=()=>{
   if(queued)return;
   queued=true;
   requestAnimationFrame(()=>{queued=false;update()});
 };
 const root=document.getElementById('app');
 if(root)new MutationObserver(schedule).observe(root,{subtree:true,childList:true});
 window.addEventListener('resize',schedule,{passive:true});
 schedule();
 window.cbMatchMobileV7={enhance:update};
})();