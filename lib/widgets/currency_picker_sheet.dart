import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';

/// Opens the shared currency picker and resolves to the chosen [Currency], or
/// null if the sheet was dismissed.
///
/// Extracted out of the group-edit form's private `_CurrencyField` binding so
/// it is reusable: multi-currency-expense-rate needs the same picker for an
/// expense's entry currency, where there is no `currency_code` form field to
/// bind to. It also inherits the shape of the retired home-currency sheet, which
/// this feature deletes.
Future<Currency?> showCurrencyPicker(
  BuildContext context, {
  Currency? initial,
}) => showModalBottomSheet<Currency>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  useSafeArea: true,
  sheetAnimationStyle: kSheetAnimationStyle,
  barrierColor: kSheetBarrierColor,
  builder: (_) => _CurrencyPickerSheet(initial: initial),
);

class _CurrencyPickerSheet extends StatelessWidget {
  const _CurrencyPickerSheet({this.initial});

  final Currency? initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return SheetScaffold(
      title: l10n.groupCurrencyLabel,
      body: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final c in kSupportedCurrencies)
              InkWell(
                onTap: () => Navigator.pop(context, c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.pickerLabel,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (c == initial)
                        Icon(Icons.check_circle, color: colorScheme.primary)
                      else
                        Icon(
                          Icons.circle_outlined,
                          color: colorScheme.outlineVariant,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
