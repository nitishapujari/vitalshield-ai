import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:vitalshield_ai/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:vitalshield_ai/models/user_model.dart';
import 'package:vitalshield_ai/navigation/bottom_nav.dart';

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

  Widget buildTestWidget({required String currentPath, required UserModel user}) {
    final mockState = DashboardState(
      user: user,
      hasCheckedInToday: false,
      isLoading: false,
    );

    return ProviderScope(
      overrides: [
        dashboardProvider.overrideWith((ref) => MockDashboardNotifier(mockState)),
      ],
      child: MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNav(currentPath: currentPath),
          body: const SizedBox(),
        ),
      ),
    );
  }

  testWidgets('BottomNav displays More tab and opens sheet with gender constraints (Male)', (WidgetTester tester) async {
    const user = UserModel(id: '1', name: 'John', age: 30, email: 'john@test.com', gender: 'Male');

    await tester.pumpWidget(buildTestWidget(currentPath: '/dashboard', user: user));
    await tester.pumpAndSettle();

    // Verify BottomNav items exist
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Check-In'), findsOneWidget);
    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    // Tap "More"
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle(); // Wait for bottom sheet to open

    // Verify bottom sheet items are displayed
    expect(find.text('More Options'), findsOneWidget);
    expect(find.text('Health Journey'), findsOneWidget);
    expect(find.text('Health Overview'), findsOneWidget);
    expect(find.text('Predictions'), findsOneWidget);
    expect(find.text('Future Simulation'), findsOneWidget);
    expect(find.text('Wellness'), findsOneWidget);

    // Verify "Wellness Rhythm" is NOT displayed for a Male user
    expect(find.text('Wellness Rhythm'), findsNothing);
  });

  testWidgets('BottomNav opens sheet and shows Wellness Rhythm for Female', (WidgetTester tester) async {
    const user = UserModel(id: '2', name: 'Jane', age: 28, email: 'jane@test.com', gender: 'Female');

    await tester.pumpWidget(buildTestWidget(currentPath: '/dashboard', user: user));
    await tester.pumpAndSettle();

    // Tap "More"
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    // Verify "Wellness Rhythm" IS displayed for a Female user
    expect(find.text('Wellness Rhythm'), findsOneWidget);
  });

  testWidgets('BottomNav highlights More tab when sub-path is active', (WidgetTester tester) async {
    const user = UserModel(id: '2', name: 'Jane', age: 28, email: 'jane@test.com', gender: 'Female');

    // /predictions is a sub-path of More
    await tester.pumpWidget(buildTestWidget(currentPath: '/predictions', user: user));
    await tester.pumpAndSettle();

    // Tap "More" to open sheet
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    // Verify Predictions shows active (it will have the LucideIcons.check icon instead of chevron_right)
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });
}
