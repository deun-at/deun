import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// F145: the shimmer skeletons must mirror the v3 card/row silhouettes they
/// stand in for — not plain full-width rectangles. These tests assert the
/// group-list and friend-row skeletons render their shape elements (a leading
/// icon/avatar box + text bars) inside the real card containers.

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(height: 800, child: child)),
    );

/// Bones are theme-tinted, rounded/circular DecoratedBoxes; count the ones of a
/// given box shape so we can assert the skeleton's silhouette.
int _boneCount(WidgetTester tester, {required BoxShape shape}) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.shape == shape && d.color != null;
      })
      .length;
}

void main() {
  testWidgets('card skeleton mirrors the group-list card (SoftCard + icon tile + bars)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerCardList(
        height: 100,
        listEntryLength: 3,
        shape: ShimmerShape.card,
      )),
    );
    // pump one frame of the shimmer animation.
    await tester.pump(const Duration(milliseconds: 100));

    // Each card is a real SoftCard (shares radius/shadow with the live list).
    expect(find.byType(SoftCard), findsWidgets);

    // Each card carries a leading rounded icon tile + a title bar + a footer
    // balance bar + an avatar-stack silhouette (circles). At least the icon
    // tiles and avatar circles must be present.
    expect(_boneCount(tester, shape: BoxShape.rectangle),
        greaterThanOrEqualTo(3), reason: 'icon tile + title/balance bars');
    expect(_boneCount(tester, shape: BoxShape.circle),
        greaterThanOrEqualTo(3), reason: 'avatar-stack circles');
  });

  testWidgets('row skeleton mirrors the friend row (CardColumn + avatar circle + name bars)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerCardList(
        height: 70,
        listEntryLength: 4,
        shape: ShimmerShape.row,
      )),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Rows are joined into a single SoftCard (F166: the live friend-list chrome,
    // not the retired CardColumn card/margin/28-8 radii).
    expect(find.byType(SoftCard), findsOneWidget);

    // Each row has one avatar circle + a name bar + a username bar + a trailing
    // balance bar.
    expect(_boneCount(tester, shape: BoxShape.circle),
        greaterThanOrEqualTo(4), reason: 'one avatar per row');
    expect(_boneCount(tester, shape: BoxShape.rectangle),
        greaterThanOrEqualTo(4), reason: 'name/username/balance bars');
  });

  testWidgets('bars skeleton (default) still renders without overflow, in a SoftCard',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerCardList(height: 80, listEntryLength: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ShimmerCardList), findsOneWidget);
    // F166: joined into one SoftCard, not the retired CardColumn chrome.
    expect(find.byType(SoftCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ledger skeleton mirrors the day-sectioned _QuickRow ledger',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerCardList(
        height: 80,
        listEntryLength: 12,
        shape: ShimmerShape.ledger,
      )),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Rows spread across day sections, each section a real SoftCard (mirrors the
    // live _DaySection: header + joined _QuickRow card, F166).
    expect(find.byType(SoftCard), findsWidgets);
    // 12 rows → each _QuickRow silhouette has a leading icon tile + 2 text bars
    // + a trailing total bar, plus one day-header bar per section.
    expect(_boneCount(tester, shape: BoxShape.rectangle),
        greaterThanOrEqualTo(12), reason: 'icon tiles + text/total bars + day headers');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shimmer gradient base is translucent so bones show through (F166)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerCardList(
        height: 80,
        listEntryLength: 3,
        shape: ShimmerShape.card,
      )),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final state = tester.state<ShimmerCardListState>(find.byType(ShimmerCardList));
    final colors = state.gradient.colors;
    // An opaque base overpaints every bone into a flat block under
    // BlendMode.srcATop (F166). The base (endpoints) must be translucent.
    expect(colors.first.a, lessThan(1.0), reason: 'gradient base must be translucent');
    expect(colors.last.a, lessThan(1.0), reason: 'gradient base must be translucent');
  });
}
