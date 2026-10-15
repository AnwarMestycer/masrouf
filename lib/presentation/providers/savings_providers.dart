import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/repositories/savings_repository_impl.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/repositories/repositories.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>(
  (ref) => SavingsRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    sync: ref.watch(syncEngineProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
    plan: ref.watch(settingsProvider.select((s) => s.savings)),
  ),
);

final savingsStatusProvider = StreamProvider<SavingsStatus>(
  (ref) => ref.watch(savingsRepositoryProvider).watchStatus(),
);

final confirmedPeriodsProvider = StreamProvider<List<SavingsPeriod>>(
  (ref) => ref.watch(savingsRepositoryProvider).watchConfirmed(),
);

/// What safe-to-spend must hold back for the open period.
///
/// Resolved to zero while the status is still loading rather than exposing an
/// `AsyncValue`: a safe-to-spend figure that flickers upward for one frame is
/// an invitation to spend money that is already promised.
final savingsReservedProvider = Provider<Money>((ref) {
  final base = ref.watch(baseCurrencyProvider);
  return ref.watch(savingsStatusProvider).value?.reserved ?? Money.zero(base);
});
