import 'package:flutter_test/flutter_test.dart';
import 'package:atc_dashboard/src/app.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title is present
    expect(find.text('Air Traffic Control Dashboard'), findsOneWidget);
    
    // Verify that KPI cards are present (by checking for "Active Flights")
    expect(find.text('Active Flights'), findsOneWidget);
  });
}
