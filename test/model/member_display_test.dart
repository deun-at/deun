// injectable-repositories: one helper names members on every surface.

import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:flutter_test/flutter_test.dart';

GroupMember _member(String email, String name, {bool removed = false}) =>
    GroupMember()
      ..groupId = 'g1'
      ..email = email
      ..displayName = name
      ..isGuest = false
      ..isFavorite = false
      ..removedAt = removed ? DateTime.utc(2026, 8, 15) : null;

final _roster = [
  _member('me@test.com', 'Mia'),
  _member('ann@test.com', 'Ann'),
  _member('carol@test.com', 'Carol', removed: true),
  _member('guest+1@guest.invalid', 'Gus'),
];

MemberDisplay _display(String? currentUserEmail) => MemberDisplay(
  currentUserEmail: currentUserEmail,
  youLabel: 'You',
  roster: _roster,
);

void main() {
  test(
    'the signed-in user reads You and every other member their display name',
    () {
      final display = _display('me@test.com');
      expect(display.nameOf('me@test.com'), 'You');
      expect(display.isYou('me@test.com'), isTrue);
      expect(display.nameOf('ann@test.com'), 'Ann');
      expect(display.isYou('ann@test.com'), isFalse);
      expect(
        display.nameOf('carol@test.com'),
        'Carol',
        reason: 'soft-removed, still on past expenses',
      );
      expect(display.nameOf('guest+1@guest.invalid'), 'Gus');
    },
  );

  test(
    'an email that is not on the roster reads as that email, never blank',
    () {
      expect(_display('me@test.com').nameOf('gone@test.com'), 'gone@test.com');
    },
  );

  test('with nobody signed in, nobody reads You', () {
    final display = _display(null);
    for (final member in _roster) {
      expect(display.isYou(member.email), isFalse, reason: member.email);
      expect(
        display.nameOf(member.email),
        member.displayName,
        reason: member.email,
      );
    }
  });

  test('pickers offer active members only; the roster keeps removed ones', () {
    final display = _display('me@test.com');
    expect(
      display.pickerMembers.map((m) => m.email),
      unorderedEquals(['me@test.com', 'ann@test.com', 'guest+1@guest.invalid']),
    );
    expect(
      display.rosterMembers.map((m) => m.email),
      unorderedEquals(_roster.map((m) => m.email)),
    );
  });
}
