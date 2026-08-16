import 'package:deun/helper/helper.dart';

import 'group_member_model.dart';

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

/// The writes an invite-link join may need, decided before anything is written.
class GroupJoinPlan {
  const GroupJoinPlan({
    required this.insertMembership,
    required this.clearRemovedAt,
    required this.mergeGuest,
  });

  /// The joiner has no `group_member` row yet — insert one.
  final bool insertMembership;

  /// The joiner has a soft-removed row — clear its `removed_at` instead of
  /// inserting, so their historical shares are neither touched nor duplicated.
  final bool clearRemovedAt;

  /// The joiner picked a guest placeholder to absorb: transfer that guest's
  /// expenses and shares, then drop the guest.
  final bool mergeGuest;
}

/// Plans a join from the joiner's own `group_member` row ([existingMembership],
/// null when they have none) and the guest they picked to merge
/// ([selectedGuestEmail], null = join as a brand-new member).
///
/// Pure: no Supabase. The guest merge is deliberately independent of the
/// membership write — a soft-removed member coming back through the invite link
/// may just as well be picking up a guest placeholder, and their merge must not
/// be skipped because their `group_member` row already exists.
GroupJoinPlan resolveGroupJoin({
  required Map<String, dynamic>? existingMembership,
  required String? selectedGuestEmail,
}) {
  return GroupJoinPlan(
    insertMembership: existingMembership == null,
    clearRemovedAt:
        existingMembership != null && existingMembership['removed_at'] != null,
    mergeGuest: selectedGuestEmail != null,
  );
}

/// Emails that must not be offered as "add" candidates in the group-member
/// search: everyone already in the submitted roster, the current user, and every
/// **removed** member. A removed member still has a `group_member` row, so the
/// add path would collide with it; they come back through the roster's explicit
/// "Add back" action, which clears `removed_at`.
Set<String> excludedCandidateEmails({
  required List<Map<String, dynamic>> submittedMembers,
  required String? currentUserEmail,
  required List<GroupMember> allMembers,
}) {
  return {
    ...submittedMembers.map((m) => (m['email'] as String?) ?? ''),
    currentUserEmail ?? '',
    ...allMembers.where((m) => m.isRemoved).map((m) => m.email),
  };
}
