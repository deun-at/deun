import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/widgets.dart';

/// The `push` Edge Function call. Default: [_invokePush].
typedef PushTransport =
    Future<void> Function(
      String type,
      String objectId,
      Set<String> receivers,
      String title,
      String body,
    );

/// One row of today's select. Group row: `name`, `currency_code`,
/// `user_display_name` (the group's creator). Expense row: `name`,
/// `group_name`, `group_currency_code`, `user_display_name` (the expense's
/// creator).
typedef NotificationRowLookup =
    Future<Map<String, dynamic>> Function(String id);

/// The signed-in user's display name, or null when nobody is signed in.
typedef SenderNameLookup = Future<String?> Function();

/// The body posted to the `push` Edge Function. [senderEmail] is left out of
/// `notification_receiver`; [receivers] is not mutated.
Map<String, dynamic> pushRequestBody({
  required String type,
  required String objectId,
  required Set<String> receivers,
  required String title,
  required String body,
  String? senderEmail,
}) => {
  'type': 'INSERT',
  'table': type,
  'record': {
    'type': type,
    'object_id': objectId,
    'title': title,
    'body': body,
    'notification_receiver': [
      for (final receiver in receivers)
        if (receiver != senderEmail) receiver,
    ],
  },
};

/// Composes and sends every push. Holds its [AppLocalizations] from
/// construction on, so no BuildContext is ever read after a lookup returns.
/// Constructing one touches no Supabase client; the defaults reach `supabase`
/// only when a send runs. Every method completes normally on every failure.
class NotificationSender {
  NotificationSender(
    this._l10n, {
    PushTransport? push,
    NotificationRowLookup? groupRow,
    NotificationRowLookup? expenseRow,
    SenderNameLookup? senderName,
  }) : _push = push ?? _invokePush,
       _groupRow = groupRow ?? _fetchGroupRow,
       _expenseRow = expenseRow ?? _fetchExpenseRow,
       _senderName = senderName ?? _fetchSenderName;

  /// Resolves [AppLocalizations] synchronously: call it before the first await.
  factory NotificationSender.of(
    BuildContext context, {
    PushTransport? push,
    NotificationRowLookup? groupRow,
    NotificationRowLookup? expenseRow,
    SenderNameLookup? senderName,
  }) => NotificationSender(
    AppLocalizations.of(context)!,
    push: push,
    groupRow: groupRow,
    expenseRow: expenseRow,
    senderName: senderName,
  );

  final AppLocalizations _l10n;
  final PushTransport _push;
  final NotificationRowLookup _groupRow;
  final NotificationRowLookup _expenseRow;
  final SenderNameLookup _senderName;

  String _money(double amount, Object? currencyCode) =>
      _l10n.toCurrency(amount, currencyCode as String? ?? kDefaultCurrencyCode);

  Future<void> memberAdded(String groupId, Set<String> receivers) =>
      _guard('group', () async {
        final row = await _groupRow(groupId);
        await _push(
          'group',
          groupId,
          receivers,
          _l10n.groupNotificationTitle(row['user_display_name']),
          _l10n.groupNotificationBody(row['name']),
        );
      });

  /// [recordedByDisplayName] null = the payer recorded it (today's copy);
  /// non-null = the on-behalf copy.
  Future<void> paybackRecorded({
    required String groupId,
    required Set<String> receivers,
    required double amount,
    required String paidByDisplayName,
    required String paidForDisplayName,
    String? recordedByDisplayName,
  }) => _guard('payback', () async {
    final row = await _groupRow(groupId);
    final amountText = _money(amount, row['currency_code']);
    final String title;
    final String body;
    if (recordedByDisplayName == null) {
      title = _l10n.groupPayBackNotificationTitle(
        paidByDisplayName,
        row['name'],
      );
      body = _l10n.groupPayBackNotificationBody(amountText);
    } else {
      title = _l10n.groupPayBackOnBehalfNotificationTitle(
        recordedByDisplayName,
        row['name'],
      );
      body = _l10n.groupPayBackOnBehalfNotificationBody(
        paidByDisplayName,
        paidForDisplayName,
        amountText,
      );
    }
    await _push('group', groupId, receivers, title, body);
  });

  Future<void> paymentReminder(
    String groupId,
    Set<String> receivers,
    double amount,
  ) => _guard('reminder', () async {
    final row = await _groupRow(groupId);
    await _push(
      'reminder',
      groupId,
      receivers,
      _l10n.reminderNotificationTitle(row['user_display_name']),
      _l10n.reminderNotificationBody(
        _money(amount, row['currency_code']),
        row['name'],
      ),
    );
  });

  Future<void> expenseCreated(
    String expenseId,
    Set<String> receivers,
    double amount,
  ) => _guard('expense', () async {
    final row = await _expenseRow(expenseId);
    await _push(
      'expense',
      expenseId,
      receivers,
      _l10n.expenseNotificationTitle(row['user_display_name']),
      _l10n.expenseNotificationBody(
        row['name'],
        row['group_name'],
        _money(amount, row['group_currency_code']),
      ),
    );
  });

  Future<void> friendRequested(Set<String> receivers) =>
      _guard('friend request', () async {
        final name = await _senderName();
        if (name == null) return;
        await _push(
          'friendship',
          '',
          receivers,
          _l10n.friendRequestNotificationTitle,
          _l10n.friendRequestNotificationBody(name),
        );
      });

  Future<void> friendAccepted(Set<String> receivers) =>
      _guard('friend accept', () async {
        final name = await _senderName();
        if (name == null) return;
        await _push(
          'friendship',
          '',
          receivers,
          _l10n.friendAcceptNotificationTitle,
          _l10n.friendAcceptNotificationBody(name),
        );
      });

  Future<void> claimNudge({
    required String expenseId,
    required Set<String> receivers,
    required String senderDisplayName,
    required String expenseName,
    required String groupName,
  }) => _guard(
    'claim nudge',
    () => _push(
      'expense',
      expenseId,
      receivers,
      _l10n.claimNudgeNotificationTitle(senderDisplayName),
      _l10n.claimNudgeNotificationBody(expenseName, groupName),
    ),
  );

  static Future<void> _guard(String kind, Future<void> Function() send) async {
    try {
      await send();
    } catch (e) {
      debugPrint('Failed to send $kind notification: $e');
    }
  }
}

Future<Map<String, dynamic>> _fetchGroupRow(String groupId) async =>
    await supabase
        .from('group')
        .select(
          'name, currency_code, ...user_id(user_display_name:display_name)',
        )
        .eq('id', groupId)
        .single();

Future<Map<String, dynamic>> _fetchExpenseRow(
  String expenseId,
) async => await supabase
    .from('expense')
    .select(
      'name, ...group!expense_group_id_fkey(group_name:name, group_currency_code:currency_code), ...user_id(user_display_name:display_name)',
    )
    .eq('id', expenseId)
    .single();

Future<String?> _fetchSenderName() async {
  final email = supabase.auth.currentUser?.email;
  if (email == null) return null;
  return (await UserRepository.fetchDetail(email)).displayName;
}

Future<void> _invokePush(
  String type,
  String objectId,
  Set<String> receivers,
  String title,
  String body,
) async {
  final res = await supabase.functions.invoke(
    'push',
    body: pushRequestBody(
      type: type,
      objectId: objectId,
      receivers: receivers,
      title: title,
      body: body,
      senderEmail: supabase.auth.currentUser?.email,
    ),
  );
  debugPrint(res.data.toString());
}
