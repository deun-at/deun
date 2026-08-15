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

  group('isSettled', () {
    test('a zero balance is settled', () {
      expect(isSettled(0), isTrue);
    });

    test('below half a cent is settled, in both signs', () {
      expect(isSettled(0.004), isTrue);
      expect(isSettled(-0.004), isTrue);
    });

    test('half a cent is outstanding, in both signs', () {
      expect(isSettled(0.005), isFalse);
      expect(isSettled(-0.005), isFalse);
    });

    test('0.007 is outstanding — one answer, not two', () {
      // The payment screen said outstanding (0.005) and the group list said
      // settled (0.01) for this exact value.
      expect(isSettled(0.007), isFalse);
    });

    test('settled means exactly "renders as 0.00"', () {
      expect(roundCurrency(0.004), 0.0);
      expect(roundCurrency(0.005), 0.01);
      expect(kSettledEpsilon, 0.005);
    });
  });

  group('escapeHtml', () {
    test('escapes html-relevant characters', () {
      expect(
        escapeHtml('<script>alert("x&y")</script>'),
        '&lt;script&gt;alert(&quot;x&amp;y&quot;)&lt;/script&gt;',
      );
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
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(formatDate(todayStr), 'Today');
    });

    test('yesterday returns "Yesterday"', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final str =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(formatDate(str), 'Yesterday');
    });

    test('different year shows full date with year', () {
      expect(formatDate('2020-06-15'), contains('2020'));
    });
  });
}
