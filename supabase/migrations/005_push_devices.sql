-- Device-token registry for future APNs push delivery.
-- This migration is safe to apply before Apple Developer credentials exist.
create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_token text not null unique,
  platform text not null default 'ios' check (platform in ('ios')),
  environment text not null check (environment in ('sandbox','production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_devices_user_id_idx
  on public.push_devices(user_id);

alter table public.push_devices enable row level security;

create policy "users read their own push devices"
on public.push_devices for select to authenticated
using (user_id = auth.uid());

create policy "users register their own push devices"
on public.push_devices for insert to authenticated
with check (user_id = auth.uid());

create policy "users update their own push devices"
on public.push_devices for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "users remove their own push devices"
on public.push_devices for delete to authenticated
using (user_id = auth.uid());

-- No client-side sender credentials or APNs secrets are stored in this table.
-- A trusted Edge Function will use these records after Apple setup is complete.

-- Enable filtered DELETE events and publish shopping-list changes for Realtime.
-- With RLS enabled, Supabase only sends the primary key from DELETE records.
alter table public.shopping_items replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shopping_items'
  ) then
    alter publication supabase_realtime add table public.shopping_items;
  end if;
end;
$$;

-- Publish family calendar changes for in-app Realtime updates.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'family_items'
  ) then
    alter publication supabase_realtime add table public.family_items;
  end if;
end;
$$;
