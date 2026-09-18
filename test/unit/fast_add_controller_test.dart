import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/domain/entities/history_filter.dart';
import 'package:masrouf/domain/entities/txn.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';
import 'package:masrouf/presentation/add/controllers/fast_add_controller.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// Records what the add flow tried to write, without touching a database.
class _FakeTransactionRepository implements TransactionRepository {
  final List<Txn> added = <Txn>[];

  @override
  Future<Result<Txn>> add(Txn txn) async {
    added.add(txn);
    return Ok<Txn>(txn);
  }

  @override
  Future<Result<Txn>> update(Txn txn) async {
    added.add(txn);
    return Ok<Txn>(txn);
  }

  @override
  Future<Result<void>> delete(String id) async => const Ok<void>(null);

  @override
  Future<Result<void>> restore(String id) async => const Ok<void>(null);

  @override
  Future<Result<Txn>> duplicate(String id) async => throw UnimplementedError();

  @override
  Future<Result<int>> recategorize(List<String> ids, String categoryId) async =>
      const Ok<int>(0);

  @override
  Future<Result<int>> addTag(List<String> ids, String tag) async =>
      const Ok<int>(0);

  @override
  Future<Result<int>> deleteMany(List<String> ids) async => const Ok<int>(0);

  @override
  Future<Result<int>> restoreMany(List<String> ids) async => const Ok<int>(0);

  @override
  Future<Result<String>> exportCsv() async => const Ok<String>('');

  @override
  Future<Txn?> getById(String id) async => null;

  @override
  Future<List<TxnView>> page(HistoryFilter filter, {required int offset}) async =>
      const <TxnView>[];

  @override
  Stream<List<TxnView>> watchRecent({int limit = 5}) =>
      const Stream<List<TxnView>>.empty();

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();

  @override
  Stream<List<String>> watchTags() => const Stream<List<String>>.empty();
}

