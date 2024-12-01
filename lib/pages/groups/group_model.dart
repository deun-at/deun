import 'dart:convert';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../expenses/expense_model.dart';
import 'group_member_model.dart';

class Group {
  late int id;
  late String name;
  late int colorValue;
  late String createdAt;
  late String userId;
  late double sumAmount;
  late Map<int, Expense> expenses;
  late List<GroupMember> groupMembers;

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];
    name = json["name"];
    colorValue = json["color_value"];
    createdAt = json["created_at"];
    userId = json["user_id"];

    sumAmount = 0.0;
    expenses = <int, Expense>{};
    if (json["expense"] != null) {
      for (var element in json["expense"]) {
        Expense expense = Expense();
        expense.loadDataFromJson(element);
        expenses.addAll({expense.id: expense});

        sumAmount += expense.amount;
      }
    }

    groupMembers = [];
    if (json["group_member"] != null) {
      debugPrint(json["group_member"].toString());
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

  static Future<Map<int, Group>> fetchData() async {
    List<Map<String, dynamic>> data = await supabase
        .from('group')
        .select(
            '*, expense(*, expense_entry(*)), group_member(*, ...user(display_name:display_name))')
        .order('created_at', ascending: false)
        .order('created_at',
            ascending: false,
            referencedTable: 'expense'); //todo order by activity

    Map<int, Group> retData = <int, Group>{};

    for (var element in data) {
      Group group = Group();
      group.loadDataFromJson(element);
      retData.addAll({group.id: group});
    }

    return retData;
  }

  static List<Map<String, dynamic>> decodeGroupMembersString(
      String? jsonValue) {
    var selectedGroupMembers =
        List<Map<String, dynamic>>.from(jsonDecode(jsonValue ?? "[]"));

    if (selectedGroupMembers.isEmpty) {
      selectedGroupMembers.add({
        'email': supabase.auth.currentUser?.email ?? '',
        'display_name': '',
      });
    }

    return selectedGroupMembers;
  }

  static Future<void> saveAll(
      int? groupId, Map<String, dynamic> formValue) async {
    Map<String, dynamic> upsertVals = {
      "name": formValue["name"],
      "color_value": formValue["color_value"],
      "user_id": supabase.auth.currentUser?.id
    };

    if (groupId != null) {
      upsertVals.addAll({'id': groupId});
    }
    Map<String, dynamic> groupInsertResponse =
        await supabase.from('group').upsert(upsertVals).select('id').single();

    List<Map<String, dynamic>> groupMembers =
        decodeGroupMembersString(formValue['group_members']);

    await supabase
        .from('group_member')
        .delete()
        .eq('group_id', groupInsertResponse['id']);

    if (groupMembers.isNotEmpty) {
      List<Map<String, dynamic>> upsertGroupMembers = [];
      upsertGroupMembers.addAll(groupMembers.map((groupMember) {
        return {
          'group_id': groupInsertResponse['id'],
          'email': groupMember['email']
        };
      }));

      await supabase.from('group_member').insert(upsertGroupMembers);
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color_value': colorValue,
        'group_members': jsonEncode(
            groupMembers.map((groupMember) => groupMember.toJson()).toList()),
      };
}
