-- Court Boss · dynamic ATP calendar evolution v1
-- 2026 remains the canonical template.
-- Grand Slams never move.
-- Masters 1000 remain fixed, except the Canadian Masters alternating Montreal/Toronto.
-- ATP 500/250 franchises can rarely relocate in deterministic four-season hosting contracts.

create or replace function public.calendar_evolution_hash(p_text text)
returns integer
language sql
immutable
set search_path = public
as $$
  select (('x' || substr(md5(coalesce(p_text,'')),1,7))::bit(28)::int);
$$;

create or replace function public.calendar_future_variant(
  p_year integer,
  p_competition_key text,
  p_category text,
  p_surface text,
  p_country text,
  p_city text
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_region text;
  v_cycle integer;
  v_c integer;
  v_threshold integer;
  v_roll integer;
  v_variant_seed integer := -1;
  v_return_roll integer;
  v_pick jsonb;
begin
  if p_year < 2027 or p_category not in ('ATP 500','ATP 250') then
    return jsonb_build_object('changed',false);
  end if;

  v_region := case
    when p_country in ('USA','CAN','MEX','ARG','BRA','CHI','COL','PER','URU','ECU') then 'AMERICAS'
    when p_country in ('CHN','JPN','KOR','HKG','TPE','SGP','AUS','NZL','KAZ','UAE','QAT','IND') then 'ASIA_PAC'
    else 'EUROPE'
  end;

  v_cycle := greatest(0,(p_year-2027)/4);
  v_threshold := case when p_category='ATP 500' then 60 else 120 end;

  for v_c in 0..v_cycle loop
    v_roll := mod(public.calendar_evolution_hash(
      'relocate|'||coalesce(p_competition_key,p_city)||'|'||v_c
    ),1000);

    if v_roll < v_threshold then
      v_return_roll := mod(public.calendar_evolution_hash(
        'return|'||coalesce(p_competition_key,p_city)||'|'||v_c
      ),100);

      if v_variant_seed >= 0 and v_return_roll < 18 then
        v_variant_seed := -1;
      else
        v_variant_seed := public.calendar_evolution_hash(
          'venue|'||coalesce(p_competition_key,p_city)||'|'||v_c
        );
      end if;
    end if;
  end loop;

  if v_variant_seed < 0 then
    return jsonb_build_object(
      'changed',false,
      'cycle',v_cycle,
      'contract_block_start',2027+v_cycle*4,
      'contract_block_end',2030+v_cycle*4
    );
  end if;

  with candidates(region,surface,city,country) as (
    values
      ('EUROPE','Dur','Copenhagen','DEN'),
      ('EUROPE','Dur','Helsinki','FIN'),
      ('EUROPE','Dur','Prague','CZE'),
      ('EUROPE','Dur','Dublin','IRL'),
      ('EUROPE','Dur','Milan','ITA'),
      ('EUROPE','Dur','Luxembourg','LUX'),
      ('EUROPE','Dur','Sofia','BUL'),
      ('EUROPE','Dur','Warsaw','POL'),
      ('EUROPE','Terre','Belgrade','SRB'),
      ('EUROPE','Terre','Naples','ITA'),
      ('EUROPE','Terre','Valencia','ESP'),
      ('EUROPE','Terre','Bordeaux','FRA'),
      ('EUROPE','Terre','Split','CRO'),
      ('EUROPE','Terre','Athens','GRE'),
      ('EUROPE','Terre','Bratislava','SVK'),
      ('EUROPE','Gazon','Nottingham','GBR'),
      ('EUROPE','Gazon','Manchester','GBR'),
      ('EUROPE','Gazon','Berlin','GER'),
      ('EUROPE','Gazon','Dublin','IRL'),
      ('AMERICAS','Dur','Austin','USA'),
      ('AMERICAS','Dur','San Diego','USA'),
      ('AMERICAS','Dur','Vancouver','CAN'),
      ('AMERICAS','Dur','Monterrey','MEX'),
      ('AMERICAS','Dur','Orlando','USA'),
      ('AMERICAS','Dur','Cartagena','COL'),
      ('AMERICAS','Terre','Cordoba','ARG'),
      ('AMERICAS','Terre','Montevideo','URU'),
      ('AMERICAS','Terre','Bogota','COL'),
      ('AMERICAS','Terre','Sao Paulo','BRA'),
      ('AMERICAS','Terre','Lima','PER'),
      ('ASIA_PAC','Dur','Seoul','KOR'),
      ('ASIA_PAC','Dur','Taipei','TPE'),
      ('ASIA_PAC','Dur','Singapore','SGP'),
      ('ASIA_PAC','Dur','Osaka','JPN'),
      ('ASIA_PAC','Dur','Manila','PHI'),
      ('ASIA_PAC','Dur','Perth','AUS'),
      ('ASIA_PAC','Terre','Da Nang','VIE'),
      ('ASIA_PAC','Terre','Busan','KOR'),
      ('ASIA_PAC','Gazon','Perth','AUS')
  ),
  ranked as (
    select city,country,
           row_number() over(order by city,country)::int as rn,
           count(*) over()::int as cnt
    from candidates
    where region=v_region
      and surface=p_surface
      and lower(city)<>lower(coalesce(p_city,''))
  )
  select jsonb_build_object(
      'changed',true,
      'city',city,
      'country',country,
      'name',city||' Open',
      'cycle',v_cycle,
      'contract_block_start',2027+v_cycle*4,
      'contract_block_end',2030+v_cycle*4
    )
    into v_pick
  from ranked
  where rn=1+mod(v_variant_seed,cnt)
  limit 1;

  if v_pick is null then
    return jsonb_build_object('changed',false,'cycle',v_cycle);
  end if;

  return v_pick;
end;
$$;

create or replace function public.apply_future_calendar_identity()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_year integer;
  b public.tournaments%rowtype;
  v_variant jsonb;
begin
  v_year := coalesce(new.official_season,extract(year from new.start_date)::int);

  if v_year <= 2026 then
    return new;
  end if;

  if coalesce(new.source_note,'') not like 'Court Boss · calendrier auto-généré%'
     and coalesce(new.source_note,'') not like 'Court Boss dynamic calendar%' then
    return new;
  end if;

  if new.competition_key is null then
    return new;
  end if;

  select *
    into b
  from public.tournaments
  where extract(year from start_date)=2026
    and is_active=true
    and competition_key=new.competition_key
  order by id
  limit 1;

  if b.id is null then
    return new;
  end if;

  new.name := b.name;
  new.city := b.city;
  new.country := b.country;
  new.surface := b.surface;
  new.indoor := b.indoor;
  new.environment := b.environment;
  new.venue := b.venue;
  new.image_url := b.image_url;
  new.image_source_url := b.image_source_url;
  new.image_source_label := b.image_source_label;
  new.logo_url := b.logo_url;
  new.logo_source_url := b.logo_source_url;
  new.logo_source_label := b.logo_source_label;
  new.source_note := 'Court Boss · calendrier auto-généré depuis le patron 2026 · saison '||v_year;
  new.schedule_source_label := 'Court Boss infinite calendar · template 2026';

  if b.category='Grand Chelem' then
    return new;
  end if;

  if b.category='Masters 1000' then
    if b.competition_key='masters:canada' then
      if mod(v_year,2)=0 then
        new.city := 'Montreal';
      else
        new.city := 'Toronto';
        new.image_url := null;
        new.image_source_url := null;
        new.image_source_label := null;
      end if;
      new.source_note := 'Court Boss dynamic calendar · Canadian Masters alternation · '
        ||new.city||' · saison '||v_year;
      new.schedule_source_label := 'Court Boss Canadian Masters rotation';
    end if;
    return new;
  end if;

  if b.category in ('ATP 500','ATP 250') then
    v_variant := public.calendar_future_variant(
      v_year,b.competition_key,b.category,b.surface,b.country,b.city
    );

    if coalesce((v_variant->>'changed')::boolean,false) then
      new.city := v_variant->>'city';
      new.country := v_variant->>'country';
      new.name := v_variant->>'name';
      new.venue := null;
      new.image_url := null;
      new.image_source_url := null;
      new.image_source_label := null;
      new.logo_url := null;
      new.logo_source_url := null;
      new.logo_source_label := null;
      new.is_verified := false;
      new.source_url := null;
      new.source_note := 'Court Boss dynamic calendar · '
        ||b.category||' relocated from '||coalesce(b.city,'?')
        ||' to '||new.city
        ||' · contract '||coalesce(v_variant->>'contract_block_start','?')
        ||'-'||coalesce(v_variant->>'contract_block_end','?');
      new.schedule_source_label := 'Court Boss dynamic ATP calendar';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists tournaments_future_calendar_identity on public.tournaments;
create trigger tournaments_future_calendar_identity
before insert or update on public.tournaments
for each row
execute function public.apply_future_calendar_identity();

update public.tournaments
set city=city
where coalesce(official_season,extract(year from start_date)::int)>2026
  and is_active=true
  and (
    source_note like 'Court Boss · calendrier auto-généré%'
    or source_note like 'Court Boss dynamic calendar%'
  )
  and circuit='ATP';
