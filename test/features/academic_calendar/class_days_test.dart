import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/academic_calendar/model/calendar_day_summary.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';

import '../../helpers/schedule_fixtures.dart';

void main() {
  group('noClassDays', () {
    test('holidays, no-instruction and exam days, with their reason', () {
      final days = noClassDays(
        calendarOf({
          '2026-11-02': [working],
          '2026-11-08': [holiday('Diwali')],
          '2026-11-09': [noInstruction],
          '2026-11-10': [exam],
        }),
      );
      expect(days.keys, ['2026-11-08', '2026-11-09', '2026-11-10']);
      expect(days['2026-11-08'], (
        kind: CalendarDayKind.holiday,
        reason: 'Diwali',
      ));
      expect(days['2026-11-10']!.reason, 'CAT - I');
    });

    // A holiday sharing its cell with a working-day entry must still read as
    // a holiday, named for the holiday rather than the working day.
    test('a holiday beside a working-day entry is still a holiday', () {
      final days = noClassDays(
        calendarOf({
          '2026-11-08': [working, holiday('Diwali')],
        }),
      );
      expect(days['2026-11-08']!.reason, 'Diwali');
    });

    test('no calendar means no known no-class days', () {
      expect(noClassDays(null), isEmpty);
    });
  });

  group('lastInstructionalDay', () {
    // The calendar runs on through the exam weeks; classes end before them.
    test('is the last working day, not the last day listed', () {
      final calendar = calendarOf({
        '2026-11-20': [working],
        '2026-11-21': [working],
        '2026-11-25': [exam],
      });
      expect(lastInstructionalDay(calendar), DateTime(2026, 11, 21));
    });

    test('is null with no calendar or no working days', () {
      expect(lastInstructionalDay(null), isNull);
      expect(
        lastInstructionalDay(
          calendarOf({
            '2026-11-08': [holiday('Diwali')],
          }),
        ),
        isNull,
      );
    });
  });

  group('weekOf', () {
    test('runs Sunday to Saturday, like the day tabs', () {
      final week = weekOf(DateTime(2026, 11, 4));
      expect(week.first, DateTime(2026, 11, 1));
      expect(week.last, DateTime(2026, 11, 7));
      expect(weekOf(DateTime(2026, 11, 1)).first, DateTime(2026, 11, 1));
      expect(weekOf(DateTime(2026, 11, 7)).first, DateTime(2026, 11, 1));
    });

    test('steps whole weeks across month ends', () {
      expect(
        weekOf(DateTime(2026, 11, 4), weekOffset: -1).first,
        DateTime(2026, 10, 25),
      );
      expect(
        weekOf(DateTime(2026, 11, 4), weekOffset: 5).last,
        DateTime(2026, 12, 12),
      );
    });
  });

  test('isoDate pads to the format the calendar uses', () {
    expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
