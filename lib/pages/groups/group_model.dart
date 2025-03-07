import 'dart:convert';

import '../../constants.dart';
import '../../main.dart';
import '../expenses/expense_model.dart';
import 'group_member_model.dart';

class GroupSharesSummary {
  late String dipslayName;
  late String? paypalMe;
  late double shareAmount;
}

class Group {
  late String id;
  late String name;
  late int colorValue;
  late String createdAt;
  late String userId;

  late List<GroupMember> groupMembers;
  late Map<String, GroupSharesSummary> groupSharesSummary;
  late double totalExpenses;
  late double totalShareAmount;

  late List<Expense>? expenses;

  static const groupSelectString =
      '*, group_shares_summary_helper:group_shares_summary!inner(*), group_shares_summary(*, ...paid_by(paid_by_display_name:display_name, paid_by_paypal_me:paypal_me), ...paid_for(paid_for_display_name:display_name, paid_for_paypal_me:paypal_me)), group_member(*, ...user(display_name:display_name))';

  void loadDataFromJson(Map<String, dynamic> json) {
    String? currentUserEmail = supabase.auth.currentUser?.email;

    id = json["id"];
    name = json["name"];
    colorValue = json["color_value"] ?? ColorSeed.baseColor.color.toARGB32();
    createdAt = json["created_at"];
    userId = json["user_id"];

    groupMembers = [];
    if (json["group_member"] != null) {
      for (var element in json["group_member"]) {
        GroupMember groupMember = GroupMember();
        groupMember.loadDataFromJson(element);
        groupMembers.add(groupMember);
      }
    }

    totalExpenses = 0;
    totalShareAmount = 0;
    groupSharesSummary = {};
    if (json["group_shares_summary"] != null) {
      for (var element in json["group_shares_summary"]) {
        if (element['paid_for'] == currentUserEmail) {
          totalExpenses += double.parse((element['total_expenses'] ?? 0).toString());
          totalShareAmount = double.parse((element['total_share_amount'] ?? 0).toString());
        }

        if (element['paid_by'] == currentUserEmail && element['paid_for'] != currentUserEmail) {
          if (groupSharesSummary[element['paid_for']] == null) {
            groupSharesSummary[element['paid_for']] = GroupSharesSummary();
            groupSharesSummary[element['paid_for']]!.dipslayName = element['paid_for_display_name'];
            groupSharesSummary[element['paid_for']]!.paypalMe = element['paid_for_paypal_me'];
            groupSharesSummary[element['paid_for']]!.shareAmount = 0;
          }

          groupSharesSummary[element['paid_for']]!.shareAmount = groupSharesSummary[element['paid_for']]!.shareAmount +
              double.parse((element['share_amount'] ?? 0).toString());
        } else if (element['paid_for'] == currentUserEmail && element['paid_by'] != currentUserEmail) {
          if (groupSharesSummary[element['paid_by']] == null) {
            groupSharesSummary[element['paid_by']] = GroupSharesSummary();
            groupSharesSummary[element['paid_by']]!.dipslayName = element['paid_by_display_name'];
            groupSharesSummary[element['paid_by']]!.paypalMe = element['paid_by_paypal_me'];
            groupSharesSummary[element['paid_by']]!.shareAmount = 0;
          }

          groupSharesSummary[element['paid_by']]!.shareAmount = groupSharesSummary[element['paid_by']]!.shareAmount -
              double.parse((element['share_amount'] ?? 0).toString());
        }
      }
    }
  }

  delete() async {
    await supabase.from('group').delete().eq('id', id);
    await supabase.from('group_update_checker').delete().eq('group_id', id);
  }

  static Future<List<Group>> fetchData(String statusFilter) async {
    var query = supabase.from('group').select(groupSelectString);

    if (statusFilter == GroupListFilter.active.value) {
      query = query.not('group_shares_summary_helper.total_share_amount', 'eq', '0');
      query = query.filter('group_shares_summary_helper.paid_for', 'eq', supabase.auth.currentUser?.email);
    } else if (statusFilter == GroupListFilter.done.value) {
      query = query.filter('group_shares_summary_helper.total_share_amount', 'eq', '0');
      query = query.filter('group_shares_summary_helper.paid_for', 'eq', supabase.auth.currentUser?.email);
    } else {
      query = query.filter('group_shares_summary_helper.paid_for', 'eq', supabase.auth.currentUser?.email);
    }

    List<Map<String, dynamic>> data = await query.order('name', ascending: true);

    List<Group> retData = List.empty(growable: true);

    for (var element in data) {
      Group group = Group();
      group.loadDataFromJson(element);
      retData.add(group);
    }

    return retData;
  }

  static Future<Group> fetchDetail(String groupId) async {
    Map<String, dynamic> data = await supabase.from('group').select(groupSelectString).eq('id', groupId).single();

    Group group = Group();
    group.loadDataFromJson(data);

    return group;
  }

  static List<Map<String, dynamic>> decodeGroupMembersString(String? jsonValue) {
    var selectedGroupMembers = List<Map<String, dynamic>>.from(jsonDecode(jsonValue ?? "[]"));

    if (selectedGroupMembers.isEmpty) {
      selectedGroupMembers.add({
        'email': supabase.auth.currentUser?.email ?? '',
        'display_name': '',
      });
    }

    return selectedGroupMembers;
  }

  static Future<String> saveAll(String? groupId, Map<String, dynamic> formValue) async {
    Map<String, dynamic> upsertVals = {
      "name": formValue["name"],
      "color_value": formValue["color_value"] ?? ColorSeed.baseColor.color.toARGB32(),
      "user_id": supabase.auth.currentUser?.id
    };

    if (groupId != null) {
      upsertVals.addAll({'id': groupId});
    }
    Map<String, dynamic> groupInsertResponse = await supabase.from('group').upsert(upsertVals).select('id').single();

    List<Map<String, dynamic>> groupMembers = decodeGroupMembersString(formValue['group_members']);

    await supabase.from('group_member').delete().eq('group_id', groupInsertResponse['id']);

    if (groupMembers.isNotEmpty) {
      List<Map<String, dynamic>> upsertGroupMembers = [];
      upsertGroupMembers.addAll(groupMembers.map((groupMember) {
        return {'group_id': groupInsertResponse['id'], 'email': groupMember['email']};
      }));

      await supabase.from('group_member').insert(upsertGroupMembers);
    }

    await supabase
        .rpc('update_group_member_shares', params: {"_group_id": groupInsertResponse['id'], "_expense_id": null});

    return groupInsertResponse['id'] as String;
  }

  static Future<void> payBack(String groupId, String email, double amount) async {
    final expenseId = await supabase.rpc('pay_back', params: {
      "_group_id": groupId,
      "_paid_by": supabase.auth.currentUser?.email,
      "_paid_for": email,
      "_amount": amount
    });
    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": expenseId});
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color_value': colorValue,
        'group_members': jsonEncode(groupMembers.map((groupMember) => groupMember.toJson()).toList()),
      };
}
