-- ITF 2026 WTT Regulations III.A.6: ranking 21 days before Monday of tournament week.
-- https://www.itftennis.com/media/15546/2026-wtt-regulations.pdf (page 21)
CREATE OR REPLACE FUNCTION public.tournament_entry_eligibility(p_player_id bigint, p_tournament_id bigint, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  r integer;
  ranking_date date;
  method text:=lower(coalesce(p_entry_method,'direct'));
  ok boolean:=true;
  reason text:='eligible';
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_player_or_tournament');
  end if;

  ranking_date:=
    case
      when t.circuit='ATP' and t.category in ('ATP 250','ATP 500','Masters 1000')
        then coalesce(
          case when method='qualifying' then t.qualifying_entry_deadline else t.main_entry_deadline end,
          t.start_date-21
        )
      when t.circuit='Challenger' then coalesce(t.main_entry_deadline,t.start_date-21)
      when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-21
      else t.start_date
    end;

  r:=public.player_rank_at_date(p.id,ranking_date);

  if coalesce(p.career_status,'active')<>'active' then
    ok:=false; reason:='inactive_player';
  elsif coalesce(p.career_focus,'mixed')='doubles_only' then
    ok:=false; reason:='doubles_only';
  elsif coalesce(p.injury_status,'Fit')<>'Fit' then
    ok:=false; reason:='injured';

  -- ATP 2026 advanced-entry thresholds.
  elsif t.circuit='ATP'
    and t.category in ('ATP 250','ATP 500','Masters 1000')
    and method in ('direct','qualifying')
    and r>500 then
    ok:=false; reason:='atp_advanced_entry_top500_required';

  elsif t.circuit='Challenger'
    and t.category in ('Challenger 175','Challenger 125')
    and method='direct'
    and r>500 then
    ok:=false; reason:='challenger_175_125_direct_top500_required';

  -- ITF 2026 play-down rule.
  elsif t.circuit='ITF' and t.category in ('M15','M25') and r between 1 and 200 then
    ok:=false; reason:='itf_play_down_top200';

  -- Challenger 50.
  elsif t.circuit='Challenger' and t.category='Challenger 50' then
    if r between 1 and 50 then
      ok:=false; reason:='ch50_top50_prohibited';
    elsif r between 51 and 150 then
      if method not in ('wildcard','candidate') then
        ok:=false; reason:='ch50_top150_no_direct_or_qualifying';
      elsif r between 51 and 100 and p.country is distinct from t.country then
        ok:=false; reason:='ch50_wc_51_100_home_nation_only';
      end if;
    end if;

  -- Challenger 75-125 play-up rules.
  elsif t.circuit='Challenger' and t.category in ('Challenger 75','Challenger 100','Challenger 125') then
    if r between 1 and 10 then
      ok:=false; reason:='challenger_top10_prohibited';
    elsif r between 11 and 50 then
      if t.category='Challenger 75' then
        ok:=false; reason:='ch75_11_50_prohibited';
      elsif method not in ('wildcard','qualifying_wildcard','candidate') then
        ok:=false; reason:='challenger_11_50_wildcard_only';
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'eligible',ok,
    'reason',reason,
    'ranking',r,
    'ranking_date',ranking_date,
    'entry_method',method,
    'circuit',t.circuit,
    'category',t.category
  );
end;
$function$
;

