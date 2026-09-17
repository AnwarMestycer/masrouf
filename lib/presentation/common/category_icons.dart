import 'package:flutter/material.dart';

/// The app's icon vocabulary.
///
/// Categories store a *key* into this map, never a raw code point. Flutter can
/// only tree-shake icon fonts when every [IconData] it sees is a compile-time
/// constant reachable from source; a code point loaded from the database defeats
/// that and would ship the entire Material font. Storing keys also means the icon
/// set can be redesigned without rewriting user rows.
abstract final class CategoryIcons {
  static const IconData fallback = Icons.category_outlined;

  static const Map<String, IconData> byKey = <String, IconData>{
    'wallet': Icons.account_balance_wallet_outlined,
    'laptop': Icons.laptop_mac_outlined,
    'receipt_refund': Icons.receipt_long_outlined,
    'gift': Icons.card_giftcard_outlined,
    'more': Icons.more_horiz_outlined,
    'groceries': Icons.local_grocery_store_outlined,
    'restaurant': Icons.restaurant_outlined,
    'transport': Icons.directions_bus_outlined,
    'home': Icons.home_outlined,
    'utilities': Icons.bolt_outlined,
    'subscriptions': Icons.subscriptions_outlined,
    'health': Icons.medical_services_outlined,
    'family': Icons.family_restroom_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'gym': Icons.fitness_center_outlined,
    'savings': Icons.savings_outlined,
    'coffee': Icons.local_cafe_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'phone': Icons.smartphone_outlined,
    'internet': Icons.wifi_outlined,
    'education': Icons.school_outlined,
    'travel': Icons.flight_takeoff_outlined,
    'pets': Icons.pets_outlined,
    'repairs': Icons.build_outlined,
    'charity': Icons.volunteer_activism_outlined,
    'entertainment': Icons.movie_outlined,
    'clothes': Icons.checkroom_outlined,
    'baby': Icons.child_friendly_outlined,
    'insurance': Icons.shield_outlined,
    'tax': Icons.account_balance_outlined,
    'invest': Icons.trending_up_outlined,
    'category': Icons.category_outlined,
  };

  static IconData resolve(String key) => byKey[key] ?? fallback;

  /// Stable ordering for the icon picker.
  static List<String> get keys => byKey.keys.toList(growable: false);
}

/// Icons for the account types, kept beside the category set for the same
/// tree-shaking reason.
abstract final class AccountIcons {
  static const IconData cash = Icons.payments_outlined;
  static const IconData bank = Icons.account_balance_outlined;
  static const IconData savings = Icons.savings_outlined;
  static const IconData foreign = Icons.currency_exchange_outlined;
}
