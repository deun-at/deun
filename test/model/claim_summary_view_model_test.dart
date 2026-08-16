import 'package:flutter_test/flutter_test.dart';
import 'package:deun/helper/currency.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';

void main() {
  ClaimUnit u(double cost, List<String> claimers) =>
      ClaimUnit(unitCost: cost, claimers: claimers);

  ClaimSummary summaryOf(
    List<ClaimUnit> units,
    String persona, {
    Currency currency = Currency.eur,
  }) => buildClaimSummary(
    units: units,
    personaEmail: persona,
    currency: currency,
  );

  group('buildClaimSummary', () {
    test('totals: claimed, unclaimed and grand total', () {
      final summary = summaryOf([
        u(5.0, ['sam@x']),
        u(4.0, []),
        u(6.0, ['priya@x']),
      ], 'sam@x');
      expect(summary.total, 15.0);
      expect(summary.claimed, 11.0);
      expect(summary.unclaimed, 4.0);
    });

    test('yourShare reflects the selected persona', () {
      final units = [
        u(5.0, ['sam@x']),
        u(6.0, ['sam@x', 'priya@x']),
      ];
      expect(
        summaryOf(units, 'sam@x').yourShare,
        8.0, // 5 + 3
      );
      expect(summaryOf(units, 'priya@x').yourShare, 3.0);
    });

    test('yourShare is zero when the persona has claimed nothing', () {
      final summary = summaryOf([
        u(5.0, ['sam@x']),
      ], 'nobody@x');
      expect(summary.yourShare, 0.0);
    });

    test('yourClaimedCount counts the persona\'s claimed units', () {
      final units = [
        u(5.0, ['sam@x']),
        u(6.0, ['sam@x', 'priya@x']),
        u(4.0, ['priya@x']),
        u(3.0, []),
      ];
      expect(summaryOf(units, 'sam@x').yourClaimedCount, 2);
      expect(summaryOf(units, 'nobody@x').yourClaimedCount, 0);
    });

    test(
      'progress is claimed / total, clamped and safe for an empty receipt',
      () {
        expect(
          summaryOf([
            u(4.0, ['a']),
            u(4.0, []),
          ], 'a').progress,
          0.5,
        );
        // No units at all -> no division-by-zero, progress 0.
        expect(summaryOf(const [], 'a').progress, 0.0);
      },
    );

    test(
      'memberTotals are ordered by amount desc with persona pinned first',
      () {
        final summary = summaryOf([
          u(10.0, ['big@x']),
          u(2.0, ['me@x']),
          u(6.0, ['mid@x']),
        ], 'me@x');
        expect(summary.memberTotals.map((e) => e.email).toList(), [
          'me@x',
          'big@x',
          'mid@x',
        ]);
        expect(summary.memberTotals.first.amount, 2.0);
      },
    );

    test('isFullyClaimed / isEmpty flags', () {
      expect(
        summaryOf([
          u(5.0, ['a']),
        ], 'a').isFullyClaimed,
        isTrue,
      );
      expect(summaryOf([u(5.0, [])], 'a').isFullyClaimed, isFalse);
      expect(summaryOf(const [], 'a').isEmpty, isTrue);
    });

    // multi-currency-core review: the remainder used to be judged against a
    // hardcoded EUR half-cent, so a sub-yen leftover on a JPY receipt read as
    // outstanding on a screen that renders it as ¥0.
    group('isFullyClaimed is judged in the receipt currency', () {
      test('a 0.3 remainder is settled in JPY but outstanding in EUR', () {
        final units = [
          u(9.7, ['a']),
          u(0.3, []),
        ];
        expect(
          summaryOf(units, 'a', currency: Currency.jpy).isFullyClaimed,
          isTrue,
        );
        expect(
          summaryOf(units, 'a', currency: Currency.eur).isFullyClaimed,
          isFalse,
        );
      });

      test('a whole-yen remainder is still outstanding in JPY', () {
        final units = [
          u(9.0, ['a']),
          u(1.0, []),
        ];
        expect(
          summaryOf(units, 'a', currency: Currency.jpy).isFullyClaimed,
          isFalse,
        );
      });

      test('the summary carries the currency it was built with', () {
        expect(
          summaryOf(const [], 'a', currency: Currency.jpy).currency,
          Currency.jpy,
        );
      });
    });
  });
}
