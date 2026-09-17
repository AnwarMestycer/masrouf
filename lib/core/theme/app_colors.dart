import 'package:flutter/material.dart';

/// The app's colour system.
///
/// One seeded Material 3 scheme carries the neutral chrome; the semantic
/// money colours below are defined per-brightness rather than pulled from the
/// scheme, because income/expense must stay legible and consistent regardless of
/// how the seed rolls the tertiary slots.
abstract final class AppColors {
  /// Deep teal — reads as "money" without the debt-collector green.
  static const Color seed = Color(0xFF0E7C7B);

  static const Color incomeLight = Color(0xFF0F7B3E);
  static const Color incomeDark = Color(0xFF5BD48A);
  static const Color expenseLight = Color(0xFFB3261E);
  static const Color expenseDark = Color(0xFFFF8A80);
  static const Color transferLight = Color(0xFF4B5A9E);
  static const Color transferDark = Color(0xFF9DAEFF);

  /// Default palette offered when creating a category.
  ///
  /// These eight hues and their dark counterparts are a validated categorical
  /// set: they clear the lightness band, chroma floor, adjacent-pair CVD
  /// separation (worst ΔE 9.1 light / 8.4 dark) and normal-vision separation
  /// (19.6 / 19.3) against both chart surfaces. The *order* is the safety
  /// mechanism, not decoration — reordering breaks the adjacent-pair guarantee,
  /// so add hues at the end rather than inserting.
  ///
  /// Three light slots sit under 3:1 contrast on a light surface, so every chart
  /// using them ships direct labels and a ranked list beside it rather than
  /// relying on slice colour alone.
  static const List<Color> categoryPalette = <Color>[
    Color(0xFF2A78D6), // blue
    Color(0xFFEB6834), // orange
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFFE87BA4), // magenta
    Color(0xFF008300), // green
    Color(0xFF4A3AA7), // violet
    Color(0xFFE34948), // red
  ];

  /// The same eight hues re-stepped for a dark surface.
  ///
  /// Selected for the dark lightness band rather than derived by lightening the
  /// light values — an automatic flip lands outside the band and loses contrast.
  static const List<Color> categoryPaletteDark = <Color>[
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];

  /// Resolves a stored category colour for the current surface.
  ///
  /// Categories persist a single ARGB value — the light step. When the palette
  /// slot is recognised the matching dark step is substituted; a colour the user
  /// picked freely is returned untouched, since there is no principled way to
  /// re-step an arbitrary hue.
  static Color resolveCategoryColor(int argb, Brightness brightness) {
    if (brightness == Brightness.light) return Color(argb);
    for (var i = 0; i < categoryPalette.length; i++) {
      if (categoryPalette[i].toARGB32() == argb) return categoryPaletteDark[i];
    }
    return Color(argb);
  }

  /// Neutral for the aggregated "Other" slice. Deliberately outside the
  /// categorical set so it never reads as one more category.
  static const Color otherSliceLight = Color(0xFF8A8A85);
  static const Color otherSliceDark = Color(0xFF6E6E69);
}

/// Semantic colours that Material's [ColorScheme] has no slot for.
///
/// A [ThemeExtension] rather than loose globals so widgets read them through
/// `Theme.of(context)` and they animate correctly across a theme switch.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.positiveSurface,
    required this.negativeSurface,
  });

  factory MoneyColors.of(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return MoneyColors(
      income: isDark ? AppColors.incomeDark : AppColors.incomeLight,
      expense: isDark ? AppColors.expenseDark : AppColors.expenseLight,
      transfer: isDark ? AppColors.transferDark : AppColors.transferLight,
      positiveSurface: (isDark ? AppColors.incomeDark : AppColors.incomeLight)
          .withValues(alpha: isDark ? 0.16 : 0.10),
      negativeSurface: (isDark ? AppColors.expenseDark : AppColors.expenseLight)
          .withValues(alpha: isDark ? 0.16 : 0.10),
    );
  }

  final Color income;
  final Color expense;
  final Color transfer;
  final Color positiveSurface;
  final Color negativeSurface;

  @override
  MoneyColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? positiveSurface,
    Color? negativeSurface,
  }) =>
      MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
        positiveSurface: positiveSurface ?? this.positiveSurface,
        negativeSurface: negativeSurface ?? this.negativeSurface,
      );

  @override
  MoneyColors lerp(ThemeExtension<MoneyColors>? other, double t) {
    if (other is! MoneyColors) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      positiveSurface: Color.lerp(positiveSurface, other.positiveSurface, t)!,
      negativeSurface: Color.lerp(negativeSurface, other.negativeSurface, t)!,
    );
  }
}

extension MoneyColorsX on ThemeData {
  MoneyColors get money => extension<MoneyColors>()!;
}
