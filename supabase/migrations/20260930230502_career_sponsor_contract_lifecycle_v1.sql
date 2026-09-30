alter table public.sponsor_offers
  add column if not exists accepted_on date,
  add column if not exists starts_on date,
  add column if not exists ends_on date,
  add column if not exists weeks_paid integer not null default 0,
  add column if not exists ended_on date;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='sponsor_offers_weeks_paid_nonnegative'
      and conrelid='public.sponsor_offers'::regclass
  ) then
    alter table public.sponsor_offers
      add constraint sponsor_offers_weeks_paid_nonnegative check (weeks_paid >= 0);
  end if;
end $$;

with c as (
  select coalesce(career_date,date '2025-12-01') as d
  from public.career_state
  where id='demo'
)
update public.sponsor_offers s
set accepted_on=coalesce(s.accepted_on,c.d),
    starts_on=coalesce(s.starts_on,c.d),
    ends_on=coalesce(s.ends_on,c.d + greatest(1,s.duration_weeks)*7),
    weeks_paid=greatest(0,coalesce(s.weeks_paid,0))
from c
where s.status='accepted'
  and (s.accepted_on is null or s.starts_on is null or s.ends_on is null);

create or replace function public.process_sponsor_week(
  p_date date,
  p_week integer
)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  r record;
  v_tx_id bigint;
  v_paid numeric:=0;
  v_paid_contracts int:=0;
  v_expired int:=0;
  v_active int:=0;
  v_new_weeks int;
  v_start date;
  v_end date;
begin
  if p_date is null then
    raise exception 'p_date is required';
  end if;

  for r in
    select *
    from public.sponsor_offers
    where status='accepted'
    order by id
    for update
  loop
    v_start:=coalesce(r.starts_on,r.accepted_on,p_date);
    v_end:=coalesce(r.ends_on,v_start + greatest(1,r.duration_weeks)*7);

    if r.starts_on is null or r.accepted_on is null or r.ends_on is null then
      update public.sponsor_offers
      set accepted_on=coalesce(accepted_on,v_start),
          starts_on=coalesce(starts_on,v_start),
          ends_on=coalesce(ends_on,v_end)
      where id=r.id;
    end if;

    if p_date < v_start then
      v_active:=v_active+1;
      continue;
    end if;

    if p_date > v_end or coalesce(r.weeks_paid,0) >= greatest(1,r.duration_weeks) then
      update public.sponsor_offers
      set status='expired',
          ended_on=coalesce(ended_on,least(p_date,v_end))
      where id=r.id and status='accepted';

      if found then
        v_expired:=v_expired+1;
        insert into public.inbox_items(
          kind,title,body,action_route,game_date,priority,is_read,
          decision_status,related_entity_type,related_entity_id
        )
        values(
          'commercial',
          'Contrat sponsor terminé · '||r.brand,
          'Le contrat avec '||r.brand||' est arrivé à son terme après '||
            greatest(1,r.duration_weeks)||' semaines.',
          'finance',p_date,'normal',false,'resolved','sponsor_contract',r.id
        );
      end if;
      continue;
    end if;

    v_tx_id:=null;
    insert into public.finance_transactions(
      transaction_key,game_date,week,category,amount,currency,
      source_type,source_id,description,metadata
    )
    values(
      'sponsor:'||r.id||':week:'||p_date::text,
      p_date,p_week,'sponsor_income',r.weekly_value,'EUR',
      'sponsor_offer',r.id,
      'Revenu sponsor · '||r.brand,
      jsonb_build_object(
        'brand',r.brand,
        'contract_week',coalesce(r.weeks_paid,0)+1,
        'duration_weeks',greatest(1,r.duration_weeks),
        'starts_on',v_start,
        'ends_on',v_end
      )
    )
    on conflict(transaction_key) do nothing
    returning id into v_tx_id;

    if v_tx_id is not null then
      v_new_weeks:=coalesce(r.weeks_paid,0)+1;
      v_paid:=v_paid+coalesce(r.weekly_value,0);
      v_paid_contracts:=v_paid_contracts+1;

      update public.sponsor_offers
      set weeks_paid=v_new_weeks,
          starts_on=v_start,
          ends_on=v_end
      where id=r.id;

      update public.finances
      set sponsor_income=coalesce(sponsor_income,0)+coalesce(r.weekly_value,0)
      where id='demo';

      if v_new_weeks >= greatest(1,r.duration_weeks) or p_date >= v_end then
        update public.sponsor_offers
        set status='expired',ended_on=p_date
        where id=r.id and status='accepted';

        if found then
          v_expired:=v_expired+1;
          insert into public.inbox_items(
            kind,title,body,action_route,game_date,priority,is_read,
            decision_status,related_entity_type,related_entity_id
          )
          values(
            'commercial',
            'Contrat sponsor terminé · '||r.brand,
            'Le dernier versement de '||r.brand||' a été reçu. Le contrat de '||
              greatest(1,r.duration_weeks)||' semaines est terminé.',
            'finance',p_date,'normal',false,'resolved','sponsor_contract',r.id
          );
        end if;
      else
        v_active:=v_active+1;
      end if;
    else
      if coalesce(r.weeks_paid,0) < greatest(1,r.duration_weeks) and p_date <= v_end then
        v_active:=v_active+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'model','CB-SPONSOR-LIFECYCLE-v1',
    'date',p_date,
    'week',p_week,
    'total_paid',v_paid,
    'paid_contracts',v_paid_contracts,
    'active_contracts',v_active,
    'expired_contracts',v_expired
  );
end;
$function$;
