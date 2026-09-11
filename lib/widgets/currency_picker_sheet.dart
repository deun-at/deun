import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';

/// Opens the shared currency picker and resolves to the chosen [Currency], or
/// null if the sheet was dismissed.
///
/// One picker for every currency decision in the app: a group's currency, and
/// an expense's entry currency.
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

/// The picker body: a search field over a two-lane list of every supported
/// currency.
///
/// Two lanes because there are two ways to know a currency, and the list is 31
/// long: the ISO code in a fixed-width lane on the left for someone who knows
/// "CHF", the name beside it for someone who only knows "Swiss Franc". The
/// fixed lane is what makes the list scannable — codes are all three characters,
/// so they form a clean column to run an eye down, which a code-plus-symbol
/// label of varying width never did.
class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({this.initial});

  final Currency? initial;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final matches = kSupportedCurrencies
        .where((c) => c.matches(_query))
        .toList();

    return SheetScaffold(
      title: l10n.groupCurrencyLabel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('currency_picker_search'),
            controller: _searchController,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: l10n.currencyPickerSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              // The clear affordance only exists once there is something to
              // clear, so the field is quiet at rest.
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('currency_picker_search_clear'),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            Padding(
              key: const ValueKey('currency_picker_empty'),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                l10n.currencyPickerNoMatches(_query.trim()),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final c in matches)
                    _CurrencyRow(
                      currency: c,
                      selected: c == widget.initial,
                      onTap: () => Navigator.pop(context, c),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One currency: code lane, name, and a check when it is the current choice.
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                currency.code,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(
                currency.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Only the chosen one is marked. The empty radio on all 30 others
            // was 30 pieces of furniture saying nothing.
            if (selected)
              Icon(Icons.check, size: 20, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
