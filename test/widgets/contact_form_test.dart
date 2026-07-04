import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/settings/contact.dart';
import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpContact(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
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
          child: const Contact(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'contact fields use the label-above AppTextField pattern — no floating '
      'Material label anywhere (F172)', (tester) async {
    await _pumpContact(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Contact)))!;

    // All four contact fields are AppTextFields in label-above mode.
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 4);
    for (final f in fields) {
      expect(f.labelMode, AppTextFieldLabelMode.above);
    }

    // Not a single TextField carries a floating Material label.
    final decorations =
        tester.widgetList<TextField>(find.byType(TextField)).map((t) => t.decoration);
    for (final d in decorations) {
      expect(d?.labelText, isNull);
      expect(d?.label, isNull);
    }

    // The four labels render as static text above their inputs.
    for (final label in [
      l10n.contactName,
      l10n.contactCompany,
      l10n.contactEmail,
      l10n.contactDescription,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the description field is multiline (maxLines: null) (F172)',
      (tester) async {
    await _pumpContact(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Contact)))!;

    final descField = find.ancestor(
      of: find.text(l10n.contactDescription),
      matching: find.byType(AppTextField),
    );
    expect(descField, findsOneWidget);
    final appField = tester.widget<AppTextField>(descField);
    expect(appField.maxLines, isNull);
    expect(appField.minLines, 3);
  });

  testWidgets('editing a field flows back into the FormBuilder value (F172)',
      (tester) async {
    await _pumpContact(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Contact)))!;

    final nameField = find.ancestor(
      of: find.text(l10n.contactName),
      matching: find.byType(AppTextField),
    );
    final input = find.descendant(of: nameField, matching: find.byType(TextField));

    await tester.enterText(input, 'Maya');
    await tester.pump();

    final formState = tester.state<FormBuilderState>(find.byType(FormBuilder));
    expect(formState.fields['name']!.value, 'Maya');
  });

  testWidgets('required validators still fire on the empty name field (F172)',
      (tester) async {
    await _pumpContact(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Contact)))!;

    final formState = tester.state<FormBuilderState>(find.byType(FormBuilder));
    expect(formState.saveAndValidate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text(l10n.contactNameValidationEmpty), findsOneWidget);
  });
}
