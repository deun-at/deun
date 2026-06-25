import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/presentation/friend_list.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
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

/// The [SemanticColors] theme extension resolved from the friend list subtree.
SemanticColors _semanticColors(WidgetTester tester) {
  final context = tester.element(find.byType(FriendList));
  return Theme.of(context).extension<SemanticColors>()!;
}

/// The color the balance label [text] is rendered in (its plain-text tint).
Color? _balanceLabelColor(WidgetTester tester, String text) {
  final widget = tester.widget<Text>(find.text(text));
  return widget.style?.color;
}

void main() {
  testWidgets('header shows a tinted QR action and a filled accent add action',
      (tester) async {
    await _pumpFriendList(tester, const FriendshipListState());

    // Both header actions are the shared 38×38 HeaderIconButton.
    expect(find.byIcon(Icons.qr_code), findsOneWidget);
    expect(find.byIcon(Icons.person_add), findsOneWidget);

    final qr = tester.widget<HeaderIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.qr_code),
        matching: find.byType(HeaderIconButton),
      ),
    );
    final add = tester.widget<HeaderIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.person_add),
        matching: find.byType(HeaderIconButton),
      ),
    );

    // QR is the tinted (secondary) variant; add-friend is the filled accent
    // (primary) variant.
    expect(qr.filled, isFalse);
    expect(add.filled, isTrue);

    // The filled accent circle paints colorScheme.primary with an onPrimary
    // icon (legible); the tinted circle paints the warm-tint surface.
    final context = tester.element(find.byType(FriendList));
    final colorScheme = Theme.of(context).colorScheme;

    final addContainer = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.person_add),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      (addContainer.decoration as BoxDecoration).color,
      colorScheme.primary,
    );
    final addIcon = tester.widget<Icon>(find.byIcon(Icons.person_add));
    expect(addIcon.color, colorScheme.onPrimary);

    final qrContainer = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.qr_code),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      (qrContainer.decoration as BoxDecoration).color,
      colorScheme.onSurface.withValues(alpha: 0.04),
    );
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

  testWidgets('accepted friends render plain semantic-colored balance text',
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

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // V3: plain colored balance TEXT, not a filled chip/pill.
    expect(find.byType(BalancePill), findsNothing);
    expect(find.byType(MemberAvatar), findsNWidgets(3));

    // Each settlement state renders its localized balance label as plain text.
    expect(find.text(l10n.balanceOwed), findsOneWidget); // "You're owed"
    expect(find.text(l10n.balanceOwe), findsOneWidget); // "You owe"
    expect(find.text(l10n.balanceSettled), findsOneWidget); // "Settled up"

    // The balance text is tinted by the semantic token: green (success) for the
    // owed friend, red (danger) for the owe friend, neutral for settled.
    final semantic = _semanticColors(tester);
    expect(_balanceLabelColor(tester, l10n.balanceOwed), semantic.success);
    expect(_balanceLabelColor(tester, l10n.balanceOwe), semantic.danger);

    // Settled rows render NO amount (label only) — owed/owe rows render an amount
    // alongside (MoneyText), colored to match.
    expect(find.byType(MoneyText), findsNWidgets(2));

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
    // Plain colored balance text (owed → MoneyText amount), no pill, in dark mode.
    expect(find.byType(BalancePill), findsNothing);
    expect(find.byType(MoneyText), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      _balanceLabelColor(tester, l10n.balanceOwed),
      _semanticColors(tester).success,
    );
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
    expect(find.byType(MoneyText), findsNWidgets(2));
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

    expect(find.byType(MoneyText), findsOneWidget);
    // In reduced-motion mode there is no AnimationLimiter wrapper.
    expect(find.byType(AnimationLimiter), findsNothing);
  });
}
