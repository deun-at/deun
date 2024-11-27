import 'package:intl/intl.dart';

String localizeDateTime(String? dateTimeIn) {
  if (dateTimeIn == null) return '';
  final utc = DateTime.parse(dateTimeIn).toUtc();
  final local = utc.toLocal();
  return local.toString();
}

String toHumanDateString(String? dateTimeIn) {
  if (dateTimeIn == null) return '';

  DateFormat format = DateFormat("dd.MM.yyyy");
  return format.format(DateTime.parse(dateTimeIn));
}

String toCurrency(double value) {
  final NumberFormat numFormat = NumberFormat('###,##0.00', 'en_US');
  return "€${numFormat.format(value)}";
}