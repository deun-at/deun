import 'dart:convert';
import 'dart:io';

import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _newKeys = <String>[
  'groupMembersSearchHint',
  'groupMemberCountLabel',
  'groupMemberAddError',
  'groupMemberAlreadyInGroup',
  'groupMemberGuestNameLabel',
  'groupMemberGuestCreateButton',
  'groupMemberGuestCreateError',
  'groupMembersEmptyCtaTitle',
  'groupMembersEmptyCtaBody',
];

const _retiredKeys = <String>[
  'groupMemberSelectionEmpty',
  'groupMemberSelectionTitle',
  'groupMemberResultEmpty',
  'groupMemberAddFriends',
  'groupMemberAddGuestLink',
  'groupMemberOwnerTag',
  'groupMemberRemoveSuccess',
  'groupMemberRemovedSectionTitle',
  'groupMemberReAdd',
  'groupMemberRemoveBlocked',
];

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    de = await AppLocalizations.delegate.load(const Locale('de'));
  });

  test('every new members-flow key exists in both locales', () {
    final enArb = _arb('lib/l10n/app_en.arb');
    final deArb = _arb('lib/l10n/app_de.arb');

    for (final key in _newKeys) {
      expect(
        enArb.containsKey(key),
        isTrue,
        reason: '$key missing from app_en.arb',
      );
      expect(
        deArb.containsKey(key),
        isTrue,
        reason: '$key missing from app_de.arb',
      );
    }
  });

  test('every retired members-flow key is gone from both locales', () {
    final enArb = _arb('lib/l10n/app_en.arb');
    final deArb = _arb('lib/l10n/app_de.arb');

    for (final key in _retiredKeys) {
      expect(
        enArb.containsKey(key),
        isFalse,
        reason: '$key still in app_en.arb',
      );
      expect(
        enArb.containsKey('@$key'),
        isFalse,
        reason: '@$key metadata still in app_en.arb',
      );
      expect(
        deArb.containsKey(key),
        isFalse,
        reason: '$key still in app_de.arb',
      );
    }
  });

  test('the German copy is German, not the English string copied over', () {
    expect(de.groupMemberGuestCreateButton, 'Gast erstellen');
    expect(
      de.groupMemberGuestCreateButton,
      isNot(en.groupMemberGuestCreateButton),
    );
    expect(de.groupMemberCountLabel(2), '2 Mitglieder');
    expect(en.groupMemberCountLabel(1), '1 member');
    expect(de.groupMemberCountLabel(1), '1 Mitglied');
    expect(en.groupMembersSearchHint, isNot(de.groupMembersSearchHint));
    expect(en.groupMemberAddError('Ann'), isNot(de.groupMemberAddError('Ann')));
  });
}
