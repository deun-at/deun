import 'package:deun/helper/currency.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('resolveGroupJoinState', () {
    GroupMember member(
      String email, {
      bool isGuest = false,
      DateTime? removedAt,
    }) => GroupMember()
      ..groupId = 'g1'
      ..email = email
      ..displayName = email
      ..isGuest = isGuest
      ..isFavorite = false
      ..removedAt = removedAt;

    // 28
    test(
      'offers exactly the active guests: never a soft-removed guest, never a real user',
      () {
        final state = resolveGroupJoinState(
          roster: [
            member('ann@test.com'),
            member('guest+1@guest.invalid', isGuest: true),
            member(
              'guest+2@guest.invalid',
              isGuest: true,
              removedAt: DateTime.utc(2026, 8, 15),
            ),
          ],
          currentEmail: 'me@test.com',
        );

        expect(state.joinableGuests.map((m) => m.email), [
          'guest+1@guest.invalid',
        ]);
      },
    );

    // 29
    test('an active member of the group is already in', () {
      final state = resolveGroupJoinState(
        roster: [member('me@test.com')],
        currentEmail: 'me@test.com',
      );

      expect(state.isActiveMember, isTrue);
    });

    // 30
    test('a soft-removed member is not in, so they can re-join', () {
      final state = resolveGroupJoinState(
        roster: [member('me@test.com', removedAt: DateTime.utc(2026, 8, 15))],
        currentEmail: 'me@test.com',
      );

      expect(state.isActiveMember, isFalse);
    });

    // 31
    test('no own row, or nobody signed in, is not a member', () {
      final roster = [member('ann@test.com')];

      expect(
        resolveGroupJoinState(
          roster: roster,
          currentEmail: 'me@test.com',
        ).isActiveMember,
        isFalse,
      );
      expect(
        resolveGroupJoinState(
          roster: roster,
          currentEmail: null,
        ).isActiveMember,
        isFalse,
      );
    });
  });
}
