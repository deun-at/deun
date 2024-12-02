class GroupMember {
  late String groupId;
  late String email;
  late String displayName;

  void loadDataFromJson(Map<String, dynamic> json) {
    groupId = json["group_id"];
    email = json["email"];
    displayName = json["display_name"];
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'email': email,
        'display_name': displayName,
      };
}
