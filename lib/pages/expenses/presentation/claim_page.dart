import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen 9 — Tap to Claim.
///
/// Header (merchant + live-presence pulse + edit-items), a "Preview as" persona
/// switcher, a dark summary card (your share / claimed-total progress /
/// unclaimed / per-member totals) and the per-unit item cards (F131): one card
/// per item group with a slot chip per unit — tap a free slot to take it solo,
/// tap a claimed slot or "Split one" for the solo/split modal (see [_ItemCard]).
/// Signature of the push sender used by the Nudge action. Defaults to the real
/// [sendNotification] helper; tests inject a spy so they never hit the live
/// `push` Edge Function.
typedef ClaimNotificationSender = Future<void> Function(
  String type,
  String objectId,
  Set<String> notificationReceiver,
  String title,
  String body,
);

class ClaimPage extends ConsumerStatefulWidget {
  const ClaimPage({
    super.key,
    required this.group,
    required this.expense,
    this.sendNotificationOverride,
  });

  final Group group;
  final Expense expense;

  /// Test seam for the Nudge push. Null in production → [sendNotification].
  final ClaimNotificationSender? sendNotificationOverride;

  @override
  ConsumerState<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends ConsumerState<ClaimPage> {
  /// The persona whose perspective the summary reflects. v0: defaults to the
  /// signed-in user; the switcher lets you preview the claim view as any other
  /// member (drives `claim_math` "your share" for the selected persona only —
  /// it does not change who actually claims anything, that stays E3-T3).
  String? _personaEmail;

  /// The entry id of the unit whose inline split editor is currently expanded,
  /// or null when every item card is collapsed. Only one editor is open at a
  /// time (F163: the modal bottom sheet is replaced by an in-card editor).
  String? _expandedUnit;

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

  /// The expense payer's display name for the unclaimed callout (F130).
  String _payerName(BuildContext context, Expense expense) {
    final email = expense.paidBy;
    if (email != null && email.isNotEmpty) return _displayName(context, email);
    return expense.paidByDisplayName ?? '';
  }

  ClaimNotifier get _notifier =>
      ref.read(claimProvider(widget.group.id, widget.expense.id).notifier);

  /// Free-slot tap: claims the unit solo for the current persona. Persists
  /// immediately through the notifier's server RPC (optimistic refetch keeps
  /// the chips live).
  Future<void> _takeOne(ClaimUnitRow row) async {
    final persona = _persona;
    if (persona.isEmpty) return;
    try {
      await _notifier.claimUnit(row.entryId, persona);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.claimLoadError);
      }
    }
  }

  /// Toggles the inline split editor for [row] open/closed (F163: replaces the
  /// modal bottom sheet). Tapping an already-open unit collapses it.
  void _toggleUnit(ClaimUnitRow row) {
    setState(() {
      _expandedUnit = _expandedUnit == row.entryId ? null : row.entryId;
    });
  }

  /// Applies the chosen claimer set for [entryId] via the notifier and collapses
  /// the editor. Solo = one member; split = several; empty = unclaimed. The
  /// claim RPC / data flow is unchanged — only the container is inline now.
  Future<void> _applySplit(String entryId, List<String> claimers) async {
    setState(() => _expandedUnit = null);
    try {
      await _notifier.splitUnit(entryId, claimers);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.claimLoadError);
      }
    }
  }

  /// "Split one" on an item card: opens the inline editor on the first free
  /// unit. Nothing persists until the editor is applied.
  void _splitOne(ClaimItemGroup group) {
    final row = group.firstFree;
    if (row == null) return;
    _toggleUnit(row);
  }

  /// Nudge: fires an "expense" push to every other group member reminding them
  /// to claim their items (F175), then shows the local confirmation snackbar.
  /// Unclaimed units have no owner, so the receiver set is the whole group —
  /// `sendNotification` auto-strips the current user. Copy is built sender-side
  /// (same convention as [sendExpenseNotification]).
  void _nudge() {
    final l10n = AppLocalizations.of(context)!;
    final senderName =
        _memberFor(_currentUserEmail ?? '')?.displayName ?? l10n.you;
    final receivers =
        widget.group.groupMembers.map((m) => m.email).toSet();
    (widget.sendNotificationOverride ?? sendNotification)(
      'expense',
      widget.expense.id,
      receivers,
      l10n.claimNudgeNotificationTitle(senderName),
      l10n.claimNudgeNotificationBody(widget.expense.name, widget.group.name),
    );
    showSnackBar(context, l10n.claimNudgeSent);
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
              final groups = notifier.itemGroups;
              final rows = notifier.unitRows;
              final summary = buildClaimSummary(
                units: rows.map((r) => r.unit).toList(),
                personaEmail: _persona,
              );

              return Column(
                children: [
                  DeunHeader(
                    title: expense.name,
                    subtitle: l10n.claimPresenceCount(notifier.claimingNow),
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
                            payerName: _payerName(context, expense),
                            onNudge: _nudge,
                          ),
                        ],
                        const SizedBox(height: 24),
                        _ItemsCaption(l10n.claimItemsCaption),
                        const SizedBox(height: 8),
                        _ItemList(
                          groups: groups,
                          persona: _persona,
                          currentUserEmail: _currentUserEmail,
                          members: widget.group.groupMembers,
                          expandedUnit: _expandedUnit,
                          displayName: (e) => _displayName(context, e),
                          onTakeOne: _takeOne,
                          onTapUnit: _toggleUnit,
                          onSplitOne: _splitOne,
                          onApplySplit: _applySplit,
                        ),
                      ],
                    ),
                  ),
                  if (rows.isNotEmpty) const _TapItemsHintBar(),
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

