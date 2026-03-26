import 'package:deun/pages/users/user_model.dart';

import '../../../main.dart';

class Friendship {
  late SupaUser user;
  late String status;
  late bool isIncomingRequest;
  late double shareAmount;

  void loadDataFromJson(Map<String, dynamic> json) {

    if (json["requester"]["email"] == supabase.auth.currentUser?.email) {
      isIncomingRequest = false;
      user = SupaUser.fromJson(json["addressee"]);
    } else {
      isIncomingRequest = true;
      user = SupaUser.fromJson(json["requester"]);
    }

    status = json["status"];
  }
}
