import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';

/// What removing a member from a group should do, decided before anything is
/// written. `blocked` carries the amount to name in the message.
sealed class MemberRemovalOutcome {
  const MemberRemovalOutcome();

  /// The member still owes, or is still owed, [outstanding] in the group. Nothing
  /// may be written; the caller surfaces the amount.
  const factory MemberRemovalOutcome.blocked({required double outstanding}) =
      MemberRemovalBlocked;

  /// Settled, but they appear on at least one expense: keep the `group_member`
  /// row and stamp `removed_at`, so every `expense_entry_share` row of theirs
  /// keeps a member behind it and no balance moves.
  static const MemberRemovalOutcome softRemoved = MemberRemovalSoftRemoved();

  /// Settled and involved in no expense at all: delete the `group_member` row
  /// outright — a tombstone would only clutter the roster.
  static const MemberRemovalOutcome hardRemoved = MemberRemovalHardRemoved();
}

class MemberRemovalBlocked extends MemberRemovalOutcome {
  const MemberRemovalBlocked({required this.outstanding});

  /// Magnitude of the unsettled balance (never negative), in the group currency.
  final double outstanding;
}

class MemberRemovalSoftRemoved extends MemberRemovalOutcome {
  const MemberRemovalSoftRemoved();
}

class MemberRemovalHardRemoved extends MemberRemovalOutcome {
  const MemberRemovalHardRemoved();
}

/// Maps `remove_group_member`'s answer (`{outcome, outstanding}`) to the outcome
/// the Members page acts on. `outstanding` arrives as a JSON number (int or
/// double). Anything else throws a [FormatException], which the page's existing
/// catch turns into the remove-error snackbar instead of a silent success.
MemberRemovalOutcome memberRemovalOutcomeFromRpc(Object? answer) =>
    switch (answer) {
      {'outcome': 'blocked', 'outstanding': final num outstanding} =>
        MemberRemovalOutcome.blocked(outstanding: outstanding.toDouble()),
      {'outcome': 'soft_removed'} => MemberRemovalOutcome.softRemoved,
      {'outcome': 'hard_removed'} => MemberRemovalOutcome.hardRemoved,
      _ => throw FormatException(
        'remove_group_member: unrecognised answer',
        answer,
      ),
    };

/// Decides the removal outcome from the member's net group [balance] (signed:
/// negative = they owe) and whether they appear on any expense in the group.
///
/// Pure: no Supabase, no context, no clock. The unsettled test is symmetric in
/// the sign of [balance] — being owed money strands a debt just as being in debt
/// does.
MemberRemovalOutcome resolveMemberRemoval({
  required double balance,
  required bool hasExpenseHistory,
  required Currency currency,
}) {
  if (!isSettled(balance, currency)) {
    return MemberRemovalOutcome.blocked(outstanding: balance.abs());
  }
  return hasExpenseHistory
      ? MemberRemovalOutcome.softRemoved
      : MemberRemovalOutcome.hardRemoved;
}

/// What the invite-link join page needs to know before anything is written:
/// whether the signed-in user is already an active member (then the page goes
/// straight to the group), and which guest placeholders they may claim.
class GroupJoinState {
  const GroupJoinState({
    required this.isActiveMember,
    required this.joinableGuests,
  });

  /// The user has a `group_member` row with no `removed_at`. A soft-removed
  /// member is NOT active: they stay on the join page so they can re-join.
  final bool isActiveMember;

  /// The group's active guest members — never a soft-removed guest, never a
  /// real user, never the joiner.
  final List<GroupMember> joinableGuests;
}

/// Decides the join state from [roster] (any mix of the group's members) and
/// the signed-in [currentEmail] (null when nobody is signed in).
///
/// Pure: no Supabase. The writes themselves are decided server-side by
/// `join_group`, which applies the same rules (guest must be an active
/// `is_guest` member; a soft-removed joiner is re-activated).
GroupJoinState resolveGroupJoinState({
  required List<GroupMember> roster,
  required String? currentEmail,
}) => GroupJoinState(
  isActiveMember:
      currentEmail != null &&
      roster.any((m) => m.email == currentEmail && !m.isRemoved),
  joinableGuests: [
    for (final m in roster)
      if (m.isGuest && !m.isRemoved && m.email != currentEmail) m,
  ],
);
