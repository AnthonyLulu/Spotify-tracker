import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010033000_staff_world_bulk_fit_page_enrichment_v61.sql',import.meta.url),'utf8');
const p=sql.indexOf('CREATE OR REPLACE FUNCTION public.staff_world_search(');
const staff=sql.slice(p);
const pageStart=staff.indexOf('page as (');
const pageEnd=staff.indexOf('page_enriched as (');
const prePage=staff.slice(0,pageEnd);
const postPage=staff.slice(pageEnd);

test('v61 computes compatibility for the full staff set via one relational join',()=>{
  assert.ok(p>0,'original staff_world_search must be replaced, not shadowed');
  assert.match(sql,/CREATE OR REPLACE FUNCTION public\.staff_fit_scores_bulk_v61\(p_player_id bigint\)/);
  assert.match(sql,/join public\.staff_profiles sp on true/);
  assert.match(sql,/public\.staff_role_group\(sp\.primary_role\)/);
  assert.match(sql,/where p\.id=p_player_id/);
  assert.match(staff,/left join public\.staff_fit_scores_bulk_v61\(p_managed_player_id\) fit on fit\.staff_id=sp\.id/);
  assert.match(staff,/fit\.managed_fit as managed_fit/);
  assert.ok(!prePage.includes('public.staff_fit_score('),'do not call scalar subqueries for 8,845 staff');
});

test('ranking, filters and pagination retain the original market contract',()=>{
  assert.ok(pageStart>0&&pageEnd>pageStart);
  const paged=staff.slice(pageStart,pageEnd);
  assert.match(paged,/managed_fit desc nulls last,\s*reputation desc/);
  assert.match(paged,/offset \(select off from params\)/);
  assert.match(paged,/limit \(select lim from params\)/);
  for(const filter of ['p.role_filter','p.country_filter','p.former_filter','p.status_filter']){
    assert.ok(prePage.includes(filter));
  }
  for(const output of ["'total'","'offset'","'limit'","'rows'","'roles'","'countries'","'agencies'","'academies'","'training_centers'"]){
    assert.ok(staff.includes(output),'missing response key '+output);
  }
});

test('optional staff details are queried only for selected page rows',()=>{
  for(const feature of ['current_clients','agency_name','academy_name','top_license']){
    assert.ok(!prePage.includes('as '+feature),'premature expensive field: '+feature);
    assert.ok(postPage.includes('as '+feature),'missing field: '+feature);
  }
  assert.match(staff,/from page_enriched page/);
  assert.match(postPage,/where psa\.staff_profile_id=pg\.id/);
  assert.match(postPage,/where sam\.staff_profile_id=pg\.id/);
});

test('batch helper is not newly executable by untrusted API roles',()=>{
  assert.match(sql,/REVOKE EXECUTE ON FUNCTION public\.staff_fit_scores_bulk_v61\(bigint\) FROM PUBLIC,anon,authenticated/);
  assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.staff_fit_scores_bulk_v61\(bigint\) TO service_role/);
  assert.doesNotMatch(sql,/\b(?:TRUNCATE|DROP TABLE|DELETE FROM public\.game_saves)\b/i);
});
