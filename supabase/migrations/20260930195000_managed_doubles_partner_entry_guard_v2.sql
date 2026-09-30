
create or replace function public.invalidate_managed_doubles_entries_on_partner_change()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_managed bigint;
  v_date date;
begin
  select managed_player_id,career_date into v_managed,v_date
  from public.career_state where id='demo';

  if new.player_a_id=v_managed then
    update public.managed_doubles_entries
    set status='withdrawn',
        withdrawn_on=coalesce(v_date,current_date),
        metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
          'withdrawal_reason','partner_changed',
          'replacement_partner_id',new.player_b_id
        ),
        updated_at=now()
    where owner_id='demo'
      and player_id=v_managed
      and status='entered'
      and partner_id<>new.player_b_id;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_invalidate_managed_doubles_entries_on_partner_change
  on public.doubles_partnerships;

create trigger trg_invalidate_managed_doubles_entries_on_partner_change
after insert on public.doubles_partnerships
for each row
execute function public.invalidate_managed_doubles_entries_on_partner_change();
