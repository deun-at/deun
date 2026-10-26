// guest-merge-rpc: the join_group migration, read as source. Each test pins one
// contract criterion; the behaviour itself is proven on the local harness
// (supabase/tests/rls_stopgap/40_join_group_cases.sql).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'join_group_migration_source.dart';

/// Every statement in [text] that contains [verb], cut to start at [verb].
List<String> _statements(String text, String verb) => [
  for (final piece in text.split(';'))
    if (piece.contains(verb)) piece.substring(piece.indexOf(verb)).trim(),
];

final _ifToken = RegExp(r'\bend if\b|(?<!end )\bif\b');

/// How many `if` blocks are open at [pos] (`elsif` does not open one).
int _ifDepthAt(String body, int pos) {
  var depth = 0;
  for (final m in _ifToken.allMatches(body.substring(0, pos))) {
    depth += m.group(0) == 'end if' ? -1 : 1;
  }
  return depth;
}

/// The end of the `end if` that closes the `if` starting at [ifPos].
int _matchingEndIf(String body, int ifPos) {
  var depth = 0;
  for (final m in _ifToken.allMatches(body, ifPos)) {
    depth += m.group(0) == 'end if' ? -1 : 1;
    if (depth == 0) return m.end;
  }
  throw StateError('unclosed if at $ifPos');
}

