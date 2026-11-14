-- Notify other signed-in family members when a shopping item is checked
-- or removed. The actor is excluded from their own notification feed.
alter table public.family_notifications
  drop constraint if exists family_notifications_event_type_check;

alter table public.family_notifications
  add constraint family_notifications_event_type_check
  check (event_type in (
    'calendar_item_added',
    'calendar_item_updated',
    'shopping_item_added',
    'shopping_item_checked',
    'shopping_item_deleted',
    'member_joined'
  ));

create or replace function public.notify_shopping_item_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  target_list_id uuid;
  target_family_id uuid;
  target_title text;
  actor_name text;
  event_name text;
  notification_title text;
  notification_body text;
begin
  if tg_op = 'DELETE' then
    target_list_id := old.list_id;
    target_title := old.title;
    event_name := 'shopping_item_deleted';
    notification_title := 'Vara borttagen från inköpslistan';
    notification_body := 'En vara togs bort: ' || target_title || '.';
  else
    target_list_id := new.list_id;
    target_title := new.title;
    event_name := 'shopping_item_checked';
    notification_title := case when new.is_checked
      then 'Vara avbockad på inköpslistan'
      else 'Vara åter på inköpslistan'
    end;
    notification_body := case when new.is_checked
      then target_title || ' har markerats som handlad.'
      else target_title || ' har markerats som ej handlad.'
    end;
  end if;

  select family_id into target_family_id
  from public.shopping_lists
  where id = target_list_id;

  select display_name into actor_name
  from public.family_members
  where family_id = target_family_id and user_id = auth.uid()
  limit 1;
  actor_name := coalesce(actor_name, 'En familjemedlem');

  insert into public.family_notifications (
    family_id, recipient_user_id, actor_user_id, event_type, title, body
  )
  select target_family_id, member.user_id, auth.uid(), event_name,
         notification_title, actor_name || ': ' || notification_body
  from public.family_members member
  where member.family_id = target_family_id
    and member.user_id is not null
    and member.user_id <> auth.uid();

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists shopping_items_notify_checked on public.shopping_items;
create trigger shopping_items_notify_checked
after update of is_checked on public.shopping_items
for each row
when (old.is_checked is distinct from new.is_checked)
execute function public.notify_shopping_item_change();

drop trigger if exists shopping_items_notify_delete on public.shopping_items;
create trigger shopping_items_notify_delete
after delete on public.shopping_items
for each row execute function public.notify_shopping_item_change();
