import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010102224_atp_expired_vs_net_points_v43.sql',import.meta.url),'utf8');
const modules=fs.readFileSync(new URL('../court-boss/modules.js',import.meta.url),'utf8');
const canonical=fs.readFileSync(new URL('../supabase/migrations/20261002225830_atp_rolling_ledger_infinite_calendar_v1.sql',import.meta.url),'utf8');
const snapshot=JSON.parse(fs.readFileSync(new URL('../court-boss/data/atp-singles-2025-12-01.json',import.meta.url),'utf8'));

test('2025-12-01 official reference and ATP 500 runner-up points remain frozen',()=>{
 assert.equal(snapshot.snapshot,'2025-12-01');
 assert.equal(snapshot.rows[0].name,'Carlos Alcaraz');
 assert.equal(snapshot.rows[0].rank,1);
 assert.equal(snapshot.rows[1].name,'Jannik Sinner');
 assert.equal(snapshot.rows[1].rank,2);
 assert.match(canonical,/when 'F' then 330/);
 assert.match(canonical,/public\.atp_points_to_defend/);
 assert.match(canonical,/public\.atp_player_ranking_summary/);
});

test('net delta uses the existing ATP best-results calculation, not raw gross expiry',()=>{
 assert.match(sql,/public\.atp_points_movement_v1\(p_player_id bigint, p_from_date date, p_to_date date\)/);
 assert.match(sql,/public\.atp_player_ranking_summary\(p_player_id,p_from_date\)/);
 assert.match(sql,/public\.atp_player_ranking_summary\(p_player_id,p_to_date\)/);
 assert.match(sql,/public\.atp_player_breakdown\(p_player_id,p_from_date\)/);
 assert.match(sql,/counting=true AND points>0/);
 assert.match(sql,/drop_date>=p_from_date AND drop_date<p_to_date/);
 assert.match(sql,/'expired_counted_points',v_expired/);
 assert.match(sql,/'net_change_points',v_new-v_old/);
 assert.match(sql,/'other_effects_points',v_new-v_old\+v_expired/);
 assert.match(sql,/p_to_date-p_from_date>62/);
});

test('net points calculator is read-only, invoker, and service-role only',()=>{
 assert.match(sql,/STABLE/);
 assert.doesNotMatch(sql,/SECURITY DEFINER/i);
 assert.match(sql,/SET search_path TO ''/);
 assert.match(sql,/REVOKE ALL ON FUNCTION public\.atp_points_movement_v1\(bigint,date,date\) FROM PUBLIC,anon,authenticated/);
 assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.atp_points_movement_v1\(bigint,date,date\) TO service_role/);
 assert.doesNotMatch(sql,/^\s*(?:UPDATE\s+|DELETE\s+FROM\s+|TRUNCATE\s+TABLE\s+|INSERT\s+INTO\s+|DROP\s+TABLE\s+)/im);
});

test('season screen shows negative gross expiry and explains that the net change may differ',()=>{
 assert.match(modules,/Prochains points à défendre/);
 assert.match(modules,/Expiration brute/);
 assert.match(modules,/−330 points à défendre peut devenir −230 points nets/);
 assert.match(modules,/x\.estimated\?/);
 assert.match(modules,/−\$\{fmt\(w\.points_to_defend\|\|0\)\} pts/);
});
