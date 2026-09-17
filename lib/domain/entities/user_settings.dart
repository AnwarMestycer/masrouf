import 'package:masrouf/core/money/currency.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:meta/meta.dart';

@immutable
class UserSettings {
  const UserSettings({
    required this.baseCurrency,
    required this.locale,
    required this.themeMode,
    required this.paydayDayOfMonth,
  });

  static const UserSettings fallback = UserSettings(
    baseCurrency: Currency.tnd,
    locale: 'fr',
    themeMode: ThemeMode.system,
    paydayDayOfMonth: 25,
  );

  /// Everything is reported in this currency. Foreign amounts keep their original
  /// currency on the row and are converted for display only.
  final Currency baseCurrency;

  final String locale;
  final ThemeMode themeMode;

  /// Drives "safe to spend": the horizon is the next occurrence of this day.
  final int paydayDayOfMonth;

  UserSettings copyWith({
    Currency? baseCurrency,
    String? locale,
    ThemeMode? themeMode,
    int? paydayDayOfMonth,
  }) =>
      UserSettings(
        baseCurrency: baseCurrency ?? this.baseCurrency,
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        paydayDayOfMonth: paydayDayOfMonth ?? this.paydayDayOfMonth,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettings &&
          other.baseCurrency == baseCurrency &&
          other.locale == locale &&
          other.themeMode == themeMode &&
          other.paydayDayOfMonth == paydayDayOfMonth);

  @override
  int get hashCode =>
      Object.hash(baseCurrency, locale, themeMode, paydayDayOfMonth);
}

/// A user-maintained conversion rate. There is no rate provider in v1 — the user
/// types what their exchange office actually gave them, which for TND is more
/// accurate than any published mid-market rate.
@immutable
class ExchangeRate {
  const ExchangeRate({
    required this.currency,
    required this.rateToBase,
    required this.updatedAt,
  });

  final Currency currency;
  final double rateToBase;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExchangeRate &&
          other.currency == currency &&
          other.rateToBase == rateToBase);

  @override
  int get hashCode => Object.hash(currency, rateToBase);
}

/// The authenticated identity, reduced to what the UI actually needs.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.emailConfirmed,
  });

  final String id;
  final String email;
  final bool emailConfirmed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.emailConfirmed == emailConfirmed);

  @override
  int get hashCode => Object.hash(id, email, emailConfirmed);
}
