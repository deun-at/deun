class GroupMember {
  late String groupId;
  late String email;
  late String displayName;
  String? username;
  String? usernameCode;
  late bool isGuest;
  late bool isFavorite;

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
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'email': email,
        'display_name': displayName,
        'username': username,
        'username_code': usernameCode,
        'is_guest': isGuest,
        'is_favorite': isFavorite,
      };
}
