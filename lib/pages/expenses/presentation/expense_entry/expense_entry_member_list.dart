import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../../../widgets/decimal_text_input_formatter.dart';
import '../../../../widgets/restyle/member_avatar.dart';
import '../../../../widgets/restyle/money_text.dart';
import '../../../../widgets/restyle/soft_card.dart';
import '../../../../widgets/restyle/stepper_control.dart';
import '../../../groups/data/group_member_model.dart';
import '../../data/split_mode.dart';

/// The quick split's member rows (include toggle, avatar, name, per-mode input)
/// plus the hidden `share_data` / `split_mode` / `locked_members` fields. All
/// split state lives in the editor's State; this only draws it and reports
/// edits through the callbacks.
class ExpenseEntryMemberList extends StatelessWidget {
  const ExpenseEntryMemberList({
    super.key,
    required this.index,
    required this.splitMode,
    required this.currency,
    required this.groupMembers,
    required this.enabledMembers,
    required this.lockedMembers,
    required this.memberAmounts,
    required this.memberPercentages,
    required this.memberParts,
    required this.shareData,
    required this.isSplitBalanced,
    required this.displayName,
    required this.isYou,
    required this.amountPreview,
    required this.memberController,
    required this.onToggleMember,
    required this.onSetParts,
    required this.onSetPercentage,
    required this.onStepPercentage,
    required this.onStepAmount,
    required this.onMemberAmountTap,
  });

  final int index;
  final SplitMode splitMode;
  final Currency currency;
  final List<GroupMember> groupMembers;

  /// The State's own Sets, not copies: the `shares` and `locked_members` fields
  /// take them as initial values and `_syncFormFields` hands the same
  /// instances back, so their identity is part of the form contract.
  final Set<String> enabledMembers;
  final Set<String> lockedMembers;
  final Map<String, double> memberAmounts;
  final Map<String, double> memberPercentages;
  final Map<String, int> memberParts;

  /// `share_data`'s initial value: a fresh `_buildShareData()` per build.
  final Map<String, dynamic> shareData;

  /// Whether the split adds up, read when the shares field validates.
  final bool Function() isSplitBalanced;
  final String Function(String email) displayName;
  final bool Function(String email) isYou;
  final double Function(String email) amountPreview;

