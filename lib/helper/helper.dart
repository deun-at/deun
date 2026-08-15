import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deun/l10n/app_localizations.dart';

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

/// Round a currency value to 2 decimal places to prevent floating-point drift.
/// Use at every arithmetic boundary where money is computed.
double roundCurrency(double value) => (value * 100).roundToDouble() / 100;

/// Half a cent: the magnitude at which a balance stops being settled. Below it a
/// balance rounds to `0.00` at two decimals, so "settled" means exactly "renders
/// as zero" — never a wider window that hides a real cent.
const double kSettledEpsilon = 0.005;

/// Whether [amount] counts as a settled balance. THE settled/outstanding
/// decision in the app: the payment screen, the group-detail hero, the group-list
/// hero, the group cards, the friend list and the member-removal guard all route
/// through this one predicate, so a balance can never read settled on one screen
/// and outstanding on another.
///
/// The active/done group tabs filter server-side in a PostgREST query and cannot
/// call this — `GroupRepository.activeBalanceFilter` builds the same threshold
/// from [kSettledEpsilon] instead.
///
/// `multi-currency-core` widens this to `isSettled(double amount, Currency
/// currency)` (true below half a minor unit). Keep every call site here so that
/// stays a signature change and not a second sweep.
bool isSettled(double amount) => amount.abs() < kSettledEpsilon;

/// App-wide default group currency (ISO 4217). New groups default to this and
/// any amount rendered without an explicit group currency falls back to it.
const String kDefaultCurrencyCode = 'EUR';

/// Currencies offered in the group currency picker. Every entry is an ISO 4217
/// code `intl` can format with a locale-aware symbol.
const List<String> kSupportedCurrencyCodes = [
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'JPY',
  'CAD',
  'AUD',
  'NZD',
  'CNY',
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'CZK',
  'HUF',
  'INR',
  'BRL',
  'ZAR',
  'MXN',
  'SGD',
  'HKD',
  'KRW',
  'TRY',
];

/// The locale-aware currency symbol for [currencyCode] (e.g. "$", "£", "€"),
/// used for bare amount-input adornments.
String currencySymbolFor(String localeName, String currencyCode) =>
    NumberFormat.simpleCurrency(
      locale: localeName,
      name: currencyCode,
    ).currencySymbol;

/// Currency-aware money formatting keyed on an ISO 4217 [currencyCode].
///
/// Replaces the former generated `toCurrency` (which baked in "€"): the symbol
/// and its placement now come from the currency code + active locale, so the
/// same amount renders "$1,234.56" in en-US/USD and "1.234,56 €" in de-DE/EUR.
/// [currencyCode] defaults to [kDefaultCurrencyCode] so cross-group/aggregate
/// call sites (statistics, friends) format via the default rather than a
/// hardcoded symbol.
extension AppLocalizationsCurrency on AppLocalizations {
  String toCurrency(
    double amount, [
    String currencyCode = kDefaultCurrencyCode,
  ]) => NumberFormat.simpleCurrency(
    locale: localeName,
    name: currencyCode,
    decimalDigits: 2,
  ).format(amount);
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

void sendGroupPayBackNotification(
  BuildContext context,
  String groupId,
  String expenseId,
  Set<String> notificationReceiver,
  double amount,
) {
  supabase
      .from('expense')
      .select(
        'name, ...group!expense_group_id_fkey(group_name:name, group_currency_code:currency_code), ...paid_by(user_display_name:display_name)',
      )
      .eq('id', expenseId)
      .single()
      .then(
        (value) {
          final l10n = AppLocalizations.of(context)!;
          String title = l10n.groupPayBackNotificationTitle(
            value['user_display_name'] ?? '',
            value['group_name'],
          );
          String body = l10n.groupPayBackNotificationBody(
            l10n.toCurrency(
              amount,
              value['group_currency_code'] ?? kDefaultCurrencyCode,
            ),
          );

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
