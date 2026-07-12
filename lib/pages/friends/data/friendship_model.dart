import 'package:deun/pages/users/user_model.dart';

import '../../../main.dart';

class Friendship {
  late SupaUser user;
  late String status;
  late bool isIncomingRequest;
  late double shareAmount;

  /// True when this friend's shared amount was aggregated across groups in
  /// different currencies and converted into the home currency, so the figure
  /// is an estimate (mark it "≈"). False when every shared group was already in
  /// the home currency (exact).
  bool approximate = false;

  /// Number of mutual groups excluded from [shareAmount] because their currency
  /// had no available conversion rate.
  int excludedCount = 0;

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
