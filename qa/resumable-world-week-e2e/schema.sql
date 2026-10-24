-- QA-only E2E schema; NEVER apply directly to production.
CREATE TABLE IF NOT EXISTS cb_e2e_reconstruction_20261010.world_week_jobs_v1 (
 job_key text PRIMARY KEY,
 from_date date NOT NULL,
 to_date date NOT NULL,
 status text NOT NULL DEFAULT 'running' CHECK(status IN ('running','completed')),
 expected_items integer NOT NULL DEFAULT 0,
 completed_items integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(to_date > from_date)
);
CREATE TABLE IF NOT EXISTS cb_e2e_reconstruction_20261010.world_week_items_v1 (
 job_key text NOT NULL REFERENCES cb_e2e_reconstruction_20261010.world_week_jobs_v1(job_key) ON DELETE CASCADE,
 tournament_id bigint NOT NULL REFERENCES public.tournaments(id),
 seq integer NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','completed')),
 matches_added integer NOT NULL DEFAULT 0,
 ranking_rows_added integer NOT NULL DEFAULT 0,
 completed_at timestamptz,
 PRIMARY KEY(job_key,tournament_id),
 UNIQUE(job_key,seq)
);
CREATE INDEX IF NOT EXISTS cb_e2e_week_step_pending_v1
 ON cb_e2e_reconstruction_20261010.world_week_items_v1(job_key,status,seq);
REVOKE ALL ON cb_e2e_reconstruction_20261010.world_week_jobs_v1 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON cb_e2e_reconstruction_20261010.world_week_items_v1 FROM PUBLIC,anon,authenticated;
