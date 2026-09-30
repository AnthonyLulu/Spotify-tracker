
alter table public.managed_doubles_entries
  drop constraint if exists managed_doubles_entries_status_check;

alter table public.managed_doubles_entries
  add constraint managed_doubles_entries_status_check
  check(status in ('entered','withdrawn','played'));

comment on column public.managed_doubles_entries.status is
  'entered = active schedule, withdrawn = cancelled, played = completed tournament.';
