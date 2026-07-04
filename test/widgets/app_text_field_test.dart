import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, Brightness.light)
              .copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The effective opacity of the in-field hint [text] — Material wraps the hint
/// in an [AnimatedOpacity] that fades to 0 when the field is non-empty (the hint
/// hides; it never floats to a label).
double _hintOpacity(WidgetTester tester, String text) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(
      of: find.text(text),
      matching: find.byType(AnimatedOpacity),
    ),
  );
  return opacity.opacity;
}

void main() {
  testWidgets(
      'placeholder mode: label shows as in-field hint, disappears on input, '
      'never floats to a Material label', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      AppTextField(
        controller: controller,
        label: 'Email',
        labelMode: AppTextFieldLabelMode.placeholder,
      ),
    );

    // The label is the placeholder (hintText), never a floating labelText.
    final decoration = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(decoration.hintText, 'Email');
    expect(decoration.labelText, isNull);
    expect(decoration.label, isNull);

    // Placeholder is visible while empty...
    expect(find.text('Email'), findsOneWidget);

    // While empty the hint is fully opaque.
    expect(_hintOpacity(tester, 'Email'), 1.0);

    // Once the user types, the hint fades to fully hidden (opacity 0) — it does
    // NOT float up to the border. Settle the cross-fade first.
    await tester.enterText(find.byType(TextField), 'a@b.co');
    await tester.pumpAndSettle();
    expect(_hintOpacity(tester, 'Email'), 0.0);
  });

  testWidgets(
      'label-above mode: renders a static label above the field, never a '
      'floating Material label', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      AppTextField(
        controller: controller,
        label: 'Display name',
        labelMode: AppTextFieldLabelMode.above,
      ),
    );

    // No Material floating label / no in-field placeholder.
    final decoration = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(decoration.labelText, isNull);
    expect(decoration.label, isNull);
    expect(decoration.hintText, isNull);

    // Static label text is present and sits above the field.
    expect(find.text('Display name'), findsOneWidget);
    final labelY = tester.getTopLeft(find.text('Display name')).dy;
    final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
    expect(labelY, lessThan(fieldY));

    // Label stays put after typing (it is static, not a placeholder).
    await tester.enterText(find.byType(TextField), 'Jakob');
    await tester.pump();
    expect(find.text('Display name'), findsOneWidget);
  });

  testWidgets(
      'above mode: flat beige inset box (surfaceContainer, radius 12, no '
      'shadow) — F169; placeholder mode stays white r14 + shadow', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final theme = getThemeData(context, kBrandSeed, Brightness.light)
                .copyWith(splashFactory: NoSplash.splashFactory);
            scheme = theme.colorScheme;
            return Theme(
              data: theme,
              child: Scaffold(
                body: Column(
                  children: [
                    AppTextField(
                      key: const Key('above'),
                      controller: controller,
                      label: 'Name',
                      labelMode: AppTextFieldLabelMode.above,
                    ),
                    AppTextField(
                      key: const Key('placeholder'),
                      controller: TextEditingController(),
                      label: 'Email',
                      labelMode: AppTextFieldLabelMode.placeholder,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    BoxDecoration decoOf(Key k) => tester
        .widget<DecoratedBox>(
          find.descendant(of: find.byKey(k), matching: find.byType(DecoratedBox)),
        )
        .decoration as BoxDecoration;

    // Above (profile): flat, no shadow; radius 12.
    final above = decoOf(const Key('above'));
    expect(above.boxShadow, anyOf(isNull, isEmpty));
    expect(above.borderRadius, BorderRadius.circular(12));

    // Placeholder (login): keeps the soft card shadow; radius 14.
    final placeholder = decoOf(const Key('placeholder'));
    expect(placeholder.boxShadow, isNotEmpty);
    expect(placeholder.borderRadius, BorderRadius.circular(14));

    // Above fill = beige surfaceContainer; placeholder fill = white lowest.
    final aboveDeco =
        tester.widget<TextField>(find.descendant(of: find.byKey(const Key('above')), matching: find.byType(TextField))).decoration!;
    expect(aboveDeco.fillColor, scheme.surfaceContainer);
    final phDeco =
        tester.widget<TextField>(find.descendant(of: find.byKey(const Key('placeholder')), matching: find.byType(TextField))).decoration!;
    expect(phDeco.fillColor, scheme.surfaceContainerLowest);
  });

  testWidgets('above mode: prefixText renders in the muted onSurfaceVariant tone (F170)',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final theme = getThemeData(context, kBrandSeed, Brightness.light);
            scheme = theme.colorScheme;
            return Theme(
              data: theme,
              child: Scaffold(
                body: AppTextField(
                  controller: controller,
                  label: 'PayPal.me',
                  prefixText: 'paypal.me/',
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(deco.prefixText, 'paypal.me/');
    expect(deco.prefixStyle?.color, scheme.onSurfaceVariant);
  });
}
