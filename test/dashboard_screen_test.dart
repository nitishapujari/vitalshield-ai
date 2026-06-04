import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:vitalshield_ai/features/dashboard/dashboard_screen.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/models/user_model.dart';
import 'package:vitalshield_ai/services/api_service.dart';

class MockDashboardNotifier extends StateNotifier<DashboardState> implements DashboardNotifier {
  MockDashboardNotifier(DashboardState state) : super(state);

  @override
  Future<void> loadDashboardData() async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<void> injectTestData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DashboardScreen displays pending state when hasCheckedInToday is false', (WidgetTester tester) async {
    final mockState = DashboardState(
      user: const UserModel(id: '1', name: 'Nitisha', age: 25, email: 'nitisha@test.com'),
      latestCheckin: DailyCheckinModel(
        id: '1',
        heartRate: 70,
        systolic: 120,
        diastolic: 80,
        glucose: 90.0,
        sleepHours: 7.5,
        steps: 8000,
        timestamp: DateTime.now().subtract(const Duration(days: 2)), // 2 days ago
      ),
      healthScore: 85,
      primaryInsight: 'Previous insight',
      hasCheckedInToday: false,
      isLoading: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) => MockDashboardNotifier(mockState)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Score Card shows pending indicators
    expect(find.text('--'), findsAtLeast(2)); // Wellness score is '--', and card values are '--'
    expect(find.text('PENDING'), findsNWidgets(2));
    expect(find.text('Pending'), findsAtLeast(3)); // Status labels on the cards
    expect(find.text("Complete today's check-in to generate updated insights and compute your wellness score."), findsOneWidget);
    expect(find.text('Daily Check-In Pending'), findsOneWidget);
  });

  testWidgets('DashboardScreen displays today\'s details when hasCheckedInToday is true', (WidgetTester tester) async {
    final mockState = DashboardState(
      user: const UserModel(id: '1', name: 'Nitisha', age: 25, email: 'nitisha@test.com'),
      latestCheckin: DailyCheckinModel(
        id: '1',
        heartRate: 72,
        systolic: 118,
        diastolic: 78,
        glucose: 95.0,
        sleepHours: 8.0,
        steps: 10000,
        timestamp: DateTime.now(), // today
      ),
      healthScore: 92,
      primaryInsight: 'Great job staying active!',
      hasCheckedInToday: true,
      isLoading: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) => MockDashboardNotifier(mockState)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Score Card shows score
    expect(find.text('92'), findsOneWidget);
    expect(find.text('OPTIMAL'), findsOneWidget);
    // Verify wellness cards show values
    expect(find.text('72 BPM'), findsOneWidget);
    expect(find.text('118/78'), findsOneWidget);
    expect(find.text('95.0 mg/dL'), findsOneWidget);
    expect(find.text('8.0h'), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);
    expect(find.text('Great job staying active!'), findsOneWidget);
  });
}
