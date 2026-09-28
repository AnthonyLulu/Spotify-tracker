revoke execute on function public.normalize_newgen_potential_before_insert() from public,anon,authenticated;
grant execute on function public.normalize_newgen_potential_before_insert() to service_role;

revoke execute on function public.progress_player_development_weekly(date) from public,anon,authenticated;
grant execute on function public.progress_player_development_weekly(date) to service_role;

revoke execute on function public.refresh_player_attribute_trends(date) from public,anon,authenticated;
grant execute on function public.refresh_player_attribute_trends(date) to service_role;

revoke execute on function public.refresh_player_training_loads(date) from public,anon,authenticated;
grant execute on function public.refresh_player_training_loads(date) to service_role;
