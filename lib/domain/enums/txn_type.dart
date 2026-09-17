/// Whether a transaction adds to, removes from, or moves between accounts.
enum TxnType {
  income('income'),
  expense('expense'),
  transfer('transfer');

  const TxnType(this.wire);

  /// The value stored in Postgres and drift. Explicit rather than [name] so
  /// renaming the Dart identifier can never silently orphan existing rows.
  final String wire;

  static TxnType fromWire(String value) => switch (value) {
        'income' => TxnType.income,
        'expense' => TxnType.expense,
        'transfer' => TxnType.transfer,
        _ => throw ArgumentError.value(value, 'value', 'Unknown TxnType'),
      };

  /// The direction this type moves the *source* account's balance.
  /// A transfer leaves the source like an expense does; the destination side is
  /// added back separately when balances are computed.
  int get balanceSign => this == TxnType.income ? 1 : -1;

  bool get isTransfer => this == TxnType.transfer;
}

/// Income or expense — the two kinds a category can belong to. Transfers are
/// deliberately uncategorised: money moving between your own accounts is not
/// spending, and letting it carry a category would double-count it in analytics.
enum CategoryKind {
  income('income'),
  expense('expense');

  const CategoryKind(this.wire);

  final String wire;

  static CategoryKind fromWire(String value) => switch (value) {
        'income' => CategoryKind.income,
        'expense' => CategoryKind.expense,
        _ => throw ArgumentError.value(value, 'value', 'Unknown CategoryKind'),
      };

  TxnType get asTxnType =>
      this == CategoryKind.income ? TxnType.income : TxnType.expense;
}

enum AccountType {
  cash('cash'),
  bank('bank'),
  savings('savings'),
  foreign('foreign');

  const AccountType(this.wire);

  final String wire;

  static AccountType fromWire(String value) => switch (value) {
        'cash' => AccountType.cash,
        'bank' => AccountType.bank,
        'savings' => AccountType.savings,
        'foreign' => AccountType.foreign,
        _ => throw ArgumentError.value(value, 'value', 'Unknown AccountType'),
      };
}

enum Cadence {
  weekly('weekly'),
  monthly('monthly');

  const Cadence(this.wire);

  final String wire;

  static Cadence fromWire(String value) => switch (value) {
        'weekly' => Cadence.weekly,
        'monthly' => Cadence.monthly,
        _ => throw ArgumentError.value(value, 'value', 'Unknown Cadence'),
      };
}

/// Where a planned expense is in its life.
///
/// Only [pending] reserves money against Safe to spend. [done] means it was
/// confirmed and a real transaction now carries it; [cancelled] means it never
/// happened. Both terminal states are kept rather than deleted so a plan that
/// was skipped can still be seen in the calendar it was planned on.
enum PlannedStatus {
  pending('pending'),
  done('done'),
  cancelled('cancelled');

  const PlannedStatus(this.wire);

  final String wire;

  static PlannedStatus fromWire(String value) => values.firstWhere(
        (s) => s.wire == value,
        orElse: () => PlannedStatus.pending,
      );
}
