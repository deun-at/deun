import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_detail_view_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/delete_confirm_sheet.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen 11 — Expense detail (read view).
///
/// A read-only restyle of an existing [Expense]: summary card (category icon,
/// title, "category · date" subtitle, total, payer, your-net), an optional
/// "Review & claim" banner for itemized expenses (→ E3), and a per-member
/// breakdown bound to [Expense.groupMemberShareStatistic]. Hosts Edit (→
/// existing editor) and Delete (→ existing repository) actions.
///
/// This is intentionally a SEPARATE widget from the editor
/// (`expense_detail.dart`): tapping a quick expense in the ledger opens this
/// read view, and Edit pushes the editor unchanged.
class ExpenseDetailRead extends ConsumerWidget {
  const ExpenseDetailRead({
    super.key,
    required this.group,
    required this.expense,
  });

  final Group group;
  final Expense expense;

  String? get _currentUserEmail => supabase.auth.currentUser?.email;

  GroupMember? _findMember(String? email) {
    if (email == null) return null;
    try {
      return group.groupMembers.firstWhere((m) => m.email == email);
    } catch (_) {
      return null;
    }
  }

  /// Members in display order: "you" first, then alphabetical — matching the
  /// editor's sort so the breakdown reads consistently.
  List<String> get _orderedMemberEmails {
    final members = [...group.groupMembers]..sort((a, b) {
        if (a.email == _currentUserEmail) return -1;
        if (b.email == _currentUserEmail) return 1;
        return a.fullUsername.compareTo(b.fullUsername);
      });
    return members.map((m) => m.email).toList();
  }

  String _displayName(BuildContext context, GroupMember? member) {
    if (member == null) return '';
    return member.email == _currentUserEmail
        ? AppLocalizations.of(context)!.you
        : member.displayName;
  }

