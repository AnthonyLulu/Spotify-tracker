import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync(new URL('../supabase/migrations/20261010031000_preseason_doubles_health_date_v65.sql',import.meta.url),'utf8');

test('preseason health probes the first playable doubles year without touching the requested date',()=>{
  assert.match(sql,/pg_get_functiondef\('public\.career_system_health\(date\)'::regprocedure\)/);
  assert.match(sql,/original text := 'public\.doubles_entry_rules_audit_v20\(p_date\)'/);
  assert.match(sql,/greatest\(p_date, DATE ''2026-01-01''\)/);
  assert.match(sql,/IF occurrences<>2 THEN/);
  assert.match(sql,/EXECUTE definition;/);
  assert.doesNotMatch(sql,/\b(?:TRUNCATE|DROP TABLE|DELETE FROM|UPDATE public\.players|UPDATE public\.game_saves)\b/i);
  const auditedDate=date=>[date,'2026-01-01'].sort()[1];
  assert.equal(auditedDate('2025-12-01'),'2026-01-01');
  assert.equal(auditedDate('2026-01-01'),'2026-01-01');
  assert.equal(auditedDate('2027-04-15'),'2027-04-15');
});
