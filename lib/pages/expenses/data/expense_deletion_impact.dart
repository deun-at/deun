import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';

import 'expense_model.dart';
import 'expense_repository.dart';

/// Loads every payback (settle-up) row of one group.
///
/// The guard must not classify from the ledger page it happens to have in
/// memory: `ExpenseListNotifier` paginates at 20, so a settlement sitting on an
/// unloaded page would silently read as "nothing settled". Production binding is
/// `ExpenseRepository.fetchPaybackRows`; widget tests inject a stub so they
/// never reach the network.
typedef GroupPaybackLoader = Future<List<Expense>> Function(String groupId);

/// What deleting an expense will do to balances that were already settled,
/// decided before the confirmation is shown.
///
/// Presentation only. No case here changes what is written — [Expense] deletion
/// still runs `ExpenseRepository.delete` unchanged. The impact only chooses which
/// copy the user has to confirm, and an expense is never made undeletable.
sealed class ExpenseDeletionImpact {
  const ExpenseDeletionImpact();

  /// Nothing has been settled at or after this expense — today's plain
  /// confirmation, unchanged.
  static const ExpenseDeletionImpact none = ExpenseDeletionNone();

  /// The row being deleted **is** a settlement: [counterparty] was paid
  /// [amount], and the debt that payment cleared will be open again.
  const factory ExpenseDeletionImpact.reopensSettlement({
    required String counterparty,
    required double amount,
  }) = ExpenseDeletionReopensSettlement;

  /// A normal expense that [paybackCount] settlements already covered. Deleting
  /// it moves balances people have already paid against.
  const factory ExpenseDeletionImpact.alreadySettled({
    required int paybackCount,
  }) = ExpenseDeletionAlreadySettled;
}

class ExpenseDeletionNone extends ExpenseDeletionImpact {
  const ExpenseDeletionNone();
}

class ExpenseDeletionReopensSettlement extends ExpenseDeletionImpact {
  const ExpenseDeletionReopensSettlement({
    required this.counterparty,
    required this.amount,
  });

  /// Display name of the member the settlement was made with.
  final String counterparty;

  /// The settled amount, in the group currency.
  final double amount;
}

class ExpenseDeletionAlreadySettled extends ExpenseDeletionImpact {
  const ExpenseDeletionAlreadySettled({required this.paybackCount});

  /// How many payback rows sit on or after the expense's day (never zero).
  final int paybackCount;
}

/// Classifies what deleting [expense] would reopen, given [groupExpenses] — the
/// group's payback rows (extra non-payback rows are ignored, so handing it the
/// whole expense list is equally valid).
///
/// Pure: no Supabase, no context, no clock. Detection reuses
/// [Expense.isPaidBackRow] — the same flag `classifyLedgerRow` keys the ledger's
/// payback row off — rather than a second notion of "is a settlement".
///
/// A payback dated the **same day** as [expense] counts as covering it:
/// `expense_date` is a date, not a timestamp (and `pay_back` stamps `now()` into
/// it), so a strict `>` would miss the ordinary "settle up at the end of the
/// night" case. A payback dated strictly before it does not count.
ExpenseDeletionImpact classifyExpenseDeletion(
  Expense expense,
  List<Expense> groupExpenses,
) {
  if (expense.isPaidBackRow) {
    return ExpenseDeletionImpact.reopensSettlement(
      counterparty: _paybackCounterparty(expense),
      amount: expense.amount,
    );
  }

  final expenseDay = localDayOf(expense.expenseDate);
  final covering = groupExpenses
      .where(
        (e) =>
            e.isPaidBackRow && !localDayOf(e.expenseDate).isBefore(expenseDay),
      )
      .length;

  return covering == 0
      ? ExpenseDeletionImpact.none
      : ExpenseDeletionImpact.alreadySettled(paybackCount: covering);
}

/// Probes what deleting [expense] would reopen, shared by both delete call
/// sites (the read view and the editor) so the probe-fetch-classify sequence
/// exists exactly once.
///
/// Skips the network round-trip entirely when [expense] is itself a payback
/// row: [classifyExpenseDeletion] never reads `groupExpenses` in that branch,
/// so fetching them first would be a guaranteed-wasted request on every
/// settlement delete. Otherwise loads the group's payback rows via [loader]
/// (production default: `ExpenseRepository.fetchPaybackRows`) and classifies
/// against them. A failed probe degrades to [ExpenseDeletionImpact.none] —
/// today's plain confirmation — rather than blocking the delete: this guard
/// is presentation-only, never a reason to trap the user behind a network
/// error.
Future<ExpenseDeletionImpact> probeDeletionImpact(
  Expense expense, {
  GroupPaybackLoader? loader,
}) async {
  if (expense.isPaidBackRow) {
    return classifyExpenseDeletion(expense, const []);
  }

  try {
    final paybacks = await (loader ?? ExpenseRepository.fetchPaybackRows)(
      expense.groupId,
    );
    return classifyExpenseDeletion(expense, paybacks);
  } catch (e) {
    debugPrint('Payback probe failed for group ${expense.groupId}: $e');
    return ExpenseDeletionImpact.none;
  }
}

/// The member a payback row settled with: the single share on the row's single
/// entry (`pay_back` writes exactly one of each — see
/// `20260815000000_baseline_ledger_functions.sql`). Empty when the row carries no
/// share at all, which a real payback row never does.
String _paybackCounterparty(Expense expense) {
  for (final entry in expense.expenseEntries.values) {
    for (final share in entry.expenseEntryShares) {
      return share.displayName;
    }
  }
  return '';
}

/// The confirmation copy each impact asks for. Kept next to the classifier the
/// same way `breakdownHeading` sits next to its view model — the classifier
/// itself stays pure; only these getters know about l10n.
extension ExpenseDeletionImpactCopy on ExpenseDeletionImpact {
  /// Sheet title. [ExpenseDeletionNone] is today's title, unchanged.
  String confirmTitle(AppLocalizations l10n) => switch (this) {
    ExpenseDeletionNone() => l10n.expenseDeleteItemTitle,
    ExpenseDeletionReopensSettlement() => l10n.expenseDeletePaybackTitle,
    ExpenseDeletionAlreadySettled() => l10n.expenseDeleteSettledTitle,
  };

  /// Sheet body. [ExpenseDeletionNone] is today's body, unchanged.
  /// [currencyCode] formats the settled amount — pass the *group's* currency,
  /// not the payback row's (rows fetched for the guard carry no group embed).
  String confirmMessage(AppLocalizations l10n, String currencyCode) =>
      switch (this) {
        ExpenseDeletionNone() => l10n.expenseDeleteItemMessage,
        ExpenseDeletionReopensSettlement(:final counterparty, :final amount) =>
          l10n.expenseDeletePaybackMessage(
            l10n.toCurrency(amount, currencyCode),
            counterparty,
          ),
        ExpenseDeletionAlreadySettled(:final paybackCount) =>
          l10n.expenseDeleteSettledMessage(paybackCount),
      };
}
