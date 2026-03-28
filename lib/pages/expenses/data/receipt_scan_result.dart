class ReceiptLineItem {
  final String name;
  final double amount;

  const ReceiptLineItem({required this.name, required this.amount});
}

class ReceiptScanResult {
  final String? merchantName;
  final DateTime? date;
  final List<ReceiptLineItem> lineItems;
  final double? total;

  const ReceiptScanResult({
    this.merchantName,
    this.date,
    this.lineItems = const [],
    this.total,
  });

  bool get isEmpty =>
      merchantName == null &&
      date == null &&
      lineItems.isEmpty &&
      total == null;
}
