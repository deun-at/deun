import 'dart:math' as math;

import 'currency.dart';

/// Rounds [value] to [currency]'s minor unit, to prevent floating-point drift.
/// Use at every arithmetic boundary where money is computed.
///
/// The [Currency] is required on purpose: a compile error at every call site is
/// the cheapest way to guarantee none keeps the old hardcoded 2 decimals.
double roundCurrency(double value, Currency currency) {
  final factor = math.pow(10, currency.decimalDigits).toDouble();
  return (value * factor).roundToDouble() / factor;
}

/// The ledger value of [amount] (expressed in some other currency) converted at
/// [rate] into [target], rounded to [target]'s own minor unit.
///
/// The single conversion primitive of this feature: 3000 JPY at 0.0058 into a
/// EUR group is 17.40; 20 EUR at 172 into a JPY group is 3440 with no
/// fractional part. Conversion happens ONCE, at entry, client-side — the stored
/// value is an ordinary group-currency amount and nothing downstream of the
/// write knows a conversion happened.
double convertToGroupCurrency(double amount, double rate, Currency target) =>
    roundCurrency(amount * rate, target);

/// Splits [total] into [parts] amounts in [currency] that sum to EXACTLY
/// [total], spreading the indivisible remainder one minor unit at a time over
/// the leading parts.
///
/// The settle-residue invariant: parts sum to the whole. Converting a
/// multi-quantity line per unit instead would disagree with the preview and the
/// notification — 3 x 10.00 CHF at 0.9432 is 28.30 as a line, but 3 x 9.43 =
/// 28.29 per unit. Here the line converts once and this distributes the result
/// as 9.44 / 9.43 / 9.43.
///
/// Floor division, not truncation, so a negative total (a discount line) also
/// sums back exactly: -7 minor units over 3 parts is -3/-2/-2, not -2/-2/-1.
List<double> distributeCurrency(double total, int parts, Currency currency) {
  if (parts <= 1) return [roundCurrency(total, currency)];
  final unit = currency.minorUnit;
  final units = (roundCurrency(total, currency) / unit).round();
  final base = (units / parts).floor();
  final remainder = units - base * parts;
  return [
    for (var i = 0; i < parts; i++)
      roundCurrency((base + (i < remainder ? 1 : 0)) * unit, currency),
  ];
}

/// Rounds every value in [values] to a whole minor unit of [currency] so the
/// results sum to EXACTLY [total], handing the indivisible units to the values
/// that discarded the most in rounding (largest remainder).
///
/// [distributeCurrency] is the equal-parts case of this. This one takes a split
/// that is *already* uneven — percentages, shares, a manual split — and is what
/// keeps a per-member breakdown adding up to the expense it belongs to. Rounding
/// each share on its own instead is what made 100.01 across four members read
/// 25.00 four times, a cent short of the expense it was describing.
///
/// With an equal split *somebody* has to carry the spare cent, and it must be
/// the same somebody on every render. [priority] is served first among equals —
/// pass the payer, so the person already fronting the money absorbs the
/// rounding instead of whoever happens to sort first. Falling back to the key
/// would quietly tax the same member in every group they are in.
Map<K, double> apportionCurrency<K extends Comparable>(
  Map<K, double> values,
  double total,
  Currency currency, {
  K? priority,
}) {
  if (values.isEmpty) return <K, double>{};
  final unit = currency.minorUnit;
  // Nudge past float error (25.00 / 0.01 can land on 2499.999…) before flooring.
  const epsilon = 1e-9;

  final keys = values.keys.toList()..sort();
  final units = <K, int>{};
  final fractions = <K, double>{};
  var assigned = 0;
  for (final key in keys) {
    final exact = (values[key] ?? 0) / unit + epsilon;
    final floored = exact.floor();
    units[key] = floored;
    fractions[key] = exact - floored;
    assigned += floored;
  }

  final order = [...keys]
    ..sort((a, b) {
      // Largest discarded fraction first — that part is the apportionment
      // itself and [priority] never overrides it. Only a tie is the payer's to
      // win, which in an equal split is every time.
      final byFraction = fractions[b]!.compareTo(fractions[a]!);
      if (byFraction != 0) return byFraction;
      if (a == priority) return -1;
      if (b == priority) return 1;
      return a.compareTo(b);
    });

  // Round-robin so the sum is exact even if the values never summed to [total].
  var leftover = (roundCurrency(total, currency) / unit).round() - assigned;
  for (var i = 0; leftover > 0; i++, leftover--) {
    final key = order[i % order.length];
    units[key] = units[key]! + 1;
  }
  for (var i = 0; leftover < 0; i++, leftover++) {
    final key = order[order.length - 1 - (i % order.length)];
    units[key] = units[key]! - 1;
  }

  return {
    for (final key in keys) key: roundCurrency(units[key]! * unit, currency),
  };
}