  /// The State's get-or-create for the per-member controllers; it owns and
  /// disposes them.
  final TextEditingController Function(String key, String initialValue)
  memberController;
  final void Function(GroupMember member, bool include) onToggleMember;
  final void Function(String email, int parts) onSetParts;
  final void Function(String email, double percentage) onSetPercentage;
  final void Function(String email, double delta) onStepPercentage;
  final void Function(String email, double delta) onStepAmount;
  final Future<void> Function(String email, TextEditingController controller)
  onMemberAmountTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Shares field with validation
        FormBuilderField(
          key: ValueKey("${index}_shares"),
          name: "expense_entry[$index][shares]",
          initialValue: enabledMembers,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            Set<String>? shares = value;
            if (shares == null || shares.isEmpty) {
              return l10n.expenseEntrySharesValidationEmpty;
            }
            if (!isSplitBalanced()) {
              switch (splitMode) {
                case SplitMode.percentage:
                  return l10n.splitPercentageError;
                case SplitMode.amount:
                  return l10n.splitAmountError;
                case SplitMode.equal:
                case SplitMode.shares:
                  return l10n.expenseEntrySharesValidationEmpty;
              }
            }
            return null;
          },
          builder: (FormFieldState<dynamic> sharesField) {
            // F161 D1: only the member rows sit in a white SoftCard (radius 18,
            // padding v6/h4). No "Split between" InputDecorator label — the
            // section heading above already names it. errorText kept below.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Column(
                    children: [
                      ...groupMembers.map((member) {
                        bool isEnabled = enabledMembers.contains(member.email);
                        return _buildMemberRow(context, member, isEnabled);
                      }),
                    ],
                  ),
                ),
                if (sharesField.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      sharesField.errorText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Hidden fields for share_data, split_mode, locked_members
        Offstage(
          child: Column(
            children: [
              FormBuilderField(
                key: ValueKey("${index}_share_data"),
                name: "expense_entry[$index][share_data]",
                initialValue: shareData,
                builder: (field) => const SizedBox.shrink(),
              ),
              FormBuilderField(
                key: ValueKey("${index}_split_mode"),
                name: "expense_entry[$index][split_mode]",
                initialValue: splitMode.toDbValue(),
                builder: (field) => const SizedBox.shrink(),
              ),
              FormBuilderField(
                key: ValueKey("${index}_locked_members"),
                name: "expense_entry[$index][locked_members]",
                initialValue: lockedMembers,
                builder: (field) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// F161 D4: custom 26px round include toggle (mockup L982-988).
  /// Included = filled primary circle + white check(17); excluded = empty
  /// circle with a 2px outlineVariant border. The gesture box is padded out to
  /// a ≥48px hit target while the visual stays 26px.
  Widget _buildIncludeToggle(
    BuildContext context,
    GroupMember member,
    bool isEnabled,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: isEnabled,
      label: displayName(member.email),
      child: GestureDetector(
        key: ValueKey('split_toggle_${index}_${member.email}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggleMember(member, !isEnabled),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnabled ? colorScheme.primary : Colors.transparent,
              border: isEnabled
                  ? null
                  : Border.all(color: colorScheme.outlineVariant, width: 2),
            ),
            child: isEnabled
                ? Icon(Icons.check, size: 17, color: colorScheme.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRow(
    BuildContext context,
    GroupMember member,
    bool isEnabled,
  ) {
    String name = displayName(member.email);
    bool isLocked = lockedMembers.contains(member.email);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // F161 D4: 26px round include-toggle. Included = filled primary
          // circle + white check(17); excluded = empty circle with a 2px
          // outlineVariant border. ≥48px tap target via the padded gesture box.
          _buildIncludeToggle(context, member, isEnabled),
          // Avatar
          Opacity(
            opacity: isEnabled ? 1 : 0.4,
            child: MemberAvatar(
              name: name,
              colorKey: member.email,
              radius: 16,
              isYou: isYou(member.email),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isEnabled ? null : Theme.of(context).disabledColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Input area — fixed width to prevent layout shifts
          isEnabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Exact (amount) mode keeps the editable field; shares/%
                    // use a ± stepper; equal shows just the per-head amount.
                    if (splitMode == SplitMode.amount) ...[
                      _buildMemberInput(context, member.email),
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                    ] else ...[
                      if (splitMode != SplitMode.equal) ...[
                        _buildMemberStepper(context, member.email),
                        const SizedBox(width: 6),
                      ],
                      // € preview for equal, percentage and parts mode
                      SizedBox(
                        width: 52,
                        child: MoneyText(
                          amountPreview(member.email),
                          currency: currency,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ],
                )
              // Excluded members show a muted "Not in" instead of an amount.
              : Text(
                  AppLocalizations.of(context)!.splitNotInLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ],
      ),
    );
  }

  /// A ± stepper for non-equal modes: ±1 part (shares), ±5% (percentage),
  /// ±€0.50 (amount). Mutates the same per-member maps the text inputs use and
  /// runs the existing recalculation path so the split math is unchanged.
  Widget _buildMemberStepper(BuildContext context, String email) {
    switch (splitMode) {
      case SplitMode.equal:
        // Equal has no per-member control — never reached (guarded in
        // _buildMemberRow).
        return const SizedBox.shrink();
      case SplitMode.shares:
        final parts = memberParts[email] ?? 1;
        return StepperControl(
          value: "$parts",
          canDecrement: parts > 0,
          onDecrement: () => onSetParts(email, (parts - 1).clamp(0, 9999)),
          onIncrement: () => onSetParts(email, parts + 1),
        );
      case SplitMode.percentage:
        final pct = memberPercentages[email] ?? 0;
        return StepperControl(
          value: "${pct.toStringAsFixed(0)}%",
          canDecrement: pct > 0,
          onDecrement: () => onStepPercentage(email, -5),
          onIncrement: () => onStepPercentage(email, 5),
        );
      case SplitMode.amount:
        final amt = memberAmounts[email] ?? 0;
        return StepperControl(
          value: AppLocalizations.of(context)!.toCurrency(amt, currency.code),
          canDecrement: amt > 0,
          onDecrement: () => onStepAmount(email, -0.50),
          onIncrement: () => onStepAmount(email, 0.50),
        );
    }
  }

  Widget _buildMemberInput(BuildContext context, String email) {
    switch (splitMode) {
      case SplitMode.equal:
        // Equal has no editable input — never reached (guarded in
        // _buildMemberRow).
        return const SizedBox.shrink();
      case SplitMode.amount:
        double val = memberAmounts[email] ?? 0;
        String ctrlKey = "amount_${index}_$email";
        TextEditingController controller = memberController(
          ctrlKey,
          formatAmountOnly(val, currency, Localizations.localeOf(context)),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currency.code, style: Theme.of(context).textTheme.bodyLarge),
            // Tap-to-open keypad (F158): per-member exact amount is money, so it
            // routes through showAmountKeypadSheet instead of a raw system-keyboard
            // field. The controller stays the source of truth (so
            // _updateUnlockedControllers still syncs it); confirm runs the same
            // mutation the old onChanged did (lock member + recalc).
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => InkWell(
                key: ValueKey(ctrlKey),
                onTap: () => onMemberAmountTap(email, controller),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Text(
                      controller.text.isEmpty
                          ? formatAmountOnly(
                              0,
                              currency,
                              Localizations.localeOf(context),
                            )
                          : controller.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case SplitMode.percentage:
        double val = memberPercentages[email] ?? 0;
        String ctrlKey = "pct_${index}_$email";
        TextEditingController controller = memberController(
          ctrlKey,
          val.toStringAsFixed(1),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 30, maxWidth: 60),
                child: TextFormField(
                  key: ValueKey(ctrlKey),
                  controller: controller,
                  onChanged: (value) =>
                      onSetPercentage(email, double.tryParse(value) ?? 0),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalTextInputFormatter(decimalRange: 1)],
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Text(" %", style: Theme.of(context).textTheme.bodyLarge),
          ],
        );

      case SplitMode.shares:
        int val = memberParts[email] ?? 1;
        String ctrlKey = "parts_${index}_$email";
        TextEditingController controller = memberController(
          ctrlKey,
          val.toString(),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 20, maxWidth: 40),
                child: TextFormField(
                  key: ValueKey(ctrlKey),
                  controller: controller,
                  onChanged: (value) =>
                      onSetParts(email, int.tryParse(value) ?? 1),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Text("x", style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
    }
  }
}
