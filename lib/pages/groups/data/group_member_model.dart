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
    displayName = json["display_name"];
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
