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

  group('roundCurrency', () {
    test('rounds drift from addition to exact cents', () {
      expect(roundCurrency(0.1 + 0.2), 0.3);
    });

    test('rounds repeating thirds to cents', () {
      expect(roundCurrency(100 / 3), 33.33);
      expect(roundCurrency(200 / 3), 66.67);
    });

    test('keeps exact values unchanged', () {
      expect(roundCurrency(12.34), 12.34);
    });

    test('rounds negative values', () {
      expect(roundCurrency(-200 / 3), -66.67);
    });
  });

  group('escapeHtml', () {
    test('escapes html-relevant characters', () {
      expect(escapeHtml('<script>alert("x&y")</script>'),
          '&lt;script&gt;alert(&quot;x&amp;y&quot;)&lt;/script&gt;');
    });

    test('null becomes empty string', () {
      expect(escapeHtml(null), '');
    });

    test('plain text passes through', () {
      expect(escapeHtml('Hello World'), 'Hello World');
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
