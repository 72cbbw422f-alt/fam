-- Familjen onboarding and collaboration RPCs.
-- Apply after 001_initial_schema.sql.
create extension if not exists pgcrypto;

create or replace function public.create_family(family_name text, owner_display_name text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  new_family_id uuid;
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(family_name)) not between 1 and 80 then
    raise exception 'Family name must be 1-80 characters';
  end if;
  if length(trim(owner_display_name)) not between 1 and 80 then
    raise exception 'Display name must be 1-80 characters';
  end if;
  if exists (select 1 from public.family_members where user_id = current_user_id) then
    raise exception 'User already belongs to a family';
  end if;

  insert into public.families(name) values (trim(family_name))
  returning id into new_family_id;

  insert into public.family_members(family_id, display_name, role, user_id)
  values (new_family_id, trim(owner_display_name), 'owner', current_user_id);

  insert into public.shopping_lists(family_id, title)
  values (new_family_id, 'Inköpslista');

  return new_family_id;
end;
$$;

create or replace function public.create_family_invite(target_family uuid)
returns text
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  raw_code text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.family_members
    where family_id = target_family and user_id = auth.uid() and role = 'owner'
  ) then
    raise exception 'Only a family owner can create invitations';
  end if;

  raw_code := upper(encode(gen_random_bytes(5), 'hex'));
  insert into public.family_invites(family_id, code_hash, expires_at, created_by)
  values (
    target_family,
    encode(digest(raw_code, 'sha256'), 'hex'),
    now() + interval '48 hours',
    auth.uid()
  );

  return raw_code;
end;
$$;

create or replace function public.accept_family_invite(invite_code text, member_display_name text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  matched_invite public.family_invites%rowtype;
  new_member_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(member_display_name)) not between 1 and 80 then
    raise exception 'Display name must be 1-80 characters';
  end if;
  if exists (select 1 from public.family_members where user_id = current_user_id) then
    raise exception 'User already belongs to a family';
  end if;

  select * into matched_invite
  from public.family_invites
  where code_hash = encode(digest(upper(trim(invite_code)), 'sha256'), 'hex')
    and accepted_at is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'Invitation code is invalid or expired';
  end if;

  insert into public.family_members(family_id, display_name, role, user_id)
  values (matched_invite.family_id, trim(member_display_name), 'member', current_user_id)
  returning id into new_member_id;

  update public.family_invites set accepted_at = now()
  where id = matched_invite.id;

  return new_member_id;
end;
$$;

revoke all on function public.create_family(text, text) from public;
revoke all on function public.create_family_invite(uuid) from public;
revoke all on function public.accept_family_invite(text, text) from public;
grant execute on function public.create_family(text, text) to authenticated;
grant execute on function public.create_family_invite(uuid) to authenticated;
grant execute on function public.accept_family_invite(text, text) to authenticated;

-- Members can manage list content only inside their own family.
create policy "members create shopping lists"
on public.shopping_lists for insert to authenticated
with check (public.is_family_member(family_id));

create policy "members update shopping lists"
on public.shopping_lists for update to authenticated
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

create policy "members delete shopping items"
on public.shopping_items for delete to authenticated
using (
  exists (
    select 1 from public.shopping_lists l
    where l.id = list_id and public.is_family_member(l.family_id)
  )
);

create policy "members delete family items"
on public.family_items for delete to authenticated
using (public.is_family_member(family_id));
