-- 018: Thùng rác nhóm (chạy sau 017). Xoá nhóm KHÔNG xoá liền: nhóm vào thùng rác, các chuyến của nhóm ẩn theo.
--   Chỉ THÊM cột (groups.deleted_at / deleted_by, trips.by_group) và sửa hàm; không đổi dữ liệu đang có.
--   delete_group(gid)        : quản trị viên -> nhóm vào thùng rác (ghi nhật ký 'trash')
--   admin_group_trash()      : danh sách nhóm trong thùng rác
--   restore_group(gid)       : khôi phục nhóm + các chuyến bị ẩn theo nhóm (chuyến đã ở thùng rác chuyến từ trước giữ nguyên)
--   purge_group(gid)         : xoá hẳn nhóm đang ở thùng rác (không khôi phục được)
-- Quay lại: chạy lại các hàm bản trước (delete_group bản 004, can_see_group, admin_groups, admin_groups_overview, enter_code,
--   restore_trip, trg_trips, trg_groups), khôi phục mọi nhóm trong thùng rác, rồi drop các cột mới và 3 hàm mới.

alter table public.groups add column if not exists deleted_at timestamptz;
alter table public.groups add column if not exists deleted_by text;
alter table public.trips  add column if not exists by_group boolean not null default false;

-- nhóm trong thùng rác: không ai thấy (kể cả quản trị viên ở danh sách thường)
create or replace function public.can_see_group(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.groups g where g.id = gid and g.deleted_at is null)
    and (public.is_admin() or public.is_organizer(gid)
      or exists (select 1 from public.trips t where t.group_id = gid and not t.deleted and public.can_view_trip(t.id))) $$;

create or replace function public.delete_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.groups where id = gid and deleted_at is null) then raise exception 'not_found'; end if;
  update public.trips set deleted = true, by_group = true, deleted_at = now(), deleted_by = auth.uid(), rev = rev + 1
    where group_id = gid and not deleted;
  update public.groups set deleted_at = now(), deleted_by = public.my_email() where id = gid;
end $$;

create or replace function public.restore_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.groups where id = gid and deleted_at is not null) then raise exception 'not_found'; end if;
  update public.groups set deleted_at = null, deleted_by = null where id = gid;
  update public.trips set deleted = false, by_group = false, deleted_at = null, deleted_by = null, rev = rev + 1
    where group_id = gid and by_group;
end $$;

create or replace function public.purge_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if not exists (select 1 from public.groups where id = gid and deleted_at is not null) then raise exception 'not_in_trash'; end if;
  delete from public.groups where id = gid;
end $$;

