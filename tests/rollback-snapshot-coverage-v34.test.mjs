import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync('supabase/functions/court-boss/index.ts','utf8');
const captureStart=edge.indexOf('async function captureManagedSaveSnapshot()');
const boundary=edge.indexOf('async function ensureCareerBaselineTemplate()',captureStart);
const saveCode=edge.slice(captureStart,boundary);
const restoreStart=saveCode.indexOf('async function restoreManagedSaveSnapshot');
const capture=saveCode.slice(0,restoreStart);
const restore=saveCode.slice(restoreStart);
const unique=xs=>[...new Set(xs)].sort();

test('every table mutated by restore is covered by the safety snapshot',()=>{
  assert.ok(captureStart>=0&&boundary>captureStart&&restoreStart>=0,'save/restore functions must be discoverable');
  const captured=unique([...capture.matchAll(/db\.from\("([^"]+)"\)/g)].map(m=>m[1]));
  const mutated=unique([
    ...[...restore.matchAll(/db\.from\("([^"]+)"\)\.(?:delete|upsert|insert|update)/g)].map(m=>m[1]),
    ...[...restore.matchAll(/(?:upsertOne|upsertMany|deleteAll)\("([^"]+)"/g)].map(m=>m[1])
  ]);
  const missing=mutated.filter(table=>!captured.includes(table));
  assert.deepEqual(missing,[],`rollback snapshot misses mutated tables: ${missing.join(', ')}`);
  assert.ok(mutated.length>=70,'coverage parser unexpectedly found too few restore tables');
});
