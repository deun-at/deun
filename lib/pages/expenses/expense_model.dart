import '../../main.dart';
import '../groups/group_model.dart';

class Expense {
  late String id;
  late Group group;
  late String name;
  late double amount;
  late String createdAt;
  late String userId;

  late Map<String, ExpenseEntry> expenseEntries;

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];

    group = Group();
    if (json["group"] != null) {
      group.loadDataFromJson(json["group"]);
    }
    name = json["name"];
    createdAt = json["created_at"];
    userId = json["user_id"];

    amount = 0.0;
    expenseEntries = <String, ExpenseEntry>{};
    int _newTextFieldId = 0;
    if (json["expense_entry"] != null) {
      for (var element in json["expense_entry"]) {
        ExpenseEntry expenseEntry = ExpenseEntry(index: _newTextFieldId);
        expenseEntry.loadDataFromJson(element);
        expenseEntries.addAll({expenseEntry.id: expenseEntry});

        _newTextFieldId++;
        amount += expenseEntry.amount;
      }
    }
  }

  delete() async {
    return await supabase.from('expense').delete().eq('id', id);
  }

  static Future<List<Expense>> fetchData() async {
    List<Map<String, dynamic>> data =
        await supabase.from('expense').select('*, group(*), expense_entry(*)');

    List<Expense> retData = [];

    for (var element in data) {
      Expense expense = Expense();
      expense.loadDataFromJson(element);
      retData.add(expense);
    }

    return retData;
  }

  static Future<void> saveAll(
      String groupId, String? expenseId, Map<String, dynamic> formResponse) async {
    Map<String, dynamic> upsertVals = {
      'name': formResponse['name'],
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
          expenseEntryValues[index]?['expense_id'] =
              expenseInsertResponse['id'];
        }

        expenseEntryValues[index]?[fieldName] = value;
      }
    });

    await supabase
        .from('expense_entry')
        .delete()
        .eq('expense_id', expenseInsertResponse['id']);

    List<Map<String, dynamic>> upsertExpenseEntries =
        List.of(expenseEntryValues.values);

    await supabase.from('expense_entry').insert(upsertExpenseEntries);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonValue = {
        'name': name,
    };

    expenseEntries.forEach((key, value) {
      jsonValue.addAll({"expense_entry[${value.index}][name]": value.name});
      jsonValue.addAll({"expense_entry[${value.index}][amount]": value.amount.toString()});
    });

    return jsonValue;
  }
}

class ExpenseEntry {
  int index;
  late String id;
  late Expense expense;
  late String name;
  late double amount;
  late String createdAt;

  ExpenseEntry({required this.index});

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];

    expense = Expense();
    if (json["expense"] != null) {
      expense.loadDataFromJson(json["expense"]);
    }
    name = json["name"];
    amount = double.parse((json["amount"] ?? 0).toString());
    createdAt = json["created_at"];
  }
}
