import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_invite_page.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

Group _fakeGroup() => Group()
  ..id = 'grp-123'
  ..name = 'Trip to Rome';

Future<void> _pumpInvite(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // NoSplash avoids loading the ink ripple fragment shader, which the test
      // engine can't decode; getThemeData inherits this splash factory.
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
          // The invite sheet is presented above the app shell, which always
          // provides a descendant Scaffold for snackbars; mirror that here.
          child: Scaffold(body: GroupInvitePage(group: _fakeGroup())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('buildGroupInviteLink', () {
    test('encodes the group id and name into the join deep link', () {
      final link = GroupInvitePage.buildGroupInviteLink(_fakeGroup());
      final s = link.toString();
      expect(s, contains('/#/group/join'));
      expect(s, contains('groupId=grp-123'));
      // Space in the name must be percent-encoded.
      expect(s, contains('name=Trip%20to%20Rome'));
    });
  });

  group('GroupInvitePage (restyled)', () {
    testWidgets(
        'surfaces the link first with copy/share; QR is behind a toggle',
        (tester) async {
      await _pumpInvite(tester);

      expect(find.byType(SheetScaffold), findsOneWidget);

      final l10n = AppLocalizations.of(
          tester.element(find.byType(GroupInvitePage)))!;
      // The link is the primary surface, with the join subtitle.
      expect(find.text(l10n.groupInviteSubtitle), findsOneWidget);
      expect(find.textContaining('grp-123'), findsOneWidget);
      // Copy and the primary "Share link" controls render.
      expect(find.text(l10n.copyLink), findsOneWidget);
      expect(find.text(l10n.inviteShareLink), findsOneWidget);

      // QR is secondary: hidden until a toggle is tapped. Both the in-body
      // "Show QR code" toggle and the footer "QR" button are present.
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(l10n.groupInviteShowQr), findsOneWidget);
      expect(find.text(l10n.inviteQrButton), findsOneWidget);

      await tester.tap(find.text(l10n.groupInviteShowQr));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(l10n.groupInviteHideQr), findsOneWidget);
    });

    testWidgets('footer QR button reveals the QR code', (tester) async {
      await _pumpInvite(tester);
      final l10n = AppLocalizations.of(
          tester.element(find.byType(GroupInvitePage)))!;

      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.text(l10n.inviteQrButton));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await _pumpInvite(tester, brightness: Brightness.dark);
      expect(find.byType(SheetScaffold), findsOneWidget);

      final l10n = AppLocalizations.of(
          tester.element(find.byType(GroupInvitePage)))!;
      // Reveal the QR to exercise its dark-mode render path.
      await tester.tap(find.text(l10n.groupInviteShowQr));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('tapping Copy writes the invite link to the clipboard',
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

      await _pumpInvite(tester);
      final l10n = AppLocalizations.of(
          tester.element(find.byType(GroupInvitePage)))!;

      await tester.tap(find.text(l10n.copyLink));
      await tester.pumpAndSettle();

      final clipboardCall = calls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
        orElse: () => const MethodCall('none'),
      );
      expect(clipboardCall.method, 'Clipboard.setData');
      final text = (clipboardCall.arguments as Map)['text'] as String;
      expect(text, contains('grp-123'));
    });
  });
}
