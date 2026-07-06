import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_ledger.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../expenses/data/expense_model.dart';
import '../../expenses/provider/expense_list.dart';

/// Opens an expense the same way the ledger does: expenses with per-unit claim
/// items go to Tap-to-Claim (Screen 9); everything else — quick expenses AND
/// old itemized expenses with manual splits (no claim units) — goes to the read
/// detail (Screen 11), which shows the real per-member breakdown. Routing on
/// claim units (not entry count) keeps old itemized expenses off the claim
/// screen, where they'd read as €0.00 / "no claimable items". Shared so the
/// expense search routes identically to a ledger tap.
void openLedgerExpense(BuildContext context, Group group, Expense expense) {
  GoRouter.of(context).push(
    expense.hasClaimUnits ? "/group/details/claim" : "/group/details/expense-detail",
    extra: {'group': group, 'expense': expense},
  );
}

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
    return ref.read(expenseListProvider(widget.group.id).notifier).reload(widget.group.id);
  }

  void _openExpense(Expense expense) =>
      openLedgerExpense(context, widget.group, expense);

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
        final expenseListState = ref.watch(expenseListProvider(widget.group.id));
        final isLoading = expenseListState.isLoading;
        final expenses = expenseListState.value;
        oldOffset = ref.read(expenseListProvider(widget.group.id).notifier).offset;

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
          return EmptyListWidget(
            icon: Icons.receipt_long_outlined,
            label: AppLocalizations.of(context)!.groupExpenseNoEntries,
            onRefresh: () => updateExpenseList(),
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

                final section = sections[hasAd && index > adPos ? index - 1 : index];
                return _DaySection(
                  section: section,
                  group: widget.group,
                  onOpenExpense: _openExpense,
                );
              },
            ),
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >
                  scrollInfo.metrics.maxScrollExtent - MediaQuery.of(context).size.height) {
                if (oldOffset == ref.read(expenseListProvider(widget.group.id).notifier).offset) {
                  // make sure ListView has newest data after previous loadMore
                  ref.read(expenseListProvider(widget.group.id).notifier).loadMoreEntries(widget.group.id);
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
  });

  final LedgerDaySection section;
  final Group group;
  final void Function(Expense) onOpenExpense;

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
            child: SectionLabel(formatDate(section.day.toIso8601String(), context)),
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
  });

  final Expense expense;
  final Group group;
  final void Function(Expense) onOpenExpense;

  @override
  Widget build(BuildContext context) {
    switch (classifyLedgerRow(expense)) {
      case LedgerRowType.payback:
        return _PaybackRow(expense: expense);
      case LedgerRowType.itemized:
        return _ItemizedRow(expense: expense, onTap: () => onOpenExpense(expense));
      case LedgerRowType.quick:
        return LedgerQuickRow(expense: expense, onTap: () => onOpenExpense(expense));
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
          expense.amount - currentUserShares,
        );
        semantic = MoneySemantic.positive;
      } else {
        netLabel = l10n.expenseDisplayAmount('yes', l10n.you, "borrowed", currentUserShares);
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    return Row(
      children: [
        Flexible(
          child: Text(
            paidPart,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (netWidget != null) ...[
          Text(
            "  ·  ",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
          MoneyText(
            expense.amount,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// A tappable, ink-splashing padded row used inside a joined date-group card.
/// Replaces the per-row [SoftCard] so consecutive rows share one card surface
/// with no gaps between them (v3 date-group list).
class LedgerRowInk extends StatelessWidget {
  const LedgerRowInk({super.key, required this.child, required this.padding, this.onTap});

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
    final hasUnclaimed = unclaimed > 0.005;
    final youClaimed =
        currentUserEmail != null && (shareStat[currentUserEmail] ?? 0) > 0.005;

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
                              Text.rich(
                                TextSpan(
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                        MoneyText(
                          expense.amount,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (youClaimed) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: semantic.success),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              l10n.groupDetailYouClaimed(shareStat[currentUserEmail] ?? 0),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                                  ? l10n.groupDetailUnclaimed(unclaimed)
                                  : l10n.groupDetailAllClaimed,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

  List<AvatarStackMember> _claimerMembers(Expense expense, String? currentUserEmail) {
    final seen = <String>{};
    final members = <AvatarStackMember>[];
    for (final entry in expense.expenseEntries.values) {
      for (final share in entry.expenseEntryShares) {
        if (seen.add(share.email)) {
          members.add(AvatarStackMember(
            name: share.displayName,
            colorKey: share.email,
            isYou: share.email == currentUserEmail,
          ));
        }
      }
    }
    return members;
  }
}

/// Payback / settlement: green inset "{from} paid {to} €X · PAYMENT".
class _PaybackRow extends StatelessWidget {
  const _PaybackRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final currentUserEmail = supabase.auth.currentUser?.email;

    final ExpenseEntryShare paidBackEntryShare =
        expense.expenseEntries.entries.first.value.expenseEntryShares.first;

    final paidByYourself = expense.paidBy == currentUserEmail ? 'yes' : '';
    final paidByDisplayName =
        expense.paidBy == currentUserEmail ? l10n.you : (expense.paidByDisplayName ?? "");
    final paidToYourself = paidBackEntryShare.email == currentUserEmail ? 'yes' : '';
    final paidToDisplayName =
        paidBackEntryShare.email == currentUserEmail ? l10n.you : paidBackEntryShare.displayName;

    // v3 inset payback chip: sits inside the joined date-group card with a
    // small margin, so its green surface floats within the row stack.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: semantic.paybackBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, size: 18, color: semantic.paybackText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.groupDisplayPaidBack(
                paidByYourself,
                paidByDisplayName,
                paidToYourself,
                paidToDisplayName,
                expense.amount,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: semantic.paybackText),
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
    );
  }
}
