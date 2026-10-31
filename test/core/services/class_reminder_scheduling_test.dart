import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/capstone_attendance.dart';
import 'package:vit_ap_student_app/core/models/exam_schedule.dart';
import 'package:vit_ap_student_app/core/models/mark.dart';
import 'package:vit_ap_student_app/core/models/profile.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/models/user_preferences.dart';
import 'package:vit_ap_student_app/core/services/notification_service.dart';

import '../../helpers/schedule_fixtures.dart';

/// Stands in for the OS, holding what has been scheduled.
class _FakeNotifications {
  final Map<int, Map<String, Object?>> pending = {};

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'zonedSchedule':
        final args = Map<String, Object?>.from(call.arguments as Map);
        pending[args['id']! as int] = args;
      case 'cancel':
        pending.remove((call.arguments as Map)['id']);
      case 'pendingNotificationRequests':
        return [
          for (final p in pending.values)
            {
              'id': p['id'],
              'title': p['title'],
              'body': p['body'],
              'payload': p['payload'],
            },
        ];
    }
    return null;
  }

  Iterable<Map<String, Object?>> titled(String title) =>
      pending.values.where((p) => p['title'] == title);
}

User userWith(Timetable timetable) => User(
  profile: ToOne<Profile>(),
  attendance: ToMany<Attendance>(),
  timetable: ToOne<Timetable>(target: timetable),
  examSchedule: ToMany<ExamSchedule>(),
  marks: ToMany<Mark>(),
  capstoneAttendance: ToOne<CapstoneAttendance>(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeNotifications os;

  // A class every day of the week at 23:58, so there's always one ahead.
  final everyDay = timetableOf({
    for (final d in [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ])
      d: [slot('CSE1001', 'A1', '23:58', courseName: 'Problem Solving')],
  });

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    os = _FakeNotifications();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          os.handle,
        );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('schedules dated one-off reminders for the coming week', () async {
    await NotificationService.scheduleTimetableNotifications(
      user: userWith(everyDay),
      prefs: UserPreferences(timetableNotificationDelay: 1),
    );
    final classes = os.titled('📅 Class Starting Soon').toList();
    // Today's 23:57 reminder may already be past when this runs.
    expect(classes.length, inInclusiveRange(6, 7));
    for (final c in classes) {
      expect(c['payload'], 'class_reminder');
      // No weekly repeat: that is what made them fire on holidays.
      expect(c.containsKey('matchDateTimeComponents'), isFalse);
    }
  });

  // Reminders from before this change repeat weekly and carry no payload. Left
  // alone, they'd keep firing on holidays beside the new ones.
  test('replaces old weekly reminders and leaves exam reminders', () async {
    os.pending[1] = {
      'id': 1,
      'title': '📅 Class Starting Soon',
      'payload': '',
      'matchDateTimeComponents': 1,
    };
    os.pending[2] = {
      'id': 2,
      'title': '📢 Exam Reminder: Problem Solving',
      'payload': '',
    };

    await NotificationService.scheduleTimetableNotifications(
      user: userWith(everyDay),
      prefs: UserPreferences(timetableNotificationDelay: 1),
    );

    expect(os.pending.containsKey(1), isFalse);
    expect(os.pending.containsKey(2), isTrue);
  });

  test('rescheduling twice leaves one set, not two', () async {
    final prefs = UserPreferences(timetableNotificationDelay: 1);
    await NotificationService.scheduleTimetableNotifications(
      user: userWith(everyDay),
      prefs: prefs,
    );
    final first = os.pending.length;
    await NotificationService.scheduleTimetableNotifications(
      user: userWith(everyDay),
      prefs: prefs,
    );
    expect(os.pending.length, first);
  });

  test('turned off, it cancels and schedules nothing', () async {
    await NotificationService.scheduleTimetableNotifications(
      user: userWith(everyDay),
      prefs: UserPreferences(timetableNotificationDelay: 1),
    );
    await NotificationService.scheduleTimetableNotifications(
      user: userWith(everyDay),
      prefs: UserPreferences(isTimetableNotificationsEnabled: false),
    );
    expect(os.titled('📅 Class Starting Soon'), isEmpty);
  });
}
