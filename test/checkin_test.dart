import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/core/constants/metric_ranges.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/checkin/data/local/checkin_storage.dart';
import 'package:vitalshield_ai/features/checkin/presentation/providers/checkin_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyCheckinModel Tests', () {
    test('toJson and fromJson should parse correctly', () {
      final now = DateTime.now();
      final checkin = DailyCheckinModel(
        id: 'test_123',
        userId: 'user_abc',
        heartRate: 72,
        systolic: 120,
        diastolic: 80,
        glucose: 85.5,
        steps: 8000,
        sleepHours: 7.5,
        timestamp: now,
      );

      final json = checkin.toJson();
      expect(json['id'], 'test_123');
      expect(json['user_id'], 'user_abc');
      expect(json['heart_rate'], 72);
      expect(json['systolic'], 120);
      expect(json['diastolic'], 80);
      expect(json['glucose'], 85.5);
      expect(json['steps'], 8000);
      expect(json['sleep_hours'], 7.5);
      expect(json['timestamp'], now.toIso8601String());

      final parsed = DailyCheckinModel.fromJson(json);
      expect(parsed.id, checkin.id);
      expect(parsed.userId, checkin.userId);
      expect(parsed.heartRate, checkin.heartRate);
      expect(parsed.systolic, checkin.systolic);
      expect(parsed.diastolic, checkin.diastolic);
      expect(parsed.glucose, checkin.glucose);
      expect(parsed.steps, checkin.steps);
      expect(parsed.sleepHours, checkin.sleepHours);
      expect(parsed.bloodPressureDisplay, '120/80');
    });

    test('bloodPressureDisplay should handle nulls gracefully', () {
      const checkin = DailyCheckinModel();
      expect(checkin.bloodPressureDisplay, '--');
    });

    test('copyWith should copy properties correctly', () {
      const checkin = DailyCheckinModel(heartRate: 70);
      final updated = checkin.copyWith(heartRate: 80, steps: 5000);
      expect(updated.heartRate, 80);
      expect(updated.steps, 5000);
    });
  });

  group('CheckinStorage Tests', () {
    late CheckinStorage storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = CheckinStorage();
    });

    test('saveCheckin and getLatestCheckin should persist and retrieve data', () async {
      final now = DateTime.now();
      final checkin1 = DailyCheckinModel(
        id: '1',
        heartRate: 70,
        systolic: 115,
        diastolic: 75,
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
      );
      final checkin2 = DailyCheckinModel(
        id: '2',
        heartRate: 80,
        systolic: 120,
        diastolic: 80,
        timestamp: now,
      );

      await storage.saveCheckin(checkin1);
      await storage.saveCheckin(checkin2);

      final latest = await storage.getLatestCheckin();
      expect(latest, isNotNull);
      expect(latest!.id, '2');
      expect(latest.heartRate, 80);

      final hasCheckedIn = await storage.hasCheckedInToday();
      expect(hasCheckedIn, isTrue);

      final all = await storage.getAllCheckins();
      expect(all.length, 2);

      await storage.clearAll();
      final afterClear = await storage.getAllCheckins();
      expect(afterClear.isEmpty, isTrue);
    });

    test('saving a second checkin on the same day should overwrite the existing one', () async {
      final now = DateTime.now();
      final checkin1 = DailyCheckinModel(
        id: '1',
        heartRate: 70,
        systolic: 115,
        diastolic: 75,
        timestamp: now,
      );
      final checkin2 = DailyCheckinModel(
        id: '2',
        heartRate: 85,
        systolic: 120,
        diastolic: 80,
        timestamp: now,
      );

      await storage.saveCheckin(checkin1);
      await storage.saveCheckin(checkin2);

      final all = await storage.getAllCheckins();
      expect(all.length, 1);
      expect(all.first.id, '2');
      expect(all.first.heartRate, 85);
    });
  });

  group('CheckinNotifier Validation Tests', () {
    late CheckinNotifier notifier;

    setUp(() {
      notifier = CheckinNotifier();
    });

    test('initial state values', () {
      expect(notifier.state.currentStep, 0);
      expect(notifier.state.steps, 8000);
      expect(notifier.state.sleepHours, 7.0);
      expect(notifier.state.validationError, isNull);
    });

    test('validate steps with incorrect inputs', () {
      // Step 0: Heart Rate
      notifier.setHeartRate(null);
      expect(notifier.validateCurrentStep(), isFalse);
      expect(notifier.state.validationError, isNotNull);

      notifier.setHeartRate(MetricRanges.minHeartRate - 5);
      expect(notifier.validateCurrentStep(), isFalse);

      notifier.setHeartRate(75);
      expect(notifier.validateCurrentStep(), isTrue);
      expect(notifier.state.validationError, isNull);
    });

    testWidgets('CheckinNotifier double-tap and duplicate submission protection test', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = CheckinNotifier();

      // Verify initial state
      expect(notifier.state.currentStep, 0);

      // Set valid values for all steps
      notifier.setHeartRate(75);
      
      // Step 0 -> Step 1
      await notifier.nextStep(() {});
      expect(notifier.state.currentStep, 1);
      
      // Set BP
      notifier.setBloodPressure(120, 80);
      // Step 1 -> Step 2
      await notifier.nextStep(() {});
      expect(notifier.state.currentStep, 2);
      
      // Set Glucose
      notifier.setGlucose(90.0);
      // Step 2 -> Step 3
      await notifier.nextStep(() {});
      expect(notifier.state.currentStep, 3);
      
      // Steps are already pre-set to 8000
      // Step 3 -> Step 4
      await notifier.nextStep(() {});
      expect(notifier.state.currentStep, 4);

      // Now we are at the final step (Sleep)
      // Trigger submission multiple times in rapid succession
      bool completionCalled1 = false;
      bool completionCalled2 = false;

      // Start submission 1
      final future1 = notifier.nextStep(() {
        completionCalled1 = true;
      });

      // Try starting submission 2 instantly
      final future2 = notifier.nextStep(() {
        completionCalled2 = true;
      });

      // Instantly isAnalyzing should be true
      expect(notifier.state.isAnalyzing, isTrue);
      expect(notifier.state.isCompleted, isFalse);

      // Attempting previousStep or nextStep again should do nothing
      notifier.previousStep();
      expect(notifier.state.currentStep, 4);

      // Let the delayed transitions run
      // First delayed duration in submitCheckin: 2500ms
      await tester.pump(const Duration(milliseconds: 2500));
      // Second delayed duration (emotional completion feedback): 1200ms
      await tester.pump(const Duration(milliseconds: 1200));

      // Await the futures to complete
      await future1;
      await future2;

      // Verify state is completed
      expect(notifier.state.isCompleted, isFalse); // It resets to CheckinState() after completion callback
      
      // The completion callback for the first call should be executed
      expect(completionCalled1, isTrue);
      // The second call should have bypassed due to guard, so callback2 remains false
      expect(completionCalled2, isFalse);
    });
  });
}
