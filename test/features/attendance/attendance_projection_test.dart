import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/attendance/utils/attendance_projection.dart';

import '../../helpers/schedule_fixtures.dart';

void main() {
  group('the 75% arithmetic', () {
    test('classes needed to get back to 75%', () {
      expect(classesNeededFor75(20, 30), 10); // 30 / 40
      expect(classesNeededFor75(29, 40), 4); // 33 / 44
      expect(classesNeededFor75(30, 40), 0);
      expect(classesNeededFor75(0, 0), 0);
    });

    test('classes that can be missed while staying at 75%', () {
      expect(classesSkippableAt75(28, 30), 7); // 28 / 37 = 75.7%
      expect(classesSkippableAt75(30, 40), 0);
      expect(classesSkippableAt75(20, 30), 0);
    });

    test('percent is 0 before any class is held', () {
      expect(attendancePercent(0, 0), 0);
      expect(attendancePercent(3, 4), 75);
    });
  });

  test('a two-period lab counts as two classes', () {
    expect(classesInEntry('L31+L32'), 2);
    expect(classesInEntry('A1'), 1);
    expect(classesInEntry(''), 1);
    expect(classesInEntry(null), 1);
  });

  test('timetable entries match a course by code and slot', () {
    final theory = attendanceRow(
      courseCode: 'CSE1001',
      slot: 'A1+TA1',
      attended: 0,
      total: 0,
    );
    expect(isClassOf(slot('CSE1001', 'A1', '09:00'), theory), isTrue);
    expect(isClassOf(slot('CSE1001', 'TA1', '12:00'), theory), isTrue);
    // Same course, but its lab: a different attendance row.
    expect(isClassOf(slot('CSE1001', 'L31+L32', '14:00'), theory), isFalse);
    expect(isClassOf(slot('CSE1002', 'A1', '09:00'), theory), isFalse);
  });

  group('projectAttendance', () {
    // Theory every Monday and Wednesday. 2 Nov 2026 is a Monday.
    final timetable = timetableOf({
      'Monday': [slot('CSE1001', 'A1', '09:00')],
      'Wednesday': [slot('CSE1001', 'A1', '09:00')],
      'Tuesday': [slot('CSE1001', 'L31+L32', '14:00')],
    });
    final theory = attendanceRow(
      courseCode: 'CSE1001',
      slot: 'A1',
      attended: 18,
      total: 22,
    );

    test('counts remaining classes after holidays and exams', () {
      final projection = projectAttendance(
        course: theory,
        timetable: timetable,
        // Mon 9th a holiday, Wed 11th an exam: only 16 and 18 Nov remain,
        // and the Tuesday labs are another course.
        noClass: noClassDays(
          calendarOf({
            '2026-11-09': [holiday('Diwali')],
            '2026-11-11': [exam],
          }),
        ),
        today: DateTime(2026, 11, 6),
        lastDay: DateTime(2026, 11, 18),
      );
      expect(projection.remaining, 2);
      // 24 held in the end needs 18; 20 is the most possible, so 2 can go.
      expect(projection.canSkip, 2);
    });

    // Whether today's class is in VTOP's count yet isn't knowable, so it's
    // left out: the cautious side, fewer to skip.
    test('starts counting tomorrow', () {
      final projection = projectAttendance(
        course: theory,
        timetable: timetable,
        noClass: const {},
        today: DateTime(2026, 11, 2),
        lastDay: DateTime(2026, 11, 4),
      );
      expect(projection.remaining, 1);
    });

    test('a lab session counts twice', () {
      final lab = attendanceRow(
        courseCode: 'CSE1001',
        slot: 'L31+L32',
        attended: 10,
        total: 10,
      );
      final projection = projectAttendance(
        course: lab,
        timetable: timetable,
        noClass: const {},
        today: DateTime(2026, 11, 1),
        lastDay: DateTime(2026, 11, 14),
      );
      expect(projection.remaining, 4);
    });

    test("says so when 75% can't be reached any more", () {
      final projection = projectAttendance(
        course: attendanceRow(
          courseCode: 'CSE1001',
          slot: 'A1',
          attended: 5,
          total: 20,
        ),
        timetable: timetable,
        noClass: const {},
        today: DateTime(2026, 11, 1),
        lastDay: DateTime(2026, 11, 4),
      );
      expect(projection.remaining, 2);
      expect(projection.canSkip, 0);
      expect(projection.bestPossible, closeTo(31.8, 0.1));
    });

    test('nothing left after the last instructional day', () {
      final projection = projectAttendance(
        course: theory,
        timetable: timetable,
        noClass: const {},
        today: DateTime(2026, 11, 20),
        lastDay: DateTime(2026, 11, 18),
      );
      expect(projection.remaining, 0);
      expect(projection.canSkip, 0);
    });
  });
}
