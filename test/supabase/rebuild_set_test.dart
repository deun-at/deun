// schema-baseline: the rebuild rule, proven on fixtures before it touches the
// real dump, so a real-tree check can only go green because the real tree
// passes. Red means a rebuild breaks: a pre-stamp file replayed over the dump
// (20260417 cannot narrow get_user_spending_summary back to int), or a newer
// file skipped and its change silently dropped.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rebuild_set.dart';

const _stamped = '-- dump-stamp: 20260701000000\n';

/// The migrations present at 439b7d5. The dump of 2026-10-25 contains all of
/// them, so none may ever be replayed over it.
const _appliedAt439b7d5 = [
  '20260417_user_spending_summary.sql',
  '20260610120000_atomic_save_rpcs.sql',
  '20260618000000_per_unit_claim_entries.sql',
  '20260628000000_fix_spending_summary_color_bigint.sql',
  '20260712000000_add_group_currency_code.sql',
  '20260815000000_baseline_ledger_functions.sql',
  '20260815010000_group_member_removal.sql',
  '20260815020000_settle_residue_exact_payback.sql',
  '20260816000000_group_currency_code_persist.sql',
  '20260816010000_payback_on_behalf.sql',
  '20260816020000_expense_entry_currency_rate.sql',
];

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('rebuild_set_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'replays exactly the migrations stamped after the dump stamp, in filename order',
    () {
      final rebuild = loadFixture(tmp, _stamped, {
        '20260417_spending.sql': '',
        '20260630235959_pre.sql': '',
        '20260701_same_day_padded.sql': '',
        '20260702_short_post.sql': '',
        '20260801000000_post.sql': '',
        'rollback/20260901000000_post_rollback.sql': '',
        'README.md': '',
      });

      expect(rebuild.dumpStamp, '20260701000000');
      expect(rebuild.replayedMigrations, [
        '20260702_short_post.sql',
        '20260801000000_post.sql',
      ]);
      expect(rebuild.preStampMigrations, [
        '20260417_spending.sql',
        '20260630235959_pre.sql',
        '20260701_same_day_padded.sql',
      ]);
    },
  );

  test('refuses a baseline without a dump-stamp line', () {
    expect(
      () => loadFixture(tmp, '--\n-- PostgreSQL database dump\n--\n'),
      throwsStateError,
    );
  });

  test(
    'a function re-stated after the stamp resolves to its re-stated body',
    () {
      final rebuild = loadFixture(
        tmp,
        _stamped +
            r'''
CREATE FUNCTION public.get_user_spending_summary(p_user_email text, p_start date, p_end date) RETURNS TABLE(group_id uuid, color_value bigint)
    LANGUAGE sql STABLE
    AS $$ select null::uuid, 1::bigint; $$;

CREATE FUNCTION public.pay_back(_group_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$ begin return null; /* baseline body */ end; $_$;

CREATE FUNCTION public.retired() RETURNS void
    LANGUAGE sql
    AS $$ select 1 $$;
''',
        {
          '20260417_spending.sql': r'''
create or replace function get_user_spending_summary(p_user_email text, p_start date, p_end date)
returns table (group_id uuid, color_value int) language sql as $$ select null::uuid, 1; $$;
''',
          '20260702000000_pay_back.sql': r'''
create or replace function public.pay_back(_group_id uuid)
returns uuid language plpgsql as $function$
begin
  -- first re-statement; a semicolon; inside the body does not end it
  return null;
end;
$function$;
''',
          '20260703000000_pay_back_again.sql': r'''
create or replace function public.pay_back(_group_id uuid)
returns uuid language plpgsql as $$ begin return null; /* newest body */ end; $$;
drop function if exists public.retired();
''',
        },
      );

      expect(rebuild.latestFunctionSource('pay_back'), contains('newest body'));
      expect(
        rebuild.latestFunctionSource('public.pay_back'),
        contains('newest body'),
      );
      expect(
        rebuild.latestFunctionSource('get_user_spending_summary'),
        contains('color_value bigint'),
      );
      expect(rebuild.hasFunction('retired'), isFalse);
      expect(rebuild.latestFunctionSource('never_defined'), isNull);
    },
  );

  test(
    'names match case-insensitively, unquoted, with public as the default schema',
    () {
      final rebuild = loadFixture(
        tmp,
        _stamped +
            r'''
CREATE TABLE public."group" (
    name text,
    color_value bigint,
    note text DEFAULT 'a, b; c'::text,
    CONSTRAINT group_name_check CHECK ((name <> ''::text))
);

COMMENT ON COLUMN public."group".note IS 'Free text; never parsed';

CREATE TABLE public."user" (
    email text NOT NULL
);

CREATE TABLE auth.users (
    id uuid NOT NULL
);

CREATE VIEW public.member_view AS
 SELECT 1 AS one;

CREATE INDEX Group_Name_Idx ON public."group" USING btree (name);
''',
        {
          '20260712000000_currency.sql': r'''
alter table "group"
  add column if not exists currency_code text not null default 'EUR';
alter table public."user"
  add column if not exists locale text,
  add column if not exists display_name text;
create index if not exists user_locale_idx
  on public."user" (locale);
''',
        },
      );

      expect(rebuild.hasRelation('group'), isTrue);
      expect(rebuild.hasRelation('GROUP'), isTrue);
      expect(rebuild.hasRelation('public."group"'), isTrue);
      expect(rebuild.hasRelation('member_view'), isTrue);
      expect(rebuild.hasRelation('auth.users'), isTrue);
      expect(rebuild.hasRelation('users'), isFalse);
      expect(rebuild.hasColumn('group', 'note'), isTrue);
      expect(rebuild.hasColumn('"group"', 'Currency_Code'), isTrue);
      expect(rebuild.hasColumn('user', 'display_name'), isTrue);
      expect(rebuild.hasColumn('group', 'constraint'), isFalse);
      expect(rebuild.hasIndex('group_name_idx'), isTrue);
      expect(rebuild.hasIndex('user_locale_idx'), isTrue);
    },
  );

  test(
    'publication membership: ADD TABLE, FOR TABLE, FOR ALL TABLES and a guarded add inside DO',
    () {
      final rebuild = loadFixture(
        Directory('${tmp.path}/explicit'),
        _stamped +
            r'''
CREATE TABLE public.friendship (requester text);
CREATE TABLE public.group_member (email text);
CREATE TABLE public.expense_update_checker (expense_id uuid);
CREATE TABLE public.group_update_checker (group_id uuid);
CREATE TABLE public.device_tokens (token text);
CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');
CREATE PUBLICATION supabase_realtime_messages_publication WITH (publish = 'insert, update, delete, truncate');
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.friendship;
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.expense_update_checker;
ALTER PUBLICATION supabase_realtime_messages_publication ADD TABLE ONLY public.device_tokens;
CREATE FUNCTION public.publish_later() RETURNS void
    LANGUAGE plpgsql
    AS $$ begin alter publication supabase_realtime add table public.device_tokens; end; $$;
''',
        {
          '20260702000000_scope.sql': r'''
begin;
do $$
begin
  -- A FOR ALL TABLES publication already carries group_member.
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'group_member'
  ) then
    alter publication supabase_realtime add table public.group_member;
  end if;
end
$$;
alter publication supabase_realtime drop table public.expense_update_checker;
commit;
''',
        },
      );
      expect(rebuild.inRealtimePublication('friendship'), isTrue);
      expect(rebuild.inRealtimePublication('group_member'), isTrue);
      expect(rebuild.inRealtimePublication('expense_update_checker'), isFalse);
      expect(rebuild.inRealtimePublication('group_update_checker'), isFalse);
      expect(rebuild.inRealtimePublication('device_tokens'), isFalse);

      final listed = loadFixture(
        Directory('${tmp.path}/listed'),
        '${_stamped}CREATE TABLE public.a (x int);\n'
        'CREATE TABLE public.b (x int);\n'
        'CREATE PUBLICATION supabase_realtime FOR TABLE public.a, ONLY b;\n',
      );
      expect(listed.inRealtimePublication('a'), isTrue);
      expect(listed.inRealtimePublication('b'), isTrue);

      final all = loadFixture(
        Directory('${tmp.path}/all'),
        '${_stamped}CREATE TABLE public.a (x int);\n'
        'CREATE PUBLICATION supabase_realtime FOR ALL TABLES;\n',
      );
      expect(all.inRealtimePublication('a'), isTrue);
      expect(all.inRealtimePublication('not_a_table'), isFalse);
    },
  );

  test(
    'pre-stamp gaps name what an applied migration creates and the dump lacks',
    () {
      final rebuild = loadFixture(
        tmp,
        _stamped +
            r'''
CREATE TABLE public.expense_entry (id uuid, item_group_id uuid);
CREATE FUNCTION public.save_expense_all(_group_id uuid) RETURNS uuid
    LANGUAGE sql
    AS $$ select null::uuid $$;
''',
        {
          '20260618000000_claims.sql': r'''
alter table public.expense_entry
  add column if not exists item_group_id uuid,
  add column if not exists original_amount numeric;
create index if not exists expense_entry_item_group_id_idx
  on public.expense_entry (item_group_id);
create or replace function public.save_expense_all(_group_id uuid)
returns uuid language sql as $$ select null::uuid $$;
create or replace function public.claim_set_unit_shares(_entry_id uuid)
returns void language sql as $$ select 1 $$;
''',
        },
      );

      expect(
        rebuild.preStampGaps(),
        unorderedEquals([
          '20260618000000_claims.sql: column expense_entry.original_amount',
          '20260618000000_claims.sql: index expense_entry_item_group_id_idx',
          '20260618000000_claims.sql: function claim_set_unit_shares',
        ]),
      );
    },
  );

  group('the real tree', () {
    late RebuildSet rebuild;
    setUpAll(() => rebuild = RebuildSet.load());

    test('no migration present at 439b7d5 is replayed over the dump', () {
      expect(
        rebuild.replayedMigrations.toSet().intersection(
          _appliedAt439b7d5.toSet(),
        ),
        isEmpty,
      );
    });

    test(
      'every function, added column and index a pre-stamp migration creates is in the rebuild set',
      () {
        expect(rebuild.preStampMigrations, isNotEmpty);
        expect(rebuild.preStampGaps(), isEmpty);
      },
    );
  });
}