create or replace function public.admin_group_trash()
returns table(id uuid, name text, created_at timestamptz, deleted_at timestamptz, deleted_by text, trips bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select g.id, g.name, g.created_at, g.deleted_at, g.deleted_by,
    (select count(*) from public.trips t where t.group_id = g.id and t.by_group)
    from public.groups g where g.deleted_at is not null order by g.deleted_at desc;
end $$;

-- danh sách quản trị: bỏ nhóm trong thùng rác
create or replace function public.admin_groups()
returns table(id uuid, name text, created_at timestamptz, creator_email text, join_enabled boolean, members bigint, trips bigint, last_activity timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select g.id, g.name, g.created_at, u.email::text, g.join_enabled,
      (select count(*) from public.group_members m where m.group_id = g.id),
      (select count(*) from public.trips t where t.group_id = g.id and not t.deleted),
      (select max(t.updated_at) from public.trips t where t.group_id = g.id)
    from public.groups g left join auth.users u on u.id = g.created_by where g.deleted_at is null order by g.created_at desc;
end $$;

create or replace function public.admin_groups_overview()
returns table(id uuid, name text, created_at timestamptz, creator_email text, trips jsonb, organizers jsonb)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  select g.id, g.name, g.created_at, cu.email::text,
    coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', coalesce(nullif(t.data ->> 'name', ''), '(chưa đặt tên)'),
        'closed', t.closed_at is not null, 'hidden', t.hide_in_group,
        'leaders', coalesce((select jsonb_agg(r.email order by r.email) from public.trip_roles r where r.trip_id = t.id and r.role = 'leader'), '[]'::jsonb),
        'helpers', (select count(*) from public.trip_roles r where r.trip_id = t.id and r.role = 'helper'))
        order by t.updated_at desc)
      from public.trips t where t.group_id = g.id and not t.deleted), '[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object(
        'email', o.email, 'added_at', o.added_at, 'added_by', o.added_by,
        'signed_up', u.id is not null, 'last_sign_in_at', u.last_sign_in_at,
        'last_active', (select max(coalesce(s.refreshed_at, s.updated_at, s.created_at)) from auth.sessions s where s.user_id = u.id),
        'sessions', (select count(*) from auth.sessions s where s.user_id = u.id and (s.not_after is null or s.not_after > now())),
        'devices', coalesce((select jsonb_agg(distinct case
            when s.user_agent ilike '%ipad%' then 'iPad' when s.user_agent ilike '%iphone%' then 'iPhone'
            when s.user_agent ilike '%android%' then 'Android' when s.user_agent ilike '%windows%' then 'Windows'
            when s.user_agent ilike '%mac os%' or s.user_agent ilike '%macintosh%' then 'Mac / iPad' else 'Khác' end)
          from auth.sessions s where s.user_id = u.id and (s.not_after is null or s.not_after > now())), '[]'::jsonb))
        order by o.added_at)
      from public.group_organizers o
      left join lateral (select x.id, x.last_sign_in_at from auth.users x where lower(x.email) = o.email and not coalesce(x.is_anonymous, false) limit 1) u on true
      where o.group_id = g.id), '[]'::jsonb)
  from public.groups g left join auth.users cu on cu.id = g.created_by
  where g.deleted_at is null
  order by g.created_at desc;
end $$;

-- mã nhóm của nhóm trong thùng rác: báo "không còn"
create or replace function public.enter_code(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code,''), '[^A-Za-z0-9]', '', 'g')); tc record; gc record; nm text; gn text;
begin
  if auth.uid() is null then raise exception 'need_session'; end if;
  if (select count(*) from public.code_attempts where user_id = auth.uid() and not ok and at > now() - interval '10 minutes') >= 8
     or (select count(*) from public.code_attempts where not ok and at > now() - interval '10 minutes') >= 300 then
    return jsonb_build_object('error', 'rate_limited');
  end if;
  if c ~ '^(CH|NH)' then c := substr(c, 1, 2) || '-' || substr(c, 3); end if;
  select * into tc from public.trip_codes where code = c;
  if found then
    insert into public.code_attempts(user_id, ok) values (auth.uid(), true);
    if not tc.enabled then return jsonb_build_object('error', 'locked'); end if;
    if tc.expires_at <= now() then return jsonb_build_object('error', 'expired'); end if;
    select t.data ->> 'name', g.name into nm, gn from public.trips t join public.groups g on g.id = t.group_id where t.id = tc.trip_id and not t.deleted and g.deleted_at is null;
    if nm is null then return jsonb_build_object('error', 'gone'); end if;
    insert into public.code_access(user_id, kind, target, ver) values (auth.uid(), 'trip', tc.trip_id, tc.ver)
      on conflict (user_id, kind, target) do update set ver = excluded.ver, at = now();
    return jsonb_build_object('kind', 'trip', 'trip_id', tc.trip_id, 'name', nm, 'group_name', gn,
      'group_id', (select group_id from public.trips where id = tc.trip_id));
  end if;
  select * into gc from public.group_view_codes where code = c;
  if found then
    insert into public.code_attempts(user_id, ok) values (auth.uid(), true);
    if exists (select 1 from public.groups where id = gc.group_id and deleted_at is not null) then return jsonb_build_object('error', 'gone'); end if;
    if not gc.enabled then return jsonb_build_object('error', 'locked'); end if;
    if gc.expires_at <= now() then return jsonb_build_object('error', 'expired'); end if;
    insert into public.code_access(user_id, kind, target, ver) values (auth.uid(), 'group', gc.group_id::text, gc.ver)
      on conflict (user_id, kind, target) do update set ver = excluded.ver, at = now();
    return jsonb_build_object('kind', 'group', 'group_id', gc.group_id, 'name', (select name from public.groups where id = gc.group_id));
  end if;
  insert into public.code_attempts(user_id, ok) values (auth.uid(), false);
  delete from public.code_attempts where at < now() - interval '1 day';
  return jsonb_build_object('error', 'not_found');