void main() {
  late ProviderContainer container;
  late _FakeTransactionRepository repository;

  FastAddController controller() =>
      container.read(fastAddControllerProvider.notifier);
  FastAddState state() => container.read(fastAddControllerProvider);

  setUp(() {
    repository = _FakeTransactionRepository();
    container = ProviderContainer(
      overrides: [
        baseCurrencyProvider.overrideWithValue(Currency.tnd),
        transactionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  group('amount entry', () {
    test('digits build the whole part', () {
      controller()
        ..pressDigit('2')
        ..pressDigit('5');
      expect(state().amount.milli, 25000);
      expect(state().displayWhole, '25');
    });

    test('the decimal key switches to millimes', () {
      // "2,5" must read as two and a half dinars, matching how prices are said.
      controller()
        ..pressDigit('2')
        ..pressDecimal()
        ..pressDigit('5');
      expect(state().amount.milli, 2500);
    });

    test('precision is capped at the currency scale', () {
      final c = controller()
        ..pressDigit('1')
        ..pressDecimal()
        ..pressDigit('2')
        ..pressDigit('3')
        ..pressDigit('4');
      c.pressDigit('5'); // ignored — TND has three decimals
      expect(state().amount.milli, 1234);
    });

    test('a leading zero is replaced rather than appended', () {
      controller()
        ..pressDigit('0')
        ..pressDigit('5');
      expect(state().displayWhole, '5');
    });

    test('a second decimal press is ignored', () {
      controller()
        ..pressDigit('1')
        ..pressDecimal()
        ..pressDecimal()
        ..pressDigit('5');
      expect(state().amount.milli, 1500);
    });

    test('backspace unwinds the fraction, then the separator, then digits', () {
      final c = controller()
        ..pressDigit('1')
        ..pressDigit('2')
        ..pressDecimal()
        ..pressDigit('5');

      c.backspace();
      expect(state().displayFraction, '');
      c.backspace();
      expect(state().displayFraction, isNull);
      c.backspace();
      expect(state().displayWhole, '1');
      c.backspace();
      expect(state().hasAmount, isFalse);
      // Backspacing past empty must not throw.
      c.backspace();
      expect(state().hasAmount, isFalse);
    });
  });

  group('canSave', () {
    test('needs an amount, an account and a category', () {
      final c = controller();
      expect(state().canSave, isFalse);

      c.pressDigit('5');
      expect(state().canSave, isFalse, reason: 'no account yet');

      c.setAccount('acc', Currency.tnd, 1);
      expect(state().canSave, isFalse, reason: 'no category yet');

      c.setCategory('cat');
      expect(state().canSave, isTrue);
    });

    test('a transfer needs a distinct destination instead of a category', () {
      final c = controller()
        ..pressDigit('5')
        ..setAccount('acc', Currency.tnd, 1)
        ..setType(TxnType.transfer);
      expect(state().canSave, isFalse);

      c.setTransferAccount('acc');
      expect(state().canSave, isFalse, reason: 'destination equals source');

      c.setTransferAccount('acc-2');
      expect(state().canSave, isTrue);
    });

    test('switching type clears a category that no longer applies', () {
      final c = controller()
        ..setAccount('acc', Currency.tnd, 1)
        ..setCategory('expense-cat');
      c.setType(TxnType.income);
      expect(state().categoryId, isNull);
    });
  });

  group('save', () {
    test('writes a positive magnitude with the direction in the type', () async {
      controller()
        ..pressDigit('2')
        ..pressDigit('5')
        ..setAccount('acc', Currency.tnd, 1)
        ..setCategory('cat');

      expect((await controller().save()).isOk, isTrue);
      expect(repository.added, hasLength(1));

      final written = repository.added.single;
      expect(written.type, TxnType.expense);
      expect(written.amount.milli, 25000);
      expect(written.amount.isPositive, isTrue);
      expect(written.categoryId, 'cat');
      expect(written.transferAccountId, isNull);
    });

    test('refuses an incomplete entry', () async {
      controller().pressDigit('5');
      expect((await controller().save()).isErr, isTrue);
      expect(repository.added, isEmpty);
    });

    test('a transfer is written uncategorised', () async {
      controller()
        ..pressDigit('9')
        ..setAccount('acc', Currency.tnd, 1)
        ..setType(TxnType.transfer)
        ..setTransferAccount('acc-2');

      expect((await controller().save()).isOk, isTrue);
      final written = repository.added.single;
      expect(written.categoryId, isNull);
      expect(written.transferAccountId, 'acc-2');
    });
  });

  /// The rate is frozen onto the row at write time and editing it later never
  /// rewrites history, so a rate guessed as 1.0 is permanently and invisibly
  /// wrong. Refusing to write is the only safe answer.
  group('missing exchange rate', () {
    test('an account with no known rate blocks the save', () async {
      controller()
        ..pressDigit('5')
        ..setCategory('cat')
        ..setAccount('acc-eur', Currency.eur, null);

      expect(state().rateMissing, isTrue);
      expect(state().canSave, isFalse);
      expect((await controller().save()).isErr, isTrue);
      expect(repository.added, isEmpty);
    });

    test('the base currency never needs a rate', () {
      controller()
        ..pressDigit('5')
        ..setCategory('cat')
        ..setAccount('acc', Currency.tnd, 1);

      expect(state().rateMissing, isFalse);
      expect(state().canSave, isTrue);
    });

    test('a rate arriving late unblocks the entry', () async {
      controller()
        ..pressDigit('5')
        ..setCategory('cat')
        ..setAccount('acc-eur', Currency.eur, null);
      expect(state().canSave, isFalse);

      // What the rates stream does once it emits.
      controller().setRate(3.4);

      expect(state().canSave, isTrue);
      expect((await controller().save()).isOk, isTrue);
      expect(repository.added.single.fxRateToBase, 3.4);
    });

    test('an edited transaction keeps its frozen rate', () {
      controller().loadForEdit(
        Txn(
          id: 't1',
          type: TxnType.expense,
          amount: const Money(10000, Currency.eur),
          fxRateToBase: 3.2,
          categoryId: 'cat',
          accountId: 'acc-eur',
          transferAccountId: null,
          date: DateTime(2026, 8, 26),
          note: null,
          tags: const <String>[],
          recurringRuleId: null,
          createdAt: DateTime(2026, 8, 26),
          updatedAt: DateTime(2026, 8, 26),
        ),
      );

      // A later rate change must not rewrite what the row was written at.
      controller().setRate(9.9);

      expect(state().fxRateToBase, 3.2);
    });
  });
}
