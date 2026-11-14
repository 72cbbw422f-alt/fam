-- Familjen initial schema. Apply in the Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  role text not null default 'member' check (role in ('owner','member','child')),
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists family_members_family_user_unique
  on public.family_members(family_id, user_id) where user_id is not null;

create table if not exists public.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.family_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  details text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  kind text not null check (kind in ('appointment','birthday','event','health_visit')),
  member_id uuid references public.family_members(id) on delete set null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create table if not exists public.shopping_lists (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null default 'Inköpslista',
  created_at timestamptz not null default now()
);

create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.shopping_lists(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  is_checked boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists family_items_family_starts_idx
  on public.family_items(family_id, starts_at);
create index if not exists shopping_lists_family_id_idx
  on public.shopping_lists(family_id);
create index if not exists shopping_items_list_id_idx
  on public.shopping_items(list_id);

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invites enable row level security;
alter table public.family_items enable row level security;
alter table public.shopping_lists enable row level security;
alter table public.shopping_items enable row level security;

create or replace function public.is_family_member(target_family uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.family_members
    where family_id = target_family and user_id = auth.uid()
  );
$$;

revoke all on function public.is_family_member(uuid) from public;
grant execute on function public.is_family_member(uuid) to authenticated;

create policy "family members read family"
on public.families for select to authenticated
using (public.is_family_member(id));

create policy "family members read member profiles"
on public.family_members for select to authenticated
using (public.is_family_member(family_id));

create policy "family members read items"
on public.family_items for select to authenticated
using (public.is_family_member(family_id));

create policy "family members create items"
on public.family_items for insert to authenticated
with check (public.is_family_member(family_id) and created_by = auth.uid());

create policy "family members update items"
on public.family_items for update to authenticated
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

create policy "family members read shopping lists"
on public.shopping_lists for select to authenticated
using (public.is_family_member(family_id));

create policy "family members read shopping items"
on public.shopping_items for select to authenticated
using (
  exists (
    select 1 from public.shopping_lists l
    where l.id = list_id and public.is_family_member(l.family_id)
  )
);

create policy "family members create shopping items"
on public.shopping_items for insert to authenticated
with check (
  created_by = auth.uid() and
  exists (
    select 1 from public.shopping_lists l
    where l.id = list_id and public.is_family_member(l.family_id)
  )
);

create policy "family members update shopping items"
on public.shopping_items for update to authenticated
using (
  exists (
    select 1 from public.shopping_lists l
    where l.id = list_id and public.is_family_member(l.family_id)
  )
)
with check (
  exists (
    select 1 from public.shopping_lists l
    where l.id = list_id and public.is_family_member(l.family_id)
  )
);

-- Deliberately no direct client policy for invite rows.
-- Secure invite creation/acceptance RPCs and owner-only family creation
-- must be added and audited before enabling family onboarding.
