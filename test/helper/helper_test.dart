import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/helper.dart';

void main() {
  group('toHumanDateString', () {
    test('formats ISO date to dd.MM.yyyy', () {
      expect(toHumanDateString('2024-03-15'), '15.03.2024');
    });

    test('formats datetime string', () {
      expect(toHumanDateString('2024-03-15T14:30:00'), '15.03.2024');
    });

    test('null returns empty string', () {
      expect(toHumanDateString(null), '');
    });

    test('first day of year', () {
      expect(toHumanDateString('2024-01-01'), '01.01.2024');
    });

    test('last day of year', () {
      expect(toHumanDateString('2024-12-31'), '31.12.2024');
    });
  });

  group('toCurrency', () {
    test('formats simple amount', () {
      expect(toCurrency(12.5), '€12.50');
    });

    test('formats with thousands separator', () {
      expect(toCurrency(1234.56), '€1,234.56');
    });

    test('formats zero', () {
      expect(toCurrency(0), '€0.00');
    });

    test('formats negative', () {
      expect(toCurrency(-12.5), '€-12.50');
    });

    test('formats large amount', () {
      expect(toCurrency(123456.78), '€123,456.78');
    });
  });

  group('toNumber', () {
    test('formats simple number', () {
      expect(toNumber(12.5), '12.50');
    });

    test('formats with thousands separator', () {
      expect(toNumber(1234.56), '1,234.56');
    });

    test('formats zero', () {
      expect(toNumber(0), '0.00');
    });

    test('formats negative', () {
      expect(toNumber(-12.5), '-12.50');
    });
  });

  group('formatDate', () {
    test('null returns empty string', () {
      expect(formatDate(null), '');
    });

    test('today returns "Today"', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(formatDate(todayStr), 'Today');
    });

    test('yesterday returns "Yesterday"', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final str = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(formatDate(str), 'Yesterday');
    });

    test('different year shows full date with year', () {
      expect(formatDate('2020-06-15'), contains('2020'));
    });
  });
}
