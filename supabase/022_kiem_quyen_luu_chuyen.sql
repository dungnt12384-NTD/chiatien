-- 022: Máy chủ kiểm quyền từng phần khi lưu chuyến (save_trip) – trước đây chỉ giao diện chặn.
--   * Tài khoản nhận tiền (data.bank, dùng cho QR): chỉ Thủ quỹ / quản trị viên đổi được.
--     Máy chủ tự ghi data.bankBy (email) + data.bankAt (giờ máy chủ) mỗi lần đổi; người dùng không tự ghi được 2 trường này.
--   * Người hỗ trợ:
--       - members  : cần tab 'member'
--       - advances : cần tab 'advance'; holder: cần 'advance' (hoặc 'member' khi đang xoá / thêm người)
--       - khoản chi thường (không phải tiền phòng): thêm mới cần tab 'expense';
--         chỉ sửa / xoá được khoản do CHÍNH MÌNH tạo (data.expenses[].by). Khoản của người khác giữ nguyên;
--         riêng khi danh sách người đi thay đổi thì cho phép excluded / payer / selfRoom đổi theo (app tự cập nhật).
--       - khoản tiền phòng: giữ như cũ (app tự chuẩn hoá theo phòng).
--   * Mọi khoản chi: máy chủ tự ghi 'by' = email người tạo cho khoản mới, giữ nguyên 'by' của khoản cũ (không giả được).
--   * Vi phạm: KHÔNG lưu, trả {ok:false, denied:'<lý do>', rev, data: bản trên máy chủ} để app quay về bản đúng.
-- Quay lại: chạy lại save_trip bản 007; drop function public.trip_guard(text,jsonb,jsonb,boolean), public.trip_exp_core(jsonb,boolean);

create or replace function public.trip_exp_core(e jsonb, loose boolean)
returns jsonb language sql immutable set search_path = public as $$
  select case when loose then e - 'by' - 'excluded' - 'payer' - 'selfRoom' else e - 'by' end $$;

create or replace function public.trip_guard(p_id text, old_d jsonb, new_d jsonb, p_lead boolean)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  em text := public.my_email();
  tb text[];
  od jsonb := coalesce(old_d -> 'data', '{}'::jsonb);
  nd jsonb := coalesce(new_d -> 'data', '{}'::jsonb);
  mem_ch boolean; o jsonb; n jsonb; arr jsonb := '[]'::jsonb; is_room boolean;
