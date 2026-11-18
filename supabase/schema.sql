-- Chia Tiền Nhóm: cấu trúc dữ liệu cho Supabase (chạy một lần trong SQL Editor)
-- Ý tưởng: mỗi "nhóm" có nhiều thành viên đăng nhập; mỗi chuyến đi thuộc một nhóm.
-- Chỉ thành viên của nhóm mới đọc/ghi được chuyến của nhóm đó (bảo vệ bằng Row Level Security).

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique default substr(replace(gen_random_uuid()::text,'-',''),1,10),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'editor' check (role in ('owner','editor','viewer')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.trips (
  id text primary key,                       -- id chuyến do ứng dụng tạo
  group_id uuid not null references public.groups(id) on delete cascade,
  data jsonb not null,                       -- toàn bộ dữ liệu một chuyến
  deleted boolean not null default false,    -- xoá mềm để máy khác biết mà xoá theo
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid() references auth.users(id)
);
create index if not exists trips_group_idx on public.trips(group_id, updated_at desc);

-- Hàm kiểm tra thành viên (security definer để tránh vòng lặp luật truy cập)
create or replace function public.is_member(gid uuid, need_edit boolean default false)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = gid and m.user_id = auth.uid()
      and (not need_edit or m.role in ('owner','editor'))
  );
$$;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.trips enable row level security;

-- groups: chỉ thấy nhóm mình thuộc; ai đăng nhập cũng tạo được nhóm; chỉ owner sửa/xoá
create policy groups_select on public.groups for select to authenticated using (public.is_member(id));
create policy groups_insert on public.groups for insert to authenticated with check (created_by = auth.uid());
create policy groups_update on public.groups for update to authenticated
  using (exists (select 1 from public.group_members m where m.group_id = id and m.user_id = auth.uid() and m.role = 'owner'));
create policy groups_delete on public.groups for delete to authenticated
  using (exists (select 1 from public.group_members m where m.group_id = id and m.user_id = auth.uid() and m.role = 'owner'));

-- group_members: thấy danh sách thành viên cùng nhóm; chỉ owner thêm/xoá người khác; ai cũng tự rời nhóm được
create policy gm_select on public.group_members for select to authenticated using (public.is_member(group_id));
create policy gm_delete on public.group_members for delete to authenticated
  using (user_id = auth.uid()
     or exists (select 1 from public.group_members m where m.group_id = group_members.group_id and m.user_id = auth.uid() and m.role = 'owner'));
-- (không có policy insert/update: việc vào nhóm đi qua hàm create_group / join_group bên dưới)

-- trips: thành viên nhóm đọc; owner/editor ghi
create policy trips_select on public.trips for select to authenticated using (public.is_member(group_id));
create policy trips_insert on public.trips for insert to authenticated with check (public.is_member(group_id, true));
create policy trips_update on public.trips for update to authenticated
  using (public.is_member(group_id, true)) with check (public.is_member(group_id, true));
create policy trips_delete on public.trips for delete to authenticated using (public.is_member(group_id, true));

-- Tạo nhóm mới và tự thành owner
create or replace function public.create_group(gname text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.groups(name, created_by) values (gname, auth.uid()) returning * into g;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'owner');
  return g;
end $$;

-- Vào nhóm bằng mã mời (vai trò editor)
create or replace function public.join_group(code text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into g from public.groups where invite_code = code;
  if not found then raise exception 'invalid code'; end if;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'editor')
    on conflict do nothing;
  return g;
end $$;

revoke all on function public.create_group(text) from public, anon;
revoke all on function public.join_group(text) from public, anon;
grant execute on function public.create_group(text) to authenticated;
grant execute on function public.join_group(text) to authenticated;

-- Cập nhật updated_at tự động
create or replace function public.touch_trip() returns trigger language plpgsql as $$
begin new.updated_at = now(); new.updated_by = auth.uid(); return new; end $$;
drop trigger if exists trips_touch on public.trips;
create trigger trips_touch before insert or update on public.trips for each row execute function public.touch_trip();

-- Bật cập nhật tức thời (realtime) cho bảng chuyến
alter publication supabase_realtime add table public.trips;
