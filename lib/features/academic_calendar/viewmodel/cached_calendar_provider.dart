import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/models/academic_calendar.dart';
import 'package:vit_ap_student_app/features/academic_calendar/repository/academic_calendar_repository.dart';

/// The stored academic calendar, for screens that only read it.
///
/// Auto-disposed, so each screen re-reads on open and never shows a calendar
/// left over from before a refresh or a logout. The read is local and cheap.
final cachedCalendarProvider = FutureProvider.autoDispose<AcademicCalendar?>(
  (ref) => cachedCalendarForSavedSemester(),
);
