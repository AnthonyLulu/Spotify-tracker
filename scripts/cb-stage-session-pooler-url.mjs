// Construct an isolated-stage Postgres session-pooler URL WITHOUT logging secrets.
// Only an exact hostname copied from the project's Supabase Connect dialog is accepted.
const host = process.env.CB_E2E_POOLER_HOST || '';
const password = process.env.CB_E2E_DB_PASSWORD || '';
const project = 'sozrygjxjotozrsenred';

if (!/^aws-[0-9]+-[a-z0-9-]+\.pooler\.supabase\.com$/.test(host)) {
  console.error('Invalid session-pooler host. Copy the HOST only from Supabase Connect > Session pooler.');
  process.exit(2);
}
if (!password) {
  console.error('Missing stage DB password secret');
  process.exit(2);
}
const u = new URL('postgresql://postgres.' + project + '@' + host + ':5432/postgres');
u.password = password; // URL-encode safely, including symbols such as @, # and /.
u.searchParams.set('sslmode', 'require');
process.stdout.write(u.toString());
