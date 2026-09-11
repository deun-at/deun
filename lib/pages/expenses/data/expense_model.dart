import '../../../helper/helper.dart';
import '../../groups/data/group_model.dart';
import 'expense_conversion.dart';
import 'expense_entry_model.dart';
import 'expense_category.dart';

class Expense {
  late String id;
  late String groupId;

  /// The owning group. Default-initialized so that reading `group.currencyCode`
  /// for amount formatting is safe even when an Expense is built without its
  /// group loaded (e.g. in tests); production always loads it via the select.
  Group group = Group();
  late String name;
  late double amount;
  late String? paidBy;
  late String expenseDate;
  late String createdAt;
  late bool isPaidBackRow;
  late ExpenseCategory? category;

  late Map<String, ExpenseEntry> expenseEntries;

  late Map<String, double> groupMemberShareStatistic;
  late String? paidByDisplayName;

  /// Who wrote this row, from `expense.user_id`. On a payback that is the
  /// recorder, who is the payer on the ordinary self-payback and somebody else
  /// when the payback was recorded on the payer's behalf. Null on every row
  /// written before `pay_back` started stamping it.
  String? recordedByEmail;
  String? recordedByDisplayName;

  /// ISO 4217 code the amounts were ENTERED in, when that differs from the
  /// group's currency. Null means the expense is in the group's own currency.
  /// PROVENANCE ONLY — no balance path reads it.
  String? originalCurrencyCode;

  /// The frozen rate applied at entry: 1 [originalCurrencyCode] =
  /// [conversionRate] group currency. Never recomputed.
  double? conversionRate;

  /// `yyyy-MM-dd` the [conversionRate] is attributed to. Stamped when the entry
  /// currency was chosen, and never re-stamped by an edit to anything else — a
  /// rate only gets a new date when it is a new rate for a new currency pair.
  String? rateDate;

  static const expenseSelectString =
      '*, ...paid_by(paid_by_display_name:display_name), ...user_id(recorded_by_email:email, recorded_by_display_name:display_name), expense_entry(*, expense_entry_share(*, ...email(display_name:display_name))), group!expense_group_id_fkey(*, group_shares_summary(*, ...paid_by(paid_by_display_name:display_name), ...paid_for(paid_for_display_name:display_name)), group_member(*, ...user(display_name:display_name, is_guest:is_guest)))';

  /// Lean select for a group's payback rows (see
  /// `ExpenseRepository.fetchPaybackRows`): only the columns [loadDataFromJson]
  /// needs to build a valid [Expense] without crashing (the non-nullable
  /// `late` fields) plus [expenseDate] and [isPaidBackRow], which is all
  /// `classifyExpenseDeletion` ever reads off a probed row. No `paid_by` join,
  /// no `expense_entry` tree, no `group` embed — the guard never reads amounts,
  /// shares, or the group off these rows; [group] simply stays
  /// default-initialized and callers format amounts with the group they
  /// already hold.
  static const paybackSelectString =
      'id, group_id, name, expense_date, created_at, is_paid_back_row';

