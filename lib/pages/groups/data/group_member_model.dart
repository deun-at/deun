class GroupMember {
  late String groupId;
  late String email;
  late String displayName;
  late bool isGuest;
  late bool isFavorite;

  void loadDataFromJson(Map<String, dynamic> json) {
    groupId = json["group_id"];
    email = json["email"];
    displayName = json["display_name"];
    isGuest = json["is_guest"];
    isFavorite = json["is_favorite"] ?? false;
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'email': email,
        'display_name': displayName,
        'is_guest': isGuest,
        'is_favorite': isFavorite,
      };
}
