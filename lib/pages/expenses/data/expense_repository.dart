import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/helper/search_filter.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/itemized_totals.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';

class ExpenseRepository {
  /// Null outside tests. When set, [saveAll] sends its one `save_expense_all`
  /// call here instead of `supabase.rpc`.
  @visibleForTesting
  static Future<Object?> Function(Map<String, dynamic> params)?
  saveExpenseAllOverride;

  /// Null outside tests. When set, [claimSetUnitShares] sends its one
  /// `claim_set_unit_shares` call here instead of `supabase.rpc`.
  @visibleForTesting
  static Future<Object?> Function(Map<String, dynamic> params)?
  claimSetUnitSharesOverride;

  static Future<List<Expense>> fetchData([
    String? groupId,
    int rangeFrom = 0,
    int rangeTo = 0,
    String? filter,
  ]) async {
    var query = supabase.from('expense').select(Expense.expenseSelectString);

    if (groupId != null) {
      query = query.eq('group_id', groupId);
    }

    if (filter != null) {
      final search = literalSearchFilter(filter);
      query = query
          .filter('name', search.operator, search.value)
          .eq('is_paid_back_row', 'false');
    }

    //created_at as fallback if multiple entrys are on the same date/check if name makes more senses
    List<Map<String, dynamic>> data = await query
        .order('expense_date')
        .order('created_at')
        .range(rangeFrom, rangeTo);

    List<Expense> retData = List.empty(growable: true);

    for (var element in data) {
      Expense expense = Expense();
      expense.loadDataFromJson(element);
      retData.add(expense);
    }

    return retData;
  }

