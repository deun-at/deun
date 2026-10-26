import 'dart:async';

import 'package:deun/app_paths.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:deun/provider.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_error_state.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_item_list.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_persona_switcher.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_presence_pulse.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_summary_card.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_tap_items_hint_bar.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_unclaimed_callout.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
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
/// tap a claimed slot or "Split one" for the solo/split modal (see [ClaimItemCard]).
/// The push transport the Nudge action sends through. Tests inject a spy so
/// they never hit the live `push` Edge Function.
typedef ClaimNotificationSender = PushTransport;

class ClaimPage extends ConsumerStatefulWidget {
  const ClaimPage({
    super.key,
    required this.group,
    required this.expense,
    this.sendNotificationOverride,
  });

  final Group group;
  final Expense expense;

  /// Test seam for the Nudge push. Null in production → the service's default transport.
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

  String? get _currentUserEmail => ref.read(currentUserProvider)?.email;

  String get _persona => _personaEmail ?? _currentUserEmail ?? '';

  void _openEditor() {
    GoRouter.of(context).push(
      AppPaths.expenseEdit(widget.group.id, widget.expense.id),
      extra: ExpenseRouteExtra(group: widget.group, expense: widget.expense),
    );
  }

  /// The expense payer's display name for the unclaimed callout (F130).
  String _payerName(MemberDisplay display, Expense expense) {
    final email = expense.paidBy;
    if (email != null && email.isNotEmpty) return display.nameOf(email);
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

  /// Nudge: fires a claim-nudge push to every other group member reminding
  /// them to claim their items (F175), then shows the local confirmation
  /// snackbar. Unclaimed units have no owner, so the receiver set is the whole
  /// group. The server drops the sender and anyone not an active member, and
  /// writes the copy in each receiver's language.
  void _nudge() {
    unawaited(
      NotificationSender(push: widget.sendNotificationOverride).claimNudge(
        expenseId: widget.expense.id,
        receivers: widget.group.groupMembers.map((m) => m.email).toSet(),
      ),
    );
    showSnackBar(context, AppLocalizations.of(context)!.claimNudgeSent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final display = MemberDisplay(
      currentUserEmail: ref.watch(currentUserProvider)?.email,
      youLabel: l10n.you,
      roster: widget.group.groupMembers,
    );
    final claimState = ref.watch(
      claimProvider(widget.group.id, widget.expense.id),
    );
    final notifier = ref.read(
      claimProvider(widget.group.id, widget.expense.id).notifier,
    );

    return ThemeBuilder(
      colorValue: widget.group.colorValue,
      builder: (context) {
        return Scaffold(
          body: claimState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                ClaimErrorState(message: l10n.claimLoadError),
            data: (expense) {
              final groups = notifier.itemGroups;
              final rows = notifier.unitRows;
              final summary = buildClaimSummary(
                units: rows.map((r) => r.unit).toList(),
                personaEmail: _persona,
                currency: widget.group.currency,
              );

              return Column(
                children: [
                  DeunHeader(
                    title: expense.name,
                    subtitle: l10n.claimPresenceCount(notifier.claimingNow),
                    subtitleLeading: const ClaimPresencePulse(),
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
                        ClaimPersonaSwitcher(
                          members: display.pickerMembers,
                          selected: _persona,
                          display: display,
                          onChanged: (email) =>
                              setState(() => _personaEmail = email),
                        ),
                        const SizedBox(height: 16),
                        ClaimSummaryCard(
                          summary: summary,
                          display: display,
                          currency: widget.group.currency,
                        ),
                        if (!summary.isFullyClaimed &&
                            !isSettled(
                              summary.unclaimed,
                              widget.group.currency,
                            )) ...[
                          const SizedBox(height: 16),
                          ClaimUnclaimedCallout(
                            unclaimed: summary.unclaimed,
                            payerName: _payerName(display, expense),
                            onNudge: _nudge,
                            currency: widget.group.currency,
                          ),
                        ],
                        const SizedBox(height: 24),
                        ClaimItemsCaption(l10n.claimItemsCaption),
                        const SizedBox(height: 8),
                        ClaimItemList(
                          groups: groups,
                          persona: _persona,
                          display: display,
                          // group-member-removal: activeMembers, not
                          // groupMembers — a removed member must not be
                          // offered a share of a new/edited split. Existing
                          // claims survive because ClaimSplitEditorCard seeds
                          // _selected from initialClaimers (the unit's stored
                          // claimers), and the display helper keeps
                          // resolving names from the full roster.
                          members: widget.group.activeMembers,
                          expandedUnit: _expandedUnit,
                          onTakeOne: _takeOne,
                          onTapUnit: _toggleUnit,
                          onSplitOne: _splitOne,
                          onApplySplit: _applySplit,
                          currency: widget.group.currency,
                        ),
                      ],
                    ),
                  ),
                  if (rows.isNotEmpty) const ClaimTapItemsHintBar(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
