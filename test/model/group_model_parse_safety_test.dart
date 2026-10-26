import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Deliberately never initialises Supabase: the current-user lookup inside
// `Group.loadDataFromJson`'s guard then throws, which is the reachable way to
// force a failed summary calculation (group-model-parse-safety).

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
      ..loadDataFromJson(_groupJson(simplifiedExpenses: null));
    expect(group.simplifiedExpenses, isFalse);
    expect(group.groupMembers.map((m) => m.email), ['a@test.com']);
  });

  test('a failed summary calculation still leaves readable defaults', () {
    final failed = Group()..loadDataFromJson(_groupJson());
    expect(failed.groupSharesSummary, isEmpty);
    expect(failed.totalExpenses, 0);
    expect(failed.totalShareAmount, 0);

    final named = Group()..totalShareAmount = -12.34;
    expect(GroupRepository.narrowToStatus([named, failed], 'active'), [named]);
  });
}
