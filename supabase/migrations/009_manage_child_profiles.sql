-- Allow authenticated family members to rename or remove child profiles
-- that belong to their own family. Adult/login profiles are never mutable here.

create or replace function public.update_family_child_profile(
  target_member_id uuid,
  new_display_name text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  current_family_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(new_display_name)) not between 1 and 80 then
    raise exception 'Child name must be 1-80 characters';
  end if;

  select family_id into current_family_id
  from public.family_members
  where user_id = auth.uid()
  limit 1;

  if current_family_id is null then
    raise exception 'Family membership required';
  end if;

  update public.family_members
  set display_name = trim(new_display_name)
  where id = target_member_id
    and family_id = current_family_id
    and role = 'child'
    and user_id is null;

  if not found then
    raise exception 'Child profile not found in your family';
  end if;
end;
$$;

create or replace function public.delete_family_child_profile(target_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  current_family_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select family_id into current_family_id
  from public.family_members
  where user_id = auth.uid()
  limit 1;

  if current_family_id is null then
    raise exception 'Family membership required';
  end if;

  delete from public.family_members
  where id = target_member_id
    and family_id = current_family_id
    and role = 'child'
    and user_id is null;

  if not found then
    raise exception 'Child profile not found in your family';
  end if;
end;
$$;

revoke all on function public.update_family_child_profile(uuid, text) from public;
revoke all on function public.delete_family_child_profile(uuid) from public;
grant execute on function public.update_family_child_profile(uuid, text) to authenticated;
grant execute on function public.delete_family_child_profile(uuid) to authenticated;
