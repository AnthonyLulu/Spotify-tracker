(() => {
  async function callLive(path){
    if(!local.liveMatch) return;
    const d=await get(path,{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({session_id:local.liveMatch.id,tactics:local.tactics||{}})
    });
    local.liveMatch=d.session;
    persist();
    render();
    return d;
  }

  window.playLivePoint=async()=>{
    try{await callLive('/api/live-match/game')}catch(e){alert(e.message)}
  };

  window.simulateLiveGame=async()=>{
    try{await callLive('/api/live-match/game')}catch(e){alert(e.message)}
  };

  window.simulateLiveSet=async()=>{
    try{await callLive('/api/live-match/advance')}catch(e){alert(e.message)}
  };
})();