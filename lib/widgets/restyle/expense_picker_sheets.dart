import 'package:flutter/material.dart';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/date_option.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/expenses/data/keypad_amount.dart';
import 'package:deun/pages/expenses/data/keypad_calculator.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';

import 'package:deun/widgets/decimal_text_input_formatter.dart';

import 'member_avatar.dart';
import 'soft_card.dart';
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

/// An icon grid of every [ExpenseCategory] (monochrome icon tile + name).
/// Tapping a tile pops it as the sheet result. Tiles are colorless: the
/// selected one uses the theme's primary fill, the rest a neutral surface
/// (matching the v3 handoff category sheet — no per-category color).
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isSelected
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Icon(
              category.getIcon(),
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.getDisplayName(l10n),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
  String? title,
}) {
  return _showSheet<String>(
    context,
    PaidBySheet(
      members: members,
      selectedEmail: selectedEmail,
      currentUserEmail: currentUserEmail,
      title: title,
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
    this.title,
  });

  final List<GroupMember> members;
  final String? selectedEmail;
  final String? currentUserEmail;

  /// What this picker is choosing. Both sides of a payback reuse this sheet, so
  /// the payee picker has to be able to say so rather than announcing "Paid by".
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final display = MemberDisplay(
      currentUserEmail: currentUserEmail,
      youLabel: l10n.you,
      roster: members,
    );

    return SheetScaffold(
      title: title ?? l10n.paidBySheetTitle,
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
                isYou: display.isYou(member.email),
              ),
              title: Text(display.nameOf(member.email)),
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

    Widget tile(
      IconData icon,
      String label,
      DateOption option, {
      bool selected = false,
    }) {
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
          tile(
            Icons.today_outlined,
            l10n.dateToday,
            DateOption.today,
            selected: DateOption.today.matches(current, now),
          ),
          tile(
            Icons.history,
            l10n.dateYesterday,
            DateOption.yesterday,
            selected: DateOption.yesterday.matches(current, now),
          ),
          tile(
            Icons.calendar_month_outlined,
            l10n.datePickCustom,
            DateOption.pick,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount keypad sheet
// ---------------------------------------------------------------------------

/// Opens the amount keypad as a [SheetScaffold]. Supports +, −, ×, ÷ via
/// [KeypadCalculator] and enforces 2 decimals / 7 integer digits / a single
/// decimal point per operand. Resolves to the confirmed amount (`double`), or
/// `null` if dismissed.
Future<double?> showAmountKeypadSheet(
  BuildContext context, {
  required double initialAmount,
  required Currency currency,
}) {
  return _showSheet<double>(
    context,
    AmountKeypadSheet(initialAmount: initialAmount, currency: currency),
  );
}

/// A numeric amount keypad (digits, decimal, backspace) with a live amount
/// display. Confirm pops the entered value.
class AmountKeypadSheet extends StatefulWidget {
  const AmountKeypadSheet({
    super.key,
    required this.initialAmount,
    required this.currency,
  });

  final double initialAmount;
  final Currency currency;

  @override
  State<AmountKeypadSheet> createState() => _AmountKeypadSheetState();
}

class _AmountKeypadSheetState extends State<AmountKeypadSheet> {
  late KeypadCalculator _calc;

  @override
  void initState() {
    super.initState();
    // The seed goes through the keypad's own formatter (KeypadAmount.format) so
    // the sheet cannot disagree with the calculator about how a currency's
    // digits are rendered: 42 -> "42", 12.5 -> "12.50", ¥3000 -> "3000".
    final seed = widget.initialAmount > 0
        ? KeypadAmount.format(
            widget.initialAmount,
            widget.currency.decimalDigits,
          )
        : '0';
    _calc = KeypadCalculator.fromText(
      seed,
      decimalDigits: widget.currency.decimalDigits,
    );
  }

  void _onDigit(String digit) =>
      setState(() => _calc = _calc.appendDigit(digit));

  void _onDecimal() => setState(() => _calc = _calc.appendDecimal());

  void _onBackspace() => setState(() => _calc = _calc.backspace());

  void _onOperator(KeypadOperator op) =>
      setState(() => _calc = _calc.applyOperator(op));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasError = _calc.hasError;
    // During an invalid calculation the running result is undefined; show the
    // last-good `0` placeholder rather than a bogus number.
    final displayValue = hasError ? 0.0 : _calc.value;

    return SheetScaffold(
      title: l10n.amountSheetTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // In-progress expression line (empty during plain entry) + inline
          // error when the calculation can't be committed.
          SizedBox(
            height: 22,
            child: Text(
              hasError ? l10n.amountKeypadInvalid : _calc.expression,
              key: const ValueKey('keypad_expression'),
              style: textTheme.titleMedium?.copyWith(
                color: hasError
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Live running result.
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 16),
            child: MoneyText(
              displayValue,
              currency: widget.currency,
              style: textTheme.displayMedium?.copyWith(
                color: hasError ? colorScheme.error : colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _KeypadGrid(
            onDigit: _onDigit,
            onDecimal: _onDecimal,
            onBackspace: _onBackspace,
            onOperator: _onOperator,
          ),
        ],
      ),
      footer: PrimaryButton(
        key: const ValueKey('keypad_confirm'),
        // '=' semantics: resolve the final result. Blocked while invalid so a
        // divide-by-zero / out-of-range result can never be committed.
        onPressed: hasError
            ? null
            : () => Navigator.of(context).pop(_calc.value),
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
    required this.onOperator,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final ValueChanged<KeypadOperator> onOperator;

  @override
  Widget build(BuildContext context) {
    // Digit rows paired with the operator column (classic calculator layout);
    // '=' is the confirm/Save CTA in the sheet footer.
    const digitRows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    const operatorColumn = [
      KeypadOperator.divide,
      KeypadOperator.multiply,
      KeypadOperator.subtract,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < digitRows.length; i++)
          Row(
            children: [
              for (final d in digitRows[i])
                _KeypadButton(
                  keyValue: 'keypad_$d',
                  label: d,
                  onTap: () => onDigit(d),
                ),
              _KeypadButton(
                keyValue: 'keypad_op_${operatorColumn[i].name}',
                label: operatorColumn[i].symbol,
                accent: true,
                onTap: () => onOperator(operatorColumn[i]),
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
            _KeypadButton(
              keyValue: 'keypad_op_${KeypadOperator.add.name}',
              label: KeypadOperator.add.symbol,
              accent: true,
              onTap: () => onOperator(KeypadOperator.add),
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
    this.accent = false,
  });

  final String keyValue;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  /// Operator keys use a primary-tinted fill/label so they read distinctly from
  /// the neutral digit keys while keeping the sheet's established look.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final fill = accent
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = accent
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey(keyValue),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: foreground)
                    : Text(
                        label!,
                        style: textTheme.headlineSmall?.copyWith(
                          color: foreground,
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

/// Everything the conversion sheet renders that only the expense editor knows,
/// read fresh on every rebuild.
@immutable
class ConversionSheetData {
  const ConversionSheetData({
    required this.enteredTotal,
    required this.convertedTotal,
    required this.baseRate,
    required this.prefilledRateDate,
    required this.rateUnavailable,
    required this.cardFeePercent,
    required this.hasSavedRate,
  });

  /// The expense total in the ENTRY currency.
  final double enteredTotal;

  /// The same total in the GROUP currency; null while there is no usable rate.
  final double? convertedTotal;

  /// The rate as the source quoted it, before the fee. Non-null only while the
  /// field holds a FETCHED rate.
  final double? baseRate;

  /// `yyyy-MM-dd` the fetched rate is effective for.
  final String? prefilledRateDate;

  final bool rateUnavailable;

  /// The saved card fee, or null. Non-null AND [baseRate] non-null is exactly
  /// the state in which a fee was applied.
  final double? cardFeePercent;

  /// Whether a sticky rate is remembered for this group and currency — the
  /// condition on "Clear saved rate".
  final bool hasSavedRate;
}

/// Opens the conversion sheet: the conversion stated, the rate field, the
/// source line, the card-fee row, "Clear saved rate" and Done.
///
/// This is where the rate field lives now. It was on the editor's main screen,
/// where the currency/rate block already ran to two cards and three tap
/// targets; the fee could not become a fourth.
///
/// [data] is a getter, not a value: the sheet is a separate route and re-reads
/// the editor's state on every rebuild, driven by [rateState].
Future<void> showConversionSheet(
  BuildContext context, {
  required Currency entryCurrency,
  required Currency groupCurrency,
  required TextEditingController rateController,
  required Listenable rateState,
  required ConversionSheetData Function() data,
  required VoidCallback onRateTyped,
  required VoidCallback onClearSavedRate,
  required VoidCallback onEditCardFee,
}) => _showSheet<void>(
  context,
  ConversionSheet(
    entryCurrency: entryCurrency,
    groupCurrency: groupCurrency,
    rateController: rateController,
    rateState: rateState,
    data: data,
    onRateTyped: onRateTyped,
    onClearSavedRate: onClearSavedRate,
    onEditCardFee: onEditCardFee,
  ),
);

/// The conversion sheet body. Provider-free by construction: everything
/// Riverpod-shaped arrives through [data] or a callback, which is what keeps
/// this file free of `provider.dart`.
class ConversionSheet extends StatelessWidget {
  const ConversionSheet({
    super.key,
    required this.entryCurrency,
    required this.groupCurrency,
    required this.rateController,
    required this.rateState,
    required this.data,
    required this.onRateTyped,
    required this.onClearSavedRate,
    required this.onEditCardFee,
  });

  final Currency entryCurrency;
  final Currency groupCurrency;
  final TextEditingController rateController;

  /// Ticks whenever anything this sheet renders changes: a rate landing from a
  /// fetch, a fee change, a cleared sticky rate.
  final Listenable rateState;

  final ConversionSheetData Function() data;
  final VoidCallback onRateTyped;
  final VoidCallback onClearSavedRate;
  final VoidCallback onEditCardFee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return ListenableBuilder(
      listenable: rateState,
      builder: (context, _) {
        final d = data();
        final rate = parseConversionRate(rateController.text);

        return SheetScaffold(
          title: l10n.expenseConversionSheetTitle,
          footer: PrimaryButton(
            key: const ValueKey('expense_conversion_done'),
            label: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. The conversion, stated.
              SoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderRadius: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        key: const ValueKey('expense_conversion_entered'),
                        formatMoney(d.enteredTotal, entryCurrency, locale),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (d.convertedTotal != null)
                      Text(
                        key: const ValueKey('expense_rate_preview'),
                        l10n.expenseRatePreview(
                          formatMoney(d.convertedTotal!, groupCurrency, locale),
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 2. The rate field — moved here verbatim from the editor.
              SoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                borderRadius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const ValueKey('expense_rate_field'),
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      // Twelve, not six, and it has to match what [formatRate]
                      // can render: a rate is a multiplier, so a small one
                      // needs decimals to carry its significant digits. The
                      // smallest pair the app can produce — IDR into GBP — is
                      // 0.0000494306, which needs ten. Capping at six would
                      // round a fetched rate away the moment the user touched
                      // the field, which is the same 0.87% error formatRate was
                      // fixed to stop.
                      inputFormatters: [
                        DecimalTextInputFormatter(decimalRange: 12),
                      ],
                      onChanged: (_) => onRateTyped(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        labelText: l10n.expenseRateFieldLabel,
                        // InputDecorator fades prefix and suffix out whenever
                        // the label is inline — i.e. on an empty, unfocused
                        // field, which is precisely the FIRST foreign expense
                        // in a group, where nothing is remembered yet and the
                        // user has no way to know which way round to type the
                        // rate.
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        // The field reads as a sentence — "1 CHF = [0.9432]
                        // EUR" — so the direction is never ambiguous.
                        prefixText:
                            '${l10n.expenseRatePrefix(entryCurrency.code)} ',
                        suffixText: ' ${groupCurrency.code}',
                        // No rate => the hint, never a "= EUR 0.00" preview.
                        helperText: rate == null
                            ? l10n.expenseRateRequired
                            : null,
                        helperMaxLines: 3,
                      ),
                    ),
                    // 3. The prefill-date line, or the unavailable line.
                    if (d.prefilledRateDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          key: const ValueKey('expense_rate_prefill_date'),
                          // The user sees which day the rate belongs to BEFORE
                          // it is frozen on the row — a Saturday expense
                          // carries Friday's rate, and that is a fact about the
                          // rate, not a rounding error.
                          l10n.expenseRatePrefilledOn(
                            formatDate(d.prefilledRateDate, context),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (d.rateUnavailable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          key: const ValueKey('expense_rate_unavailable'),
                          l10n.expenseRateUnavailable,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 4. The source line: both numbers on screen, so the user can see
              // the percent between them. With no fee the base and the
              // effective rate are the same number and this would be pure
              // duplication of the prefill-date line.
              if (d.baseRate != null && d.cardFeePercent != null) ...[
                const SizedBox(height: 8),
                Text(
                  key: const ValueKey('expense_conversion_source'),
                  l10n.expenseConversionSourceLine(
                    formatDate(d.prefilledRateDate, context),
                    formatRate(d.baseRate!),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // 5. The card-fee row.
              SoftCard(
                key: const ValueKey('expense_conversion_fee_row'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                borderRadius: 16,
                onTap: onEditCardFee,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.cardFeeSheetTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      d.cardFeePercent == null
                          ? l10n.settingsCardFeeNone
                          : l10n.cardFeePercentValue(
                              formatPercentValue(d.cardFeePercent!, locale),
                            ),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 6. The honesty copy. Load-bearing: card networks convert at
              // their own wholesale rate and then add the fee, so this must not
              // imply it reconciles a statement.
              Text(
                l10n.cardFeeSheetHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // 7. Clearing the REMEMBERED rate, so it only exists once one is
              // remembered — never as a companion to an empty field.
              if (d.hasSavedRate)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('expense_rate_reset'),
                    onPressed: onClearSavedRate,
                    child: Text(l10n.expenseRateReset),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
