import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_ledger.dart';
import 'package:deun/pages/groups/presentation/payback_detail_sheet.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/empty_state.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/data/expense_model.dart';
import '../../expenses/provider/expense_list.dart';

class GroupDetailList extends ConsumerStatefulWidget {
  const GroupDetailList({super.key, required this.group, this.adBlock});

  final Group group;
  final Widget? adBlock;

  @override
  ConsumerState<GroupDetailList> createState() => _GroupDetailListState();
}

class _GroupDetailListState extends ConsumerState<GroupDetailList> {
  int oldOffset = 0;

  Future<void> updateExpenseList() async {
    return ref
        .read(expenseListProvider(widget.group.id).notifier)
        .reload(widget.group.id);
  }

  void _openExpense(Expense expense) =>
      openLedgerExpense(context, widget.group, expense);

  void _openPayback(Expense expense) =>
      showPaybackDetailSheet(context, group: widget.group, expense: expense);

  /// Combined-list index for the inline ad: right after the day section that
  /// contains the 5th expense, so it appears near the top regardless of how the
  /// expenses cluster into days. Falls back to after the last section when there
  /// are fewer than 5 expenses total (matching the "or last" behaviour).
  int _adSlotIndex(List<LedgerDaySection> sections) {
    const target = 5;
    var running = 0;
    for (var i = 0; i < sections.length; i++) {
      running += sections[i].expenses.length;
      if (running >= target) return i + 1;
    }
    return sections.length;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final expenseListState = ref.watch(
          expenseListProvider(widget.group.id),
        );
        final isLoading = expenseListState.isLoading;
        final expenses = expenseListState.value;
        oldOffset = ref
            .read(expenseListProvider(widget.group.id).notifier)
            .offset;

        if (isLoading) {
          // Mirror the real day-grouped ledger (section header + joined
          // LedgerQuickRow cards) rather than flat bars (F166).
          return const ShimmerCardList(
            height: 80,
            listEntryLength: 12,
            shape: ShimmerShape.ledger,
          );
        }

        if (expenses == null || expenses.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          // No CTA: the screen already carries an extended, labelled
          // "Add expense" FAB (group_detail.dart), so a button here would be a
          // third way to do one thing. The body names the FAB instead, which
          // also teaches the affordance the user will keep using.
          return EmptyState.refreshable(
            onRefresh: updateExpenseList,
            icon: Icons.receipt_long_outlined,
            headline: l10n.emptyExpensesHeadline,
            body: l10n.emptyExpensesBody,
          );
        }

        final sections = groupExpensesByDay(expenses);

        // Inline ad slot: sit right after the day-section holding the 5th
        // expense (or after the last section when there are fewer), so it's
        // visible without scrolling to the very bottom — which, with many
        // expenses, it never reached (the old placement was a trailing footer).
        final bool hasAd = widget.adBlock != null;
        final int adPos = hasAd ? _adSlotIndex(sections) : -1;

        return RefreshIndicator(
          onRefresh: () => updateExpenseList(),
          child: NotificationListener<ScrollNotification>(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              itemCount: sections.length + (hasAd ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasAd && index == adPos) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: widget.adBlock,
                  );
                }

                final section =
                    sections[hasAd && index > adPos ? index - 1 : index];
                return _DaySection(
                  section: section,
                  group: widget.group,
                  onOpenExpense: _openExpense,
                  onOpenPayback: _openPayback,
                );
              },
            ),
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >
                  scrollInfo.metrics.maxScrollExtent -
                      MediaQuery.of(context).size.height) {
                if (oldOffset ==
                    ref
                        .read(expenseListProvider(widget.group.id).notifier)
                        .offset) {
                  // make sure ListView has newest data after previous loadMore
                  ref
                      .read(expenseListProvider(widget.group.id).notifier)
                      .loadMoreEntries(widget.group.id);
                }
              }
              return false;
            },
          ),
        );
      },
    );
  }
}

