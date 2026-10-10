const {chromium}=require("playwright");
const fs=require("node:fs");
const path=require("node:path");
const assert=require("node:assert/strict");
const base=path.resolve(__dirname,"..");
const get=p=>fs.readFileSync(path.join(base,p),"utf8");
const css=[
  "court-boss/app.css","court-boss/match-center-v1.css",
  "court-boss/match-center-v14.css","court-boss/match-center-layout-v2.css",
  "court-boss/match-center-tournament-v3.css"
].map(get).join("\n");
const v3=get("court-boss/match-center-tournament-v3.js");
const fixtures=[
 {name:"Australian Open",category:"Grand Chelem",city:"Melbourne",surface:"Dur",id:"ao",a:"#2f86c9",b:"#1f5d95"},
 {name:"Roland-Garros",category:"Grand Chelem",city:"Paris",surface:"Terre battue",id:"rg",a:"#cf7948",b:"#a64f2f"},
 {name:"Wimbledon",category:"Grand Chelem",city:"Londres",surface:"Gazon",id:"wimbledon",a:"#69934f",b:"#416d36"},
 {name:"US Open",category:"Grand Chelem",city:"New York",surface:"Dur",id:"uso",a:"#315f9e",b:"#23477f"},
 {name:"Monte-Carlo Masters",category:"Masters 1000",city:"Monte-Carlo",surface:"Terre battue",id:"monte-carlo",a:"#c56f46",b:"#9f4d32"},
 {name:"Doha ATP 250",category:"ATP 250",city:"Doha",surface:"Dur",id:"doha",a:"#2e6e8a",b:"#204a63"},
 {name:"Lyon Challenger",category:"Challenger 100",city:"Lyon",surface:"Dur",id:"event-82",a:"#356f91",b:"#254f6d"},
 {name:"M25 Antalya",category:"M25",circuit:"ITF",city:"Antalya",surface:"Terre battue",id:"event-103",a:"#be7047",b:"#93452f"}
];
const surface=what=>/terre/i.test(what)?"clay":/gazon/i.test(what)?"grass":"hard";
const fixture=f=>{
 const s=surface(f.surface);
 return '<div class="app-shell"><div class="topbar">COURT BOSS</div><main class="page"><div id="app"><div class="cb-match-shell"><div class="card cb-live-card" data-cb-tournament-skin="'+f.id+'" style="--cb-theme-court-a:'+f.a+';--cb-theme-court-b:'+f.b+';--cb-theme-accent:#61cbe0;--cb-theme-board:#102f44;">'
 +'<div class="cb-broadcast-head"><div class="cb-broadcast-brand"><div class="cb-broadcast-logo">LOGO</div><div><small>'+f.category+'</small><b>'+f.name+'</b><em>'+f.city+'</em></div></div><div class="cb-broadcast-status"><b>LIVE</b></div></div>'
 +'<div class="cb-tv-score"><div class="cb-tv-score-row user"><div class="cb-tv-player">Arthur Fils</div><b>6</b><b>4</b><b>30</b></div></div>'
 +'<div class="cb-match-context">Surface : '+f.surface+'</div>'
 +'<div class="fm-court '+s+' cb-court" data-cb-tournament-skin="'+f.id+'" style="--cb-theme-court-a:'+f.a+';--cb-theme-court-b:'+f.b+';--cb-theme-accent:#61cbe0;--cb-theme-board:#102f44;"><div class="cb-venue-board-v14"><b>'+f.name+'</b></div><i class="fm-court-line baseline top"></i><i class="fm-court-line baseline bottom"></i><i class="fm-court-line sideline left"></i><i class="fm-court-line sideline right"></i><i class="fm-court-line service horizontal top"></i><i class="fm-court-line service horizontal bottom"></i><i class="fm-net"></i><div class="fm-player-dot user" style="left:50%;top:80%">AF</div><div class="fm-player-dot opponent" style="left:50%;top:20%">JS</div><i class="fm-ball" style="left:52%;top:60%"></i></div>'
 +'<div class="cb-match-story"><div class="cb-event-feed">Coup droit gagnant</div></div><div class="cb-live-controls">Pause • 1x • 2x • 3x</div><details open class="cb-coach-panel"><summary>Tactiques</summary></details><div class="cb-stat-grid"><div>Points gagnés</div></div>'
 +'</div></div></main></div>';
};
(async()=>{
 const browser=await chromium.launch({headless:true,args:["--no-sandbox"]});
 try{
  for(const size of [{label:"PC",w:1530,h:900},{label:"iPhone",w:390,h:844}]){
   const page=await browser.newPage({viewport:{width:size.w,height:size.h}});
   const errors=[];page.on("pageerror",err=>errors.push(err.message));
   const seen=new Map();
   for(const f of fixtures){
    await page.setContent('<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>'+fixture(f)+'</body></html>');
    await page.addStyleTag({content:css});
    await page.evaluate(obj=>{
      window.local={liveMatch:{surface:obj.surface,stats:{_meta:{surface:obj.surface,tournament:{name:obj.name,category:obj.category,circuit:obj.circuit||"ATP",city:obj.city,venue:"Court central"}}}}};
      window.tournamentLogoHtml=t=>'<span class="tm-tour-logo-fallback"><b>'+t.name+'</b></span>';
      document.documentElement.classList.add("cb-match-layout-v2");
    },f);
    // Ensure enhancement observes DOM reconstruction, rather than injecting a new JS copy per case.
    if(!seen.has("loaded")){
      await page.addScriptTag({content:v3});
      seen.set("loaded",true);
    }else{
      await page.evaluate(()=>window.cbTournamentPresentationV3.enhance());
    }
    await page.locator(".cb-v3-court-brand").waitFor({timeout:6000});
    const result=await page.evaluate(()=>{
      const court=document.querySelector(".cb-court"),card=document.querySelector(".cb-live-card");
      return {name:card.querySelector(".cb-v3-court-brand b").textContent,
        logo:card.querySelector(".cb-v3-court-logo").textContent,
        theme:card.dataset.cbV3Theme,
        surf:court.dataset.cbV3Surface,
        bg:getComputedStyle(court).backgroundImage,
        markerCount:court.querySelectorAll(".fm-player-dot").length,
        ballCount:court.querySelectorAll(".fm-ball").length,
        watermark:court.querySelectorAll(".cb-v3-court-brand").length,
        sw:document.documentElement.scrollWidth,iw:window.innerWidth};
    });
    assert.equal(result.name,f.name);
    assert.ok(result.logo.includes(f.name),"tournament logo missing for "+f.name);
    assert.equal(result.theme,f.id);
    assert.equal(result.surf,surface(f.surface));
    assert.equal(result.markerCount,2);assert.equal(result.ballCount,1);
    assert.equal(result.watermark,1);
    assert.ok(result.bg.includes("gradient"),"court surface not themed");
    assert.ok(result.sw<=result.iw+8,"mobile horizontal overflow: "+f.name+" "+result.sw);
    if(["Australian Open","Roland-Garros","Wimbledon","US Open","Monte-Carlo Masters"].includes(f.name)){
      assert.ok(result.bg.includes("gradient"),"court skin missing "+f.name);
    }
    if(["Australian Open","Roland-Garros","Wimbledon","US Open","Monte-Carlo Masters"].includes(f.name)){
      await page.screenshot({path:"skin-"+size.label+"-"+f.id+".png",fullPage:false});
    }
    console.log("PASS",size.label,f.name,result.surf,result.theme);
   }
   assert.deepEqual(errors,[],"browser errors");
   await page.close();
  }
  console.log("TOURNAMENT V3 THEME SMOKE PASS");
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});