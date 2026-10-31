import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
function section(start,end){
  const from=source.indexOf(start),to=source.indexOf(end,from);
  assert.ok(from>=0&&to>from,`Missing client section: ${start}`);
  return source.slice(from,to);
}
const getSource=section('const get=async(', '\nlet boot=');
const localSource=section('function baseLocalState()', 'async function loadCareerHub(');
const slotsSource=section('function snapshotLocalForSave()', '\nfunction surfaceClass(');
const historySource=section('function managedMatchHistory()', '\nfunction liveMatchOwnerId(');
const detailsSource=section('window.openMatch=idx=>{', '\nwindow.pairScore=');
const rollbackKey='cbLiveRollbackCheckpointV1';
const reply=(data,status=200)=>({status,ok:status>=200&&status<300,json:async()=>data});
const unreadable=(status=200)=>({status,ok:status>=200&&status<300,json:async()=>{throw new SyntaxError('Truncated JSON')}});
const receipt=(slotNo=1)=>({ok:true,slot:{slot_no:slotNo,slot_name:'Test',career_date:'2026-01-15',week:7}});

function client({fetchMutation,marker=null,slots=[{slot_no:1,slot_name:'Test',career_date:'2026-01-15'}]}={}){
  const values=new Map(marker?[[rollbackKey,JSON.stringify(marker)]]:[]);
  const storage={getItem:key=>values.get(key)??null,setItem:(key,value)=>values.set(key,String(value)),removeItem:key=>values.delete(key)};
  const requests=[],alerts=[],events=[],delays=[];
  const fetch=async(url,opts)=>{
    const path=new URL(url).pathname;
    requests.push({path,method:opts.method||'GET'});
    if(path==='/api/save-slots')return reply({ok:true,slots});
    if(path==='/api/bootstrap')return reply({career:{career_date:'2026-01-15',week:7}});
    return fetchMutation(path,opts);
  };
  return new Function('fetch','localStorage','slots','alerts','events','delays',`
    const API='https://example.test',saveKey='test-browser';let accessKey='';
    const window={};
    const alert=message=>alerts.push(message),confirm=()=>true,prompt=(_message,value)=>value;
    const console={warn(){}};
    const setTimeout=(callback,ms)=>{delays.push(ms);callback()};
    const requestCourtBossAccess=async()=>{};
    let boot=null,route='home',simulating=false;
    let saveSlots=slots,saveSlotsLoading=false,saveSlotBusy=false,saveSlotQueue=Promise.resolve(),saveSlotQueueDepth=0;
    const liveMatchSessionsByPlayer=new Map(),liveMatchOpponentsByPlayer=new Map();
    const clearLiveMatchView=()=>{events.push('clear-live');delete local.liveMatch;local.liveSessionId=null};
    const invalidateCareerCaches=()=>events.push('invalidate');
    const mergeBootstrapCore=data=>data,activeManagedId=()=>101,primaryManagedPlayerId=()=>101;
    const restoreLiveMatchForPlayer=async()=>{};
    const render=()=>events.push('render'),df=value=>value;
    const loadRankings=async()=>{},loadTournaments=async()=>{},loadManagement=async()=>{};
    const loadRankingLedger=async()=>{},loadSeasonSummary=async()=>{},loadScheduleAdvice=async()=>{};
    const loadCountries=async()=>{},loadCareerHub=async()=>{};
    ${getSource}
    ${localSource}
    ${slotsSource}
    return {
      get,saveCareerSlot,loadCareerSlot,deleteCareerSlot,rollbackUnsavedLiveBatchOnStartup,
      local:()=>local,setLocal:state=>{local={...local,...state}},
      busy:()=>saveSlotBusy,liveMatchSessionsByPlayer,
      storage:localStorage,alerts,events,delays
    };
  `)(fetch,storage,slots,alerts,events,delays);
}

test('unreadable successful save never clears the live rollback checkpoint or reports success',async()=>{
  const marker={slot_no:0,career_date:'2026-01-14'};
  let writes=0;
  const c=client({marker,fetchMutation:async()=>{writes++;return unreadable()}});
  const result=await c.saveCareerSlot(1,'manual',true);
  assert.equal(result.ok,false);
  assert.match(result.error,/Impossible de confirmer/);
  assert.equal(writes,1,'a committed mutation must not be automatically retried');
  assert.equal(c.local().lastSaveState.status,'error');
  assert.deepEqual(JSON.parse(c.storage.getItem(rollbackKey)),marker);
  assert.equal(c.busy(),false);
});

