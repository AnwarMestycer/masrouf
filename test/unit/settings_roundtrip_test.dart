import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/row_writer.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/data/repositories/settings_repository_impl.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_database.dart';

/// The settings row is written with `insertOrReplace`, so every column has to
/// be named on every write. An omitted one is not left alone — it is reset to
/// its default.
///
/// That is how the savings plan silently went back to zero every time the
/// language or the theme was changed, and again on the next pull. Nothing
/// failed; a number the user had set simply stopped being there.
void main() {
  late AppDatabase db;
  const userId = 'u1';
  const base = Currency.tnd;

  const plan = SavingsPlan(
    rate: 0.30,
    floor: Money(50000, base),
    ceiling: Money(400000, base),
    recoveryPeriods: 3,
  );

  SettingsRepositoryImpl repo() => SettingsRepositoryImpl(
        db: db,
        sync: testSyncEngine(db),
        userId: userId,
      );

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('the savings plan survives a local save', () async {
    final settings = UserSettings.fallback.copyWith(savings: plan);
    await repo().save(settings);

    final stored = await repo().read();
    expect(stored.savings.rate, 0.30);
    expect(stored.savings.floor, const Money(50000, base));
    expect(stored.savings.ceiling, const Money(400000, base));
    expect(stored.savings.recoveryPeriods, 3);
  });

  /// The exact sequence that lost it: set a plan, then change something else.
  test('changing an unrelated setting does not wipe the plan', () async {
    await repo().save(UserSettings.fallback.copyWith(savings: plan));

    final afterPlan = await repo().read();
    await repo().save(afterPlan.copyWith(locale: 'ar', paydayDayOfMonth: 26));

    final stored = await repo().read();
    expect(stored.locale, 'ar');
    expect(stored.paydayDayOfMonth, 26);
    expect(
      stored.savings.rate,
      0.30,
      reason: 'changing the language must not reset the savings plan',
    );
    expect(stored.savings.recoveryPeriods, 3);
  });

  test('the plan survives a pull that rewrites the row', () async {
    await repo().save(UserSettings.fallback.copyWith(savings: plan));

    // What the server would send back for this user.
    final wire = settingsToJson(
      userId,
      UserSettings.fallback.copyWith(locale: 'fr', savings: plan),
    );
    await applyRemoteRows(db, userId, SyncEntity.userSettings, <Json>[wire]);

    final stored = await repo().read();
    expect(stored.savings.rate, 0.30);
    expect(stored.savings.floor, const Money(50000, base));
    expect(stored.savings.recoveryPeriods, 3);
  });

  /// A server that has not run the savings migration sends no such fields.
  /// That has to read as "no plan" rather than failing the whole pull.
  test('a row without savings fields reads as no plan', () async {
    final wire = settingsToJson(userId, UserSettings.fallback)
      ..remove('savings_rate')
      ..remove('savings_floor')
      ..remove('savings_ceiling')
      ..remove('savings_recovery_periods');

    await applyRemoteRows(db, userId, SyncEntity.userSettings, <Json>[wire]);

    final stored = await repo().read();
    expect(stored.savings.rate, 0);
    expect(stored.savings.recoveryPeriods, 1);
  });

  test('the plan round-trips through the wire format', () {
    final wire =
        settingsToJson(userId, UserSettings.fallback.copyWith(savings: plan));
    final back = settingsFromJson(wire);

    expect(back.savings.rate, 0.30);
    expect(back.savings.floor, const Money(50000, base));
    expect(back.savings.ceiling, const Money(400000, base));
    expect(back.savings.recoveryPeriods, 3);
  });
}
