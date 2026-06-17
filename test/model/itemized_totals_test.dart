import 'package:deun/pages/expenses/data/itemized_totals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('itemizedTotal', () {
    test('sums line totals (unitPrice * quantity) across items', () {
      final total = itemizedTotal([
        const ItemLine(unitPrice: 2.50, quantity: 2), // 5.00
        const ItemLine(unitPrice: 3.00, quantity: 1), // 3.00
        const ItemLine(unitPrice: 1.20, quantity: 5), // 6.00
      ]);
      expect(total, closeTo(14.00, 0.0001));
    });

    test('is zero for an empty item list', () {
      expect(itemizedTotal(const []), 0);
    });

    test('treats a single item line total correctly', () {
      final total = itemizedTotal([
        const ItemLine(unitPrice: 9.99, quantity: 3), // 29.97
      ]);
      expect(total, closeTo(29.97, 0.0001));
    });
  });
}
