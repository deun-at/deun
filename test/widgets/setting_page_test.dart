import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/settings/card_fee_sheet.dart';
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

/// A card fee with no platform channel behind it, so the Settings row can be
/// driven at a known value.
class _FakeCardFeeNotifier extends CardFeeNotifier {
  _FakeCardFeeNotifier(this._initial);

  final double? _initial;

  @override
  double? build() => _initial;
}

Future<void> _pumpSettings(WidgetTester tester, {double? cardFee}) async {
  // The settings screen is a scrollable ListView; give it a tall viewport so the
  // preferences section (below the profile form) is laid out, not lazily culled.
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userDetailProvider.overrideWith(
          () => _FakeUserDetailNotifier(_fakeUser()),
        ),
        cardFeeProvider.overrideWith(() => _FakeCardFeeNotifier(cardFee)),
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
    'switch does not bloat it (F148)',
    (tester) async {
      await _pumpSettings(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(Setting)))!;

      final notificationsHeight = _rowHeight(
        tester,
        l10n.settingsNotifications,
      );
      final appearanceHeight = _rowHeight(tester, l10n.settingsAppearance);

      expect(
        notificationsHeight,
        moreOrLessEquals(appearanceHeight, epsilon: 0.5),
      );
    },
  );

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

  testWidgets('the screen title lines up with the cards beneath it', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pumpSettings(tester);

    // A stray 4px of header padding sat on top of the ListView's 16, putting
    // the title 4px right of everything else on the screen.
    expect(
      tester.getTopLeft(find.text(l10n.settings)).dx,
      tester.getTopLeft(find.byType(SoftCard).first).dx,
    );
  });

  // The card fee's Settings surface. The sheet behind it is covered by
  // test/widgets/card_fee_sheet_test.dart; this is the row that opens it.
  testWidgets('the fee row reads None when no fee is saved', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pumpSettings(tester);

    expect(find.text(l10n.settingsCardFee), findsOneWidget);
    expect(find.text(l10n.settingsCardFeeSubtitle), findsOneWidget);
    expect(find.text(l10n.settingsCardFeeNone), findsOneWidget);
  });

  testWidgets('the fee row states a saved fee, per locale', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pumpSettings(tester, cardFee: 1.4);

    expect(
      find.text(l10n.cardFeePercentValue('1.4')),
      findsOneWidget,
      reason: 'the row renders the fee, not a placeholder',
    );
    expect(find.text(l10n.settingsCardFeeNone), findsNothing);
  });

  testWidgets('tapping the fee row opens the entry sheet', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pumpSettings(tester, cardFee: 1.4);

    await tester.tap(find.text(l10n.settingsCardFee));
    await tester.pumpAndSettle();

    expect(find.byType(CardFeeSheet), findsOneWidget);
    // Seeded from the stored value, so the row and the sheet are one number.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('card_fee_field')))
          .controller!
          .text,
      '1.4',
    );
  });
}
