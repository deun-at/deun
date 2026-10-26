// injectable-repositories: a model is told whom it is parsed for, so the same
// row gives each user their own figures.

import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helper/two_user_fixtures.dart';

Map<String, double> _counterparties(Group group) => {
  for (final entry in group.groupSharesSummary.entries)
    entry.key: entry.value.shareAmount,
};

void main() {
  test(
    'the same group row gives each member their own balance and counterparties',
    () {
      for (final simplified in [false, true]) {
        final row = sharedGroupRow(simplifiedExpenses: simplified);
        final forAnn = Group()..loadDataFromJson(row, currentUserEmail: ann);
        final forBob = Group()..loadDataFromJson(row, currentUserEmail: bob);

        expect(forAnn.totalShareAmount, 10, reason: 'simplified: $simplified');
        expect(_counterparties(forAnn), {
          bob: 10.0,
        }, reason: 'simplified: $simplified');
        expect(forBob.totalShareAmount, -10, reason: 'simplified: $simplified');
        expect(_counterparties(forBob), {
          ann: -10.0,
        }, reason: 'simplified: $simplified');
      }
    },
  );

  test(
    "an expense row's embedded group carries the parsing user's figures",
    () {
      final row = {
        'id': 'e1',
        'group_id': 'g1',
        'name': 'Dinner',
        'expense_date': '2026-01-01',
        'paid_by': ann,
        'created_at': '',
        'is_paid_back_row': false,
        'category': null,
        'expense_entry': const <Map<String, dynamic>>[],
        'group': sharedGroupRow(),
      };
      final forAnn = Expense()..loadDataFromJson(row, currentUserEmail: ann);
      final forBob = Expense()..loadDataFromJson(row, currentUserEmail: bob);

      expect(forAnn.group.totalShareAmount, 10);
      expect(_counterparties(forAnn.group), {bob: 10.0});
      expect(forBob.group.totalShareAmount, -10);
      expect(_counterparties(forBob.group), {ann: -10.0});
    },
  );

  test('a friendship row names the other side as the friend', () {
    final forRequester = Friendship()
      ..loadDataFromJson(annBobFriendshipRow(), currentUserEmail: ann);
    final forAddressee = Friendship()
      ..loadDataFromJson(annBobFriendshipRow(), currentUserEmail: bob);

    expect(forRequester.user.email, bob);
    expect(forRequester.isIncomingRequest, isFalse);
    expect(forAddressee.user.email, ann);
    expect(forAddressee.isIncomingRequest, isTrue);
  });
}
