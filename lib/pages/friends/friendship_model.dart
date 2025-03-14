import 'package:deun/pages/users/user_model.dart';

import '../../main.dart';

class Friendship {
  late User user;
  late String status;
  late bool isRequester;
  late double shareAmount;

  void loadDataFromJson(Map<String, dynamic> json) {
    user = User();

    if (json["requester"]["email"] == supabase.auth.currentUser?.email) {
      isRequester = false;
      user.loadDataFromJson(json["addressee"]);
    } else {
      isRequester = true;
      user.loadDataFromJson(json["requester"]);
    }

    status = json["status"];
  }

  static Future<List<Friendship>> fetchData() async {
    String currentEmail = supabase.auth.currentUser?.email ?? '';
    var query = supabase
        .from('friendship')
        .select('*, requester(*), addressee(*)')
        .or("addressee.eq.$currentEmail,requester.eq.$currentEmail");

    List<Map<String, dynamic>> data = await query
        .order('status', ascending: true)
        .order('display_name', referencedTable: 'requester', ascending: false)
        .order('display_name', referencedTable: 'addressee', ascending: false);

    List<Friendship> retData = List.empty(growable: true);

    List<Map<String, dynamic>> groupSharesSummaryData = await supabase
        .from('group_shares_summary')
        .select('*')
        .or("paid_by.eq.$currentEmail,paid_for.eq.$currentEmail");

    for (var element in data) {
      if ((element["status"] == "accepted" && element["requester"]["email"] == currentEmail) ||
          element["status"] == "pending") {
        Friendship friendship = Friendship();
        friendship.loadDataFromJson(element);
        friendship.shareAmount = 0;

        if (element["status"] == "accepted") {
          for (var groupSharesSummary in groupSharesSummaryData) {
            if (groupSharesSummary["paid_by"] == currentEmail &&
                groupSharesSummary["paid_for"] == friendship.user.email) {
              friendship.shareAmount += groupSharesSummary["share_amount"] ?? 0;
            } else if (groupSharesSummary["paid_for"] == currentEmail &&
                groupSharesSummary["paid_by"] == friendship.user.email) {
              friendship.shareAmount -= groupSharesSummary["share_amount"] ?? 0;
            }
          }
        }

        retData.add(friendship);
      }
    }

    return retData;
  }

  static Future<Friendship> fetchDetail(String email) async {
    // String currentEmail = supabase.auth.currentUser?.email ?? '';

    Friendship friendship = Friendship();
    // friendship.loadDataFromJson(json);
    return friendship;
  }

  static Future<List<User>> fetchFriends(String searchString, List<String> selectedUsers, int limit) async {
    var userEmail = supabase.auth.currentUser?.email ?? '';

    List<Map<String, dynamic>> data = await supabase
        .from("friendship")
        .select("...addressee!inner(*)")
        .or("requester.eq.$userEmail")
        .eq("status", "accepted")
        .or("email.ilike.%$searchString%,display_name.ilike.%$searchString%", referencedTable: "addressee")
        .not("addressee.email", "in", "(${selectedUsers.join(",")})")
        .order("email", referencedTable: "addressee")
        .limit(limit);

    //debugPrint(data.toString());

    List<User> retData = [];

    for (var element in data) {
      User user = User();
      user.loadDataFromJson(element);
      retData.add(user);
    }

    return retData;
  }

  static Future<void> request(String email) async {
    await supabase.from("friendship").upsert({
      "requester": supabase.auth.currentUser?.email,
      "addressee": email,
    });
  }

  static Future<void> accepted(String email) async {
    await supabase.from("friendship").upsert([
      {
        "requester": supabase.auth.currentUser?.email,
        "addressee": email,
        "status": "accepted",
      },
      {
        "requester": email,
        "addressee": supabase.auth.currentUser?.email,
        "status": "accepted",
      }
    ]);
  }

  static Future<void> cancel(String email) async {
    await supabase
        .from("friendship")
        .delete()
        .eq("requester", supabase.auth.currentUser?.email ?? '')
        .eq("addressee", email);
  }

  static Future<void> remove(String email) async {
    await supabase.from("friendship").delete().or(
        'and(requester.eq.$email,addressee.eq.${supabase.auth.currentUser?.email ?? ''}),and(requester.eq.${supabase.auth.currentUser?.email ?? ''},addressee.eq.$email)');
  }
}