/// A day header followed by the ledger rows for that calendar day.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.section,
    required this.group,
    required this.onOpenExpense,
    required this.onOpenPayback,
  });

  final LedgerDaySection section;
  final Group group;
  final void Function(Expense) onOpenExpense;
  final void Function(Expense) onOpenPayback;

  @override
  Widget build(BuildContext context) {
    // v3: a date group is ONE card holding its rows joined (no intra-group
    // gaps); spacing lives only BETWEEN date groups (the bottom margin below).
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: SectionLabel(
              formatDate(section.day.toIso8601String(), context),
            ),
          ),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            borderRadius: 20,
            child: Column(
              children: [
                for (final expense in section.expenses)
                  _LedgerRow(
                    expense: expense,
                    group: group,
                    onOpenExpense: onOpenExpense,
                    onOpenPayback: onOpenPayback,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dispatches to the right row presentation based on [classifyLedgerRow].
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.expense,
    required this.group,
    required this.onOpenExpense,
    required this.onOpenPayback,
  });

  final Expense expense;
  final Group group;
  final void Function(Expense) onOpenExpense;
  final void Function(Expense) onOpenPayback;

  @override
  Widget build(BuildContext context) {
    switch (classifyLedgerRow(expense)) {
      case LedgerRowType.payback:
        return _PaybackRow(
          expense: expense,
          onTap: () => onOpenPayback(expense),
        );
      case LedgerRowType.itemized:
        return _ItemizedRow(
          expense: expense,
          onTap: () => onOpenExpense(expense),
        );
      case LedgerRowType.quick:
        return LedgerQuickRow(
          expense: expense,
          onTap: () => onOpenExpense(expense),
        );
    }
  }
}

