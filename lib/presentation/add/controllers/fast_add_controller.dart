import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/ids.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:meta/meta.dart';

/// The add sheet's state.
///
/// The amount is held as the digits the user typed rather than as a [Money], so
/// backspace and the decimal key behave exactly as they look on screen —
/// `2.` and `2.0` are different things to a person mid-entry even though they are
/// the same number.
@immutable
class FastAddState {
  const FastAddState({
    required this.currency,
    this.whole = '',
    this.fraction = '',
    this.decimalMode = false,
    this.type = TxnType.expense,
    this.categoryId,
    this.accountId,
    this.transferAccountId,
    required this.date,
    this.note = '',
    this.tags = const <String>[],
    this.fxRateToBase = 1,
    this.saving = false,
    this.editingId,
  });

  factory FastAddState.initial(Currency currency) =>
      FastAddState(currency: currency, date: DateTime.now().dateOnly);

  final String whole;
  final String fraction;

  /// True once the decimal key has been pressed, so subsequent digits go to the
  /// right of the separator.
  final bool decimalMode;

  final TxnType type;
  final String? categoryId;
  final String? accountId;
  final String? transferAccountId;
  final DateTime date;
  final String note;
  final List<String> tags;
  final Currency currency;

  /// The rate that will be frozen onto the transaction, or null when the user
  /// has not set one for [currency] yet.
  ///
  /// Null blocks the save. Substituting 1.0 would record a foreign amount as if
  /// it were base currency, and because the rate is frozen at write time and
  /// editing it later never rewrites history, that error is permanent and
  /// silent — the worst failure mode this app has.
  final double? fxRateToBase;

  final bool saving;

  /// Non-null when editing an existing transaction rather than creating one.
  final String? editingId;

  bool get isEditing => editingId != null;

  Money get amount => Money(
        (int.tryParse(whole.isEmpty ? '0' : whole) ?? 0) * Money.scale +
            int.parse(fraction.padRight(3, '0').padLeft(3, '0')),
        currency,
      );

  bool get hasAmount => amount.isPositive;

  /// True when [fxRateToBase] is unknown, so the UI can say why saving is
  /// blocked instead of just disabling the button.
  bool get rateMissing => fxRateToBase == null;

  /// Everything the write needs is present.
  bool get canSave =>
      hasAmount &&
      accountId != null &&
      !rateMissing &&
      !saving &&
      (type.isTransfer
          ? transferAccountId != null && transferAccountId != accountId
          : categoryId != null);

  /// What the amount row displays while typing.
  String get displayWhole => whole.isEmpty ? '0' : whole;
  String? get displayFraction => decimalMode ? fraction : null;

  FastAddState copyWith({
    String? whole,
    String? fraction,
    bool? decimalMode,
    TxnType? type,
    String? categoryId,
    String? accountId,
    String? transferAccountId,
    DateTime? date,
    String? note,
    List<String>? tags,
    Currency? currency,
    double? fxRateToBase,
    bool? saving,
    bool clearCategory = false,
    bool clearTransferAccount = false,
    bool clearRate = false,
  }) =>
      FastAddState(
        whole: whole ?? this.whole,
        fraction: fraction ?? this.fraction,
        decimalMode: decimalMode ?? this.decimalMode,
        type: type ?? this.type,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        accountId: accountId ?? this.accountId,
        transferAccountId: clearTransferAccount
            ? null
            : (transferAccountId ?? this.transferAccountId),
        date: date ?? this.date,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        currency: currency ?? this.currency,
        fxRateToBase: clearRate ? null : (fxRateToBase ?? this.fxRateToBase),
        saving: saving ?? this.saving,
        editingId: editingId,
      );
}

/// Drives the fast-add screen.
///
/// Deliberately synchronous everywhere except [save]: every keystroke must land
/// in the same frame it was pressed, so nothing here awaits anything.
class FastAddController extends Notifier<FastAddState> {
  @override
  FastAddState build() {
    final currency = ref.watch(baseCurrencyProvider);
    return FastAddState.initial(currency);
  }

  static const int _maxWholeDigits = 9;

  void pressDigit(String digit) {
    if (state.decimalMode) {
      // Cap at the currency's precision — extra digits would be silently
      // rounded away, which looks like the app ignoring input.
      if (state.fraction.length >= state.currency.decimals) return;
      state = state.copyWith(fraction: state.fraction + digit);
      return;
    }
    if (state.whole.length >= _maxWholeDigits) return;
    // Avoid a leading zero: "0" then "5" should read 5, not 05.
    final next = state.whole == '0' ? digit : state.whole + digit;
    state = state.copyWith(whole: next);
  }

  void pressDecimal() {
    if (state.decimalMode) return;
    state = state.copyWith(
      decimalMode: true,
      whole: state.whole.isEmpty ? '0' : state.whole,
    );
  }