begin
  mem_ch := (od -> 'members') is distinct from (nd -> 'members');
  if not p_lead then
    select r.tabs into tb from public.trip_roles r where r.trip_id = p_id and r.email = em;
    tb := coalesce(tb, '{}');
    if (od -> 'bank') is distinct from (nd -> 'bank') then raise exception 'denied:bank'; end if;
    if mem_ch and not 'member' = any(tb) then raise exception 'denied:member'; end if;
    if (od -> 'advances') is distinct from (nd -> 'advances') and not ('advance' = any(tb) or (mem_ch and 'member' = any(tb))) then
      raise exception 'denied:advance'; end if;
    if (od -> 'holder') is distinct from (nd -> 'holder') and not ('advance' = any(tb) or (mem_ch and 'member' = any(tb))) then
      raise exception 'denied:advance'; end if;
    -- khoản chi cũ
    for o in select x from jsonb_array_elements(coalesce(od -> 'expenses', '[]'::jsonb)) x loop
      if jsonb_array_length(coalesce(o -> 'rooms', '[]'::jsonb)) > 0 then continue; end if;
      select x into n from jsonb_array_elements(coalesce(nd -> 'expenses', '[]'::jsonb)) x where x ->> 'id' = o ->> 'id' limit 1;
      if (o ->> 'by') is not distinct from em and em is not null then
        if (n is null or public.trip_exp_core(n, mem_ch) <> public.trip_exp_core(o, mem_ch)) and not 'expense' = any(tb) then
          raise exception 'denied:expense'; end if;
      else
        if n is null then raise exception 'denied:exp_other'; end if;
        if jsonb_array_length(coalesce(n -> 'rooms', '[]'::jsonb)) = 0
           and public.trip_exp_core(n, mem_ch) <> public.trip_exp_core(o, mem_ch) then raise exception 'denied:exp_other'; end if;
      end if;
    end loop;
    -- khoản chi mới
    if not 'expense' = any(tb) and exists (
        select 1 from jsonb_array_elements(coalesce(nd -> 'expenses', '[]'::jsonb)) x
         where jsonb_array_length(coalesce(x -> 'rooms', '[]'::jsonb)) = 0
           and not exists (select 1 from jsonb_array_elements(coalesce(od -> 'expenses', '[]'::jsonb)) y where y ->> 'id' = x ->> 'id')) then
      raise exception 'denied:expense'; end if;
  end if;
  -- đóng dấu người tạo khoản chi
  for n in select x from jsonb_array_elements(coalesce(nd -> 'expenses', '[]'::jsonb)) x loop
    select x into o from jsonb_array_elements(coalesce(od -> 'expenses', '[]'::jsonb)) x where x ->> 'id' = n ->> 'id' limit 1;
    if o is not null then
      n := case when o ? 'by' then jsonb_set(n, '{by}', o -> 'by') else n - 'by' end;
    elsif em is not null then
      n := jsonb_set(n, '{by}', to_jsonb(em));
    end if;
    arr := arr || jsonb_build_array(n);
    o := null;
  end loop;
  if nd ? 'expenses' then nd := jsonb_set(nd, '{expenses}', arr); end if;
  -- tài khoản nhận tiền: dấu người đổi + giờ do máy chủ ghi
  if (od -> 'bank') is distinct from (nd -> 'bank') then
    nd := jsonb_set(jsonb_set(nd, '{bankBy}', coalesce(to_jsonb(em), to_jsonb('quản trị viên'::text))), '{bankAt}', to_jsonb(now()));
  else
    nd := nd - 'bankBy' - 'bankAt';
    if od ? 'bankBy' then nd := jsonb_set(nd, '{bankBy}', od -> 'bankBy'); end if;
    if od ? 'bankAt' then nd := jsonb_set(nd, '{bankAt}', od -> 'bankAt'); end if;
  end if;
  return jsonb_set(coalesce(new_d, '{}'::jsonb), '{data}', nd);
end $$;

create or replace function public.save_trip(p_id text, p_group uuid, p_data jsonb, p_base integer, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare cur integer; cur_data jsonb; cl timestamptz; g uuid; del boolean; em text := public.my_email(); nd jsonb;
begin
  select rev, data, closed_at, group_id, deleted into cur, cur_data, cl, g, del from public.trips where id = p_id for update;
  if not found then
    if not public.can_create_trip(p_group) then raise exception 'forbidden'; end if;
    nd := public.trip_guard(p_id, '{}'::jsonb, p_data, true);
    insert into public.trips(id, group_id, data, rev) values (p_id, p_group, nd, 1);
    if em is not null then
      insert into public.trip_roles(trip_id, email, role, tabs, added_by) values (p_id, em, 'leader', '{member,advance,room,expense}', em) on conflict do nothing;
    end if;
    insert into public.trip_codes(trip_id, code) values (p_id, public.gen_code('CH')) on conflict do nothing;
    return jsonb_build_object('ok', true, 'rev', 1);
  end if;
  if g <> p_group or not public.can_edit_trip(p_id) then raise exception 'forbidden'; end if;
  if del then return jsonb_build_object('ok', false, 'deleted', true, 'rev', cur); end if;
  if cl is not null then return jsonb_build_object('ok', false, 'closed', true, 'rev', cur, 'data', cur_data); end if;
  if cur = p_base or p_force then
    begin
      nd := public.trip_guard(p_id, cur_data, p_data, public.can_lead_trip(p_id));
    exception when others then
      if sqlerrm like 'denied:%' then
        return jsonb_build_object('ok', false, 'denied', substr(sqlerrm, 8), 'rev', cur, 'data', cur_data);
      end if;
      raise;
    end;
    update public.trips set data = nd, rev = cur + 1 where id = p_id;
    perform public.log_changes(p_id, g, cur_data, nd);
    return jsonb_build_object('ok', true, 'rev', cur + 1);
  end if;
  return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur, 'data', cur_data);
end $$;

revoke all on function public.trip_guard(text, jsonb, jsonb, boolean) from public, anon, authenticated;
revoke all on function public.trip_exp_core(jsonb, boolean) from public, anon;
