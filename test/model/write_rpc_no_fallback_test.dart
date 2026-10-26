// legacy-fallback-removal: a group save, an expense save and a claim change
// each write through their one server RPC or fail with that RPC's own error.
// No client-side multi-step fallback runs: a fallback would reach the
// FakeSupabaseClient and fail with a different error, turning these tests red.
// Every RPC goes through the repositories' constructor seams. No test reaches
// the network.

import 'package:deun/helper/currency.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/expenses/data/expense_draft.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/fake_supabase.dart';

/// A missing-function error as PostgREST (PGRST202) or Postgres (42883)
/// reports it.
PostgrestException _missing(String code) =>
    PostgrestException(message: 'Could not find the function', code: code);

GroupRepository _groups(
  Future<Object?> Function(Map<String, dynamic>) saveGroupAll,
) => GroupRepository(FakeSupabaseClient(), null, saveGroupAllRpc: saveGroupAll);

ExpenseRepository _expenses({
  Future<Object?> Function(Map<String, dynamic>)? saveExpenseAll,
  Future<Object?> Function(Map<String, dynamic>)? claimSetUnitShares,
}) => ExpenseRepository(
  FakeSupabaseClient(),
  null,
  saveExpenseAllRpc: saveExpenseAll,
  claimSetUnitSharesRpc: claimSetUnitShares,
);

void main() {
  late List<Map<String, dynamic>> calls;

  /// A seam that records every call and answers with [respond].
  Future<Object?> Function(Map<String, dynamic>) recorder(
    Object? Function() respond,
  ) => (params) async {
    calls.add(params);
    return respond();
  };

  setUp(() => calls = []);

  group('a group save goes through save_group_all alone', () {
    for (final code in ['PGRST202', '42883']) {
      test(
        'a missing save_group_all ($code) is thrown after that one call',
        () async {
          final missing = _missing(code);
          final groups = _groups(recorder(() => throw missing));

          await expectLater(
            groups.saveAll(null, {'name': 'Trip'}),
            throwsA(same(missing)),
          );
          expect(calls, hasLength(1));
        },
      );
    }

    test(
      'a successful save returns the id the RPC returned, after that one call',
      () async {
        final groups = _groups(recorder(() => 'g-new'));

        expect(await groups.saveAll(null, {'name': 'Trip'}), 'g-new');
        expect(calls, hasLength(1));
        expect((calls.single['_group'] as Map)['name'], 'Trip');
      },
    );
  });

  group('an expense save goes through save_expense_all alone', () {
    final notifications = NotificationSender(push: (request) async {});

    /// One equal-split line, as the editor hands it over.
    ExpenseDraft draft() => ExpenseDraft(
      name: 'Dinner',
      expenseDate: DateTime(2026, 10, 26),
      paidBy: 'a@test.com',
      entries: const [
        ExpenseEntryDraft(
          name: 'Dinner',
          unitPrice: 10,
          shares: {'a@test.com', 'b@test.com'},
        ),
      ],
    );

    Future<void> save(ExpenseRepository expenses, String? expenseId) =>
        expenses.saveAll(
          'g1',
          expenseId,
          draft(),
          currency: Currency.eur,
          notifications: notifications,
        );

    for (final code in ['PGRST202', '42883']) {
      test(
        'a missing save_expense_all ($code) is thrown after that one call',
        () async {
          final missing = _missing(code);
          final expenses = _expenses(
            saveExpenseAll: recorder(() => throw missing),
          );

          await expectLater(save(expenses, 'e1'), throwsA(same(missing)));
          expect(calls, hasLength(1));
        },
      );
    }

    test('a successful edit completes after that one call', () async {
      final expenses = _expenses(saveExpenseAll: recorder(() => 'e1'));

      await save(expenses, 'e1');
      expect(calls, hasLength(1));
      expect((calls.single['_expense'] as Map)['id'], 'e1');
    });

    test(
      'a successful create pushes the planned receivers and amount once',
      () async {
        final expenses = _expenses(saveExpenseAll: recorder(() => 'e-new'));
        final pushes = <PushRequest>[];

        await expenses.saveAll(
          'g1',
          null,
          draft(),
          currency: Currency.eur,
          notifications: NotificationSender(
            push: (request) async => pushes.add(request),
          ),
        );

        expect(calls, hasLength(1));
        expect(pushes, hasLength(1));
        expect(pushes.single.kind, PushKind.expenseCreated);
        expect(pushes.single.objectId, 'e-new');
        expect(pushes.single.receivers, {'a@test.com', 'b@test.com'});
        expect(pushes.single.amount, 10.0);
      },
    );
  });

  test(
    'a missing claim_set_unit_shares is thrown after that one call',
    () async {
      final missing = _missing('PGRST202');
      final expenses = _expenses(
        claimSetUnitShares: recorder(() => throw missing),
      );

      await expectLater(
        expenses.claimSetUnitShares(
          groupId: 'g1',
          expenseId: 'e1',
          unitEntryId: 'u1',
          claimerEmails: const ['a@test.com'],
        ),
        throwsA(same(missing)),
      );
      expect(calls, hasLength(1));
    },
  );
}
