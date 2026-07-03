import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/item_icon.dart';

void main() {
  group('iconForItemName', () {
    test('pizza → local_pizza', () {
      expect(iconForItemName('Margherita Pizza'), Icons.local_pizza_rounded);
    });

    test('cola/drink → local_bar', () {
      expect(iconForItemName('Cola'), Icons.local_bar_rounded);
      expect(iconForItemName('Beer'), Icons.local_bar_rounded);
    });

    test('coffee → local_cafe', () {
      expect(iconForItemName('Latte coffee'), Icons.local_cafe_rounded);
    });

    test('salad/food → restaurant', () {
      expect(iconForItemName('Caesar Salad'), Icons.restaurant_rounded);
    });

    test('taxi → local_taxi', () {
      expect(iconForItemName('Uber ride'), Icons.local_taxi_rounded);
    });

    test('case-insensitive match', () {
      expect(iconForItemName('PIZZA'), Icons.local_pizza_rounded);
    });

    test('unknown name → receipt_long default', () {
      expect(iconForItemName('Widget 42'), Icons.receipt_long_rounded);
      expect(iconForItemName(''), Icons.receipt_long_rounded);
    });
  });
}
