import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vit_ap_student_app/core/common/widget/app_input_decoration.dart';
import 'package:vit_ap_student_app/features/attendance/utils/attendance_projection.dart';

/// Opens the calculator, optionally starting from a course's own numbers.
Future<void> showAttendanceCalculator(
  BuildContext context, {
  int? attended,
  int? total,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AttendanceCalculatorSheet(attended: attended, total: total),
  );
}

/// Try-your-own-numbers attendance maths: the percentage, and how many classes
/// in a row it takes to reach 75% or can be missed while staying there.
class AttendanceCalculatorSheet extends StatefulWidget {
  const AttendanceCalculatorSheet({super.key, this.attended, this.total});

  final int? attended;
  final int? total;

  @override
  State<AttendanceCalculatorSheet> createState() =>
      _AttendanceCalculatorSheetState();
}

class _AttendanceCalculatorSheetState extends State<AttendanceCalculatorSheet> {
  late final TextEditingController _attended = TextEditingController(
    text: widget.attended?.toString() ?? '',
  );
  late final TextEditingController _total = TextEditingController(
    text: widget.total?.toString() ?? '',
  );

  @override
  void dispose() {
    _attended.dispose();
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final int? attended = int.tryParse(_attended.text);
    final int? total = int.tryParse(_total.text);
    final bool tooMany = attended != null && total != null && attended > total;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance calculator', style: tt.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field(_attended, 'Classes attended')),
              const SizedBox(width: 12),
              Expanded(child: _field(_total, 'Classes held')),
            ],
          ),
          const SizedBox(height: 16),
          if (tooMany)
            Text(
              "Attended can't be more than held",
              style: tt.bodyMedium?.copyWith(color: cs.error),
            )
          else if (attended != null && total != null && total > 0)
            _Result(attended: attended, total: total)
          else
            Text(
              'Enter both numbers to see where you stand.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: appInputDecoration(context, labelText: label),
    onChanged: (_) => setState(() {}),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.attended, required this.total});

  final int attended;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final double percent = attendancePercent(attended, total);
    final int needed = classesNeededFor75(attended, total);
    final int skippable = classesSkippableAt75(attended, total);

    final String verdict = needed > 0
        ? 'Attend $needed ${_classes(needed)} in a row to reach 75%.'
        : skippable > 0
        ? 'You can miss $skippable ${_classes(skippable)} in a row and stay at 75%.'
        : "You're right at 75%. Missing the next class drops you below it.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${percent.toStringAsFixed(2)}%',
          style: tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: needed > 0 ? cs.error : cs.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(verdict, style: tt.bodyLarge),
      ],
    );
  }
}

String _classes(int n) => n == 1 ? 'class' : 'classes';
