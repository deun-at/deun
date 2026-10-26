import 'dart:io';

import 'package:deun/helper/search_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const _names = [
  '50% off',
  '500 EUR',
  '50 EUR',
  'a_b',
  'axb',
  'a*b',
  'ab',
  'aab',
  'a long b',
  r'a\b',
  r'50\',
  'Taxi',
  'Taxi (1)',
  'v1.2',
  'abc',
  'Café Müller',
];

/// The names the escaped value matches, through the Dart RegExp proxy for
/// PostgREST `imatch` (Postgres `~*`): case-insensitive, unanchored.
List<String> _found(String typed, [List<String> names = _names]) {
  final filter = literalSearchFilter(typed);
  expect(filter.operator, 'imatch');
  final pattern = RegExp(filter.value, caseSensitive: false);
  return names.where(pattern.hasMatch).toList();
}

void main() {
  test('% and _ match only themselves', () {
    expect(literalSearchFilter('50%').value, '50%');
    expect(literalSearchFilter('a_b').value, 'a_b');
    expect(_found('50%'), ['50% off']);
    expect(_found('a_b'), ['a_b']);
  });

  test('* matches only itself', () {
    expect(literalSearchFilter('a*b').value, r'a\*b');
    expect(_found('a*b'), ['a*b']);
  });

  test('a backslash matches only a backslash', () {
    expect(literalSearchFilter(r'a\b').value, r'a\\b');
    expect(literalSearchFilter(r'50\').value, r'50\\');
    expect(_found(r'a\b'), [r'a\b']);
    expect(_found(r'50\'), [r'50\']);
  });

  test('every regex metacharacter matches only itself and never fails', () {
    expect(literalSearchFilter('(1').value, r'\(1');
    expect(literalSearchFilter('[x').value, r'\[x');
    expect(_found('.'), ['v1.2']);
    expect(_found('(1'), ['Taxi (1)']);

    for (final c in r'\.^$*+?()[]{}|'.split('')) {
      final value = literalSearchFilter(c).value;
      expect(value, '\\$c', reason: c);
      expect(_found(c, ['x${c}y', 'xy', 'abc']), ['x${c}y'], reason: c);
      expect(_found('a$c', ['a${c}b', 'ab', 'a']), ['a${c}b'], reason: c);
    }
  });

  test('ordinary text matches itself, ignoring case', () {
    expect(literalSearchFilter('TAXI').value, 'TAXI');
    expect(literalSearchFilter('müller').value, 'müller');
    expect(literalSearchFilter('Café Müller 2').value, 'Café Müller 2');
    expect(literalSearchFilter('🚕 ride').value, '🚕 ride');
    expect(_found('TAXI'), ['Taxi', 'Taxi (1)']);
    expect(_found('müller'), ['Café Müller']);
  });

  test('the expense search sends only the escaped, literal filter', () {
    final source = File(
      'lib/pages/expenses/data/expense_repository.dart',
    ).readAsStringSync();
    expect(source, contains('literalSearchFilter('));
    expect(source, isNot(matches(RegExp(r"\b(i?like)\(\s*'name'"))));
  });
}
