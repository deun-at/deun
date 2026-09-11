import 'dart:math' as math;

import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deun/l10n/app_localizations.dart';

import 'currency.dart';
export 'currency.dart';

/// True when an RPC failed because the function doesn't exist on the server
/// yet (older database without the atomic save migrations applied).
/// PGRST202 = PostgREST schema cache miss, 42883 = Postgres undefined function.
bool isMissingFunctionError(PostgrestException e) =>
    e.code == 'PGRST202' || e.code == '42883';

/// True when a PostgREST call failed because a column doesn't exist on the
/// server yet (an older database without a feature's migration applied).
/// 42703 = Postgres undefined column, PGRST204 = PostgREST schema-cache miss.
bool isMissingColumnError(PostgrestException e) =>
    e.code == '42703' || e.code == 'PGRST204';

/// Build a "username#code" string from a raw JSON map, falling back to display_name.
String fullUsernameFromJson(Map<String, dynamic> json) {
  final username = json['username'];
  final code = json['username_code'];
  if (username != null && code != null) return '$username#$code';
  return json['display_name'] ?? '';
}

/// Sanitize a value before interpolating it into a Supabase PostgREST filter string.
/// Strips characters that could break the filter DSL (commas, parentheses, etc.).
String sanitizeFilterValue(String value) =>
    value.replaceAll(RegExp(r'[%,()\\]'), '');

/// Rounds [value] to [currency]'s minor unit, to prevent floating-point drift.
/// Use at every arithmetic boundary where money is computed.
///
/// The [Currency] is required on purpose: a compile error at every call site is
/// the cheapest way to guarantee none keeps the old hardcoded 2 decimals.
double roundCurrency(double value, Currency currency) {
  final factor = math.pow(10, currency.decimalDigits).toDouble();
  return (value * factor).roundToDouble() / factor;
}

/// `yyyy-MM-dd` for [date] — the shape every date column in this app is
/// written and read as (`expense.expense_date`, `expense.rate_date`).
///
/// One definition so a hand-rolled `'${d.year}-${...}'` cannot drift on a
/// single-digit month or day.
String ymd(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

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
/// Ties break on the key, not on map order: with four equal shares *somebody*
/// has to carry the spare cent, and it must be the same somebody on every
/// render.
Map<K, double> apportionCurrency<K extends Comparable>(
  Map<K, double> values,
  double total,
  Currency currency,
) {
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
      final byFraction = fractions[b]!.compareTo(fractions[a]!);
      return byFraction != 0 ? byFraction : a.compareTo(b);
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

/// A conversion rate as text: up to 6 fractional digits, trailing zeros
/// trimmed, always `.`-separated. 0.0058 renders "0.0058" and 172 renders
/// "172". A rate is a technical figure, not money — it is deliberately NOT
/// locale-formatted, so the string round-trips through
/// [parseConversionRate] unchanged.
String formatRate(double rate) {
  var text = rate.toStringAsFixed(6);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
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

/// The locale-aware currency symbol for [currencyCode] (e.g. "$", "£", "€"),
/// used for bare amount-input adornments.
String currencySymbolFor(String localeName, String currencyCode) =>
    NumberFormat.simpleCurrency(
      locale: localeName,
      name: currencyCode,
    ).currencySymbol;

/// The canonical money string: [amount] in [currency], with [locale]'s grouping,
/// decimal separator and symbol placement, at the currency's own decimal digits.
/// "¥3,000" in `en` and "3.000 ¥" in `de`; "$1,234.56" and "1.234,56 $". A
/// 0-decimal currency never renders a fractional part.
String formatMoney(double amount, Currency currency, Locale locale) =>
    NumberFormat.simpleCurrency(
      locale: locale.toString(),
      name: currency.code,
      decimalDigits: currency.decimalDigits,
    ).format(amount);

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

void showSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  SnackBar snackBar = SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 2),
  );

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(snackBar);
}

void showMaterialBanner(
  BuildContext context,
  String message,
  Function onPressed,
) {
  final messenger = ScaffoldMessenger.of(context);

  final banner = MaterialBanner(
    content: Text(message),
    actions: <Widget>[
      TextButton(
        onPressed: () {
          onPressed();
          messenger.hideCurrentMaterialBanner();
        },
        child: Text(AppLocalizations.of(context)!.open),
      ),
      TextButton(
        onPressed: () {
          messenger.hideCurrentMaterialBanner();
        },
        child: Text(AppLocalizations.of(context)!.close),
      ),
    ],
  );

  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(banner);
}

