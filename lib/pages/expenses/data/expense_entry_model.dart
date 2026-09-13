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

  /// This entry's amount AS ENTERED, in the expense's original currency. Null
  /// on every entry that was not converted (and on every row read from a
  /// pre-migration server, where the column simply does not come back).
  double? originalAmount;

  double get unitPrice => quantity > 0 ? amount / quantity : amount;

  /// True when this entry's amounts were converted on the way in, i.e. its
  /// [amount] is a LEDGER value that differs from what the user typed.
  ///
  /// `original_amount` is written for every entry of a converted expense and
  /// for none of an unconverted one (see `ExpenseRepository.saveAll`), so its
  /// presence is the entry-level answer to "is this row's money column in the
  /// entry currency or the ledger currency".
  bool get isConverted => originalAmount != null;

  /// This line's total AS ENTERED, in the expense's entry currency.
  double get enteredLineTotal => originalAmount ?? amount;

  /// The unit price as the user TYPED it: the original amount when this entry
  /// was converted, the ledger amount otherwise.
  ///
  /// A plain division, so it is only the seed for a single-unit line — a
  /// multi-unit line has to go through [unitPriceFieldTextForTotal], which
  /// keeps the digits that make unit price x quantity round back to
  /// [enteredLineTotal].
  double get enteredUnitPrice {
    final entered = enteredLineTotal;
    return quantity > 0 ? entered / quantity : entered;
  }

  /// True when this entry is a single claimable unit produced by the
  /// per-unit claim model (split_mode 'claim', quantity 1).
  bool get isClaimUnit => splitMode == 'claim' && quantity == 1;

  /// Per-unit claimer emails, in unit order. Only populated on the synthetic
  /// qty-N entries produced by [Expense.editorEntries] when regrouping claim
  /// units for the editor — used to preserve existing claims on re-save.
  List<List<String>> unitClaims = const [];

  List<ExpenseEntryShare> expenseEntryShares = [];

  ExpenseEntry({required this.index});

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];

    expenseId = json["expense_id"];
    name = json["name"];
    amount = double.parse((json["amount"] ?? 0).toString());
    originalAmount = json["original_amount"] != null
        ? double.parse(json["original_amount"].toString())
        : null;
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

  /// This exact-split share in the LEDGER (group) currency — the value every
  /// balance path reads. Never seed an editor field from it directly; use
  /// [enteredFixedAmount].
  late double? fixedAmount;

  /// This exact-split share AS ENTERED, in the expense's original currency.
  /// Null on every share that was not converted (and on every row read from a
  /// pre-migration server, where the column simply does not come back).
  double? originalFixedAmount;
  late int? parts;
  late bool isLocked;
  late String createdAt;

  /// This share's exact-split amount in the ENTRY currency — what the editor's
  /// exact-split field must hold — or null when the row carries no usable
  /// entered value and the caller has to fall back to the percentage.
  ///
  /// [fixedAmount] is converted before the write (`ExpenseRepository.saveAll`),
  /// so it is the entered amount only while [isConverted] is false. Feeding it
  /// back into an entry-currency field on a converted expense makes the next
  /// save convert it a second time — the ledger amount silently shrinking by
  /// the rate on every re-save, and the derived percentage mixing the two
  /// currencies.
  double? enteredFixedAmount({required bool isConverted}) =>
      isConverted ? originalFixedAmount : fixedAmount;

  void loadDataFromJson(Map<String, dynamic> json) {
    expenseEntryId = json["expense_entry_id"];
    email = json["email"];
    // Same guard as GroupMember: display_name is joined from the user table, so
    // a deleted user yields null while this share row still carries the email
    // the balance math keys on. Shares are parsed in a loop nested two deep
    // inside the group fetch — throwing here would fail the whole load.
    displayName = json["display_name"] ?? email;
    percentage = double.parse((json["percentage"] ?? 0).toString());
    fixedAmount = json["fixed_amount"] != null
        ? double.parse(json["fixed_amount"].toString())
        : null;
    originalFixedAmount = json["original_fixed_amount"] != null
        ? double.parse(json["original_fixed_amount"].toString())
        : null;
    parts = json["parts"] != null
        ? int.tryParse(json["parts"].toString())
        : null;
    isLocked = json["is_locked"] == true;
    createdAt = json["created_at"];
  }
}
