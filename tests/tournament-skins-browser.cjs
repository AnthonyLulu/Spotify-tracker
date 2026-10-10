const {chromium}=require("playwright");
const fs=require("node:fs");
const path=require("node:path");
const assert=require("node:assert/strict");
const base=path.resolve(__dirname,"..");
const get=p=>fs.readFileSync(path.join(base,p),"utf8");
const css=[
  "court-boss/app.css","court-boss/match-center-v1.css",
  "court-boss/match-center-v14.css","court-boss/match-center-layout-v2.css",
  "court-boss/match-center-tournament-v3.css",
  "court-boss/match-center-arena-v4.css",
  "court-boss/match-center-perspective-v5.css"
].map(get).join("\n");
const v3=get("court-boss/match-center-tournament-v3.js");
const v4=get("court-boss/match-center-arena-v4.js");
const v5=get("court-boss/match-center-perspective-v5.js");
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
 +'<div class="cb-tv-score" style="--cb-set-count:2"><div class="cb-tv-score-row cb-tv-score-head"><span>JOUEUR</span><span>S1</span><span>S2</span><span>JEU</span><span>PT</span></div><div class="cb-tv-score-row user"><div class="cb-tv-player"><i class="serving"></i><div><b>Arthur Fils 🇫🇷</b><em>Confiance 87 • Forme 92</em></div></div><b class="cb-tv-set won">6</b><b class="cb-tv-set live">4</b><b class="cb-tv-game">3</b><strong class="cb-tv-point">30</strong></div><div class="cb-tv-score-row opponent"><div class="cb-tv-player"><i></i><div><b>Jannik Sinner 🇮🇹</b><em>Confiance 85 • Forme 90</em></div></div><b class="cb-tv-set">4</b><b class="cb-tv-set live">4</b><b class="cb-tv-game">2</b><strong class="cb-tv-point">15</strong></div></div>'
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
      await page.addScriptTag({content:v4});
      await page.addScriptTag({content:v5});
      seen.set("loaded",true);
    }else{
      await page.evaluate(()=>{window.cbTournamentPresentationV3.enhance();window.cbMatchArenaV4.enhance();window.cbCourtPerspectiveV5.enhance();});
    }
    await page.locator(".cb-v3-court-brand").waitFor({state:"attached",timeout:6000});
    await page.locator(".cb-v4-venue-graphics").waitFor({timeout:6000});
    await page.locator(".cb-v5-playing-plane").waitFor({state:"attached",timeout:6000});
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
        arenaCount:court.querySelectorAll(".cb-v4-venue-graphics").length,
        standCount:court.querySelectorAll(".cb-v4-grandstand").length,
        ledLabels:[...court.querySelectorAll(".cb-v4-led")].map(x=>x.textContent),
        preservedLines:court.querySelectorAll(".fm-court-line").length,
        netMesh:getComputedStyle(court.querySelector(".fm-net")).backgroundImage,
        markerPositions:[...court.querySelectorAll(".fm-player-dot")].map(x=>[x.style.left,x.style.top]),
        planeCount:court.querySelectorAll(".cb-v5-playing-plane").length,
        planeTransform:getComputedStyle(court.querySelector(".cb-v5-playing-plane")).transform,
        projectedMarkers:[...court.querySelectorAll(".fm-player-dot")].every(el=>el.closest(".cb-v5-playing-plane")),
        projectedBall:!!court.querySelector(".cb-v5-playing-plane .fm-ball"),
        projectedNet:!!court.querySelector(".cb-v5-playing-plane .fm-net"),
        projectedLines:court.querySelectorAll(".cb-v5-playing-plane .fm-court-line").length,
        tramlines:court.querySelectorAll(".cb-v5-singles-sideline").length,
        outlineHidden:getComputedStyle(court,"::before").display==="none",
        sw:document.documentElement.scrollWidth,iw:window.innerWidth};
    });
    assert.equal(result.name,f.name);
    assert.ok(result.logo.includes(f.name),"tournament logo missing for "+f.name);
    assert.equal(result.theme,f.id);
    assert.equal(result.surf,surface(f.surface));
    assert.equal(result.markerCount,2);assert.equal(result.ballCount,1);
    assert.equal(result.watermark,1);
    assert.equal(result.arenaCount,1,"stadium missing/duplicated");
    assert.equal(result.planeCount,1,"perspective plane missing or duplicated");
    assert.notEqual(result.planeTransform,"none","court is still flat: "+f.name);
    assert.ok(result.projectedMarkers&&result.projectedBall&&result.projectedNet,"animated geometry not in projection: "+f.name);
    assert.equal(result.projectedLines,6,"court markings not projected");
    assert.equal(result.tramlines,2,"singles sidelines missing");
    assert.ok(result.outlineHidden,"old flat court outline still visible");
    await page.evaluate(()=>{window.cbMatchArenaV4.enhance();window.cbCourtPerspectiveV5.enhance();});
    assert.equal(await page.locator(".cb-v5-playing-plane").count(),1,"perspective plane duplicated after refresh");
    assert.equal(await page.locator(".cb-v4-venue-graphics").count(),1,"stadium duplicated after refresh");
    assert.equal(result.standCount,4,"stadium stands missing");
    assert.ok(result.ledLabels.some(x=>x.includes(f.name.toUpperCase())),"event LED board missing "+f.name);
    assert.equal(result.preservedLines,6,"tennis court lines changed");
    assert.ok(result.netMesh.includes("gradient"),"net mesh missing");
    assert.deepEqual(result.markerPositions,[["50%","80%"],["50%","20%"]],"players were moved by renderer");
    assert.ok(result.bg.includes("gradient"),"court surface not themed");
    assert.ok(result.sw<=result.iw+8,"mobile horizontal overflow: "+f.name+" "+result.sw);
    if(["Australian Open","Roland-Garros","Wimbledon","US Open","Monte-Carlo Masters"].includes(f.name)){
      assert.ok(result.bg.includes("gradient"),"court skin missing "+f.name);
    }
    if(["Australian Open","Roland-Garros","Wimbledon","US Open","Monte-Carlo Masters"].includes(f.name)){
      await page.screenshot({path:"perspective-"+size.label+"-"+f.id+".png",fullPage:false});
    }
    console.log("PASS",size.label,f.name,result.surf,result.theme);
   }
   assert.deepEqual(errors,[],"browser errors");
   await page.close();
  }
  console.log("TOURNAMENT V5 PERSPECTIVE AND V4 STADIUM SMOKE PASS");
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});