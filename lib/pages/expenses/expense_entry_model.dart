class ExpenseEntry {
  int index;
  late String id;
  late String expenseId;
  late String? name;
  late double amount;
  late String createdAt;

  List<ExpenseEntryShare> expenseEntryShares = [];

  ExpenseEntry({required this.index});

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];

    expenseId = json["expense_id"];
    name = json["name"];
    amount = double.parse((json["amount"] ?? 0).toString());
    createdAt = json["created_at"];

    expenseEntryShares = [];
    if (json["expense_entry_share"] != null) {
      for (var element in json["expense_entry_share"]) {
        ExpenseEntryShare expenseEntryShare = ExpenseEntryShare();
        expenseEntryShare.loadDataFromJson(element);
        expenseEntryShares.add(expenseEntryShare);
      }
    }
  }
}

class ExpenseEntryShare {
  late String expenseEntryId;
  late String email;
  late double percentage;
  late String createdAt;

  void loadDataFromJson(Map<String, dynamic> json) {
    expenseEntryId = json["expense_entry_id"];
    email = json["email"];
    percentage = double.parse((json["percentage"] ?? 0).toString());
    createdAt = json["created_at"];
  }
}
