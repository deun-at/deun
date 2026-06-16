import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_ledger.dart';
import 'package:deun/widgets/empty_list_widget.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
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

  void _openExpense(Expense expense) {
    GoRouter.of(context).push(
      "/group/details/expense",
      extra: {'group': widget.group, 'expense': expense},
    );
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
          return const ShimmerCardList(height: 80, listEntryLength: 15);
        }

        if (expenses == null || expenses.isEmpty) {
          return EmptyListWidget(
            icon: Icons.receipt_long_outlined,
            label: AppLocalizations.of(context)!.groupExpenseNoEntries,
            onRefresh: () => updateExpenseList(),
          );
        }

        final sections = groupExpensesByDay(expenses);

        return RefreshIndicator(
          onRefresh: () => updateExpenseList(),
          child: NotificationListener<ScrollNotification>(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              itemCount: sections.length + (widget.adBlock != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= sections.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: widget.adBlock,
                  );
                }

                final section = sections[index];
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: SectionLabel(formatDate(section.day.toIso8601String(), context)),
        ),
        for (final expense in section.expenses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LedgerRow(
              expense: expense,
              group: group,
              onOpenExpense: onOpenExpense,
            ),
          ),
      ],
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
        return _QuickRow(expense: expense, onTap: () => onOpenExpense(expense));
    }
  }
}

/// Shared "{payer} paid · you lent/owe €X" net summary line.
class _ExpenseNetLine extends StatelessWidget {
  const _ExpenseNetLine({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserEmail = supabase.auth.currentUser?.email;
    final currentUserPaid = expense.paidBy == currentUserEmail;
    final shareStat = expense.groupMemberShareStatistic;

    final payerName =
        currentUserPaid ? l10n.you : (expense.paidByDisplayName ?? "");
    final paidPart = l10n.expenseDisplayAmount(
      currentUserPaid ? 'yes' : '',
      payerName,
      "paid",
      expense.amount,
    );

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
class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SoftCard(
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
                _ExpenseNetLine(expense: expense),
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

    final claimers = _claimerMembers(expense, currentUserEmail);

    return SoftCard(
      onTap: onTap, // TODO(E3): route to claim_page once the Tap-to-Claim screen exists.
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: colorScheme.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        MoneyText(
                          expense.amount,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (youClaimed)
                          _ClaimPill(
                            label: l10n.groupDetailYouClaimed(shareStat[currentUserEmail] ?? 0),
                            foreground: semantic.success,
                            background: semantic.success.withValues(alpha: 0.14),
                          )
                        else
                          _ClaimPill(
                            label: l10n.groupDetailTapToClaim,
                            foreground: colorScheme.primary,
                            background: colorScheme.primary.withValues(alpha: 0.14),
                          ),
                        const Spacer(),
                        if (claimers.isNotEmpty)
                          AvatarStack(
                            members: claimers,
                            radius: 11,
                            ringColor: colorScheme.surfaceContainerLowest,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasUnclaimed
                          ? l10n.groupDetailUnclaimed(unclaimed)
                          : l10n.groupDetailAllClaimed,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: hasUnclaimed ? semantic.warning : colorScheme.onSurfaceVariant,
                          ),
                    ),
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

/// A small stadium claim pill ("Tap to claim" / "You claimed €X").
class _ClaimPill extends StatelessWidget {
  const _ClaimPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
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

    return Container(
      width: double.infinity,
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
