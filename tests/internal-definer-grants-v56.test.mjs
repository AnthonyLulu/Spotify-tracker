import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010014500_security_definer_internal_rpc_grants_v56.sql',import.meta.url),'utf8');
const edge=fs.readFileSync(new URL('../supabase/functions/court-boss/index.ts',import.meta.url),'utf8');
const targets=[
  'cb_awards_year_rollover_trigger','cb_live_match_stat_lines_trigger',
  'cb_stat_record_breakthrough_trigger','cb_world_match_stat_lines_trigger',
  'laver_cup_captain_context','laver_cup_history_stamp_captains',
  'laver_cup_roster_captain_guard'
];

test('security hardening is limited to seven existing definer functions',()=>{
  for(const name of targets)assert.ok(sql.includes("'"+name+"'"));
  assert.match(sql,/to_regprocedure\(signature\)/);
  assert.match(sql,/SECURITY DEFINER/);
  assert.match(sql,/SELECT prosecdef FROM pg_proc/);
  assert.match(sql,/REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated/);
  assert.match(sql,/GRANT EXECUTE ON FUNCTION %s TO service_role/);
  assert.match(sql,/has_function_privilege\('anon'/);
  assert.match(sql,/has_function_privilege\('authenticated'/);
  assert.match(sql,/has_function_privilege\('service_role'/);
  assert.doesNotMatch(sql,/\b(?:TRUNCATE|DELETE FROM|DROP TABLE|UPDATE public\.players|DROP FUNCTION)\b/i);
});
test('the Edge server, not the public browser, calls privileged Laver Cup helper',()=>{
  assert.ok(edge.includes('db.rpc("laver_cup_captain_context"'));
  assert.ok(edge.includes('const serviceRole=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!'));
  assert.ok(edge.includes('const db=createClient(supabaseUrl,serviceRole'));
});
