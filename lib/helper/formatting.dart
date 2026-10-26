import 'dart:math' as math;

import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'currency.dart';
import 'money.dart';

/// Build a "username#code" string from a raw JSON map, falling back to display_name.
String fullUsernameFromJson(Map<String, dynamic> json) {
  final username = json['username'];
  final code = json['username_code'];
  if (username != null && code != null) return '$username#$code';
  return json['display_name'] ?? '';
}

/// `yyyy-MM-dd` for [date] — the shape every date column in this app is
/// written and read as (`expense.expense_date`, `expense.rate_date`).
///
/// One definition so a hand-rolled `'${d.year}-${...}'` cannot drift on a
/// single-digit month or day.
String ymd(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Parses a user-typed conversion rate, returning null for anything that is not
/// a usable positive rate.
///
/// Emptying the rate field yields the string "0" (see
/// [DecimalTextInputFormatter], which rewrites an empty value to "0"), so a
/// non-positive parse MUST map to null. Otherwise clearing the field replaces
/// the "rate required" hint with a `= EUR 0.00` preview and a live Reset
/// button, and the refusal only surfaces on save.
double? parseConversionRate(String? text) {
  final value = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

/// Per-locale [NumberFormat] cache for [formatPercentValue]. The fee renders
/// on every build of the conversion row, the conversion sheet's fee row and
/// the Settings row, and constructing a NumberFormat parses a pattern.
final Map<String, NumberFormat> _percentFormats = {};

/// A percent as the user reads it in [locale] — `1.4` in `en`, `1,4` in `de`.
/// The `%` itself comes from l10n (`cardFeePercentValue`), so the unit's
/// spacing is translatable and this stays a pure number formatter.
///
/// [NumberFormat.percentPattern] is deliberately NOT used: it multiplies by
/// 100, so 1.4 would render "140%".
String formatPercentValue(double percent, Locale locale) => _percentFormats
    .putIfAbsent(
      locale.toString(),
      () => NumberFormat.decimalPattern(locale.toString()),
    )
    .format(percent);

/// Parses a typed fee percent, accepting either separator. Null for blank,
/// unparseable or negative input; **0 is valid** and means "no fee" — which is
/// why this cannot reuse [parseConversionRate], whose non-positive parse must
/// map to null.
double? parseCardFeePercent(String? text) {
  final value = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

/// A conversion rate as text: at least 6 significant digits, trailing zeros
/// trimmed, always `.`-separated. 0.0058 renders "0.0058" and 172 renders
/// "172". A rate is a technical figure, not money — it is deliberately NOT
/// locale-formatted, so the string round-trips through
/// [parseConversionRate] unchanged.
///
/// **Significant digits, not decimal places**, because a rate is a multiplier
/// and only its relative precision matters. A flat 6 decimals is fine at
/// 0.9432 and badly wrong at 0.0000494306 — IDR into GBP, the weakest quote in
/// `kSupportedCurrencies` into the strongest — where it renders "0.000049" and
/// throws away 0.87%. On a 5,000,000 IDR expense that is over two pounds. The
/// error was invisible while every rate was typed by hand; a fetched rate lands
/// in the field ready to be accepted unread.
///
/// Large rates keep every digit they had: the decimal count only ever grows
/// from 6, so 17264.19 does not become 17264.2.
String formatRate(double rate) {
  // Digits after the point needed for 6 significant ones: a rate below 1 needs
  // an extra place per leading zero. At or above 1, the integer part already
  // carries the significant digits, so 6 stays 6 and nothing that formats
  // correctly today changes.
  final decimals = rate > 0
      ? math.max(6, 6 - (math.log(rate) / math.ln10).floor() - 1).clamp(0, 20)
      : 6;
  var text = rate.toStringAsFixed(decimals);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

/// The canonical money string: the currency's ISO code, a space, then [amount]
/// with [locale]'s grouping and decimal separator at the currency's own
/// decimal digits. "JPY 3,000" in `en`, "JPY 3.000" in `de`; "EUR 1,234.56" and
/// "EUR 1.234,56". A 0-decimal currency never renders a fractional part.
///
/// The app renders no currency symbols anywhere. A symbol cannot identify a
/// currency: seven supported currencies render as "$", four as "kr" and two as
/// "¥". The two whose symbol IS unique (CHF, RON) achieve that by being their
/// own ISO code. So the code does the job in every case and the symbol in none
/// of them, and one form everywhere beats a rule about where a symbol is safe.
///
/// Unlike symbol placement, which flips per locale ("$1,234.56" vs
/// "1.234,56 $"), the code always leads. Only the separators follow the locale,
/// so the reading order is one thing the user never has to relearn.
String formatMoney(double amount, Currency currency, Locale locale) =>
    '${currency.code} ${formatAmountOnly(amount, currency, locale)}';

/// The same number without a symbol, for the few places that render the symbol
/// themselves as a separate, differently-styled glyph (the expense-editor hero,
/// the itemized unit-price chips). "12,50" in `de`, "12.50" in `en`.
String formatAmountOnly(double amount, Currency currency, Locale locale) =>
    NumberFormat.decimalPatternDigits(
      locale: locale.toString(),
      decimalDigits: currency.decimalDigits,
    ).format(amount);

/// The machine round-trip text for an amount in a form field or a controller:
/// fixed to [currency]'s decimal digits, always `.`-separated, so
/// `double.parse` reads it back exactly. NOT for display — use [formatMoney] or
/// [formatAmountOnly] for anything the user reads as money.
String amountToFieldText(double amount, Currency currency) =>
    amount.toStringAsFixed(currency.decimalDigits);

/// The PayPal.me amount path segment: the amount at [currency]'s own precision
/// with its ISO code appended ("25.50EUR", "3000JPY"). Without the code PayPal
/// opens the request in the PAYEE's default currency, so a USD balance would ask
/// for the wrong money.
String paypalMeAmountSegment(double amount, Currency currency) =>
    '${amountToFieldText(amount, currency)}${currency.code}';

/// Currency-aware money formatting keyed on an ISO 4217 [currencyCode].
///
/// Thin adapter over [formatMoney]: the code is resolved through
/// [Currency.fromCode] (EUR fallback), so decimal digits now travel with the
/// currency and a JPY amount renders "¥3,000", not "¥3,000.00". Every existing
/// call site is unchanged.
extension AppLocalizationsCurrency on AppLocalizations {
  String toCurrency(
    double amount, [
    String currencyCode = kDefaultCurrencyCode,
  ]) =>
      formatMoney(amount, Currency.fromCode(currencyCode), Locale(localeName));
}

/// Normalizes a raw `expense_date` string to local midnight, leniently:
/// unparseable values fall back to epoch so grouping/comparison stays
/// deterministic instead of throwing. Shared by the ledger's day grouping
/// (`groupExpensesByDay`) and the delete guard's same-day check
/// (`classifyExpenseDeletion`) so "same day" means the same thing in both.
DateTime localDayOf(String raw) {
  final parsed = DateTime.tryParse(raw);
  final local = (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  return DateTime(local.year, local.month, local.day);
}

String toHumanDateString(String? dateTimeIn) {
  if (dateTimeIn == null) return '';

  DateFormat format = DateFormat("dd.MM.yyyy");
  return format.format(DateTime.parse(dateTimeIn));
}

String formatDate(String? dateString, [BuildContext? context]) {
  if (dateString == null) return '';
  final parsed = DateTime.parse(dateString);
  final date = DateTime(parsed.year, parsed.month, parsed.day);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (date.year == today.year &&
      date.month == today.month &&
      date.day == today.day) {
    return context != null ? AppLocalizations.of(context)!.dateToday : 'Today';
  } else if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return context != null
        ? AppLocalizations.of(context)!.dateYesterday
        : 'Yesterday';
  } else if (date.year == now.year) {
    // Same year, display day and full month
    return DateFormat('d MMM').format(date);
  } else {
    // Different year, display full date with year
    return DateFormat('d MMM yyyy').format(date);
  }
}