void sendGroupNotification(
  BuildContext context,
  String groupId,
  Set<String> notificationReceiver,
) {
  supabase
      .from('group')
      .select('name, ...user_id(user_display_name:display_name)')
      .eq('id', groupId)
      .single()
      .then(
        (value) {
          String title = AppLocalizations.of(
            context,
          )!.groupNotificationTitle(value['user_display_name']);
          String body = AppLocalizations.of(
            context,
          )!.groupNotificationBody(value['name']);

          sendNotification('group', groupId, notificationReceiver, title, body);
        },
        onError: (e) {
          debugPrint(
            'Failed to send group notification for group $groupId: $e',
          );
        },
      );
}

/// Pushes the settle-up notification.
///
/// payback-on-behalf: [recordedByDisplayName] null means "the payer recorded
/// this themselves" and produces byte-identical copy to before the feature.
/// Non-null switches to the on-behalf copy, which names the recorder in the
/// title and both parties in the body — the visibility that stands in for the
/// permission model Deun deliberately does not have. Every name is passed in by
/// the caller (they come off the group roster it resolved the payback against),
/// so this copy does not wait on `expense.user_id` being populated and the
/// select only has to fetch the group.
void sendGroupPayBackNotification(
  BuildContext context,
  String groupId,
  String expenseId,
  Set<String> notificationReceiver,
  double amount, {
  required String paidByDisplayName,
  required String paidForDisplayName,
  String? recordedByDisplayName,
}) {
  supabase
      .from('expense')
      .select(
        'name, ...group!expense_group_id_fkey(group_name:name, group_currency_code:currency_code)',
      )
      .eq('id', expenseId)
      .single()
      .then(
        (value) {
          final l10n = AppLocalizations.of(context)!;
          final String formattedAmount = l10n.toCurrency(
            amount,
            value['group_currency_code'] ?? kDefaultCurrencyCode,
          );

          final String title;
          final String body;
          if (recordedByDisplayName == null) {
            title = l10n.groupPayBackNotificationTitle(
              paidByDisplayName,
              value['group_name'],
            );
            body = l10n.groupPayBackNotificationBody(formattedAmount);
          } else {
            title = l10n.groupPayBackOnBehalfNotificationTitle(
              recordedByDisplayName,
              value['group_name'],
            );
            body = l10n.groupPayBackOnBehalfNotificationBody(
              paidByDisplayName,
              paidForDisplayName,
              formattedAmount,
            );
          }

          sendNotification('group', groupId, notificationReceiver, title, body);
        },
        onError: (e) {
          debugPrint(
            'Failed to send pay back notification for expense $expenseId: $e',
          );
        },
      );
}

void sendPaymentReminderNotification(
  BuildContext context,
  String groupId,
  Set<String> notificationReceiver,
  double amount,
) {
  supabase
      .from('group')
      .select('name, currency_code, ...user_id(user_display_name:display_name)')
      .eq('id', groupId)
      .single()
      .then(
        (value) {
          final l10n = AppLocalizations.of(context)!;
          String title = l10n.reminderNotificationTitle(
            value['user_display_name'],
          );
          String body = l10n.reminderNotificationBody(
            l10n.toCurrency(
              amount,
              value['currency_code'] ?? kDefaultCurrencyCode,
            ),
            value['name'],
          );

          sendNotification(
            'reminder',
            groupId,
            notificationReceiver,
            title,
            body,
          );
        },
        onError: (e) {
          debugPrint(
            'Failed to send reminder notification for group $groupId: $e',
          );
        },
      );
}

void sendExpenseNotification(
  BuildContext context,
  String expenseId,
  Set<String> notificationReceiver,
  double amount,
) {
  supabase
      .from('expense')
      .select(
        'name, ...group!expense_group_id_fkey(group_name:name, group_currency_code:currency_code), ...user_id(user_display_name:display_name)',
      )
      .eq('id', expenseId)
      .single()
      .then(
        (value) {
          final l10n = AppLocalizations.of(context)!;
          String title = l10n.expenseNotificationTitle(
            value['user_display_name'],
          );
          String body = l10n.expenseNotificationBody(
            value['name'],
            value['group_name'],
            l10n.toCurrency(
              amount,
              value['group_currency_code'] ?? kDefaultCurrencyCode,
            ),
          );

          sendNotification(
            'expense',
            expenseId,
            notificationReceiver,
            title,
            body,
          );
        },
        onError: (e) {
          debugPrint(
            'Failed to send expense notification for expense $expenseId: $e',
          );
        },
      );
}

void sendFriendRequestNotification(
  BuildContext context,
  Set<String> notificationReceiver,
) {
  final l10n = AppLocalizations.of(context)!;
  UserRepository.fetchDetail(supabase.auth.currentUser!.email ?? '').then(
    (value) {
      sendNotification(
        'friendship',
        '',
        notificationReceiver,
        l10n.friendRequestNotificationTitle,
        l10n.friendRequestNotificationBody(value.displayName),
      );
    },
    onError: (e) {
      debugPrint('Failed to send friend request notification: $e');
    },
  );
}

