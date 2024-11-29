class GroupMember {
  late int groupId;
  late String email;

  void loadDataFromJson(Map<String, dynamic> json) {
    groupId = json["group_id"];
    email = json["email"];
  }
}