  static Future<List<Expense>> fetchRange(
    String groupId,
    DateTime start,
    DateTime end,
  ) async {
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

  /// Every payback (settle-up) row of [groupId], newest date first
  /// (`order()` defaults to descending). Order is incidental — the guard counts
  /// rows rather than walking them in sequence.
  ///
  /// The delete guard needs the group's WHOLE settlement history: the ledger is
  /// paginated (`ExpenseListNotifier.pageSize` 20), so classifying from the
  /// loaded page would silently miss a settlement on an unloaded one. One row
  /// per settle-up ever made in the group, on a trimmed select with no `group`
  /// embed — the guard reads only `expense_date` and `is_paid_back_row`.
  static Future<List<Expense>> fetchPaybackRows(String groupId) async {
    final List<Map<String, dynamic>> data = await supabase
        .from('expense')
        .select(Expense.paybackSelectString)
        .eq('group_id', groupId)
        .eq('is_paid_back_row', true)
        .order('expense_date');

    final List<Expense> retData = List.empty(growable: true);
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

  /// Explodes one itemized line (unit price + quantity) into per-unit
  /// claim entries. Each unit is its own expense_entry (quantity 1,
  /// split_mode 'claim', amount = unit price), grouped by [itemGroupSeq] so
  /// the save_expense_all RPC can assign one shared item_group_id per run of
  /// equal sequence values (server-side grouping; no client uuid dependency).
  /// New units start with no claimers (empty shares) — the payer covers them
  /// until someone claims. When re-saving an already-shared expense,
  /// [unitClaims] carries each existing unit's claimer emails (in unit
  /// order) so claims survive the re-explode: unit i keeps unitClaims[i],
  /// each claimer at percentage = 100 / claimers (same convention as
  /// claim_set_unit_shares). Units beyond the old quantity start unclaimed;
  /// shrinking the quantity drops the trailing units' claims.
  static List<Map<String, dynamic>> explodeItemizedEntry({
    required String? name,
    required double unitPrice,
    required int quantity,
    required int itemGroupSeq,
    required int sortIdStart,
    required Currency currency,
    List<List<String>>? unitClaims,
    ExpenseConversion? conversion,
  }) {
    final qty = quantity > 0 ? quantity : 1;
    // [unitPrice] is in the ENTRY currency. The LINE total converts once and
    // the remainder is distributed, so the units sum to exactly the figure the
    // preview and the notification quote.
    final conv = conversion ?? ExpenseConversion.identity(currency);
    final enteredLineTotal = unitPrice * qty;
    final ledger = unitLedgerAmounts(
      enteredLineTotal: enteredLineTotal,
      quantity: qty,
      conversion: conv,
    );
    final originals = unitOriginalAmounts(
      enteredLineTotal: enteredLineTotal,
      quantity: qty,
      conversion: conv,
    );
    final units = <Map<String, dynamic>>[];
    for (int i = 0; i < qty; i++) {
      final claimers = (unitClaims != null && i < unitClaims.length)
          ? unitClaims[i]
          : const <String>[];
      units.add({
        'entry': {
          'name': name,
          'amount': ledger[i],
          'original_amount': originals?[i],
          'quantity': 1,
          'split_mode': 'claim',
          'item_group_seq': itemGroupSeq,
          'sort_id': sortIdStart + i,
        },
        'shares': claimers
            .map(
              (email) => <String, dynamic>{
                'email': email,
                'percentage': 100 / claimers.length,
              },
            )
            .toList(),
      });
    }
    return units;
  }

  /// Saves an expense with all its entries and share splits in ONE server
  /// transaction (`save_expense_all`): the expense row with its provenance, every
  /// entry and share, and the share recalculation commit together or not at
  /// all. Any failure, a missing function included, is thrown as the RPC's own
  /// error having written nothing: there is no client-side fallback.
  static Future<void> saveAll(
    String groupId,
    String? expenseId,
    Map<String, dynamic> formResponse, {
    required Currency currency,
    ExpenseConversion? conversion,
    required NotificationSender notifications,
  }) async {
    final conv = conversion ?? ExpenseConversion.identity(currency);
    try {
      Map<String, dynamic> upsertVals = {
        'name': formResponse['name'],
        'expense_date': formResponse['expense_date'].toString(),
        'paid_by': formResponse['paid_by'],
        'group_id': groupId,
        'user_id': supabase.auth.currentUser?.id,
        'category': (formResponse['category'] as ExpenseCategory?)?.name,
        ...conv.expenseProvenance,
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
      int itemGroupSeq = 0;
      for (var expenseEntry in expenseEntryValues.values) {
        int qty =
            int.tryParse(expenseEntry['quantity']?.toString() ?? '1') ?? 1;
        double unitPrice = double.parse(expenseEntry['amount']);
        // Entered amounts are in the ENTRY currency; the ledger value is the
        // converted one. The LINE converts once, through the same
        // [ledgerLineTotal] the editor's preview reads, so the figure previewed
        // and the figure stored are the same number by construction.
        // `toLedger` throws MissingConversionRateException when a foreign
        // currency carries no rate — no 1:1 fallback ever.
        final line = ItemLine(unitPrice: unitPrice, quantity: qty);
        double enteredTotal = line.lineTotal;
        double entryTotal = ledgerLineTotal(line, conv);
        amount = roundCurrency(amount + entryTotal, currency);

        String splitMode = expenseEntry['split_mode'] ?? 'equal';

        // Itemized claim cards register no split fields (F118), so 'shares'
        // may be absent entirely.
        Set<String> expenseEntryShares = expenseEntry['shares'] ?? <String>{};
        Map<String, dynamic> shareData = expenseEntry['share_data'] ?? {};
        Set<String> lockedMembers =
            expenseEntry['locked_members'] is Set<String>
            ? expenseEntry['locked_members']
            : <String>{};

        notificationReceiver.addAll(expenseEntryShares);

        // Claimable itemized lines are exploded into per-unit claim entries
        // (quantity 1, split_mode 'claim'), grouped server-side by a shared
        // item_group_seq. Detection: an explicit claimable flag, or a plain
        // multi-quantity itemized line with no manual custom split.
        final bool isClaimable =
            (expenseEntry['claimable'] == true) ||
            (qty > 1 && shareData.isEmpty && expenseEntryShares.isEmpty);

        if (isClaimable) {
          itemGroupSeq++;
          // Existing per-unit claims (edit round-trip, F146) — injected by
          // the editor from the regrouped entry so a re-save keeps claimers.
          final unitClaims = (expenseEntry['existing_claims'] as List?)
              ?.map((u) => (u as List).cast<String>())
              .toList();
          entries.addAll(
            ExpenseRepository.explodeItemizedEntry(
              name: expenseEntry['name'] as String?,
              unitPrice: unitPrice,
              quantity: qty,
              itemGroupSeq: itemGroupSeq,
              sortIdStart: sortId,
              currency: currency,
              unitClaims: unitClaims,
              conversion: conv,
            ),
          );
          sortId += qty * 10; // leave room between groups
          continue;
        }

        List<Map<String, dynamic>> shareRows = [];

        // Safety net: if split mode is 'exact' but all amounts are zero,
        // the widget didn't know the real total — fall back to equal split.
        bool allZeroExact =
            splitMode == 'exact' &&
            shareData.isNotEmpty &&
            shareData.values.every((v) => (v as num).toDouble() == 0.0);
        if (allZeroExact) {
          shareData = {};
        }

        if (shareData.isNotEmpty) {
          int totalParts = splitMode == 'shares'
              ? shareData.values.fold(0, (sum, v) => sum + (v as int))
              : 0;

          // An exact split's ledger amounts come out of the already-converted
          // line, not from converting each share on its own — otherwise they
          // sum to a cent less than the entry they belong to.
          final exactLedger = splitMode == 'exact'
              ? ledgerFixedAmounts(
                  enteredByEmail: {
                    for (final e in shareData.entries)
                      e.key: (e.value as num).toDouble(),
                  },
                  entryTotal: entryTotal,
                  conv: conv,
                  payer: formResponse['paid_by'] as String?,
                )
              : const <String, double>{};

          for (var entry in shareData.entries) {
            double percentage;
            double? fixedAmount;
            double? originalFixedAmount;
            int? parts;

            switch (splitMode) {
              case 'exact':
                final enteredFixed = (entry.value as num).toDouble();
                fixedAmount = exactLedger[entry.key];
                // The entry-currency twin of the ledger `fixed_amount`, so the
                // editor can reload this share into an entry-currency field
                // without inverting the conversion. Same rule (and same null
                // on an identity conversion) as `original_amount` below.
                originalFixedAmount = conv.isIdentity
                    ? null
                    : roundCurrency(enteredFixed, conv.entryCurrency);
                percentage = enteredTotal > 0
                    ? (enteredFixed / enteredTotal) * 100
                    : 0;
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
              "original_fixed_amount": originalFixedAmount,
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
            'original_amount': conv.isIdentity
                ? null
                : roundCurrency(enteredTotal, conv.entryCurrency),
            'quantity': qty,
            'split_mode': splitMode,
            'sort_id': sortId,
          },
          'shares': shareRows,
        });

        sortId += 10;
      }

      final Map<String, dynamic> params = {
        '_group_id': groupId,
        '_expense': upsertVals,
        '_entries': entries,
      };
      final override = saveExpenseAllOverride;
      final savedExpenseId =
          (override != null
                  ? await override(params)
                  : await supabase.rpc('save_expense_all', params: params))
              as String;

      if (expenseId == null) {
        unawaited(
          notifications.expenseCreated(
            savedExpenseId,
            notificationReceiver,
            amount,
          ),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Failed to save expense in group $groupId: ${e.message}');
      rethrow;
    }
  }

  /// Sets the exact claimer set for a single claim unit (one expense_entry)
  /// in ONE server transaction (`claim_set_unit_shares`), which also
  /// recalculates the group's shares. [claimerEmails] empty => the unit
  /// becomes unclaimed. Each claimer gets percentage = 100 / claimers so
  /// existing percentage-based aggregations (groupMemberShareStatistic,
  /// get_user_spending_summary) stay correct. Any failure, a missing function
  /// included, is thrown as the RPC's own error: there is no client-side
  /// fallback.
  static Future<void> claimSetUnitShares({
    required String groupId,
    required String expenseId,
    required String unitEntryId,
    required List<String> claimerEmails,
  }) async {
    final double pct = claimerEmails.isEmpty ? 0 : 100 / claimerEmails.length;
    final Map<String, dynamic> params = {
      '_group_id': groupId,
      '_expense_id': expenseId,
      '_entry_id': unitEntryId,
      '_shares': [
        for (final email in claimerEmails) {'email': email, 'percentage': pct},
      ],
    };
    final override = claimSetUnitSharesOverride;
    if (override != null) {
      await override(params);
    } else {
      await supabase.rpc('claim_set_unit_shares', params: params);
    }
  }

  /// Every expense of [groupId] that could carry its own currency, on the lean
  /// [Expense.currencyProbeSelectString]. Feeds `canChangeGroupCurrency`.
  ///
  /// Pre-migration tolerance: `original_currency_code` does not exist on a
  /// server without this feature's migration, and PostgREST answers an unknown
  /// column with 42703 / PGRST204. On that server no expense CAN carry a
  /// foreign currency, so an empty list is the correct answer — the picker
  /// stays unlocked rather than erroring.
  static Future<List<Expense>> fetchCurrencyProbeRows(String groupId) async {
    try {
      final List<Map<String, dynamic>> data = await supabase
          .from('expense')
          .select(Expense.currencyProbeSelectString)
          .eq('group_id', groupId)
          .not('original_currency_code', 'is', null);
      return [for (final element in data) Expense()..loadDataFromJson(element)];
    } on PostgrestException catch (e) {
      if (!isMissingColumnError(e)) rethrow;
      return const [];
    }
  }

  /// The RPC [delete] calls — the ONE place its name lives.
  static const String deleteRpcName = 'delete_expense';

  /// The `delete_expense` argument map.
  static Map<String, dynamic> deleteRpcParams(
    String expenseId,
    String groupId,
  ) => {'_expense_id': expenseId, '_group_id': groupId};

  /// Deletes [expenseId] from [groupId] in ONE server transaction
  /// (`delete_expense`): the expense (scoped to the group, so a mismatched pair
  /// deletes nothing), its `expense_update_checker` row and the group's
  /// recalculation commit together or not at all. The recalculation passes a
  /// null expense id, so the deleted row is never re-announced. Payback rows
  /// take the same path. Still the `ExpenseDeleter` shape.
  static Future<void> delete(String expenseId, String groupId) async {
    await supabase.rpc(
      deleteRpcName,
      params: deleteRpcParams(expenseId, groupId),
    );
  }
}
