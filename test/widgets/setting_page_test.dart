import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/settings/setting.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SupaUser _fakeUser() => const SupaUser(
      email: 'maya@deun.app',
      firstName: 'Maya',
      lastName: 'Okonkwo',
      displayName: 'Maya Okonkwo',
      username: 'maya',
      usernameCode: '4821',
    );

class _FakeUserDetailNotifier extends UserDetailNotifier {
  _FakeUserDetailNotifier(this._user);

  final SupaUser _user;

  @override
  Future<SupaUser> build() async => _user;
}

Future<void> _pumpSettings(WidgetTester tester) async {
  // The settings screen is a scrollable ListView; give it a tall viewport so the
  // preferences section (below the profile form) is laid out, not lazily culled.
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userDetailProvider.overrideWith(() => _FakeUserDetailNotifier(_fakeUser())),
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
            data: getThemeData(context, kBrandSeed, Brightness.light)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: const Setting(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rendered height of the preference row carrying [label].
double _rowHeight(WidgetTester tester, String label) {
  // Each preference row is an InkWell wrapping a Padding + Row; measure the
  // InkWell that contains the label text.
  final row = find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );
  return tester.getSize(row.first).height;
}

void main() {
  testWidgets(
      'the notification row is the same height as other preference rows — the '
      'switch does not bloat it (F148)', (tester) async {
    await _pumpSettings(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Setting)))!;

    final notificationsHeight = _rowHeight(tester, l10n.settingsNotifications);
    final appearanceHeight = _rowHeight(tester, l10n.settingsAppearance);

    expect(notificationsHeight, moreOrLessEquals(appearanceHeight, epsilon: 0.5));
  });

  testWidgets('the notification switch still toggles (F148)', (tester) async {
    await _pumpSettings(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Setting)),
    );

    expect(container.read(notificationsEnabledProvider), isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(notificationsEnabledProvider), isFalse);
  });
}
