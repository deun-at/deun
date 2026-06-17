import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';

void main() {
  ClaimUnit u(double cost, List<String> claimers) =>
      ClaimUnit(unitCost: cost, claimers: claimers);

  group('buildClaimSummary', () {
    test('totals: claimed, unclaimed and grand total', () {
      final summary = buildClaimSummary(
        units: [u(5.0, ['sam@x']), u(4.0, []), u(6.0, ['priya@x'])],
        personaEmail: 'sam@x',
      );
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
        buildClaimSummary(units: units, personaEmail: 'sam@x').yourShare,
        8.0, // 5 + 3
      );
      expect(
        buildClaimSummary(units: units, personaEmail: 'priya@x').yourShare,
        3.0,
      );
    });

    test('yourShare is zero when the persona has claimed nothing', () {
      final summary = buildClaimSummary(
        units: [u(5.0, ['sam@x'])],
        personaEmail: 'nobody@x',
      );
      expect(summary.yourShare, 0.0);
    });

    test('progress is claimed / total, clamped and safe for an empty receipt', () {
      expect(
        buildClaimSummary(units: [u(4.0, ['a']), u(4.0, [])], personaEmail: 'a')
            .progress,
        0.5,
      );
      // No units at all -> no division-by-zero, progress 0.
      expect(
        buildClaimSummary(units: const [], personaEmail: 'a').progress,
        0.0,
      );
    });

    test('memberTotals are ordered by amount desc with persona pinned first', () {
      final summary = buildClaimSummary(
        units: [
          u(10.0, ['big@x']),
          u(2.0, ['me@x']),
          u(6.0, ['mid@x']),
        ],
        personaEmail: 'me@x',
      );
      expect(summary.memberTotals.map((e) => e.email).toList(),
          ['me@x', 'big@x', 'mid@x']);
      expect(summary.memberTotals.first.amount, 2.0);
    });

    test('isFullyClaimed / isEmpty flags', () {
      expect(
        buildClaimSummary(units: [u(5.0, ['a'])], personaEmail: 'a')
            .isFullyClaimed,
        isTrue,
      );
      expect(
        buildClaimSummary(units: [u(5.0, [])], personaEmail: 'a')
            .isFullyClaimed,
        isFalse,
      );
      expect(
        buildClaimSummary(units: const [], personaEmail: 'a').isEmpty,
        isTrue,
      );
    });
  });
}
