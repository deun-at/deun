// group-write-rpcs: the four group-write RPCs, read as source. The behaviour is
// proven on the local harness (supabase/tests/rls_stopgap/60_group_write_cases.sql);
// these pin the statements and their order, so a later re-statement that drops
// a guard, a lock or a recalculation turns red.

import 'package:flutter_test/flutter_test.dart';

import 'join_group_migration_source.dart';

const _recalc =
    'perform public.update_group_member_shares(_group_id, null::uuid);';

/// Text between `public.<fn>(` and its `as $<fn>$`: arguments, return type and
/// attributes.
String _header(String sql, String fn) {
  final match = RegExp(
    'create or replace function public\\.$fn\\((.*?) as \\\$$fn\\\$',
  ).firstMatch(sql);
  if (match == null) throw StateError('$fn is not defined');
  return match.group(1)!;
}

void main() {
  late String sql;
  late String add;
  late String remove;

  setUpAll(() {
    sql = migrationSqlBySuffix('_group_write_rpcs.sql');
    add = functionBody(sql, 'add_group_member');
    remove = functionBody(sql, 'remove_group_member');
  });

  test(
    'an unsettled member, owing or owed, is blocked with the magnitude before any group_member write',
    () {
      const read =
          'select gss.total_share_amount into _balance '
          'from public.group_shares_summary as gss '
          'where gss.group_id = _group_id and gss.paid_for = _email limit 1; '
          '_balance := coalesce(_balance, 0);';
      const blocked =
          'if abs(_balance) >= _settled_epsilon then '
          "return jsonb_build_object('outcome', 'blocked', 'outstanding', abs(_balance)); "
          'end if;';

      final readAt = remove.indexOf(read);
      final blockedAt = remove.indexOf(blocked);
      final firstWrite = RegExp(
        r'update public\.group_member|delete from public\.group_member',
      ).firstMatch(remove)!.start;

      expect(readAt, isNonNegative, reason: 'one summary row, 0 when none');
      expect(blockedAt, greaterThan(readAt));
      expect(blockedAt, lessThan(firstWrite));
      expect(
        remove,
        isNot(contains('sum(')),
        reason: 'total_share_amount repeats on every row of the member',
      );
    },
  );

  test(
    'history is a payment or a share in this group; it soft-removes, and only its absence deletes',
    () {
      expect(
        remove,
        contains(
          '_has_history := exists (select 1 from public.expense as e '
          'where e.group_id = _group_id and e.paid_by = _email) '
          'or exists (select 1 from public.expense_entry_share as s '
          'join public.expense_entry as ee on ee.id = s.expense_entry_id '
          'join public.expense as e on e.id = ee.expense_id '
          'where e.group_id = _group_id and s.email = _email);',
        ),
      );

      final branch = RegExp(
        r'if _has_history then (.*?) else (.*?) end if;',
      ).firstMatch(remove);
      expect(branch, isNotNull);
      final soft = branch!.group(1)!;
      final hard = branch.group(2)!;

      expect(
        soft,
        contains(
          'update public.group_member set removed_at = now() '
          'where group_id = _group_id and email = _email and removed_at is null;',
        ),
      );
      expect(soft, isNot(contains('delete')));
      expect(
        hard,
        contains(
          'delete from public.group_member '
          'where group_id = _group_id and email = _email;',
        ),
      );
      expect(hard, isNot(contains('update')));
      expect('delete from '.allMatches(remove), hasLength(1));
      expect('update public.'.allMatches(remove), hasLength(1));
    },
  );

  test(
    'member writes on one group never interleave, and a removal reads only after in-flight expense writes',
    () {
      for (final body in [add, remove]) {
        expect(
          RegExp(
            r'^\s*declare .*? begin perform public\.lock_group_member_writes\(_group_id\);',
          ).hasMatch(body),
          isTrue,
          reason: 'the member-write lock is the first statement',
        );
      }
      for (final fn in ['add_group_member', 'remove_group_member']) {
        expect(
          RegExp(r'\b(stable|immutable)\b').hasMatch(_header(sql, fn)),
          isFalse,
          reason: '$fn: every statement after the lock needs a fresh snapshot',
        );
      }

      const locks =
          'lock table public.expense in share mode; '
          'lock table public.expense_entry_share in share mode;';
      final locksAt = remove.indexOf(locks);
      expect(locksAt, isNonNegative);
      expect(
        locksAt,
        lessThan(remove.indexOf('from public.group_shares_summary')),
      );
      expect(locksAt, lessThan(remove.indexOf('from public.expense ')));
      expect(
        locksAt,
        lessThan(remove.indexOf('from public.expense_entry_share ')),
      );

      // The lock is the one guest-merge-rpc created; redefining it here could
      // change its key and let join_group interleave with these writes.
      expect(sql, isNot(contains('function public.lock_group_member_writes')));
    },
  );

  test(
    'add: a soft-removed row is cleared, an active row writes nothing, anyone else gets one non-favourite row',
    () {
      const lookup =
          'select gm.removed_at into _removed_at from public.group_member as gm '
          'where gm.group_id = _group_id and gm.email = _email;';
      final branch = RegExp(
        r'if not found then (.*?) elsif _removed_at is not null then (.*?) else (.*?) end if;',
      ).firstMatch(add);
      expect(branch, isNotNull);

      final lookupAt = add.indexOf(lookup);
      expect(lookupAt, isNonNegative);
      expect(lookupAt, lessThan(branch!.start));
      expect(
        branch.group(1),
        contains(
          'insert into public.group_member (group_id, email, is_favorite) '
          'values (_group_id, _email, false);',
        ),
      );
      expect(
        branch.group(2),
        contains(
          'update public.group_member set removed_at = null '
          'where group_id = _group_id and email = _email and removed_at is not null;',
        ),
      );
      expect(branch.group(2), isNot(contains('insert')));
      expect(branch.group(3), "return 'already_member';");
      expect('insert into '.allMatches(add), hasLength(1));
      expect('update public.'.allMatches(add), hasLength(1));
    },
  );

  test(
    'every add or removal that wrote recalculates once, after its write; already-member and blocked do not',
    () {
      for (final body in [add, remove]) {
        expect(_recalc.allMatches(body), hasLength(1));
        final recalcAt = body.indexOf(_recalc);
        final lastWrite = RegExp(
          r'insert into |update public\.|delete from ',
        ).allMatches(body).last.end;
        expect(recalcAt, greaterThan(lastWrite));
        // The four write answers leave only through the return after the recalc.
        expect(body.substring(recalcAt), startsWith('$_recalc return '));
        expect(RegExp(r'\breturn\b').allMatches(body), hasLength(2));
        expect(
          body,
          isNot(contains('exception when')),
          reason: 'a handler would let the write commit without its recalc',
        );
      }
      expect(
        add.indexOf("return 'already_member';"),
        lessThan(add.indexOf(_recalc)),
      );
      expect(
        remove.indexOf("'outcome', 'blocked'"),
        lessThan(remove.indexOf(_recalc)),
      );
    },
  );

  test(
    'delete_expense deletes the expense in its group, then its checker row, then recalculates with a null expense id',
    () {
      final body = functionBody(sql, 'delete_expense');
      const steps = [
        'delete from public.expense where id = _expense_id and group_id = _group_id;',
        'delete from public.expense_update_checker '
            'where expense_id = _expense_id and group_id = _group_id;',
        _recalc,
      ];
      var at = -1;
      for (final step in steps) {
        final next = body.indexOf(step);
        expect(next, greaterThan(at), reason: 'missing or out of order: $step');
        at = next;
      }
      expect(body, isNot(contains('exception when')));
    },
  );

  test(
    'delete_group deletes the group, then its checker row, and never recalculates',
    () {
      final body = functionBody(sql, 'delete_group');
      final groupAt = body.indexOf(
        'delete from public."group" where id = _group_id;',
      );
      expect(groupAt, isNonNegative);
      expect(
        body.indexOf(
          'delete from public.group_update_checker where group_id = _group_id;',
        ),
        greaterThan(groupAt),
      );
      expect(body, isNot(contains('update_group_member_shares')));
    },
  );

  test(
    'none of the four is security definer, so RLS decides as it did for the direct statements',
    () {
      expect(sql, isNot(contains('security definer')));
    },
  );
}
