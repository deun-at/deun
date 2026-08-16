import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/helper/currency.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
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

void main() {
  group('resolveMemberRemoval', () {
    // 1
    test('0.004 counts as settled — a member with history is soft-removed', () {
      expect(
        resolveMemberRemoval(
          balance: 0.004,
          hasExpenseHistory: true,
          currency: Currency.eur,
        ),
        MemberRemovalOutcome.softRemoved,
      );
    });

    // 2
    test('0.005 blocks, and names the outstanding amount', () {
      final outcome = resolveMemberRemoval(
        balance: 0.005,
        hasExpenseHistory: true,
        currency: Currency.eur,
      );

      expect(outcome, isA<MemberRemovalBlocked>());
      expect((outcome as MemberRemovalBlocked).outstanding, 0.005);
    });

    // 3
    test('-0.005 blocks too: the epsilon is symmetric in both signs', () {
      final owed = resolveMemberRemoval(
        balance: 0.005,
        hasExpenseHistory: false,
        currency: Currency.eur,
      );
      final owing = resolveMemberRemoval(
        balance: -0.005,
        hasExpenseHistory: false,
        currency: Currency.eur,
      );

      expect(owed, isA<MemberRemovalBlocked>());
      expect(owing, isA<MemberRemovalBlocked>());
      expect(
        (owing as MemberRemovalBlocked).outstanding,
        (owed as MemberRemovalBlocked).outstanding,
      );
    });

    // 4
    test('-0.004 with no expense history is a hard remove', () {
      expect(
        resolveMemberRemoval(
          balance: -0.004,
          hasExpenseHistory: false,
          currency: Currency.eur,
        ),
        MemberRemovalOutcome.hardRemoved,
      );
    });

    // 5
    test('an exactly zero balance with history is a soft remove', () {
      expect(
        resolveMemberRemoval(
          balance: 0,
          hasExpenseHistory: true,
          currency: Currency.eur,
        ),
        MemberRemovalOutcome.softRemoved,
      );
    });

    // 6
    test('an exactly zero balance with no history is a hard remove', () {
      expect(
        resolveMemberRemoval(
          balance: 0,
          hasExpenseHistory: false,
          currency: Currency.eur,
        ),
        MemberRemovalOutcome.hardRemoved,
      );
    });

    // 7
    test('a real debt blocks even when the member has no expense history', () {
      // Being owed money is enough to strand a debt; history is irrelevant here.
      final outcome = resolveMemberRemoval(
        balance: 12.5,
        hasExpenseHistory: false,
        currency: Currency.eur,
      );

      expect(outcome, isA<MemberRemovalBlocked>());
      expect((outcome as MemberRemovalBlocked).outstanding, 12.5);
    });

    // 8
    test(
      'outstanding is a magnitude, so the message never shows a minus sign',
      () {
        final outcome = resolveMemberRemoval(
          balance: -7.25,
          hasExpenseHistory: true,
          currency: Currency.eur,
        );

        expect((outcome as MemberRemovalBlocked).outstanding, 7.25);
      },
    );
  });

  group('resolveGroupJoin', () {
    // 28
    test(
      'a brand-new joiner inserts a membership and merges the picked guest',
      () {
        final plan = resolveGroupJoin(
          existingMembership: null,
          selectedGuestEmail: 'guest+1@guest.invalid',
        );

        expect(plan.insertMembership, isTrue);
        expect(plan.clearRemovedAt, isFalse);
        expect(plan.mergeGuest, isTrue);
      },
    );

    // 29
    test(
      'a removed member re-joining clears the marker, inserts nothing, and still merges the picked guest',
      () {
        // The bug this pins: the guest merge used to be nested inside the
        // "no membership row yet" branch, so a re-joining removed member who
        // picked a guest was sent into the group with the guest untouched — no
        // transfer, no error.
        final plan = resolveGroupJoin(
          existingMembership: const {
            'email': 'c@test.com',
            'removed_at': '2026-08-15T09:30:00Z',
          },
          selectedGuestEmail: 'guest+1@guest.invalid',
        );

        expect(plan.insertMembership, isFalse);
        expect(plan.clearRemovedAt, isTrue);
        expect(plan.mergeGuest, isTrue);
      },
    );

    // 30
    test('joining as a new member merges no guest', () {
      final plan = resolveGroupJoin(
        existingMembership: null,
        selectedGuestEmail: null,
      );

      expect(plan.insertMembership, isTrue);
      expect(plan.mergeGuest, isFalse);
    });

    // 31
    test('an active membership row is left alone', () {
      final plan = resolveGroupJoin(
        existingMembership: const {'email': 'a@test.com', 'removed_at': null},
        selectedGuestEmail: null,
      );

      expect(plan.insertMembership, isFalse);
      expect(plan.clearRemovedAt, isFalse);
      expect(plan.mergeGuest, isFalse);
    });
  });

  group('excludedCandidateEmails', () {
    // 9
    test('excludes every submitted member and the current user', () {
      final excluded = excludedCandidateEmails(
        submittedMembers: [
          {'email': 'a@test.com'},
          {'email': 'b@test.com'},
        ],
        currentUserEmail: 'me@test.com',
        allMembers: [_member('a@test.com'), _member('b@test.com')],
      );

      expect(
        excluded,
        containsAll(['a@test.com', 'b@test.com', 'me@test.com']),
      );
    });

    // 10
    test('excludes a removed member, so search cannot re-add them', () {
      final excluded = excludedCandidateEmails(
        submittedMembers: [
          {'email': 'a@test.com'},
        ],
        currentUserEmail: 'me@test.com',
        allMembers: [
          _member('a@test.com'),
          _member('c@test.com', removedAt: DateTime.utc(2026, 8, 15)),
        ],
      );

      expect(excluded, contains('c@test.com'));
    });

    // 11
    test('does not exclude an unrelated friend', () {
      final excluded = excludedCandidateEmails(
        submittedMembers: [
          {'email': 'a@test.com'},
        ],
        currentUserEmail: 'me@test.com',
        allMembers: [_member('a@test.com')],
      );

      expect(excluded, isNot(contains('sam@test.com')));
    });
  });
}