/// Shared "{payer} paid · you lent/owe €X" net summary line.
class ExpenseNetLine extends StatelessWidget {
  const ExpenseNetLine({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserEmail = supabase.auth.currentUser?.email;
    final currentUserPaid = expense.paidBy == currentUserEmail;
    final shareStat = expense.groupMemberShareStatistic;

    // Paid clause without the amount — the row's trailing total already shows it.
    final paidPart = currentUserPaid
        ? l10n.expensePaidByYou
        : l10n.expensePaidByOther(expense.paidByDisplayName ?? "");

    Widget? netWidget;
    if (shareStat.containsKey(currentUserEmail)) {
      final currentUserShares = shareStat[currentUserEmail] ?? 0;
      final String netLabel;
      final MoneySemantic semantic;
      if (currentUserPaid) {
        netLabel = l10n.expenseDisplayAmount(
          'yes',
          l10n.you,
          "lent",
          l10n.toCurrency(
            expense.amount - currentUserShares,
            expense.group.currencyCode,
          ),
        );
        semantic = MoneySemantic.positive;
      } else {
        netLabel = l10n.expenseDisplayAmount(
          'yes',
          l10n.you,
          "borrowed",
          l10n.toCurrency(currentUserShares, expense.group.currencyCode),
        );
        semantic = MoneySemantic.negative;
      }
      netWidget = Text(
        netLabel,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: semantic == MoneySemantic.positive
              ? Theme.of(context).extension<SemanticColors>()!.success
              : Theme.of(context).extension<SemanticColors>()!.danger,
        ),
      );
    } else if (!currentUserPaid) {
      netWidget = Text(
        l10n.expenseNoShares,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    return Row(
      children: [
        Flexible(
          child: Text(
            paidPart,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (netWidget != null) ...[
          Text(
            "  ·  ",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(child: netWidget),
        ],
      ],
    );
  }
}

/// Quick expense: category icon, title, payer/net line, trailing total.
class LedgerQuickRow extends StatelessWidget {
  const LedgerQuickRow({super.key, required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LedgerRowInk(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              expense.category?.getIcon() ?? Icons.receipt_long_outlined,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                ExpenseNetLine(expense: expense),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _LedgerAmount(expense: expense),
        ],
      ),
    );
  }
}

/// The trailing amount of a ledger row: the group-currency ledger value, and —
/// only when the expense was entered in another currency — what was actually
/// typed, underneath it.
///
/// The ledger value stays the headline because it is the number every balance
/// on the screen is computed from. The entered amount is the one the user
/// recognises from their own evening, and without it a converted row is
/// indistinguishable from a native one: on a trip abroad that is every row in
/// the list. It is code-qualified rather than symbolised — see
/// [formatMoney].
class _LedgerAmount extends StatelessWidget {
  const _LedgerAmount({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amount = MoneyText(
      expense.amount,
      currency: expense.group.currency,
      style: textTheme.titleMedium,
    );

    final entered = expense.originalAmount;
    if (entered == null || expense.originalCurrencyCode == null) return amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        amount,
        const SizedBox(height: 2),
        Text(
          formatMoney(
            entered,
            expense.entryCurrency,
            Localizations.localeOf(context),
          ),
          style: textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A tappable, ink-splashing padded row used inside a joined date-group card.
/// Replaces the per-row [SoftCard] so consecutive rows share one card surface
/// with no gaps between them (v3 date-group list).
class LedgerRowInk extends StatelessWidget {
  const LedgerRowInk({
    super.key,
    required this.child,
    required this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Itemized expense: accent left bar, claim pill / claimed state, claimer
/// avatars and unclaimed meta.
class _ItemizedRow extends StatelessWidget {
  const _ItemizedRow({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final currentUserEmail = supabase.auth.currentUser?.email;

    // Claim derivation from the existing share statistic (do not recompute
    // settlement). A member is a "claimer" when they hold a share; the current
    // user has claimed when they appear there.
    final shareStat = expense.groupMemberShareStatistic;
    final claimed = shareStat.values.fold<double>(0, (sum, v) => sum + v);
    final unclaimed = expense.amount - claimed;
    // Both remainders are judged in the expense's OWN currency: a ¥0.3 leftover
    // renders as ¥0, so it must not light up as unclaimed here.
    final currency = expense.group.currency;
    final hasUnclaimed = !isSettled(unclaimed, currency);
    final youClaimed =
        currentUserEmail != null &&
        !isSettled(shareStat[currentUserEmail] ?? 0, currency);

    final currentUserPaid = expense.paidBy == currentUserEmail;
    // Handoff subline: "You paid · itemized" / "Sam paid · itemized".
    final payerLabel = currentUserPaid
        ? l10n.expensePaidByYou
        : l10n.expensePaidByOther(expense.paidByDisplayName ?? "");

    final claimers = _claimerMembers(expense, currentUserEmail);

    // Left accent bar marks a claimable row (handoff: only when unclaimed
    // items remain).
    final showAccentBar = hasUnclaimed;

    return LedgerRowInk(
      onTap: onTap, // → /group/details/claim (Screen 9), via _openExpense.
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: showAccentBar ? colorScheme.primary : Colors.transparent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: category icon · title + payer/itemized subline · amount.
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            expense.category?.getIcon() ??
                                Icons.receipt_long_outlined,
                            size: 22,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                  children: [
                                    TextSpan(text: "$payerLabel · "),
                                    TextSpan(
                                      text: l10n.groupDetailItemizedTag,
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _LedgerAmount(expense: expense),
                      ],
                    ),
                    if (youClaimed) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: semantic.success,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              l10n.groupDetailYouClaimed(
                                l10n.toCurrency(
                                  shareStat[currentUserEmail] ?? 0.0,
                                  expense.group.currencyCode,
                                ),
                              ),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: semantic.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // LEFT: overlapping claimer avatars + "€X unclaimed" meta.
                          if (claimers.isNotEmpty) ...[
                            AvatarStack(
                              members: claimers,
                              radius: 11,
                              ringColor: colorScheme.surfaceContainerLowest,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              hasUnclaimed
                                  ? l10n.groupDetailUnclaimed(
                                      l10n.toCurrency(
                                        unclaimed,
                                        expense.group.currencyCode,
                                      ),
                                    )
                                  : l10n.groupDetailAllClaimed,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: hasUnclaimed
                                        ? semantic.warning
                                        : colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // RIGHT: compact "Tap to claim" icon button.
                          HeaderIconButton(
                            icon: Icons.add,
                            filled: true,
                            tooltip: l10n.groupDetailTapToClaim,
                            onTap: onTap,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AvatarStackMember> _claimerMembers(
    Expense expense,
    String? currentUserEmail,
  ) {
    final seen = <String>{};
    final members = <AvatarStackMember>[];
    for (final entry in expense.expenseEntries.values) {
      for (final share in entry.expenseEntryShares) {
        if (seen.add(share.email)) {
          members.add(
            AvatarStackMember(
              name: share.displayName,
              colorKey: share.email,
              isYou: share.email == currentUserEmail,
            ),
          );
        }
      }
    }
    return members;
  }
}

/// Payback / settlement: green inset "{from} paid {to} €X · PAYMENT".
/// Tappable — opens [PaybackDetailSheet], the surface a payback can be
/// deleted from.
class _PaybackRow extends StatelessWidget {
  const _PaybackRow({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final currentUserEmail = supabase.auth.currentUser?.email;

    // v3 inset payback chip: sits inside the joined date-group card with a
    // small margin, so its green surface floats within the row stack. The
    // chip is its own Material/InkWell so the tap splash lands on the chip
    // itself rather than the SoftCard Material hidden beneath it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Material(
        color: semantic.paybackBackground,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, size: 18, color: semantic.paybackText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paybackSummaryLine(
                          expense,
                          l10n,
                          currencyCode: expense.group.currencyCode,
                          currentUserEmail: currentUserEmail,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: semantic.paybackText,
                        ),
                      ),
                      // payback-on-behalf: no owner concept means the
                      // deterrent is visibility — a payback somebody else
                      // recorded says so, right in the ledger.
                      if (expense.isRecordedOnBehalf)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l10n.paybackRecordedBy(
                              expense.recordedByDisplayName ?? '',
                            ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: semantic.paybackText.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.groupDetailPaymentTag,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: semantic.paybackText,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
