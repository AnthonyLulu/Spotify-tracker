
drop policy if exists "service_role_read_atp_commitment_rules_v18" on public.atp_commitment_rules_v18;
create policy "service_role_read_atp_commitment_rules_v18"
on public.atp_commitment_rules_v18
for select
to service_role
using (true);
