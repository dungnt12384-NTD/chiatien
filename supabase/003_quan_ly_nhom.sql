-- Quản lý nhóm: đổi tên, xoá nhóm (chỉ chủ nhóm), rời nhóm, giới hạn số nhóm một người được tạo.
create or replace function public.create_group(gname text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups; n text := btrim(regexp_replace(coalesce(gname,''), '\s+', ' ', 'g'));
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if n = '' or length(n) > 40 then raise exception 'invalid name'; end if;
  if (select count(*) from public.group_members where user_id = auth.uid() and role = 'owner') >= 3 then
    raise exception 'group limit';
  end if;
  insert into public.groups(name, created_by) values (n, auth.uid()) returning * into g;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'owner');
  insert into public.group_codes(group_id, edit_code, view_code) values (g.id, public.new_code(), public.new_code());
  return g;
end $$;

create or replace function public.rename_group(gid uuid, new_name text)
returns void language plpgsql security definer set search_path = public as $$
declare n text := btrim(regexp_replace(coalesce(new_name,''), '\s+', ' ', 'g'));
begin
  if not public.is_owner(gid) then raise exception 'forbidden'; end if;
  if n = '' or length(n) > 40 then raise exception 'invalid name'; end if;
  update public.groups set name = n where id = gid;
end $$;

create or replace function public.delete_group(gid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(gid) then raise exception 'forbidden'; end if;
  delete from public.groups where id = gid;   -- kéo theo chuyến, thành viên, mã mời, link chia sẻ (on delete cascade)
end $$;

create or replace function public.leave_group(gid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.is_owner(gid) then raise exception 'owner cannot leave'; end if;
  delete from public.group_members where group_id = gid and user_id = auth.uid();
end $$;

revoke all on function public.rename_group(uuid,text), public.delete_group(uuid), public.leave_group(uuid) from public, anon;
grant execute on function public.rename_group(uuid,text), public.delete_group(uuid), public.leave_group(uuid) to authenticated;
