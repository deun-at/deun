class GroupMember {
  late int groupId;
  late String email;
  late String firstname;
  late String lastname;

  void loadDataFromJson(Map<String, dynamic> json) {
    groupId = json["group_id"];
    email = json["email"];
    firstname = json["firstname"];
    lastname = json["lastname"];
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'email': email,
        'firstname': firstname,
        'lastname': lastname
      };
}
