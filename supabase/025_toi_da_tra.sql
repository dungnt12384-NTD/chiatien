-- 025: "Tôi đã trả" – người đi (đăng nhập hoặc chỉ dùng mã xem) gửi ĐỀ NGHỊ khoản đã trả thay; chỉ Thủ quỹ (và quản trị viên) duyệt.
--   Đề nghị chưa phải khoản chi: Thủ quỹ bấm Duyệt thì app mở sẵn form khoản chi (đã điền), chọn người chia rồi lưu bằng đường lưu bình thường.
--   Giới hạn chống spam: tối đa 5 đề nghị chờ duyệt / người / chuyến, 60 / chuyến, 20 / giờ / người. Chuyến đã chốt thì không gửi được.
-- Quay lại: drop function public.submit_claim(text,text,text,text,text,bigint,text), public.trip_claims_list(text), public.decide_claim(bigint,boolean,text); drop table public.trip_claims;

create table if not exists public.trip_claims(
  id bigserial primary key,
  trip_id text not null references public.trips(id) on delete cascade,
  day_id text, member_id text not null, member_name text,
  descr text not null check (length(descr) between 1 and 80),
  amount bigint not null check (amount between 1 and 1000000000),
  note text check (note is null or length(note) <= 200),
  reporter text, user_id uuid default auth.uid(), at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_at timestamptz, decided_by text, reply text);
create index if not exists trip_claims_trip_idx on public.trip_claims(trip_id, status);
alter table public.trip_claims enable row level security;
revoke all on public.trip_claims from anon, authenticated;

create or replace function public.submit_claim(tid text, p_day text, p_member text, p_name text, p_desc text, p_amount bigint, p_note text)
returns bigint language plpgsql security definer set search_path = public as $$
declare td jsonb; cl timestamptz; del boolean; d text := left(btrim(coalesce(p_desc,'')), 80); nid bigint;
begin
  select data, closed_at, deleted into td, cl, del from public.trips where id = tid;
  if not found or del or auth.uid() is null or not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  if cl is not null then raise exception 'closed'; end if;
  if d = '' then raise exception 'bad_desc'; end if;
  if p_amount is null or p_amount < 1 or p_amount > 1000000000 then raise exception 'bad_amount'; end if;
  if not exists (select 1 from jsonb_array_elements(coalesce(td -> 'data' -> 'members', '[]'::jsonb)) m where m ->> 'id' = p_member) then raise exception 'bad_member'; end if;
  if coalesce(p_day,'') <> '' and not exists (select 1 from jsonb_array_elements(coalesce(td -> 'data' -> 'days', '[]'::jsonb)) x where x ->> 'id' = p_day) then raise exception 'bad_day'; end if;
  if (select count(*) from public.trip_claims where trip_id = tid and user_id = auth.uid() and status = 'pending') >= 5 then raise exception 'too_many'; end if;
  if (select count(*) from public.trip_claims where trip_id = tid and status = 'pending') >= 60 then raise exception 'too_many'; end if;
  if (select count(*) from public.trip_claims where user_id = auth.uid() and at > now() - interval '1 hour') >= 20 then raise exception 'rate_limited'; end if;
  insert into public.trip_claims(trip_id, day_id, member_id, member_name, descr, amount, note, reporter, user_id)
    values (tid, nullif(p_day,''), p_member, left(btrim(coalesce(p_name,'')), 60), d, p_amount, nullif(left(btrim(coalesce(p_note,'')), 200),''), left(btrim(coalesce(p_name,'')), 60), auth.uid())
    returning id into nid;
  return nid;
end $$;

create or replace function public.trip_claims_list(tid text)
returns table(id bigint, day_id text, member_id text, member_name text, descr text, amount bigint, note text, reporter text, mine boolean, at timestamptz, status text, decided_at timestamptz, reply text)
language plpgsql stable security definer set search_path = public as $$
declare ld boolean := public.can_lead_trip(tid);
begin
  if not public.can_view_trip(tid) then raise exception 'forbidden'; end if;
  return query select c.id, c.day_id, c.member_id, c.member_name, c.descr, c.amount, c.note, c.reporter, c.user_id = auth.uid(), c.at, c.status, c.decided_at, c.reply
    from public.trip_claims c where c.trip_id = tid and (ld or c.user_id = auth.uid())
    order by (c.status = 'pending') desc, c.id desc limit 100;
end $$;

create or replace function public.decide_claim(p_id bigint, p_ok boolean, p_reply text)
returns void language plpgsql security definer set search_path = public as $$
declare tid text; st text;
begin
  select trip_id, status into tid, st from public.trip_claims where id = p_id for update;
  if tid is null or not public.can_lead_trip(tid) then raise exception 'forbidden'; end if;
  if st <> 'pending' then raise exception 'claim_done'; end if;
  update public.trip_claims set status = case when p_ok then 'approved' else 'rejected' end, decided_at = now(),
    decided_by = coalesce(public.my_email(), 'quản trị viên'), reply = nullif(left(btrim(coalesce(p_reply,'')), 500), '') where id = p_id;
end $$;

revoke all on function public.submit_claim(text,text,text,text,text,bigint,text) from public, anon;
revoke all on function public.trip_claims_list(text) from public, anon;
revoke all on function public.decide_claim(bigint,boolean,text) from public, anon;
grant execute on function public.submit_claim(text,text,text,text,text,bigint,text) to authenticated;
grant execute on function public.trip_claims_list(text) to authenticated;
grant execute on function public.decide_claim(bigint,boolean,text) to authenticated;