void sendFriendAcceptNotification(
  BuildContext context,
  Set<String> notificationReceiver,
) {
  final l10n = AppLocalizations.of(context)!;
  UserRepository.fetchDetail(supabase.auth.currentUser!.email ?? '').then(
    (value) {
      sendNotification(
        'friendship',
        '',
        notificationReceiver,
        l10n.friendAcceptNotificationTitle,
        l10n.friendAcceptNotificationBody(value.displayName),
      );
    },
    onError: (e) {
      debugPrint('Failed to send friend accept notification: $e');
    },
  );
}

void sendFriendDeclineNotification(
  BuildContext context,
  Set<String> notificationReceiver,
) {
  final l10n = AppLocalizations.of(context)!;
  UserRepository.fetchDetail(supabase.auth.currentUser!.email ?? '').then(
    (value) {
      sendNotification(
        'friendship',
        '',
        notificationReceiver,
        l10n.friendDeclineNotificationTitle,
        l10n.friendDeclineNotificationBody(value.displayName),
      );
    },
    onError: (e) {
      debugPrint('Failed to send friend decline notification: $e');
    },
  );
}

Future<void> sendNotification(
  String type,
  String objectId,
  Set<String> notificationReceiver,
  String title,
  String body,
) async {
  try {
    notificationReceiver.remove(supabase.auth.currentUser?.email);
    final res = await supabase.functions.invoke(
      'push',
      body: {
        'type': 'INSERT',
        'table': type,
        'record': {
          'type': type,
          'object_id': objectId,
          'title': title,
          'body': body,
          'notification_receiver': notificationReceiver.toList(),
        },
      },
    );
    final data = res.data;
    debugPrint(data.toString());
  } catch (e) {
    debugPrint(e.toString());
  }
}

/// Escapes user input before it is embedded in the HTML email body.
String escapeHtml(String? value) => (value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Throws on failure so callers can show an error to the user.
Future<void> sendContactMail(Map<String, dynamic> contactInfo) async {
  final name = escapeHtml(contactInfo['name']?.toString());
  final company = escapeHtml(contactInfo['company']?.toString() ?? '-');
  final email = escapeHtml(contactInfo['email']?.toString());
  final description = escapeHtml(contactInfo['description']?.toString());

  await supabase.functions.invoke(
    'send-contact-email',
    body: {
      'message':
          "Name: $name <br>Company: $company<br>E-Mail: $email<br><br>Description: $description",
    },
  );
}

void navigateToGroup(BuildContext context, Group group) {
  // Navigate to the group detail page
  GoRouter.of(context).go("/group");
  GoRouter.of(context).push("/group/details", extra: {'group': group});
}

/// Opens an expense the same way the ledger does: expenses with per-unit claim
/// items go to Tap-to-Claim (Screen 9); everything else — quick expenses AND
/// old itemized expenses with manual splits (no claim units) — goes to the read
/// detail (Screen 11), which shows the real per-member breakdown. Routing on
/// claim units (not entry count) keeps old itemized expenses off the claim
/// screen, where they'd read as €0.00 / "no claimable items".
///
/// THE single expense opener: the ledger tap, the expense search AND push
/// notifications ([navigateToExpense]) all route through here, so a notification
/// can never land somewhere the in-app list wouldn't. Neither branch is the
/// editor (`/group/details/expense`) — that route doubles as the create screen
/// and is reached only from the "+" and the read view's edit action.
void openLedgerExpense(BuildContext context, Group group, Expense expense) {
  GoRouter.of(context).push(
    expense.hasClaimUnits
        ? "/group/details/claim"
        : "/group/details/expense-detail",
    extra: {'group': group, 'expense': expense},
  );
}

/// Push-notification entry point (both cold start and background — see
/// `_handleMessage` in `lib/navigation.dart`). Puts the group detail on the
/// stack, then opens the expense exactly where a ledger tap would, so
/// dismissing it falls back to the group detail with no editor underneath.
void navigateToExpense(BuildContext context, Expense expense) {
  navigateToGroup(context, expense.group);
  openLedgerExpense(context, expense.group, expense);
}

void navigateToFriends(BuildContext context) {
  GoRouter.of(context).go("/friend");
}

void refreshSuggestions(SearchController searchController) {
  const String _zeroWidthSpace = '\u200B';
  final previousText = searchController.text;
  searchController.text =
      '$_zeroWidthSpace$previousText'; // This will trigger updateSuggestions and call `suggestionsBuilder`.
  searchController.text = previousText;
}
