import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const workflow=fs.readFileSync(new URL('../.github/workflows/court-boss-pages.yml',import.meta.url),'utf8');
const smoke=workflow.split("cat > mobile-smoke.cjs <<'EOF'")[1]?.split('\n          EOF')[0];
assert.ok(smoke);
test('mobile smoke defines and invokes the UI-only gate closer before clicks',()=>{
  const defined=smoke.indexOf('const clearAccessGate=async()=>page.evaluate(');
  const initial=smoke.indexOf('await clearAccessGate();');
  const firstNavigation=smoke.indexOf("await page.evaluate(()=>nav('training'))");
  const firstClick=smoke.indexOf("getByRole('button',{name:'Classements'}).click()");
  assert.ok(defined>=0&&initial>defined&&firstNavigation>initial&&firstClick>initial);
  assert.equal((smoke.match(/const clearAccessGate=/g)||[]).length,1);
  assert.ok(smoke.includes("document.querySelectorAll('.cb-access-gate')"));
  assert.ok(smoke.includes("await clearAccessGate();\n            await page.getByRole('button',{name:'Records & Awards'}).click()"));
});
test('access gate remains part of actual application code',()=>{
  const app=fs.readFileSync(new URL('../court-boss/app.js',import.meta.url),'utf8');
  assert.ok(app.includes('cb-access-gate'));
  assert.doesNotMatch(app,/clearAccessGate/);
});
