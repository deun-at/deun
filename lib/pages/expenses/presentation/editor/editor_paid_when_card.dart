import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../../../widgets/restyle/expense_picker_sheets.dart';
import '../../../../widgets/restyle/member_avatar.dart';
import '../../../../widgets/restyle/soft_card.dart';
import '../../../groups/data/group_member_model.dart';
import '../../../groups/data/group_model.dart';
import '../../../groups/data/member_display.dart';

/// v3 quick block: a single white card holding the Paid-by and When rows with
/// no spacing between them (a hairline divider separates the two), replacing
/// the two separate boxed cards.
///
/// Owns the `paid_by` and `expense_date` form fields. [onDateChanged] hears
/// every date change: it is THE only refetch trigger for a historical rate.
class EditorPaidWhenCard extends StatelessWidget {
  const EditorPaidWhenCard({
    super.key,
    required this.screenContext,
    required this.group,
    required this.display,
    required this.initialDate,
    required this.initialPaidBy,
    required this.onDateChanged,
  });

  /// The screen's own context, above the group's `ThemeBuilder`: the divider's
  /// colour and the sheets this card opens take the app's brand theme from
  /// here, not the group's.
  final BuildContext screenContext;
  final Group group;

  /// How this card names members; its `currentUserEmail` is the signed-in
  /// user, who is the default payer.
  final MemberDisplay display;
  final DateTime initialDate;

  /// The saved expense's payer, or null for a new one, which defaults to the
  /// signed-in user.
  final String? initialPaidBy;

  final ValueChanged<DateTime?> onDateChanged;

  // group-member-removal: keeps searching the FULL roster (not activeMembers) —
  // a past expense paid by a since-removed member must still resolve to their
  // name in the ledger.
  GroupMember? _findMember(String? email) {
    if (email == null) return null;
    try {
      return group.groupMembers.firstWhere((m) => m.email == email);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(screenContext).colorScheme;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPaidByRow(context),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          _buildDateRow(context),
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormBuilderField<DateTime>(
      name: "expense_date",
      initialValue: initialDate,
      // THE only refetch trigger. A historical rate is a fact about the
      // expense's day, so changing the day changes the rate; changing anything
      // else does not, and any broader trigger reintroduces surprise rate
      // movement on an expense the user thought was settled.
      onChanged: onDateChanged,
      builder: (FormFieldState<DateTime?> field) {
        final value = field.value ?? initialDate;
        return _PaidWhenRow(
          icon: Icons.calendar_today_outlined,
          label: l10n.expenseWhen,
          value: formatDate(value.toIso8601String(), context),
          onTap: () async {
            final picked = await showDateOptionsSheet(
              screenContext,
              current: value,
            );
            if (picked != null) field.didChange(picked);
          },
        );
      },
    );
  }

  Widget _buildPaidByRow(BuildContext context) {
    final initialEmail = initialPaidBy ?? display.currentUserEmail;

    return FormBuilderField<String>(
      name: "paid_by",
      initialValue: initialEmail,
      builder: (FormFieldState<String?> field) {
        final l10n = AppLocalizations.of(context)!;
        final selectedMember = _findMember(field.value);
        final isYou = display.isYou(field.value);
        return _PaidWhenRow(
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.expensePaidBy,
          value: display.nameOf(field.value),
          trailingLeading: selectedMember != null
              ? MemberAvatar(
                  name: selectedMember.displayName,
                  colorKey: selectedMember.email,
                  radius: 12,
                  isYou: isYou,
                )
              : null,
          onTap: () async {
            final picked = await showPaidBySheet(
              screenContext,
              members: display.pickerMembers,
              selectedEmail: field.value,
              currentUserEmail: display.currentUserEmail,
            );
            if (picked != null) field.didChange(picked);
          },
        );
      },
    );
  }
}

/// A single-line row for the quick editor's Paid-by / When list: leading icon,
/// grey label, right-aligned value (optionally preceded by a small avatar),
/// then a chevron. Rows sit inside a shared card with no spacing between them.
/// Tapping fires [onTap] — which opens the existing picker/sheet unchanged.
class _PaidWhenRow extends StatelessWidget {
  const _PaidWhenRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailingLeading,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Optional small widget shown just before the value (e.g. a member avatar).
  final Widget? trailingLeading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 21),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingLeading != null) ...[
              trailingLeading!,
              const SizedBox(width: 8),
            ],
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colorScheme.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
