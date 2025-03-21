import '../../main.dart';

class User {
  late String email;
  late String userId;
  late String? firstName;
  late String? lastName;
  late String displayName;
  late String? paypalMe;
  late String? iban;
  late String? locale;
  late String createdAt;

  void loadDataFromJson(Map<String, dynamic> json) {
    email = json["email"];
    userId = json["user_id"];
    firstName = json["first_name"];
    lastName = json["last_name"];
    displayName = json["display_name"];
    locale = json["locale"];
    paypalMe = json["paypal_me"];
    iban = json["iban"];
    createdAt = json["created_at"];
  }

  static Future<List<User>> fetchData(String searchString, List<String> selectedUsers, int limit) async {
    List<Map<String, dynamic>> data = await supabase
        .from("user")
        .select("*")
        .eq("email", searchString)
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

  static Future<User> fetchDetail(String email) async {
    Map<String, dynamic> data = await supabase.from("user").select("*").eq("email", email).single();

    User user = User();
    user.loadDataFromJson(data);

    return user;
  }

  static Future<void> saveAll(Map<String, dynamic> formResponse) async {
    Map<String, dynamic> upsertVals = {
      'first_name': formResponse['first_name'],
      'last_name': formResponse['last_name'],
      'display_name': formResponse['display_name'],
      'locale': formResponse['locale'],
      'paypal_me': formResponse['paypal_me'],
      'iban': formResponse['iban'],
    };

    if (supabase.auth.currentUser?.email != null) {
      return await supabase.from('user').update(upsertVals).eq('email', supabase.auth.currentUser?.email ?? '');
    } else {
      throw Exception('User email is empty');
    }
  }

  Map<String, dynamic> toJson() => {
        "email": email,
        "user_id": userId,
        "first_name": firstName,
        "last_name": lastName,
        "display_name": displayName,
        "locale": locale,
        "paypal_me": paypalMe,
        "iban": iban,
        "created_at": createdAt,
      };
}
