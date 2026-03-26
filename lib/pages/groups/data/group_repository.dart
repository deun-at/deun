import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../main.dart';

class GroupRepository {
  static Future<List<Group>> fetchData(String statusFilter, {String? paidTo}) async {
    var currentUserEmail = supabase.auth.currentUser?.email ?? '';
    var query = supabase.from('group').select(Group.groupSelectString);

    if (statusFilter == GroupListFilter.active.value) {
      query = query.or('total_share_amount.gte.0.01,total_share_amount.lte.-0.01',
          referencedTable: 'group_shares_summary_helper');
    } else if (statusFilter == GroupListFilter.done.value) {
      query = query.lt("group_shares_summary_helper.total_share_amount", 0.01);
      query = query.gt("group_shares_summary_helper.total_share_amount", -0.01);
    }

    query = query.eq('group_shares_summary_helper.paid_for', currentUserEmail);

    if (paidTo != null) {
      query = query.or(
          'and(paid_by.eq.$currentUserEmail,paid_for.eq.$paidTo),and(paid_by.eq.$paidTo,paid_for.eq.$currentUserEmail)',
          referencedTable: 'group_shares_summary_helper');
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
    Map<String, dynamic> data = await supabase.from('group').select(Group.groupSelectString).eq('id', groupId).single();

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

    // Resolve any pending guest members by creating guest user records and replacing entries
    for (int i = 0; i < groupMembers.length; i++) {
      final member = groupMembers[i];
      if ((member['is_guest_pending'] ?? false) == true) {
        final displayName = (member['display_name'] ?? '').toString();
        if (displayName.isNotEmpty) {
          final guestUser = await UserRepository.createGuest(displayName);
          groupMembers[i] = {
            'email': guestUser.email,
            'display_name': guestUser.displayName,
            'is_guest': guestUser.isGuest,
          };
        }
      }
    }

    await supabase.from('group_member').delete().eq('group_id', groupInsertResponse['id']);

    if (groupMembers.isNotEmpty) {
      Set<String> notificationReceiver = {};

      for (var groupMember in groupMembers) {
        if ((groupMember['is_guest'] ?? false) == false) {
          notificationReceiver.add(groupMember['email']);
        }
      }

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

  static Future<void> payBack(BuildContext context, String groupId, String email, double amount,
      {bool sendNotification = true}) async {
    final expenseId = await supabase.rpc('pay_back', params: {
      "_group_id": groupId,
      "_paid_by": supabase.auth.currentUser?.email,
      "_paid_for": email,
      "_amount": amount
    });
    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": expenseId});

    if (context.mounted && sendNotification) {
      sendGroupPayBackNotification(context, groupId, expenseId, {email}, amount);
    }
  }

  static Future<void> payBackAll(BuildContext context, String email, double amount) async {
    final groupList = await GroupRepository.fetchData(GroupListFilter.active.value, paidTo: email);

    await Future.wait(groupList.map((groupData) async {
      double groupAmount = 0;
      groupData.groupSharesSummary.forEach((key, groupShare) {
        if (key == email) {
          groupAmount += groupShare.shareAmount;
        }
      });

      if (groupAmount.abs() >= 0.01) {
        await GroupRepository.payBack(context, groupData.id, email, amount, sendNotification: false);
      }
    }));
  }

  static Future<void> delete(String groupId) async {
    await supabase.from('group').delete().eq('id', groupId);
    await supabase.from('group_update_checker').delete().eq('group_id', groupId);
  }
}
