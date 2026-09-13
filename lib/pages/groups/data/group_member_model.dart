class GroupMember {
  late String groupId;
  late String email;
  late String displayName;
  String? username;
  String? usernameCode;
  late bool isGuest;
  late bool isFavorite;

  /// When set, this member was removed from the group while still appearing on
  /// past expenses. Their `expense_entry_share` rows and the group's balance
  /// math are untouched — removal changes visibility only. Not `late`, so a
  /// GroupMember built without JSON is an active member.
  DateTime? removedAt;

  bool get isRemoved => removedAt != null;

  String get fullUsername => username != null && usernameCode != null
      ? '$username#$usernameCode'
      : displayName;

  void loadDataFromJson(Map<String, dynamic> json) {
    groupId = json["group_id"];
    email = json["email"];
    // Defensive: display_name is joined from the user table, not stored on the
    // membership row, so a deleted user (or a guest who never had a profile)
    // returns null while this row is otherwise intact. Members are parsed in a
    // loop inside the group fetch, so throwing here would fail the whole load.
    // Fall back to the email — it still identifies the person, and it is what
    // group_list.dart already shows for a blank name.
    displayName = json["display_name"] ?? email;
    username = json["username"];
    usernameCode = json["username_code"];
    isGuest = json["is_guest"];
    isFavorite = json["is_favorite"] ?? false;
    final removedAtRaw = json["removed_at"];
    removedAt = removedAtRaw == null
        ? null
        : DateTime.parse(removedAtRaw.toString());
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'email': email,
    'display_name': displayName,
    'username': username,
    'username_code': usernameCode,
    'is_guest': isGuest,
    'is_favorite': isFavorite,
    'removed_at': removedAt?.toIso8601String(),
  };
}
