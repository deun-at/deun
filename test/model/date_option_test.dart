import 'package:deun/pages/expenses/data/date_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateOption.resolve', () {
    final now = DateTime(2026, 6, 17, 14, 30);

    test('today maps to the given reference date at midnight', () {
      final d = DateOption.today.resolve(now);
      expect(d, DateTime(2026, 6, 17));
    });

    test('yesterday maps to the day before at midnight', () {
      final d = DateOption.yesterday.resolve(now);
      expect(d, DateTime(2026, 6, 16));
    });

    test('yesterday crosses a month boundary', () {
      final d = DateOption.yesterday.resolve(DateTime(2026, 7, 1, 9));
      expect(d, DateTime(2026, 6, 30));
    });

    test('pick has no resolved value (deferred to the calendar)', () {
      expect(DateOption.pick.resolve(now), isNull);
    });
  });

  group('DateOption.matches', () {
    final now = DateTime(2026, 6, 17, 14, 30);

    test('today matches a same-day value with a different time', () {
      expect(DateOption.today.matches(DateTime(2026, 6, 17, 8), now), isTrue);
    });

    test('today does not match yesterday', () {
      expect(DateOption.today.matches(DateTime(2026, 6, 16), now), isFalse);
    });

    test('yesterday matches the previous day', () {
      expect(
        DateOption.yesterday.matches(DateTime(2026, 6, 16, 23), now),
        isTrue,
      );
    });

    test('pick never matches a quick option', () {
      expect(DateOption.pick.matches(DateTime(2026, 6, 17), now), isFalse);
    });
  });
}
