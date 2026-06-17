import 'package:deun/pages/expenses/data/claimable_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('markEntriesClaimable', () {
    test('adds a claimable flag for every entry index present', () {
      final form = {
        'name': 'Supermarket',
        'expense_entry[0][name]': 'Beer',
        'expense_entry[0][amount]': '5.00',
        'expense_entry[0][quantity]': '3',
        'expense_entry[1][name]': 'Wine',
        'expense_entry[1][amount]': '8.50',
      };

      final out = markEntriesClaimable(form);

      expect(out['expense_entry[0][claimable]'], isTrue);
      expect(out['expense_entry[1][claimable]'], isTrue);
    });

    test('does not mutate the original map', () {
      final form = {'expense_entry[0][amount]': '5.00'};
      markEntriesClaimable(form);
      expect(form.containsKey('expense_entry[0][claimable]'), isFalse);
    });

    test('preserves all existing keys and values', () {
      final form = {
        'name': 'Shop',
        'paid_by': 'a@test.com',
        'expense_entry[2][amount]': '1.00',
      };
      final out = markEntriesClaimable(form);
      expect(out['name'], 'Shop');
      expect(out['paid_by'], 'a@test.com');
      expect(out['expense_entry[2][amount]'], '1.00');
      expect(out['expense_entry[2][claimable]'], isTrue);
    });

    test('no entries → no claimable keys added', () {
      final form = {'name': 'Shop'};
      final out = markEntriesClaimable(form);
      expect(out.keys.any((k) => k.contains('[claimable]')), isFalse);
    });
  });
}
