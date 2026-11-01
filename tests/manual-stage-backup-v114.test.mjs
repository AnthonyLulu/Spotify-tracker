import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const workflow=readFileSync(new URL('../.github/workflows/court-boss-stage-encrypted-backup.yml',import.meta.url),'utf8');
const backupPath=new URL('../scripts/cb-stage-independent-backup-verify.sh',import.meta.url);
const backup=readFileSync(backupPath,'utf8');

test('manual backup never automatically runs on push or PR and cannot run off the game branch',()=>{
 assert.match(workflow,/^on:\\s*\\n\\s*workflow_dispatch:\\s*\\n\\s*inputs:/m);
 assert.doesNotMatch(workflow,/^\s*(push|pull_request|schedule):/m);
 assert.match(workflow,/github\.ref == 'refs\/heads\/court-boss-live'/);
 assert.match(workflow,/permissions:\s*\n\s*contents: read/);
 assert.match(workflow,/persist-credentials: false/);
 assert.match(workflow,/cancel-in-progress: false/);
});

test('workflow requires owner GitHub secrets, never exposes a private age key',()=>{
 assert.match(workflow,/secrets\.CB_E2E_DB_URL/);
 assert.match(workflow,/secrets\.CB_BACKUP_AGE_RECIPIENT/);
 assert.doesNotMatch(workflow,/secrets\.(?:CB_BACKUP_AGE_IDENTITY|CB_E2E_RESTORE_TEST_DB_URL)/);
 assert.match(workflow,/sozrygjxjotozrsenred/);
 assert.doesNotMatch(workflow,/qrsvliliezbiedmaewml/);
 assert.doesNotMatch(workflow,/\b(?:supabase db reset|DROP DATABASE|DELETE FROM public\.game_saves)\b/);
 assert.match(workflow,/cb_e2e_restore_ci TEMPLATE template0/);
 assert.doesNotMatch(workflow,/cb_e2e_restore_ci TEMPLATE postgres/);
 // Using the busy postgres database as a template fails as soon as
 // Supabase's own services connect to it.
 assert.doesNotMatch(workflow,/pg_terminate_backend|DROP DATABASE|supabase db reset/);
 assert.match(workflow,/supabase db start/);
 assert.match(workflow,/CB_E2E_BACKUP_DIR/);
 assert.match(workflow,/actions\/upload-artifact@v4/);
 assert.match(workflow,/retention-days: 7/);
 assert.match(workflow,/compression-level: 0/);
 assert.match(workflow,/if-no-files-found: error/);
});

test('operator shell script optionally accepts a public-only age recipient without claiming decryption verification',()=>{
 const checked=spawnSync('bash',['-n',fileURLToPath(backupPath)],{encoding:'utf8'});
 assert.equal(checked.status,0,checked.stderr);
 assert.match(backup,/CB_BACKUP_AGE_IDENTITY_FILE:-/);
 assert.match(backup,/OFFLINE PRIVATE-KEY CHECK STILL REQUIRED/);
 assert.match(backup,/ENCRYPTED STAGE ARCHIVE WITH LOCAL RESTORE HASH PARITY/);
 assert.match(backup,/stage_or_restored_fingerprints "\$CB_E2E_RESTORE_TEST_DB_URL"/);
 assert.match(backup,/Stage changed during multi-session export/);
 assert.match(backup,/26/);
 assert.match(backup,/sha256sum "\$out"/);
});

test('backup prepares required pg_trgm GIN opclass in local scratch before restore',()=>{
 assert.match(backup,/CREATE SCHEMA IF NOT EXISTS extensions/);
 assert.match(backup,/CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions/);
 assert.match(backup,/CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions/);
 assert.match(backup,/CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions/);
 assert.match(backup,/CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions/);
 assert.match(backup,/c\.opcname='gin_trgm_ops'/);
 assert.match(backup,/Scratch lacks required extension schemas or GIN trigram opclass/);
 assert.ok(backup.indexOf('RESTORE_EXTENSIONS_SQL')<backup.indexOf('supabase db dump --db-url'));
 assert.match(backup,/CB_E2E_DB_PASSWORD:-/);
 assert.match(workflow,/secrets\.CB_E2E_DB_PASSWORD/);
 assert.match(backup,/sozrygjxjotozrsenred/);
 assert.doesNotMatch(backup,/qrsvliliezbiedmaewml/);
});
