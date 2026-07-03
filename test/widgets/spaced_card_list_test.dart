import 'package:deun/widgets/restyle/spaced_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spacedCardItems interleaves a consistent gap between cards', () {
    final a = Container();
    final b = Container();
    final c = Container();

    final items = spacedCardItems([a, b, c]);

    // 3 cards + 2 gaps between them.
    expect(items.length, 5);
    expect(items[0], same(a));
    expect(items[2], same(b));
    expect(items[4], same(c));

    // The interleaved gaps are all the shared spaced-list gap — no ad-hoc value.
    final gap1 = items[1] as SizedBox;
    final gap2 = items[3] as SizedBox;
    expect(gap1.height, kSpacedCardGap);
    expect(gap2.height, kSpacedCardGap);
  });

  test('spacedCardItems adds no leading/trailing gap', () {
    final only = Container();
    final items = spacedCardItems([only]);
    expect(items.length, 1);
    expect(items.single, same(only));

    expect(spacedCardItems(<Widget>[]), isEmpty);
  });

  testWidgets('SpacedCardList renders children separated by the shared gap',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpacedCardList(
            children: [
              SizedBox(key: Key('card-0'), height: 20),
              SizedBox(key: Key('card-1'), height: 20),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('card-0')), findsOneWidget);
    expect(find.byKey(const Key('card-1')), findsOneWidget);

    // A gap of exactly kSpacedCardGap sits between the two cards (non-spaced
    // joined lists would have zero gap here).
    final gap = tester.getTopLeft(find.byKey(const Key('card-1'))).dy -
        tester.getBottomLeft(find.byKey(const Key('card-0'))).dy;
    expect(gap, kSpacedCardGap);
  });
}
