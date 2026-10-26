import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../widgets/restyle/expense_picker_sheets.dart';

/// The Quick layout's expense-level amount: unboxed icon+amount sitting
/// directly on the page background, tap opens the keypad (F100), and a
/// per-person split preview sits directly below the amount.
class EditorQuickAmountSection extends StatelessWidget {
  const EditorQuickAmountSection({
    super.key,
    required this.screenContext,
    required this.firstIndex,
    required this.amountController,
    required this.currency,
    required this.memberCount,
    required this.onAmountChanged,
  });

  /// The screen's own context, above the group's `ThemeBuilder`: the amount's
  /// colours and the keypad it opens take the app's brand theme from here, not
  /// the group's. The auto-opened keypad of a new expense already uses it.
  final BuildContext screenContext;

  /// The first entry's index, which names the form field this amount is.
  final int firstIndex;
  final TextEditingController amountController;
  final Currency currency;
  final int memberCount;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField(
      key: ValueKey("expense_level_amount_$firstIndex"),
      name: "expense_entry[$firstIndex][amount]",
      initialValue: amountController.text != "0" ? amountController.text : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: AppLocalizations.of(
            context,
          )!.expenseEntryAmountValidationEmpty,
        ),
        (value) {
          final amount = double.tryParse(value?.toString() ?? '');
          if (amount != null && amount <= 0) {
            return AppLocalizations.of(
              context,
            )!.expenseEntryAmountValidationZero;
          }
          return null;
        },
      ]),
      builder: (FormFieldState<dynamic> field) {
        final theme = Theme.of(screenContext);
        final colorScheme = theme.colorScheme;
        final amountStyle = theme.textTheme.displayMedium?.copyWith(
          color: colorScheme.onSurface,
        );
        final amount = double.tryParse(amountController.text) ?? 0;
        final perHead = amount / (memberCount > 0 ? memberCount : 1);
        final l10n = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => openEditorAmountKeypad(
                screenContext,
                field: field,
                amountController: amountController,
                currency: currency,
                onAmountChanged: onAmountChanged,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    errorText: field.errorText,
                    errorMaxLines: 2,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currency.code,
                        style: amountStyle?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatAmountOnly(
                          amount,
                          currency,
                          Localizations.localeOf(context),
                        ),
                        textAlign: TextAlign.center,
                        style: amountStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.expenseSplitEach(l10n.toCurrency(perHead, currency.code)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Opens the restyled amount keypad sheet and, on confirm, writes the value
/// back through the same channels the inline editor used: the form [field]
/// (validated/saved) and the shared [amountController] (split-sync), then
/// [onAmountChanged] so the screen repaints. The written string keeps the
/// currency-precision field format (`amountToFieldText`), so the value
/// round-trips and validators are unchanged.
Future<void> openEditorAmountKeypad(
  BuildContext context, {
  required FormFieldState<dynamic> field,
  required TextEditingController amountController,
  required Currency currency,
  required VoidCallback onAmountChanged,
}) async {
  final picked = await showAmountKeypadSheet(
    context,
    initialAmount: double.tryParse(amountController.text) ?? 0,
    currency: currency,
  );
  if (picked == null || !context.mounted) return;
  final text = amountToFieldText(picked, currency);
  amountController.text = text;
  onAmountChanged();
  field.didChange(text);
}
