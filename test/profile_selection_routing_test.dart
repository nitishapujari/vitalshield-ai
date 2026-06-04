import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Authenticated with 1 profile routes directly to Dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'is_authenticated': true,
      'local_profiles': jsonEncode([
        {
          'id': 'profile_1',
          'name': 'Sarah',
          'gender': 'Female',
          'dob': '1998-05-28T00:00:00.000',
        }
      ]),
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: VitalShieldApp(),
      ),
    );

    // Initial frame (Splash screen starts)
    await tester.pump();

    // Pump past the splash screen navigation delay (3.5s total)
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify it navigated past profile selection straight to Dashboard
    expect(find.text('Who is tracking wellness today?'), findsNothing);
    
    // Clear any pending timers/microtasks scheduled during build/animation init
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Authenticated with multiple profiles routes to Profile Selection screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'is_authenticated': true,
      'local_profiles': jsonEncode([
        {
          'id': 'profile_1',
          'name': 'Sarah',
          'gender': 'Female',
          'dob': '1998-05-28T00:00:00.000',
        },
        {
          'id': 'profile_2',
          'name': 'Ria',
          'gender': 'Female',
          'dob': '2019-05-28T00:00:00.000',
        }
      ]),
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: VitalShieldApp(),
      ),
    );

    // Initial frame
    await tester.pump();

    // Pump past splash screen navigation delay
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify it navigated to Profile Selection screen
    expect(find.text('Who is tracking wellness today?'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(find.text('Ria'), findsOneWidget);
    
    // Clear any pending timers/microtasks scheduled during build/animation init
    await tester.pump(const Duration(seconds: 2));
  });
}
