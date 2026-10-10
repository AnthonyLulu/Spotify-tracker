import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const modules=fs.readFileSync(new URL('../court-boss/modules.js',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../supabase/migrations/20261010102224_atp_expired_vs_net_points_v43.sql',import.meta.url),'utf8');
const routeStart=edge.indexOf('if(path.endsWith("/api/ranking-ledger")&&req.method==="GET")');
const routeEnd=edge.indexOf('if(path.endsWith("/api/play-tournament")&&req.method==="POST")',routeStart);
assert.ok(routeStart>0 && routeEnd>routeStart);
const route=edge.slice(routeStart,routeEnd);

test('net forecast never bypasses existing managed squad authorization',()=>{
 assert.match(route,/requestedPlayerId/);
 assert.match(route,/if\(playerId!==primaryId\)/);
 assert.match(route,/academy_roster/);
 assert.match(route,/Ce joueur ne fait pas partie du groupe géré/);
 assert.ok(route.indexOf('if(playerId!==primaryId)')<route.indexOf('atp_points_movement_v1'));
});
test('net forecast comes from V43 ATP SQL, cannot be forged by subtracting gross',()=>{
 assert.match(route,/db\.rpc\("atp_points_movement_v1"/);
 assert.match(route,/p_player_id:playerId,p_from_date:today,p_to_date:throughDate/);
 assert.match(route,/net_forecast:netForecast,net_forecast_status:netForecastStatus/);
 assert.match(migration,/v_new-v_old/);
 assert.match(migration,/public\.atp_player_ranking_summary\(p_player_id,p_from_date\)/);
 assert.doesNotMatch(route,/netForecast\s*=\s*-Number\(nextWeek\.points_to_defend/);
});
test('the route is safe before the production SQL migration and limits forecast queries',()=>{
 assert.match(route,/if\(!movement\.error&&movement\.data\?\.ok===true\)/);
 assert.match(route,/netForecastStatus="unavailable"/);
 assert.match(route,/netForecastStatus="outside_window"/);
 assert.match(route,/offsetDays>=1&&offsetDays<=62/);
 assert.doesNotMatch(route,/return h\(\{error:movement\.error/);
});
test('season UI distinguishes gross negative expiry from actual forecast and never claims a missing value',()=>{
 assert.match(modules,/const netForecast=ledger\.net_forecast\?\.ok===true/);
 assert.match(modules,/Variation nette projetée/);
 assert.match(modules,/Expiration brute/);
 assert.match(modules,/Non calculée/);
 assert.match(modules,/netForecast\?'Jusqu’au '/);
 assert.match(modules,/Projection ATP réelle · résultats connus/);
 assert.match(modules,/nextDefense&&w\.week_start===nextDefense\.week_start&&netForecast/);
});
test('mobile assets bust the stale weekly ledger module cache',()=>{
 for(const path of ['index.html','play.html']){
   const html=fs.readFileSync(new URL('../court-boss/'+path,import.meta.url),'utf8');
   assert.match(html,/modules\.js\?v=20261010-atp-net-v44/);
 }
});
