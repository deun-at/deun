import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

@riverpod
Future<List<Group>> groupList(Ref ref) async {
  return await Group.fetchData();
}

@riverpod
Future<Group> groupDetail(Ref ref, String groupId) async {
  return await Group.fetchDetail(groupId);
}

@riverpod
Future<Expense> expenseDetail(Ref ref, String expenseId) async {
  return await Expense.fetchDetail(expenseId);
}

@riverpod
Future<List<Expense>> expenseList(Ref ref) async {
  return await Expense.fetchData();
}
