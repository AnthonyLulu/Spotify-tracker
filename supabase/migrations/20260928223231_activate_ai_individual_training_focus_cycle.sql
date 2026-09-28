create table if not exists public.player_ai_training_focus_cycles (
  review_month date primary key,
  reviewed_on date not null,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.player_ai_training_focus_cycles enable row level security;
revoke all on table public.player_ai_training_focus_cycles from public, anon, authenticated;
grant select, insert, update on table public.player_ai_training_focus_cycles to service_role;

create or replace function public.run_ai_training_focus_cycle(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month date:=date_trunc('month',coalesce(p_date,current_date))::date;
  v_claimed int:=0;
  v_focus jsonb;
  v_training jsonb;
  v_result jsonb;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'historical_cutoff',true,'updated',0);
  end if;

  insert into public.player_ai_training_focus_cycles(review_month,reviewed_on)
  values(v_month,v_date)
  on conflict do nothing;
  get diagnostics v_claimed=row_count;

  if v_claimed=0 then
    select result into v_result
    from public.player_ai_training_focus_cycles
    where review_month=v_month;
    return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('already_reviewed',true);
  end if;

  v_focus:=public.refresh_ai_training_focus(v_date,null);
  v_training:=public.apply_ai_training_focus_development(v_date);

  v_result:=jsonb_build_object(
    'date',v_date,
    'review_month',v_month,
    'focus_refresh',coalesce(v_focus,'{}'::jsonb),
    'focused_development',coalesce(v_training,'{}'::jsonb),
    'model','monthly AI individual focus cycle · 74 attributes'
  );

  update public.player_ai_training_focus_cycles
  set result=v_result
  where review_month=v_month;

  return v_result;
end;
$$;

revoke all on function public.run_ai_training_focus_cycle(date) from public, anon, authenticated;
grant execute on function public.run_ai_training_focus_cycle(date) to service_role;
