-- Court Boss · long-term Masters 1000 evolution v2
-- Grand Slams remain permanent.
-- Canadian Masters keeps Montreal/Toronto alternation.
-- Other Masters are protected through 2035, then one global licence review occurs every 8-12 years.
-- Category, surface, calendar slot, competition_key, history_group and prestige remain attached to the licence.

create or replace function public.masters1000_future_variant(
  p_year integer,
  p_competition_key text,
  p_surface text,
  p_month integer,
  p_city text,
  p_country text
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_event_year integer := 2036;
  v_selected text;
  v_roll integer;
  v_gap integer;
  v_relocated boolean := false;
  v_city text := p_city;
  v_country text := p_country;
  v_name text := null;
  v_last_change integer := null;
  v_return_roll integer;
  v_seed integer;
  v_pick record;
begin
  if p_year < 2036 or p_competition_key is null or p_competition_key='masters:canada' then
    return jsonb_build_object('changed',false,'protected',true,'protected_through',2035);
  end if;

  while v_event_year <= p_year loop
    v_roll := mod(public.calendar_evolution_hash('masters-license|'||v_event_year),42);

    v_selected := case
      when v_roll < 2 then 'masters:indian-wells'
      when v_roll < 6 then 'masters:miami'
      when v_roll < 7 then 'masters:monte-carlo'
      when v_roll < 17 then 'masters:madrid'
      when v_roll < 19 then 'masters:rome'
      when v_roll < 27 then 'masters:cincinnati'
      when v_roll < 33 then 'masters:shanghai'
      else 'masters:paris'
    end;

    if v_selected = p_competition_key then
      v_return_roll := mod(public.calendar_evolution_hash(
        'masters-return|'||p_competition_key||'|'||v_event_year
      ),100);

      if v_relocated and v_return_roll < 28 then
        v_relocated := false;
        v_city := p_city;
        v_country := p_country;
        v_name := null;
        v_last_change := v_event_year;
      else
        v_seed := public.calendar_evolution_hash(
          'masters-host|'||p_competition_key||'|'||v_event_year
        );

        select c.city,c.country
          into v_pick
        from (
          select x.city,x.country,
                 row_number() over(order by x.city,x.country)::integer as rn,
                 count(*) over()::integer as cnt
          from (values
            ('masters:indian-wells','Las Vegas','USA'),
            ('masters:indian-wells','Phoenix','USA'),
            ('masters:indian-wells','San Diego','USA'),
            ('masters:miami','Atlanta','USA'),
            ('masters:miami','Orlando','USA'),
            ('masters:miami','Mexico City','MEX'),
            ('masters:monte-carlo','Nice','FRA'),
            ('masters:monte-carlo','Marseille','FRA'),
            ('masters:monte-carlo','Genoa','ITA'),
            ('masters:madrid','Lisbon','POR'),
            ('masters:madrid','Seville','ESP'),
            ('masters:madrid','Valencia','ESP'),
            ('masters:rome','Florence','ITA'),
            ('masters:rome','Milan','ITA'),
            ('masters:rome','Naples','ITA'),
            ('masters:cincinnati','Chicago','USA'),
            ('masters:cincinnati','Indianapolis','USA'),
            ('masters:cincinnati','Nashville','USA'),
            ('masters:shanghai','Seoul','KOR'),
            ('masters:shanghai','Singapore','SGP'),
            ('masters:shanghai','Osaka','JPN'),
            ('masters:paris','Brussels','BEL'),
            ('masters:paris','Frankfurt','GER'),
            ('masters:paris','London','GBR')
          ) as x(key,city,country)
          where x.key=p_competition_key
            and lower(x.city)<>lower(coalesce(v_city,''))
        ) c
        where c.rn=1+mod(v_seed,c.cnt)
        limit 1;

        if v_pick.city is not null then
          v_relocated := true;
          v_city := v_pick.city;
          v_country := v_pick.country;
          v_name := v_city||' Masters';
          v_last_change := v_event_year;
        end if;
      end if;
    end if;

    v_gap := 8 + mod(public.calendar_evolution_hash('masters-gap|'||v_event_year),5);
    v_event_year := v_event_year + v_gap;
  end loop;

  return jsonb_build_object(
    'changed',v_relocated,
    'city',v_city,
    'country',v_country,
    'name',coalesce(v_name,p_city||' Masters'),
    'last_change_year',v_last_change,
    'next_global_review_year',v_event_year,
    'surface_locked',p_surface,
    'calendar_month_locked',p_month,
    'license_key',p_competition_key
  );
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

  if v_year <= 2026 then return new; end if;

  if coalesce(new.source_note,'') not like 'Court Boss · calendrier auto-généré%'
     and coalesce(new.source_note,'') not like 'Court Boss dynamic calendar%' then
    return new;
  end if;

  if new.competition_key is null then return new; end if;

  select * into b
  from public.tournaments
  where extract(year from start_date)=2026
    and is_active=true
    and competition_key=new.competition_key
  order by id
  limit 1;

  if b.id is null then return new; end if;

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

  if b.category='Grand Chelem' then return new; end if;

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
      return new;
    end if;

    v_variant := public.masters1000_future_variant(
      v_year,b.competition_key,b.surface,extract(month from b.start_date)::integer,b.city,b.country
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
      new.source_note := 'Court Boss dynamic calendar · Masters 1000 licence moved from '
        ||b.city||' to '||new.city
        ||' · lineage '||b.competition_key
        ||' · since '||coalesce(v_variant->>'last_change_year','?');
      new.schedule_source_label := 'Court Boss long-term Masters 1000 evolution';
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

update public.tournaments
set city=city
where coalesce(official_season,extract(year from start_date)::int)>2026
  and is_active=true
  and (
    source_note like 'Court Boss · calendrier auto-généré%'
    or source_note like 'Court Boss dynamic calendar%'
  )
  and circuit='ATP';
