import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../widgets/restyle/stepper_control.dart';
import '../../data/item_icon.dart';

/// F117 item row: leading auto-icon tile, inline-editable name +
/// "€ [price] each", line total right; bottom row = trash left, qty
/// stepper right. Wraps the same FormBuilderFields (name / amount /
/// quantity) so saving, the itemized total, and the claim explosion
/// (F118/F146) stay wired to unchanged state.
///
/// BUG D: renders as a FLAT row (no own SoftCard) — the parent joins all item
/// rows inside ONE SoftCard, so wrapping here too produced a card-in-card.
class ExpenseEntryItemRow extends StatelessWidget {
  const ExpenseEntryItemRow({
    super.key,
    required this.index,
    required this.currency,
    required this.itemName,
    required this.initialName,
    required this.initialAmountText,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.onRemove,
    required this.onNameChanged,
    required this.onUnitPriceChanged,
    required this.onUnitPriceTap,
    required this.onQuantityChanged,
  });

  final int index;
  final Currency currency;

  /// The live item name the leading auto-icon follows (F117).
  final String itemName;

  /// The name field's initial value (HEAD: `widget.initialName`).
  final String? initialName;

  /// The amount field's initial value (HEAD: `widget.initialAmount ??
  /// (shares.isNotEmpty ? _seedAmountText(entry) : null)`, computed by the State).
  final String? initialAmountText;
  final double unitPrice;
  final int quantity;

  /// Unit price × quantity.
  final double lineTotal;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<dynamic> onUnitPriceChanged;
  final Future<void> Function(FormFieldState<dynamic> field) onUnitPriceTap;
  final ValueChanged<dynamic> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading auto-icon tile (iconForItemName, F116) in a small
              // rounded tinted square.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  iconForItemName(itemName),
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              // Name (inline field) + "€ [price] each" (inline field).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(context, l10n),
                    const SizedBox(height: 3),
                    _buildUnitPriceField(context, l10n),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Line total (price × qty), right-aligned.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.toCurrency(lineTotal, currency.code),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom row: trash left, qty stepper right.
          Row(
            children: [
              IconButton(
                onPressed: () => onRemove(),
                icon: const Icon(Icons.delete_outline),
                color: Theme.of(context).extension<SemanticColors>()!.danger,
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
              const Spacer(),
              _buildQuantityStepper(l10n),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(BuildContext context, AppLocalizations l10n) {
    return FormBuilderField(
      key: ValueKey("${index}_name"),
      name: "expense_entry[$index][name]",
      initialValue: initialName,
      builder: (FormFieldState<dynamic> field) => TextFormField(
        initialValue: field.value,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.itemNameHint,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (value) {
          field.didChange(value);
          onNameChanged(value);
        },
      ),
    );
  }

  Widget _buildUnitPriceField(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return FormBuilderField(
      key: ValueKey("${index}_amount"),
      name: "expense_entry[$index][amount]",
      initialValue: initialAmountText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: onUnitPriceChanged,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(
          errorText: l10n.expenseEntryAmountValidationEmpty,
        ),
        (value) {
          final amount = double.tryParse(value?.toString() ?? '');
          // Negative lines are legal: receipt discounts ("Aktion", deposit
          // returns) come through the scanner as -0.80 etc. Only the expense
          // total has to stay positive — guarded in ExpenseDetail._saveExpense.
          if (amount != null && amount == 0) {
            return l10n.expenseEntryAmountValidationNonZero;
          }
          return null;
        },
      ]),
      builder: (FormFieldState<dynamic> field) {
        return InputDecorator(
          decoration: InputDecoration(
            errorText: field.errorText,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currency.code,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              // Tap-to-open keypad (F158): the unit price is money, so it routes
              // through showAmountKeypadSheet like the quick-split amount, not a
              // raw system-keyboard field. Tinted pill reads as editable.
              InkWell(
                onTap: () => onUnitPriceTap(field),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40, maxWidth: 90),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formatAmountOnly(
                      unitPrice,
                      currency,
                      Localizations.localeOf(context),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.itemPriceEachSuffix,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuantityStepper(AppLocalizations l10n) {
    return FormBuilderField(
      key: ValueKey("${index}_quantity"),
      name: "expense_entry[$index][quantity]",
      initialValue: quantity.toString(),
      onChanged: onQuantityChanged,
      builder: (FormFieldState<dynamic> qtyField) {
        void updateQty(int newQty) {
          if (newQty < 1) newQty = 1;
          qtyField.didChange(newQty.toString());
        }

        return StepperControl(
          value: l10n.itemQtyStepperValue(quantity),
          canDecrement: quantity > 1,
          onDecrement: () => updateQty(quantity - 1),
          onIncrement: () => updateQty(quantity + 1),
        );
      },
    );
  }
}
