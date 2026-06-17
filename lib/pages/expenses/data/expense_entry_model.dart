class ExpenseEntry {
  int index;
  late String id;
  late String expenseId;
  late String? name;
  late double amount;
  late int quantity;
  late String splitMode;
  late String createdAt;
  late String? itemGroupId;

  double get unitPrice => quantity > 0 ? amount / quantity : amount;

  /// True when this entry is a single claimable unit produced by the
  /// per-unit claim model (split_mode 'claim', quantity 1).
  bool get isClaimUnit => splitMode == 'claim' && quantity == 1;

  List<ExpenseEntryShare> expenseEntryShares = [];

  ExpenseEntry({required this.index});

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];

    expenseId = json["expense_id"];
    name = json["name"];
    amount = double.parse((json["amount"] ?? 0).toString());
    quantity = int.tryParse((json["quantity"] ?? 1).toString()) ?? 1;
    splitMode = json["split_mode"] ?? 'equal';
    createdAt = json["created_at"];
    itemGroupId = json["item_group_id"];

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
  late String displayName;
  late double percentage;
  late double? fixedAmount;
  late int? parts;
  late bool isLocked;
  late String createdAt;

  void loadDataFromJson(Map<String, dynamic> json) {
    expenseEntryId = json["expense_entry_id"];
    email = json["email"];
    displayName = json["display_name"];
    percentage = double.parse((json["percentage"] ?? 0).toString());
    fixedAmount = json["fixed_amount"] != null
        ? double.parse(json["fixed_amount"].toString())
        : null;
    parts = json["parts"] != null ? int.tryParse(json["parts"].toString()) : null;
    isLocked = json["is_locked"] == true;
    createdAt = json["created_at"];
  }
}
