import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen 9 — Tap to Claim (layout & summary).
///
/// Header (merchant + live-presence pulse + edit-items), a "Preview as" persona
/// switcher, a dark summary card (your share / claimed-total progress /
/// unclaimed / per-member totals) and a read-only list of claimable items.
///
/// Scope (E3-T2): chrome + summary + entry routing only. The per-unit
/// claim/unclaim/split chips and the sticky Confirm CTA are E3-T3 — the item
/// area renders read-only here (see [_ItemList]).
class ClaimPage extends ConsumerStatefulWidget {
  const ClaimPage({super.key, required this.group, required this.expense});

  final Group group;
  final Expense expense;

  @override
  ConsumerState<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends ConsumerState<ClaimPage> {
  /// The persona whose perspective the summary reflects. v0: defaults to the
  /// signed-in user; the switcher lets you preview the claim view as any other
  /// member (drives `claim_math` "your share" for the selected persona only —
  /// it does not change who actually claims anything, that stays E3-T3).
  String? _personaEmail;

  String? get _currentUserEmail => supabase.auth.currentUser?.email;

  String get _persona => _personaEmail ?? _currentUserEmail ?? '';

  void _openEditor() {
    GoRouter.of(context).push(
      '/group/details/expense',
      extra: {'group': widget.group, 'expense': widget.expense},
    );
  }

  GroupMember? _memberFor(String email) {
    try {
      return widget.group.groupMembers.firstWhere((m) => m.email == email);
    } catch (_) {
      return null;
    }
  }

  String _displayName(BuildContext context, String email) {
    if (email == _currentUserEmail) return AppLocalizations.of(context)!.you;
    return _memberFor(email)?.displayName ?? email;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final claimState = ref.watch(
      claimProvider(widget.group.id, widget.expense.id),
    );
    final notifier =
        ref.read(claimProvider(widget.group.id, widget.expense.id).notifier);

    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.claimTitle),
            actions: [
              IconButton(
                tooltip: l10n.claimEditItems,
                onPressed: _openEditor,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: claimState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorState(message: l10n.claimLoadError),
            data: (expense) {
              final rows = notifier.unitRows;
              final summary = buildClaimSummary(
                units: rows.map((r) => r.unit).toList(),
                personaEmail: _persona,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _Header(
                    merchant: expense.name,
                    onEdit: _openEditor,
                  ),
                  const SizedBox(height: 16),
                  _PersonaSwitcher(
                    members: widget.group.groupMembers,
                    selected: _persona,
                    currentUserEmail: _currentUserEmail,
                    onChanged: (email) =>
                        setState(() => _personaEmail = email),
                  ),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    summary: summary,
                    displayName: (e) => _displayName(context, e),
                    currentUserEmail: _currentUserEmail,
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l10n.claimItemsLabel),
                  const SizedBox(height: 8),
                  _ItemList(
                    rows: rows,
                    currentUserEmail: _currentUserEmail,
                    displayName: (e) => _displayName(context, e),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Header: merchant title with a pulsing live-presence dot, plus an edit-items
/// affordance. The pulse honors the platform "reduce motion" setting.
class _Header extends StatelessWidget {
  const _Header({required this.merchant, required this.onEdit});

  final String merchant;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merchant,
                style: textTheme.headlineSmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const _PresencePulse(),
                  const SizedBox(width: 8),
                  Text(
                    l10n.claimPresenceLive,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.tune, size: 18),
          label: Text(l10n.claimEditItems),
        ),
      ],
    );
  }
}

/// A small dot that pulses on a ~1.6s loop (Motion spec). Collapses to a static
/// dot when the user has requested reduced motion.
class _PresencePulse extends StatefulWidget {
  const _PresencePulse();

  @override
  State<_PresencePulse> createState() => _PresencePulseState();
}

class _PresencePulseState extends State<_PresencePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final color = semantic.success;

    // Start/stop the loop in build so it reacts to a live reduce-motion change.
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    const double dot = 8;
    if (reduceMotion) {
      return Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value; // 0..1
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding, fading halo.
              Container(
                width: dot + (10 * t),
                height: dot + (10 * t),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: (1 - t) * 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "Preview as" persona switcher. v0: a segmented control over the group's
/// members (you first) that re-derives the summary's "your share" for the
/// chosen perspective. Does not mutate claims.
class _PersonaSwitcher extends StatelessWidget {
  const _PersonaSwitcher({
    required this.members,
    required this.selected,
    required this.currentUserEmail,
    required this.onChanged,
  });

  final List<GroupMember> members;
  final String selected;
  final String? currentUserEmail;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final ordered = [...members]..sort((a, b) {
        if (a.email == currentUserEmail) return -1;
        if (b.email == currentUserEmail) return 1;
        return a.displayName.compareTo(b.displayName);
      });

    final segments = [
      for (final m in ordered)
        AppSegment<String>(
          value: m.email,
          label: m.email == currentUserEmail ? l10n.you : m.displayName,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l10n.claimPreviewAs),
        const SizedBox(height: 8),
        if (segments.length <= 1)
          // Solo group: nothing to preview as, render a static label.
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              segments.isEmpty ? '' : segments.first.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          )
        else
          AppSegmentedControl<String>(
            value: selected,
            segments: segments,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

/// The dark summary card (hero style): your share, claimed/total progress,
/// unclaimed remainder and per-member totals. Mirrors the group balance hero's
/// tinted-surface treatment so it reads as the screen's focal card.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.displayName,
    required this.currentUserEmail,
  });

  final ClaimSummary summary;
  final String Function(String email) displayName;
  final String? currentUserEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Same hero treatment as the group balance hero: tinted focal surface.
    final Color heroSurface =
        isDark ? colorScheme.primaryContainer : colorScheme.primary;
    final Color onHero =
        isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.claimYourShare,
            style: textTheme.labelLarge?.copyWith(color: onHeroMuted),
          ),
          const SizedBox(height: 6),
          MoneyText(
            summary.yourShare,
            style: textTheme.displaySmall?.copyWith(color: onHero),
          ),
          const SizedBox(height: 18),
          ProgressBar(
            value: summary.progress,
            fillColor: onHero,
            trackColor: onHero.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l10n.claimProgressLabel(
                  l10n.toCurrency(summary.claimed),
                  l10n.toCurrency(summary.total),
                ),
                style: textTheme.bodySmall?.copyWith(color: onHeroMuted),
              ),
              const Spacer(),
              Text(
                summary.isFullyClaimed
                    ? l10n.claimAllClaimed
                    : '${l10n.claimUnclaimedLabel}: ${l10n.toCurrency(summary.unclaimed)}',
                style: textTheme.bodySmall?.copyWith(
                  color: onHeroMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (summary.memberTotals.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: onHero.withValues(alpha: 0.18)),
            const SizedBox(height: 14),
            Text(
              l10n.claimPerMemberLabel,
              style: textTheme.labelMedium?.copyWith(color: onHeroMuted),
            ),
            const SizedBox(height: 10),
            for (final m in summary.memberTotals) ...[
              _MemberTotalRow(
                name: displayName(m.email),
                colorKey: m.email,
                amount: m.amount,
                isYou: m.email == currentUserEmail,
                onHero: onHero,
              ),
              if (m != summary.memberTotals.last) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _MemberTotalRow extends StatelessWidget {
  const _MemberTotalRow({
    required this.name,
    required this.colorKey,
    required this.amount,
    required this.isYou,
    required this.onHero,
  });

  final String name;
  final String colorKey;
  final double amount;
  final bool isYou;
  final Color onHero;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        MemberAvatar(name: name, colorKey: colorKey, radius: 14, isYou: isYou),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: textTheme.bodyMedium?.copyWith(color: onHero),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        MoneyText(
          amount,
          style: textTheme.titleSmall
              ?.copyWith(color: onHero, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Read-only list of claimable items. Each row shows the item name, unit cost
/// and current claimers (avatars or an "unclaimed" chip).
///
// TODO(E3-T3): interactive chips — replace the read-only claimer display with
// per-unit claim / unclaim / "split one" controls + the sticky Confirm CTA.
class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.rows,
    required this.currentUserEmail,
    required this.displayName,
  });

  final List<ClaimUnitRow> rows;
  final String? currentUserEmail;
  final String Function(String email) displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (rows.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          l10n.claimNoItems,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in rows) ...[
          _ItemRow(
            row: row,
            currentUserEmail: currentUserEmail,
            displayName: displayName,
          ),
          if (row != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.row,
    required this.currentUserEmail,
    required this.displayName,
  });

  final ClaimUnitRow row;
  final String? currentUserEmail;
  final String Function(String email) displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    final claimers = row.unit.claimers;
    final stackMembers = [
      for (final email in claimers)
        AvatarStackMember(
          name: displayName(email),
          colorKey: email,
          isYou: email == currentUserEmail,
        ),
    ];

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name ?? '',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                MoneyText(
                  row.unit.unitCost,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // TODO(E3-T3): interactive chips go here (take one / split / claimed).
          if (row.unit.isClaimed)
            AvatarStack(members: stackMembers, radius: 14)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: ShapeDecoration(
                color: semantic.warning.withValues(alpha: 0.16),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l10n.claimItemUnclaimed,
                style: textTheme.labelMedium?.copyWith(
                  color: semantic.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
