/// A member whose user row is gone must not take down the list they appear in.
///
/// `display_name` does not come from the membership row — it is joined from the
/// user table (`...email(display_name:display_name)` on shares,
/// `...user(display_name:display_name, ...)` on members). A deleted user, or a
/// guest who never had a profile, yields a null while the owning row itself is
/// intact and still carries the email.
///
/// Both models declare `late String displayName`, so that null threw a
/// TypeError mid-parse. Members and shares are parsed in loops nested inside
/// the group fetch, so one of them failed the whole load — the same shape as
/// the null expense name in [expense_name_fallback_test.dart].
///
/// The fallback is the email rather than an empty string: it still identifies
/// the person, and it is what group_list.dart already shows when a display name
/// is blank.
library;

import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _memberRow({required Object? displayName}) => {
  'group_id': 'g1',
  'email': 'alice@test.com',
  'display_name': displayName,
  'is_guest': false,
  'is_favorite': false,
};

Map<String, dynamic> _shareRow({required Object? displayName}) => {
  'expense_entry_id': 'ee1',
  'email': 'bob@test.com',
  'display_name': displayName,
  'percentage': 50.0,
  'is_locked': false,
  'created_at': '2026-01-10T10:00:00',
};

void main() {
  group('GroupMember.displayName tolerates a deleted user row', () {
    test('a null display name falls back to the email', () {
      final member = GroupMember();

      expect(
        () => member.loadDataFromJson(_memberRow(displayName: null)),
        returnsNormally,
      );
      expect(member.displayName, 'alice@test.com');
    });

    test('an absent display_name key falls back to the email', () {
      final json = _memberRow(displayName: null)..remove('display_name');
      final member = GroupMember();

      expect(() => member.loadDataFromJson(json), returnsNormally);
      expect(member.displayName, 'alice@test.com');
    });

    test('a real display name is untouched', () {
      final member = GroupMember()
        ..loadDataFromJson(_memberRow(displayName: 'Alice'));

      expect(member.displayName, 'Alice');
    });

    test('fullUsername still reads the fallback when no username is set', () {
      final member = GroupMember()
        ..loadDataFromJson(_memberRow(displayName: null));

      // fullUsername defers to displayName without a username/code pair, so it
      // must not surface a null either.
      expect(member.fullUsername, 'alice@test.com');
    });
  });

  group('ExpenseEntryShare.displayName tolerates a deleted user row', () {
    test('a null display name falls back to the email', () {
      final share = ExpenseEntryShare();

      expect(
        () => share.loadDataFromJson(_shareRow(displayName: null)),
        returnsNormally,
      );
      expect(share.displayName, 'bob@test.com');
    });

    test('a real display name is untouched', () {
      final share = ExpenseEntryShare()
        ..loadDataFromJson(_shareRow(displayName: 'Bob'));

      expect(share.displayName, 'Bob');
    });

    test('one share with no display name does not fail the others', () {
      final rows = [
        _shareRow(displayName: 'Alice'),
        _shareRow(displayName: null),
        _shareRow(displayName: 'Carol'),
      ];

      final parsed = rows.map(
        (json) => ExpenseEntryShare()..loadDataFromJson(json),
      );

      expect(parsed.map((s) => s.displayName), [
        'Alice',
        'bob@test.com',
        'Carol',
      ]);
    });
  });
}
