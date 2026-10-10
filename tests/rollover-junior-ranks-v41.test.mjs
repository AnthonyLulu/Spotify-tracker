import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql = fs.readFileSync(new URL('../supabase/migrations/20261010093831_rollover_junior_rank_refresh_after_newyear_v41.sql',import.meta.url),'utf8');

test('daily rollover recalculates junior singles then doubles after the year changes',()=>{
 const yearChange=sql.indexOf('ranking_result:=public.refresh_world_rankings(make_date(p_new_year,1,1));');
 const singles=sql.indexOf('junior_display_result:=public.refresh_junior_display_pool_v3(2000);');
 const doubles=sql.indexOf("junior_doubles_result:=public.refresh_junior_doubles_ranking(make_date(p_new_year,1,1));");
 assert.ok(yearChange!==-1 && singles>yearChange && doubles>singles,
  'singles/doubles must refresh after the year boundary and in that order');
 assert.match(sql,/newgen_result:=newgen_result\|\|jsonb_build_object/);
 assert.match(sql,/RAISE EXCEPTION 'Junior ranking refresh incomplete after daily rollover %'/);
});

test('v41 preserves existing daily rollover signature and does not revive Jan 5 jumps',()=>{
 assert.match(sql,/CREATE OR REPLACE FUNCTION public\.rollover_season_daily_v22\(p_new_year integer\)/);
 assert.match(sql,/SECURITY DEFINER/);
 assert.match(sql,/career_date=make_date\(p_new_year,1,1\)-1/);
 assert.doesNotMatch(sql,/career_date=make_date\(p_new_year,1,5\)/);
 assert.doesNotMatch(sql,/\bDROP\s+TABLE\b|\bTRUNCATE\s+TABLE\b/i);
});