  void _openEditor(BuildContext context) {
    GoRouter.of(context).push(
      '/group/details/expense',
      extra: {'group': group, 'expense': expense},
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirmationSheet(
      context,
      title: l10n.expenseDeleteItemTitle,
      message: l10n.expenseDeleteItemMessage,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ExpenseRepository.delete(expense.id, expense.groupId);
      if (context.mounted) {
        showSnackBar(context, l10n.expenseDeleteSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, l10n.expenseDeleteError);
      }
    } finally {
      // Pop this read screen — the expense is gone.
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return ThemeBuilder(
      colorValue: group.colorValue,
      builder: (context) {
        return Scaffold(
          body: Column(
            children: [
              DeunHeader(
                title: l10n.expenseDetailTitle,
                trailingActions: [
                  IconButton(
                    tooltip: l10n.edit,
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.edit_outlined),
                    iconSize: 22,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    tooltip: l10n.delete,
                    onPressed: () => _confirmDelete(context),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    iconSize: 22,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _SummaryCard(
                expense: expense,
                payerName: _displayName(context, _findMember(expense.paidBy)),
                payerIsYou: expense.paidBy == _currentUserEmail,
                currentUserEmail: _currentUserEmail,
              ),
              if (isItemizedExpense(expense)) ...[
                const SizedBox(height: 16),
                _ReviewClaimBanner(
                  onTap: () {
                    // → Tap-to-Claim screen (Screen 9).
                    GoRouter.of(context).push(
                      '/group/details/claim',
                      extra: {'group': group, 'expense': expense},
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              SectionLabel(breakdownHeading(expense, l10n)),
              const SizedBox(height: 8),
              _MemberBreakdown(
                expense: expense,
                memberEmails: _orderedMemberEmails,
                memberFor: _findMember,
                displayName: (m) => _displayName(context, m),
                currentUserEmail: _currentUserEmail,
              ),
            ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Summary card: tinted category icon, title, "category · date" subtitle,
/// total, and a single combined "{avatar} {payer} paid … {your net}" line
/// (design_11).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.expense,
    required this.payerName,
    required this.payerIsYou,
    required this.currentUserEmail,
  });

  final Expense expense;
  final String payerName;
  final bool payerIsYou;
  final String? currentUserEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final category = expense.category;
    final tint = category?.getColor(context) ?? colorScheme.primary;

    final subtitleParts = <String>[
      if (category != null) category.getDisplayName(l10n),
      formatDate(expense.expenseDate, context),
    ];

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category?.getIcon() ?? Icons.receipt_long_outlined,
                  color: tint,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.name,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join('  ·  '),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          MoneyText(
            expense.amount,
            style: textTheme.displaySmall?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 14),
          _PaidNetRow(
            expense: expense,
            payerName: payerName,
            payerIsYou: payerIsYou,
            currentUserEmail: currentUserEmail,
          ),
        ],
      ),
    );
  }
}

/// Single combined line (design_11): the payer's colored avatar + "{payer} paid"
/// on the left, the current user's net phrase ("You lent €X" / "You owe €X" /
/// "Settled") on the right. The net is derived from the existing share
/// statistic — not recomputed.
class _PaidNetRow extends StatelessWidget {
  const _PaidNetRow({
    required this.expense,
    required this.payerName,
    required this.payerIsYou,
    required this.currentUserEmail,
  });

  final Expense expense;
  final String payerName;
  final bool payerIsYou;
  final String? currentUserEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final breakdown = buildMemberBreakdown(
      expense: expense,
      memberEmails: currentUserEmail == null ? const [] : [currentUserEmail!],
    );
    final net = breakdown.isEmpty ? 0.0 : breakdown.first.net;
    final isInvolved = breakdown.isNotEmpty;

    final String netLabel;
    final Color netColor;
    if (!isInvolved) {
      netLabel = l10n.expenseNoShares;
      netColor = colorScheme.onSurfaceVariant;
    } else if (net > 0.005) {
      netLabel = l10n.expenseYouLentAmount(l10n.toCurrency(net.abs()));
      netColor = Theme.of(context).extension<SemanticColors>()!.success;
    } else if (net < -0.005) {
      netLabel = l10n.expenseYouOweAmount(l10n.toCurrency(net.abs()));
      netColor = Theme.of(context).extension<SemanticColors>()!.danger;
    } else {
      netLabel = l10n.expenseNetSettled;
      netColor = colorScheme.onSurfaceVariant;
    }

    return Row(
      children: [
        MemberAvatar(
          name: payerName,
          colorKey: expense.paidBy ?? payerName,
          radius: 12,
          isYou: payerIsYou,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            payerIsYou
                ? l10n.expensePaidByYou
                : l10n.expensePaidByOther(payerName),
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Text(
          netLabel,
          style: textTheme.titleSmall
              ?.copyWith(color: netColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Tinted "Review & claim" banner for itemized expenses. Routing to the claim
/// screen is stubbed until E3 (see [onTap]); the styling is final.
class _ReviewClaimBanner extends StatelessWidget {
  const _ReviewClaimBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.expenseReviewClaimTitle,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.expenseReviewClaimSubtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right, color: colorScheme.primary),
        ],
      ),
    );
  }
}

/// Per-member breakdown: one [SoftCard] row per involved member with avatar,
/// name, their share and their net (lent/owes). Bound to the pre-computed
/// [Expense.groupMemberShareStatistic] via [buildMemberBreakdown].
class _MemberBreakdown extends StatelessWidget {
  const _MemberBreakdown({
    required this.expense,
    required this.memberEmails,
    required this.memberFor,
    required this.displayName,
    required this.currentUserEmail,
  });

  final Expense expense;
  final List<String> memberEmails;
  final GroupMember? Function(String?) memberFor;
  final String Function(GroupMember?) displayName;
  final String? currentUserEmail;

  @override
  Widget build(BuildContext context) {
    final rows = buildMemberBreakdown(
      expense: expense,
      memberEmails: memberEmails,
    );

    return Column(
      children: [
        for (final entry in rows) ...[
          _MemberRow(
            entry: entry,
            member: memberFor(entry.email),
            displayName: displayName,
            isYou: entry.email == currentUserEmail,
          ),
          if (entry != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.entry,
    required this.member,
    required this.displayName,
    required this.isYou,
  });

  final MemberBreakdownEntry entry;
  final GroupMember? member;
  final String Function(GroupMember?) displayName;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = displayName(member);

    final bool lent = entry.net > 0.005;
    final bool owes = entry.net < -0.005;
    final MoneySemantic semantic = lent
        ? MoneySemantic.positive
        : owes
            ? MoneySemantic.negative
            : MoneySemantic.neutral;
    final String netLabel = lent
        ? l10n.expenseMemberLent
        : owes
            ? l10n.expenseMemberOwes
            : l10n.expenseNetSettled;

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          MemberAvatar(
            name: name,
            colorKey: entry.email,
            radius: 18,
            isYou: isYou,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.isPayer)
                  Text(
                    l10n.expensePaidBy,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                netLabel,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              MoneyText(
                entry.net.abs(),
                semantic: semantic,
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
