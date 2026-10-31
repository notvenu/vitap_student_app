/// Attendance arithmetic: what it takes to stay at 75%, now and by the end of
/// the semester.
///
/// The projection only knows what VTOP has recorded. Faculty upload manual
/// attendance late, sometimes weeks late, so classes already held can be
/// missing from both counts. Every screen showing these numbers says so.
library;

import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/timetable/utils/dated_classes.dart';

/// [attended] out of [total] as a percentage, 0 when nothing has been held.
double attendancePercent(int attended, int total) =>
    total <= 0 ? 0 : attended * 100 / total;

/// Classes to attend in a row to get back to 75%. Zero when already there.
int classesNeededFor75(int attended, int total) {
  // (attended + n) / (total + n) >= 0.75  =>  n >= 3 * total - 4 * attended
  final int needed = 3 * total - 4 * attended;
  return needed > 0 ? needed : 0;
}

/// Classes that can be missed in a row while staying at 75%. Zero when
/// already below.
int classesSkippableAt75(int attended, int total) {
  // attended / (total + k) >= 0.75  =>  k <= (4 * attended - 3 * total) / 3
  final int skippable = (4 * attended - 3 * total) ~/ 3;
  return skippable > 0 ? skippable : 0;
}

/// How many classes a timetable entry counts as.
///
/// A two-period lab appears once in the timetable as `L31+L32` but is two
/// hours of attendance, so an entry counts once per slot in it.
int classesInEntry(String? slot) {
  final int slots = (slot ?? '')
      .split('+')
      .where((s) => s.trim().isNotEmpty)
      .length;
  return slots == 0 ? 1 : slots;
}

/// Whether a timetable entry is a class of [course].
///
/// Matched on course code and slot rather than course type, whose wording
/// differs between the two VTOP pages. The attendance row carries every slot
/// the course meets in (`A1+TA1`), and each timetable entry one of them.
bool isClassOf(Day entry, Attendance course) {
  if (entry.courseCode != course.courseCode) return false;
  final Set<String> courseSlots = _slots(course.courseSlot);
  final Set<String> entrySlots = _slots(entry.slot);
  return entrySlots.isNotEmpty && courseSlots.containsAll(entrySlots);
}

Set<String> _slots(String? slot) => (slot ?? '')
    .split('+')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toSet();

/// Where a course stands at the end of the semester.
typedef AttendanceProjection = ({
  /// Classes still to come, after holidays and exams.
  int remaining,

  /// How many of [remaining] can be missed while finishing at 75%.
  int canSkip,

  /// Percentage at the end if every remaining class is attended. Below 75
  /// means it can no longer be reached.
  double bestPossible,
});

/// Projects [course] to [lastDay], counting classes from the day after
/// [today].
///
/// Today is left out on purpose: whether today's class is in VTOP's count yet
/// isn't knowable, and leaving it out errs on the side of fewer classes to
/// skip.
AttendanceProjection projectAttendance({
  required Attendance course,
  required Timetable timetable,
  required Map<String, NoClassDay> noClass,
  required DateTime today,
  required DateTime lastDay,
}) {
  final int attended = int.tryParse(course.attendedClasses.trim()) ?? 0;
  final int total = int.tryParse(course.totalClasses.trim()) ?? 0;

  int remaining = 0;
  for (
    DateTime date = DateTime(today.year, today.month, today.day + 1);
    !date.isAfter(lastDay);
    date = DateTime(date.year, date.month, date.day + 1)
  ) {
    for (final Day entry in classesOn(timetable, date, noClass: noClass)) {
      if (isClassOf(entry, course)) remaining += classesInEntry(entry.slot);
    }
  }

  final int finalTotal = total + remaining;
  // ceil(0.75 * finalTotal), in integers so 0.75 * 40 can't land on 30.0000001.
  final int required = (3 * finalTotal + 3) ~/ 4;
  return (
    remaining: remaining,
    canSkip: (attended + remaining - required).clamp(0, remaining),
    bestPossible: attendancePercent(attended + remaining, finalTotal),
  );
}