void main() {
  late String sql;
  late String body;
  late int mergeAt;

  setUpAll(() {
    sql = joinGroupMigrationSql();
    body = functionBody(sql, 'join_group');
    mergeAt = body.indexOf('if _guest_email is not null then');
  });

  test(
    'the merge rewrites paid_by and share emails only on the joined group\'s rows',
    () {
      final rewrites = _statements(
        body,
        'update public.',
      ).where((s) => s.contains('_guest_email')).toList();

      expect(rewrites, hasLength(2));
      for (final rewrite in rewrites) {
        expect(rewrite, contains('e.group_id = _group_id'));
      }
      expect(
        rewrites.where(
          (s) =>
              s.startsWith('update public.expense as e set paid_by = _email'),
        ),
        hasLength(1),
      );
      final shareRewrite = rewrites.singleWhere(
        (s) => s.startsWith('update public.expense_entry_share'),
      );
      expect(
        shareRewrite,
        contains('join public.expense as e on e.id = ee.expense_id'),
      );

      final guestMembershipDelete = _statements(
        body,
        'delete from public.group_member',
      ).single;
      expect(
        guestMembershipDelete,
        allOf(
          contains('gm.group_id = _group_id'),
          contains('gm.email = _guest_email'),
        ),
      );
    },
  );

  test(
    'no row inserts, a soft-removed row is re-activated, an active row is left alone, and the merge runs in every case',
    () {
      final branchStart = body.indexOf('if not found then');
      expect(branchStart, greaterThan(-1));
      final branchEnd = _matchingEndIf(body, branchStart);
      final branch = body.substring(branchStart, branchEnd);

      final insertAt = branch.indexOf(
        'insert into public.group_member (group_id, email, is_favorite) '
        'values (_group_id, _email, false)',
      );
      final elsifAt = branch.indexOf('elsif _removed_at is not null then');
      expect(insertAt, greaterThan(-1));
      expect(elsifAt, greaterThan(insertAt));
      expect(
        branch.indexOf('update public.group_member'),
        greaterThan(elsifAt),
      );
      expect(
        _statements(branch, 'update public.group_member').single,
        allOf(
          contains('set removed_at = null'),
          contains('group_id = _group_id'),
          contains('email = _email'),
          contains('removed_at is not null'),
        ),
      );
      // An active row falls through the branch: no `else`, so no write.
      expect(RegExp(r'\belse\b').hasMatch(branch), isFalse);

      // The joiner's own row is looked up before the branch decides.
      final lookup = body.indexOf(
        'from public.group_member as gm '
        'where gm.group_id = _group_id and gm.email = _email',
      );
      expect(lookup, inInclusiveRange(0, branchStart));

      // One membership insert, one re-activation, in the whole function.
      expect('insert into public.group_member'.allMatches(body), hasLength(1));
      expect(_statements(body, 'update public.group_member'), hasLength(1));

      // The merge sits after the branch at top level, not inside any arm.
      expect(mergeAt, greaterThan(branchEnd));
      expect(_ifDepthAt(body, mergeAt), 0);
    },
  );

  test(
    'the guest user row is deleted only when has_any_membership says no group names it, after the recalc',
    () {
      expect('delete from public."user"'.allMatches(body), hasLength(1));
      final guarded = RegExp(
        r'if _guest_email is not null and not public\.has_any_membership\(_guest_email\) '
        r'then delete from public\."user"',
      ).firstMatch(body);
      expect(guarded, isNotNull);
      expect(
        guarded!.start,
        greaterThan(body.indexOf('perform public.update_group_member_shares(')),
      );
    },
  );

  test('every refusal raises before the first write', () {
    final firstWrite = RegExp(
      r'insert into |update public\.|delete from ',
    ).firstMatch(body)!.start;

    expect(body, contains("auth.jwt() ->> 'email'"));
    final noEmail = RegExp(
      r'if _email is null[^;]*? then raise exception',
    ).firstMatch(body);
    expect(noEmail, isNotNull);
    expect(noEmail!.end, lessThan(firstWrite));

    final notAnActiveGuest = RegExp(
      r'if _guest_email is not null and not exists \(select 1 from '
      r'public\.group_join_guests\(_group_id\) as g where g\.email = _guest_email\) '
      r'then raise exception',
    ).firstMatch(body);
    expect(notAnActiveGuest, isNotNull);
    expect(notAnActiveGuest!.end, lessThan(firstWrite));
  });

  test(
    'the recalc runs once inside join_group, after the merge and before the guest delete; the client sends none',
    () {
      const recalc =
          'perform public.update_group_member_shares(_group_id, null';
      expect(recalc.allMatches(body), hasLength(1));
      final recalcAt = body.indexOf(recalc);
      expect(_ifDepthAt(body, recalcAt), 0);
      expect(recalcAt, greaterThan(_matchingEndIf(body, mergeAt)));
      expect(recalcAt, lessThan(body.indexOf('delete from public."user"')));

      final page = File(
        'lib/pages/groups/presentation/group_join_page.dart',
      ).readAsStringSync();
      expect(page, isNot(contains('update_group_member_shares')));
      final repository = File(
        'lib/pages/groups/data/member_repository.dart',
      ).readAsStringSync();
      final joinGroup = RegExp(
        r'Future<void> joinGroup\((.*?)\r?\n  \}\r?\n', // CRLF checkouts
        dotAll: true,
      ).firstMatch(repository);
      expect(joinGroup, isNotNull);
      expect(joinGroup!.group(1), contains('joinGroupRpcName'));
      expect(joinGroup.group(1), isNot(contains('update_group_member_shares')));
    },
  );

  test(
    'a silent no-op raises: re-activation, guest removal, and leftover guest rows',
    () {
      expect(
        RegExp(
          r'update public\.group_member set removed_at = null [^;]*; '
          r'get diagnostics (\w+) = row_count; if \1 (= 0|<> 1|< 1) then raise exception',
        ).hasMatch(body),
        isTrue,
      );
      expect(
        RegExp(
          r'delete from public\.group_member as gm where [^;]*_guest_email[^;]*; '
          r'get diagnostics (\w+) = row_count; if \1 (= 0|<> 1|< 1) then raise exception',
        ).hasMatch(body),
        isTrue,
      );

      final merge = body.substring(mergeAt, _matchingEndIf(body, mergeAt));
      final residualAt = merge.indexOf(
        'if exists (select 1 from public.expense as e '
        'where e.group_id = _group_id and e.paid_by = _guest_email)',
      );
      expect(
        residualAt,
        greaterThan(merge.indexOf('delete from public.group_member')),
      );
      expect(
        RegExp(
          r'or exists \(select 1 from public\.expense_entry_share as s [^;]*'
          r'e\.group_id = _group_id[^;]*s\.email = _guest_email[^;]*\) then raise exception',
        ).hasMatch(merge.substring(residualAt)),
        isTrue,
      );
    },
  );

  test(
    'the claimable guests are the group\'s active guest members, readable by a signed-in non-member only',
    () {
      final header = RegExp(
        r'create or replace function public\.group_join_guests\(_group_id uuid\) '
        r'(.*?) as \$group_join_guests\$',
      ).firstMatch(sql);
      expect(header, isNotNull);
      expect(
        header!.group(1),
        allOf(
          contains('returns table (email text, display_name text)'),
          contains('security definer'),
          contains('stable'),
          contains("set search_path = ''"),
        ),
      );
      expect(
        functionBody(sql, 'group_join_guests'),
        allOf(
          contains('gm.group_id = _group_id'),
          contains('gm.removed_at is null'),
          contains('u.is_guest is true'),
        ),
      );
      expect(
        sql,
        contains(
          'revoke execute on function public.group_join_guests(uuid) from public, anon',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.group_join_guests(uuid) to authenticated;',
        ),
      );
    },
  );

  test('join_group takes the group member-write lock as its first statement', () {
    expect(
      RegExp(
        r'^\s*declare .*? begin perform public\.lock_group_member_writes\(_group_id\);',
      ).hasMatch(body),
      isTrue,
    );
    expect(
      RegExp(
        r'create or replace function public\.lock_group_member_writes\(_group_id uuid\)'
        r'.*?pg_advisory_xact_lock',
      ).hasMatch(allMigrationsSql()),
      isTrue,
    );
  });
}
