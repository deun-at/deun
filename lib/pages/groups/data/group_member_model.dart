class GroupMember {
  late String groupId;
  late String email;
  late String displayName;
  late bool isGuest;

  void loadDataFromJson(Map<String, dynamic> json) {
    groupId = json["group_id"];
    email = json["email"];
    displayName = json["display_name"];
    isGuest = json["is_guest"];
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'email': email,
        'display_name': displayName,
        'is_guest': isGuest,
      };
}
