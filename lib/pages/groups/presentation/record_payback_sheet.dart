import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

import '../data/group_model.dart';
import '../data/group_repository.dart';
import '../data/payback_request.dart';

/// The write [RecordPaybackSheet] performs. Null in production →
/// [GroupRepository.payBack]; widget tests inject a stub so they never reach the
/// network (same seam as `ExpenseDetailRead.loadGroupPaybacks`).
typedef PaybackRecorder =
    Future<void> Function({
      required String groupId,
      required String paidBy,
      required String paidFor,
      required double amount,
    });

/// Opens the record-a-payment sheet.
///
/// Resolves when the sheet closes and carries no result: a written payback bumps
/// `group_update_checker`, and the realtime subscription behind
/// `groupDetailProvider` is what refreshes the screen underneath — the caller has
/// nothing to do with the answer.
Future<void> showRecordPaybackSheet(
  BuildContext context, {
  required Group group,
  PaybackRecorder? recordPayback,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    backgroundColor: Colors.transparent,
    builder: (_) => ThemeBuilder(
      colorValue: group.colorValue,
      builder: (_) =>
          RecordPaybackSheet(group: group, recordPayback: recordPayback),
    ),
  );
}

/// Records a payment between ANY two members of the group — including two
/// people who are not the current user.
///
/// Deun has no owner concept (see the plan's Decisions): any member may edit or
/// delete anyone's expenses, so gating this would be a stricter rule than the
/// app applies to strictly more destructive actions. What replaces permission is
/// visibility — both parties are notified and the recorder is written onto the
/// row.
class RecordPaybackSheet extends StatefulWidget {
  const RecordPaybackSheet({
    super.key,
    required this.group,
    this.recordPayback,
  });

  final Group group;
  final PaybackRecorder? recordPayback;

  @override
  State<RecordPaybackSheet> createState() => _RecordPaybackSheetState();
}

class _RecordPaybackSheetState extends State<RecordPaybackSheet> {
  String? _paidBy;
  String? _paidFor;
  double _amount = 0;
  bool _saving = false;

  String? get _currentUserEmail => supabase.auth.currentUser?.email;

  @override
  void initState() {
    super.initState();
    // The common case is still "I paid them", so the payer starts as me.
    _paidBy = _currentUserEmail;
  }

  String _nameFor(String? email) {
    if (email == null) return '';
    for (final member in widget.group.groupMembers) {
      if (member.email == email) return member.displayName;
    }
    return email;
  }

  Future<void> _pickMember(bool isPayer) async {
    final picked = await showPaidBySheet(
      context,
      members: widget.group.activeMembers,
      selectedEmail: isPayer ? _paidBy : _paidFor,
      currentUserEmail: _currentUserEmail,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isPayer) {
        _paidBy = picked;
      } else {
        _paidFor = picked;
      }
    });
  }

  Future<void> _pickAmount() async {
    final picked = await showAmountKeypadSheet(context, initialAmount: _amount);
    if (picked == null || !mounted) return;
    setState(() => _amount = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    // Decided before anything is written. The same rule runs again inside
    // GroupRepository.payBack and a third time inside the pay_back RPC; this
    // call is the one that produces a message.
    final plan = resolvePayback(
      paidBy: _paidBy ?? '',
      paidFor: _paidFor ?? '',
      amount: _amount,
      recordedBy: _currentUserEmail ?? '',
      members: widget.group.groupMembers,
    );

    final PaybackAccepted accepted;
    switch (plan) {
      case PaybackRejected():
        showSnackBar(context, plan.message(l10n));
        return;
      case PaybackAccepted():
        accepted = plan;
    }

    setState(() => _saving = true);
    try {
      final recorder = widget.recordPayback;
      if (recorder != null) {
        await recorder(
          groupId: widget.group.id,
          paidBy: accepted.paidBy,
          paidFor: accepted.paidFor,
          amount: accepted.amount,
        );
      } else {
        await GroupRepository.payBack(
          context,
          widget.group.id,
          accepted.paidFor,
          accepted.amount,
          paidBy: accepted.paidBy,
          // Deliberately no `members:` here: the sheet can sit open for a while,
          // so let the repository re-resolve against a FRESH roster and catch a
          // member removed in the meantime.
        );
      }
      if (!mounted) return;
      showSnackBar(
        context,
        l10n.paybackRecordSuccess(
          accepted.paidByDisplayName,
          accepted.paidForDisplayName,
          l10n.toCurrency(accepted.amount, widget.group.currencyCode),
        ),
      );
      Navigator.of(context).pop();
    } on PaybackRejectedException catch (e) {
      // The repository re-resolves the plan, so it can reject what the sheet
      // accepted. Say why, not the generic write error.
      if (mounted) showSnackBar(context, e.rejection.message(l10n));
    } catch (e) {
      debugPrint('Failed to record payback in ${widget.group.id}: $e');
      if (mounted) showSnackBar(context, l10n.payBackError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return SheetScaffold(
      title: l10n.paybackRecordTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.paybackRecordSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _PickerRow(
            rowKey: const ValueKey('record_payback_paid_by'),
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.paybackRecordPaidByLabel,
            value: _nameFor(_paidBy),
            email: _paidBy,
            onTap: () => _pickMember(true),
          ),
          _PickerRow(
            rowKey: const ValueKey('record_payback_paid_to'),
            icon: Icons.person_outline,
            label: l10n.paybackRecordPaidToLabel,
            value: _nameFor(_paidFor),
            email: _paidFor,
            onTap: () => _pickMember(false),
          ),
          ListTile(
            key: const ValueKey('record_payback_amount'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.payments_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            title: Text(l10n.paybackRecordAmountLabel),
            trailing: MoneyText(
              _amount,
              currencyCode: widget.group.currencyCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: _pickAmount,
          ),
        ],
      ),
      footer: PrimaryButton(
        key: const ValueKey('record_payback_submit'),
        onPressed: _saving ? null : _submit,
        loading: _saving,
        label: l10n.paybackRecordSubmit,
      ),
    );
  }
}

/// One "label … member" row that opens the shared paid-by picker.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.email,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final String value;
  final String? email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      key: rowKey,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (email != null) ...[
            MemberAvatar(name: value, colorKey: email!, radius: 12),
            const SizedBox(width: 8),
          ],
          Text(value, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}
