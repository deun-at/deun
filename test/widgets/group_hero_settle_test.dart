import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// F176 regression: the group-detail hero "Settle up" pill must render its full
/// label even next to a wide avatar stack (5+ members). v3 always shows the
/// full label; the pill sizes to its intrinsic width and the avatar stack takes
/// the flexible slot.

const _settleLabel = 'Settle up';

List<AvatarStackMember> _members(int n) => [
      for (var i = 0; i < n; i++)
        AvatarStackMember(name: 'M$i', colorKey: 'm$i@test.com'),
    ];

/// The hero balance-row layout, mirroring _GroupBalanceHero (group_detail.dart).
Widget _heroRow(int memberCount) {
  final members = _members(memberCount);
  return Row(
    children: [
      if (members.isNotEmpty)
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AvatarStack(
              members: members,
              ringColor: const Color(0xFF5750E6),
              uniformColor: Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ),
      const SizedBox(width: 12),
      PrimaryButton(
        label: _settleLabel,
        background: Colors.white,
        foreground: const Color(0xFF5750E6),
        compact: true,
        onPressed: () {},
      ),
    ],
  );
}

Future<void> _pumpAt(WidgetTester tester, Widget child, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, Brightness.light)
              .copyWith(splashFactory: NoSplash.splashFactory),
          // Hero uses 20px padding all round on a full-width container.
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// True if the "Settle up" [Text] is ellipsized (its rendered paragraph
/// exceeded max lines OR its width is narrower than the text needs).
bool _labelClipped(WidgetTester tester) {
  final el = find.text(_settleLabel).evaluate().single;
  final rp = el.renderObject as RenderParagraph;
  return rp.didExceedMaxLines || rp.size.width < rp.getMaxIntrinsicWidth(double.infinity) - 0.5;
}

void main() {
  testWidgets('F176 · Settle up label is not clipped with 5 members at 390px',
      (tester) async {
    await _pumpAt(tester, _heroRow(5), 390);
    expect(_labelClipped(tester), isFalse,
        reason: 'the Settle up pill must show its full label, not "Settle …"');
    expect(find.byType(AvatarStack), findsOneWidget);
  });

  testWidgets('F176 · Settle up label is not clipped with 8 members at 390px',
      (tester) async {
    await _pumpAt(tester, _heroRow(8), 390);
    expect(_labelClipped(tester), isFalse);
  });

  testWidgets('F176 · narrow case (2 members) still renders full label + stack',
      (tester) async {
    await _pumpAt(tester, _heroRow(2), 390);
    expect(_labelClipped(tester), isFalse);
    expect(find.byType(AvatarStack), findsOneWidget);
    // Avatar stack stays on-screen (left edge >= 0).
    final rect = tester.getRect(find.byType(AvatarStack));
    expect(rect.left, greaterThanOrEqualTo(0));
  });
}
