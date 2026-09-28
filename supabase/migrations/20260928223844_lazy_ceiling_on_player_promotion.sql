create or replace function public.ensure_player_attribute_ceiling_on_promotion()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_date date;
begin
  if new.career_status='active'
     and coalesce(new.data_source,'') not ilike 'hidden duplicate merged into %'
     and (
       new.ranking_current=true
       or new.game_generated=true
       or new.itf_ranking is not null
       or new.junior_ranking is not null
       or new.ncaa_current=true
       or new.doubles_ranking is not null
     )
     and exists(select 1 from public.player_attributes a where a.player_id=new.id)
     and exists(select 1 from public.player_development_profiles d where d.player_id=new.id)
     and not exists(select 1 from public.player_attribute_ceilings c where c.player_id=new.id)
  then
    select coalesce(career_date,current_date) into v_date
    from public.career_state where id='demo';

    perform public.refresh_player_attribute_ceilings(coalesce(v_date,current_date),new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ensure_player_attribute_ceiling_on_promotion on public.players;
create trigger trg_ensure_player_attribute_ceiling_on_promotion
after update of ranking_current,itf_ranking,junior_ranking,ncaa_current,doubles_ranking,career_status,game_generated
on public.players
for each row execute function public.ensure_player_attribute_ceiling_on_promotion();

revoke execute on function public.ensure_player_attribute_ceiling_on_promotion() from public,anon,authenticated;
grant execute on function public.ensure_player_attribute_ceiling_on_promotion() to service_role;
