do $cb$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid)
  into v_def
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='simulate_junior_world_tournaments'
  limit 1;

  if v_def is null then
    raise exception 'simulate_junior_world_tournaments not found';
  end if;

  if position('v_match jsonb;' in v_def)=0 then
    if position(E'  singles_simulated int:=0;\n  doubles_simulated int:=0;\nbegin' in v_def)=0 then
      raise exception 'junior declaration anchor missing';
    end if;
    v_def:=replace(
      v_def,
      E'  singles_simulated int:=0;\n  doubles_simulated int:=0;\nbegin',
      E'  singles_simulated int:=0;\n  doubles_simulated int:=0;\n  v_match jsonb;\n  v_prob numeric;\n  v_tmp_id bigint;\n  v_tmp_name text;\n  v_pair1_strength int;\n  v_pair2_strength int;\n  v_pair_prob numeric;\nbegin'
    );
  end if;

  if position('player_matchup_probability_v4(' in v_def)=0 then
    if position(E'      if sw is not null and sf is not null then\n        update public.players' in v_def)=0 then
      raise exception 'junior singles anchor missing';
    end if;
    v_def:=replace(
      v_def,
      E'      if sw is not null and sf is not null then\n        update public.players',
      E'      if sw is not null and sf is not null then\n        v_match:=public.player_matchup_probability_v4(\n          sw,sf,t.surface,coalesce(t.end_date,t.start_date),\n          coalesce(t.court_speed,\n            case when t.surface ilike ''Terre%'' then .68\n                 when t.surface ilike ''Gazon%'' then 1.15\n                 when coalesce(t.indoor,false) then 1.18\n                 else 1.0 end),\n          3\n        );\n        v_prob:=coalesce((v_match->>''player_a_probability'')::numeric,.5);\n        if random()>v_prob then\n          v_tmp_id:=sw; sw:=sf; sf:=v_tmp_id;\n          v_tmp_name:=sw_name; sw_name:=sf_name; sf_name:=v_tmp_name;\n          v_prob:=1-v_prob;\n        end if;\n\n        update public.players'
    );
  end if;

  if position('doubles_pair_metrics(dw1,dw2' in v_def)=0 then
    if position(E'      if dw1 is not null and dw2 is not null and df1 is not null and df2 is not null then\n        update public.players' in v_def)=0 then
      raise exception 'junior doubles anchor missing';
    end if;
    v_def:=replace(
      v_def,
      E'      if dw1 is not null and dw2 is not null and df1 is not null and df2 is not null then\n        update public.players',
      E'      if dw1 is not null and dw2 is not null and df1 is not null and df2 is not null then\n        select pair_strength into v_pair1_strength\n        from public.doubles_pair_metrics(dw1,dw2,coalesce(t.end_date,t.start_date));\n        select pair_strength into v_pair2_strength\n        from public.doubles_pair_metrics(df1,df2,coalesce(t.end_date,t.start_date));\n        v_pair_prob:=greatest(.18,least(.82,\n          1/(1+exp(-(coalesce(v_pair1_strength,50)-coalesce(v_pair2_strength,50))/8.0))\n        ));\n        if random()>v_pair_prob then\n          v_tmp_id:=dw1; dw1:=df1; df1:=v_tmp_id;\n          v_tmp_id:=dw2; dw2:=df2; df2:=v_tmp_id;\n          v_tmp_name:=dw1_name; dw1_name:=df1_name; df1_name:=v_tmp_name;\n          v_tmp_name:=dw2_name; dw2_name:=df2_name; df2_name:=v_tmp_name;\n          v_pair_prob:=1-v_pair_prob;\n        end if;\n\n        update public.players'
    );
  end if;

  execute v_def;
end
$cb$;
