import 'package:deun/widgets/card_list_view_builder.dart';
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

    // Rows are joined into a single CardColumn card (matches the live friend
    // list's joined-row layout, F143).
    expect(find.byType(CardColumn), findsOneWidget);

    // Each row has one avatar circle + a name bar + a username bar + a trailing
    // balance bar.
    expect(_boneCount(tester, shape: BoxShape.circle),
        greaterThanOrEqualTo(4), reason: 'one avatar per row');
    expect(_boneCount(tester, shape: BoxShape.rectangle),
        greaterThanOrEqualTo(4), reason: 'name/username/balance bars');
  });

  testWidgets('bars skeleton (default) still renders without overflow',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const ShimmerCardList(height: 80, listEntryLength: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ShimmerCardList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
