-- Supabase schema for「海事法規、規定辨識和執行追蹤系統」
-- 使用方式：Supabase Dashboard → SQL Editor → 貼上整份執行。
-- 執行前請把 BOOTSTRAP_OWNER_EMAIL 改成第一位管理員 email。

create extension if not exists pgcrypto;

create table if not exists public.app_members (
  email text primary key,
  role text not null check (role in ('owner', 'admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 既有專案若曾使用 editor/viewer，重新執行本 schema 會收斂為 owner/admin。
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'app_members_role_check'
      and conrelid = 'public.app_members'::regclass
  ) then
    alter table public.app_members drop constraint app_members_role_check;
  end if;
  update public.app_members
    set role = 'admin', active = false
    where role not in ('owner', 'admin');
  alter table public.app_members
    add constraint app_members_role_check check (role in ('owner', 'admin'));
end $$;

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

-- Owner 是最高權限，且同一時間只能有一位啟用中的 Owner。
create unique index if not exists app_members_single_active_owner_idx
on public.app_members ((role))
where role = 'owner' and active = true;

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
using (public.app_current_role() = 'owner')
with check (public.app_current_role() = 'owner');

drop policy if exists "active_members_read_state" on public.app_state;
create policy "active_members_read_state"
on public.app_state
for select
using (
  public.app_current_role() in ('admin', 'owner')
  or key in ('tasks', 'candidate_items', 'message_sources', 'pdf_library', 'operator_roster', 'personnel_roles', 'site_access_password')
);

drop policy if exists "editors_write_state" on public.app_state;
drop policy if exists "admins_insert_state" on public.app_state;
create policy "admins_insert_state"
on public.app_state
for insert
with check (public.app_current_role() in ('admin', 'owner'));

drop policy if exists "editors_update_state" on public.app_state;
drop policy if exists "admins_update_state" on public.app_state;
create policy "admins_update_state"
on public.app_state
for update
using (public.app_current_role() in ('admin', 'owner'))
with check (public.app_current_role() in ('admin', 'owner'));

-- 操作員不登入 Supabase；前端會要求其從預設名單選擇「部門/姓名」，
-- 然後以 operator:部門/姓名 寫入 audit_logs。管理員也可由前端人員名單辨識。
-- 為支援此模式，匿名訪客只允許更新 tasks；備選項目/消息源/PDF資料仍需 owner/admin 維護。
drop policy if exists "operators_insert_tasks_state" on public.app_state;
create policy "operators_insert_tasks_state"
on public.app_state
for insert
with check (auth.role() = 'anon' and key = 'tasks');

drop policy if exists "operators_update_tasks_state" on public.app_state;
create policy "operators_update_tasks_state"
on public.app_state
for update
using (auth.role() = 'anon' and key = 'tasks')
with check (auth.role() = 'anon' and key = 'tasks');

drop policy if exists "active_members_read_logs" on public.audit_logs;
create policy "active_members_read_logs"
on public.audit_logs
for select
using (public.app_current_role() in ('admin', 'owner'));

drop policy if exists "editors_insert_logs" on public.audit_logs;
drop policy if exists "admins_insert_logs" on public.audit_logs;
create policy "admins_insert_logs"
on public.audit_logs
for insert
with check (public.app_current_role() in ('admin', 'owner'));

drop policy if exists "operators_insert_logs" on public.audit_logs;
create policy "operators_insert_logs"
on public.audit_logs
for insert
with check (auth.role() = 'anon' and (actor_email like 'operator:%' or actor_email like 'admin:%'));

-- Bootstrap：唯一 Owner。請改成你的 email 後執行。
insert into public.app_members (email, role, active)
values (lower('BOOTSTRAP_OWNER_EMAIL'), 'owner', true)
on conflict (email) do update set role = excluded.role, active = true;
