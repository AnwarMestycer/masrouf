import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/theme/app_colors.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/analytics/cashflow_calendar.dart';
import 'package:masrouf/presentation/add/widgets/add_widgets.dart';
import 'package:masrouf/presentation/common/feedback.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/dashboard/widgets/dashboard_widgets.dart';
import 'package:masrouf/presentation/providers/analytics_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

/// The shape of a month before it happens.
///
/// Deliberately forward-looking and deliberately separate from the analytics
/// tab, which is entirely about what already occurred. Nothing on this screen
/// has touched a balance.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// Its own month cursor rather than `selectedMonthProvider`, which refuses to
  /// move past the current month — the exact opposite of what a calendar of
  /// things that have not happened yet needs.
  late Ym _ym = Ym.current();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(localeCodeProvider);
    final async = ref.watch(calendarProvider(_ym));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: Column(
        children: <Widget>[
          MonthStepper(
            label: DateFormat.yMMMM(locale).format(_ym.firstDay),
            onPrevious: () => setState(() => _ym = _ym.previous),
            onNext: () => setState(() => _ym = _ym.next),
            // Forward is the point here.
            canGoNext: true,
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ValueUnavailable(
                onRetry: () => ref.invalidate(calendarProvider(_ym)),
              ),
              data: (calendar) => calendar.isEmpty
                  ? EmptyHint(
                      icon: Icons.calendar_month_outlined,
                      title: l10n.calendarEmpty,
                      subtitle: l10n.plannedEmptyHint,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.lg,
                            vertical: Gap.sm,
                          ),
                          child: Text(
                            l10n.calendarDayTotal(
                              formatter.format(calendar.total),
                            ),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        _Grid(
                          ym: _ym,
                          calendar: calendar,
                          locale: locale,
                          onSelect: (day) => _showDay(day, calendar),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDay(int day, CashflowCalendar calendar) {
    final entries = calendar.byDay[day];
    if (entries == null || entries.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = context.l10n;
        final formatter = ref.read(moneyFormatterProvider);
        final locale = ref.read(localeCodeProvider);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Gap.lg),
            children: <Widget>[
              ListTile(
                title: Text(
                  DateFormat.yMMMMEEEEd(locale)
                      .format(DateTime(_ym.year, _ym.month, day)),
                ),
                subtitle: Text(
                  l10n.calendarDayTotal(
                    formatter.format(calendar.totalFor(day)),
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final entry in entries)
                ListTile(
                  leading: Icon(
                    entry.source == CalendarSource.recurring
                        ? Icons.repeat
                        : Icons.event_outlined,
                    size: 20,
                  ),
                  title: Text(entry.label.isEmpty ? l10n.txnAll : entry.label),
                  subtitle: Text(
                    entry.source == CalendarSource.recurring
                        ? l10n.recurringTitle
                        : l10n.plannedTitle,
                  ),
                  trailing: Text(formatter.format(entry.amount)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A month grid, one cell per day.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.ym,
    required this.calendar,
    required this.locale,
    required this.onSelect,
  });

  final Ym ym;
  final CashflowCalendar calendar;
  final String locale;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Monday-first, matching the week bucketing the cash-flow chart already
    // uses, so the two never disagree about where a week starts.
    final leading = (ym.firstDay.weekday - DateTime.monday) % 7;
    final cells = leading + ym.dayCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(locale)
                          .format(DateTime(2024, 1, 1).add(Duration(days: i))),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: Gap.xs,
              crossAxisSpacing: Gap.xs,
            ),
            itemCount: cells,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              return _DayCell(
                day: day,
                total: calendar.totalFor(day),
                hasEntries: calendar.byDay.containsKey(day),
                onTap: () => onSelect(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.total,
    required this.hasEntries,
    required this.onTap,
  });

  final int day;
  final Money total;
  final bool hasEntries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: hasEntries ? onTap : null,
      borderRadius: BorderRadius.circular(Gap.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color: hasEntries
              ? theme.money.negativeSurface
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Gap.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('$day', style: theme.textTheme.bodySmall),
            // A dot rather than the amount: seven columns cannot hold a
            // three-decimal dinar figure, and a truncated number is worse than
            // no number. The amount is one tap away.
            if (hasEntries)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: theme.money.expense,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
