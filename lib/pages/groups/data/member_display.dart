import 'group_member_model.dart';

/// How every surface names a group member. The signed-in user reads
/// [youLabel]; anyone else reads their display name from the FULL roster, so a
/// soft-removed member keeps their name on past expenses; an email that is not
/// on the roster reads as that email. With nobody signed in, nobody is "You".
///
/// [pickerMembers] (active members only — group-member-removal's rule for
/// pickers) and [rosterMembers] (everyone) share one order: the signed-in user
/// first, then by `fullUsername`.
class MemberDisplay {
  MemberDisplay({
    required this.currentUserEmail,
    required this.youLabel,
    required List<GroupMember> roster,
  }) : _roster = roster;

  final String? currentUserEmail;
  final String youLabel;
  final List<GroupMember> _roster;

  bool isYou(String? email) =>
      email != null && email.isNotEmpty && email == currentUserEmail;

  /// '' only for a null email.
  String nameOf(String? email) {
    if (email == null) return '';
    if (isYou(email)) return youLabel;
    for (final member in _roster) {
      if (member.email == email) return member.displayName;
    }
    return email;
  }

  late final List<GroupMember> rosterMembers = [..._roster]
    ..sort((a, b) {
      if (isYou(a.email)) return -1;
      if (isYou(b.email)) return 1;
      return a.fullUsername.compareTo(b.fullUsername);
    });

  late final List<GroupMember> pickerMembers = [
    for (final member in rosterMembers)
      if (!member.isRemoved) member,
  ];
}