end $$;

-- chuyến bị ẩn theo nhóm: không khôi phục lẻ được (khôi phục cả nhóm)
create or replace function public.restore_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  if exists (select 1 from public.groups where id = gid and deleted_at is not null) then raise exception 'group_in_trash'; end if;
  update public.trips set deleted = false, by_group = false, deleted_at = null, deleted_by = null, rev = rev + 1 where id = tid and group_id = gid;
end $$;

-- nhật ký: chuyến ẩn/hiện theo nhóm không ghi từng chuyến (đã có 1 dòng của nhóm)
create or replace function public.trg_trips() returns trigger
language plpgsql security definer set search_path = public as $$
declare gn text; nm text; gid uuid;
begin
  gid := coalesce(new.group_id, old.group_id);
  select name into gn from public.groups where id = gid;
  if gn is null then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    perform public.log_event('create','trip',gid,gn,new.id,new.data ->> 'name',null);
  elsif tg_op = 'UPDATE' then
    nm := new.data ->> 'name';
    if new.deleted is distinct from old.deleted then
      if not (new.by_group or old.by_group) then
        perform public.log_event(case when new.deleted then 'delete' else 'restore' end,'trip',gid,gn,new.id,nm,null); end if;
    elsif new.closed_at is distinct from old.closed_at then
      perform public.log_event(case when new.closed_at is null then 'reopen' else 'close' end,'trip',gid,gn,new.id,nm,null);
    elsif nm is distinct from (old.data ->> 'name') then
      perform public.log_event('rename','trip',gid,gn,new.id,nm,jsonb_build_object('from',old.data ->> 'name','to',nm));
    end if;
  elsif tg_op = 'DELETE' then
    perform public.log_event('delete','trip',gid,gn,old.id,old.data ->> 'name',jsonb_build_object('purge',true));
    return old;
  end if;
  return new;
end $$;

create or replace function public.trg_groups() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_event('create','group',new.id,new.name,new.id::text,new.name,null);
  elsif tg_op = 'UPDATE' then
    if new.name is distinct from old.name then
      perform public.log_event('rename','group',new.id,new.name,new.id::text,new.name,jsonb_build_object('from',old.name,'to',new.name)); end if;
    if new.join_enabled is distinct from old.join_enabled then
      perform public.log_event(case when new.join_enabled then 'join_on' else 'join_off' end,'group',new.id,new.name,new.id::text,new.name,null); end if;
    if new.deleted_at is distinct from old.deleted_at then
      perform public.log_event(case when new.deleted_at is null then 'restore' else 'trash' end,'group',new.id,new.name,new.id::text,new.name,
        jsonb_build_object('trips',(select count(*) from public.trips where group_id=new.id and by_group))); end if;
  elsif tg_op = 'DELETE' then
    perform public.log_event('delete','group',old.id,old.name,old.id::text,old.name,
      jsonb_build_object('trips',(select count(*) from public.trips where group_id=old.id),'members',(select count(*) from public.group_members where group_id=old.id)));
    return old;
  end if;
  return new;
end $$;

revoke all on function public.restore_group(uuid) from public, anon;
revoke all on function public.purge_group(uuid) from public, anon;
revoke all on function public.admin_group_trash() from public, anon;
grant execute on function public.restore_group(uuid) to authenticated;
grant execute on function public.purge_group(uuid) to authenticated;
grant execute on function public.admin_group_trash() to authenticated;
