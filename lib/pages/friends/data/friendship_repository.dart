import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_model.dart';

import '../../../main.dart';

class FriendshipRepository {
  /// Fetches accepted friendships with their per-currency shared amounts. Each
  /// mutual group contributes in ITS OWN currency; nothing is converted and
  /// nothing is excluded for want of a rate.
  static Future<List<Friendship>> fetchData() async {
    String currentEmail = supabase.auth.currentUser?.email ?? '';

    List<Map<String, dynamic>> data = await supabase
        .from('friendship')
        .select('*, requester(*), addressee(*)')
        .eq('status', 'accepted')
        .or('requester.eq.$currentEmail,addressee.eq.$currentEmail');

    List<Friendship> retData = List.empty(growable: true);
    Set<String> seenEmails = {};

    final groupList = await GroupRepository.fetchData("active");

    for (var element in data) {
      Friendship friendship = Friendship();
      friendship.loadDataFromJson(element);

      // Deduplicate: with bidirectional query, the same friend may appear twice
      if (seenEmails.contains(friendship.user.email)) continue;
      seenEmails.add(friendship.user.email);

      final contributions = <CurrencyAmount>[];
      for (var group in groupList) {
        final groupShare = group.groupSharesSummary[friendship.user.email];
        if (groupShare == null) continue;
        if (isSettled(groupShare.shareAmount, group.currency)) continue;
        contributions.add(
          CurrencyAmount(group.currency, groupShare.shareAmount),
        );
      }
      friendship.balances = contributions;

      retData.add(friendship);
    }

    retData.sort((a, b) {
      if (a.shareAmount == 0 && b.shareAmount != 0) {
        return 1;
      } else if (a.shareAmount != 0 && b.shareAmount == 0) {
        return -1;
      } else if (a.shareAmount == 0 && b.shareAmount == 0) {
        return a.user.displayName.toLowerCase().compareTo(
          b.user.displayName.toLowerCase(),
        );
      } else if (a.shareAmount == b.shareAmount) {
        return a.user.displayName.toLowerCase().compareTo(
          b.user.displayName.toLowerCase(),
        );
      } else {
        return b.shareAmount.compareTo(a.shareAmount);
      }
    });

    return retData;
  }

  static Future<List<Friendship>> getRequestedFriendships() async {
    String currentEmail = supabase.auth.currentUser?.email ?? '';

    List<Map<String, dynamic>> data = await supabase
        .from('friendship')
        .select('*, requester(*), addressee(*)')
        .or("addressee.eq.$currentEmail,requester.eq.$currentEmail")
        .order('status', ascending: true)
        .order('display_name', referencedTable: 'addressee', ascending: false);

    List<Friendship> retData = List.empty(growable: true);

    for (var element in data) {
      Friendship friendship = Friendship();
      friendship.loadDataFromJson(element);
      retData.add(friendship);
    }

    return retData;
  }

  static Future<List<Friendship>> fetchPendingIncoming() async {
    return _fetchPendingByRole('addressee');
  }

  static Future<List<Friendship>> fetchPendingOutgoing() async {
    return _fetchPendingByRole('requester');
  }

  static Future<List<Friendship>> _fetchPendingByRole(String roleColumn) async {
    String currentEmail = supabase.auth.currentUser?.email ?? '';

    List<Map<String, dynamic>> data = await supabase
        .from('friendship')
        .select('*, requester(*), addressee(*)')
        .eq(roleColumn, currentEmail)
        .eq('status', 'pending');

    List<Friendship> retData = List.empty(growable: true);

    for (var element in data) {
      Friendship friendship = Friendship();
      friendship.loadDataFromJson(element);
      retData.add(friendship);
    }

    return retData;
  }

  static Future<Friendship> fetchDetail(String email) async {
    Friendship friendship = Friendship();
    return friendship;
  }

  static Future<List<SupaUser>> fetchFriends(
    String searchString,
    Iterable<String> selectedUsers,
    int limit,
  ) async {
    var userEmail = supabase.auth.currentUser?.email ?? '';

    final escaped = searchString.replaceAll(RegExp(r'[%_,()\\]'), '');

    List<Map<String, dynamic>> data = await supabase
        .from("friendship")
        .select("...addressee!inner(*)")
        .or("requester.eq.$userEmail")
        .eq("status", "accepted")
        .or(
          "email.ilike.%$escaped%,display_name.ilike.%$escaped%,username.ilike.%$escaped%",
          referencedTable: "addressee",
        )
        .not("addressee.email", "in", "(${selectedUsers.join(",")})")
        .order("email", referencedTable: "addressee")
        .limit(limit);

    return data.map(SupaUser.fromJson).toList();
  }

  static Future<void> request(String email) async {
    if (email == supabase.auth.currentUser?.email) return;
    await supabase.from("friendship").upsert({
      "requester": supabase.auth.currentUser?.email,
      "addressee": email,
    });
  }

  static Future<void> accepted(String email) async {
    if (email != supabase.auth.currentUser?.email) {
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
        },
      ]);
    }
  }

  static Future<void> cancel(String email) async {
    await supabase
        .from("friendship")
        .delete()
        .eq("requester", supabase.auth.currentUser?.email ?? '')
        .eq("addressee", email);
  }

  static Future<void> decline(String email) async {
    await supabase
        .from("friendship")
        .delete()
        .eq("addressee", supabase.auth.currentUser?.email ?? '')
        .eq("requester", email);
  }

  static Future<void> remove(String email) async {
    final safeEmail = sanitizeFilterValue(email);
    final currentEmail = sanitizeFilterValue(
      supabase.auth.currentUser?.email ?? '',
    );
    await supabase
        .from("friendship")
        .delete()
        .or(
          'and(requester.eq.$safeEmail,addressee.eq.$currentEmail),and(requester.eq.$currentEmail,addressee.eq.$safeEmail)',
        );
  }
}
