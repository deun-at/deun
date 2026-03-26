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

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonValue = {
      'name': name,
      'paid_by': paidBy,
      'category': category?.name,
    };

    expenseEntries.forEach((key, value) {
      jsonValue.addAll({"expense_entry[${value.index}][name]": value.name});
      jsonValue.addAll({"expense_entry[${value.index}][amount]": value.amount.toString()});
      jsonValue.addAll({"expense_entry[${value.index}][shares]": value.expenseEntryShares.map((e) => e.email).toSet()});
    });

    return jsonValue;
  }
}
