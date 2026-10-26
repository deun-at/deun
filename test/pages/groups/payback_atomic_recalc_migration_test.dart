// payback-atomic-recalc: the newest `pay_back` and `pay_back_exact` definitions
// in supabase/migrations, read as source. The self-hosted instance is out of
// the build's reach; the behaviour is proven on the local harness
// (supabase/tests/rls_stopgap/50_pay_back_cases.sql).
//
// "Newest" = the last match in the newest file, by filename, that contains the
// function's own `create or replace function` header. `pay_back_exact`'s header
// and its `return public.pay_back(` call never count as a `pay_back` definition.
// Any later re-statement that drops the recalculation or a guard turns this red.

import 'package:flutter_test/flutter_test.dart';

import 'join_group_migration_source.dart';

const _payBackHeader = 'create or replace function public.pay_back(';
const _payBackExactHeader = 'create or replace function public.pay_back_exact(';

/// The newest definition of the function whose normalized header is [header]:
/// its file, its signature (header up to `as`) and its dollar-quoted body.
({String file, String signature, String body}) _newestDefinition(
  String header,
) {
  for (final file in migrationFiles().reversed) {
    final sql = normalizedSql(file.readAsStringSync());
    final at = sql.lastIndexOf(header);
    if (at < 0) continue;
    final open = RegExp(r'\bas (\$\w*\$)').firstMatch(sql.substring(at));
    if (open == null) throw StateError('no body after $header');
    final tag = open.group(1)!;
    final bodyStart = at + open.end;
    final bodyEnd = sql.indexOf(tag, bodyStart);
    if (bodyEnd < 0) throw StateError('unclosed $tag after $header');
    return (
      file: file.uri.pathSegments.last,
      signature: sql.substring(at, at + open.start),
      body: sql.substring(bodyStart, bodyEnd),
    );
  }
  throw StateError('no migration defines $header');
}

/// The statement in [body] that starts at [start], up to its `;`.
String _statement(String body, String start) {
  final at = body.indexOf(start);
  if (at < 0) throw StateError('no statement starting "$start"');
  return body.substring(at, body.indexOf(';', at));
}

void main() {
  late ({String file, String signature, String body}) payBack;
  late ({String file, String signature, String body}) payBackExact;

  setUpAll(() {
    payBack = _newestDefinition(_payBackHeader);
    payBackExact = _newestDefinition(_payBackExactHeader);
  });

  test(
    'pay_back recalculates the group after its last insert and before it returns',
    () {
      const recalc =
          'perform public.update_group_member_shares(_group_id, new_expense_id);';
      final body = payBack.body;
      final recalcAt = body.indexOf(recalc);

      expect(
        recalcAt,
        isNonNegative,
        reason: '${payBack.file} records a payback without its balance update',
      );
      expect(
        recalcAt,
        greaterThan(body.lastIndexOf('insert into ')),
        reason: 'the recalculation must see the payback it settles',
      );
      expect(
        recalcAt,
        lessThan(RegExp(r'\breturn\b').firstMatch(body)!.start),
        reason: 'pay_back must not return before recalculating',
      );
      // A handler would let the payback commit with its recalculation failed.
      expect(body, isNot(contains('exception when')));
    },
  );

  test('pay_back still refuses a bad payer or payee before any insert', () {
    final body = payBack.body;
    final firstInsert = body.indexOf('insert into ');
    const guards = [
      'if _paid_by is null or _paid_for is null then raise exception',
      'if _paid_by = _paid_for then raise exception',
      'if not exists (select 1 from public.group_member as gm '
          'where gm.group_id = _group_id and gm.email = _paid_by '
          'and gm.removed_at is null) then raise exception',
      'if not exists (select 1 from public.group_member as gm '
          'where gm.group_id = _group_id and gm.email = _paid_for '
          'and gm.removed_at is null) then raise exception',
    ];

    for (final guard in guards) {
      final at = body.indexOf(guard);
      expect(at, isNonNegative, reason: '${payBack.file} lost: $guard');
      expect(at, lessThan(firstInsert), reason: 'runs after a write: $guard');
    }
  });

  test('pay_back still stamps the recorder onto the payback row', () {
    final insert = _statement(payBack.body, 'insert into expense (');

    expect(insert, contains('is_paid_back_row, user_id) values ('));
    expect(insert, contains('true, auth.uid())'));
  });

  test('pay_back keeps the signature and return type the app calls', () {
    expect(
      payBack.signature,
      '$_payBackHeader'
      '_group_id uuid, _paid_by text, _paid_for text, _amount numeric) '
      'returns uuid language plpgsql ',
    );
  });

  test(
    'pay_back_exact records through pay_back and has no insert of its own',
    () {
      expect(payBackExact.body, contains('return public.pay_back('));
      expect(
        payBackExact.body,
        isNot(contains('insert into')),
        reason: '${payBackExact.file} writes a payback that skips pay_back',
      );
    },
  );
}
