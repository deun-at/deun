import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/settings/settings_profile_form.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
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

/// A [UserDetailNotifier] returning a fixed user synchronously (no supabase).
class _FakeUserDetailNotifier extends UserDetailNotifier {
  _FakeUserDetailNotifier(this._user);

  final SupaUser _user;

  @override
  Future<SupaUser> build() async => _user;
}

Future<void> _pumpForm(WidgetTester tester, {SupaUser? user}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userDetailProvider
            .overrideWith(() => _FakeUserDetailNotifier(user ?? _fakeUser())),
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
            child: const Scaffold(
              body: SingleChildScrollView(child: SettingsProfileForm()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'profile text fields use the label-above AppTextField pattern — no '
      'floating Material label anywhere', (tester) async {
    await _pumpForm(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsProfileForm)))!;

    // The form's text fields are AppTextFields (one per editable field).
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields, isNotEmpty);
    for (final f in fields) {
      // Every one is in label-above mode (static label, never floating).
      expect(f.labelMode, AppTextFieldLabelMode.above);
    }

    // Not a single TextField inside the form carries a floating Material label.
    final decorations = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((t) => t.decoration);
    for (final d in decorations) {
      expect(d?.labelText, isNull);
      expect(d?.label, isNull);
    }

    // The field labels render as static text above their inputs.
    for (final label in [
      l10n.settingsFirstName,
      l10n.settingsLastName,
      l10n.settingsDisplayName,
      l10n.settingsUsername,
    ]) {
      expect(find.text(label), findsOneWidget);
      final labelY = tester.getTopLeft(find.text(label)).dy;
      // Its sibling input sits below the label.
      expect(labelY, isNotNull);
    }
  });

  testWidgets('editing a field flows back into the FormBuilder value so the '
      'existing save path persists the edit', (tester) async {
    await _pumpForm(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsProfileForm)))!;

    // Locate the display-name field by its label-above text, then its input.
    final displayField = find.ancestor(
      of: find.text(l10n.settingsDisplayName),
      matching: find.byType(AppTextField),
    );
    expect(displayField, findsOneWidget);
    final input = find.descendant(of: displayField, matching: find.byType(TextField));

    // Seeded from the user (initialValue via FormBuilder).
    expect(find.widgetWithText(TextField, 'Maya Okonkwo'), findsOneWidget);

    await tester.enterText(input, 'Maya O.');
    await tester.pump();

    // The bound FormBuilder field's value (what saveAndValidate() reads) updated.
    final formState =
        tester.state<FormBuilderState>(find.byType(FormBuilder));
    expect(formState.fields['display_name']!.value, 'Maya O.');
  });

  testWidgets('required validators still fire on an emptied field', (tester) async {
    await _pumpForm(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsProfileForm)))!;

    final displayField = find.ancestor(
      of: find.text(l10n.settingsDisplayName),
      matching: find.byType(AppTextField),
    );
    final input = find.descendant(of: displayField, matching: find.byType(TextField));

    await tester.enterText(input, '');
    await tester.pump();

    final formState = tester.state<FormBuilderState>(find.byType(FormBuilder));
    expect(formState.saveAndValidate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsDisplayNameValidationEmpty), findsOneWidget);
  });

  testWidgets('the Update button is full width (F150)', (tester) async {
    await _pumpForm(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsProfileForm)))!;

    final update = find.widgetWithText(PrimaryButton, l10n.update);
    expect(update, findsOneWidget);
    // fullWidth (the default) rather than the old right-aligned intrinsic width.
    expect(tester.widget<PrimaryButton>(update).fullWidth, isTrue);
    // It spans the full form width, not shrink-wrapped to its label.
    final buttonWidth = tester.getSize(update).width;
    final formWidth = tester.getSize(find.byType(SettingsProfileForm)).width;
    expect(buttonWidth, moreOrLessEquals(formWidth, epsilon: 1));
  });
}
