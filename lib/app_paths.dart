import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/groups/data/group_model.dart';

/// Every group and expense location, built from ids. The router reads the
/// same shapes back (lib/app_router.dart); a page opened from one of these
/// needs nothing but its location.
abstract final class AppPaths {
  static const String groupNew = '/group/new';

  static String group(String groupId) => '/group/$groupId';
  static String groupEdit(String groupId) => '${group(groupId)}/edit';
  static String groupMembers(String groupId) => '${group(groupId)}/members';
  static String groupShare(String groupId) => '${group(groupId)}/share';
  static String groupPayment(String groupId) => '${group(groupId)}/payment';
  static String groupStatistics(String groupId) =>
      '${group(groupId)}/statistics';

  /// The month sheet for the window [start]–[end].
  static String groupStatisticsMonth(
    String groupId, {
    required DateTime start,
    required DateTime end,
  }) => Uri(
    path: '${groupStatistics(groupId)}/month',
    queryParameters: _window(start, end),
  ).toString();

  /// The category sheet for [category] over the window [start]–[end].
  static String groupStatisticsCategory(
    String groupId, {
    required String category,
    required DateTime start,
    required DateTime end,
  }) => Uri(
    path: '${groupStatistics(groupId)}/category',
    queryParameters: {'name': category, ..._window(start, end)},
  ).toString();

  static String expenseNew(String groupId) => '${group(groupId)}/expense/new';
  static String expense(String groupId, String expenseId) =>
      '${group(groupId)}/expense/$expenseId';
  static String expenseEdit(String groupId, String expenseId) =>
      '${expense(groupId, expenseId)}/edit';
  static String expenseClaim(String groupId, String expenseId) =>
      '${expense(groupId, expenseId)}/claim';

  /// A statistics window as `from`/`to` local date-times; the router parses
  /// them back with `DateTime.tryParse`.
  static Map<String, String> _window(DateTime start, DateTime end) => {
    'from': start.toIso8601String(),
    'to': end.toIso8601String(),
  };
}

/// The object an expense route may be pushed with so it renders at once. The
/// path stays authoritative: the route ignores an extra whose ids differ.
final class ExpenseRouteExtra {
  const ExpenseRouteExtra({
    required this.group,
    this.expense,
    this.receiptResult,
  });

  final Group group;
  final Expense? expense;

  /// A transient scan for the new-expense editor. It has no address, so a
  /// refresh of that location opens an empty editor.
  final ReceiptScanResult? receiptResult;
}
