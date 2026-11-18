-- Thùng rác chuyến đi (xoá mềm 30 ngày), thông tin và lịch sử từng chuyến. (Chạy sau 005)
alter table public.trips add column if not exists deleted_at timestamptz;
alter table public.trips add column if not exists deleted_by uuid;

-- chuyển chuyến vào thùng rác (người nhập, chủ nhóm, quản trị viên)
create or replace function public.trash_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  update public.trips set deleted = true, deleted_at = now(), deleted_by = auth.uid(), rev = rev + 1
    where id = tid and group_id = gid;
end $$;

create or replace function public.restore_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  update public.trips set deleted = false, deleted_at = null, deleted_by = null, rev = rev + 1
    where id = tid and group_id = gid;
end $$;

-- xoá hẳn khỏi thùng rác: chỉ chủ nhóm hoặc quản trị viên
create or replace function public.purge_trip(gid uuid, tid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage(gid) then raise exception 'forbidden'; end if;
  delete from public.trips where id = tid and group_id = gid and deleted;
end $$;

-- danh sách thùng rác (tự dọn chuyến quá 30 ngày)
create or replace function public.trip_trash(gid uuid)
returns table(id text, name text, deleted_at timestamptz, deleted_by_email text, days_left integer)
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  delete from public.trips t where t.group_id = gid and t.deleted and t.deleted_at < now() - interval '30 days';
  return query select t.id, coalesce(t.data ->> 'name', '(không tên)'), t.deleted_at, u.email::text,
      greatest(0, 30 - extract(day from now() - t.deleted_at)::int)
    from public.trips t left join auth.users u on u.id = t.deleted_by
    where t.group_id = gid and t.deleted order by t.deleted_at desc nulls last;
end $$;

-- thông tin một chuyến: người tạo, ngày tạo, lần sửa cuối
create or replace function public.trip_info(gid uuid, tid text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c record; t record;
begin
  if not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  select actor_email, at into c from public.audit_log where entity = 'trip' and action = 'create' and entity_id = tid and group_id = gid order by id limit 1;
  select updated_at into t from public.trips where id = tid and group_id = gid;
  return jsonb_build_object('creator', c.actor_email, 'created_at', c.at, 'updated_at', t.updated_at);
end $$;

create or replace function public.trip_audit(gid uuid, tid text, p_limit integer default 50, p_before bigint default null)
returns setof public.audit_log language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_member(gid, true) then raise exception 'forbidden'; end if;
  return query select * from public.audit_log a where a.entity = 'trip' and a.entity_id = tid and a.group_id = gid
    and (p_before is null or a.id < p_before) order by a.id desc limit least(coalesce(p_limit, 50), 200);
end $$;

revoke all on function public.trash_trip(uuid,text), public.restore_trip(uuid,text), public.purge_trip(uuid,text),
  public.trip_trash(uuid), public.trip_info(uuid,text), public.trip_audit(uuid,text,integer,bigint) from public, anon;
grant execute on function public.trash_trip(uuid,text), public.restore_trip(uuid,text), public.purge_trip(uuid,text),
  public.trip_trash(uuid), public.trip_info(uuid,text), public.trip_audit(uuid,text,integer,bigint) to authenticated;
