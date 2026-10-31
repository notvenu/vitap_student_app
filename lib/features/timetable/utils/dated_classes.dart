/// The weekly timetable laid onto real dates.
library;

import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/utils/get_classes.dart';
import 'package:vit_ap_student_app/core/utils/parse_class_time.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The timetable's day name for [date], e.g. `Monday`.
String weekdayName(DateTime date) => _weekdayNames[date.weekday - 1];

/// The classes scheduled on [date], or none when [noClass] has it as a
/// holiday, exam or other no-class day.
List<Day> classesOn(
  Timetable timetable,
  DateTime date, {
  Map<String, NoClassDay> noClass = const {},
}) {
  if (noClass.containsKey(isoDate(date))) return const [];
  return getClassesForDay(timetable, weekdayName(date));
}

/// One class reminder to schedule.
typedef PlannedClassReminder = ({
  int id,
  DateTime fireAt,
  String courseName,
  String venue,
});

/// Reminders for every class in the [days] starting today, skipping no-class
/// days and anything already past.
///
/// These used to be weekly repeating alarms. A repeating alarm can't skip one
/// week, so every holiday got its full set of "class starting soon" pings.
/// Dated one-offs over a short window can skip them; the window is topped up
/// each time the app opens.
///
/// All times are wall-clock times in the timetable's own zone (IST).
List<PlannedClassReminder> planClassReminders({
  required Timetable timetable,
  required Map<String, NoClassDay> noClass,
  required DateTime now,
  required int delayMinutes,
  int days = 7,
}) {
  final List<PlannedClassReminder> planned = [];
  for (int offset = 0; offset < days; offset++) {
    final DateTime date = DateTime(now.year, now.month, now.day + offset);
    for (final Day slot in classesOn(timetable, date, noClass: noClass)) {
      if (slot.courseName == null) continue;
      final DateTime? startsAt = parseClassTime(slot.startTime, onDate: date);
      if (startsAt == null) continue;

      final DateTime fireAt = startsAt.subtract(
        Duration(minutes: delayMinutes),
      );
      if (!fireAt.isAfter(now)) continue;

      planned.add((
        // Masked to 31 bits: Android rejects ids outside a signed int.
        id:
            'class_${isoDate(date)}_${slot.startTime}_${slot.courseCode}_${slot.slot}'
                .hashCode &
            0x7FFFFFFF,
        fireAt: fireAt,
        courseName: slot.courseName!,
        venue: slot.venue ?? '',
      ));
    }
  }
  planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return planned;
}
