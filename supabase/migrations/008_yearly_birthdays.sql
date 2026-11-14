-- Yearly recurrence is opt-in and applies to birthday entries only.
alter table public.family_items
  add column if not exists is_recurring_yearly boolean not null default false;

create index if not exists family_items_recurring_birthdays_idx
  on public.family_items(family_id, kind)
  where kind = 'birthday' and is_recurring_yearly = true;
