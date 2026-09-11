import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:flutter/material.dart';

/// "Primary inline, remainder collapsed" — the single disclosure every
/// cross-group surface uses, so the rule is decided once.
///
/// Renders NOTHING when [breakdown] is single-currency: that is the only case
/// production is in today, and it must keep its exact layout and line count
/// with no expand affordance. Otherwise it renders one tappable label naming
/// how many currencies are hidden inline (never zero), and on expand one row per
/// currency, each an exact ledger value in its own currency at that currency's
/// decimal digits, each carrying its own direction and semantic colour.
///
/// The expanded/collapsed state is local [State] — it is view state, so it is
/// not persisted and does not survive an app launch.
///
/// When [onSelected] is non-null the disclosure doubles as a currency SWITCHER:
/// every row (the primary included, so the user can switch back) is tappable
/// and the [selected] one is marked. That is what the statistics trend chart
/// uses instead of a second control.
class CurrencyBreakdownDisclosure extends StatefulWidget {
  const CurrencyBreakdownDisclosure({
    super.key,
    required this.breakdown,
    required this.foreground,
    this.selected,
    this.onSelected,
  });

  final CurrencyBreakdown breakdown;

  /// Text colour for the disclosure label, so the widget reads correctly both
  /// on the ink hero and on a plain surface.
  final Color foreground;

  final Currency? selected;
  final ValueChanged<Currency>? onSelected;

  @override
  State<CurrencyBreakdownDisclosure> createState() =>
      _CurrencyBreakdownDisclosureState();
}

class _CurrencyBreakdownDisclosureState
    extends State<CurrencyBreakdownDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.breakdown.isSingleCurrency) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // In selector mode the primary is listed too, so the user can switch back
    // to it. The count stays `hiddenCount` in both modes — a two-currency user
    // must read "one hidden currency" — and selector mode says so with its own
    // wording, which names the action instead of promising a row count.
    final selecting = widget.onSelected != null;
    final rows = selecting ? widget.breakdown.all : widget.breakdown.others;
    final label = selecting
        ? l10n.currencyBreakdownSelect(widget.breakdown.hiddenCount)
        : l10n.currencyBreakdownMore(widget.breakdown.hiddenCount);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: widget.foreground,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(width: 2),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: widget.foreground,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final entry in rows)
            _BreakdownRow(
              entry: entry,
              foreground: widget.foreground,
              selected: widget.selected == entry.currency,
              onTap: widget.onSelected == null
                  ? null
                  : () => widget.onSelected!(entry.currency),
            ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.entry,
    required this.foreground,
    required this.selected,
    this.onTap,
  });

  final CurrencyAmount entry;
  final Color foreground;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // A currency whose symbol IS its code — CHF, RON — would otherwise
            // read "CHF  -CHF2.14". The amount already identifies it.
            if (entry.currency.code != entry.currency.symbol) ...[
              Text(
                entry.currency.code,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
            ],
            MoneyText(
              entry.amount,
              currency: entry.currency,
              semantic: MoneySemantic.auto,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
