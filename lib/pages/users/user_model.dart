import '../../main.dart';

class User {
  late String email;
  late String firstname;
  late String lastname;
  late String createdAt;

  void loadDataFromJson(Map<String, dynamic> json) {
    email = json["email"];
    firstname = json["firstname"];
    lastname = json["lastname"];
    createdAt = json["created_at"];
  }

  static Future<List<User>> fetchData(String searchString, List<String> selectedUsers, int limit) async {
    List<Map<String, dynamic>> data = await supabase
        .from("user")
        .select("*")
        .like("email", "%$searchString%")
        .not('email', 'in', '(${selectedUsers.join(',')})')
        .order("email")
        .limit(limit);

    List<User> retData = [];

    for (var element in data) {
      User user = User();
      user.loadDataFromJson(element);
      retData.add(user);
    }

    return retData;
  }

  Map<String, dynamic> toJson() => {
        "email": email,
        "firstname": firstname,
        "lastname": lastname,
        "created_at": createdAt,
      };
}
