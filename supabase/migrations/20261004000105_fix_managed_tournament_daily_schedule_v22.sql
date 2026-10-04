
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
  v_is_qual boolean:=false;
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

  v_is_qual:=v_phase='qualifying'
    or v_code ~ '^Q[0-9]+$'
    or v_code ~ '^DQ(?:[0-9]+|F)$';

  if v_is_qual then
    v_start:=coalesce(t.qualifying_start_date,t.start_date-1);
    v_end:=coalesce(t.qualifying_end_date,v_start);

    if v_event='doubles' and v_code like 'DQ%' then
      v_rounds:=2;
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

      -- qualifying rounds are small, use threshold math without floating-point
      -- edge cases at exact powers of two.
      if v_draw<=v_q_slots then v_rounds:=1;
      elsif v_draw<=v_q_slots*2 then v_rounds:=1;
      elsif v_draw<=v_q_slots*4 then v_rounds:=2;
      elsif v_draw<=v_q_slots*8 then v_rounds:=3;
      elsif v_draw<=v_q_slots*16 then v_rounds:=4;
      else v_rounds:=5;
      end if;

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

    v_bracket:=case
      when v_draw<=4 then 4
      when v_draw<=8 then 8
      when v_draw<=16 then 16
      when v_draw<=32 then 32
      when v_draw<=64 then 64
      when v_draw<=128 then 128
      else 256
    end;
    v_rounds:=case v_bracket
      when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5
      when 64 then 6 when 128 then 7 else 8 end;

    v_idx:=case
      when v_code='F' then v_rounds
      when v_code='SF' then greatest(1,v_rounds-1)
      when v_code='QF' then greatest(1,v_rounds-2)
      when v_code='R16' then greatest(1,v_rounds-3)
      when v_code='R32' then greatest(1,v_rounds-4)
      when v_code='R64' then greatest(1,v_rounds-5)
      when v_code='R128' then greatest(1,v_rounds-6)
      when v_code='R256' then greatest(1,v_rounds-7)
      else 1
    end;
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
    'phase',case when v_is_qual then 'qualifying' else 'main' end,
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
