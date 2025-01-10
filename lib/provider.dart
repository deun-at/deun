import 'package:deun/constants.dart';
import 'package:deun/pages/friends/friendship_model.dart';
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
Future<List<Expense>> expenseList(Ref ref) async {
  return await Expense.fetchData();
}

@riverpod
Future<List<Friendship>> friendshipList(Ref ref) async {
  return await Friendship.fetchData();
}

@riverpod
class ThemeColor extends _$ThemeColor {
  /// Classes annotated by `@riverpod` **must** define a [build] function.
  /// This function is expected to return the initial state of your shared state.
  /// It is totally acceptable for this function to return a [Future] or [Stream] if you need to.
  /// You can also freely define parameters on this method.
  @override
  Color build() => ColorSeed.baseColor.color;

  void setColor(Color color) => state = color;
  void resetColor() => state = ColorSeed.baseColor.color;
}
