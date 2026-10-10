/* Real logo regression: exercises the production tournamentLogoHtml,
 * a locally served SVG, the V4 stadium board, and Safari-sized CSS.
 * Unlike earlier mock fixtures this does NOT pretend that "AO" is Wimbledon.
 */
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..','court-boss');
const get=name=>fs.readFileSync(path.join(root,name),'utf8');
const app=get('app.js');
const start=app.indexOf('const MAJOR_TOURNAMENT_LOGOS=[');
const end=app.indexOf('function tournamentPhotoUrl',start);
assert.ok(start>0&&end>start,'tournament logo catalog not found in app.js');
const catalog=app.slice(start,end);
assert.ok(catalog.includes('wimbledon-crest.svg'),'local Wimbledon logo not wired into production catalog');
const asset=get('wimbledon-crest.svg');
assert.ok(asset.includes('<svg')&&asset.includes('THE CHAMPIONSHIPS'),'recognizable Wimbledon badge missing');
const css=['app.css','match-center-v1.css','match-center-v14.css','match-center-layout-v2.css',
  'match-center-tournament-v3.css','match-center-arena-v4.css','match-center-perspective-v5.css',
  'match-center-experience-v6.css','match-center-mobile-v7.css','wimbledon-crest.css'].map(get).join('\n');
const functions=`function esc(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/'/g,'&#39;')}
function cbMediaUrl(u){return String(u||'')}
`+catalog;
const arena=get('match-center-arena-v4.js');
function html(){
 return '<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>'+
   '<div class="app-shell"><main class="page"><div id="app"><div class="cb-match-shell">'+
   '<div class="card cb-live-card" data-cb-v3-theme="wimbledon" data-cb-v7-mobile="ready" style="--cb-theme-accent:#b2d89c;--cb-theme-board:#183c28">'+
   '<div class="cb-broadcast-head"><div class="cb-broadcast-brand"><div id="logo-placeholder"></div><div><small>GRAND SLAM</small><b>Wimbledon</b><em>Londres · Centre Court</em></div></div></div>'+
   '<div class="cb-tv-score"><div class="cb-tv-score-row user"><div class="cb-tv-player">Arthur Fils</div><b>6</b><b>3</b></div></div>'+
   '<div class="fm-court cb-court grass" data-cb-tournament-skin="wimbledon" data-cb-venue-tier="slam" style="--cb-theme-court-a:#69934f;--cb-theme-court-b:#416d36;--cb-theme-accent:#b2d89c;--cb-theme-board:#183c28">'+
   '<div class="fm-player-dot user" style="left:48%;top:78%">AF</div><div class="fm-player-dot opponent" style="left:51%;top:20%">JS</div><i class="fm-net"></i><i class="fm-ball" style="left:50%;top:54%"></i></div>'+
   '</div></div></div></main></div></body></html>';
}
(async()=>{
  const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
  try{
    for(const [name,w,h] of [['PC',1450,900],['iPhone',390,844]]){
      const page=await browser.newPage({viewport:{width:w,height:h}});
      const errors=[];
      page.on('pageerror',e=>errors.push(e.message));
      await page.route('https://court-boss-test.local/',route=>route.fulfill({status:200,contentType:'text/html',body:html()}));
      await page.route('https://court-boss-test.local/wimbledon-crest.svg',route=>route.fulfill({status:200,contentType:'image/svg+xml',body:asset}));
      await page.goto('https://court-boss-test.local/');
      await page.addStyleTag({content:css});
      await page.addScriptTag({content:functions});
      await page.evaluate(()=>{
        document.documentElement.classList.add('cb-match-layout-v2');
        window.local={liveMatch:{stats:{_meta:{tournament:{name:'Wimbledon',city:'Londres',category:'Grand Chelem',venue:'Centre Court'}}}}};
        const target=document.querySelector('#logo-placeholder');
        target.outerHTML=window.tournamentLogoHtml({name:'Wimbledon',category:'Grand Chelem'},'cb-broadcast-logo');
      });
      await page.addScriptTag({content:arena});
      await page.locator('.cb-wimbledon-court-logo').waitFor({state:'attached',timeout:7000});
      await page.waitForFunction(()=>{
        const a=document.querySelector('.cb-broadcast-logo .tm-tour-logo');
        const b=document.querySelector('.cb-wimbledon-court-logo');
        return a?.complete&&a.naturalWidth>0&&b?.complete&&b.naturalWidth>0;
      },null,{timeout:7000});
      const state=await page.evaluate(()=>{
        const a=document.querySelector('.cb-broadcast-logo .tm-tour-logo');
        const b=document.querySelector('.cb-wimbledon-court-logo');
        const box=a.getBoundingClientRect();
        return {
          src:a.getAttribute('src'),alt:a.getAttribute('alt'),
          brandNatural:a.naturalWidth,boardNatural:b.naturalWidth,
          brandWidth:box.width,brandHeight:box.height,
          left:box.left,right:box.right,viewport:window.innerWidth,
          label:document.querySelector('.cb-broadcast-brand b').textContent,
          pageErrors:document.querySelectorAll('.cb-broadcast-logo-fallback').length,
          boardText:document.querySelector('.cb-v4-led-north')?.textContent
        };
      });
      assert.equal(state.src,'wimbledon-crest.svg');
      assert.equal(state.alt,'Logo Wimbledon');
      assert.ok(state.brandNatural>=180 && state.boardNatural>=180,'badge did not render');
      assert.ok(state.brandWidth>=35 && state.brandHeight>=35,'logo too tiny in header');
      assert.ok(state.right<=state.viewport,'logo clipped on phone');
      assert.equal(state.label,'Wimbledon');
      assert.ok(state.boardText.includes('WIMBLEDON'),'stadium branding missing');
      assert.deepEqual(errors,[],'browser errors');
      await page.screenshot({path:'wimbledon-crest-'+name+'.png',fullPage:false});
      console.log('PASS:',name,JSON.stringify(state));
      await page.close();
    }
    // Safety fallback: if even the bundled asset fails, the logo is
    // replaced by a readable WIM tile rather than a blank white square.
    const page=await browser.newPage();
    await page.route('https://court-boss-test.local/',route=>route.fulfill({status:200,contentType:'text/html',body:html()}));
    await page.route('https://court-boss-test.local/wimbledon-crest.svg',route=>route.abort());
    await page.goto('https://court-boss-test.local/');
    await page.addScriptTag({content:functions});
    await page.evaluate(()=>{
      document.querySelector('#logo-placeholder').outerHTML=window.tournamentLogoHtml({name:'Wimbledon'},'cb-broadcast-logo');
    });
    await page.locator('.tm-tour-logo-fallback').waitFor({state:'visible',timeout:7000});
    assert.equal(await page.locator('.tm-tour-logo-fallback b').textContent(),'WIM');
    console.log('PASS: Broken asset fallback remains readable.');
    await page.close();
    console.log('WIMBLEDON BRANDING: PASS');
  }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});