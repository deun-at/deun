import 'package:deun/app_paths.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens group [groupId] over the group list. [group], when at hand, renders
/// the page at once; without it the route loads the group.
void navigateToGroup(BuildContext context, String groupId, {Group? group}) {
  GoRouter.of(context).go('/group');
  GoRouter.of(context).push(AppPaths.group(groupId), extra: group);
}

/// Opens an expense the same way the ledger does: expenses with per-unit claim
/// items go to Tap-to-Claim (Screen 9); everything else — quick expenses AND
/// old itemized expenses with manual splits (no claim units) — goes to the read
/// detail (Screen 11), which shows the real per-member breakdown. Routing on
/// claim units (not entry count) keeps old itemized expenses off the claim
/// screen, where they'd read as €0.00 / "no claimable items".
///
/// THE single expense opener: the ledger tap, the expense search AND push
/// notifications ([navigateToExpense]) all route through here, so a notification
/// can never land somewhere the in-app list wouldn't. Neither branch is the
/// editor (`AppPaths.expenseEdit`) — that route is reached only from the read
/// view's edit action, and the create screen (`AppPaths.expenseNew`) only from
/// the "+".
void openLedgerExpense(BuildContext context, Group group, Expense expense) {
  GoRouter.of(context).push(
    expense.hasClaimUnits
        ? AppPaths.expenseClaim(group.id, expense.id)
        : AppPaths.expense(group.id, expense.id),
    extra: ExpenseRouteExtra(group: group, expense: expense),
  );
}

/// Push-notification entry point (both cold start and background — see
/// `_handleMessage` in `lib/navigation.dart`). Puts the group detail on the
/// stack, then opens the expense exactly where a ledger tap would, so
/// dismissing it falls back to the group detail with no editor underneath.
void navigateToExpense(BuildContext context, Expense expense) {
  navigateToGroup(context, expense.group.id, group: expense.group);
  openLedgerExpense(context, expense.group, expense);
}

void navigateToFriends(BuildContext context) {
  GoRouter.of(context).go("/friend");
}
