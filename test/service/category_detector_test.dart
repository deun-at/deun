import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';

void main() {
  group('ExpenseCategory.fromString', () {
    test('valid category name', () {
      expect(ExpenseCategory.fromString('food'), ExpenseCategory.food);
    });

    test('null returns other', () {
      expect(ExpenseCategory.fromString(null), ExpenseCategory.other);
    });

    test('unknown string returns other', () {
      expect(ExpenseCategory.fromString('nonexistent'), ExpenseCategory.other);
    });

    test('all enum values round-trip', () {
      for (final cat in ExpenseCategory.values) {
        expect(ExpenseCategory.fromString(cat.name), cat);
      }
    });
  });

  group('CategoryDetector.detectCategory', () {
    group('groceries', () {
      test('REWE → groceries', () {
        expect(CategoryDetector.detectCategory('REWE'), ExpenseCategory.groceries);
      });

      test('Lidl Einkauf → groceries', () {
        expect(CategoryDetector.detectCategory('Lidl Einkauf'), ExpenseCategory.groceries);
      });

      test('Aldi Süd → groceries', () {
        expect(CategoryDetector.detectCategory('Aldi Süd'), ExpenseCategory.groceries);
      });
    });

    group('coffee', () {
      test('Starbucks → coffee', () {
        expect(CategoryDetector.detectCategory('Starbucks'), ExpenseCategory.coffee);
      });

      test('Morning Coffee → coffee', () {
        expect(CategoryDetector.detectCategory('Morning Coffee'), ExpenseCategory.coffee);
      });
    });

    group('transport', () {
      test('Uber ride → transport', () {
        expect(CategoryDetector.detectCategory('Uber ride'), ExpenseCategory.transport);
      });

      test('Train ticket → transport', () {
        expect(CategoryDetector.detectCategory('Train ticket'), ExpenseCategory.transport);
      });
    });

    group('restaurants', () {
      test('Pizza restaurant → restaurants', () {
        expect(CategoryDetector.detectCategory('Pizza restaurant'), ExpenseCategory.restaurants);
      });

      test('McDonald lunch → restaurants', () {
        expect(CategoryDetector.detectCategory('McDonald lunch'), ExpenseCategory.restaurants);
      });
    });

    group('case insensitivity', () {
      test('REWE (uppercase) → groceries', () {
        expect(CategoryDetector.detectCategory('REWE'), ExpenseCategory.groceries);
      });

      test('starbucks (lowercase) → coffee', () {
        expect(CategoryDetector.detectCategory('starbucks'), ExpenseCategory.coffee);
      });
    });

    group('unknown', () {
      test('random text → other', () {
        expect(CategoryDetector.detectCategory('something random'), ExpenseCategory.other);
      });

      test('empty string → other', () {
        expect(CategoryDetector.detectCategory(''), ExpenseCategory.other);
      });
    });
  });
}
