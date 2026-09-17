import 'package:flutter/widgets.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/validation/validators.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/l10n/app_localizations.dart';

/// Shorthand for the generated localisations.
extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}

/// Turns a domain [Failure] into something a person can act on.
///
/// The mapping lives here rather than in the domain layer so failures stay free
/// of `BuildContext` and the same code renders in English, French or Arabic.
/// Anything not explicitly handled falls back to the generic message — an
/// unmapped code must never surface a raw exception string to the user.
extension FailureMessage on Failure {
  String localise(L10n l10n) => switch (code) {
        FailureCode.invalidCredentials => l10n.errorInvalidCredentials,
        FailureCode.emailAlreadyRegistered => l10n.errorEmailAlreadyRegistered,
        FailureCode.weakPassword => l10n.errorWeakPassword,
        FailureCode.emailNotConfirmed => l10n.errorEmailNotConfirmed,
        FailureCode.network => l10n.errorNetwork,
        FailureCode.rateLimited => l10n.errorRateLimited,
        FailureCode.sessionExpired => l10n.errorSessionExpired,
        FailureCode.notFound ||
        FailureCode.validation ||
        FailureCode.storage ||
        FailureCode.unknown =>
          l10n.errorUnknown,
      };
}

extension ValidationMessage on ValidationError {
  String localise(L10n l10n) => switch (this) {
        ValidationError.emailRequired => l10n.validationEmailRequired,
        ValidationError.emailInvalid => l10n.validationEmailInvalid,
        ValidationError.passwordRequired => l10n.validationPasswordRequired,
        ValidationError.passwordTooShort => l10n.validationPasswordTooShort,
        ValidationError.passwordMismatch => l10n.validationPasswordMismatch,
        ValidationError.amountRequired => l10n.validationAmountRequired,
        ValidationError.amountNotPositive => l10n.validationAmountPositive,
        ValidationError.nameRequired => l10n.validationNameRequired,
        ValidationError.categoryRequired => l10n.validationCategoryRequired,
        ValidationError.rateNotPositive => l10n.validationRatePositive,
      };
}

extension TxnTypeLabel on TxnType {
  String localise(L10n l10n) => switch (this) {
        TxnType.income => l10n.txnIncome,
        TxnType.expense => l10n.txnExpense,
        TxnType.transfer => l10n.txnTransfer,
      };
}

extension AccountTypeLabel on AccountType {
  String localise(L10n l10n) => switch (this) {
        AccountType.cash => l10n.accountTypeCash,
        AccountType.bank => l10n.accountTypeBank,
        AccountType.savings => l10n.accountTypeSavings,
        AccountType.foreign => l10n.accountTypeForeign,
      };
}

extension CadenceLabel on Cadence {
  String localise(L10n l10n) => switch (this) {
        Cadence.weekly => l10n.recurringCadenceWeekly,
        Cadence.monthly => l10n.recurringCadenceMonthly,
      };
}
