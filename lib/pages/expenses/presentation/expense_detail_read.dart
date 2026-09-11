import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_deletion_impact.dart';
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
class ExpenseDetailRead extends ConsumerStatefulWidget {
  const ExpenseDetailRead({
    super.key,
    required this.group,
    required this.expense,
    this.loadGroupPaybacks,
  });

  final Group group;
  final Expense expense;

  /// Test seam for the group's payback probe. Null in production →
  /// [ExpenseRepository.fetchPaybackRows].
  final GroupPaybackLoader? loadGroupPaybacks;

  @override
  ConsumerState<ExpenseDetailRead> createState() => _ExpenseDetailReadState();
}

class _ExpenseDetailReadState extends ConsumerState<ExpenseDetailRead> {
  /// True while the delete guard's payback probe is in flight. A slow/hanging
  /// fetch must not leave the delete action tappable — that would let a repeat
  /// tap start a second probe and stack a second confirmation on top of the
  /// first. The action shows progress and ignores taps for exactly this
  /// window; once the confirmation sheet appears it is itself modal, so no
  /// further guard is needed past this point.
  bool _deleteProbeInFlight = false;

  String? get _currentUserEmail => supabase.auth.currentUser?.email;

  GroupMember? _findMember(String? email) {
    if (email == null) return null;
    try {
      return widget.group.groupMembers.firstWhere((m) => m.email == email);
    } catch (_) {
      return null;
    }
  }

