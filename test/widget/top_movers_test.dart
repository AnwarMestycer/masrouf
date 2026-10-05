import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/money/money_formatter.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/analytics/widgets/top_movers.dart';

/// The ranked list answers "where does the money go". This answers "what
/// changed", which is the only thing a comparison is for.
void main() {
  const base = Currency.tnd;

  Category category(String name) => Category(
        id: 'cat-$name',
        name: name,
        kind: CategoryKind.expense,
        icon: 'groceries',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: false,
        updatedAt: DateTime(2026, 10),
      );

  CategorySlice slice(String name, int now, int before) => CategorySlice(
        category: category(name),
        total: Money(now, base),
        txnCount: 1,
        share: 0.5,
        previousTotal: Money(before, base),
      );

  Future<void> pump(WidgetTester tester, List<CategorySlice> slices) async {
    final l10n = await L10n.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: TopMovers(
              slices: slices,
              formatter: MoneyFormatter('en'),
              l10n: l10n,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ranked by the size of the swing in money, not in percent. A category that
  /// went from 2 to 6 tripled and means nothing beside one that rose by 300.
  testWidgets('the biggest swing in money comes first', (tester) async {
    await pump(tester, <CategorySlice>[
      slice('Coffee', 6000, 2000), // tripled, but only +4
      slice('Education', 322000, 0), // +322
      slice('Rent', 115000, 100000), // +15
    ]);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(
      names.indexOf('Education'),
      lessThan(names.indexOf('Rent')),
      reason: '+322 outranks +15',
    );
    expect(names.indexOf('Rent'), lessThan(names.indexOf('Coffee')));
  });

  /// Appearing from nothing, or stopping altogether, is the largest change
  /// there is — and the one most worth surfacing.
  testWidgets('a category that appeared or vanished still counts',
      (tester) async {
    await pump(tester, <CategorySlice>[
      slice('Education', 322000, 0),
      slice('Shopping', 0, 164000),
    ]);

    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
  });

  testWidgets('a category that did not move is left out', (tester) async {
    await pump(tester, <CategorySlice>[
      slice('Rent', 115000, 115000),
      slice('Coffee', 6000, 2000),
    ]);

    expect(find.text('Coffee'), findsOneWidget);
    expect(
      find.text('Rent'),
      findsNothing,
      reason: 'unchanged is not a change',
    );
  });

  testWidgets('nothing is rendered when nothing moved', (tester) async {
    await pump(tester, <CategorySlice>[slice('Rent', 115000, 115000)]);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('the list is capped', (tester) async {
    await pump(tester, <CategorySlice>[
      for (var i = 0; i < 12; i++) slice('cat$i', (i + 1) * 1000, 0),
    ]);

    expect(find.text('cat11'), findsOneWidget, reason: 'biggest swing');
    expect(find.text('cat0'), findsNothing, reason: 'smallest, past the cap');
  });
}
