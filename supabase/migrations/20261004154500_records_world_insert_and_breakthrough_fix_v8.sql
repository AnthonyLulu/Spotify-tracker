-- Follow-up for Records/Awards V8.
-- Capture completed world matches inserted with a result, not only later winner updates,
-- and persist historical ace-record breakthroughs for any player/newgen.

create or replace function public.cb_world_match_stat_lines_trigger()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if new.winner_id is not null then
    if tg_op='INSERT' or old.winner_id is null or old.winner_id is distinct from new.winner_id then
      perform public.cb_record_world_match_stat_lines(new.id);
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_cb_world_match_stat_lines on public.world_tournament_matches;
create trigger trg_cb_world_match_stat_lines
after insert or update of winner_id on public.world_tournament_matches
for each row execute function public.cb_world_match_stat_lines_trigger();

create or replace function public.cb_stat_record_breakthrough_trigger()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_name text;
  v_country text;
  v_career_aces bigint:=0;
begin
  select p.name,p.country into v_name,v_country from public.players p where p.id=new.player_id;
  if v_name is null then return new; end if;

  select coalesce(pcs.aces,0)+coalesce((
    select sum(s.aces) from public.court_boss_match_stat_lines s
    where s.player_id=new.player_id
      and s.match_date>date '2025-12-01'
      and s.match_date<=new.match_date
  ),0)
  into v_career_aces
  from (select 1) z
  left join public.player_career_stats pcs on pcs.player_id=new.player_id;

  if v_career_aces>14450 and not exists(
    select 1 from public.record_occurrences ro
    where ro.record_code='career_aces_reference'
      and ro.player_id=new.player_id
      and coalesce(ro.value,0)>=v_career_aces
  ) then
    insert into public.record_occurrences(
      record_code,player_id,player_name,country,season,achieved_on,value,label,
      source_type,source_label,source_url,metadata
    ) values (
      'career_aces_reference',new.player_id,v_name,v_country,new.season,new.match_date,v_career_aces,
      v_career_aces||' aces en carrière','career','Court Boss · moteur stats v8','',
      jsonb_build_object('source_kind',new.source_kind,'source_id',new.source_id)
    );
  end if;

  if new.aces>=113 and not exists(
    select 1 from public.record_occurrences ro
    where ro.record_code='aces_match_record'
      and ro.player_id=new.player_id
      and coalesce(ro.value,0)>=new.aces
  ) then
    insert into public.record_occurrences(
      record_code,player_id,player_name,country,season,achieved_on,value,label,
      source_type,source_label,source_url,metadata
    ) values (
      'aces_match_record',new.player_id,v_name,v_country,new.season,new.match_date,new.aces,
      new.aces||' aces · '||coalesce((select t.name from public.tournaments t where t.id=new.tournament_id),'Match'),
      'career','Court Boss · moteur stats v8','',
      jsonb_build_object('source_kind',new.source_kind,'source_id',new.source_id,'world_match_id',new.world_match_id)
    );
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_cb_stat_record_breakthrough on public.court_boss_match_stat_lines;
create trigger trg_cb_stat_record_breakthrough
after insert or update of aces on public.court_boss_match_stat_lines
for each row execute function public.cb_stat_record_breakthrough_trigger();
