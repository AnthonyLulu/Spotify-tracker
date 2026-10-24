# Manual, private, independent stage backup with GitHub Actions (P0 v114)

This workflow provides a *possible executable path* to an off-Supabase encrypted archive for the isolated Court Boss 2025–2050 staging database without asking for any secret in ChatGPT.

### Scope, safety and status

- Workflow file: `.github/workflows/court-boss-stage-encrypted-backup.yml`.
- Trigger: **workflow_dispatch only**. It does not run from pushes, PRs or a timer. It refuses execution outside `court-boss-live`.
- Source host must be the isolated stage `sozrygjxjotozrsenred`, **never** the production `qrsvliliezbiedmaewml`. Source is read only. The stage must contain zero `game_saves`, `game_save_slots`, and `career_state`, plus the original checkpoint and 24,435 frozen synthetic player seed/attribute rows.
- Destination is disposable local Supabase PostgreSQL 17 on the GitHub Actions runner, database `cb_e2e_restore_ci`; never an existing remote database.
- The owner needs **two GitHub Actions repository secrets** (configure under repository Settings > Secrets and variables > Actions): `CB_E2E_DB_URL`, the stage-only connection string; `CB_BACKUP_AGE_RECIPIENT`, an **age public recipient** starting with `age1`. Keep the matching age private identity **offline**, NOT in the repository, in this chat or in an Actions secret.
- To create an owner-held key pair in a trusted private environment: `age-keygen -o /your/private/path/cb-e2e-key.txt`, then `age-keygen -y /your/private/path/cb-e2e-key.txt` to copy only the **public key** into the GitHub secret. Never publish the private file.
- Run manually from repository Actions > **Court Boss E2E isolated-stage encrypted backup (manual only)** > Run workflow, selecting `court-boss-live`.
- On successful source dump and local restore content parity, an encrypted `.tar.age` plus `.sha256` is uploaded as the `court-boss-isolated-stage-encrypted-backup` artifact, for **7 days**. Download it onto owner-controlled storage before expiration. Securely retain the decryption private identity somewhere else. GitHub artifacts are not permanent backups.
- Verify download checksum with `sha256sum -c <archive>.sha256`. Decrypt **offline** with `age -d -i /your/private/path/cb-e2e-key.txt <archive>.tar.age > backup.tar`, and inspect `tar -tf backup.tar`. Inside the extracted archive, `sha256sum -c SHA256SUMS` validates the dump contents. Only then record the independent-backup receipt. No passwords/private keys pasted into ChatGPT.
- GitHub Actions runtime costs, archive storage limits and any organization approvals should be checked by the repository owner before running. The workflow does **not** automatically create/charge a new Supabase or Render database.

### What is verified automatically, and what remains unverified

Automatic: source stage ID and zero private saves; full schema/data/roles SQL dump; a fresh PG17 local restore; twelve baseline + fourteen world side-effect table count and sorted row-hash comparisons, before/after export and after local restore; age recipient encryption; artifact generation. If any check fails, no artifact is uploaded.

**NOT automatic:** final age ciphertext decryption by the owner, 100% of Supabase platform schemas (auth/storage are omitted by the CLI), and all noncritical game-table digest parity. The existing local restore script may need adjustments for extension/schema compatibility. This workflow has not been dispatched end-to-end during development: its first run may fail; troubleshoot failures before claiming a verified backup.

Until an independent encrypted file has actually been downloaded, decrypted and restored successfully, do **not** reset original stage, delete cancelled events, replay the 22 Feb 2026-to-29 Mar 2026 span, or certify 2050. Production stays untouched.
