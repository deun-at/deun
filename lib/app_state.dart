import 'package:flutter/material.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';

class AppState {
  ValueNotifier<ListGroupState> groupItems = ValueNotifier(ListGroupState(isLoading: true, data: <String, Group>{}));
  ValueNotifier<ListExpenseState> expenseItems = ValueNotifier(ListExpenseState(isLoading: true, data: <String, Expense>{}));

  Future<void> fetchGroupData() async {
    debugPrint("fetchGroupData");
    var data = await Group.fetchData();
    debugPrint("fetchGroupData finish");
    groupItems.value = ListGroupState(isLoading: false, data: data);
  }

  Future<void> fetchExpenseData() async {
    debugPrint("fetchExpenseData");
    var data = await Expense.fetchData();
    expenseItems.value = ListExpenseState(isLoading: false, data: data);
  }
}

class ListGroupState {
  final bool isLoading;
  final Map<String, Group> data;

  ListGroupState({required this.isLoading, required this.data});
}

class ListExpenseState {
  final bool isLoading;
  final Map<String, Expense> data;

  ListExpenseState({required this.isLoading, required this.data});
}
