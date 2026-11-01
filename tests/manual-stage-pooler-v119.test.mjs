import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const helper = fileURLToPath(new URL('../scripts/cb-stage-session-pooler-url.mjs', import.meta.url));
const workflow = readFileSync(new URL('../.github/workflows/court-boss-stage-encrypted-backup.yml', import.meta.url), 'utf8');
const backup = readFileSync(new URL('../scripts/cb-stage-independent-backup-verify.sh', import.meta.url), 'utf8');
function run(host, password = 'test@#:/?%,secret') {
  return spawnSync('node', [helper], {
    encoding: 'utf8',
    env: {...process.env, CB_E2E_POOLER_HOST: host, CB_E2E_DB_PASSWORD: password}
  });
}

test('builds a stage-only IPv4 session pooler URL with encoded password', () => {
  const password = 'test@#:/?%,secret';
  const r = run('aws-0-eu-west-3.pooler.supabase.com', password);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stderr, '');
  const u = new URL(r.stdout);
  assert.equal(u.protocol, 'postgresql:');
  assert.equal(u.hostname, 'aws-0-eu-west-3.pooler.supabase.com');
  assert.equal(u.port, '5432');
  assert.equal(u.username, 'postgres.sozrygjxjotozrsenred');
  assert.equal(decodeURIComponent(u.password), password);
  assert.equal(u.pathname, '/postgres');
  assert.equal(u.searchParams.get('sslmode'), 'require');
});
for (const host of [
  '', 'db.sozrygjxjotozrsenred.supabase.co',
  'aws-0-eu-west-3.pooler.supabase.com.evil.example',
  'aws-0-eu-west-3.pooler.supabase.com:6543',
  'https://aws-0-eu-west-3.pooler.supabase.com'
]) {
  test('rejects unsafe pooler host '+JSON.stringify(host), () => {
    const r = run(host);
    assert.notEqual(r.status, 0);
    assert.equal(r.stdout, '');
  });
}
test('missing password fails closed without returning a URL', () => {
  const r = run('aws-0-eu-west-3.pooler.supabase.com', '');
  assert.notEqual(r.status, 0);
  assert.equal(r.stdout, '');
});

test('workflow cannot silently fall back to unreachable IPv6 direct host', () => {
  assert.match(workflow, /stage_pooler_host:/);
  assert.match(workflow, /inputs\.stage_pooler_host/);
  assert.match(workflow, /secrets\.CB_E2E_DB_PASSWORD/);
  assert.match(workflow, /CB_E2E_DB_URL must be the STAGE Session pooler URL/);
  assert.match(workflow, /github\.ref == 'refs\/heads\/court-boss-live'/);
  assert.doesNotMatch(workflow, /^\s*(push|pull_request|schedule):/m);
  assert.match(backup, /cb-stage-session-pooler-url\.mjs/);
  assert.match(backup, /GITHUB_ACTIONS === 'true'/);
  assert.doesNotMatch(backup, /postgres@db\.sozrygjxjotozrsenred\.supabase\.co/);
});
