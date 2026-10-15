import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:meta/meta.dart';

@immutable
class UserSettings {
  const UserSettings({
    required this.baseCurrency,
    required this.locale,
    required this.themeMode,
    required this.paydayDayOfMonth,
    this.savings = const SavingsPlan(rate: 0),
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

  /// Pay-yourself-first. A rate of zero means no plan, which is what every
  /// account without one reads as — nothing committed, nothing reserved.
  final SavingsPlan savings;

  UserSettings copyWith({
    Currency? baseCurrency,
    String? locale,
    ThemeMode? themeMode,
    int? paydayDayOfMonth,
    SavingsPlan? savings,
  }) =>
      UserSettings(
        baseCurrency: baseCurrency ?? this.baseCurrency,
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        paydayDayOfMonth: paydayDayOfMonth ?? this.paydayDayOfMonth,
        savings: savings ?? this.savings,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettings &&
          other.baseCurrency == baseCurrency &&
          other.locale == locale &&
          other.themeMode == themeMode &&
          other.paydayDayOfMonth == paydayDayOfMonth &&
          other.savings.rate == savings.rate &&
          other.savings.floor == savings.floor &&
          other.savings.ceiling == savings.ceiling &&
          other.savings.recoveryPeriods == savings.recoveryPeriods);

  @override
  int get hashCode => Object.hash(
        baseCurrency,
        locale,
        themeMode,
        paydayDayOfMonth,
        savings.rate,
        savings.floor,
        savings.ceiling,
        savings.recoveryPeriods,
      );
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
