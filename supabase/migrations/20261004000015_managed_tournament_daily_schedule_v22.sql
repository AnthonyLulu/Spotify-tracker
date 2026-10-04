
create or replace function public.managed_tournament_match_date_v22(
  p_tournament_id bigint,
  p_player_id bigint,
  p_round_code text,
  p_phase text default 'main',
  p_event_type text default 'singles'
)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  v_phase text:=lower(coalesce(p_phase,'main'));
  v_event text:=lower(coalesce(p_event_type,'singles'));
  v_code text:=upper(coalesce(p_round_code,''));
  v_start date;
  v_end date;
  v_span int:=0;
  v_draw int:=0;
  v_bracket int:=0;
  v_rounds int:=1;
  v_idx int:=1;
  v_q_slots int:=1;
  v_base date;
  v_next_base date;
  v_shift int:=0;
  v_date date;
  v_gap int:=0;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  if v_phase='qualifying' or v_code like 'Q%' or v_code like 'DQ%' then
    v_start:=coalesce(t.qualifying_start_date,t.start_date-1);
    v_end:=coalesce(t.qualifying_end_date,v_start);

    if v_event='doubles' and v_code like 'DQ%' then
      v_rounds:=case when v_code='DQF' then 2 else 2 end;
      v_idx:=case when v_code='DQF' then 2 else 1 end;
    else
      select * into r
      from public.tournament_format_rules fr
      where fr.circuit=t.circuit
        and fr.category=t.category
        and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
      limit 1;

      v_draw:=greatest(1,coalesce(t.qualifying_draw_size,r.qualifying_draw_size,1));
      v_q_slots:=greatest(1,coalesce(r.qualifier_count,1));
      v_rounds:=greatest(1,ceil(ln(v_draw::numeric/v_q_slots::numeric)/ln(2::numeric))::int);
      if v_code ~ '^Q[0-9]+$' then
        v_idx:=greatest(1,least(v_rounds,substring(v_code from 2)::int));
      else
        v_idx:=1;
      end if;
    end if;
  else
    v_start:=coalesce(t.main_draw_start_date,t.start_date);
    v_end:=coalesce(t.end_date,v_start);

    if v_event='doubles' then
      v_draw:=greatest(4,coalesce(t.doubles_draw_size,16));
    else
      v_draw:=greatest(2,coalesce(t.singles_draw_size,t.draw_size,32));
    end if;

    v_bracket:=power(2,ceil(ln(v_draw::numeric)/ln(2::numeric)))::int;
    v_rounds:=greatest(1,ceil(ln(v_bracket::numeric)/ln(2::numeric))::int);

    if v_code='F' then v_idx:=v_rounds;
    elsif v_code='SF' then v_idx:=greatest(1,v_rounds-1);
    elsif v_code='QF' then v_idx:=greatest(1,v_rounds-2);
    elsif v_code ~ '^R[0-9]+$' then
      v_idx:=greatest(
        1,
        least(
          v_rounds,
          v_rounds-ceil(ln(substring(v_code from 2)::numeric)/ln(2::numeric))::int+1
        )
      );
    else
      v_idx:=1;
    end if;
  end if;

  v_span:=greatest(0,v_end-v_start);
  v_base:=v_start+
    case
      when v_rounds<=1 then 0
      else round((v_idx-1)::numeric*v_span/greatest(1,v_rounds-1))::int
    end;

  v_next_base:=v_start+
    case
      when v_rounds<=1 or v_idx>=v_rounds then v_span
      else round(v_idx::numeric*v_span/greatest(1,v_rounds-1))::int
    end;

  v_gap:=greatest(0,v_next_base-v_base);

  -- Early-round order-of-play variation. If the calendar leaves at least one
  -- spare day before the next round, half the field plays on day two.
  if v_idx<v_rounds and v_gap>=2 then
    v_shift:=mod(abs(hashtext(
      'managed-order-v22|'||t.id::text||'|'||coalesce(p_player_id,0)::text||'|'||v_code||'|'||v_event
    )),2);
  end if;

  v_date:=least(v_end,v_base+v_shift);

  return jsonb_build_object(
    'ok',true,
    'tournament_id',t.id,
    'player_id',p_player_id,
    'event_type',v_event,
    'phase',case when v_phase='qualifying' or v_code like 'Q%' or v_code like 'DQ%' then 'qualifying' else 'main' end,
    'round_code',v_code,
    'round_index',v_idx,
    'rounds_count',v_rounds,
    'match_date',v_date,
    'base_round_date',v_base,
    'next_round_base_date',case when v_idx<v_rounds then v_next_base else null end,
    'event_start',v_start,
    'event_end',v_end,
    'order_shift_days',v_shift,
    'model','CB-MANAGED-TOURNAMENT-DAY-v22'
  );
end;
$function$;

revoke all on function public.managed_tournament_match_date_v22(bigint,bigint,text,text,text) from public,anon,authenticated;
grant execute on function public.managed_tournament_match_date_v22(bigint,bigint,text,text,text) to service_role;
