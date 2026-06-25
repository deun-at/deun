import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/success_badge.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/helper/helper.dart';
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

  ClaimNotifier get _notifier =>
      ref.read(claimProvider(widget.group.id, widget.expense.id).notifier);

  /// Toggles the persona's claim on [row]: claim when open or not yet claimed
  /// by the persona, otherwise unclaim. Each tap persists immediately via the
  /// notifier (optimistic refetch keeps the chips live).
  Future<void> _toggleClaim(ClaimUnitRow row) async {
    final persona = _persona;
    if (persona.isEmpty) return;
    final state = ClaimChipState.forPersona(row, persona);
    try {
      if (state.claimedByYou) {
        await _notifier.unclaimUnit(row.entryId, persona);
      } else {
        await _notifier.claimUnit(row.entryId, persona);
      }
    } catch (_) {
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.claimLoadError);
      }
    }
  }

  /// Opens the inline member picker to split a single unit, then applies the
  /// chosen claimer set via the notifier.
  Future<void> _openSplitPicker(ClaimUnitRow row) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: kSheetAnimationStyle,
      barrierColor: kSheetBarrierColor,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SplitPickerSheet(
        unitCost: row.unit.unitCost,
        members: widget.group.groupMembers,
        currentUserEmail: _currentUserEmail,
        initialClaimers: row.unit.claimers.toSet(),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _notifier.splitUnit(row.entryId, result);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.claimLoadError);
      }
    }
  }

  /// v0 Nudge: claims are already persisted per-tap, so there is no dedicated
  /// reminder backend on this branch. Surfaces a localized confirmation
  /// snackbar (the reminder path is a follow-up).
  void _nudge() {
    showSnackBar(context, AppLocalizations.of(context)!.claimNudgeSent);
  }

  /// v0 Confirm: per-tap claims are already saved, so Confirm is an
  /// acknowledgement that shows the success sheet, then pops the screen.
  Future<void> _confirm(double yourTotal) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: kSheetAnimationStyle,
      barrierColor: kSheetBarrierColor,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ClaimSuccessSheet(amount: yourTotal),
    );
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
          body: claimState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorState(message: l10n.claimLoadError),
            data: (expense) {
              final rows = notifier.unitRows;
              final summary = buildClaimSummary(
                units: rows.map((r) => r.unit).toList(),
                personaEmail: _persona,
              );
              final yourTotal = confirmTotalForPersona(rows, _persona);

              return Column(
                children: [
                  DeunHeader(
                    title: expense.name,
                    subtitle: l10n.claimPresenceLive,
                    subtitleLeading: const _PresencePulse(),
                    leadingIcon: Icons.arrow_back,
                    trailing: IconButton(
                      tooltip: l10n.claimEditItems,
                      onPressed: _openEditor,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
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
                        if (!summary.isFullyClaimed &&
                            summary.unclaimed > 0.005) ...[
                          const SizedBox(height: 16),
                          _UnclaimedCallout(
                            unclaimed: summary.unclaimed,
                            onNudge: _nudge,
                          ),
                        ],
                        const SizedBox(height: 24),
                        SectionLabel(l10n.claimItemsLabel),
                        const SizedBox(height: 8),
                        _ItemList(
                          rows: rows,
                          persona: _persona,
                          currentUserEmail: _currentUserEmail,
                          displayName: (e) => _displayName(context, e),
                          onToggle: _toggleClaim,
                          onSplit: _openSplitPicker,
                        ),
                      ],
                    ),
                  ),
                  if (rows.isNotEmpty)
                    _ConfirmBar(
                      yourTotal: yourTotal,
                      onConfirm: () => _confirm(yourTotal),
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
    duration: Motion.presencePulse,
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
            animate: true,
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

/// Interactive list of claimable items. Each unit renders a chip:
/// • open units show a dashed "take one" affordance;
/// • claimed units show their claimer avatar(s) + the per-claimer cost when
///   split, tinted with the "you" accent when the persona is a claimer.
/// Tapping a chip toggles the persona's claim; "Split one" opens the member
/// picker.
class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.rows,
    required this.persona,
    required this.currentUserEmail,
    required this.displayName,
    required this.onToggle,
    required this.onSplit,
  });

  final List<ClaimUnitRow> rows;
  final String persona;
  final String? currentUserEmail;
  final String Function(String email) displayName;
  final ValueChanged<ClaimUnitRow> onToggle;
  final ValueChanged<ClaimUnitRow> onSplit;

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
            persona: persona,
            currentUserEmail: currentUserEmail,
            displayName: displayName,
            onToggle: () => onToggle(row),
            onSplit: () => onSplit(row),
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
    required this.persona,
    required this.currentUserEmail,
    required this.displayName,
    required this.onToggle,
    required this.onSplit,
  });

  final ClaimUnitRow row;
  final String persona;
  final String? currentUserEmail;
  final String Function(String email) displayName;
  final VoidCallback onToggle;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chipState = ClaimChipState.forPersona(row, persona);

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
          _ClaimChip(
            row: row,
            chipState: chipState,
            currentUserEmail: currentUserEmail,
            displayName: displayName,
            onToggle: onToggle,
            onSplit: onSplit,
          ),
        ],
      ),
    );
  }
}

