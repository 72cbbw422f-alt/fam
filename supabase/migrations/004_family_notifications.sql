-- Family activity notifications.
-- Apply after 003_integrity_hardening.sql.
create table if not exists public.family_notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('calendar_item_added','calendar_item_updated','shopping_item_added','member_joined')),
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists family_notifications_recipient_created_idx
  on public.family_notifications(recipient_user_id, created_at desc);
alter table public.family_notifications enable row level security;

create policy "users read their own family notifications"
on public.family_notifications for select to authenticated
using (recipient_user_id = auth.uid());

create or replace function public.notify_family_item_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  actor_name text;
  notification_title text;
  notification_body text;
  event_name text;
begin
  select display_name into actor_name
  from public.family_members
  where family_id = new.family_id and user_id = auth.uid()
  limit 1;
  actor_name := coalesce(actor_name, 'En familjemedlem');

  if tg_op = 'INSERT' then
    event_name := 'calendar_item_added';
    notification_title := 'Ny aktivitet i familjekalendern';
    notification_body := actor_name || ' lade till ' || new.title || '.';
  else
    event_name := 'calendar_item_updated';
    notification_title := 'Aktivitet uppdaterad';
    notification_body := actor_name || ' ändrade ' || new.title || '.';
  end if;

  insert into public.family_notifications (
    family_id, recipient_user_id, actor_user_id, event_type, title, body
  )
  select new.family_id, member.user_id, auth.uid(), event_name, notification_title, notification_body
  from public.family_members member
  where member.family_id = new.family_id
    and member.user_id is not null
    and member.user_id <> auth.uid();

  return new;
end;
$$;

drop trigger if exists family_items_notify_insert on public.family_items;
create trigger family_items_notify_insert
after insert on public.family_items
for each row execute function public.notify_family_item_change();

drop trigger if exists family_items_notify_update on public.family_items;
create trigger family_items_notify_update
after update on public.family_items
for each row
when (
  old.title is distinct from new.title
  or old.details is distinct from new.details
  or old.starts_at is distinct from new.starts_at
  or old.kind is distinct from new.kind
  or old.member_id is distinct from new.member_id
)
execute function public.notify_family_item_change();

create or replace function public.notify_shopping_item_added()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  target_family uuid;
  actor_name text;
begin
  select family_id into target_family
  from public.shopping_lists where id = new.list_id;

  select display_name into actor_name
  from public.family_members
  where family_id = target_family and user_id = auth.uid()
  limit 1;
  actor_name := coalesce(actor_name, 'En familjemedlem');

  insert into public.family_notifications (
    family_id, recipient_user_id, actor_user_id, event_type, title, body
  )
  select target_family, member.user_id, auth.uid(), 'shopping_item_added',
         'Ny vara på inköpslistan', actor_name || ' lade till ' || new.title || '.'
  from public.family_members member
  where member.family_id = target_family
    and member.user_id is not null
    and member.user_id <> auth.uid();

  return new;
end;
$$;

drop trigger if exists shopping_items_notify_insert on public.shopping_items;
create trigger shopping_items_notify_insert
after insert on public.shopping_items
for each row execute function public.notify_shopping_item_added();

create or replace function public.notify_family_member_joined()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.user_id is null then
    return new;
  end if;

  insert into public.family_notifications (
    family_id, recipient_user_id, actor_user_id, event_type, title, body
  )
  select new.family_id, member.user_id, new.user_id, 'member_joined',
         'Ny familjemedlem', new.display_name || ' har anslutit till familjen.'
  from public.family_members member
  where member.family_id = new.family_id
    and member.user_id is not null
    and member.user_id <> new.user_id;

  return new;
end;
$$;

drop trigger if exists family_members_notify_join on public.family_members;
create trigger family_members_notify_join
after insert on public.family_members
for each row execute function public.notify_family_member_joined();

create or replace function public.mark_family_notification_read(notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  update public.family_notifications
  set read_at = now()
  where id = notification_id
    and recipient_user_id = auth.uid()
    and read_at is null;
end;
$$;

revoke all on function public.mark_family_notification_read(uuid) from public;
grant execute on function public.mark_family_notification_read(uuid) to authenticated;


-- Enable Postgres Changes delivery for the in-app notification stream.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'family_notifications'
  ) then
    alter publication supabase_realtime add table public.family_notifications;
  end if;
end;
$$;
