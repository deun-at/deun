import 'dart:math';

import '../../main.dart';

class SupaUser {
  late String email;
  late String? userId;
  late String? firstName;
  late String? lastName;
  late String displayName;
  late String? paypalMe;
  late String? iban;
  late String? locale;
  late String createdAt;
  late bool isGuest;

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
    isGuest = json["is_guest"];
  }

  static Future<List<SupaUser>> fetchData(String searchString, List<String> selectedUsers, int? limit) async {
    var query =
        supabase.from("user").select("*").ilike('email', searchString).not('email', 'in', selectedUsers).order("email");

    if (limit != null) {
      query = query.limit(limit);
    }

    List<Map<String, dynamic>> data = await query;
    List<SupaUser> retData = [];
    for (var element in data) {
      SupaUser user = SupaUser();
      user.loadDataFromJson(element);
      retData.add(user);
    }

    return retData;
  }

  static Future<SupaUser> fetchDetail(String email) async {
    Map<String, dynamic> data = await supabase.from("user").select("*").eq("email", email).single();

    SupaUser user = SupaUser();
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

  static Future<SupaUser> createGuest(String displayName) async {
    // Generate a unique placeholder email for the guest user
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(999999);
    final email = 'guest+$ts$rand@guest.invalid';

    Map<String, dynamic> insertVals = {
      'email': email,
      'display_name': displayName,
      'is_guest': true
    };

    Map<String, dynamic> data = await supabase.from('user').insert(insertVals).select('*').single();

    SupaUser user = SupaUser();
    user.loadDataFromJson(data);
    return user;
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
