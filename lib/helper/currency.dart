import 'dart:math' as math;

/// An ISO 4217 currency: its code, its display symbol, and — the reason this
/// type exists at all — how many fractional digits its minor unit has.
///
/// Every amount in the app is rounded, formatted and entered against one of
/// these instead of an implicit 2-decimal EUR. Money itself stays a Dart
/// `double`; only the exponent becomes explicit.
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalDigits,
  });

  /// ISO 4217 alphabetic code, e.g. "EUR".
  final String code;

  /// The currency's English name, e.g. "Swiss Franc".
  ///
  /// Not localized: these are proper nouns of the ISO 4217 register, they are
  /// the strings people search for, and translating 31 of them into every
  /// locale is a maintenance burden with no payoff. The code is what identifies
  /// the currency; this only helps someone who knows "Swiss Franc" but not
  /// "CHF" find it.
  final String name;

  /// Display symbol, e.g. "€".
  ///
  /// **Never rendered.** No amount anywhere in the app carries a symbol — see
  /// `formatMoney`. This is kept only as reference data on the registry, since
  /// deleting it loses information that is genuinely about the currency.
  final String symbol;

  /// Fractional digits of the minor unit: 2 for EUR, 0 for JPY.
  final int decimalDigits;

  /// The smallest representable amount: 0.01 for a 2-decimal currency, 1 for a
  /// 0-decimal one.
  double get minorUnit => 1 / math.pow(10, decimalDigits);

  /// Half a minor unit — below this an amount rounds to zero at this currency's
  /// precision, which is exactly what "settled" means. See [isSettled].
  double get settledEpsilon => minorUnit / 2;

  /// Whether this currency answers to [query] in the picker's search.
  ///
  /// Matches the code or the name, case-insensitively, on any substring: "fr"
  /// finds CHF (Swiss Franc), "dollar" finds all six, "chf" finds one. An empty
  /// or whitespace-only query matches everything, so clearing the field restores
  /// the full list rather than emptying it.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return code.toLowerCase().contains(q) || name.toLowerCase().contains(q);
  }

  /// Resolves an ISO code to a supported [Currency], falling back to [eur] for
  /// null, empty or unknown codes rather than throwing. Legacy rows, a hand-
  /// edited preference and a future server value all land on EUR instead of
  /// crashing a list fetch.
  static Currency fromCode(String? code) => _byCode[code] ?? eur;

  static final Map<String, Currency> _byCode = {
    for (final c in kSupportedCurrencies) c.code: c,
  };

  // ---- The ECB / Frankfurter reference set (EUR + the 30 ECB quotes). ------
  // Pinned to the rate source's coverage so every currency the user can pick is
  // one multi-currency-rate-source can later quote a rate for.
  static const Currency eur = Currency(
    code: 'EUR',
    name: 'Euro',
    symbol: '€',
    decimalDigits: 2,
  );
  static const Currency usd = Currency(
    code: 'USD',
    name: 'US Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency jpy = Currency(
    code: 'JPY',
    name: 'Japanese Yen',
    symbol: '¥',
    decimalDigits: 0,
  );
  static const Currency bgn = Currency(
    code: 'BGN',
    name: 'Bulgarian Lev',
    symbol: 'lev',
    decimalDigits: 2,
  );
  static const Currency czk = Currency(
    code: 'CZK',
    name: 'Czech Koruna',
    symbol: 'Kč',
    decimalDigits: 2,
  );
  static const Currency dkk = Currency(
    code: 'DKK',
    name: 'Danish Krone',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency gbp = Currency(
    code: 'GBP',
    name: 'Pound Sterling',
    symbol: '£',
    decimalDigits: 2,
  );
  static const Currency huf = Currency(
    code: 'HUF',
    name: 'Hungarian Forint',
    symbol: 'Ft',
    decimalDigits: 2,
  );
  static const Currency pln = Currency(
    code: 'PLN',
    name: 'Polish Zloty',
    symbol: 'zł',
    decimalDigits: 2,
  );
  static const Currency ron = Currency(
    code: 'RON',
    name: 'Romanian Leu',
    symbol: 'RON',
    decimalDigits: 2,
  );
  static const Currency sek = Currency(
    code: 'SEK',
    name: 'Swedish Krona',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency chf = Currency(
    code: 'CHF',
    name: 'Swiss Franc',
    symbol: 'CHF',
    decimalDigits: 2,
  );
  static const Currency isk = Currency(
    code: 'ISK',
    name: 'Icelandic Krona',
    symbol: 'kr',
    decimalDigits: 0,
  );
  static const Currency nok = Currency(
    code: 'NOK',
    name: 'Norwegian Krone',
    symbol: 'kr',
    decimalDigits: 2,
  );

  /// Named `tryLira` because `try` is a Dart keyword.
  static const Currency tryLira = Currency(
    code: 'TRY',
    name: 'Turkish Lira',
    symbol: 'TL',
    decimalDigits: 2,
  );
  static const Currency aud = Currency(
    code: 'AUD',
    name: 'Australian Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency brl = Currency(
    code: 'BRL',
    name: 'Brazilian Real',
    symbol: r'R$',
    decimalDigits: 2,
  );
  static const Currency cad = Currency(
    code: 'CAD',
    name: 'Canadian Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency cny = Currency(
    code: 'CNY',
    name: 'Chinese Yuan',
    symbol: '¥',
    decimalDigits: 2,
  );
  static const Currency hkd = Currency(
    code: 'HKD',
    name: 'Hong Kong Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency idr = Currency(
    code: 'IDR',
    name: 'Indonesian Rupiah',
    symbol: 'Rp',
    decimalDigits: 2,
  );
  static const Currency ils = Currency(
    code: 'ILS',
    name: 'Israeli Shekel',
    symbol: '₪',
    decimalDigits: 2,
  );
  static const Currency inr = Currency(
    code: 'INR',
    name: 'Indian Rupee',
    symbol: '₹',
    decimalDigits: 2,
  );
  static const Currency krw = Currency(
    code: 'KRW',
    name: 'South Korean Won',
    symbol: '₩',
    decimalDigits: 0,
  );
  static const Currency mxn = Currency(
    code: 'MXN',
    name: 'Mexican Peso',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency myr = Currency(
    code: 'MYR',
    name: 'Malaysian Ringgit',
    symbol: 'RM',
    decimalDigits: 2,
  );
  static const Currency nzd = Currency(
    code: 'NZD',
    name: 'New Zealand Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency php = Currency(
    code: 'PHP',
    name: 'Philippine Peso',
    symbol: '₱',
    decimalDigits: 2,
  );
  static const Currency sgd = Currency(
    code: 'SGD',
    name: 'Singapore Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency thb = Currency(
    code: 'THB',
    name: 'Thai Baht',
    symbol: '฿',
    decimalDigits: 2,
  );
  static const Currency zar = Currency(
    code: 'ZAR',
    name: 'South African Rand',
    symbol: 'R',
    decimalDigits: 2,
  );

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Currency($code)';
}

/// The currencies offered in every picker, in ECB publication order (EUR, then
/// the majors, then alphabetical within the rest of the reference table).
///
/// Pinned to the ECB / Frankfurter reference set so every listed currency is one
/// `multi-currency-rate-source` can later quote — no picker entry is a dead end.
/// The set contains no 3-decimal currency (KWD/BHD/JOD are not ECB quotes);
/// [Currency] still handles a general exponent, the list simply exercises 0 and 2.
const List<Currency> kSupportedCurrencies = [
  Currency.eur,
  Currency.usd,
  Currency.jpy,
  Currency.bgn,
  Currency.czk,
  Currency.dkk,
  Currency.gbp,
  Currency.huf,
  Currency.pln,
  Currency.ron,
  Currency.sek,
  Currency.chf,
  Currency.isk,
  Currency.nok,
  Currency.tryLira,
  Currency.aud,
  Currency.brl,
  Currency.cad,
  Currency.cny,
  Currency.hkd,
  Currency.idr,
  Currency.ils,
  Currency.inr,
  Currency.krw,
  Currency.mxn,
  Currency.myr,
  Currency.nzd,
  Currency.php,
  Currency.sgd,
  Currency.thb,
  Currency.zar,
];
