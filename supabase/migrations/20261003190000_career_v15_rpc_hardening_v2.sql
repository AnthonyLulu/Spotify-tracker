-- Court Boss Career V15 RPC hardening v2
revoke all on function public.career_operating_cost_profile_v15(date) from public,anon,authenticated;
revoke all on function public.process_career_operating_costs_v15(date,integer) from public,anon,authenticated;
revoke all on function public.career_generate_media_event_v15(date) from public,anon,authenticated;
revoke all on function public.career_long_term_health_v15(date) from public,anon,authenticated;
revoke all on function public.apply_managed_medical_week(date,bigint) from public,anon,authenticated;

grant execute on function public.career_operating_cost_profile_v15(date) to service_role;
grant execute on function public.process_career_operating_costs_v15(date,integer) to service_role;
grant execute on function public.career_generate_media_event_v15(date) to service_role;
grant execute on function public.career_long_term_health_v15(date) to service_role;
grant execute on function public.apply_managed_medical_week(date,bigint) to service_role;
