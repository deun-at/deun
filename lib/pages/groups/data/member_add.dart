import 'package:deun/pages/users/user_model.dart';

import 'group_member_model.dart';

/// What adding one member to a group did, as `add_group_member` answers it.
/// The server decides from the member's current `group_member` row, under the
/// group's member-write lock, in the same transaction as the write.
enum MemberAddOutcome {
  /// No row at all — insert one.
  inserted,

  /// A soft-removed row — clear its `removed_at` instead of inserting, so the
  /// historical `expense_entry_share` rows are neither touched nor duplicated.
  reAdded,

  /// An active row already — write NOTHING and say so.
  alreadyMember,
}

/// Maps `add_group_member`'s answer to the outcome the Members page acts on.
/// Anything else throws a [FormatException], which the page's existing catch
/// turns into the add-error snackbar instead of a silent success.
MemberAddOutcome memberAddOutcomeFromRpc(Object? answer) => switch (answer) {
  'inserted' => MemberAddOutcome.inserted,
  're_added' => MemberAddOutcome.reAdded,
  'already_member' => MemberAddOutcome.alreadyMember,
  _ => throw FormatException('add_group_member: unrecognised answer', answer),
};

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
/// only way back is to find them in search, and `add_group_member` now turns
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