  /// Lean select for the group-currency lock probe: only what
  /// [loadDataFromJson] needs for its non-nullable `late` fields, plus the
  /// original currency the lock decides on. No `group` embed, no entry tree.
  static const currencyProbeSelectString =
      'id, group_id, name, expense_date, created_at, is_paid_back_row, original_currency_code';

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
    recordedByEmail = json["recorded_by_email"];
    recordedByDisplayName = json["recorded_by_display_name"];
    createdAt = json["created_at"];
    isPaidBackRow = json["is_paid_back_row"];
    category = ExpenseCategory.fromString(json["category"]);
    originalCurrencyCode = json["original_currency_code"];
    conversionRate = json["conversion_rate"] != null
        ? double.parse(json["conversion_rate"].toString())
        : null;
    rateDate = json["rate_date"]?.toString();

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
                (groupMemberShareStatistic[e.email] ?? 0) +
                (expenseEntry.amount * (e.percentage / 100));
          }
        }
      }
    }
  }

  /// True when this expense carries per-unit claim entries (the new claim
  /// model). Old itemized expenses (manual multi-entry splits from before the
  /// claim feature) have none — the claim screen can't show them, so routing
  /// gates on this to send them to the read view instead.
  bool get hasClaimUnits => expenseEntries.values.any((e) => e.isClaimUnit);

  /// True when this settle-up row was recorded by someone other than the payer.
  ///
  /// Gated on [isPaidBackRow] deliberately: on a normal expense `user_id` and
  /// `paid_by` differ all the time (anyone may enter an expense someone else
  /// paid) and that is not attribution-worthy. On a payback it is the whole
  /// point — the record carries who made it.
  bool get isRecordedOnBehalf =>
      isPaidBackRow &&
      (recordedByEmail ?? '').isNotEmpty &&
      recordedByEmail != paidBy;

  /// The currency the amounts were ENTERED in: the frozen original currency
  /// when this expense was converted, otherwise the group's own.
  Currency get entryCurrency => originalCurrencyCode != null
      ? Currency.fromCode(originalCurrencyCode)
      : group.currency;

  /// This expense's total AS ENTERED, in [entryCurrency]. Null when the expense
  /// was not converted.
  double? get originalAmount {
    if (originalCurrencyCode == null) return null;
    double sum = 0;
    var seen = false;
    for (final entry in expenseEntries.values) {
      final original = entry.originalAmount;
      if (original == null) continue;
      seen = true;
      sum += original;
    }
    return seen ? roundCurrency(sum, entryCurrency) : null;
  }

  /// True when this expense was entered in a currency other than
  /// [groupCurrency]. The evidence `canChangeGroupCurrency` locks a group's
  /// picker on. Compared against the passed currency rather than the embedded
  /// [group], because the lock probe reads rows on a lean select with no group.
  bool isForeignCurrencyIn(Currency groupCurrency) =>
      originalCurrencyCode != null &&
      Currency.fromCode(originalCurrencyCode) != groupCurrency;

  /// Entries grouped per item card, insertion-ordered: per-unit claim entries
  /// (split_mode 'claim', quantity 1) group by item_group_id — a standalone
  /// unit (no group id) forms a group of one — and every other entry passes
  /// through as its own single-entry group (keyed by id, so they never merge).
  /// Shared by the editor's qty-N regrouping ([editorEntries], F146) and the
  /// claim screen's per-unit item cards (F131).
  Map<String, List<ExpenseEntry>> get entriesByItem {
    final grouped = <String, List<ExpenseEntry>>{};
    for (final entry in expenseEntries.values) {
      final key = entry.isClaimUnit
          ? (entry.itemGroupId ?? entry.id)
          : entry.id;
      (grouped[key] ??= []).add(entry);
    }
    return grouped;
  }

  /// Entries as the editor shows them: each [entriesByItem] claim group
  /// collapses into one synthetic qty-N entry (amount = group total,
  /// unitClaims = each unit's claimer emails in unit order). Non-claim
  /// entries pass through unchanged. Indices are reassigned sequentially so
  /// form field names stay dense.
  List<ExpenseEntry> get editorEntries {
    final result = <ExpenseEntry>[];
    for (final group in entriesByItem.values) {
      final first = group.first;
      if (!first.isClaimUnit) {
        result.add(first);
      } else {
        result.add(
          ExpenseEntry(index: 0)
            ..id = first.id
            ..expenseId = first.expenseId
            ..name = first.name
            ..amount = group.fold(0.0, (sum, e) => sum + e.amount)
            ..originalAmount = group.every((e) => e.originalAmount != null)
                ? group.fold<double>(0.0, (sum, e) => sum + e.originalAmount!)
                : null
            ..quantity = group.length
            ..splitMode = first.splitMode
            ..createdAt = first.createdAt
            ..itemGroupId = first.itemGroupId
            ..unitClaims = [
              for (final e in group)
                e.expenseEntryShares
                    .map((s) => s.email)
                    .toList(growable: false),
            ],
        );
      }
    }
    for (var i = 0; i < result.length; i++) {
      result[i].index = i;
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonValue = {
      'name': name,
      'paid_by': paidBy,
      'category': category?.name,
    };

    // Uses the regrouped editor entries so form-level initial values line up
    // with the item cards the editor renders (claim units collapse to one
    // qty-N card). Amount is the unit price — the per-item amount field the
    // cards register.
    for (final value in editorEntries) {
      jsonValue.addAll({"expense_entry[${value.index}][name]": value.name});
      jsonValue.addAll({
        // Machine round-trip text at the ENTRY currency's precision, so a JPY
        // expense seeds the editor field with "3000" and not "3000.00", and a
        // converted expense seeds from the amount AS ENTERED rather than the
        // ledger value. A group-less Expense keeps the default Group's EUR
        // precision.
        //
        // Through [unitPriceFieldTextForTotal] rather than a plain division so
        // a multi-unit line whose total did not divide evenly reloads with the
        // digits that multiply back to it — the save reads unit price x
        // quantity, and "9.43" x 3 stores 28.29 for a 28.30 line.
        "expense_entry[${value.index}][amount]": unitPriceFieldTextForTotal(
          value.enteredLineTotal,
          value.quantity,
          entryCurrency,
        ),
      });
      jsonValue.addAll({
        "expense_entry[${value.index}][shares]": value.expenseEntryShares
            .map((e) => e.email)
            .toSet(),
      });
    }

    return jsonValue;
  }
}
