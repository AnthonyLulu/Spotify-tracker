revoke all on function public.refresh_player_archetypes(date) from public,anon,authenticated;
grant execute on function public.refresh_player_archetypes(date) to service_role;
