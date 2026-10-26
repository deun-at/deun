import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void navigateToGroup(BuildContext context, Group group) {
  // Navigate to the group detail page
  GoRouter.of(context).go("/group");
  GoRouter.of(context).push("/group/details", extra: {'group': group});
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
/// editor (`/group/details/expense`) — that route doubles as the create screen
/// and is reached only from the "+" and the read view's edit action.
void openLedgerExpense(BuildContext context, Group group, Expense expense) {
  GoRouter.of(context).push(
    expense.hasClaimUnits
        ? "/group/details/claim"
        : "/group/details/expense-detail",
    extra: {'group': group, 'expense': expense},
  );
}

/// Push-notification entry point (both cold start and background — see
/// `_handleMessage` in `lib/navigation.dart`). Puts the group detail on the
/// stack, then opens the expense exactly where a ledger tap would, so
/// dismissing it falls back to the group detail with no editor underneath.
void navigateToExpense(BuildContext context, Expense expense) {
  navigateToGroup(context, expense.group);
  openLedgerExpense(context, expense.group, expense);
}

void navigateToFriends(BuildContext context) {
  GoRouter.of(context).go("/friend");
}