  void backspace() {
    if (state.decimalMode && state.fraction.isNotEmpty) {
      state = state.copyWith(
        fraction: state.fraction.substring(0, state.fraction.length - 1),
      );
      return;
    }
    if (state.decimalMode) {
      state = state.copyWith(decimalMode: false);
      return;
    }
    if (state.whole.isNotEmpty) {
      state = state.copyWith(
        whole: state.whole.substring(0, state.whole.length - 1),
      );
    }
  }

  void clearAmount() =>
      state = state.copyWith(whole: '', fraction: '', decimalMode: false);

  /// Switching between income and expense invalidates the chosen category, since
  /// the two kinds draw from different lists.
  void setType(TxnType type) {
    if (type == state.type) return;
    state = state.copyWith(
      type: type,
      clearCategory: true,
      clearTransferAccount: !type.isTransfer,
    );
  }

  void setCategory(String id) => state = state.copyWith(categoryId: id);

  /// [rateToBase] is null when no rate has been set for [currency] yet; the
  /// state carries that through rather than defaulting, so [FastAddState.canSave]
  /// can refuse the write.
  void setAccount(String id, Currency currency, double? rateToBase) {
    state = state.copyWith(
      accountId: id,
      currency: currency,
      fxRateToBase: rateToBase,
      clearRate: rateToBase == null,
      // A foreign account cannot be its own transfer destination.
      clearTransferAccount: state.transferAccountId == id,
      // Precision differs between currencies; trim rather than silently round.
      fraction: state.fraction.length > currency.decimals
          ? state.fraction.substring(0, currency.decimals)
          : state.fraction,
    );
  }

  /// Adopts a rate that only became known after the account was chosen.
  ///
  /// The rate table is read asynchronously, so on a cold start the account is
  /// picked a frame or two before its rate exists. Without this the entry would
  /// stay blocked until the user re-tapped the account.
  ///
  /// Never called while editing: an existing transaction keeps the rate frozen
  /// at the moment it was written.
  void setRate(double? rateToBase) {
    if (state.isEditing || rateToBase == state.fxRateToBase) return;
    state = state.copyWith(
      fxRateToBase: rateToBase,
      clearRate: rateToBase == null,
    );
  }

  void setTransferAccount(String id) =>
      state = state.copyWith(transferAccountId: id);

  void setDate(DateTime date) => state = state.copyWith(date: date.dateOnly);

  void setNote(String note) => state = state.copyWith(note: note);

  void setTags(List<String> tags) => state = state.copyWith(tags: tags);

  /// Loads an existing transaction for editing.
  void loadForEdit(Txn txn) {
    final magnitude = txn.amount.milli.abs();
    final whole = (magnitude ~/ Money.scale).toString();
    final fractionDigits = (magnitude % Money.scale)
        .toString()
        .padLeft(3, '0')
        .substring(0, txn.amount.currency.decimals);
    final fraction = fractionDigits.replaceFirst(RegExp(r'0+$'), '');

    state = FastAddState(
      currency: txn.amount.currency,
      whole: whole,
      fraction: fraction,
      decimalMode: fraction.isNotEmpty,
      type: txn.type,
      categoryId: txn.categoryId,
      accountId: txn.accountId,
      transferAccountId: txn.transferAccountId,
      date: txn.date,
      note: txn.note ?? '',
      tags: txn.tags,
      fxRateToBase: txn.fxRateToBase,
      editingId: txn.id,
    );
  }

  /// Writes the transaction.
  ///
  /// The repository commits to SQLite and queues the push, so this returns in
  /// microseconds and the caller can pop the route immediately — there is no
  /// spinner in the happy path because there is nothing to wait for.
  /// Returns the repository's [Result] rather than a bool so the caller can
  /// tell the user *why* a save failed. Returning bool is what made the primary
  /// action fail silently: there was nothing left to report.
  Future<Result<Txn>> save() async {
    if (!state.canSave) {
      return const Err<Txn>(
        Failure(
          FailureCode.validation,
          debugMessage: 'save() called while canSave was false',
        ),
      );
    }
    state = state.copyWith(saving: true);

    final now = DateTime.now();
    final txn = Txn(
      id: state.editingId ?? Ids.newId(),
      type: state.type,
      amount: state.amount,
      // canSave has already refused a null rate.
      fxRateToBase: state.fxRateToBase!,
      categoryId: state.type.isTransfer ? null : state.categoryId,
      accountId: state.accountId!,
      transferAccountId: state.type.isTransfer ? state.transferAccountId : null,
      date: state.date,
      note: state.note.trim().isEmpty ? null : state.note.trim(),
      tags: state.tags,
      recurringRuleId: null,
      createdAt: now,
      updatedAt: now,
    );

    final repository = ref.read(transactionRepositoryProvider);
    final result = state.isEditing
        ? await repository.update(txn)
        : await repository.add(txn);

    if (result.isErr) state = state.copyWith(saving: false);
    return result;
  }
}

final fastAddControllerProvider =
    NotifierProvider.autoDispose<FastAddController, FastAddState>(
  FastAddController.new,
);
