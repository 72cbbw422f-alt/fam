-- Familjen integrity hardening.
-- Apply after 002_family_onboarding.sql.
-- A login account can belong to only one family. Child profiles remain
-- separate rows with user_id = NULL and do not require login accounts.
create unique index if not exists family_members_one_family_per_user
  on public.family_members(user_id)
  where user_id is not null;

-- Prevent assigning an event to a member profile from another family.
create or replace function public.validate_family_item_member()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.member_id is not null and not exists (
    select 1
    from public.family_members m
    where m.id = new.member_id
      and m.family_id = new.family_id
  ) then
    raise exception 'Selected member does not belong to this family';
  end if;
  return new;
end;
$$;

drop trigger if exists family_items_validate_member on public.family_items;
create trigger family_items_validate_member
before insert or update of family_id, member_id
on public.family_items
for each row execute function public.validate_family_item_member();

-- Keep updated_at reliable regardless of which client performs an update.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists family_items_set_updated_at on public.family_items;
create trigger family_items_set_updated_at
before update on public.family_items
for each row execute function public.set_updated_at();

-- Helpful indexes for the most common family-scoped screens.
create index if not exists family_items_family_kind_starts_idx
  on public.family_items(family_id, kind, starts_at);
create index if not exists family_members_family_display_name_idx
  on public.family_members(family_id, display_name);
