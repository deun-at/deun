import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/member_add.dart';
import 'package:flutter_test/flutter_test.dart';

GroupMember _member(String email, {DateTime? removedAt}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = email;
  m.isGuest = false;
  m.isFavorite = false;
  m.removedAt = removedAt;
  return m;
}

Map<String, dynamic> _memberJson(String email) => {
  'group_id': 'g1',
  'email': email,
  'display_name': email,
  'username': null,
  'username_code': null,
  'is_guest': false,
  'is_favorite': false,
  'removed_at': null,
};

/// A group with three members (a/b/c), where a owes 12.5 and b is owed 12.5.
Map<String, dynamic> groupJson() => {
  'id': 'g1',
  'name': 'Trip',
  'color_value': 0xFF000000,
  'simplified_expenses': false,
  'created_at': '',
  'user_id': null,
  'currency_code': 'EUR',
  'group_member': [
    _memberJson('a@test.com'),
    _memberJson('b@test.com'),
    _memberJson('c@test.com'),
  ],
  'group_shares_summary': [
    {
      'paid_for': 'a@test.com',
      'total_share_amount': -12.5,
      'paid_by': 'b@test.com',
      'share_amount': 12.5,
      'total_expenses': 12.5,
    },
    {
      'paid_for': 'b@test.com',
      'total_share_amount': 12.5,
      'paid_by': 'a@test.com',
      'share_amount': 12.5,
      'total_expenses': 12.5,
    },
    {'paid_for': 'c@test.com', 'total_share_amount': 0, 'paid_by': null},
  ],
};

void main() {
  group('resolveMemberAdd', () {
    test('no membership row at all inserts one', () {
      expect(
        resolveMemberAdd(existingMembership: null),
        MemberAddOutcome.inserted,
      );
    });

    test('a soft-removed row is a re-add, not an insert', () {
      expect(
        resolveMemberAdd(
          existingMembership: {
            'email': 'carol@test.com',
            'removed_at': '2026-08-15T09:30:00Z',
          },
        ),
        MemberAddOutcome.reAdded,
        reason: 'clearing removed_at leaves the historical shares untouched',
      );
    });

    test('an active row is already a member: nothing to write', () {
      expect(
        resolveMemberAdd(
          existingMembership: {'email': 'ann@test.com', 'removed_at': null},
        ),
        MemberAddOutcome.alreadyMember,
      );
    });
  });

  group('shouldNotifyAddedMember', () {
    test('a real user who joined (inserted) is notified', () {
      expect(
        shouldNotifyAddedMember(
          outcome: MemberAddOutcome.inserted,
          isGuest: false,
        ),
        isTrue,
      );
    });

    test('a real user who re-joined (reAdded) is notified', () {
      expect(
        shouldNotifyAddedMember(
          outcome: MemberAddOutcome.reAdded,
          isGuest: false,
        ),
        isTrue,
      );
    });

    test('a guest is never notified, even when inserted', () {
      expect(
        shouldNotifyAddedMember(
          outcome: MemberAddOutcome.inserted,
          isGuest: true,
        ),
        isFalse,
      );
    });

    test('an already-member add announces nothing', () {
      expect(
        shouldNotifyAddedMember(
          outcome: MemberAddOutcome.alreadyMember,
          isGuest: false,
        ),
        isFalse,
      );
    });
  });

  group('addCandidateExclusions', () {
    test('excludes the active roster and the current user', () {
      final excluded = addCandidateExclusions(
        members: [_member('ann@test.com'), _member('bob@test.com')],
        currentUserEmail: 'me@test.com',
      );
      expect(excluded, {'ann@test.com', 'bob@test.com', 'me@test.com'});
    });

    test('does NOT exclude a soft-removed member — search is the way back', () {
      final excluded = addCandidateExclusions(
        members: [
          _member('ann@test.com'),
          _member('carol@test.com', removedAt: DateTime.utc(2026, 8, 15)),
        ],
        currentUserEmail: 'me@test.com',
      );
      expect(excluded, {'ann@test.com', 'me@test.com'});
      expect(excluded, isNot(contains('carol@test.com')));
    });

    test('a null current user contributes no empty-string entry', () {
      final excluded = addCandidateExclusions(
        members: [_member('ann@test.com')],
        currentUserEmail: null,
      );
      expect(excluded, {'ann@test.com'});
      expect(excluded, isNot(contains('')));
    });

    test('an empty-string current user contributes no empty-string entry', () {
      final excluded = addCandidateExclusions(
        members: [_member('ann@test.com')],
        currentUserEmail: '',
      );
      expect(excluded, {'ann@test.com'});
      expect(excluded, isNot(contains('')));
    });
  });

  group('Group.memberBalances / isSolo', () {
    test('memberBalances keys every member by their own net share amount', () {
      final g = Group()..loadDataFromJson(groupJson());
      expect(g.memberBalances['a@test.com'], -12.5);
      expect(g.memberBalances['b@test.com'], 12.5);
      expect(g.memberBalances['c@test.com'], 0);
    });

    test('a group with no summary rows reads all-zero, not null', () {
      final g = Group()
        ..loadDataFromJson({...groupJson(), 'group_shares_summary': null});
      expect(g.memberBalances, isEmpty);
      expect(g.memberBalances['a@test.com'] ?? 0, 0);
    });

    test('a Group built without JSON reads all-zero, not throwing', () {
      final g = Group();
      expect(g.memberBalances, isEmpty);
    });

    test('isSolo is true for a creator-only group', () {
      final g = Group();
      g.groupMembers = [_member('me@test.com')];
      expect(g.isSolo, isTrue);
    });

    test('isSolo is false once a second active member joins', () {
      final g = Group();
      g.groupMembers = [_member('me@test.com'), _member('ann@test.com')];
      expect(g.isSolo, isFalse);
    });

    test('isSolo is true again when the only other member is soft-removed', () {
      final g = Group();
      g.groupMembers = [
        _member('me@test.com'),
        _member('ann@test.com', removedAt: DateTime.utc(2026, 8, 15)),
      ];
      expect(g.isSolo, isTrue);
    });
  });
}
