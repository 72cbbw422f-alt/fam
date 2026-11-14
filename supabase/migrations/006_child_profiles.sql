-- Allow authenticated family members to create child profiles
-- without creating login accounts for children.
create or replace function public.create_family_child_profile(child_display_name text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  current_family_id uuid;
  new_member_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(child_display_name)) not between 1 and 80 then
    raise exception 'Child name must be 1-80 characters';
  end if;

  select family_id into current_family_id
  from public.family_members
  where user_id = auth.uid()
  limit 1;

  if current_family_id is null then
    raise exception 'Family membership required';
  end if;

  insert into public.family_members(family_id, display_name, role, user_id)
  values (current_family_id, trim(child_display_name), 'child', null)
  returning id into new_member_id;

  return new_member_id;
end;
$$;

revoke all on function public.create_family_child_profile(text) from public;
grant execute on function public.create_family_child_profile(text) to authenticated;
