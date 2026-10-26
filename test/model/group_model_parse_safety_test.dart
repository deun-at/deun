import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// The current user is a parameter of `Group.loadDataFromJson` now, so nothing
// reachable forces its guard to fail. The guard case reads a Group whose
// summary calculation never ran: at the old head the failing global read was
// the guard's first statement, so those are exactly the fields a failed run
// leaves (group-model-parse-safety; injectable-repositories, Decisions).

Map<String, dynamic> _groupJson({Object? simplifiedExpenses = false}) => {
  'id': 'g1',
  'name': 'Trip',
  'color_value': 0xFF000000,
  'simplified_expenses': simplifiedExpenses,
  'created_at': '',
  'user_id': null,
  'currency_code': 'EUR',
  'group_member': [
    {
      'group_id': 'g1',
      'email': 'a@test.com',
      'display_name': 'a',
      'username': null,
      'username_code': null,
      'is_guest': false,
      'is_favorite': false,
      'removed_at': null,
    },
  ],
  'group_shares_summary': [
    {
      'paid_by': 'a@test.com',
      'paid_for': 'a@test.com',
      'share_amount': 0,
      'total_expenses': 12.5,
      'total_share_amount': -12.5,
    },
  ],
};

void main() {
  test('a null simplified_expenses loads as false', () {
    final group = Group()
      ..loadDataFromJson(
        _groupJson(simplifiedExpenses: null),
        currentUserEmail: null,
      );
    expect(group.simplifiedExpenses, isFalse);
    expect(group.groupMembers.map((m) => m.email), ['a@test.com']);
  });

  test('a failed summary calculation still leaves readable defaults', () {
    final failed = Group();
    expect(failed.groupSharesSummary, isEmpty);
    expect(failed.totalExpenses, 0);
    expect(failed.totalShareAmount, 0);

    final named = Group()..totalShareAmount = -12.34;
    expect(GroupRepository.narrowToStatus([named, failed], 'active'), [named]);
  });
}
