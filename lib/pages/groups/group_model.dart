import 'dart:convert';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../main.dart';
import '../expenses/expense_model.dart';
import 'group_member_model.dart';

class Group {
  late String id;
  late String name;
  late int colorValue;
  late String createdAt;
  late String userId;
  late double sumAmount;
  late Map<String, Expense> expenses;
  late List<GroupMember> groupMembers;

  late Map<String, double> groupMemberShareStatistic;

  void loadDataFromJson(Map<String, dynamic> json) {
    String? currentUserEmail = supabase.auth.currentUser?.email;

    id = json["id"];
    name = json["name"];
    colorValue = json["color_value"] ?? ColorSeed.baseColor.color.value;
    createdAt = json["created_at"];
    userId = json["user_id"];

    groupMemberShareStatistic = {};
    sumAmount = 0.0;
    expenses = <String, Expense>{};
    if (json["expense"] != null) {
      for (var element in json["expense"]) {
        Expense expense = Expense();
        expense.loadDataFromJson(element);
        expenses.addAll({expense.id: expense});

        sumAmount += expense.amount;

        bool paidByCurrentUser = false;
        if (expense.paidBy == currentUserEmail) {
          paidByCurrentUser = true;
        }

        expense.groupMemberShareStatistic.forEach((String email, double amount) {
          if (paidByCurrentUser && email != currentUserEmail) {
            groupMemberShareStatistic[email] = (groupMemberShareStatistic[email] ?? 0) + amount;
          } else if (paidByCurrentUser == false && email == currentUserEmail) {
            groupMemberShareStatistic[expense.paidBy ?? ''] = (groupMemberShareStatistic[expense.paidBy ?? ''] ?? 0) - amount;
          }
        });
      }
    }

    groupMembers = [];
    if (json["group_member"] != null) {
      for (var element in json["group_member"]) {
        GroupMember groupMember = GroupMember();
        groupMember.loadDataFromJson(element);
        groupMembers.add(groupMember);
      }
    }
  }

  delete() async {
    return await supabase.from('group').delete().eq('id', id);
  }

  static Future<Map<String, Group>> fetchData() async {
    List<Map<String, dynamic>> data = await supabase.from('group_data_view').select(); //todo order by activity

    Map<String, Group> retData = <String, Group>{};

    for (var element in data) {
      Group group = Group();
      group.loadDataFromJson(element);
      retData.addAll({group.id: group});
    }

    return retData;
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

  static Future<void> saveAll(String? groupId, Map<String, dynamic> formValue) async {
    Map<String, dynamic> upsertVals = {
      "name": formValue["name"],
      "color_value": formValue["color_value"] ?? ColorSeed.baseColor.color.value,
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
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color_value': colorValue,
        'group_members': jsonEncode(groupMembers.map((groupMember) => groupMember.toJson()).toList()),
      };
}
