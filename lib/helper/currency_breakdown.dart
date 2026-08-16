import 'package:flutter/widgets.dart' show Locale;

import 'helper.dart';

/// One contribution to a cross-group aggregate: an [amount] in [currency].
///
/// Replaces the conversion-era `CurrencyAmount(amount, currencyCode)`: the
/// currency is the value object, not a loose code, so decimal digits travel
/// with every figure and nothing has to re-resolve a string.
class CurrencyAmount {
  const CurrencyAmount(this.currency, this.amount);

  final Currency currency;
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is CurrencyAmount &&
      other.currency == currency &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(currency, amount);

  @override
  String toString() => 'CurrencyAmount(${currency.code}, $amount)';
}

/// "Primary inline, remainder collapsed" — the ONE shape all three cross-group
/// surfaces render (overall balance hero, friend balances, personal statistics),
/// so the disclosure rule is decided once rather than three times.
class CurrencyBreakdown {
  const CurrencyBreakdown({required this.primary, this.others = const []});

  /// The currency with the largest absolute amount, rendered inline.
  final CurrencyAmount primary;

  /// Every remaining currency, ordered the same way, hidden behind the
  /// disclosure.
  final List<CurrencyAmount> others;

  /// How many currencies the disclosure hides. Never rendered when 0 — a
  /// disclosure with a count of zero must not exist.
  int get hiddenCount => others.length;

  /// True when there is nothing to disclose, which is the only case production
  /// is in today. Every surface must render exactly as it did before in this
  /// case.
  bool get isSingleCurrency => others.isEmpty;

  /// Primary first, then the remainder — the selector order.
  List<CurrencyAmount> get all => [primary, ...others];

  /// No contributions at all: zero, in EUR, single-currency.
  static const CurrencyBreakdown empty = CurrencyBreakdown(
    primary: CurrencyAmount(Currency.eur, 0),
  );

  @override
  bool operator ==(Object other) {
    if (other is! CurrencyBreakdown) return false;
    if (other.primary != primary) return false;
    if (other.others.length != others.length) return false;
    for (var i = 0; i < others.length; i++) {
      if (other.others[i] != others[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(primary, Object.hashAll(others));

  @override
  String toString() => 'CurrencyBreakdown($primary, others: $others)';
}

/// Sums [contributions] per currency and orders them primary-first: largest
/// absolute amount, ties broken by ISO code ascending so the order is
/// deterministic rather than dependent on map iteration order — which is what
/// makes it testable.
///
/// Each per-currency net is rounded at its OWN currency's precision and, when
/// [dropSettled], dropped when [isSettled] in that currency, so a ¥0.4 residue
/// never surfaces as a second currency and no figure is ever the sum of two
/// currencies.
///
/// [dropSettled] is right for *balances* — a settled currency is not a debt and
/// must not occupy a disclosure row. It is wrong for *spending* totals, where a
/// currency the user only ever paid in nets a ~0 share and would vanish from the
/// selector, taking its "you paid" figure and its trend series with it. Pass
/// `false` there so the fold keeps every currency it was handed.
List<CurrencyAmount> sumByCurrency(
  Iterable<CurrencyAmount> contributions, {
  bool dropSettled = true,
}) {
  final totals = <Currency, double>{};
  for (final c in contributions) {
    totals[c.currency] = (totals[c.currency] ?? 0) + c.amount;
  }
  final entries = <CurrencyAmount>[];
  for (final entry in totals.entries) {
    final rounded = roundCurrency(entry.value, entry.key);
    if (dropSettled && isSettled(rounded, entry.key)) continue;
    entries.add(CurrencyAmount(entry.key, rounded));
  }
  entries.sort((a, b) {
    final byMagnitude = b.amount.abs().compareTo(a.amount.abs());
    if (byMagnitude != 0) return byMagnitude;
    return a.currency.code.compareTo(b.currency.code);
  });
  return entries;
}

/// [sumByCurrency] split into the inline primary and the collapsed remainder.
///
/// When every currency nets to settled there is still a figure to render (a
/// zero), so the primary falls back to the ISO-lowest currency seen — the same
/// tiebreak used everywhere else — and the breakdown reports itself as
/// single-currency, because a "0 other currencies" disclosure must not appear.
///
/// [dropSettled] is forwarded to [sumByCurrency]: pass `false` for spending
/// totals so a currency whose net share rounds away still gets a row.
CurrencyBreakdown currencyBreakdownOf(
  Iterable<CurrencyAmount> contributions, {
  bool dropSettled = true,
}) {
  final summed = sumByCurrency(contributions, dropSettled: dropSettled);
  if (summed.isNotEmpty) {
    return CurrencyBreakdown(primary: summed.first, others: summed.sublist(1));
  }
  final codes = {for (final c in contributions) c.currency.code}.toList()
    ..sort();
  if (codes.isEmpty) return CurrencyBreakdown.empty;
  return CurrencyBreakdown(
    primary: CurrencyAmount(Currency.fromCode(codes.first), 0),
  );
}

/// "€10.00 + ¥3,000" — every amount in its own currency, joined. Used where a
/// confirmation must name what was actually settled instead of one merged
/// figure. A single-currency list produces exactly [formatMoney]'s output, so
/// the common case reads identically to before.
String formatCurrencyAmounts(Iterable<CurrencyAmount> amounts, Locale locale) =>
    amounts.map((a) => formatMoney(a.amount, a.currency, locale)).join(' + ');
