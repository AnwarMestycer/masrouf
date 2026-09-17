import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/account.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:meta/meta.dart';

/// A single logged movement of money.
///
/// Named `Txn` rather than `Transaction` to avoid colliding with drift's own
/// `Transaction` type, which is imported all over the data layer.
@immutable
class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.fxRateToBase,
    required this.categoryId,
    required this.accountId,
    required this.transferAccountId,
    required this.date,
    required this.note,
    required this.tags,
    required this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final TxnType type;

  /// Always a positive magnitude; [type] carries the direction. Storing signed
  /// amounts would make it possible to represent a "negative expense", which has
  /// no meaning and would corrupt every aggregate.
  final Money amount;

  /// Rate to the user's base currency, captured when the row was written.
  ///
  /// Frozen per row on purpose: editing today's EUR rate must not silently rewrite
  /// what last year's spending is reported to have cost.
  final double fxRateToBase;

  /// Null only for transfers.
  final String? categoryId;

  final String accountId;

  /// Destination account; non-null exactly when [type] is transfer.
  final String? transferAccountId;

  final DateTime date;
  final String? note;
  final List<String> tags;

  /// Set when this row was materialised from a recurring rule, so the rule can be
  /// traced and its generated rows found.
  final String? recurringRuleId;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTransfer => type.isTransfer;

  /// Signed value in base currency, for aggregation.
  Money signedBaseAmount(Money converted) =>
      type == TxnType.income ? converted : -converted;

  Txn copyWith({
    TxnType? type,
    Money? amount,
    double? fxRateToBase,
    String? categoryId,
    String? accountId,
    String? transferAccountId,
    DateTime? date,
    String? note,
    List<String>? tags,
    DateTime? updatedAt,
    bool clearCategory = false,
    bool clearTransferAccount = false,
    bool clearNote = false,
  }) =>
      Txn(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        fxRateToBase: fxRateToBase ?? this.fxRateToBase,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        accountId: accountId ?? this.accountId,
        transferAccountId: clearTransferAccount
            ? null
            : (transferAccountId ?? this.transferAccountId),
        date: date?.dateOnly ?? this.date,
        note: clearNote ? null : (note ?? this.note),
        tags: tags ?? this.tags,
        recurringRuleId: recurringRuleId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Txn &&
          other.id == id &&
          other.type == type &&
          other.amount == amount &&
          other.fxRateToBase == fxRateToBase &&
          other.categoryId == categoryId &&
          other.accountId == accountId &&
          other.transferAccountId == transferAccountId &&
          other.date == date &&
          other.note == note &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        amount,
        fxRateToBase,
        categoryId,
        accountId,
        transferAccountId,
        date,
        note,
        updatedAt,
      );
}

/// A transaction with its category and account already resolved.
///
/// Produced by a single joined query so a history list never issues a lookup per
/// row — the N+1 that would otherwise show up as jank on fast scrolls.
@immutable
class TxnView {
  const TxnView({
    required this.txn,
    required this.category,
    required this.account,
    required this.transferAccount,
    required this.baseAmount,
  });

  final Txn txn;
  final Category? category;
  final Account account;
  final Account? transferAccount;

  /// [Txn.amount] converted with the row's frozen rate. Precomputed here so list
  /// items and aggregates agree, and so the conversion is not redone per frame.
  final Money baseAmount;

  String get id => txn.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TxnView &&
          other.txn == txn &&
          other.category == category &&
          other.account == account &&
          other.transferAccount == transferAccount &&
          other.baseAmount == baseAmount);

  @override
  int get hashCode =>
      Object.hash(txn, category, account, transferAccount, baseAmount);
}
