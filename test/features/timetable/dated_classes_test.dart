import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/timetable/utils/dated_classes.dart';

import '../../helpers/schedule_fixtures.dart';

void main() {
  final timetable = timetableOf({
    'Monday': [slot('CSE1001', 'A1', '09:00', courseName: 'Problem Solving')],
    'Tuesday': [slot('CSE1001', 'L31+L32', '14:00', courseName: 'PS Lab')],
  });
  final diwali = noClassDays(
    calendarOf({
      '2026-11-09': [holiday('Diwali')],
    }),
  );

  test('weekdayName matches the timetable keys', () {
    expect(weekdayName(DateTime(2026, 11, 1)), 'Sunday');
    expect(weekdayName(DateTime(2026, 11, 2)), 'Monday');
  });

  test('classesOn follows the weekday, and is empty on a no-class day', () {
    expect(classesOn(timetable, DateTime(2026, 11, 2)), hasLength(1));
    expect(
      classesOn(timetable, DateTime(2026, 11, 9), noClass: diwali),
      isEmpty,
    );
  });

  group('planClassReminders', () {
    List<DateTime> fireTimes(DateTime now, {int days = 7}) =>
        planClassReminders(
          timetable: timetable,
          noClass: diwali,
          now: now,
          delayMinutes: 10,
          days: days,
        ).map((r) => r.fireAt).toList();

    test('one reminder per class in the coming week, delay ahead', () {
      expect(fireTimes(DateTime(2026, 11, 1, 8)), [
        DateTime(2026, 11, 2, 8, 50),
        DateTime(2026, 11, 3, 13, 50),
      ]);
    });

    // Reminders used to repeat weekly, so they fired on every holiday. The
    // Monday after this one is Diwali and must stay quiet.
    test('skips holidays', () {
      expect(fireTimes(DateTime(2026, 11, 8, 8)), [
        DateTime(2026, 11, 10, 13, 50),
      ]);
    });

    test('leaves out a reminder whose moment has passed', () {
      expect(fireTimes(DateTime(2026, 11, 2, 8, 55)), [
        DateTime(2026, 11, 3, 13, 50),
      ]);
    });

    test('a 14-day window reaches the week after', () {
      expect(fireTimes(DateTime(2026, 11, 1, 8), days: 14), hasLength(3));
    });

    test('skips empty cells and unreadable times', () {
      final planned = planClassReminders(
        timetable: timetableOf({
          'Monday': [
            slot('CSE1001', 'A1', '-'),
            slot('CSE1002', 'B1', '10:00', courseName: null),
          ],
        }),
        noClass: const {},
        now: DateTime(2026, 11, 1),
        delayMinutes: 10,
      );
      expect(planned, isEmpty);
    });

    // Rescheduling must replace a reminder, not add a twin beside it.
    test('ids are stable and distinct', () {
      List<int> ids() => planClassReminders(
        timetable: timetable,
        noClass: const {},
        now: DateTime(2026, 11, 1),
        delayMinutes: 10,
        days: 14,
      ).map((r) => r.id).toList();
      expect(ids(), ids());
      expect(ids().toSet(), hasLength(4));
    });
  });
}
