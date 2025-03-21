import 'package:deun/main.dart';
import 'package:deun/pages/expenses/expense_model.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:deun/l10n/app_localizations.dart';

String toHumanDateString(String? dateTimeIn) {
  if (dateTimeIn == null) return '';

  DateFormat format = DateFormat("dd.MM.yyyy");
  return format.format(DateTime.parse(dateTimeIn));
}

String toCurrency(double value) {
  final NumberFormat numFormat = NumberFormat('###,##0.00', 'en_US');
  return "€${numFormat.format(value)}";
}

String toNumber(double value) {
  final NumberFormat numFormat = NumberFormat('###,##0.00', 'en_US');
  return numFormat.format(value);
}

String formatDate(String? dateString) {
  if (dateString == null) return '';
  final date = DateTime.parse(dateString);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (date.isAtSameMomentAs(today)) {
    return 'Today';
  } else if (date.isAtSameMomentAs(yesterday)) {
    return 'Yesterday';
  } else if (date.year == now.year) {
    // Same year, display day and full month
    return DateFormat('d MMM').format(date);
  } else {
    // Different year, display full date with year
    return DateFormat('d MMM yyyy').format(date);
  }
}

showSnackBar(BuildContext context, GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey, String message) {
  SnackBar snackBar = SnackBar(
    content: Text(message),
    action: SnackBarAction(
      label: AppLocalizations.of(context)!.close,
      onPressed: () {},
    ),
  );

  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}

showMaterialBanner(BuildContext context, String message, Function onPressed) {
  final messengerKey = rootScaffoldMessengerKey.currentState;

  if (messengerKey == null) {
    return;
  }

  final banner = MaterialBanner(
    content: Text(message),
    actions: <Widget>[
      TextButton(
        onPressed: () {
          onPressed();
          messengerKey.hideCurrentMaterialBanner();
        },
        child: Text(AppLocalizations.of(context)!.open),
      ),
      TextButton(
        onPressed: () {
          messengerKey.hideCurrentMaterialBanner();
        },
        child: Text(AppLocalizations.of(context)!.close),
      ),
    ],
  );

  messengerKey.hideCurrentMaterialBanner();
  messengerKey.showMaterialBanner(banner);
}

sendGroupNotification(BuildContext context, String groupId, Set<String> notificationReceiver) {
  supabase.from('group').select('name, ...user_id(user_display_name:display_name)').eq('id', groupId).single().then(
    (value) {
      String title = AppLocalizations.of(context)!.groupNotificationTitle(value['user_display_name']);
      String body = AppLocalizations.of(context)!.groupNotificationBody(value['name']);

      sendNotification('group', groupId, notificationReceiver, title, body);
    },
  );
}

sendGroupPayBackNotification(
    BuildContext context, String groupId, String expenseId, Set<String> notificationReceiver, double amount) {
  supabase
      .from('expense')
      .select('name, ...group!expense_group_id_fkey(group_name:name), ...paid_by(user_display_name:display_name)')
      .eq('id', expenseId)
      .single()
      .then(
    (value) {
      debugPrint(value.toString());
      String title = AppLocalizations.of(context)!
          .groupPayBackNotificationTitle(value['user_display_name'] ?? '', value['group_name']);
      String body = AppLocalizations.of(context)!.groupPayBackNotificationBody(amount);

      sendNotification('group', groupId, notificationReceiver, title, body);
    },
  );
}

sendExpenseNotification(BuildContext context, String expenseId, Set<String> notificationReceiver, double amount) {
  supabase
      .from('expense')
      .select('name, ...group!expense_group_id_fkey(group_name:name), ...user_id(user_display_name:display_name)')
      .eq('id', expenseId)
      .single()
      .then(
    (value) {
      String title = AppLocalizations.of(context)!.expenseNotificationTitle(value['user_display_name']);
      String body = AppLocalizations.of(context)!.expenseNotificationBody(value['name'], value['group_name'], amount);

      sendNotification('expense', expenseId, notificationReceiver, title, body);
    },
  );
}

sendFriendRequestNotification(BuildContext context, Set<String> notificationReceiver) {
  User.fetchDetail(supabase.auth.currentUser!.email ?? '').then(
    (value) {
      sendNotification(
        'friendship',
        '',
        notificationReceiver,
        // ignore: use_build_context_synchronously
        AppLocalizations.of(context)!.friendRequestNotificationTitle,
        // ignore: use_build_context_synchronously
        AppLocalizations.of(context)!.friendRequestNotificationBody(value.displayName),
      );
    },
  );
}

sendFriendAcceptNotification(BuildContext context, Set<String> notificationReceiver) {
  User.fetchDetail(supabase.auth.currentUser!.email ?? '').then(
    (value) {
      sendNotification(
        'friendship',
        '',
        notificationReceiver,
        // ignore: use_build_context_synchronously
        AppLocalizations.of(context)!.friendAcceptNotificationTitle,
        // ignore: use_build_context_synchronously
        AppLocalizations.of(context)!.friendAcceptNotificationBody(value.displayName),
      );
    },
  );
}

sendNotification(String type, String objectId, Set<String> notificationReceiver, String title, String body) async {
  try {
    notificationReceiver.remove(supabase.auth.currentUser?.email);
    final res = await supabase.functions.invoke('push', body: {
      'type': 'INSERT',
      'table': type,
      'record': {
        'type': type,
        'object_id': objectId,
        'title': title,
        'body': body,
        'notification_receiver': notificationReceiver.toList(),
      }
    });
    final data = res.data;
    debugPrint(data.toString());
  } catch (e) {
    debugPrint(e.toString());
  }
}

navigateToExpense(BuildContext context, Expense expense) {
  // Navigate to the group expense list first
  GoRouter.of(context).go("/group");
  GoRouter.of(context).push("/group/details", extra: {'group': expense.group});

  // Delay opening the BottomSheet
  Future.delayed(Durations.medium1, () {
    // ignore: use_build_context_synchronously
    GoRouter.of(context).push("/group/details/expense", extra: {'group': expense.group, 'expense': expense});
  });
}

navigateToFriends(BuildContext context) {
  GoRouter.of(context).go("/friend");
}