test('valid JSON without a matching successful save receipt leaves the checkpoint armed',async()=>{
  for(const data of [{},{ok:false},receipt(9),{ok:true,slot:{slot_no:null}}]){
    const c=client({marker:{slot_no:0},fetchMutation:async()=>reply(data)});
    const result=await c.saveCareerSlot(1,'manual',true);
    assert.equal(result.ok,false);
    assert.equal(c.local().lastSaveState.status,'error');
    assert.deepEqual(JSON.parse(c.storage.getItem(rollbackKey)),{slot_no:0});
  }
});

test('successful save requires the requested slot receipt before releasing the checkpoint',async()=>{
  const c=client({marker:{slot_no:0},fetchMutation:async()=>reply(receipt(1))});
  assert.equal((await c.saveCareerSlot(1,'manual',true)).ok,true);
  assert.equal(c.local().lastSaveState.slot_no,1);
  assert.equal(c.local().lastSaveState.status,'ok');
  assert.equal(c.storage.getItem(rollbackKey),null);
});

test('unreadable load leaves current local state, live sessions and rollback marker intact',async()=>{
  const c=client({marker:{slot_no:0},fetchMutation:async()=>unreadable()});
  c.setLocal({date:'2026-02-01',liveMatch:{id:77},liveSessionId:77});
  c.liveMatchSessionsByPlayer.set(101,77);
  const before=structuredClone(c.local());
  const result=await c.loadCareerSlot(1);
  assert.equal(result.ok,false);
  assert.deepEqual(c.local(),before);
  assert.equal(c.liveMatchSessionsByPlayer.get(101),77);
  assert.ok(c.storage.getItem(rollbackKey));
  assert.deepEqual(c.events,[]);
});

test('empty, mismatched or incomplete load receipts cannot reset local career to the 2025 default',async()=>{
  const good={...receipt(1),local_payload:{date:'2026-01-15'},live_match_sessions:[]};
  const invalid=[{},receipt(1),{...good,ok:false},{...good,slot:{slot_no:9}},
    {...good,local_payload:null},{...good,local_payload:[]},{...good,live_match_sessions:null}];
  for(const data of invalid){
    const c=client({marker:{slot_no:0},fetchMutation:async()=>reply(data)});
    c.setLocal({date:'2026-02-01',shortlist:[55]});
    const before=structuredClone(c.local());
    assert.equal((await c.loadCareerSlot(1)).ok,false);
    assert.deepEqual(c.local(),before);
    assert.deepEqual(c.events,[]);
    assert.ok(c.storage.getItem(rollbackKey));
  }
});

test('startup rollback also rejects incomplete receipts without losing the retry marker',async()=>{
  const c=client({marker:{slot_no:0},fetchMutation:async()=>reply({ok:true})});
  c.setLocal({date:'2026-02-01'});
  await assert.rejects(()=>c.rollbackUnsavedLiveBatchOnStartup(),/Confirmation de chargement invalide/);
  assert.equal(c.local().date,'2026-02-01');
  assert.ok(c.storage.getItem(rollbackKey));
  assert.deepEqual(c.events,[]);
});

test('a complete load receipt restores career and live match ownership',async()=>{
  const data={...receipt(1),local_payload:{date:'2026-01-15',shortlist:[42]},
    live_match_sessions:[{managed_player_id:101,id:88,status:'active'}]};
  const c=client({fetchMutation:async()=>reply(data)});
  const result=await c.loadCareerSlot(1);
  assert.equal(result.ok,true);
  assert.equal(c.local().date,'2026-01-15');
  assert.deepEqual(c.local().shortlist,[42]);
  assert.equal(c.liveMatchSessionsByPlayer.get(101),88);
  assert.equal(JSON.parse(c.storage.getItem(rollbackKey)).slot_no,1);
});

test('successful HTTP responses with non-object JSON are rejected before callers use them',async()=>{
  for(const data of [null,[],true,42,'ok']){
    const c=client({fetchMutation:async()=>reply(data)});
    await assert.rejects(()=>c.get('/api/save',{method:'POST'}),error=>
      error.code==='INVALID_API_RESPONSE'&&error.status===200);
  }
});

test('an unreadable HTTP 502 remains a bounded read retry, never a mutation retry',async()=>{
  let reads=0;
  const c=client({fetchMutation:async()=>++reads===1?unreadable(502):reply({rows:[1]})});
  assert.deepEqual(await c.get('/api/tournaments'),{rows:[1]});
  assert.equal(reads,2);
  assert.deepEqual(c.delays,[450]);
  let writes=0;
  const w=client({fetchMutation:async()=>{writes++;return unreadable(502)}});
  await assert.rejects(()=>w.get('/api/save',{method:'POST'}),error=>error.status===502);
  assert.equal(writes,1);
  assert.deepEqual(w.delays,[]);
});

test('non-object HTTP errors retain their status and do not bypass authentication',async()=>{
  const c=client({fetchMutation:async()=>reply(null,401)});
  await assert.rejects(()=>c.get('/api/save',{method:'POST',authPrompt:false}),error=>error.status===401);
});

