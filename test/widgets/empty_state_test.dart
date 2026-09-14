import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/restyle/empty_state.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in a minimal themed app. [disableAnimations] drives the
/// reduced-motion branch.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(EmptyState))).colorScheme;

/// The chip: the [Container] wrapping the icon that actually carries a fill.
Container _chip(WidgetTester tester, IconData icon) {
  return tester.widget<Container>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
        .first,
  );
}

void main() {
  // AC1 — the chip is a filled primaryContainer, the icon onPrimaryContainer.
  // NOT colorScheme.outline, the disabled/hairline token the four old empty
  // states drew their icon in.
  testWidgets('the icon sits in a filled primaryContainer chip', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
    );

    final scheme = _scheme(tester);
    final decoration =
        _chip(tester, Icons.group_outlined).decoration as BoxDecoration;

    expect(decoration.color, scheme.primaryContainer);
    expect(decoration.borderRadius, BorderRadius.circular(28));

    final icon = tester.widget<Icon>(find.byIcon(Icons.group_outlined));
    expect(icon.color, scheme.onPrimaryContainer);
    expect(
      icon.color,
      isNot(scheme.outline),
      reason:
          'outline is the token that made the old empty states read as unfinished',
    );
  });

  // AC5 (component half) — the error tone is a distinct treatment, so a failed
  // load cannot be painted in the same accent as an empty account.
  testWidgets('the error tone repaints the chip in the error container', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.cloud_off,
        headline: 'Could not load this',
        tone: EmptyStateTone.error,
      ),
    );

    final scheme = _scheme(tester);
    final decoration =
        _chip(tester, Icons.cloud_off).decoration as BoxDecoration;
    expect(decoration.color, scheme.errorContainer);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_off)).color,
      scheme.onErrorContainer,
    );
  });

  // AC2 — headline, optional body, optional action, in that order.
  testWidgets('renders headline, body and action in order', (tester) async {
    await _pump(
      tester,
      EmptyState(
        icon: Icons.group_outlined,
        headline: 'No groups yet',
        body: 'Start one for a trip.',
        actionLabel: 'New group',
        onAction: () {},
      ),
    );

    final headlineY = tester.getCenter(find.text('No groups yet')).dy;
    final bodyY = tester.getCenter(find.text('Start one for a trip.')).dy;
    final actionY = tester.getCenter(find.byType(PrimaryButton)).dy;

    expect(headlineY, lessThan(bodyY));
    expect(bodyY, lessThan(actionY));
  });

  // AC2 — a null body lays out no Text, a null action lays out no button.
  testWidgets('omits the body and the action when they are null', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
    );

    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
  });

  // AC5 (component half) — tone alone never conjures a Retry; the caller does.
  testWidgets('the empty tone renders no action without one being passed', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.group_outlined,
        headline: 'No groups yet',
        body: 'Start one for a trip.',
      ),
    );
    expect(find.byType(PrimaryButton), findsNothing);
  });

  // AC3 — the bare constructor owns no scrollable and no RefreshIndicator.
  testWidgets('the default constructor builds a bare min-size column', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
    );

    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byType(Scrollable), findsNothing);

    final column = tester.widget<Column>(
      find
          .descendant(
            of: find.byType(EmptyState),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(column.mainAxisSize, MainAxisSize.min);
  });

  // AC3 — .refreshable wraps the same column so the pull gesture still works
  // on an empty list.
  testWidgets('.refreshable wraps the column in a pullable single ListView', (
    tester,
  ) async {
    var refreshed = 0;
    await _pump(
      tester,
      EmptyState.refreshable(
        onRefresh: () async => refreshed++,
        icon: Icons.group_outlined,
        headline: 'No groups yet',
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());

    await tester.fling(find.text('No groups yet'), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  // AC4 — the defect that stopped group_list.dart using EmptyListWidget: a
  // nested vertical viewport has unbounded height and crashes layout.
  testWidgets('a bare EmptyState nests inside a caller ListView', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              SizedBox(height: 40),
              EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No groups yet'), findsOneWidget);
  });

  // AC9 — the chip pops on mount; the words are at rest from the first frame.
  testWidgets('the chip pops from 0 while the words never move', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.group_outlined,
        headline: 'No groups yet',
        body: 'Start one for a trip.',
      ),
      settle: false,
    );

    final pop = find.byKey(kEmptyStateChipPopKey);
    expect(pop, findsOneWidget);
    expect(tester.widget<ScaleTransition>(pop).scale.value, 0.0);

    final headlineAtMount = tester.getTopLeft(find.text('No groups yet'));
    final bodyAtMount = tester.getTopLeft(find.text('Start one for a trip.'));
    // Opaque from frame one — no fade wrapper over the message.
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    await tester.pump(Motion.successPopDuration);
    expect(tester.widget<ScaleTransition>(pop).scale.value, 1.0);
    expect(tester.getTopLeft(find.text('No groups yet')), headlineAtMount);
    expect(tester.getTopLeft(find.text('Start one for a trip.')), bodyAtMount);
  });

  // AC9 — the pop uses the shared overshoot curve, not an invented one.
  testWidgets('the chip pop overshoots with Motion.successPop', (tester) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
      settle: false,
    );

    final pop = find.byKey(kEmptyStateChipPopKey);
    var sawOvershoot = false;
    for (
      var elapsed = Duration.zero;
      elapsed < Motion.successPopDuration;
      elapsed += const Duration(milliseconds: 20)
    ) {
      await tester.pump(const Duration(milliseconds: 20));
      if (tester.widget<ScaleTransition>(pop).scale.value > 1.0) {
        sawOvershoot = true;
      }
    }
    expect(sawOvershoot, isTrue);
  });

  // AC10 — reduced motion renders the chip statically at full scale, with no
  // ScaleTransition carrying the chip's key in the tree.
  testWidgets('reduced motion renders the chip statically at full scale', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
      disableAnimations: true,
    );

    expect(find.byKey(kEmptyStateChipPopKey), findsNothing);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);

    final scheme = _scheme(tester);
    final decoration =
        _chip(tester, Icons.group_outlined).decoration as BoxDecoration;
    expect(decoration.color, scheme.primaryContainer);
  });

  // AC10 guard — disposing under reduced motion must not trip the Ticker
  // ancestor lookup (the PrimaryButton._CheckPopState bug, commit 33c7d2a).
  testWidgets('disposing under reduced motion throws nothing', (tester) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.group_outlined, headline: 'No groups yet'),
      disableAnimations: true,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
