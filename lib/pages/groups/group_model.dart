import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../main.dart';
import '../expenses/expense_model.dart';
import 'group_member_model.dart';

class GroupSharesSummary {
  late String dipslayName;
  late String? paypalMe;
  late String? iban;
  late double shareAmount;
}

class Group {
  late String id;
  late String name;
  late int colorValue;
  late bool simplifiedExpenses;
  late String createdAt;
  late String? userId;

  late List<GroupMember> groupMembers;
  late Map<String, GroupSharesSummary> groupSharesSummary;
  late double totalExpenses;
  late double totalShareAmount;

  late List<Expense>? expenses;

  static const groupSelectString =
      '*, group_shares_summary_helper:group_shares_summary!inner(*), group_shares_summary(*, ...paid_by(paid_by_display_name:display_name, paid_by_paypal_me:paypal_me, paid_by_iban:iban), ...paid_for(paid_for_display_name:display_name, paid_for_paypal_me:paypal_me, paid_for_iban:iban)), group_member(*, ...user(display_name:display_name))';

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];
    name = json["name"];
    colorValue = json["color_value"] ?? ColorSeed.baseColor.color.toARGB32();
    simplifiedExpenses = json["simplified_expenses"];
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

    try {
      if (simplifiedExpenses) {
        calculateGroupSharesSummarySimplified(json);
      } else {
        calculateGroupSharesSummaryDefault(json);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  calculateGroupSharesSummaryDefault(Map<String, dynamic> json) {
    String? currentUserEmail = supabase.auth.currentUser?.email;
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
            groupSharesSummary[element['paid_for']]!.iban = element['paid_for_iban'];
            groupSharesSummary[element['paid_for']]!.shareAmount = 0;
          }

          groupSharesSummary[element['paid_for']]!.shareAmount = groupSharesSummary[element['paid_for']]!.shareAmount +
              double.parse((element['share_amount'] ?? 0).toString());
        } else if (element['paid_for'] == currentUserEmail && element['paid_by'] != currentUserEmail) {
          if (groupSharesSummary[element['paid_by']] == null) {
            groupSharesSummary[element['paid_by']] = GroupSharesSummary();
            groupSharesSummary[element['paid_by']]!.dipslayName = element['paid_by_display_name'];
            groupSharesSummary[element['paid_by']]!.paypalMe = element['paid_by_paypal_me'];
            groupSharesSummary[element['paid_by']]!.iban = element['paid_by_iban'];
            groupSharesSummary[element['paid_by']]!.shareAmount = 0;
          }

          groupSharesSummary[element['paid_by']]!.shareAmount = groupSharesSummary[element['paid_by']]!.shareAmount -
              double.parse((element['share_amount'] ?? 0).toString());
        }
      }
    }
  }

  calculateGroupSharesSummarySimplified(Map<String, dynamic> json) {
    String? currentUserEmail = supabase.auth.currentUser?.email;
    totalExpenses = 0;
    totalShareAmount = 0;
    groupSharesSummary = {};

    Map<String, dynamic> helperArray = {};
    if (json["group_shares_summary"] != null) {
      Map<String, double> simplifiedExpenseArray = {};
      for (var element in json["group_shares_summary"]) {
        if (element['paid_for'] == currentUserEmail) {
          totalExpenses += double.parse((element['total_expenses'] ?? 0).toString());
          totalShareAmount = double.parse((element['total_share_amount'] ?? 0).toString());
        }

        if (simplifiedExpenseArray[element["paid_for"]] == null) {
          simplifiedExpenseArray[element["paid_for"]] = double.parse((element['total_share_amount'] ?? 0).toString());
        }

        if (helperArray[element["paid_by"]] == null) {
          helperArray[element["paid_by"]] = {
            "display_name": element['paid_by_display_name'],
            "paypal_me": element['paid_by_paypal_me'],
            "iban": element['paid_by_iban'],
          };
        }

        if (helperArray[element["paid_for"]] == null) {
          helperArray[element["paid_for"]] = {
            "display_name": element['paid_for_display_name'],
            "paypal_me": element['paid_for_paypal_me'],
            "iban": element['paid_for_iban'],
          };
        }
      }

      simplifiedExpenseArray =
          Map.fromEntries(simplifiedExpenseArray.entries.toList()..sort((e1, e2) => e1.value.compareTo(e2.value)));

      Map<String, double> finalSimplifiedExpenseArray = {};
      while (simplifiedExpenseArray.length > 1) {
        var firstEntry = simplifiedExpenseArray.entries.first;
        var lastEntry = simplifiedExpenseArray.entries.last;

        if (firstEntry.value < lastEntry.value) {
          if (firstEntry.value.abs() <= lastEntry.value.abs()) {
            if (firstEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[lastEntry.key] = firstEntry.value;
            } else if (lastEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[firstEntry.key] = firstEntry.value.abs();
            }

            simplifiedExpenseArray[firstEntry.key] = 0;
            simplifiedExpenseArray[lastEntry.key] = lastEntry.value.abs() - firstEntry.value.abs();
          } else {
            if (firstEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[lastEntry.key] = lastEntry.value * -1;
            } else if (lastEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[firstEntry.key] = lastEntry.value;
            }

            simplifiedExpenseArray[firstEntry.key] = lastEntry.value.abs() - firstEntry.value.abs();
            simplifiedExpenseArray[lastEntry.key] = 0;
          }

          if (simplifiedExpenseArray[firstEntry.key] == 0) {
            simplifiedExpenseArray.remove(firstEntry.key);
          }

          if (simplifiedExpenseArray[lastEntry.key] == 0) {
            simplifiedExpenseArray.remove(lastEntry.key);
          }
        } else {
          break;
        }
      }

      finalSimplifiedExpenseArray.forEach((key, value) {
        groupSharesSummary[key] = GroupSharesSummary();
        groupSharesSummary[key]!.dipslayName = helperArray[key]["display_name"] ?? '';
        groupSharesSummary[key]!.paypalMe = helperArray[key]["paypal_me"];
        groupSharesSummary[key]!.iban = helperArray[key]["iban"];
        groupSharesSummary[key]!.shareAmount = value;
      });
    }
  }

  delete() async {
    await supabase.from('group').delete().eq('id', id);
    await supabase.from('group_update_checker').delete().eq('group_id', id);
  }

  static Future<List<Group>> fetchData(String statusFilter) async {
    var query = supabase.from('group').select(groupSelectString);

    if (statusFilter == GroupListFilter.active.value) {
      query = query.or('total_share_amount.gte.0.01,total_share_amount.lte.-0.01',
          referencedTable: 'group_shares_summary_helper');
      query = query.eq('group_shares_summary_helper.paid_for', supabase.auth.currentUser?.email ?? '');
    } else if (statusFilter == GroupListFilter.done.value) {
      query = query.lt("group_shares_summary_helper.total_share_amount", 0.01);
      query = query.gt("group_shares_summary_helper.total_share_amount", -0.01);
      query = query.eq('group_shares_summary_helper.paid_for', supabase.auth.currentUser?.email ?? '');
    } else {
      query = query.eq('group_shares_summary_helper.paid_for', supabase.auth.currentUser?.email ?? '');
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

  static Future<String> saveAll(BuildContext context, String? groupId, Map<String, dynamic> formValue) async {
    Map<String, dynamic> upsertVals = {
      "name": formValue["name"],
      "color_value": formValue["color_value"] ?? ColorSeed.baseColor.color.toARGB32(),
      "simplified_expenses": formValue["simplified_expenses"] ?? false,
      "user_id": supabase.auth.currentUser?.id,
    };

    if (groupId != null) {
      upsertVals.addAll({'id': groupId});
    }
    Map<String, dynamic> groupInsertResponse = await supabase.from('group').upsert(upsertVals).select('id').single();

    Set<String> notificationReceiver = {};
    List<Map<String, dynamic>> groupMembers = decodeGroupMembersString(formValue['group_members']);

    await supabase.from('group_member').delete().eq('group_id', groupInsertResponse['id']);

    if (groupMembers.isNotEmpty) {
      notificationReceiver.addAll(groupMembers.map((groupMember) {
        return groupMember['email'];
      }));
      List<Map<String, dynamic>> upsertGroupMembers = [];
      upsertGroupMembers.addAll(groupMembers.map((groupMember) {
        return {'group_id': groupInsertResponse['id'], 'email': groupMember['email']};
      }));

      await supabase.from('group_member').insert(upsertGroupMembers);
    }

    await supabase
        .rpc('update_group_member_shares', params: {"_group_id": groupInsertResponse['id'], "_expense_id": null});

    if (groupId == null && context.mounted) {
      sendGroupNotification(context, groupInsertResponse['id'], notificationReceiver);
    }

    return groupInsertResponse['id'] as String;
  }

  static Future<void> payBack(BuildContext context, String groupId, String email, double amount) async {
    final expenseId = await supabase.rpc('pay_back', params: {
      "_group_id": groupId,
      "_paid_by": supabase.auth.currentUser?.email,
      "_paid_for": email,
      "_amount": amount
    });
    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": expenseId});

    if (context.mounted) {
      sendGroupPayBackNotification(context, groupId, expenseId, {email}, amount);
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color_value': colorValue,
        'simplified_expenses': simplifiedExpenses,
        'group_members': jsonEncode(groupMembers.map((groupMember) => groupMember.toJson()).toList()),
      };
}
