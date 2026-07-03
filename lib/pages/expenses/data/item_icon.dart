import 'package:flutter/material.dart';

/// Auto-derives a Material rounded icon for an itemized line item from its
/// name (F116). Keyword substring match, first hit wins; falls back to a
/// generic receipt icon. Pure — safe to unit-test and call during build.
///
/// ponytail: flat keyword→icon list, order matters (specific before generic).
/// Add keywords here rather than growing a per-category abstraction.
IconData iconForItemName(String name) {
  final n = name.toLowerCase();
  const table = <(List<String>, IconData)>[
    (['pizza'], Icons.local_pizza_rounded),
    (['burger', 'fries', 'mcdonald', 'kfc'], Icons.lunch_dining_rounded),
    (['coffee', 'espresso', 'latte', 'cappuccino', 'cafe'], Icons.local_cafe_rounded),
    (['beer', 'cola', 'coke', 'drink', 'bar', 'wine', 'soda', 'juice'], Icons.local_bar_rounded),
    (['cake', 'dessert', 'icecream', 'ice cream', 'sweet', 'donut'], Icons.cake_rounded),
    (['salad', 'restaurant', 'dinner', 'lunch', 'food', 'meal', 'sushi', 'pasta'], Icons.restaurant_rounded),
    (['grocery', 'groceries', 'supermarket', 'market'], Icons.local_grocery_store_rounded),
    (['taxi', 'uber', 'transport', 'bus', 'train', 'ride'], Icons.local_taxi_rounded),
    (['ticket', 'movie', 'cinema', 'concert', 'show'], Icons.local_activity_rounded),
  ];
  for (final (keywords, icon) in table) {
    for (final k in keywords) {
      if (n.contains(k)) return icon;
    }
  }
  return Icons.receipt_long_rounded;
}
