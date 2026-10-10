import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source=fs.readFileSync(new URL('../supabase/migrations/20261010094833_rollover_preserve_dec31_for_daily_tick_v42.sql',import.meta.url),'utf8');

test('daily season rollover does not consume January 1 before the daily tick',()=>{
 const year=source.indexOf("make_date(p_new_year,1,1)");
 const rank=source.indexOf("ranking_result:=public.refresh_world_rankings(make_date(p_new_year,1,1));");
 const junior=source.indexOf("junior_display_result:=public.refresh_junior_display_pool_v3(2000);");
 const doubles=source.indexOf("junior_doubles_result:=public.refresh_junior_doubles_ranking(make_date(p_new_year,1,1));");
 const finalReset=source.indexOf("SET career_date=make_date(p_new_year,1,1)-1,updated_at=now()");
 const returning=source.lastIndexOf("return jsonb_build_object(");
 assert.ok(year!==-1&&rank>year&&junior>rank&&doubles>junior&&finalReset>doubles&&returning>finalReset,
   'ranking, juniors, year boundary repair must occur in this order before return');
 assert.match(source,/SET season_year=p_new_year,week=1,career_date=make_date\(p_new_year,1,1\)-1/);
 assert.match(source,/WHERE id='demo';/);
});

test('keep the real daily rollover and safety guard, not the old Jan 5 behavior',()=>{
 assert.match(source,/CREATE OR REPLACE FUNCTION public\.rollover_season_daily_v22\(p_new_year integer\)/);
 assert.match(source,/RAISE EXCEPTION 'Junior ranking refresh incomplete after daily rollover %'/);
 assert.match(source,/SECURITY DEFINER/);
 assert.doesNotMatch(source,/career_date=make_date\(p_new_year,1,5\)/);
 assert.doesNotMatch(source,/\b(?:DROP|TRUNCATE)\s+TABLE\b/i);
});
