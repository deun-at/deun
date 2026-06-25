import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/presentation/friend_qr_page.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

SupaUser _fakeUser() => const SupaUser(
      email: 'maya@deun.app',
      displayName: 'Maya Okonkwo',
      username: 'maya',
      usernameCode: '4821',
    );

/// A [UserDetailNotifier] that returns a fixed user synchronously, skipping the
/// supabase fetch.
class _FakeUserDetailNotifier extends UserDetailNotifier {
  _FakeUserDetailNotifier(this._user);

  final SupaUser _user;

  @override
  Future<SupaUser> build() async => _user;
}

Future<void> _pumpQr(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  SupaUser? user,
  Locale? locale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userDetailProvider.overrideWith(() => _FakeUserDetailNotifier(user ?? _fakeUser())),
      ],
      child: MaterialApp(
        locale: locale,
        theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
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
            child: const FriendQrPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('buildFriendQrLink', () {
    test('encodes username and code into the accept deep link', () {
      final link = FriendQrPage.buildFriendQrLink(_fakeUser());
      expect(link, isNotNull);
      final s = link!.toString();
      expect(s, contains('/#/friend/accept'));
      expect(s, contains('u=maya'));
      expect(s, contains('c=4821'));
    });

    test('returns null when username or code is missing', () {
      const user = SupaUser(email: 'x@y.z', displayName: 'No Handle');
      expect(FriendQrPage.buildFriendQrLink(user), isNull);
    });
  });

  group('FriendQrPage (restyled)', () {
    testWidgets('renders the My code / Scan segmented control', (tester) async {
      await _pumpQr(tester);
      expect(find.byType(AppSegmentedControl<int>), findsOneWidget);
    });

    testWidgets('My code tab shows the QR, profile and Copy/Share actions',
        (tester) async {
      await _pumpQr(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(FriendQrPage)))!;

      // QR rendered.
      expect(find.byType(QrImageView), findsOneWidget);
      // Profile row: avatar + name + @handle.
      expect(find.byType(MemberAvatar), findsOneWidget);
      expect(find.text('Maya Okonkwo'), findsOneWidget);
      expect(find.text('@maya#4821'), findsOneWidget);
      // Copy + Share actions.
      expect(find.text(l10n.copyLink), findsOneWidget);
      expect(find.text(l10n.share), findsOneWidget);
    });

    testWidgets(
        'Copy is a SecondaryButton and Share a PrimaryButton (radius-15, not stadium pills)',
        (tester) async {
      await _pumpQr(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(FriendQrPage)))!;

      // Copy = secondary (white + hairline border); Share = primary (solid indigo).
      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      // The copy label lives inside the SecondaryButton, share inside the primary.
      expect(
        find.descendant(
          of: find.byType(SecondaryButton),
          matching: find.text(l10n.copyLink),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.text(l10n.share),
        ),
        findsOneWidget,
      );
      // No leftover stadium-pill FilledButtons for these two actions.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the German "Link kopieren" label stays on a single line',
        (tester) async {
      await _pumpQr(tester, locale: const Locale('de'));
      final text = tester.widget<Text>(find.text('Link kopieren'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      // And it must actually fit — no ellipsis truncation at the row width.
      final painter = TextPainter(
        text: TextSpan(text: 'Link kopieren', style: text.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      expect(painter.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text('Link kopieren')).width,
          greaterThanOrEqualTo(painter.width));
    });

    testWidgets('renders in dark mode without throwing (QR still present)',
        (tester) async {
      await _pumpQr(tester, brightness: Brightness.dark);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(AppSegmentedControl<int>), findsOneWidget);
    });

    testWidgets('switching to Scan renders the viewfinder chrome', (tester) async {
      await _pumpQr(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(FriendQrPage)))!;

      await tester.tap(find.text(l10n.friendQrTabScan));
      await tester.pumpAndSettle();

      // The scan prompt is shown over the viewfinder; no throw on camera chrome.
      expect(find.text(l10n.friendQrScanPrompt), findsOneWidget);
      // QR (My code) is no longer shown.
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('scan controls expose localized semantics labels', (tester) async {
      await _pumpQr(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(FriendQrPage)))!;

      await tester.tap(find.text(l10n.friendQrTabScan));
      await tester.pumpAndSettle();

      // Torch + camera-switch + copy controls must announce themselves.
      expect(find.bySemanticsLabel(l10n.friendQrTorchToggle), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.friendQrSwitchCamera), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.copyLink), findsOneWidget);
    });

    testWidgets('scan controls have >=48dp hit targets', (tester) async {
      await _pumpQr(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(FriendQrPage)))!;

      await tester.tap(find.text(l10n.friendQrTabScan));
      await tester.pumpAndSettle();

      for (final icon in [Icons.flash_on, Icons.cameraswitch, Icons.link]) {
        final target = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(InkResponse),
        );
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('tapping Copy writes the friend link to the clipboard',
        (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await _pumpQr(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(FriendQrPage)))!;

      await tester.tap(find.text(l10n.copyLink));
      await tester.pumpAndSettle();

      final clipboardCall = calls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
        orElse: () => const MethodCall('none'),
      );
      expect(clipboardCall.method, 'Clipboard.setData');
      final text = (clipboardCall.arguments as Map)['text'] as String;
      expect(text, contains('u=maya'));
    });
  });
}
