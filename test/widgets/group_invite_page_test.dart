import 'package:deun/constants.dart';
import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_invite_page.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helper/fake_realtime_channel_factory.dart';

const _t1 = '5f0c2a9e-1b7d-4c3e-9a41-0d6e8b2f7c11';
const _t2 = 'c3a1e7d2-8f4b-4e19-b6a0-2d9f5c7e1a42';

Group _fakeGroup({String token = _t1}) => Group()
  ..loadDataFromJson({
    'id': 'grp-123',
    'name': 'Trip to Rome',
    'created_at': '',
    'invite_token': token,
  }, currentUserEmail: null);

/// The group notifier answering with what the "server" holds right now.
class _ServerGroupNotifier extends GroupDetailNotifier {
  _ServerGroupNotifier(this.serverToken);
  final String Function() serverToken;

  @override
  Future<Group> fetchGroup(String groupId) async =>
      _fakeGroup(token: serverToken());
}

/// Pumps the invite sheet over a group snapshot that still carries [_t1].
/// [serverToken] is the token the group's detail provider loads; [open] shows
/// and hides the sheet while the group page (the watcher below) stays alive.
Future<void> _pumpInvite(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  InviteResetter? resetInvite,
  String Function()? serverToken,
  ValueNotifier<bool>? open,
}) async {
  final isOpen = open ?? ValueNotifier(true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        realtimeChannelFactoryProvider.overrideWithValue(
          FakeRealtimeChannelFactory(),
        ),
        groupDetailProvider.overrideWith2(
          (_) => _ServerGroupNotifier(serverToken ?? () => _t1),
        ),
      ],
      child: MaterialApp(
        // NoSplash avoids loading the ink ripple fragment shader, which the test
        // engine can't decode; getThemeData inherits this splash factory.
        theme: ThemeData(
          brightness: Brightness.light,
          splashFactory: NoSplash.splashFactory,
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
            data: getThemeData(context, kBrandSeed, brightness),
            // The invite sheet is presented above the app shell, which always
            // provides a descendant Scaffold for snackbars; mirror that here.
            child: Scaffold(
              // The group page keeps the group alive under the sheet.
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(groupDetailProvider('grp-123'));
                  return ValueListenableBuilder<bool>(
                    valueListenable: isOpen,
                    builder: (context, shown, _) => shown
                        ? GroupInvitePage(
                            group: _fakeGroup(),
                            resetInvite: resetInvite,
                          )
                        : const SizedBox(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('buildGroupInviteLink', () {
    test('the join deep link carries the group id, the token and the name', () {
      final s = GroupInvitePage.buildGroupInviteLink(
        _fakeGroup(),
        token: _t1,
      ).toString();
      expect(s, contains('/#/group/join'));
      expect(s, contains('groupId=grp-123'));
      expect(s, contains('token=$_t1'));
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
          tester.element(find.byType(GroupInvitePage)),
        )!;
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
      },
    );

    testWidgets('footer QR button reveals the QR code', (tester) async {
      await _pumpInvite(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GroupInvitePage)),
      )!;

      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.text(l10n.inviteQrButton));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await _pumpInvite(tester, brightness: Brightness.dark);
      expect(find.byType(SheetScaffold), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(GroupInvitePage)),
      )!;
      // Reveal the QR to exercise its dark-mode render path.
      await tester.tap(find.text(l10n.groupInviteShowQr));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets(
      'tapping Copy writes the invite link, with the group\'s current token, to the clipboard',
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
          tester.element(find.byType(GroupInvitePage)),
        )!;

        await tester.tap(find.text(l10n.copyLink));
        await tester.pumpAndSettle();

        final clipboardCall = calls.firstWhere(
          (c) => c.method == 'Clipboard.setData',
          orElse: () => const MethodCall('none'),
        );
        expect(clipboardCall.method, 'Clipboard.setData');
        final text = (clipboardCall.arguments as Map)['text'] as String;
        expect(text, contains('grp-123'));
        expect(text, contains('token=$_t1'));
      },
    );
  });

  group('GroupInvitePage reset', () {
    late List<String> resets;
    setUp(() => resets = []);

    Future<String> recordReset(String groupId) async {
      resets.add(groupId);
      return _t2;
    }

    testWidgets('Reset asks first, and Cancel changes nothing', (tester) async {
      await _pumpInvite(tester, resetInvite: recordReset);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GroupInvitePage)),
      )!;

      await tester.tap(find.text(l10n.groupInviteResetLink));
      await tester.pumpAndSettle();
      expect(find.text(l10n.groupInviteResetTitle), findsOneWidget);
      expect(find.text(l10n.groupInviteResetBody), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(resets, isEmpty);
      expect(find.textContaining('token=$_t1'), findsOneWidget);
    });

    testWidgets('Reset issues a new token and the link carries it at once', (
      tester,
    ) async {
      await _pumpInvite(tester, resetInvite: recordReset);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GroupInvitePage)),
      )!;

      await tester.tap(find.text(l10n.groupInviteResetLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.groupInviteResetConfirm));
      await tester.pumpAndSettle();

      expect(resets, ['grp-123']);
      expect(find.textContaining('token=$_t2'), findsOneWidget);
      expect(find.textContaining('token=$_t1'), findsNothing);
    });

    testWidgets(
      'reopening the sheet from a stale group snapshot shows the reset token',
      (tester) async {
        var server = _t1;
        final open = ValueNotifier(true);
        await _pumpInvite(
          tester,
          open: open,
          serverToken: () => server,
          resetInvite: (groupId) async => server = _t2,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(GroupInvitePage)),
        )!;

        await tester.tap(find.text(l10n.groupInviteResetLink));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.groupInviteResetConfirm));
        await tester.pumpAndSettle();

        open.value = false;
        await tester.pumpAndSettle();
        open.value = true;
        await tester.pumpAndSettle();

        expect(find.textContaining('token=$_t2'), findsOneWidget);
        expect(find.textContaining('token=$_t1'), findsNothing);
      },
    );

    testWidgets(
      'after a reset here, a later reset elsewhere shows once the group reloads',
      (tester) async {
        var server = _t1;
        await _pumpInvite(
          tester,
          serverToken: () => server,
          resetInvite: (groupId) async => server = _t2,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(GroupInvitePage)),
        )!;

        await tester.tap(find.text(l10n.groupInviteResetLink));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.groupInviteResetConfirm));
        await tester.pumpAndSettle();
        expect(find.textContaining('token=$_t2'), findsOneWidget);

        // Another member resets; realtime reloads the group with the new token.
        const t3 = '9b2e4f61-7a3c-4d85-8e10-6c4a2b9d3f57';
        server = t3;
        await ProviderScope.containerOf(
          tester.element(find.byType(GroupInvitePage)),
        ).read(groupDetailProvider('grp-123').notifier).reload('grp-123');
        await tester.pumpAndSettle();

        expect(find.textContaining('token=$t3'), findsOneWidget);
        expect(find.textContaining('token=$_t2'), findsNothing);
      },
    );

    testWidgets('a failed reset keeps the current link and says so', (
      tester,
    ) async {
      await _pumpInvite(
        tester,
        resetInvite: (_) async => throw Exception('reset failed'),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GroupInvitePage)),
      )!;

      await tester.tap(find.text(l10n.groupInviteResetLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.groupInviteResetConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.generalError), findsOneWidget);
      expect(find.textContaining('token=$_t1'), findsOneWidget);
    });
  });
}
