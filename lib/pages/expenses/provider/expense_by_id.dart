import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_by_id.g.dart';

/// One expense, loaded by id for a route opened from its location. Subscribes
/// to nothing; the group's realtime refresh lives on `groupDetailProvider`.
@riverpod
Future<Expense> expenseById(Ref ref, String expenseId) =>
    ref.watch(expenseRepositoryProvider).fetchDetail(expenseId);
