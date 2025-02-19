import 'package:deun/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String toHumanDateString(String? dateTimeIn) {
  if (dateTimeIn == null) return '';

  DateFormat format = DateFormat("dd.MM.yyyy");
  return format.format(DateTime.parse(dateTimeIn));
}

String toCurrency(double value) {
  final NumberFormat numFormat = NumberFormat('###,##0.00', 'en_US');
  return "€${numFormat.format(value)}";
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

showSnackBar(BuildContext context, String message) {
  SnackBar snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    width: 400.0,
    content: Text(message),
    action: SnackBarAction(
      label: AppLocalizations.of(context)!.close,
      onPressed: () {},
    ),
  );

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

sendExpenseNotification(BuildContext context, String expenseId, Set<String> notificationReceiver, double amount) {
  supabase
      .from('expense')
      .select('name, ...group(group_name:name), ...user(user_display_name:display_name)')
      .eq('id', expenseId)
      .single()
      .then((value) {
    String title = AppLocalizations.of(context)!.expenseNotificationTitle(value['user_display_name']);
    String body = AppLocalizations.of(context)!.expenseNotificationBody(value['name'], value['group_name'], amount);

    sendNotification('expense', expenseId, notificationReceiver, title, body);
  });
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
