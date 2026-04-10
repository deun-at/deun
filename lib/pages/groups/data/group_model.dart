import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../helper/helper.dart';
import '../../../main.dart';
import '../../expenses/data/expense_model.dart';
import '../data/group_member_model.dart';

class GroupSharesSummary {
  late String displayName;
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

  bool get isFavorite {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return false;
    return groupMembers.any((m) => m.email == email && m.isFavorite);
  }

  static const groupSelectString =
      '*, group_shares_summary_helper:group_shares_summary!inner(*), group_shares_summary(*, ...paid_by(paid_by_display_name:display_name, paid_by_paypal_me:paypal_me, paid_by_iban:iban), ...paid_for(paid_for_display_name:display_name, paid_for_paypal_me:paypal_me, paid_for_iban:iban)), group_member(*, ...user(display_name:display_name, username:username, username_code:username_code, is_guest:is_guest))';

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

  void calculateGroupSharesSummaryDefault(Map<String, dynamic> json) {
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
            groupSharesSummary[element['paid_for']]!.displayName = element['paid_for_display_name'];
            groupSharesSummary[element['paid_for']]!.paypalMe = element['paid_for_paypal_me'];
            groupSharesSummary[element['paid_for']]!.iban = element['paid_for_iban'];
            groupSharesSummary[element['paid_for']]!.shareAmount = 0;
          }

          groupSharesSummary[element['paid_for']]!.shareAmount = roundCurrency(
              groupSharesSummary[element['paid_for']]!.shareAmount +
              double.parse((element['share_amount'] ?? 0).toString()));
        } else if (element['paid_for'] == currentUserEmail && element['paid_by'] != currentUserEmail) {
          if (groupSharesSummary[element['paid_by']] == null) {
            groupSharesSummary[element['paid_by']] = GroupSharesSummary();
            groupSharesSummary[element['paid_by']]!.displayName = element['paid_by_display_name'];
            groupSharesSummary[element['paid_by']]!.paypalMe = element['paid_by_paypal_me'];
            groupSharesSummary[element['paid_by']]!.iban = element['paid_by_iban'];
            groupSharesSummary[element['paid_by']]!.shareAmount = 0;
          }

          groupSharesSummary[element['paid_by']]!.shareAmount = roundCurrency(
              groupSharesSummary[element['paid_by']]!.shareAmount -
              double.parse((element['share_amount'] ?? 0).toString()));
        }
      }
    }
  }

  void calculateGroupSharesSummarySimplified(Map<String, dynamic> json) {
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
            simplifiedExpenseArray[lastEntry.key] = roundCurrency(lastEntry.value.abs() - firstEntry.value.abs());
          } else {
            if (firstEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[lastEntry.key] = lastEntry.value * -1;
            } else if (lastEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[firstEntry.key] = lastEntry.value;
            }

            simplifiedExpenseArray[firstEntry.key] = roundCurrency(lastEntry.value.abs() - firstEntry.value.abs());
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
        groupSharesSummary[key]!.displayName = helperArray[key]["display_name"] ?? '';
        groupSharesSummary[key]!.paypalMe = helperArray[key]["paypal_me"];
        groupSharesSummary[key]!.iban = helperArray[key]["iban"];
        groupSharesSummary[key]!.shareAmount = value;
      });
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color_value': colorValue,
        'simplified_expenses': simplifiedExpenses,
        'group_members': jsonEncode(groupMembers.map((groupMember) => groupMember.toJson()).toList()),
      };
}
