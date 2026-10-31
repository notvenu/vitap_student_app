import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/models/academic_calendar.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/capstone_attendance.dart';
import 'package:vit_ap_student_app/core/models/exam_schedule.dart';
import 'package:vit_ap_student_app/core/models/mark.dart';
import 'package:vit_ap_student_app/core/models/profile.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/academic_calendar/viewmodel/cached_calendar_provider.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_projection_card.dart';
import 'package:vit_ap_student_app/features/timetable/utils/dated_classes.dart';

import '../../helpers/schedule_fixtures.dart';

class _StubUser extends CurrentUserNotifier {
  _StubUser(this.user);
  final User user;
  @override
  User? build() => user;
}

Future<void> pumpCard(
  WidgetTester tester, {
  required Attendance course,
  AcademicCalendar? calendar,
}) async {
  final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
  final user = User(
    profile: ToOne<Profile>(),
    attendance: ToMany<Attendance>(),
    // One class tomorrow, whatever day that is.
    timetable: ToOne<Timetable>(
      target: timetableOf({
        weekdayName(tomorrow): [slot('CSE1001', 'A1', '09:00')],
      }),
    ),
    examSchedule: ToMany<ExamSchedule>(),
    marks: ToMany<Mark>(),
    capstoneAttendance: ToOne<CapstoneAttendance>(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(() => _StubUser(user)),
        cachedCalendarProvider.overrideWith((ref) async => calendar),
      ],
      child: MaterialApp(
        home: Scaffold(body: AttendanceProjectionCard(course: course)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));

  testWidgets('without a calendar, offers to load it', (tester) async {
    await pumpCard(
      tester,
      course: attendanceRow(
        courseCode: 'CSE1001',
        slot: 'A1',
        attended: 9,
        total: 10,
      ),
    );
    expect(find.text('Load academic calendar'), findsOneWidget);
  });

  testWidgets('says plainly when 75% is out of reach', (tester) async {
    await pumpCard(
      tester,
      course: attendanceRow(
        courseCode: 'CSE1001',
        slot: 'A1',
        attended: 5,
        total: 20,
      ),
      calendar: calendarOf({
        isoDate(tomorrow): [working],
      }),
    );
    expect(find.text("75% can't be reached"), findsOneWidget);
    expect(find.textContaining('1 class left'), findsOneWidget);
    // The caveat travels with the number.
    expect(find.textContaining('VTOP has recorded so far'), findsOneWidget);
  });

  testWidgets('counts what can be missed', (tester) async {
    await pumpCard(
      tester,
      course: attendanceRow(
        courseCode: 'CSE1001',
        slot: 'A1',
        attended: 30,
        total: 30,
      ),
      calendar: calendarOf({
        isoDate(tomorrow): [working],
      }),
    );
    expect(find.text('Can miss 1'), findsOneWidget);
  });
}
