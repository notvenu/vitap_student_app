import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
import 'package:vit_ap_student_app/core/services/analytics_service.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/academic_calendar/viewmodel/cached_calendar_provider.dart';
import 'package:vit_ap_student_app/features/timetable/view/pages/timetable_page.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

import '../../helpers/schedule_fixtures.dart';

class _StubUser extends CurrentUserNotifier {
  _StubUser(this.user);
  final User user;
  @override
  User? build() => user;
}

class _IdleTimetable extends TimetableViewModel {
  @override
  AsyncValue<Timetable>? build() => null;
}

User userWith(Timetable timetable) => User(
  profile: ToOne<Profile>(),
  attendance: ToMany<Attendance>(),
  timetable: ToOne<Timetable>(target: timetable),
  examSchedule: ToMany<ExamSchedule>(),
  marks: ToMany<Mark>(),
  capstoneAttendance: ToOne<CapstoneAttendance>(),
);

Future<void> pumpPage(WidgetTester tester, {AcademicCalendar? calendar}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(
          const NoopAnalyticsService(),
        ),
        currentUserProvider.overrideWith(
          () => _StubUser(userWith(timetableOf({}))),
        ),
        timetableViewModelProvider.overrideWith(_IdleTimetable.new),
        cachedCalendarProvider.overrideWith((ref) async => calendar),
      ],
      child: const MaterialApp(home: TimetablePage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  final DateTime today = DateTime.now();
  final List<DateTime> week = weekOf(today);

  testWidgets('each day tab shows its date for this week', (tester) async {
    await pumpPage(tester, calendar: calendarOf({}));
    for (final DateTime day in week) {
      expect(find.text('${day.day}'), findsWidgets);
    }
  });

  testWidgets("today's holiday replaces the class count and the list", (
    tester,
  ) async {
    await pumpPage(
      tester,
      calendar: calendarOf({
        isoDate(today): [holiday('Diwali')],
      }),
    );
    expect(find.text('No classes today · Diwali'), findsOneWidget);
    expect(find.text('Diwali'), findsOneWidget);
    expect(find.text('No classes, per the academic calendar'), findsOneWidget);
  });

  testWidgets('the arrows move a week at a time, and Today comes back', (
    tester,
  ) async {
    await pumpPage(tester, calendar: calendarOf({}));
    expect(find.text('Today'), findsNothing);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pump(const Duration(milliseconds: 500));
    final DateTime nextSunday = weekOf(today, weekOffset: 1).first;
    expect(
      find.textContaining(
        DateFormat('d MMM').format(nextSunday.add(const Duration(days: 6))),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Today'), findsNothing);
  });

  // Fetching the calendar is a request per month and can demand an OTP, so
  // the page points at it rather than fetching it.
  testWidgets('without a calendar, it offers to load one', (tester) async {
    await pumpPage(tester);
    expect(
      find.text('Load the academic calendar to see holidays'),
      findsOneWidget,
    );
  });

  testWidgets('with a calendar, the hint is gone', (tester) async {
    await pumpPage(tester, calendar: calendarOf({}));
    expect(
      find.text('Load the academic calendar to see holidays'),
      findsNothing,
    );
  });
}