  /// Members in display order: "you" first, then alphabetical — matching the
  /// editor's sort so the breakdown reads consistently.
  List<String> get _orderedMemberEmails {
    final members = [...widget.group.groupMembers]
      ..sort((a, b) {
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
      extra: {'group': widget.group, 'expense': widget.expense},
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (_deleteProbeInFlight) return;

    // Presentation-level guard: name what the delete will reopen BEFORE
    // running it. Warn, then allow — a failed probe degrades to today's plain
    // confirmation rather than blocking a delete.
    setState(() => _deleteProbeInFlight = true);
    final impact = await probeDeletionImpact(
      widget.expense,
      loader: widget.loadGroupPaybacks,
    );
    if (!mounted) return;
    setState(() => _deleteProbeInFlight = false);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirmationSheet(
      context,
      title: impact.confirmTitle(l10n),
      message: impact.confirmMessage(l10n, widget.group.currencyCode),
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ExpenseRepository.delete(widget.expense.id, widget.expense.groupId);
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          body: Column(
            children: [
              DeunHeader(
                title: l10n.expenseDetailTitle,
                trailingActions: [
                  // v3 (expense detail header): delete on the LEFT — danger-red
                  // trash glyph on the neutral warm-tint circle (like F12
                  // logout); edit on the RIGHT — primary indigo pencil on the
                  // same tinted circle.
                  HeaderIconButton(
                    icon: Icons.delete_outline,
                    tooltip: l10n.delete,
                    onTap: () => _confirmDelete(context),
                    loading: _deleteProbeInFlight,
                    iconColor: Theme.of(
                      context,
                    ).extension<SemanticColors>()!.danger,
                  ),
                  HeaderIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: l10n.edit,
                    onTap: () => _openEditor(context),
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    _SummaryCard(
                      expense: widget.expense,
                      payerName: _displayName(
                        context,
                        _findMember(widget.expense.paidBy),
                      ),
                      payerIsYou: widget.expense.paidBy == _currentUserEmail,
                      currentUserEmail: _currentUserEmail,
                    ),
                    // Only real claim expenses get the "Review & claim" banner. Old
                    // itemized expenses (manual splits, no claim units) would land on
                    // an empty claim screen, so they show just the breakdown below.
                    if (widget.expense.hasClaimUnits) ...[
                      const SizedBox(height: 16),
                      _ReviewClaimBanner(
                        onTap: () {
                          // → Tap-to-Claim screen (Screen 9).
                          GoRouter.of(context).push(
                            '/group/details/claim',
                            extra: {
                              'group': widget.group,
                              'expense': widget.expense,
                            },
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SectionLabel(breakdownHeading(widget.expense, l10n)),
                    const SizedBox(height: 8),
                    _MemberBreakdown(
                      expense: widget.expense,
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
                    Text(expense.name, style: textTheme.titleLarge),
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
            currency: expense.group.currency,
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          // Provenance (multi-currency-expense-rate): what the user actually
          // typed, and the frozen rate it was converted at. Read-only and never
          // recomputed — the big figure above stays the ledger value.
          //
          // A labelled block rather than two grey footnotes: this is the most
          // interesting fact about the expense (it happened somewhere else, at
          // a rate a person chose), and it used to be set in the smallest,
          // lightest type on the screen. The rate carries its direction —
          // "0.9432" alone can be read either way round.
          if (expense.originalCurrencyCode != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _ProvenanceRow(
                    label: l10n.expenseProvenanceEntered,
                    value: formatMoneyQualified(
                      expense.originalAmount ?? 0,
                      expense.entryCurrency,
                      Localizations.localeOf(context),
                    ),
                    valueKey: const ValueKey('expense_original_amount'),
                  ),
                  if (expense.conversionRate != null) ...[
                    const SizedBox(height: 8),
                    _ProvenanceRow(
                      label: l10n.expenseProvenanceRate,
                      value: l10n.expenseRateAppliedOn(
                        l10n.expenseRateDirection(
                          expense.entryCurrency.code,
                          formatRate(expense.conversionRate!),
                          expense.group.currency.code,
                        ),
                        toHumanDateString(expense.rateDate),
                      ),
                      valueKey: const ValueKey('expense_rate_applied'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _PaidNetRow(
            expense: expense,
            payerName: payerName,
            payerIsYou: payerIsYou,
            currentUserEmail: currentUserEmail,
          ),
          if (expense.isRecordedOnBehalf) ...[
            const SizedBox(height: 10),
            Text(
              l10n.paybackRecordedBy(expense.recordedByDisplayName ?? ''),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
    } else if (isSettled(net, expense.group.currency)) {
      netLabel = l10n.expenseNetSettled;
      netColor = colorScheme.onSurfaceVariant;
    } else if (net > 0) {
      netLabel = l10n.expenseYouLentAmount(
        l10n.toCurrency(net.abs(), expense.group.currencyCode),
      );
      netColor = Theme.of(context).extension<SemanticColors>()!.success;
    } else {
      netLabel = l10n.expenseYouOweAmount(
        l10n.toCurrency(net.abs(), expense.group.currencyCode),
      );
      netColor = Theme.of(context).extension<SemanticColors>()!.danger;
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
        // The payer text takes the flexible slot; the net label is pinned to the
        // far right. A Flexible + Spacer pair split the free space between them,
        // which parked leftover space to the RIGHT of the net label so it was not
        // flush-right. A single Expanded consumes the slack, so the net label
        // ("You lent … / You owe …") sits truly right-aligned.
        Expanded(
          child: Text(
            payerIsYou
                ? l10n.expensePaidByYou
                : l10n.expensePaidByOther(payerName),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          netLabel,
          style: textTheme.titleSmall?.copyWith(
            color: netColor,
            fontWeight: FontWeight.w700,
          ),
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
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.expenseReviewClaimSubtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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

/// Per-member breakdown (F122): a SINGLE [SoftCard] holding the member rows
/// joined with no intra-card gaps — the same non-spaced-list pattern as the
/// group-detail date-group card (F138). Bound to the pre-computed
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
    if (rows.isEmpty) return const SizedBox.shrink();

    // The payer's display name, used verbatim in debtor rows ("owes <payer>").
    final payerName = displayName(memberFor(expense.paidBy));
    final payerIsYou = expense.paidBy == currentUserEmail;

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      borderRadius: 20,
      child: Column(
        children: [
          for (final entry in rows)
            _MemberRow(
              entry: entry,
              member: memberFor(entry.email),
              displayName: displayName,
              isYou: entry.email == currentUserEmail,
              payerName: payerName,
              payerIsYou: payerIsYou,
              total: expense.amount,
              currency: expense.group.currency,
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.entry,
    required this.member,
    required this.displayName,
    required this.isYou,
    required this.payerName,
    required this.payerIsYou,
    required this.total,
    required this.currency,
  });

  final MemberBreakdownEntry entry;
  final GroupMember? member;
  final String Function(GroupMember?) displayName;
  final bool isYou;
  final String payerName;
  final bool payerIsYou;
  final double total;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = displayName(member);

    // F123 sub-label wording, mapped to role exactly as the v3 prototype:
    //  - payer  → "paid €X.XX" (success/green)
    //  - you    → "your share"
    //  - debtor → "owes <payer>" (or "owes you" when you paid)
    final String subLabel;
    final Color subLabelColor;
    if (entry.isPayer) {
      subLabel = l10n.expenseMemberPaidAmount(
        l10n.toCurrency(total, currency.code),
      );
      subLabelColor = Theme.of(context).extension<SemanticColors>()!.success;
    } else if (isYou) {
      subLabel = l10n.expenseMemberYourShare;
      subLabelColor = colorScheme.onSurfaceVariant;
    } else {
      subLabel = l10n.expenseMemberOwesName(
        payerIsYou ? l10n.youObjectPronoun : payerName,
      );
      subLabelColor = colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
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
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subLabel,
                  style: textTheme.bodySmall?.copyWith(color: subLabelColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // F124: trailing amount is the member's SHARE — plain onSurface,
          // single line, right-aligned. No semantic color, no two-line label.
          MoneyText(
            entry.share,
            currency: currency,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One label/value line of the read view's conversion provenance block.
///
/// The label is muted and the value is not: the value is the fact, the label
/// only says which fact it is.
class _ProvenanceRow extends StatelessWidget {
  const _ProvenanceRow({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
