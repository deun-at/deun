import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/presentation/friend_list.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/card_list_view_builder.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
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

  // -------------------------------------------------------------------------
  // F167: all-friends is ONE joined SoftCard (radius 22, no inter-row gap) —
  // the same _DaySection pattern as the group-detail ledger, replacing the
  // legacy CardColumn/CardListTile chrome (10px inset, 2px gaps, 28/8 radii).
  // The request sections stay on the SPACED preset (per-card SoftCard w/ gaps).
  // -------------------------------------------------------------------------

  testWidgets('all-friends renders as ONE joined SoftCard (radius 22, no inter-row gap)',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        acceptedFriends: [
          _friend('Alice', 'alice@x.com', shareAmount: 10),
          _friend('Bob', 'bob@x.com', shareAmount: -5),
        ],
      ),
    );

    // The legacy CardColumn/Card chrome is gone; the section is a single SoftCard.
    expect(find.byType(CardColumn), findsNothing);
    final softCard = tester.widget<SoftCard>(find.byType(SoftCard));
    expect(softCard.borderRadius, 22, reason: 'v3 all-friends radius');

    // Joined: consecutive friend rows sit flush (no inter-row gap). The bottom of
    // Alice's InkWell row touches the top of Bob's.
    final aliceRow = tester.getRect(find.ancestor(
      of: find.text('Alice'),
      matching: find.byType(InkWell),
    ).first);
    final bobRow = tester.getRect(find.ancestor(
      of: find.text('Bob'),
      matching: find.byType(InkWell),
    ).first);
    expect((bobRow.top - aliceRow.bottom).abs(), lessThan(0.5),
        reason: 'joined rows have no vertical gap between them');
  });

  testWidgets('friend requests use the SPACED SoftCard preset (gapped cards)',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        pendingIncomingRequests: [_friend('Req One', 'r1@x.com')],
        pendingOutgoingRequests: [_friend('Req Two', 'r2@x.com')],
      ),
    );

    // Requests are per-card SoftCards (the SPACED preset), not a joined column.
    expect(find.byType(SoftCard), findsNWidgets(2));
    // No accepted friends here → no all-friends card.
    expect(find.byType(CardColumn), findsNothing);
  });

  testWidgets('accepted friend row lays the balance RIGHT of the name, not beneath it (F95)',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        acceptedFriends: [_friend('Owed Friend', 'owed@x.com', shareAmount: 20)],
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    final nameRect = tester.getRect(find.text('Owed Friend'));
    final labelRect = tester.getRect(find.text(l10n.balanceOwed));
    final amountRect = tester.getRect(find.byType(MoneyText));

    // Balance label + amount sit to the RIGHT of the name (trailing edge of the
    // row), NOT stacked beneath it in a subtitle column.
    expect(labelRect.left, greaterThan(nameRect.right),
        reason: 'balance label must be right of the name, not beneath it');
    expect(amountRect.left, greaterThan(labelRect.left),
        reason: 'amount trails the label on the right');

    // Same-row placement: their vertical centers align (not stacked vertically).
    expect((labelRect.center.dy - nameRect.center.dy).abs(), lessThan(nameRect.height),
        reason: 'balance shares the row baseline with the name');

    // The trailing chevron is the right-most element (balance is left of it).
    final chevronRect = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(amountRect.right, lessThan(chevronRect.left));
  });

  // -------------------------------------------------------------------------
  // F92: section wordings match the v3 handoff — incoming = "N friend
  // request(s)" (count-prefixed, pluralized), outgoing = "Pending (N)".
  // -------------------------------------------------------------------------

  testWidgets('section labels match the v3 handoff copy (F92)', (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        pendingIncomingRequests: [
          _friend('Req One', 'r1@x.com'),
          _friend('Req Two', 'r2@x.com'),
        ],
        pendingOutgoingRequests: [_friend('Out One', 'o1@x.com')],
      ),
    );

    // Incoming header: count-prefixed + pluralized ("2 friend requests").
    expect(find.text('2 friend requests'), findsOneWidget);
    // Outgoing header: "Pending (1)".
    expect(find.text('Pending (1)'), findsOneWidget);
    // Old wordings are gone.
    expect(find.text('Friend Requests (2)'), findsNothing);
    expect(find.text('Pending Requests (1)'), findsNothing);
  });

  testWidgets('incoming header uses singular form for a single request (F92)',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        pendingIncomingRequests: [_friend('Solo', 'solo@x.com')],
      ),
    );
    expect(find.text('1 friend request'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // F97: no FAB on this screen → no reserved bottom space. The list ends with a
  // normal 16px bottom margin, not the 110px FAB reservation.
  // -------------------------------------------------------------------------

  testWidgets('friends list has no extra reserved bottom padding (F97)',
      (tester) async {
    await _pumpFriendList(
      tester,
      FriendshipListState(
        acceptedFriends: [_friend('Alice', 'alice@x.com', shareAmount: 10)],
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(16, 0, 16, 16),
      reason: 'bottom padding must not reserve space for a removed FAB',
    );
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
