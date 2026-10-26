// injectable-repositories: the star on a group card is the signed-in user's
// own membership row: another member's star never shows, and a tap writes the
// flipped flag through the member repository built for the signed-in user.

import 'package:deun/constants.dart';
import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/member_repository.dart';
import 'package:deun/pages/groups/presentation/group_list.dart';
import 'package:deun/pages/groups/presentation/group_list_item.dart';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helper/fake_realtime_channel_factory.dart';

const _me = CurrentUser(id: 'me-id', email: 'me@test.com');
const _sam = 'sam@test.com';

GroupMember _member(String email, {required bool favorite}) => GroupMember()
  ..groupId = 'g1'
  ..email = email
  ..displayName = email.split('@').first
  ..isGuest = false
  ..isFavorite = favorite;

Group _group() => Group()
  ..id = 'g1'
  ..name = 'Trip'
  ..colorValue = kGroupColorPalette.first.toARGB32()
  ..simplifiedExpenses = true
  ..createdAt = ''
  ..userId = null
  ..groupMembers = [
    _member(_me.email, favorite: false),
    _member(_sam, favorite: true),
  ]
  ..expenses = null;

class _Groups implements GroupRepository {
  _Groups(this.group);

  final Group group;

  @override
  Future<List<Group>> fetchData(String statusFilter, {String? paidTo}) async =>
      [group];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

/// Records each favourite write with the account the repository acts for.
class _Members implements MemberRepository {
  _Members(this.actingAs, this.writes);

  final CurrentUser? actingAs;
  final List<(String?, String, bool)> writes;

  @override
  Future<void> toggleFavorite(String groupId, bool isFavorite) async =>
      writes.add((actingAs?.email, groupId, isFavorite));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Me extends UserDetailNotifier {
  @override
  Future<SupaUser> build() async =>
      const SupaUser(email: 'me@test.com', displayName: 'Mia');
}

void main() {
  testWidgets(
    "a group starred only by another member reads unstarred, and the star writes the signed-in user's own row",
    (tester) async {
      final group = _group();
      final writes = <(String?, String, bool)>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_me),
            realtimeChannelFactoryProvider.overrideWithValue(
              FakeRealtimeChannelFactory(),
            ),
            groupRepositoryProvider.overrideWithValue(_Groups(group)),
            memberRepositoryProvider.overrideWith(
              (ref) => _Members(ref.watch(currentUserProvider), writes),
            ),
            userDetailProvider.overrideWith(_Me.new),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Theme(
                data: getThemeData(
                  context,
                  kBrandSeed,
                  Brightness.light,
                ).copyWith(splashFactory: NoSplash.splashFactory),
                child: const GroupList(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      GroupListItem card() =>
          tester.widget<GroupListItem>(find.byType(GroupListItem));
      expect(card().isFavorite, isFalse, reason: "Sam's star is not mine");

      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();

      expect(writes, [(_me.email, 'g1', true)]);
      expect(card().isFavorite, isTrue);
      expect(
        group.groupMembers.singleWhere((m) => m.email == _sam).isFavorite,
        isTrue,
        reason: "Sam's own star is untouched",
      );
    },
  );
}
