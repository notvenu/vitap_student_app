import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_calculator_sheet.dart';

Future<void> pumpSheet(WidgetTester tester, {int? attended, int? total}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttendanceCalculatorSheet(attended: attended, total: total),
        ),
      ),
    );

Future<void> enter(WidgetTester tester, String attended, String total) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Classes attended'),
    attended,
  );
  await tester.enterText(find.widgetWithText(TextField, 'Classes held'), total);
  await tester.pump();
}

void main() {
  testWidgets('asks for both numbers before saying anything', (tester) async {
    await pumpSheet(tester);
    expect(
      find.text('Enter both numbers to see where you stand.'),
      findsOneWidget,
    );
  });

  testWidgets('starts from the course it was opened on', (tester) async {
    await pumpSheet(tester, attended: 28, total: 30);
    expect(find.text('93.33%'), findsOneWidget);
    expect(
      find.text('You can miss 7 classes in a row and stay at 75%.'),
      findsOneWidget,
    );
  });

  testWidgets('below 75%, says how many to attend', (tester) async {
    await pumpSheet(tester);
    await enter(tester, '20', '30');
    expect(find.text('66.67%'), findsOneWidget);
    expect(
      find.text('Attend 10 classes in a row to reach 75%.'),
      findsOneWidget,
    );
  });

  testWidgets('exactly at 75%, warns that one miss drops it', (tester) async {
    await pumpSheet(tester);
    await enter(tester, '30', '40');
    expect(find.textContaining('right at 75%'), findsOneWidget);
  });

  testWidgets('rejects more attended than held', (tester) async {
    await pumpSheet(tester);
    await enter(tester, '31', '30');
    expect(find.text("Attended can't be more than held"), findsOneWidget);
  });
}
