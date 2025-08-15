import 'package:flutter/material.dart';
import 'package:deun/l10n/app_localizations.dart';

enum ExpenseCategory {
  food,
  transport,
  shopping,
  entertainment,
  health,
  travel,
  bills,
  groceries,
  restaurants,
  coffee,
  gas,
  parking,
  accommodation,
  gifts,
  education,
  sports,
  beauty,
  technology,
  clothing,
  home,
  other;

  String getDisplayName(AppLocalizations localizations) {
    switch (this) {
      case ExpenseCategory.food:
        return localizations.categoryFood;
      case ExpenseCategory.transport:
        return localizations.categoryTransport;
      case ExpenseCategory.shopping:
        return localizations.categoryShopping;
      case ExpenseCategory.entertainment:
        return localizations.categoryEntertainment;
      case ExpenseCategory.health:
        return localizations.categoryHealth;
      case ExpenseCategory.travel:
        return localizations.categoryTravel;
      case ExpenseCategory.bills:
        return localizations.categoryBills;
      case ExpenseCategory.groceries:
        return localizations.categoryGroceries;
      case ExpenseCategory.restaurants:
        return localizations.categoryRestaurants;
      case ExpenseCategory.coffee:
        return localizations.categoryCoffee;
      case ExpenseCategory.gas:
        return localizations.categoryGas;
      case ExpenseCategory.parking:
        return localizations.categoryParking;
      case ExpenseCategory.accommodation:
        return localizations.categoryAccommodation;
      case ExpenseCategory.gifts:
        return localizations.categoryGifts;
      case ExpenseCategory.education:
        return localizations.categoryEducation;
      case ExpenseCategory.sports:
        return localizations.categorySports;
      case ExpenseCategory.beauty:
        return localizations.categoryBeauty;
      case ExpenseCategory.technology:
        return localizations.categoryTechnology;
      case ExpenseCategory.clothing:
        return localizations.categoryClothing;
      case ExpenseCategory.home:
        return localizations.categoryHome;
      case ExpenseCategory.other:
        return localizations.categoryOther;
    }
  }

