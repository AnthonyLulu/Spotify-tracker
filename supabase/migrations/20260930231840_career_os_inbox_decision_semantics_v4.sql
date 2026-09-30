alter table public.inbox_items
  alter column decision_status set default 'info'::text;

update public.inbox_items
set decision_status='info'
where decision_status='pending'
  and (
    action_type is null
    or action_type='open_route'
  )
  and secondary_action_type is null;
