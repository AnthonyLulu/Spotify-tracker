create or replace function public.apply_player_ai_training(p_date date default current_date)
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
  v_gain jsonb;
  v_result jsonb;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'updated',0,'historical_cutoff',true);
  end if;

  insert into public.player_ai_training_cycles(review_month,trained_on)
  values(v_month,v_date)
  on conflict do nothing;
  get diagnostics v_claimed=row_count;

  if v_claimed=0 then
    select result into v_result
    from public.player_ai_training_cycles
    where review_month=v_month;
    return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('date',v_date,'already_reviewed',true);
  end if;

  v_focus:=public.refresh_ai_training_focus(v_date,null);
  v_gain:=public.apply_ai_training_focus_development(v_date);

  v_result:=jsonb_build_object(
    'date',v_date,
    'review_month',v_month,
    'focus_refresh',coalesce(v_focus,'{}'::jsonb),
    'development',coalesce(v_gain,'{}'::jsonb),
    'model','AI individual focus + archetype/style + attribute ceilings'
  );

  update public.player_ai_training_cycles
  set result=v_result
  where review_month=v_month;

  return v_result;
end;
$$;

revoke all on function public.apply_player_ai_training(date) from public,anon,authenticated;
grant execute on function public.apply_player_ai_training(date) to service_role;
