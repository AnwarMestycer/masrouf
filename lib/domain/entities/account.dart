import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:meta/meta.dart';

/// A place money sits: a wallet, a bank account, a savings pot.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.sortOrder,
    required this.archived,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final Currency currency;

  /// What the account held before the first logged transaction. Without it a
  /// running balance would only ever show the delta since the app was installed.
  final Money openingBalance;

  final int sortOrder;

  /// Archived accounts keep their history and stay selectable when editing an old
  /// transaction, but drop out of the add flow and the balance header.
  final bool archived;

  final DateTime updatedAt;

  Account copyWith({
    String? name,
    AccountType? type,
    Currency? currency,
    Money? openingBalance,
    int? sortOrder,
    bool? archived,
    DateTime? updatedAt,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        openingBalance: openingBalance ?? this.openingBalance,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          other.currency == currency &&
          other.openingBalance == openingBalance &&
          other.sortOrder == sortOrder &&
          other.archived == archived);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        currency,
        openingBalance,
        sortOrder,
        archived,
      );
}

/// An account paired with its computed live balance.
///
/// Separate from [Account] because the balance is derived state maintained
/// incrementally by the local aggregate tables, not a stored column — keeping it
/// off the entity stops it from being accidentally written back on an edit.
@immutable
class AccountWithBalance {
  const AccountWithBalance({required this.account, required this.balance});

  final Account account;
  final Money balance;

  String get id => account.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountWithBalance &&
          other.account == account &&
          other.balance == balance);

  @override
  int get hashCode => Object.hash(account, balance);
}
