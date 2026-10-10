-- ISOLATED QA ONLY: performance experiment on real yearly newgen path.
-- Same deterministic candidate ordering, cached per transaction.
-- Never run against production without a separately validated migration.
-- Stage-only reusable name pools; source is the same eligible first/last lists.
-- Cached in the current SQL transaction, never persisted into public.
CREATE OR REPLACE FUNCTION public.cb_prime_newgen_name_pools_v1()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $cb_cache$
DECLARE
 c text;
 v_firsts text[];
 v_lasts text[];
 g_firsts text[];
 g_lasts text[];
 n int:=0;
BEGIN
 IF pg_catalog.to_regclass('pg_temp.cb_name_pool_cache_v1') IS NULL THEN
  CREATE TEMP TABLE cb_name_pool_cache_v1(
    country text PRIMARY KEY,
    firsts text[] NOT NULL,
    lasts text[] NOT NULL
  ) ON COMMIT DROP;
 ELSE
  TRUNCATE pg_temp.cb_name_pool_cache_v1;
 END IF;
 SELECT array_agg(value order by md5('GLOBAL|F|'||value)) INTO g_firsts FROM(
   SELECT DISTINCT value FROM public.newgen_name_parts
   WHERE kind='first' AND is_core=true
     AND char_length(trim(value)) BETWEEN 2 AND 28
     AND value ~ '[A-Za-zÀ-ÿ]' LIMIT 1400
 ) a;
 SELECT array_agg(value order by md5('GLOBAL|L|'||value)) INTO g_lasts FROM(
   SELECT DISTINCT value FROM public.newgen_name_parts
   WHERE kind='last' AND is_core=true
     AND char_length(trim(value)) BETWEEN 2 AND 34
     AND value ~ '[A-Za-zÀ-ÿ]'
     AND trim(value) !~ '[0-9@_/\\]' LIMIT 2200
 ) a;
 FOR c IN SELECT DISTINCT country FROM public.newgen_name_parts LOOP
   SELECT array_agg(value order by md5(c||'|F|'||value)) INTO v_firsts FROM(
    SELECT DISTINCT value FROM public.newgen_name_parts
    WHERE country=c AND kind='first'
      AND char_length(trim(value)) BETWEEN 2 AND 28
      AND value ~ '[A-Za-zÀ-ÿ]'
      AND lower(trim(value)) NOT IN ('unknown','player','tennis','none','null')
    LIMIT 1400
   ) a;
   SELECT array_agg(value order by md5(c||'|L|'||value)) INTO v_lasts FROM(
    SELECT DISTINCT value FROM public.newgen_name_parts
    WHERE country=c AND kind='last'
      AND char_length(trim(value)) BETWEEN 2 AND 34
      AND value ~ '[A-Za-zÀ-ÿ]'
      AND trim(value) !~ '[0-9@_/\\]'
      AND lower(trim(value)) NOT IN ('unknown','player','tennis','none','null')
    LIMIT 2200
   ) a;
   IF coalesce(array_length(v_firsts,1),0)<8 OR coalesce(array_length(v_lasts,1),0)<8 THEN
      v_firsts:=g_firsts;
      v_lasts:=g_lasts;
   END IF;
   IF v_firsts IS NOT NULL AND v_lasts IS NOT NULL THEN
     INSERT INTO pg_temp.cb_name_pool_cache_v1(country,firsts,lasts)
     VALUES(c,v_firsts,v_lasts);
     n:=n+1;
   END IF;
 END LOOP;
 RETURN pg_catalog.jsonb_build_object('ok',true,'countries',n,'transaction_local',true);
END;
$cb_cache$;
REVOKE ALL ON FUNCTION public.cb_prime_newgen_name_pools_v1() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.cb_prime_newgen_name_pools_v1() TO service_role;

