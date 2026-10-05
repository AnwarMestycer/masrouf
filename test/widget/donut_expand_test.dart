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
import 'package:masrouf/presentation/analytics/widgets/category_donut.dart';

/// The ring is capped at six named arcs because a categorical palette is only
/// separable for a handful of hues. That cap is about colour, not about the list
/// underneath — which is where someone looks precisely when they want the detail
/// the ring folded away.
///
/// Driven directly rather than through the Analytics tab: the page is a lazy
/// list taller than the test viewport, so rows below the fold are never built
/// and a tap on one lands on nothing.
void main() {
  const base = Currency.tnd;

  const names = <String>[
    'Rent', 'Groceries', 'Transport', 'Coffee', 'Health', 'Internet',
    'Shopping', 'Education', 'Water', 'Gym',
  ];

  Category category(String id, String name) => Category(
        id: id,
        name: name,
        kind: CategoryKind.expense,
        icon: 'groceries',
        color: 0xFF2A78D6,
        sortOrder: 0,
        isDefault: false,
        updatedAt: DateTime(2026, 10, 1),
      );

  /// Ten categories with descending spend, so six land in the ring and four in
  /// the tail, plus one that was never spent against.
  List<CategorySlice> slices({bool withEmpty = true}) {
    final totals = <int>[
      for (var i = 0; i < names.length; i++) (names.length - i) * 10000,
    ];
    final grand = totals.reduce((a, b) => a + b);
    return <CategorySlice>[
      for (var i = 0; i < names.length; i++)
        CategorySlice(
          category: category('cat-$i', names[i]),
          total: Money(totals[i], base),
          txnCount: 1,
          share: totals[i] / grand,
          previousTotal: const Money.zero(base),
        ),
      if (withEmpty)
        CategorySlice(
          category: category('cat-unused', 'Zakat'),
          total: const Money.zero(base),
          txnCount: 0,
          share: 0,
          previousTotal: const Money.zero(base),
        ),
    ];
  }

  Future<void> pumpDonut(WidgetTester tester) async {
    // Tall enough that every row is laid out, so a miss is a real failure
    // rather than the viewport.
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final l10n = await L10n.delegate.load(const Locale('en'));
    final total = slices()
        .map((s) => s.total)
        .reduce((a, b) => a + b);

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
            child: CategoryDonut(
              slices: slices(),
              total: total,
              formatter: MoneyFormatter('en'),
              l10n: l10n,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the tail is folded into one row until it is asked for',
      (tester) async {
    await pumpDonut(tester);

    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Internet'), findsOneWidget, reason: 'sixth, still ringed');
    expect(find.text('Shopping'), findsNothing, reason: 'seventh, in the tail');
    expect(find.text('Gym'), findsNothing);
    expect(find.textContaining('(+4)'), findsOneWidget);
  });

  testWidgets('tapping the folded row lists every category in it',
      (tester) async {
    await pumpDonut(tester);

    await tester.tap(find.textContaining('(+4)'));
    await tester.pumpAndSettle();

    for (final name in names) {
      expect(find.text(name), findsOneWidget, reason: '$name should be listed');
    }
    expect(
      find.textContaining('(+4)'),
      findsNothing,
      reason: 'the aggregate is replaced by what it stood for',
    );
  });

  testWidgets('the expanded list can be collapsed again', (tester) async {
    await pumpDonut(tester);

    await tester.tap(find.textContaining('(+4)'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.text('Gym'), findsNothing);
    expect(find.textContaining('(+4)'), findsOneWidget);
  });

  /// Asked for specifically: a category with nothing spent against it says
  /// nothing about composition, rounds to 0%, and draws an arc of no width.
  testWidgets('a category with nothing spent never appears', (tester) async {
    await pumpDonut(tester);
    expect(find.text('Zakat'), findsNothing);

    await tester.tap(find.textContaining('(+4)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Zakat'),
      findsNothing,
      reason: 'expanding reveals the tail, not every category that exists',
    );
  });

  /// Tail rows have no arc of their own and carry the aggregate's index, which
  /// is an easy way to index past the end of the ring. Focusing one is also the
  /// only way to read its figure in the centre, since the arc it lives in is
  /// shared with the rest of the tail.
  testWidgets('a revealed tail row can be focused and reads out', (tester) async {
    await pumpDonut(tester);

    await tester.tap(find.textContaining('(+4)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Once in the list, once in the centre of the ring.
    expect(
      find.text('Gym'),
      findsNWidgets(2),
      reason: 'the focused tail row drives the centre readout',
    );
  });
}