/// [baseRate] with the card's foreign-transaction fee folded in.
///
/// Pure and total: a null, zero or non-finite [feePercent] returns [baseRate]
/// untouched, so "no fee saved" and "a fee of 0" are one code path.
///
/// Applied to the RAW rate, before [formatRate] renders it: [formatRate] keeps
/// significant digits rather than six decimals, so multiplying an
/// already-rendered rate would round twice.
double applyCardFee(double baseRate, double? feePercent) {
  final fee = feePercent;
  if (fee == null || !fee.isFinite || fee == 0) return baseRate;
  return baseRate * (1 + fee / 100);
}

/// Thrown when an expense entered in a currency other than its group's is saved
/// with no explicit rate. There is no 1:1 fallback and no silent substitution —
/// a silent 1:1 is a confirmed, repeated failure in shipped competitors and
/// destroys trust in every number in the group.
class MissingConversionRateException implements Exception {
  const MissingConversionRateException(this.from, this.to);

  final Currency from;
  final Currency to;

  @override
  String toString() =>
      'MissingConversionRateException: no rate supplied for '
      '${from.code} -> ${to.code}';
}

/// EUR's half-minor-unit, and the SMALLEST settled epsilon in
/// [kSupportedCurrencies]. Kept as a top-level constant for the server-side
/// predicates that cannot take a [Currency]: `GroupRepository.fetchData` filters
/// `total_share_amount` on a referenced table for groups of mixed currencies, so
/// no single currency is knowable inside the query. Those predicates bracket
/// with this and [kMaxSettledEpsilon] to return a SUPERSET, and
/// `GroupRepository.narrowToStatus` then applies [isSettled] per row. It must
/// stay equal to `Currency.eur.settledEpsilon`; `helper_test.dart` pins that.
const double kSettledEpsilon = 0.005;

/// The LARGEST settled epsilon in [kSupportedCurrencies] — half a unit of the
/// 0-decimal currencies (JPY/ISK/KRW), i.e. 0.5. The counterpart bound to
/// [kSettledEpsilon]: a server-side "settled" predicate must use this wider
/// value so a ¥0.3 balance (which renders as ¥0) is not excluded from the
/// settled side before the client can judge it in its own currency.
final double kMaxSettledEpsilon = kSupportedCurrencies
    .map((c) => c.settledEpsilon)
    .reduce(math.max);

/// Whether [amount] counts as a settled balance in [currency]: true below half
/// a minor unit, i.e. exactly when the amount renders as zero at that
/// currency's precision. THE settled/outstanding decision in the app — the
/// payment screen, the group-detail hero, the group-list hero, the group cards,
/// the friend list and the member-removal guard all route through here, so a
/// balance can never read settled on one screen and outstanding on another.
bool isSettled(double amount, Currency currency) =>
    amount.abs() < currency.settledEpsilon;

/// App-wide default group currency (ISO 4217). New groups default to this and
/// any amount rendered without an explicit group currency falls back to it.
const String kDefaultCurrencyCode = 'EUR';
