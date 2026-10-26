// legacy-fallback-removal: a group save, an expense save and a claim change
// each write through their one server RPC or fail with that RPC's own error.
// No client-side multi-step fallback runs: a fallback would reach this local
// client, fail with a different error and turn these tests red. Every RPC
// goes through the repositories' @visibleForTesting seams. No test reaches the
// network.

import 'package:deun/helper/currency.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/expenses/data/expense_draft.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A missing-function error as PostgREST (PGRST202) or Postgres (42883)
/// reports it.
PostgrestException _missing(String code) =>
    PostgrestException(message: 'Could not find the function', code: code);

void main() {
  late List<Map<String, dynamic>> calls;

  /// A seam that records every call and answers with [respond].
  Future<Object?> Function(Map<String, dynamic>) recorder(
    Object? Function() respond,
  ) => (params) async {
    calls.add(params);
    return respond();
  };

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(() => calls = []);

  tearDown(() {
    GroupRepository.saveGroupAllOverride = null;
    ExpenseRepository.saveExpenseAllOverride = null;
    ExpenseRepository.claimSetUnitSharesOverride = null;
  });

  group('a group save goes through save_group_all alone', () {
    for (final code in ['PGRST202', '42883']) {
      test(
        'a missing save_group_all ($code) is thrown after that one call',
        () async {
          final missing = _missing(code);
          GroupRepository.saveGroupAllOverride = recorder(() => throw missing);

          await expectLater(
            GroupRepository.saveAll(null, {'name': 'Trip'}),
            throwsA(same(missing)),
          );
          expect(calls, hasLength(1));
        },
      );
    }

    test(
      'a successful save returns the id the RPC returned, after that one call',
      () async {
        GroupRepository.saveGroupAllOverride = recorder(() => 'g-new');

        expect(await GroupRepository.saveAll(null, {'name': 'Trip'}), 'g-new');
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

    Future<void> save(String? expenseId) => ExpenseRepository.saveAll(
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
          ExpenseRepository.saveExpenseAllOverride = recorder(
            () => throw missing,
          );

          await expectLater(save('e1'), throwsA(same(missing)));
          expect(calls, hasLength(1));
        },
      );
    }

    test('a successful edit completes after that one call', () async {
      ExpenseRepository.saveExpenseAllOverride = recorder(() => 'e1');

      await save('e1');
      expect(calls, hasLength(1));
      expect((calls.single['_expense'] as Map)['id'], 'e1');
    });

    test(
      'a successful create pushes the planned receivers and amount once',
      () async {
        ExpenseRepository.saveExpenseAllOverride = recorder(() => 'e-new');
        final pushes = <PushRequest>[];

        await ExpenseRepository.saveAll(
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
      ExpenseRepository.claimSetUnitSharesOverride = recorder(
        () => throw missing,
      );

      await expectLater(
        ExpenseRepository.claimSetUnitShares(
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
