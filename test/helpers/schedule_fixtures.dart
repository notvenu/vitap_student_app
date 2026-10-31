/// Builders for timetables, calendars and attendance rows, so tests can state
/// a schedule in a line each rather than in VTOP's JSON.
library;

import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/models/academic_calendar.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';

Day slot(
  String courseCode,
  String slot,
  String start, {
  String? courseName = 'Course',
  String venue = 'AB1-101',
}) => Day(
  startTime: start,
  endTime: '',
  courseName: courseName,
  slot: slot,
  venue: venue,
  faculty: '',
  courseCode: courseCode,
  courseType: '',
);

/// A timetable from day name to that day's entries; unnamed days are empty.
Timetable timetableOf(Map<String, List<Day>> days) {
  ToMany<Day> on(String name) => ToMany<Day>(items: [...?days[name]]);
  return Timetable(
    monday: on('Monday'),
    tuesday: on('Tuesday'),
    wednesday: on('Wednesday'),
    thursday: on('Thursday'),
    friday: on('Friday'),
    saturday: on('Saturday'),
    sunday: on('Sunday'),
  );
}

const String working = 'Instructional Day - General (Semester)|WorkingDay';
const String exam = 'CAT - I - General (Semester)|Exam Days';
const String noInstruction =
    'No Instructional Day - General (Semester)|No Instructional Day';
String holiday(String name) => 'Holiday - General (Semester)|$name';

/// A calendar from ISO date to its entries, each written `description|label`.
AcademicCalendar calendarOf(Map<String, List<String>> days) => AcademicCalendar(
  semesterId: 'AP2026274',
  classGroupId: 'COMB',
  months: ToMany<CalendarMonthRef>(items: []),
  days: ToMany<CalendarDay>(
    items: [
      for (final MapEntry<String, List<String>> d in days.entries)
        CalendarDay(
          date: d.key,
          day: int.parse(d.key.substring(8)),
          weekday: '',
          events: ToMany<CalendarEvent>(
            items: [
              for (final String e in d.value)
                CalendarEvent(
                  description: e.split('|')[0],
                  label: e.split('|')[1],
                ),
            ],
          ),
        ),
    ],
  ),
);

Attendance attendanceRow({
  required String courseCode,
  required String slot,
  required int attended,
  required int total,
}) => Attendance(
  classNumber: '1',
  faculty: '',
  courseId: 'c1',
  courseCode: courseCode,
  courseName: 'Course',
  courseType: '',
  courseTypeCode: '',
  courseSlot: slot,
  attendedClasses: '$attended',
  totalClasses: '$total',
  attendancePercentage: '',
  betweenAttendancePercentage: '',
  debarStatus: '',
);
