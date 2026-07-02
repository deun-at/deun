import '../../groups/data/group_model.dart';
import 'expense_entry_model.dart';
import 'expense_category.dart';

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
  late ExpenseCategory? category;

  late Map<String, ExpenseEntry> expenseEntries;

  late Map<String, double> groupMemberShareStatistic;
  late String? paidByDisplayName;

  static const expenseSelectString = '*, ...paid_by(paid_by_display_name:display_name), expense_entry(*, expense_entry_share(*, ...email(display_name:display_name))), group!expense_group_id_fkey(*, group_shares_summary(*, ...paid_by(paid_by_display_name:display_name), ...paid_for(paid_for_display_name:display_name)), group_member(*, ...user(display_name:display_name, is_guest:is_guest)))';

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
    category = ExpenseCategory.fromString(json["category"]);

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

  /// Entries as the editor shows them: per-unit claim entries (split_mode
  /// 'claim', quantity 1) produced by the itemized share-for-claiming save
  /// are regrouped by item_group_id into one synthetic qty-N entry (amount =
  /// group total, unitClaims = each unit's claimer emails in unit order).
  /// Non-claim entries pass through unchanged. Indices are reassigned
  /// sequentially so form field names stay dense.
  List<ExpenseEntry> get editorEntries {
    final grouped = <String, ExpenseEntry>{};
    for (final entry in expenseEntries.values) {
      if (!entry.isClaimUnit) {
        // ponytail: key by id — pass-through entries never merge.
        grouped[entry.id] = entry;
        continue;
      }
      // Standalone claim unit (no group id) groups with itself only.
      final key = entry.itemGroupId ?? entry.id;
      final existing = grouped[key];
      final claims =
          entry.expenseEntryShares.map((s) => s.email).toList(growable: false);
      if (existing == null) {
        final synthetic = ExpenseEntry(index: 0)
          ..id = entry.id
          ..expenseId = entry.expenseId
          ..name = entry.name
          ..amount = entry.amount
          ..quantity = 1
          ..splitMode = entry.splitMode
          ..createdAt = entry.createdAt
          ..itemGroupId = entry.itemGroupId
          ..unitClaims = [claims];
        grouped[key] = synthetic;
      } else {
        existing
          ..amount += entry.amount
          ..quantity += 1
          ..unitClaims = [...existing.unitClaims, claims];
      }
    }
    final result = grouped.values.toList();
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
      jsonValue.addAll({"expense_entry[${value.index}][amount]": value.unitPrice.toStringAsFixed(2)});
      jsonValue.addAll({"expense_entry[${value.index}][shares]": value.expenseEntryShares.map((e) => e.email).toSet()});
    }

    return jsonValue;
  }
}
