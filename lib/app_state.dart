import 'package:flutter/material.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';

class AppState {
  ValueNotifier<Map<int, Group>> groupItems = ValueNotifier(<int, Group>{});
  ValueNotifier<List<Expense>> expenseItems = ValueNotifier([]);

  Future<void> fetchGroupData() async {
    debugPrint("fetchGroupData");
    groupItems.value = await Group.fetchData();
  }

  Future<void> fetchExpenseData() async {
    debugPrint("fetchExpenseData");
    expenseItems.value = await Expense.fetchData();
  }
}
