/*
 * Match Center FM Layout V2
 * UI only: never reads/writes live match, tactics or career save data.
 * Persisted preference and immediate rollback to classic match view.
 */
(function(){
  "use strict";
  const KEY="cb-match-layout-preference-v2";
  const param=new URLSearchParams(window.location.search).get("match-ui");
  const read=()=>{
    try{return window.localStorage.getItem(KEY)}catch{return null}
  };
  const write=value=>{
    try{window.localStorage.setItem(KEY,value)}catch{}
  };
  if(param==="v2"||param==="classic")write(param);
  let mode=read()==="classic"?"classic":"v2";
  const update=()=>{
    document.documentElement.classList.toggle("cb-match-layout-v2",mode==="v2");
    document.querySelectorAll(".cb-layout-switch-v2").forEach(button=>{
      button.textContent=mode==="v2"?"Vue classique":"Vue Football Manager";
      button.setAttribute("aria-label",mode==="v2"?"Revenir à la présentation classique du match":"Activer la nouvelle présentation Football Manager");
      button.setAttribute("aria-pressed",String(mode==="v2"));
      button.title="L'affichage change sans modifier le match ni la sauvegarde";
    });
  };
  const toggle=()=>{
    mode=mode==="v2"?"classic":"v2";
    write(mode);
    update();
  };
  const enhance=()=>{
    const head=document.querySelector(".cb-live-card > .cb-broadcast-head");
    if(!head||head.querySelector(".cb-layout-switch-v2"))return;
    const button=document.createElement("button");
    button.className="cb-layout-switch-v2";
    button.type="button";
    button.addEventListener("click",toggle);
    head.appendChild(button);
    update();
  };
  update();
  const root=document.getElementById("app");
  if(!root)return;
  const observer=new MutationObserver(()=>{
    if(document.querySelector(".cb-live-card > .cb-broadcast-head:not(:has(.cb-layout-switch-v2))"))enhance();
  });
  observer.observe(root,{childList:true,subtree:true});
  enhance();
})();
