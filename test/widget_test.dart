import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('VitalShield AI app starts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VitalShieldApp(),
      ),
    );
    
    // Allow the router to resolve the initial route and push the splash screen
    await tester.pump();

    // Verify app launches without error
    expect(find.text('VitalShield AI'), findsOneWidget);
    
    // Pump past the splash screen navigation timer (3.5s) to trigger the timer
    await tester.pump(const Duration(milliseconds: 3500));
    // Pump extra frames to allow the router transition and old page disposal to finish
    await tester.pump(const Duration(milliseconds: 500));
  });
}
