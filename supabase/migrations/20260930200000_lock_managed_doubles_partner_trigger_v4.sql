
revoke execute on function public.invalidate_managed_doubles_entries_on_partner_change()
  from public, anon, authenticated;
grant execute on function public.invalidate_managed_doubles_entries_on_partner_change()
  to service_role;
