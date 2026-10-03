-- Court Boss Living World V14 RPC hardening
revoke all on function public.record_weekly_operating_costs_v14(date,integer,numeric,numeric,numeric) from public,anon,authenticated;
revoke all on function public.refresh_staff_lifecycle_v14(date) from public,anon,authenticated;
revoke all on function public.apply_injury_prevention_cycle_v14(date) from public,anon,authenticated;
revoke all on function public.living_world_integrity_audit_v14(date) from public,anon,authenticated;
revoke all on function public.living_world_horizon_test_v14(integer,integer) from public,anon,authenticated;
revoke all on function public.career_system_health(date) from public,anon,authenticated;
revoke all on function public.resolve_managed_media_event(bigint,text) from public,anon,authenticated;

grant execute on function public.record_weekly_operating_costs_v14(date,integer,numeric,numeric,numeric) to service_role;
grant execute on function public.refresh_staff_lifecycle_v14(date) to service_role;
grant execute on function public.apply_injury_prevention_cycle_v14(date) to service_role;
grant execute on function public.living_world_integrity_audit_v14(date) to service_role;
grant execute on function public.living_world_horizon_test_v14(integer,integer) to service_role;
grant execute on function public.career_system_health(date) to service_role;
grant execute on function public.resolve_managed_media_event(bigint,text) to service_role;
