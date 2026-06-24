-- Supabase schema for「海事法規、規定辨識和執行追蹤系統」
-- 使用方式：Supabase Dashboard → SQL Editor → 貼上整份執行。
-- 執行前請把 BOOTSTRAP_OWNER_EMAIL 改成第一位管理員 email。

create extension if not exists pgcrypto;

create table if not exists public.app_members (
  email text primary key,
  role text not null check (role in ('owner', 'admin', 'editor', 'viewer')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_state (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  actor_id uuid,
  actor_email text,
  action text not null,
  entity_type text not null,
  entity_id text,
  summary text,
  old_data jsonb,
  new_data jsonb
);

create index if not exists audit_logs_created_at_idx on public.audit_logs (created_at desc);
create index if not exists audit_logs_actor_email_idx on public.audit_logs (lower(actor_email));
create index if not exists audit_logs_entity_idx on public.audit_logs (entity_type, entity_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_members_touch_updated_at on public.app_members;
create trigger app_members_touch_updated_at
before update on public.app_members
for each row execute function public.touch_updated_at();

drop trigger if exists app_state_touch_updated_at on public.app_state;
create trigger app_state_touch_updated_at
before update on public.app_state
for each row execute function public.touch_updated_at();

create or replace function public.app_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

create or replace function public.app_current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select m.role
  from public.app_members m
  where m.email = public.app_current_email()
    and m.active = true
  limit 1;
$$;

grant execute on function public.app_current_email() to anon, authenticated;
grant execute on function public.app_current_role() to anon, authenticated;

alter table public.app_members enable row level security;
alter table public.app_state enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "members_read_self_or_admin" on public.app_members;
create policy "members_read_self_or_admin"
on public.app_members
for select
using (
  email = public.app_current_email()
  or public.app_current_role() in ('owner', 'admin')
);

drop policy if exists "admins_manage_members" on public.app_members;
create policy "admins_manage_members"
on public.app_members
for all
using (public.app_current_role() in ('owner', 'admin'))
with check (public.app_current_role() in ('owner', 'admin'));

drop policy if exists "active_members_read_state" on public.app_state;
create policy "active_members_read_state"
on public.app_state
for select
using (public.app_current_role() in ('viewer', 'editor', 'admin', 'owner'));

drop policy if exists "editors_write_state" on public.app_state;
create policy "editors_write_state"
on public.app_state
for insert
with check (public.app_current_role() in ('editor', 'admin', 'owner'));

drop policy if exists "editors_update_state" on public.app_state;
create policy "editors_update_state"
on public.app_state
for update
using (public.app_current_role() in ('editor', 'admin', 'owner'))
with check (public.app_current_role() in ('editor', 'admin', 'owner'));

drop policy if exists "active_members_read_logs" on public.audit_logs;
create policy "active_members_read_logs"
on public.audit_logs
for select
using (public.app_current_role() in ('viewer', 'editor', 'admin', 'owner'));

drop policy if exists "editors_insert_logs" on public.audit_logs;
create policy "editors_insert_logs"
on public.audit_logs
for insert
with check (public.app_current_role() in ('editor', 'admin', 'owner'));

-- Bootstrap：第一位管理員。請改成你的 email 後執行。
insert into public.app_members (email, role, active)
values (lower('BOOTSTRAP_OWNER_EMAIL'), 'owner', true)
on conflict (email) do update set role = excluded.role, active = true;