test('deleting a slot holds the same lock as save/load and suppresses duplicate clicks',async()=>{
  let release,writes=0;
  const pending=new Promise(resolve=>{release=resolve});
  const c=client({fetchMutation:async()=>{writes++;return pending}});
  const deletion=c.deleteCareerSlot(1);
  assert.equal(c.busy(),true);
  await c.deleteCareerSlot(1);
  await c.loadCareerSlot(1);
  assert.equal((await c.saveCareerSlot(1,'manual',true)).reason,'save_busy');
  release(reply({ok:true,slot_no:1}));
  assert.equal((await deletion).ok,true);
  assert.equal(writes,1);
  assert.equal(c.busy(),false);
});

test('the save used for live rollback cannot be deleted',async()=>{
  let writes=0;
  const c=client({marker:{slot_no:1,saved_live:true},fetchMutation:async()=>{writes++;return reply({ok:true,slot_no:1})}});
  await c.deleteCareerSlot(1);
  assert.equal(writes,0);
  assert.equal(c.busy(),false);
  assert.match(c.alerts[0],/point de reprise/);
  assert.ok(c.storage.getItem(rollbackKey));
});

test('a failed deletion releases the queue and cannot poison a later save',async()=>{
  let first=true;
  const c=client({fetchMutation:async()=>{
    if(first){first=false;throw new Error('Network lost')}
    return reply(receipt(1));
  }});
  assert.equal((await c.deleteCareerSlot(1)).ok,false);
  assert.equal(c.busy(),false);
  assert.equal((await c.saveCareerSlot(1,'manual',true)).ok,true);
});

test('an incomplete deletion receipt does not report success or refresh slots',async()=>{
  const c=client({fetchMutation:async()=>reply({ok:true,slot_no:9})});
  assert.equal((await c.deleteCareerSlot(1)).ok,false);
  assert.match(c.alerts[0],/Suppression non confirmée/);
  assert.deepEqual(c.events,[]);
});

function matchClient(){
  return new Function(`
    const window={},overlay={innerHTML:''};
    let activeId=202;
    const local={practiceMatches:[
      {player_a:'Primary',player_b:'Practice A',winner:'Primary',managed_player_id:101},
      {player_a:'Secondary',player_b:'Practice B',winner:'Secondary',managed_player_id:202},
      {player_a:'Primary',player_b:'Legacy practice',winner:'Primary'}
    ]};
    let boot={matches:[
      {player_a:'Primary',player_b:'Server A',winner:'Primary',managed_player_id:101},
      {player_a:'Secondary',player_b:'Server B',winner:'Secondary',managed_player_id:202},
      {player_a:'Primary',player_b:'Legacy server',winner:'Primary'},
      {player_a:'Secondary',player_b:'Primary',winner:'Primary',managed_player_id:202}
    ]};
    const activeManagedId=()=>activeId,primaryManagedPlayerId=()=>101;
    const activePlayerCareerView=()=>({player_name:activeId===101?'Primary':'Secondary'});
    const career=()=>({player_name:'Primary'}),liveMatchPanel=()=>'';
    const esc=value=>String(value??''),df=value=>value??'',surfaceClass=()=>'';
    const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
    ${historySource}
    ${detailsSource}
    return {history:managedMatchHistory,page:matchPage,open:window.openMatch,overlay,
      select:id=>{activeId=id},clearBoot:()=>{boot=null}};
  `)();
}

test('each secondary-player history row opens the same match shown on its card',()=>{
  const c=matchClient();
  const history=c.history(),page=c.page();
  assert.deepEqual(history.map(x=>x.player_b),['Practice B','Server B','Primary']);
  assert.ok(!page.includes('Practice A')&&!page.includes('Legacy practice'));
  for(const [index,match] of history.entries()){
    assert.ok(page.includes(`onclick="openMatch(${index})"`));
    c.open(index);
    assert.ok(c.overlay.innerHTML.includes(`<h1>${match.player_a} vs ${match.player_b}</h1>`));
  }
});

test('unowned legacy practice and server matches belong only to the primary player',()=>{
  const c=matchClient();
  c.select(101);
  assert.deepEqual(c.history().map(x=>x.player_b),['Practice A','Legacy practice','Server A','Legacy server']);
  c.open(1);
  assert.ok(c.overlay.innerHTML.includes('Primary vs Legacy practice'));
  c.clearBoot();
  assert.deepEqual(c.history().map(x=>x.player_b),['Practice A','Legacy practice']);
});

test('losing against the primary managed player is still a defeat for the selected player',()=>{
  const c=matchClient();
  c.open(2);
  assert.ok(c.overlay.innerHTML.includes('>Défaite</span>'));
  assert.ok(!c.overlay.innerHTML.includes('>Victoire</span>'));
});