/// "Preview as" persona switcher (v3 handoff §9): a card row with the muted
/// "Preview as" label on the left and one avatar circle per member (name in
/// small text underneath) on the right. The selected persona's avatar gets an
/// ink selection ring; the others are dimmed. Re-derives the summary's "your
/// share" for the chosen perspective — does not mutate claims. Solo groups
/// render the single member statically (nothing to preview as). The avatar
/// strip scrolls horizontally so large groups never overflow.
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final ordered = [...members]..sort((a, b) {
        if (a.email == currentUserEmail) return -1;
        if (b.email == currentUserEmail) return 1;
        return a.displayName.compareTo(b.displayName);
      });
    final interactive = ordered.length > 1;

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(
            l10n.claimPreviewAs,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in ordered) ...[
                      _PersonaAvatar(
                        key: ValueKey('persona:${m.email}'),
                        name: m.email == currentUserEmail
                            ? l10n.you
                            : m.displayName,
                        colorKey: m.email,
                        isYou: m.email == currentUserEmail,
                        selected: m.email == selected,
                        onTap: interactive ? () => onChanged(m.email) : null,
                      ),
                      if (m != ordered.last) const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One persona in the switcher: avatar circle with the name in small text
/// underneath. Selected → ink ring + full opacity; unselected → dimmed with a
/// muted label. The transparent placeholder ring keeps the avatar size stable
/// across selection changes.
class _PersonaAvatar extends StatelessWidget {
  const _PersonaAvatar({
    super.key,
    required this.name,
    required this.colorKey,
    required this.isYou,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String colorKey;
  final bool isYou;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: selected ? 1 : 0.55,
              child: MemberAvatar(
                name: name,
                colorKey: colorKey,
                radius: 16,
                isYou: isYou,
                ringColor: selected ? semantic.ink : Colors.transparent,
                ringWidth: 2.5,
              ),
            ),
            const SizedBox(height: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 56),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
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
    final textTheme = Theme.of(context).textTheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    // DESIGN_SPEC §9: fixed dark-ink focal card (#16181A), not group-tinted —
    // ink/onInk stay dark in both brightnesses.
    final Color heroSurface = semantic.ink;
    final Color onHero = semantic.onInk;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    return Container(
      width: double.infinity,
      // F174(a): mockup padding is 18×20 (vertical × horizontal), not all(20).
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // F174(a): the header baseline-aligns the big amount (left) with a
          // stacked right column ("you claimed" over the item count).
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.claimYourShare,
                      style:
                          textTheme.labelLarge?.copyWith(color: onHeroMuted),
                    ),
                    const SizedBox(height: 6),
                    MoneyText(
                      summary.yourShare,
                      style: textTheme.displaySmall?.copyWith(color: onHero),
                      animate: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // F174(a): stacked right column — muted "you claimed" label over
              // the bold white item count, bottom-aligned with the amount.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.claimYouClaimedLabel,
                    style: textTheme.bodySmall?.copyWith(color: onHeroMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.claimYouClaimedItems(summary.yourClaimedCount),
                    style: textTheme.titleSmall?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // F174(a): track rgba(white,0.12) with 16/7 margins.
          const SizedBox(height: 16),
          // F128: green success fill on the dark card (not the on-ink tone).
          ProgressBar(
            value: summary.progress,
            fillColor: semantic.success,
            trackColor: onHero.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 7),
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
              // F128/F174(a): remaining amount in amber "left" tone; once fully
              // claimed the figure flips to the green success tone (not muted).
              Text(
                summary.isFullyClaimed
                    ? l10n.claimAllClaimed
                    : l10n.claimLeftLabel(l10n.toCurrency(summary.unclaimed)),
                style: textTheme.bodySmall?.copyWith(
                  color:
                      summary.isFullyClaimed ? semantic.success : semantic.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (summary.memberTotals.isNotEmpty) ...[
            // F174(a): divider rgba(white,0.1) with 14/12 margins.
            const SizedBox(height: 14),
            Divider(height: 1, color: onHero.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            // F129/F174(c): per-person totals are equal-width chips that always
            // fit the card (flex:1, 6px gaps) — no horizontal scroll, so nothing
            // paints past the rounded edge.
            Row(
              children: [
                for (final m in summary.memberTotals) ...[
                  Expanded(
                    child: _MemberTotalChip(
                      name: displayName(m.email),
                      colorKey: m.email,
                      amount: m.amount,
                      isYou: m.email == currentUserEmail,
                      onHero: onHero,
                    ),
                  ),
                  if (m != summary.memberTotals.last)
                    const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One member's claim total as a compact chip in the horizontal per-person
/// strip: avatar + amount only (no name/label, per the v3 handoff), on a faint
/// tinted background (the "you" accent for the current persona). Lives on the
/// dark-ink hero card, so tints are keyed off [onHero] / primary and read
/// correctly in both themes.
class _MemberTotalChip extends StatelessWidget {
  const _MemberTotalChip({
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
    final primary = Theme.of(context).colorScheme.primary;
    final chipBg = isYou
        ? primary.withValues(alpha: 0.22)
        : onHero.withValues(alpha: 0.08);
    // F174(b): the chip is a vertical stack — 28px avatar on top, then the
    // amount underneath — with a 13px radius and 9×4 padding (mockup L1224-1227).
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberAvatar(name: name, colorKey: colorKey, radius: 14, isYou: isYou),
          const SizedBox(height: 5),
          MoneyText(
            amount,
            style: textTheme.bodySmall
                ?.copyWith(color: onHero, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Uppercase eyebrow caption above the item list (v3 "TAP TO TAKE WHAT YOU
/// HAD"). Natural-case copy comes from l10n; the screaming caps are applied
/// here via styling so the localized strings stay readable.
class _ItemsCaption extends StatelessWidget {
  const _ItemsCaption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Interactive list of claimable items (F131): one card per item group, with
/// one slot chip per unit — solo avatar+name, split avatars + "split · €X",
/// or a dashed "take one" per free unit — a ghost "Split one" button and the
/// "tap a slot" hint.
class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.groups,
    required this.persona,
    required this.currentUserEmail,
    required this.members,
    required this.expandedUnit,
    required this.displayName,
    required this.onTakeOne,
    required this.onTapUnit,
    required this.onSplitOne,
    required this.onApplySplit,
  });

  final List<ClaimItemGroup> groups;
  final String persona;
  final String? currentUserEmail;
  final List<GroupMember> members;
  final String? expandedUnit;
  final String Function(String email) displayName;
  final ValueChanged<ClaimUnitRow> onTakeOne;
  final ValueChanged<ClaimUnitRow> onTapUnit;
  final ValueChanged<ClaimItemGroup> onSplitOne;
  final void Function(String entryId, List<String> claimers) onApplySplit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (groups.isEmpty) {
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
        for (final group in groups) ...[
          _ItemCard(
            group: group,
            persona: persona,
            currentUserEmail: currentUserEmail,
            members: members,
            expandedUnit: expandedUnit,
            displayName: displayName,
            onTakeOne: onTakeOne,
            onTapUnit: onTapUnit,
            onSplitOne: () => onSplitOne(group),
            onApplySplit: onApplySplit,
          ),
          if (group != groups.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One item card: auto category icon, name + ×N, "€X each · N ordered"
/// subline, the persona's cost for this item, one chip per unit slot, and the
/// Split one / hint footer row.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.group,
    required this.persona,
    required this.currentUserEmail,
    required this.members,
    required this.expandedUnit,
    required this.displayName,
    required this.onTakeOne,
    required this.onTapUnit,
    required this.onSplitOne,
    required this.onApplySplit,
  });

  final ClaimItemGroup group;
  final String persona;
  final String? currentUserEmail;
  final List<GroupMember> members;
  final String? expandedUnit;
  final String Function(String email) displayName;
  final ValueChanged<ClaimUnitRow> onTakeOne;
  final ValueChanged<ClaimUnitRow> onTapUnit;
  final VoidCallback onSplitOne;
  final void Function(String entryId, List<String> claimers) onApplySplit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = group.name ?? '';
    // Auto category icon per item name (same detector the editor uses).
    final category = CategoryDetector.detectCategory(name);
    final categoryColor = category.getColor(context);
    final yourCost = persona.isEmpty ? 0.0 : group.costForPersona(persona);
    final personaHoldsNone = yourCost <= 0.005;
    // F163 taken-highlight: tint the whole card + add a faint primary border
    // when the persona holds any part of this item.
    final taken = yourCost > 0.005;

    // F163 inline editor: the expanded unit for this item (if any).
    ClaimUnitRow? expandedRow;
    for (final row in group.units) {
      if (row.entryId == expandedUnit) {
        expandedRow = row;
        break;
      }
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      color: taken ? colorScheme.primary.withValues(alpha: 0.05) : null,
      border: taken
          ? Border.all(
              color: colorScheme.primary.withValues(alpha: 0.20),
              width: 1.5,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.getIcon(), size: 22, color: categoryColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: name,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        children: [
                          if (group.quantity > 1)
                            TextSpan(
                              text: '  ×${group.quantity}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.quantity > 1
                          ? l10n.claimEachOrdered(
                              l10n.toCurrency(group.unitCost), group.quantity)
                          : l10n.toCurrency(group.unitCost),
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (yourCost > 0.005) ...[
                const SizedBox(width: 8),
                MoneyText(
                  yourCost,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final row in group.units)
                if (row.unit.isClaimed)
                  _ClaimedUnitChip(
                    key: ValueKey('slot:${row.entryId}'),
                    row: row,
                    persona: persona,
                    currentUserEmail: currentUserEmail,
                    displayName: displayName,
                    onTap: () => onTapUnit(row),
                  )
                else
                  _TakeOneChip(
                    key: ValueKey('slot:${row.entryId}'),
                    onTap: () => onTakeOne(row),
                  ),
            ],
          ),
          // F163: the inline split editor expands in place of the old modal.
          AnimatedSize(
            duration: Motion.sheetRiseDuration,
            curve: Motion.sheetRise,
            alignment: Alignment.topCenter,
            child: expandedRow == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: _SplitEditorCard(
                      key: ValueKey('editor:${expandedRow.entryId}'),
                      unitCost: expandedRow.unit.unitCost,
                      members: members,
                      currentUserEmail: currentUserEmail,
                      // Seed with the unit's claimers; for a still-free unit
                      // (opened via "Split one") preselect the current persona,
                      // matching the old modal's behaviour.
                      initialClaimers: expandedRow.unit.claimers.isNotEmpty
                          ? expandedRow.unit.claimers.toSet()
                          : {if (persona.isNotEmpty) persona},
                      onDone: (claimers) =>
                          onApplySplit(expandedRow!.entryId, claimers),
                    ),
                  ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _SplitOneButton(
                enabled: group.hasFree,
                onTap: onSplitOne,
              ),
              const Spacer(),
              if (group.hasFree && personaHoldsNone)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.claimTapSlotHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A claimed unit slot: avatar(s) pill with the claimer's name when solo or
/// "split · €each" when shared, tinted with the "you" accent when the persona
/// is a claimer. Tap opens the solo/split modal for this unit.
class _ClaimedUnitChip extends StatelessWidget {
  const _ClaimedUnitChip({
    super.key,
    required this.row,
    required this.persona,
    required this.currentUserEmail,
    required this.displayName,
    required this.onTap,
  });

  final ClaimUnitRow row;
  final String persona;
  final String? currentUserEmail;
  final String Function(String email) displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chipState = ClaimChipState.forPersona(row, persona);

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
    // F163 selected-state: a 1.5px accent border when the unit is yours,
    // otherwise a faint outline so every claimed chip reads as a bounded slot.
    final Color borderColor = chipState.claimedByYou
        ? colorScheme.primary.withValues(alpha: 0.35)
        : colorScheme.outlineVariant;
    final label = chipState.splitCount > 1
        ? l10n.claimSplitLabel(l10n.toCurrency(chipState.perUnitCost))
        : displayName(claimers.first);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(
            side: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarStack(members: stackMembers, radius: 11, ringColor: bg),
            const SizedBox(width: 6),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: chipState.claimedByYou
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A free unit slot: dashed "+ take one" chip. Tap claims it solo for the
/// current persona.
class _TakeOneChip extends StatelessWidget {
  const _TakeOneChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _DashedChip(
      color: colorScheme.primary.withValues(alpha: 0.55),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 15, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            l10n.claimTakeOne,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ghost "Split one" pill on the card footer. Dimmed and inert when the item
/// has no free unit left to split.
class _SplitOneButton extends StatelessWidget {
  const _SplitOneButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.call_split,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.claimSplitOne,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
  const _UnclaimedCallout({
    required this.unclaimed,
    required this.payerName,
    required this.onNudge,
  });

  final double unclaimed;
  final String payerName;
  final VoidCallback onNudge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: semantic.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      // F130: explanatory copy (amount + payer covers the rest) with a solid
      // black (ink/onInk) "Nudge" pill instead of a plain text link.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: semantic.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.claimUnclaimedCallout(
                    l10n.toCurrency(unclaimed),
                    payerName,
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: semantic.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _NudgePill(onTap: onNudge, label: l10n.claimNudge),
          ),
        ],
      ),
    );
  }
}

/// The solid black (ink/onInk) "Nudge" pill in the unclaimed callout (F130).
class _NudgePill extends StatelessWidget {
  const _NudgePill({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: semantic.ink,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: semantic.onInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar with a non-actionable hint (F132): claiming happens
/// instantly per tap, so there is no explicit confirm step — this just reads
/// "Tap the items you had".
class _TapItemsHintBar extends StatelessWidget {
  const _TapItemsHintBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.claimTapItemsHint,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline split editor (F163): the grey in-card box that replaces the old
/// modal bottom sheet. Choose who shares a single unit via toggleable member
/// pills, with the live per-person cost (unit / selected) in the title. "Done"
/// applies the selection through [onDone]. The claim RPC is unchanged — this is
/// only a sheet→inline container swap.
class _SplitEditorCard extends StatefulWidget {
  const _SplitEditorCard({
    super.key,
    required this.unitCost,
    required this.members,
    required this.currentUserEmail,
    required this.initialClaimers,
    required this.onDone,
  });

  final double unitCost;
  final List<GroupMember> members;
  final String? currentUserEmail;
  final Set<String> initialClaimers;
  final ValueChanged<List<String>> onDone;

  @override
  State<_SplitEditorCard> createState() => _SplitEditorCardState();
}

class _SplitEditorCardState extends State<_SplitEditorCard> {
  late final Set<String> _selected = {...widget.initialClaimers};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final perPerson =
        _selected.isEmpty ? 0.0 : widget.unitCost / _selected.length;

    return Container(
      width: double.infinity,
      // Grey surface box, radius14 (mockup L1276-1293) — surface is the warm
      // #F4F3EF token, distinct from the white item card it nests in.
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.claimSplitEditorTitle(l10n.toCurrency(perPerson)),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.claimSplitEditorHint,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final m in widget.members)
                _SplitMemberPill(
                  key: ValueKey('editor-member:${m.email}'),
                  name: m.email == widget.currentUserEmail
                      ? l10n.you
                      : m.displayName,
                  colorKey: m.email,
                  isYou: m.email == widget.currentUserEmail,
                  selected: _selected.contains(m.email),
                  onTap: () => setState(() {
                    if (!_selected.remove(m.email)) _selected.add(m.email);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 11),
          _SplitDoneButton(
            label: l10n.claimSplitDone,
            onTap: () => widget.onDone(_selected.toList()),
          ),
        ],
      ),
    );
  }
}

/// A toggleable member pill in the inline split editor: avatar + name, tinted
/// with the primary accent and a solid border when selected, faint outline when
/// not (mockup L1281-1286).
class _SplitMemberPill extends StatelessWidget {
  const _SplitMemberPill({
    super.key,
    required this.name,
    required this.colorKey,
    required this.isYou,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String colorKey;
  final bool isYou;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected
        ? colorScheme.primary.withValues(alpha: 0.14)
        : colorScheme.surfaceContainerLowest;
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.35)
        : colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(
            side: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: selected ? 1 : 0.55,
              child: MemberAvatar(
                name: name,
                colorKey: colorKey,
                radius: 11,
                isYou: isYou,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The solid-ink "Done" button that applies the inline split editor selection.
class _SplitDoneButton extends StatelessWidget {
  const _SplitDoneButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: semantic.ink,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.labelLarge?.copyWith(
                color: semantic.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
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
