/// A single itemized line: a unit price and a quantity. Its line total is
/// `unitPrice * quantity` — the same derivation the entry widget uses.
class ItemLine {
  const ItemLine({required this.unitPrice, required this.quantity});

  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;
}

/// Sum of every line total — the itemized expense total shown in the header.
double itemizedTotal(List<ItemLine> items) {
  double sum = 0;
  for (final item in items) {
    sum += item.lineTotal;
  }
  return sum;
}
