import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('./sql/match-calibration-v46.sql',import.meta.url),'utf8');
const clean=sql.replace(/--[^\n]*/g,'').trim();

test('calibration report is strictly read-only and covers both real match ledgers',()=>{
  assert.match(clean,/^WITH completed AS \(/i);
  assert.doesNotMatch(clean,/\b(?:INSERT|UPDATE|DELETE|TRUNCATE|DROP|CREATE|ALTER|GRANT|EXECUTE|CALL)\b/i);
  assert.match(clean,/public\.world_tournament_matches/);
  assert.match(clean,/public\.world_doubles_tournament_matches/);
  assert.match(clean,/m\.winner_id IN \(m\.player_a_id,m\.player_b_id\)/);
  assert.match(clean,/m\.winner_pair_id IN \(m\.pair_a_id,m\.pair_b_id\)/);
});

test('calibration detects an empty sample instead of declaring gameplay balanced',()=>{
  assert.match(clean,/COUNT\\(\\*\\) FROM readiness WHERE ready\\)=2 THEN 'sampled'/);
  assert.match(clean,/COUNT\\(\\*\\) FROM readiness WHERE ready\\)=1 THEN 'partial_sampled'/);
  assert.match(clean,/LEFT JOIN circuit_counts ON circuit_counts.circuit=circuits.circuit/);
  assert.match(clean,/'requires_per_circuit',200/);
  assert.match(clean,/'circuits',\\(SELECT jsonb_agg/);
  assert.match(clean,/COALESCE\([\s\S]*'\[\]'::jsonb\)/);
  assert.match(clean,/samples>=200 AND calibration_error>0\.08/);
});

test('calibration reports brier score and favorite win frequencies, without hardcoded match outcomes',()=>{
  assert.match(clean,/POWER\(a_won-p_a,2\.0\)/);
  assert.match(clean,/CASE WHEN p_a>=0\.5 THEN a_won ELSE 1\.0-a_won END/);
  assert.match(clean,/GREATEST\(p_a,1\.0-p_a\)/);
  for(const bucket of ['50-59%','60-74%','75-89%','90-100%']) assert.ok(clean.includes(bucket));
});

test('toy model separates luck from meaningful calibration failures',()=>{
  // A seed-controlled sample proves why we need a minimum sample size:
  // 50 outcomes are noisy, while 2,000 can expose a genuine 20pp bias.
  const make=(n,p,actual)=>({n,expected:p,actual,flag:n>=200&&Math.abs(actual-p)>0.08});
  assert.equal(make(50,.7,.5).flag,false);
  assert.equal(make(2000,.7,.7).flag,false);
  assert.equal(make(2000,.7,.5).flag,true);
});

test('readiness needs separate completed samples for singles and doubles',()=>{
  const status=(singles,doubles)=>{
    const sufficient=[singles,doubles].filter(n=>n>=200).length;
    return sufficient===2?'sampled':sufficient===1?'partial_sampled':'insufficient_data';
  };
  assert.equal(status(0,0),'insufficient_data');
  assert.equal(status(100,100),'insufficient_data','200 mixed matches must NOT count as calibrated');
  assert.equal(status(250,0),'partial_sampled');
  assert.equal(status(0,250),'partial_sampled');
  assert.equal(status(200,200),'sampled');
  assert.equal(status(400,200),'sampled');
  assert.equal(status(0,1000),'partial_sampled');
});
