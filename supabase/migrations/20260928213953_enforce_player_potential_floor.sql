-- Simulation ratings: an already achieved level is the minimum possible ceiling.
create or replace function public.enforce_player_potential_floor()
returns trigger language plpgsql set search_path=public as $$
begin
  new.potential:=greatest(new.current_ability,coalesce(new.potential,new.current_ability));
  return new;
end;
$$;
revoke all on function public.enforce_player_potential_floor() from public,anon,authenticated;
grant execute on function public.enforce_player_potential_floor() to service_role;
create trigger trg_player_potential_floor before insert or update of current_ability,potential
on public.players for each row execute function public.enforce_player_potential_floor();
with corrected as (
  update public.players set potential=current_ability where potential<current_ability returning id,current_ability,potential
)
update public.player_development_profiles d set
  potential_floor=greatest(c.current_ability,d.potential_floor),
  potential_ceiling=greatest(c.potential,d.potential_ceiling),
  potential_star_rating=greatest(.5,least(5,round(c.potential/10.0)/2.0)),
  potential_star_min=greatest(.5,least(5,round(greatest(c.current_ability,d.potential_floor)/10.0)/2.0)),
  potential_star_max=greatest(.5,least(5,round(greatest(c.potential,d.potential_ceiling)/10.0)/2.0))
from corrected c where c.id=d.player_id;
