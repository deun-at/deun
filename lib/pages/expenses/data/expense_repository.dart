import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

class ExpenseRepository {
  static Future<List<Expense>> fetchData([String? groupId, int rangeFrom = 0, int rangeTo = 0, String? filter]) async {
    var query = supabase.from('expense').select(Expense.expenseSelectString);

    if (groupId != null) {
      query = query.eq('group_id', groupId);
    }

    if (filter != null) {
      query = query.ilike('name', '%$filter%').eq('is_paid_back_row', 'false');
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

  static Future<List<Expense>> fetchRange(String groupId, DateTime start, DateTime end) async {
    var query = supabase
        .from('expense')
        .select(Expense.expenseSelectString)
        .eq('group_id', groupId)
        .eq('is_paid_back_row', false)
        .gte('expense_date', start.toIso8601String())
        .lt('expense_date', end.toIso8601String())
        .order('expense_date')
        .order('created_at');

    List<Map<String, dynamic>> data = await query;

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
        .select(Expense.expenseSelectString)
        .eq('id', expenseId)
        .order('sort_id', ascending: true, referencedTable: 'expense_entry')
        .single();

    Expense expense = Expense();
    expense.loadDataFromJson(data);

    return expense;
  }

  /// Saves an expense with all its entries and share splits atomically via
  /// the save_expense_all RPC (one transaction server-side). Falls back to
  /// the legacy multi-step write path when the database doesn't have the
  /// RPC yet, so the app works against not-yet-migrated servers.
  static Future<void> saveAll(
      BuildContext context, String groupId, String? expenseId, Map<String, dynamic> formResponse) async {
    try {
      Map<String, dynamic> upsertVals = {
        'name': formResponse['name'],
        'expense_date': formResponse['expense_date'].toString(),
        'paid_by': formResponse['paid_by'],
        'group_id': groupId,
        'user_id': supabase.auth.currentUser?.id,
        'category': (formResponse['category'] as ExpenseCategory?)?.name
      };

      if (expenseId != null) {
        upsertVals.addAll({'id': expenseId});
      }

      Map<String, Map<String, dynamic>> expenseEntryValues = {};

      formResponse.forEach((key, value) {
        if (key.startsWith('expense_entry[')) {
          RegExp regex = RegExp(r'\[(.*?)\]');

          // Use allMatches to get all occurrences
          Iterable<RegExpMatch> matches = regex.allMatches(key);

          String index = matches.elementAt(0).group(1) ?? '';
          String fieldName = matches.elementAt(1).group(1) ?? '';

          expenseEntryValues.putIfAbsent(index, () => {});
          expenseEntryValues[index]?[fieldName] = value;
        }
      });

      Set<String> notificationReceiver = {};
      double amount = 0;
      List<Map<String, dynamic>> entries = [];

      int sortId = 10;
      for (var expenseEntry in expenseEntryValues.values) {
        int qty = int.tryParse(expenseEntry['quantity']?.toString() ?? '1') ?? 1;
        double unitPrice = double.parse(expenseEntry['amount']);
        double entryTotal = roundCurrency(unitPrice * qty);
        amount = roundCurrency(amount + entryTotal);

        String splitMode = expenseEntry['split_mode'] ?? 'equal';

        Set<String> expenseEntryShares = expenseEntry['shares'];
        Map<String, dynamic> shareData = expenseEntry['share_data'] ?? {};
        Set<String> lockedMembers = expenseEntry['locked_members'] is Set<String>
            ? expenseEntry['locked_members']
            : <String>{};

        notificationReceiver.addAll(expenseEntryShares);

        List<Map<String, dynamic>> shareRows = [];

        // Safety net: if split mode is 'exact' but all amounts are zero,
        // the widget didn't know the real total — fall back to equal split.
        bool allZeroExact = splitMode == 'exact' &&
            shareData.isNotEmpty &&
            shareData.values.every((v) => (v as num).toDouble() == 0.0);
        if (allZeroExact) {
          shareData = {};
        }

        if (shareData.isNotEmpty) {
          int totalParts = splitMode == 'shares'
              ? shareData.values.fold(0, (sum, v) => sum + (v as int))
              : 0;

          for (var entry in shareData.entries) {
            double percentage;
            double? fixedAmount;
            int? parts;

            switch (splitMode) {
              case 'exact':
                fixedAmount = (entry.value as num).toDouble();
                percentage = entryTotal > 0 ? (fixedAmount / entryTotal) * 100 : 0;
                break;
              case 'percentage':
                percentage = (entry.value as num).toDouble();
                break;
              case 'shares':
                parts = entry.value as int;
                percentage = totalParts > 0 ? (parts / totalParts) * 100 : 0;
                break;
              default:
                percentage = 100 / shareData.length;
            }

            shareRows.add({
              "email": entry.key,
              "percentage": percentage,
              "fixed_amount": fixedAmount,
              "parts": parts,
              "is_locked": lockedMembers.contains(entry.key),
            });
          }
        } else {
          // Fallback: equal split using shares set (backward compat)
          shareRows = expenseEntryShares.map((email) {
            return <String, dynamic>{
              "email": email,
              "percentage": 100 / expenseEntryShares.length,
            };
          }).toList();
        }

        entries.add({
          'entry': {
            'name': expenseEntry['name'],
            'amount': entryTotal,
            'quantity': qty,
            'split_mode': splitMode,
            'sort_id': sortId,
          },
          'shares': shareRows,
        });

        sortId += 10;
      }

      String savedExpenseId;
      try {
        savedExpenseId = await supabase.rpc('save_expense_all', params: {
          '_group_id': groupId,
          '_expense': upsertVals,
          '_entries': entries,
        }) as String;
      } on PostgrestException catch (e) {
        if (!isMissingFunctionError(e)) rethrow;
        savedExpenseId = await _saveAllLegacy(groupId, upsertVals, entries);
      }

      if (expenseId == null && context.mounted) {
        sendExpenseNotification(context, savedExpenseId, notificationReceiver, amount);
      }
    } on PostgrestException catch (e) {
      debugPrint('Failed to save expense in group $groupId: ${e.message}');
      rethrow;
    }
  }

  /// Legacy non-atomic write path for servers without the save_expense_all
  /// RPC. Performs the same writes as the RPC, one statement at a time.
  static Future<String> _saveAllLegacy(
      String groupId, Map<String, dynamic> upsertVals, List<Map<String, dynamic>> entries) async {
    Map<String, dynamic> expenseInsertResponse =
        await supabase.from('expense').upsert(upsertVals).select('id').single();
    final savedExpenseId = expenseInsertResponse['id'] as String;

    await supabase.from('expense_entry').delete().eq('expense_id', savedExpenseId);

    for (var item in entries) {
      Map<String, dynamic> expenseEntryResult = await supabase
          .from('expense_entry')
          .insert({...item['entry'] as Map<String, dynamic>, 'expense_id': savedExpenseId})
          .select('id')
          .single();

      final shareRows = (item['shares'] as List)
          .map((s) => {...s as Map<String, dynamic>, 'expense_entry_id': expenseEntryResult['id']})
          .toList();
      if (shareRows.isNotEmpty) {
        await supabase.from('expense_entry_share').insert(shareRows);
      }
    }

    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": savedExpenseId});
    return savedExpenseId;
  }

  static Future<void> delete(String expenseId, String groupId) async {
    await supabase.from('expense').delete().eq('id', expenseId);
    await supabase.from('expense_update_checker').delete().eq('expense_id', expenseId);
    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": null});
  }
}
