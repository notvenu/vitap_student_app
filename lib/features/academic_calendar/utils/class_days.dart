/// Which dates have classes, read off the academic calendar.
///
/// The timetable is a weekly template with no dates in it, so on its own it
/// says there are classes on Diwali. The calendar knows better; this is where
/// the two meet, for the timetable page, class reminders and the attendance
/// projection alike.
library;

import 'package:vit_ap_student_app/core/models/academic_calendar.dart';
import 'package:vit_ap_student_app/features/academic_calendar/model/calendar_day_summary.dart';

/// A date the calendar says regular classes don't run, and why.
typedef NoClassDay = ({CalendarDayKind kind, String reason});

/// Kinds of day that cancel the regular timetable. Exam days are in because
/// classes are suspended for CAT and FAT; counting them would overstate how
/// many classes are left.
const Set<CalendarDayKind> _noClassKinds = {
  CalendarDayKind.holiday,
  CalendarDayKind.noInstruction,
  CalendarDayKind.exam,
};

/// `YYYY-MM-DD`, the format the calendar keys its days by.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Every no-class date in [calendar], keyed by [isoDate]. Empty when no
/// calendar has been loaded, so callers fall back to the plain timetable.
Map<String, NoClassDay> noClassDays(AcademicCalendar? calendar) {
  if (calendar == null) return const {};

  final Map<String, NoClassDay> result = {};
  for (final CalendarDay day in calendar.days) {
    final CalendarDayKind kind = calendarDayKind(day);
    if (!_noClassKinds.contains(kind)) continue;

    // The reason is the entry that made it a no-class day, not whatever
    // working-day entry it might share the cell with.
    final String reason = summariseCalendarDay(
      day,
    ).firstWhere((entry) => entry.kind == kind).headline;
    result[day.date] = (kind: kind, reason: reason);
  }
  return result;
}

/// The last day the calendar marks as instructional, or null when it has none.
///
/// This is where the semester's classes end: the attendance projection counts
/// up to it, and not to the end of the calendar, which runs on through exams.
DateTime? lastInstructionalDay(AcademicCalendar? calendar) {
  if (calendar == null) return null;

  String? last;
  for (final CalendarDay day in calendar.days) {
    final bool instructional = summariseCalendarDay(
      day,
    ).any((entry) => entry.kind == CalendarDayKind.working);
    if (instructional && (last == null || day.date.compareTo(last) > 0)) {
      last = day.date;
    }
  }
  return last == null ? null : DateTime.tryParse(last);
}

/// The Sunday-to-Saturday week containing [day], [weekOffset] weeks away.
///
/// Sunday first, matching the order of the timetable's day tabs.
List<DateTime> weekOf(DateTime day, {int weekOffset = 0}) {
  final DateTime sunday = DateTime(
    day.year,
    day.month,
    day.day - day.weekday % 7 + weekOffset * 7,
  );
  return [
    for (int i = 0; i < 7; i++)
      DateTime(sunday.year, sunday.month, sunday.day + i),
  ];
}
