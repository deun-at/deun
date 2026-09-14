import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every key the shared empty state adds. Both locales must carry all of them —
/// a headline shipped in English only is a blank screen in German.
const _newKeys = <String>[
  'emptyGroupsHeadline',
  'emptyGroupsBody',
  'emptyExpensesHeadline',
  'emptyExpensesBody',
  'emptyFriendsHeadline',
  'emptyFriendsBody',
  'emptyErrorHeadline',
  'emptyErrorBody',
];

/// The four keys the shared empty state replaces. `expenseNoEntries` was
/// already dead; the other three each had exactly one caller.
const _retiredKeys = <String>[
  'expenseNoEntries',
  'groupNoEntries',
  'groupExpenseNoEntries',
  'friendsNoEntries',
];

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> de;

  setUpAll(() {
    en = _arb('lib/l10n/app_en.arb');
    de = _arb('lib/l10n/app_de.arb');
  });

  // AC8 — every new key is present in BOTH ARB files.
  test('every new empty-state key exists in both locales', () {
    for (final key in _newKeys) {
      expect(
        en.containsKey(key),
        isTrue,
        reason: '$key missing from app_en.arb',
      );
      expect(
        de.containsKey(key),
        isTrue,
        reason: '$key missing from app_de.arb',
      );
      expect(
        (en[key] as String).trim(),
        isNotEmpty,
        reason: '$key is blank in app_en.arb',
      );
      expect(
        (de[key] as String).trim(),
        isNotEmpty,
        reason: '$key is blank in app_de.arb',
      );
    }
  });

  // AC8 — the German copy is German, not the English string carried over.
  test('the German empty-state copy is translated, not copied', () {
    for (final key in _newKeys) {
      expect(de[key], isNot(en[key]), reason: '$key is untranslated');
    }
  });

  // AC8 — every retired key is absent from both files, metadata included.
  test('every retired empty-state key is gone from both locales', () {
    for (final key in _retiredKeys) {
      expect(en.containsKey(key), isFalse, reason: '$key still in app_en.arb');
      expect(
        en.containsKey('@$key'),
        isFalse,
        reason: '@$key metadata still in app_en.arb',
      );
      expect(de.containsKey(key), isFalse, reason: '$key still in app_de.arb');
    }
  });

  // AC8 — the keys the empty states reuse rather than re-inventing must still
  // be in both files, so the sweep did not overshoot.
  test('the reused action keys survive in both locales', () {
    for (final key in const [
      'retry',
      'addNewGroup',
      'expenseAddButton',
      'addFriends',
    ]) {
      expect(
        en.containsKey(key),
        isTrue,
        reason: '$key missing from app_en.arb',
      );
      expect(
        de.containsKey(key),
        isTrue,
        reason: '$key missing from app_de.arb',
      );
    }
  });
}
