import '../../main.dart';

class User {
  late String email;
  late String userId;
  late String displayName;
  late String createdAt;

  void loadDataFromJson(Map<String, dynamic> json) {
    email = json["email"];
    userId = json["user_id"];
    displayName = json["display_name"];
    createdAt = json["created_at"];
  }

  static Future<List<User>> fetchData(String searchString, List<String> selectedUsers, int limit) async {
    List<Map<String, dynamic>> data = await supabase
        .from("user")
        .select("*")
        .or("email.ilike.%$searchString%,display_name.ilike.%$searchString%")
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
        "user_id": userId,
        "display_name": displayName,
        "created_at": createdAt,
      };
}
