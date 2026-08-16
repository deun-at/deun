import 'package:deun/helper/currency.dart';
import 'package:flutter/widgets.dart';

/// The ambient currency for money widgets that have no group in scope — balance
/// pills, keypad displays, statistics tiles, month sheets. It exists because
/// many [MoneyText] call sites genuinely cannot name a currency, which is why
/// the widget carried a hardcoded default before; this makes that default
/// inherited instead, so `multi-currency-group` can later re-mount the scope at
/// the group route boundary as a one-line change.
class CurrencyScope extends InheritedWidget {
  const CurrencyScope({
    super.key,
    required this.currency,
    required super.child,
  });

  final Currency currency;

  /// The ambient currency, or [Currency.eur] when no scope is mounted (widget
  /// tests, the pre-router login/onboarding apps). Never throws.
  static Currency of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.currency ??
      Currency.eur;

  @override
  bool updateShouldNotify(CurrencyScope oldWidget) =>
      oldWidget.currency != currency;
}