CREATE OR REPLACE FUNCTION public.cb_generated_player_name(p_country text, p_seed integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
declare
  c text:=upper(coalesce(nullif(trim(p_country),''),'UNK'));
  firsts text[];
  lasts text[];
  fc int:=0;
  lc int:=0;
  fi int;
  li int;
  li2 int;
  fi2 int;
  candidate text;
  candidate_norm text;
  attempt int:=0;
  seedv bigint:=greatest(coalesce(p_seed,1),1);
begin
  if pg_catalog.to_regclass('pg_temp.cb_name_pool_cache_v1') is not null then
    select cache.firsts,cache.lasts into firsts,lasts
    from pg_temp.cb_name_pool_cache_v1 cache where cache.country=c;
  end if;
  if firsts is null or lasts is null then
    -- Backwards-compatible on cache miss: preserve exactly the original
    -- generator's deterministic country pool and fallback behavior.
    select array_agg(value order by md5(c||'|F|'||value))
  into firsts
  from (
    select distinct value
    from public.newgen_name_parts
    where country=c and kind='first'
      and char_length(trim(value)) between 2 and 28
      and value ~ '[A-Za-zÀ-ÿ]'
      and lower(trim(value)) not in ('unknown','player','tennis','none','null')
    limit 1400
  ) q;

  select array_agg(value order by md5(c||'|L|'||value))
  into lasts
  from (
    select distinct value
    from public.newgen_name_parts
    where country=c and kind='last'
      and char_length(trim(value)) between 2 and 34
      and value ~ '[A-Za-zÀ-ÿ]'
      and trim(value) !~ '[0-9@_/\\]'
      and lower(trim(value)) not in ('unknown','player','tennis','none','null')
    limit 2200
  ) q;
  end if;

  fc:=coalesce(array_length(firsts,1),0);
  lc:=coalesce(array_length(lasts,1),0);

  if fc<8 or lc<8 then
    select array_agg(value order by md5('GLOBAL|F|'||value))
    into firsts
    from (
      select distinct value
      from public.newgen_name_parts
      where kind='first' and is_core=true
        and char_length(trim(value)) between 2 and 28
        and value ~ '[A-Za-zÀ-ÿ]'
      limit 1400
    ) q;

    select array_agg(value order by md5('GLOBAL|L|'||value))
    into lasts
    from (
      select distinct value
      from public.newgen_name_parts
      where kind='last' and is_core=true
        and char_length(trim(value)) between 2 and 34
        and value ~ '[A-Za-zÀ-ÿ]'
        and trim(value) !~ '[0-9@_/\\]'
      limit 2200
    ) q;

    fc:=coalesce(array_length(firsts,1),0);
    lc:=coalesce(array_length(lasts,1),0);
  end if;

  if fc=0 or lc=0 then
    raise exception 'No newgen name pool available for %',c;
  end if;

  while attempt<500 loop
    fi:=mod(abs(hashtextextended(c||'|F|'||seedv::text||'|'||attempt::text,37)),fc)+1;
    li:=mod(abs(hashtextextended(c||'|L|'||seedv::text||'|'||attempt::text,83)),lc)+1;
    candidate:=trim(firsts[fi]||' '||lasts[li]);
    candidate_norm:=lower(regexp_replace(extensions.unaccent(candidate),'[^a-zA-Z0-9]+',' ','g'));

    if char_length(candidate) between 5 and 55
       and lower(extensions.unaccent(firsts[fi]))<>lower(extensions.unaccent(lasts[li]))
       and not exists(
         select 1
         from public.players p
         where p.name_norm=candidate_norm
       )
    then
      return candidate;
    end if;

    attempt:=attempt+1;
  end loop;

  -- Small-country pools may be exhausted after decades of newgens.
  -- Expand with country-local compound surnames before declaring exhaustion.
  -- Both passes remain deterministic and reject collisions against all players.
  if fc>=1 and lc>=2 then
    attempt:=0;
    while attempt<8000 loop
      fi:=mod(abs(hashtextextended(c||'|CF|'||seedv::text||'|'||attempt::text,41)),fc)+1;
      li:=mod(abs(hashtextextended(c||'|CL|'||seedv::text||'|'||attempt::text,43)),lc)+1;
      li2:=1+mod((li-1)+1+mod(abs(hashtextextended(c||'|CL2|'||seedv::text||'|'||attempt::text,47)),lc-1),lc);
      candidate:=trim(firsts[fi]||' '||lasts[li]||'-'||lasts[li2]);
      candidate_norm:=lower(regexp_replace(extensions.unaccent(candidate),'[^a-zA-Z0-9]+',' ','g'));
      if char_length(candidate) between 5 and 72
         and lower(extensions.unaccent(firsts[fi]))<>lower(extensions.unaccent(lasts[li]))
         and not exists(select 1 from public.players p where p.name_norm=candidate_norm)
      then return candidate;end if;
      attempt:=attempt+1;
    end loop;
  end if;
  -- Final country-local fallback uses a double given name, common in
  -- several circuits, keeping unique identities free of numeric suffixes.
  if fc>=2 and lc>=1 then
    attempt:=0;
    while attempt<8000 loop
      fi:=mod(abs(hashtextextended(c||'|DF|'||seedv::text||'|'||attempt::text,53)),fc)+1;
      fi2:=1+mod((fi-1)+1+mod(abs(hashtextextended(c||'|DF2|'||seedv::text||'|'||attempt::text,59)),fc-1),fc);
      li:=mod(abs(hashtextextended(c||'|DL|'||seedv::text||'|'||attempt::text,61)),lc)+1;
      candidate:=trim(firsts[fi]||' '||firsts[fi2]||' '||lasts[li]);
      candidate_norm:=lower(regexp_replace(extensions.unaccent(candidate),'[^a-zA-Z0-9]+',' ','g'));
      if char_length(candidate) between 5 and 72
         and lower(extensions.unaccent(firsts[fi]))<>lower(extensions.unaccent(lasts[li]))
         and not exists(select 1 from public.players p where p.name_norm=candidate_norm)
      then return candidate;end if;
      attempt:=attempt+1;
    end loop;
  end if;

  raise exception 'Unable to create unique generated name for % after base and compound fallback attempts',c;
end;
$function$;

CREATE OR REPLACE FUNCTION public.generate_newgens(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  transition_result jsonb;
  junior_result jsonb;
  trimmed_count int:=0;
  verified_real_count int:=0;
  generated_count int:=0;
  name_pool_refreshed boolean:=false;
  display_pool_result jsonb;
  junior_doubles_result jsonb;
begin
  if not exists(select 1 from public.newgen_name_parts limit 1) then
    perform public.refresh_newgen_name_parts();
    name_pool_refreshed:=true;
  end if;

  -- Transaction-local reusable arrays: avoid sorting name lists
  -- for each of ~2000 newborn juniors per season.
  perform public.cb_prime_newgen_name_pools_v1();
  transition_result:=public.transition_junior_pathways(p_year);
  junior_result:=public.ensure_junior_world_pool(p_year,2000);
  trimmed_count:=public.trim_junior_world_pool(2000);

  update public.players
  set generated_name_version=6
  where game_generated=true
    and coalesce(generated_name_version,0)<6;

  select count(distinct r.player_id)::int into verified_real_count
  from public.junior_verified_reference r
  join public.players p on p.id=r.player_id
  where r.verified=true
    and r.player_id is not null
    and p.is_real=true
    and p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %';

  select count(*)::int into generated_count
  from public.players p
  where p.game_generated=true
    and p.is_real=false
    and p.career_status='active'
    and p.age between 13 and 17
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %';

  perform public.refresh_game_world_ranks();
  display_pool_result:=public.refresh_junior_display_pool_v3(2000);
  junior_doubles_result:=public.refresh_junior_doubles_ranking(make_date(p_year,1,5));

  return jsonb_build_object(
    'year',p_year,
    'junior_pool',junior_result,
    'junior_pool_target',2000,
    'junior_pool_trimmed',trimmed_count,
    'junior_pool_real',verified_real_count,
    'junior_candidates_generated',generated_count,
    'junior_display_pool',display_pool_result,
    'junior_doubles_pool',junior_doubles_result,
    'pathways',transition_result,
    'country_name_pool_refreshed',name_pool_refreshed,
    'country_name_pool_size',(select count(*) from public.newgen_name_parts),
    'world_ranks_refreshed',true,
    'name_generator_version',6
  );
end;
$function$

