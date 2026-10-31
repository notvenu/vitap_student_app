import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/academic_calendar/view/pages/academic_calendar_page.dart';
import 'package:vit_ap_student_app/features/academic_calendar/viewmodel/cached_calendar_provider.dart';
import 'package:vit_ap_student_app/features/attendance/utils/attendance_projection.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_calculator_sheet.dart';

/// Where this course ends up by the last instructional day: how many classes
/// are left once holidays and exams are taken out, and how many of them can
/// be missed while finishing at 75%.
class AttendanceProjectionCard extends ConsumerWidget {
  const AttendanceProjectionCard({super.key, required this.course});

  final Attendance course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final Timetable? timetable = ref
        .watch(currentUserProvider)
        ?.timetable
        .target;
    final calendarState = ref.watch(cachedCalendarProvider);
    if (timetable == null || !calendarState.hasValue) {
      return const SizedBox.shrink();
    }

    final int attended = int.tryParse(course.attendedClasses.trim()) ?? 0;
    final int total = int.tryParse(course.totalClasses.trim()) ?? 0;

    final calendar = calendarState.value;
    final DateTime today = DateTime.now();
    final DateTime? lastDay = lastInstructionalDay(calendar);

    final List<Widget> children;
    if (calendar == null) {
      children = [
        Text(
          'See how many classes you can miss before the semester ends.',
          style: tt.bodyLarge,
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AcademicCalendarPage(),
              ),
            );
            ref.invalidate(cachedCalendarProvider);
          },
          child: const Text('Load academic calendar'),
        ),
      ];
    } else if (lastDay == null || !lastDay.isAfter(today)) {
      children = [
        Text(
          'No classes left on this semester\'s calendar.',
          style: tt.bodyLarge,
        ),
      ];
    } else {
      final projection = projectAttendance(
        course: course,
        timetable: timetable,
        noClass: noClassDays(calendar),
        today: today,
        lastDay: lastDay,
      );
      children = [
        ..._verdict(projection, tt, cs),
        const SizedBox(height: 8),
        Text(
          'Counts classes until ${DateFormat('d MMM').format(lastDay)}, '
          'skipping holidays and exams. It only knows the attendance VTOP has '
          'recorded so far: classes that haven\'t been uploaded yet can change '
          'this.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By the end of the semester', style: tt.titleMedium),
          const SizedBox(height: 8),
          ...children,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showAttendanceCalculator(
                context,
                attended: attended,
                total: total,
              ),
              child: const Text('Try other numbers'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _verdict(
    AttendanceProjection projection,
    TextTheme tt,
    ColorScheme cs,
  ) {
    final int left = projection.remaining;
    if (left == 0) {
      return [
        Text(
          'No more classes of this course on your timetable.',
          style: tt.bodyLarge,
        ),
      ];
    }

    final String leftText = '$left ${left == 1 ? 'class' : 'classes'} left';
    if (projection.bestPossible < 75) {
      return [
        Text(
          "75% can't be reached",
          style: tt.headlineSmall?.copyWith(color: cs.error),
        ),
        Text(
          '$leftText. Attending every one ends at '
          '${projection.bestPossible.toStringAsFixed(1)}%.',
          style: tt.bodyLarge,
        ),
      ];
    }
    if (projection.canSkip == 0) {
      return [
        Text('Attend every class', style: tt.headlineSmall),
        Text(
          '$leftText, and you need all of them for 75%.',
          style: tt.bodyLarge,
        ),
      ];
    }
    return [
      Text(
        'Can miss ${projection.canSkip}',
        style: tt.headlineSmall?.copyWith(color: cs.primary),
      ),
      Text('$leftText, and you\'d still finish at 75%.', style: tt.bodyLarge),
    ];
  }
}
