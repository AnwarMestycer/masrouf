import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';

void main() {
  group('Ym', () {
    test('encodes as yyyyMM', () {
      expect(Ym.fromDate(DateTime(2026, 8, 26)).value, 202608);
    });

    test('rolls across the year boundary in both directions', () {
      expect(const Ym(202601).previous.value, 202512);
      expect(const Ym(202612).next.value, 202701);
    });

    test('finds the last day of a month without a length table', () {
      expect(const Ym(202602).lastDay.day, 28);
      expect(const Ym(202402).lastDay.day, 29); // leap year
      expect(const Ym(202612).lastDay.day, 31);
    });

    test('lastMonths returns oldest first', () {
      final months = const Ym(202603).lastMonths(4);
      expect(
        months.map((m) => m.value).toList(),
        <int>[202512, 202601, 202602, 202603],
      );
    });
  });

  group('DateOnlyX', () {
    test('ymd encodes as yyyyMMdd and sorts chronologically', () {
      expect(DateTime(2026, 8, 26).ymd, 20260826);
      expect(DateTime(2026, 8, 26).ymd < DateTime(2026, 9, 1).ymd, isTrue);
    });

    test('startOfWeek anchors on Monday', () {
      // 2026-08-26 is a Wednesday.
      expect(DateTime(2026, 8, 26).startOfWeek, DateTime(2026, 8, 24));
    });

    test('addMonthsClamped never overflows into the next month', () {
      expect(DateTime(2026, 1, 31).addMonthsClamped(1), DateTime(2026, 2, 28));
      expect(DateTime(2026, 3, 31).addMonthsClamped(1), DateTime(2026, 4, 30));
    });

    test('addMonthsClamped crosses the year boundary', () {
      expect(DateTime(2026, 12, 15).addMonthsClamped(1), DateTime(2027, 1, 15));
    });

    test('toIsoDate zero-pads for the Postgres date wire format', () {
      expect(DateTime(2026, 8, 5).toIsoDate(), '2026-08-05');
    });
  });

  group('dayOfMonthIn', () {
    test('clamps a 31st rule onto a short month', () {
      expect(dayOfMonthIn(2026, 2, 31), DateTime(2026, 2, 28));
      expect(dayOfMonthIn(2026, 4, 31), DateTime(2026, 4, 30));
    });
  });
}
