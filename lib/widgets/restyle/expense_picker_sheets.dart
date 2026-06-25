import 'package:flutter/material.dart';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/date_option.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/keypad_amount.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';

import 'member_avatar.dart';
import 'money_text.dart';
import 'primary_button.dart';
import 'sheet_scaffold.dart';

/// Shared rounded-top shape + scroll control for these pickers.
Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

// ---------------------------------------------------------------------------
// Category grid sheet
// ---------------------------------------------------------------------------

/// Opens the category picker as a [SheetScaffold] icon grid. Resolves to the
/// chosen [ExpenseCategory], or `null` if dismissed.
Future<ExpenseCategory?> showCategoryGridSheet(
  BuildContext context, {
  required ExpenseCategory? selected,
}) {
  return _showSheet<ExpenseCategory>(
    context,
    CategoryGridSheet(selected: selected),
  );
}

/// An icon grid of every [ExpenseCategory] (icon in the category color tint +
/// name). Tapping a tile pops it as the sheet result.
class CategoryGridSheet extends StatelessWidget {
  const CategoryGridSheet({super.key, required this.selected});

  final ExpenseCategory? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SheetScaffold(
      title: l10n.categorySheetTitle,
      body: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
        children: [
          for (final category in ExpenseCategory.values)
            _CategoryGridTile(
              category: category,
              isSelected: category == selected,
              onTap: () => Navigator.of(context).pop(category),
            ),
        ],
      ),
    );
  }
}

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = category.getColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 0.30 : 0.16),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Icon(category.getIcon(), color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            category.getDisplayName(l10n),
            style: textTheme.labelSmall?.copyWith(
              color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paid-by sheet
// ---------------------------------------------------------------------------

/// Opens the paid-by picker as a [SheetScaffold] member list. Resolves to the
/// chosen member's email, or `null` if dismissed.
Future<String?> showPaidBySheet(
  BuildContext context, {
  required List<GroupMember> members,
  required String? selectedEmail,
  required String? currentUserEmail,
}) {
  return _showSheet<String>(
    context,
    PaidBySheet(
      members: members,
      selectedEmail: selectedEmail,
      currentUserEmail: currentUserEmail,
    ),
  );
}

/// A member list (avatar + name, current payer checked). Tapping a row pops the
/// member's email as the result.
class PaidBySheet extends StatelessWidget {
  const PaidBySheet({
    super.key,
    required this.members,
    required this.selectedEmail,
    required this.currentUserEmail,
  });

  final List<GroupMember> members;
  final String? selectedEmail;
  final String? currentUserEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return SheetScaffold(
      title: l10n.paidBySheetTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final member in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MemberAvatar(
                name: member.displayName,
                colorKey: member.email,
                radius: 18,
                isYou: member.email == currentUserEmail,
              ),
              title: Text(
                member.email == currentUserEmail
                    ? l10n.you
                    : member.displayName,
              ),
              subtitle: Text(member.fullUsername),
              trailing: member.email == selectedEmail
                  ? Icon(Icons.check_circle, color: colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(member.email),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date sheet
// ---------------------------------------------------------------------------

/// Opens the date picker as a [SheetScaffold] with quick options
/// (Today / Yesterday / Pick a date…). "Pick a date…" defers to the platform
/// [showDatePicker]. Resolves to the chosen [DateTime], or `null` if dismissed.
Future<DateTime?> showDateOptionsSheet(
  BuildContext context, {
  required DateTime current,
}) async {
  final option = await _showSheet<DateOption>(
    context,
    DateOptionsSheet(current: current),
  );
  if (option == null) return null;

  final now = DateTime.now();
  if (option == DateOption.pick) {
    if (!context.mounted) return null;
    return showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
  }
  return option.resolve(now);
}

/// Quick date options list. Pops the chosen [DateOption] (the caller resolves
/// it to a [DateTime], deferring [DateOption.pick] to the calendar).
class DateOptionsSheet extends StatelessWidget {
  const DateOptionsSheet({super.key, required this.current});

  final DateTime current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    Widget tile(IconData icon, String label, DateOption option,
        {bool selected = false}) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: colorScheme.onSurfaceVariant),
        title: Text(label),
        trailing: selected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : null,
        onTap: () => Navigator.of(context).pop(option),
      );
    }

    return SheetScaffold(
      title: l10n.dateSheetTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile(Icons.today_outlined, l10n.dateToday, DateOption.today,
              selected: DateOption.today.matches(current, now)),
          tile(Icons.history, l10n.dateYesterday, DateOption.yesterday,
              selected: DateOption.yesterday.matches(current, now)),
          tile(Icons.calendar_month_outlined, l10n.datePickCustom,
              DateOption.pick),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount keypad sheet
// ---------------------------------------------------------------------------

/// Opens the amount keypad as a [SheetScaffold]. Enforces 2 decimals / 7
/// integer digits / a single decimal point via [KeypadAmount]. Resolves to the
/// confirmed amount (`double`), or `null` if dismissed.
Future<double?> showAmountKeypadSheet(
  BuildContext context, {
  required double initialAmount,
}) {
  return _showSheet<double>(
    context,
    AmountKeypadSheet(initialAmount: initialAmount),
  );
}

/// A numeric amount keypad (digits, decimal, backspace) with a live amount
/// display. Confirm pops the entered value.
class AmountKeypadSheet extends StatefulWidget {
  const AmountKeypadSheet({super.key, required this.initialAmount});

  final double initialAmount;

  @override
  State<AmountKeypadSheet> createState() => _AmountKeypadSheetState();
}

class _AmountKeypadSheetState extends State<AmountKeypadSheet> {
  late KeypadAmount _amount;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialAmount > 0
        ? _trimAmount(widget.initialAmount)
        : '0';
    _amount = KeypadAmount.fromText(seed);
  }

  /// Formats the seed value without forcing trailing zeros (e.g. 42 -> "42",
  /// 12.5 -> "12.50") so the keypad display matches what the user expects.
  String _trimAmount(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  void _onDigit(String digit) =>
      setState(() => _amount = _amount.appendDigit(digit));

  void _onDecimal() => setState(() => _amount = _amount.appendDecimal());

  void _onBackspace() => setState(() => _amount = _amount.backspace());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SheetScaffold(
      title: l10n.amountSheetTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live amount display.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: MoneyText(
              _amount.value,
              style: textTheme.displayMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _KeypadGrid(
            onDigit: _onDigit,
            onDecimal: _onDecimal,
            onBackspace: _onBackspace,
          ),
        ],
      ),
      footer: PrimaryButton(
        key: const ValueKey('keypad_confirm'),
        onPressed: () => Navigator.of(context).pop(_amount.value),
        label: l10n.save,
      ),
    );
  }
}

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            children: [
              for (final d in row)
                _KeypadButton(
                  keyValue: 'keypad_$d',
                  label: d,
                  onTap: () => onDigit(d),
                ),
            ],
          ),
        Row(
          children: [
            _KeypadButton(
              keyValue: 'keypad_decimal',
              label: '.',
              onTap: onDecimal,
            ),
            _KeypadButton(
              keyValue: 'keypad_0',
              label: '0',
              onTap: () => onDigit('0'),
            ),
            _KeypadButton(
              keyValue: 'keypad_backspace',
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.keyValue,
    required this.onTap,
    this.label,
    this.icon,
  });

  final String keyValue;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey(keyValue),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: colorScheme.onSurface)
                    : Text(
                        label!,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
