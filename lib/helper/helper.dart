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

/// ISO codes of [kSupportedCurrencies], for the String-keyed surfaces that still
/// store a bare code (the group form's `currency_code`, the home-currency
/// preference). Derived — never edit this list, edit [kSupportedCurrencies].
final List<String> kSupportedCurrencyCodes = [
  for (final c in kSupportedCurrencies) c.code,
];

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
