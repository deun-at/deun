import 'helper.dart';

/// Current exchange rates relative to a [base] currency, in the shape the
/// frankfurter.app / ECB "latest" endpoint returns: each entry in [rates] is
/// how many units of the keyed currency equal one unit of [base]. The base
/// currency itself is implicitly 1 and is not required to appear in [rates].
///
/// Display-only: these rates are used to convert cross-group aggregates into
/// the user's home currency. They never touch the stored ledger (expenses are
/// always entered and kept in their group's own currency).
class ExchangeRates {
  const ExchangeRates({required this.base, required this.rates});

  /// ISO 4217 code the [rates] are expressed against.
  final String base;

  /// `currencyCode -> units of that currency per 1 [base]`.
  final Map<String, double> rates;

  /// Multiplier that converts one unit of [from] into [to], or `null` when
  /// either currency has no known rate (so the caller must exclude it).
  double? conversionRate(String from, String to) {
    if (from == to) return 1;
    final fromPerBase = from == base ? 1.0 : rates[from];
    final toPerBase = to == base ? 1.0 : rates[to];
    if (fromPerBase == null || toPerBase == null) return null;
    return toPerBase / fromPerBase;
  }

  /// Parses the frankfurter.app / ECB `latest` payload
  /// (`{"base":"EUR","rates":{"USD":1.08,...}}`).
  factory ExchangeRates.fromApiJson(Map<String, dynamic> json) {
    final rawRates = (json['rates'] as Map?) ?? const {};
    return ExchangeRates(
      base: (json['base'] as String?) ?? kDefaultCurrencyCode,
      rates: {
        for (final entry in rawRates.entries)
          entry.key as String: (entry.value as num).toDouble(),
      },
    );
  }

  /// Serializable form used for the last-known-rates cache. Round-trips with
  /// [ExchangeRates.fromApiJson].
  Map<String, dynamic> toCacheJson() => {'base': base, 'rates': rates};
}

/// One group's contribution to a cross-group aggregate: an [amount] expressed
/// in [currencyCode].
class CurrencyAmount {
  const CurrencyAmount(this.amount, this.currencyCode);

  final double amount;
  final String currencyCode;
}

/// The result of converting mixed-currency contributions into a home currency.
class ConvertedTotal {
  const ConvertedTotal({
    required this.amount,
    required this.approximate,
    required this.excludedCount,
  });

  /// Sum, in the home currency, of every convertible contribution.
  final double amount;

  /// True when at least one contribution was in a foreign currency and had to
  /// be converted, so the total is an estimate (mark it with "≈"). False when
  /// every counted contribution was already in the home currency (exact).
  final bool approximate;

  /// Number of foreign contributions dropped because no rate was available.
  final int excludedCount;
}

/// Converts [amount] from [fromCurrency] into [homeCurrency]. Home-currency
/// amounts pass through untouched (no rates needed); foreign amounts are
/// converted with [rates]. Returns `null` when the amount is foreign and no
/// rate is available (offline with no cache, or an unsupported currency) — the
/// caller should then exclude it.
double? convertToHome(
  double amount,
  String fromCurrency,
  String homeCurrency,
  ExchangeRates? rates,
) {
  if (fromCurrency == homeCurrency) return amount;
  final rate = rates?.conversionRate(fromCurrency, homeCurrency);
  if (rate == null) return null;
  return roundCurrency(amount * rate, Currency.fromCode(homeCurrency));
}

/// Converts every entry in [contributions] into [homeCurrency] and sums them,
/// reporting whether the total is approximate and how many contributions were
/// excluded for lack of a rate. When rates are missing entirely the result
/// falls back to the home-currency contributions only (others excluded).
ConvertedTotal convertAndSum(
  Iterable<CurrencyAmount> contributions,
  String homeCurrency,
  ExchangeRates? rates,
) {
  double total = 0;
  bool approximate = false;
  int excluded = 0;
  for (final c in contributions) {
    final converted = convertToHome(
      c.amount,
      c.currencyCode,
      homeCurrency,
      rates,
    );
    if (converted == null) {
      excluded++;
      continue;
    }
    total = roundCurrency(total + converted, Currency.fromCode(homeCurrency));
    if (c.currencyCode != homeCurrency) approximate = true;
  }
  return ConvertedTotal(
    amount: total,
    approximate: approximate,
    excludedCount: excluded,
  );
}
