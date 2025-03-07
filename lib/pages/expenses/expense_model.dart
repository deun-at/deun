import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../groups/group_model.dart';
import 'expense_entry_model.dart';

class Expense {
  late String id;
  late String groupId;
  late Group group;
  late String name;
  late double amount;
  late String? paidBy;
  late String expenseDate;
  late String createdAt;
  late bool isPaidBackRow;

  late Map<String, ExpenseEntry> expenseEntries;

  late Map<String, double> groupMemberShareStatistic;
  late String? paidByDisplayName;

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];
    groupId = json["group_id"];

    group = Group();
    if (json["group"] != null) {
      group.loadDataFromJson(json["group"]);
    }
    name = json["name"];
    expenseDate = json["expense_date"];
    paidBy = json["paid_by"];
    paidByDisplayName = json["paid_by_display_name"];
    createdAt = json["created_at"];
    isPaidBackRow = json["is_paid_back_row"];

    amount = 0.0;
    expenseEntries = <String, ExpenseEntry>{};
    int _newTextFieldId = 0;
    groupMemberShareStatistic = {};
    if (json["expense_entry"] != null) {
      for (var element in json["expense_entry"]) {
        ExpenseEntry expenseEntry = ExpenseEntry(index: _newTextFieldId);
        expenseEntry.loadDataFromJson(element);
        expenseEntries.addAll({expenseEntry.id: expenseEntry});

        _newTextFieldId++;
        amount += expenseEntry.amount;

        if (expenseEntry.expenseEntryShares.isNotEmpty) {
          for (var e in expenseEntry.expenseEntryShares) {
            groupMemberShareStatistic[e.email] =
                (groupMemberShareStatistic[e.email] ?? 0) + (expenseEntry.amount * (e.percentage / 100));
          }
        }
      }
    }
  }

  delete() async {
    await supabase.from('expense').delete().eq('id', id);
    await supabase.from('expense_update_checker').delete().eq('expense_id', id);
    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": null});
  }

  static Future<List<Expense>> fetchData([String? groupId, int rangeFrom = 0, int rangeTo = 0, String? filter]) async {
    var query = supabase.from('expense').select(
        '*, ...paid_by(paid_by_display_name:display_name), expense_entry(*, expense_entry_share(*, ...email(display_name:display_name))), group!expense_group_id_fkey(*, group_shares_summary(*, ...paid_by(paid_by_display_name:display_name), ...paid_for(paid_for_display_name:display_name)), group_member(*, ...user(display_name:display_name)))');

    if (groupId != null) {
      query = query.eq('group_id', groupId);
    }

    if (filter != null) {
      query = query.ilike('name', '%$filter%');
    }

    //created_at as fallback if multiple entrys are on the same date/check if name makes more senses
    List<Map<String, dynamic>> data = await query.order('expense_date').order('created_at').range(rangeFrom, rangeTo);

    List<Expense> retData = List.empty(growable: true);

    for (var element in data) {
      Expense expense = Expense();
      expense.loadDataFromJson(element);
      retData.add(expense);
    }

    return retData;
  }

  static Future<Expense> fetchDetail(String expenseId) async {
    Map<String, dynamic> data = await supabase
        .from('expense')
        .select(
            '*, ...paid_by(paid_by_display_name:display_name), expense_entry(*, expense_entry_share(*, ...email(display_name:display_name))), group!expense_group_id_fkey(*, group_shares_summary(*, ...paid_by(paid_by_display_name:display_name), ...paid_for(paid_for_display_name:display_name)), group_member(*, ...user(display_name:display_name)))')
        .eq('id', expenseId)
        .single();

    Expense expense = Expense();
    expense.loadDataFromJson(data);

    return expense;
  }

  static Future<void> saveAll(
      BuildContext context, String groupId, String? expenseId, Map<String, dynamic> formResponse) async {
    Map<String, dynamic> upsertVals = {
      'name': formResponse['name'],
      'expense_date': formResponse['expense_date'].toString(),
      'paid_by': formResponse['paid_by'],
      'group_id': groupId,
      'user_id': supabase.auth.currentUser?.id
    };

    if (expenseId != null) {
      upsertVals.addAll({'id': expenseId});
    }

    Map<String, dynamic> expenseInsertResponse =
        await supabase.from('expense').upsert(upsertVals).select('id').single();

    Map<String, Map<String, dynamic>> expenseEntryValues = {};

    formResponse.forEach((key, value) {
      if (key.startsWith('expense_entry[')) {
        RegExp regex = RegExp(r'\[(.*?)\]');

        // Use allMatches to get all occurrences
        Iterable<RegExpMatch> matches = regex.allMatches(key);

        String index = matches.elementAt(0).group(1) ?? '';
        String fieldName = matches.elementAt(1).group(1) ?? '';

        if (!expenseEntryValues.containsKey(index)) {
          expenseEntryValues[index] = {};
          expenseEntryValues[index]?['expense_id'] = expenseInsertResponse['id'];
        }

        expenseEntryValues[index]?[fieldName] = value;
      }
    });

    await supabase.from('expense_entry').delete().eq('expense_id', expenseInsertResponse['id']);

    Set<String> notificationReceiver = {};
    double amount = 0;

    await Future.wait(expenseEntryValues.values.map((expenseEntry) async {
      amount += double.parse(expenseEntry['amount']);

      Map<String, dynamic> insertExpenseEntry = {
        "expense_id": expenseEntry["expense_id"],
        "name": expenseEntry["name"],
        "amount": expenseEntry["amount"],
      };

      Map<String, dynamic> expenseEntryResult =
          await supabase.from('expense_entry').insert(insertExpenseEntry).select('id').single();

      await supabase.from('expense_entry_share').delete().eq('expense_entry_id', expenseEntryResult['id']);

      Set<String> expenseEntryShares = expenseEntry['shares'];

      notificationReceiver.addAll(expenseEntryShares);

      List<Map<String, dynamic>> insertExpenseEntryShares = expenseEntryShares.map((email) {
        return {
          "expense_entry_id": expenseEntryResult['id'],
          "email": email,
          "percentage": 100 / expenseEntryShares.length
        };
      }).toList();

      await supabase.from('expense_entry_share').insert(insertExpenseEntryShares);
    }));

    await supabase
        .rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": expenseInsertResponse['id']});

    if (expenseId == null && context.mounted) {
      sendExpenseNotification(context, expenseInsertResponse['id'], notificationReceiver, amount);
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonValue = {
      'name': name,
      'paid_by': paidBy,
    };

    expenseEntries.forEach((key, value) {
      jsonValue.addAll({"expense_entry[${value.index}][name]": value.name});
      jsonValue.addAll({"expense_entry[${value.index}][amount]": value.amount.toString()});
      jsonValue.addAll({"expense_entry[${value.index}][shares]": value.expenseEntryShares.map((e) => e.email).toSet()});
    });

    return jsonValue;
  }
}
