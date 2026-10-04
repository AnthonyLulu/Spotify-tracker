alter table public.career_state
  alter column singles_rank drop not null,
  alter column doubles_rank drop not null;
