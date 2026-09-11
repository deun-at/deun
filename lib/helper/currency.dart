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
    required this.symbol,
    required this.decimalDigits,
  });

  /// ISO 4217 alphabetic code, e.g. "EUR".
  final String code;

  /// Display symbol, e.g. "€". Identical in every locale the app supports, so
  /// it is safe to hold as a constant rather than resolve per-locale (verified
  /// against `NumberFormat.simpleCurrency().currencySymbol` for `en` and `de`).
  final String symbol;

  /// Fractional digits of the minor unit: 2 for EUR, 0 for JPY.
  final int decimalDigits;

  /// The smallest representable amount: 0.01 for a 2-decimal currency, 1 for a
  /// 0-decimal one.
  double get minorUnit => 1 / math.pow(10, decimalDigits);

  /// Half a minor unit — below this an amount rounds to zero at this currency's
  /// precision, which is exactly what "settled" means. See [isSettled].
  double get settledEpsilon => minorUnit / 2;

  /// How this currency names itself in a picker or a selected-value row:
  /// "EUR · €", "USD · $" — but "CHF", not "CHF · CHF".
  ///
  /// Two of the supported currencies (CHF, RON) use their own code as their
  /// symbol, so pairing the halves unconditionally renders the code twice. The
  /// pairing exists to disambiguate a symbol that several currencies share
  /// ($ covers seven of them); when the symbol IS the code there is nothing
  /// left to disambiguate.
  String get pickerLabel => code == symbol ? code : '$code · $symbol';

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
    symbol: '€',
    decimalDigits: 2,
  );
  static const Currency usd = Currency(
    code: 'USD',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency jpy = Currency(
    code: 'JPY',
    symbol: '¥',
    decimalDigits: 0,
  );
  static const Currency bgn = Currency(
    code: 'BGN',
    symbol: 'lev',
    decimalDigits: 2,
  );
  static const Currency czk = Currency(
    code: 'CZK',
    symbol: 'Kč',
    decimalDigits: 2,
  );
  static const Currency dkk = Currency(
    code: 'DKK',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency gbp = Currency(
    code: 'GBP',
    symbol: '£',
    decimalDigits: 2,
  );
  static const Currency huf = Currency(
    code: 'HUF',
    symbol: 'Ft',
    decimalDigits: 2,
  );
  static const Currency pln = Currency(
    code: 'PLN',
    symbol: 'zł',
    decimalDigits: 2,
  );
  static const Currency ron = Currency(
    code: 'RON',
    symbol: 'RON',
    decimalDigits: 2,
  );
  static const Currency sek = Currency(
    code: 'SEK',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency chf = Currency(
    code: 'CHF',
    symbol: 'CHF',
    decimalDigits: 2,
  );
  static const Currency isk = Currency(
    code: 'ISK',
    symbol: 'kr',
    decimalDigits: 0,
  );
  static const Currency nok = Currency(
    code: 'NOK',
    symbol: 'kr',
    decimalDigits: 2,
  );

  /// Named `tryLira` because `try` is a Dart keyword.
  static const Currency tryLira = Currency(
    code: 'TRY',
    symbol: 'TL',
    decimalDigits: 2,
  );
  static const Currency aud = Currency(
    code: 'AUD',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency brl = Currency(
    code: 'BRL',
    symbol: r'R$',
    decimalDigits: 2,
  );
  static const Currency cad = Currency(
    code: 'CAD',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency cny = Currency(
    code: 'CNY',
    symbol: '¥',
    decimalDigits: 2,
  );
  static const Currency hkd = Currency(
    code: 'HKD',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency idr = Currency(
    code: 'IDR',
    symbol: 'Rp',
    decimalDigits: 2,
  );
  static const Currency ils = Currency(
    code: 'ILS',
    symbol: '₪',
    decimalDigits: 2,
  );
  static const Currency inr = Currency(
    code: 'INR',
    symbol: '₹',
    decimalDigits: 2,
  );
  static const Currency krw = Currency(
    code: 'KRW',
    symbol: '₩',
    decimalDigits: 0,
  );
  static const Currency mxn = Currency(
    code: 'MXN',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency myr = Currency(
    code: 'MYR',
    symbol: 'RM',
    decimalDigits: 2,
  );
  static const Currency nzd = Currency(
    code: 'NZD',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency php = Currency(
    code: 'PHP',
    symbol: '₱',
    decimalDigits: 2,
  );
  static const Currency sgd = Currency(
    code: 'SGD',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency thb = Currency(
    code: 'THB',
    symbol: '฿',
    decimalDigits: 2,
  );
  static const Currency zar = Currency(
    code: 'ZAR',
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
