import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/presentation/friend_list.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [FriendshipListNotifier] that skips realtime/supabase wiring and returns a
/// fixed [state] synchronously.
class _FakeFriendshipListNotifier extends FriendshipListNotifier {
  _FakeFriendshipListNotifier(this._state);

  final FriendshipListState _state;

  @override
  Future<FriendshipListState> build() async => _state;
}

Friendship _friend(String name, String email, {double shareAmount = 0}) {
  final f = Friendship();
  f.user = SupaUser(email: email, displayName: name, username: name.toLowerCase(), usernameCode: '0001');
  f.status = 'accepted';
  f.isIncomingRequest = false;
  f.shareAmount = shareAmount;
  return f;
}

Future<void> _pumpFriendList(
  WidgetTester tester,
  FriendshipListState state, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendshipListProvider.overrideWith(() => _FakeFriendshipListNotifier(state)),
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
            data: getThemeData(context, kBrandSeed, brightness),
            child: const FriendList(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header shows QR and add buttons', (tester) async {
    await _pumpFriendList(tester, const FriendshipListState());
    expect(find.byIcon(Icons.qr_code), findsOneWidget);
    expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
  });

  testWidgets('incoming request renders accept and decline actions',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        pendingIncomingRequests: [_friend('Priya Nair', 'priya@x.com')],
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text(l10n.accept), findsOneWidget);
    // Decline is the trailing close icon button.
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('outgoing request renders a cancel action', (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        pendingOutgoingRequests: [_friend('Sam Lee', 'sam@x.com')],
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text(l10n.cancel), findsOneWidget);
  });

  testWidgets('accepted friends render with semantic balance pills',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        acceptedFriends: [
          _friend('Owed Friend', 'owed@x.com', shareAmount: 20),
          _friend('Owe Friend', 'owe@x.com', shareAmount: -15),
          _friend('Even Friend', 'even@x.com', shareAmount: 0),
        ],
      ),
    );
    expect(find.byType(BalancePill), findsNWidgets(3));
    expect(find.byType(MemberAvatar), findsNWidgets(3));

    final pills = tester.widgetList<BalancePill>(find.byType(BalancePill)).toList();
    expect(pills[0].state, BalanceState.owed);
    expect(pills[1].state, BalanceState.owe);
    expect(pills[2].state, BalanceState.settled);

    // V3: every accepted-friend row ends in a trailing chevron signalling it
    // opens the friend sheet (one per accepted row).
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
  });

  testWidgets('empty state shows the no-friends message', (tester) async {
    await _pumpFriendList(tester, const FriendshipListState());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.friendsNoEntries), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        acceptedFriends: [_friend('Dark Friend', 'dark@x.com', shareAmount: 5)],
      ),
      brightness: Brightness.dark,
    );
    expect(find.text('Dark Friend'), findsOneWidget);
    expect(find.byType(BalancePill), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // V3-T5: Staggered list entrance
  // -------------------------------------------------------------------------

  testWidgets('friend cards are fully visible after pumpAndSettle (stagger completes)', (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        acceptedFriends: [
          _friend('Alice', 'alice@x.com', shareAmount: 10),
          _friend('Bob', 'bob@x.com', shareAmount: -5),
        ],
      ),
    );

    // All cards visible — entrance animation must have completed.
    expect(find.byType(BalancePill), findsNWidgets(2));
    // The AnimationLimiter must be in the tree.
    expect(find.byType(AnimationLimiter), findsOneWidget);
  });

  testWidgets(
      'friend list is visible immediately with disableAnimations=true (reduced motion)', (tester) async {
    final state = FriendshipListState(
      acceptedFriends: [_friend('Alice', 'alice@x.com', shareAmount: 10)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendshipListProvider.overrideWith(() => _FakeFriendshipListNotifier(state)),
        ],
        child: MaterialApp(
          // Use builder to inject MediaQuery override *inside* MaterialApp so it
          // takes effect after MaterialApp's own MediaQuery is established.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Theme(
              data: getThemeData(context, kBrandSeed, Brightness.light),
              child: const FriendList(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(BalancePill), findsOneWidget);
    // In reduced-motion mode there is no AnimationLimiter wrapper.
    expect(find.byType(AnimationLimiter), findsNothing);
  });
}
