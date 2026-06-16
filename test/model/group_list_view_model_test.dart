import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a bare [Group] with just the fields the view-model logic reads.
/// Favorite state is supplied to the pure functions via a predicate (see below)
/// rather than the Supabase-backed [Group.isFavorite] getter, so these tests
/// stay free of auth state.
Group _group({
  required String id,
  required String name,
  double totalShareAmount = 0,
}) {
  final g = Group();
  g.id = id;
  g.name = name;
  g.colorValue = 0xFF5750E6;
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = totalShareAmount;
  g.expenses = null;
  return g;
}

void main() {
  group('sortGroups', () {
    test('orders fav-unsettled, fav-settled, unsettled, settled', () {
      final favSettled = _group(id: 'a', name: 'A', totalShareAmount: 0);
      final settled = _group(id: 'b', name: 'B', totalShareAmount: 0);
      final favUnsettled = _group(id: 'c', name: 'C', totalShareAmount: 12);
      final unsettled = _group(id: 'd', name: 'D', totalShareAmount: -5);

      final favorites = {'a', 'c'};
      final input = [settled, favSettled, unsettled, favUnsettled];
      final sorted = sortGroups(input, isFavorite: (g) => favorites.contains(g.id));

      expect(sorted.map((g) => g.id).toList(), ['c', 'a', 'd', 'b']);
    });

    test('treats sub-cent balances as settled', () {
      final almostSettled = _group(id: 'a', name: 'A', totalShareAmount: 0.004);
      final unsettled = _group(id: 'b', name: 'B', totalShareAmount: 0.02);

      final sorted = sortGroups([almostSettled, unsettled], isFavorite: (_) => false);

      // unsettled (>= 0.01) sorts before the effectively-settled one.
      expect(sorted.map((g) => g.id).toList(), ['b', 'a']);
    });

    test('breaks ties by case-insensitive name', () {
      final beta = _group(id: 'a', name: 'beta', totalShareAmount: 10);
      final alpha = _group(id: 'b', name: 'Alpha', totalShareAmount: 10);

      final sorted = sortGroups([beta, alpha], isFavorite: (_) => false);

      expect(sorted.map((g) => g.id).toList(), ['b', 'a']);
    });

    test('does not mutate the input list', () {
      final a = _group(id: 'a', name: 'A', totalShareAmount: 0);
      final b = _group(id: 'b', name: 'B', totalShareAmount: 10);
      final input = [a, b];

      sortGroups(input, isFavorite: (_) => false);

      expect(input.map((g) => g.id).toList(), ['a', 'b']);
    });
  });

  group('aggregateOverallBalance', () {
    test('sums positive nets into owed and negative nets into owe', () {
      final groups = [
        _group(id: 'a', name: 'A', totalShareAmount: 12.50),
        _group(id: 'b', name: 'B', totalShareAmount: -4.25),
        _group(id: 'c', name: 'C', totalShareAmount: 7.75),
      ];

      final agg = aggregateOverallBalance(groups);

      expect(agg.owed, 20.25);
      expect(agg.owe, 4.25);
      expect(agg.net, 16.0);
    });

    test('ignores sub-cent balances', () {
      final groups = [
        _group(id: 'a', name: 'A', totalShareAmount: 0.004),
        _group(id: 'b', name: 'B', totalShareAmount: -0.003),
      ];

      final agg = aggregateOverallBalance(groups);

      expect(agg.owed, 0);
      expect(agg.owe, 0);
      expect(agg.net, 0);
    });

    test('empty list yields zero totals', () {
      final agg = aggregateOverallBalance(const <Group>[]);
      expect(agg.owed, 0);
      expect(agg.owe, 0);
      expect(agg.net, 0);
    });

    test('owe is reported as a positive magnitude', () {
      final groups = [_group(id: 'a', name: 'A', totalShareAmount: -10)];
      final agg = aggregateOverallBalance(groups);
      expect(agg.owe, 10);
      expect(agg.net, -10);
    });
  });
}
