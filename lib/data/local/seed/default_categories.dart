import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

/// The starter set created on a user's first launch.
///
/// This is the single source of truth for seeding — there is deliberately no
/// Postgres trigger doing the same job. Bootstrap pulls first and only seeds when
/// the pull came back with no categories, so a reinstall adopts the existing set
/// instead of duplicating it. Ids are minted fresh here rather than being fixed
/// constants, because two devices seeding the same fixed id would collide on
/// insert instead of converging.
abstract final class DefaultSeed {
  /// `(name key, icon key)` pairs. The first element is a stable English key,
  /// not the label shown to the user: [categories] translates it through the
  /// `names` map so a French or Arabic user's very first screen is not in
  /// English. The user renames freely afterwards and the row, not the constant,
  /// is authoritative from then on.
  static const List<(String, String)> incomeCategories = <(String, String)>[
    ('Salary', 'wallet'),
    ('Freelance', 'laptop'),
    ('Reimbursement', 'receipt_refund'),
    ('Gift', 'gift'),
    ('Other', 'more'),
  ];

  static const List<(String, String)> expenseCategories = <(String, String)>[
    ('Groceries', 'groceries'),
    ('Eating Out', 'restaurant'),
    ('Transport', 'transport'),
    ('Rent', 'home'),
    ('Utilities', 'utilities'),
    ('Subscriptions', 'subscriptions'),
    ('Health', 'health'),
    ('Family', 'family'),
    ('Shopping', 'shopping'),
    ('Gym', 'gym'),
    ('Savings/Zakat', 'savings'),
    ('Other', 'more'),
  ];

  /// Palette slots for the seeded categories.
  ///
  /// The palette is eight validated hues and there are twelve default expense
  /// categories, so some reuse is unavoidable. Slots are assigned so the
  /// categories most likely to dominate a month — groceries, eating out,
  /// transport, rent — take distinct leading slots; repeats fall on the tail,
  /// which the donut folds into "Other" before two same-coloured slices can
  /// appear together.
  static const List<int> _incomePalette = <int>[0, 2, 5, 4, 6];
  static const List<int> _expensePalette = <int>[
    0, 1, 2, 3, 4, 5, 6, 7, 1, 3, 2, 6,
  ];

  /// [names] maps the stable English key to the label in the user's language.
  /// A missing key falls back to the key itself, so an untranslated addition
  /// shows in English rather than blank.
  static List<Category> categories(
    List<int> palette, {
    Map<String, String> names = const <String, String>{},
  }) {
    final now = DateTime.now();
    final result = <Category>[];

    for (var i = 0; i < incomeCategories.length; i++) {
      final (name, icon) = incomeCategories[i];
      result.add(
        Category(
          id: Ids.newId(),
          name: names[name] ?? name,
          kind: CategoryKind.income,
          icon: icon,
          color: palette[_incomePalette[i % _incomePalette.length]],
          sortOrder: i,
          isDefault: true,
          updatedAt: now,
        ),
      );
    }

    for (var i = 0; i < expenseCategories.length; i++) {
      final (name, icon) = expenseCategories[i];
      result.add(
        Category(
          id: Ids.newId(),
          name: names[name] ?? name,
          kind: CategoryKind.expense,
          icon: icon,
          color: palette[_expensePalette[i % _expensePalette.length]],
          sortOrder: i,
          isDefault: true,
          updatedAt: now,
        ),
      );
    }

    return result;
  }

  /// A single cash account, so the add flow has a valid default from the very
  /// first tap instead of forcing an account-creation detour.
  static Account cashAccount(Currency base, {String? name}) => Account(
        id: Ids.newId(),
        name: name ?? 'Cash',
        type: AccountType.cash,
        currency: base,
        openingBalance: Money.zero(base),
        sortOrder: 0,
        archived: false,
        updatedAt: DateTime.now(),
      );
}