  IconData getIcon() {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.health:
        return Icons.medical_services;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.bills:
        return Icons.receipt_long;
      case ExpenseCategory.groceries:
        return Icons.shopping_cart;
      case ExpenseCategory.restaurants:
        return Icons.restaurant_menu;
      case ExpenseCategory.coffee:
        return Icons.local_cafe;
      case ExpenseCategory.gas:
        return Icons.local_gas_station;
      case ExpenseCategory.parking:
        return Icons.local_parking;
      case ExpenseCategory.accommodation:
        return Icons.hotel;
      case ExpenseCategory.gifts:
        return Icons.card_giftcard;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.sports:
        return Icons.sports_soccer;
      case ExpenseCategory.beauty:
        return Icons.face_retouching_natural;
      case ExpenseCategory.technology:
        return Icons.devices;
      case ExpenseCategory.clothing:
        return Icons.checkroom;
      case ExpenseCategory.home:
        return Icons.home;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  static ExpenseCategory fromString(String? value) {
    if (value == null) return ExpenseCategory.other;
    try {
      return ExpenseCategory.values.firstWhere((e) => e.name == value);
    } catch (e) {
      return ExpenseCategory.other;
    }
  }
}

class CategoryDetector {
  static final Map<ExpenseCategory, List<String>> _categoryKeywords = {
    ExpenseCategory.groceries: [
      'supermarket',
      'grocery',
      'store',
      'market',
      'lidl',
      'aldi',
      'rewe',
      'edeka',
      'walmart',
      'kroger',
      'tesco',
      'carrefour',
      'vegetables',
      'fruit',
      'bread',
      'milk',
      'eggs',
      'meat',
      'fish',
      'cheese'
    ],
    ExpenseCategory.restaurants: [
      'restaurant',
      'dinner',
      'lunch',
      'breakfast',
      'meal',
      'bistro',
      'cafe',
      'bar',
      'pub',
      'pizzeria',
      'mcdonald',
      'burger',
      'pizza',
      'sushi',
      'chinese',
      'italian',
      'mexican',
      'thai',
      'indian',
      'kfc',
      'subway'
    ],
    ExpenseCategory.coffee: [
      'coffee',
      'starbucks',
      'espresso',
      'cappuccino',
      'latte',
      'cafe',
      'barista',
      'costa',
      'dunkin'
    ],
    ExpenseCategory.transport: [
      'uber',
      'lyft',
      'taxi',
      'bus',
      'train',
      'metro',
      'subway',
      'ticket',
      'transport',
      'ride'
    ],
    ExpenseCategory.gas: ['gas', 'petrol', 'fuel', 'station', 'shell', 'bp', 'chevron', 'exxon', 'mobil', 'total'],
    ExpenseCategory.parking: ['parking', 'garage', 'meter', 'lot'],
    ExpenseCategory.accommodation: [
      'hotel',
      'airbnb',
      'hostel',
      'motel',
      'inn',
      'lodge',
      'resort',
      'booking',
      'stay',
      'night'
    ],
    ExpenseCategory.entertainment: [
      'movie',
      'cinema',
      'theater',
      'concert',
      'show',
      'game',
      'entertainment',
      'netflix',
      'spotify',
      'disney',
      'ticket',
      'event',
      'festival',
      'club',
      'bowling',
      'arcade'
    ],
    ExpenseCategory.shopping: ['shopping', 'mall', 'store', 'amazon', 'ebay', 'online', 'purchase', 'buy', 'order'],
    ExpenseCategory.clothing: [
      'clothing',
      'clothes',
      'shirt',
      'pants',
      'dress',
      'shoes',
      'jacket',
      'h&m',
      'zara',
      'nike',
      'adidas',
      'fashion',
      'outfit',
      'underwear',
      'socks',
      'hat',
      'belt'
    ],
    ExpenseCategory.health: [
      'pharmacy',
      'doctor',
      'hospital',
      'medical',
      'medicine',
      'prescription',
      'dentist',
      'health',
      'clinic',
      'insurance',
      'treatment',
      'therapy',
      'vitamins'
    ],
    ExpenseCategory.beauty: [
      'beauty',
      'cosmetics',
      'makeup',
      'skincare',
      'haircut',
      'salon',
      'spa',
      'manicure',
      'pedicure',
      'shampoo',
      'perfume',
      'cream'
    ],
    ExpenseCategory.technology: [
      'technology',
      'phone',
      'computer',
      'laptop',
      'tablet',
      'software',
      'app',
      'subscription',
      'apple',
      'samsung',
      'google',
      'microsoft',
      'adobe',
      'headphones',
      'charger'
    ],
    ExpenseCategory.bills: [
      'electricity',
      'water',
      'internet',
      'phone bill',
      'rent',
      'mortgage',
      'insurance',
      'utilities',
      'subscription',
      'bill',
      'payment',
      'fee'
    ],
    ExpenseCategory.education: [
      'school',
      'university',
      'course',
      'book',
      'education',
      'tuition',
      'training',
      'workshop',
      'seminar',
      'lesson',
      'class'
    ],
    ExpenseCategory.sports: [
      'gym',
      'fitness',
      'sport',
      'yoga',
      'swimming',
      'football',
      'basketball',
      'tennis',
      'golf',
      'membership',
      'equipment',
      'training'
    ],
    ExpenseCategory.gifts: [
      'gift',
      'present',
      'birthday',
      'christmas',
      'anniversary',
      'wedding',
      'valentine',
      'flower',
      'card'
    ],
    ExpenseCategory.travel: [
      'flight',
      'airline',
      'airport',
      'travel',
      'trip',
      'vacation',
      'holiday',
      'visa',
      'passport',
      'luggage',
      'tour',
      'cruise'
    ],
    ExpenseCategory.home: [
      'home',
      'house',
      'furniture',
      'decoration',
      'ikea',
      'garden',
      'tools',
      'repair',
      'maintenance',
      'cleaning',
      'supplies'
    ]
  };

  static ExpenseCategory detectCategory(String title) {
    final lowerTitle = title.toLowerCase();

    // Check each category's keywords
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerTitle.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }

    return ExpenseCategory.other;
  }
}
