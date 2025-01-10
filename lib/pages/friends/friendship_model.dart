import 'package:deun/pages/users/user_model.dart';
import 'package:flutter/material.dart';

import '../../main.dart';

class Friendship {
  late User user;
  late String status;
  late bool isRequester;

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

    for (var element in data) {
      if ((element["status"] == "accepted" && element["requester"]["email"] == currentEmail) ||
          element["status"] == "pending") {
        Friendship expense = Friendship();
        expense.loadDataFromJson(element);
        retData.add(expense);
      }
    }

    return retData;
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

    debugPrint(data.toString());

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
