import 'package:deun/pages/users/user_model.dart';

import 'group_member_model.dart';

/// What adding one member to a group must write, decided before anything is
/// written, from that member's CURRENT `group_member` row.
enum MemberAddOutcome {
  /// No row at all — insert one.
  inserted,

  /// A soft-removed row — clear its `removed_at` instead of inserting, so the
  /// historical `expense_entry_share` rows are neither touched nor duplicated.
  reAdded,

  /// An active row already — write NOTHING and say so.
  alreadyMember,
}

/// Decides the add outcome from the target's own `group_member` row
/// ([existingMembership], null when they have none).
///
/// Pure: no Supabase. Same shape as [resolveGroupJoin] and for the same reason —
/// the decision is made once, in one place, and the write path only applies it.
MemberAddOutcome resolveMemberAdd({
  required Map<String, dynamic>? existingMembership,
}) {
  if (existingMembership == null) return MemberAddOutcome.inserted;
  return existingMembership['removed_at'] != null
      ? MemberAddOutcome.reAdded
      : MemberAddOutcome.alreadyMember;
}

/// Whether an add pushes the "you were added to a group" notification: only a
/// real user (a guest carries no device) who actually joined (an
/// already-member add wrote nothing, so there is nothing to announce).
///
/// Replaces `GroupRepository.resolveNotificationReceivers`, whose receiver-SET
/// only made sense while a group save submitted a whole roster at once.
bool shouldNotifyAddedMember({
  required MemberAddOutcome outcome,
  required bool isGuest,
}) => !isGuest && outcome != MemberAddOutcome.alreadyMember;

/// Emails the Members page must not offer as add candidates: the group's ACTIVE
/// roster plus the current user.
///
/// Replaces `excludedCandidateEmails`, which also excluded **removed** members
/// because the old form's add path would have collided with their surviving row.
/// The design session reversed that: a soft-removed person is invisible, so the
/// only way back is to find them in search, and [resolveMemberAdd] now turns
/// that collision into a `reAdded` rather than a failed insert.
Set<String> addCandidateExclusions({
  required List<GroupMember> members,
  required String? currentUserEmail,
}) => {
  for (final member in members)
    if (!member.isRemoved) member.email,
  if (currentUserEmail != null && currentUserEmail.isNotEmpty) currentUserEmail,
};

/// The two result sections the Members page renders for one query.
class MemberSearchResults {
  const MemberSearchResults({required this.friends, required this.otherUsers});

  final List<SupaUser> friends;
  final List<SupaUser> otherUsers;

  bool get isEmpty => friends.isEmpty && otherUsers.isEmpty;
}