/// The per-unit chip. Open units are a dashed "take one" pill; claimed units
/// are a tinted pill with claimer avatar(s), the "split · €X" label when shared,
/// and a "Split one" affordance to open the picker.
class _ClaimChip extends StatelessWidget {
  const _ClaimChip({
    required this.row,
    required this.chipState,
    required this.currentUserEmail,
    required this.displayName,
    required this.onToggle,
    required this.onSplit,
  });

  final ClaimUnitRow row;
  final ClaimChipState chipState;
  final String? currentUserEmail;
  final String Function(String email) displayName;
  final VoidCallback onToggle;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _pill(context)),
        const SizedBox(width: 4),
        IconButton(
          tooltip: l10n.claimSplitOne,
          visualDensity: VisualDensity.compact,
          onPressed: onSplit,
          icon: Icon(Icons.call_split, size: 18, color: colorScheme.primary),
        ),
      ],
    );
  }

  /// The tappable pill: a dashed "take one" for an open unit, otherwise a
  /// tinted avatar pill (with the "split · €X" label when shared).
  Widget _pill(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    if (chipState.open) {
      return _DashedChip(
        color: semantic.warning,
        onTap: onToggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: semantic.warning),
            const SizedBox(width: 4),
            Text(
              l10n.claimTakeOne,
              style: textTheme.labelMedium?.copyWith(
                color: semantic.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final claimers = row.unit.claimers;
    final stackMembers = [
      for (final email in claimers)
        AvatarStackMember(
          name: displayName(email),
          colorKey: email,
          isYou: email == currentUserEmail,
        ),
    ];
    // "You" accent when the persona is one of the claimers.
    final Color bg = chipState.claimedByYou
        ? colorScheme.primary.withValues(alpha: 0.14)
        : colorScheme.surfaceContainerHighest;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarStack(members: stackMembers, radius: 12, ringColor: bg),
            if (chipState.splitCount > 1) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.claimSplitLabel(l10n.toCurrency(chipState.perUnitCost)),
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A dashed-border stadium chip used for the open "take one" affordance.
class _DashedChip extends StatelessWidget {
  const _DashedChip({
    required this.child,
    required this.color,
    required this.onTap,
  });

  final Widget child;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: CustomPaint(
        painter: _DashedStadiumPainter(color: color),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

/// Paints a dashed stadium (pill) border in [color].
class _DashedStadiumPainter extends CustomPainter {
  const _DashedStadiumPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Warning-tinted callout shown above the items while some units are still
/// unclaimed, with a Nudge action.
class _UnclaimedCallout extends StatelessWidget {
  const _UnclaimedCallout({required this.unclaimed, required this.onNudge});

  final double unclaimed;
  final VoidCallback onNudge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: semantic.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: semantic.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.claimUnclaimedCallout(l10n.toCurrency(unclaimed)),
              style: textTheme.bodyMedium?.copyWith(
                color: semantic.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onNudge,
            style: TextButton.styleFrom(foregroundColor: semantic.warning),
            child: Text(l10n.claimNudge),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar with the "Confirm — I had €X" CTA.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.yourTotal, required this.onConfirm});

  final double yourTotal;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: PrimaryButton(
            onPressed: onConfirm,
            label: l10n.claimConfirm(l10n.toCurrency(yourTotal)),
          ),
        ),
      ),
    );
  }
}

/// Inline member picker for "Split one": choose who shares a single unit, with
/// the live per-person cost (unit / selected). Applies via [splitUnit].
class _SplitPickerSheet extends StatefulWidget {
  const _SplitPickerSheet({
    required this.unitCost,
    required this.members,
    required this.currentUserEmail,
    required this.initialClaimers,
  });

  final double unitCost;
  final List<GroupMember> members;
  final String? currentUserEmail;
  final Set<String> initialClaimers;

  @override
  State<_SplitPickerSheet> createState() => _SplitPickerSheetState();
}

class _SplitPickerSheetState extends State<_SplitPickerSheet> {
  late final Set<String> _selected = {...widget.initialClaimers};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final perPerson =
        _selected.isEmpty ? 0.0 : widget.unitCost / _selected.length;

    return SheetScaffold(
      title: l10n.claimSplitSheetTitle,
      footer: PrimaryButton(
        onPressed: () => Navigator.of(context).pop(_selected.toList()),
        label: l10n.claimSplitApply,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.claimSplitPerPerson(l10n.toCurrency(perPerson)),
            style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          for (final m in widget.members)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(m.email),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(m.email);
                } else {
                  _selected.remove(m.email);
                }
              }),
              secondary: MemberAvatar(
                name: m.displayName,
                colorKey: m.email,
                radius: 16,
                isYou: m.email == widget.currentUserEmail,
              ),
              title: Text(
                m.email == widget.currentUserEmail ? l10n.you : m.displayName,
              ),
            ),
        ],
      ),
    );
  }
}

/// Success sheet shown after Confirm, echoing the persona's confirmed share.
class _ClaimSuccessSheet extends StatelessWidget {
  const _ClaimSuccessSheet({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return SheetScaffold(
      footer: PrimaryButton(
        onPressed: () => Navigator.of(context).pop(),
        label: l10n.claimConfirmedDone,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SuccessBadge(icon: Icons.check_circle, size: 56, color: semantic.success),
          const SizedBox(height: 16),
          Text(
            l10n.claimConfirmedTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.claimConfirmedBody(l10n.toCurrency(amount)),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
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
