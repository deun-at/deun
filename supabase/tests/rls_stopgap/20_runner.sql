-- t(case, actor, sql, expectation): runs sql as actor inside a subtransaction that is
-- always rolled back. actor = 'anon' or an email in auth.users. expectation:
--   'ok'   no error;  'ok:N' no error and N rows;  'ok:>0' rows > 0;  'err' any error.
create table if not exists test_result (n serial, name text, actor text, expect text, got text, pass boolean);
create or replace function t(_name text, _actor text, _sql text, _expect text) returns void
language plpgsql as $$
declare _uid text; _em text; _n bigint; _got text; _pass boolean;
begin
  begin
    if _actor = 'anon' then
      perform set_config('request.jwt.claims', '{"role":"anon"}', true);
      perform set_config('role', 'anon', true);
    else
      select id::text, email into _uid, _em from auth.users where email = _actor;
      perform set_config('request.jwt.claims', json_build_object('sub', _uid, 'email', _em, 'role', 'authenticated')::text, true);
      perform set_config('role', 'authenticated', true);
    end if;
    execute _sql;
    get diagnostics _n = row_count;
    _got := 'ok:' || _n;
    raise exception using errcode = 'P0001', message = '__rollback__';
  exception when others then
    if sqlerrm <> '__rollback__' then _got := 'err: ' || left(sqlerrm, 90); end if;
  end;
  _pass := case
    when _expect = 'err' then _got like 'err%'
    when _expect = 'ok' then _got like 'ok:%'
    when _expect = 'ok:>0' then _got like 'ok:%' and _got <> 'ok:0'
    else _got = _expect end;
  insert into test_result (name, actor, expect, got, pass) values (_name, _actor, _expect, _got, _pass);
end $$;
