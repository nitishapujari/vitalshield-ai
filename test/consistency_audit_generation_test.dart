import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/assistant/domain/services/response_generator.dart';
import 'package:vitalshield_ai/features/analytics/domain/services/analytics_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'generates and serializes Dart prediction and assistant outputs for consistency audit',
      () async {
    // Skip on GitHub Actions
    if (Platform.environment.containsKey('GITHUB_ACTIONS')) {
      return;
    }

    SharedPreferences.setMockInitialValues({});
    final generator = ResponseGenerator();

    final history = [
      DailyCheckinModel(
        timestamp: DateTime.parse('2026-06-03T10:00:00Z'),
        sleepHours: 5.5,
        steps: 3000,
        heartRate: 72,
        systolic: 120,
        diastolic: 80,
        glucose: 90.0,
      ),
    ];

    final jsonFile = File(
      'C:/Users/Nitisha Pujari/.gemini/antigravity-ide/brain/3df7209c-b1bb-4197-9b7f-b70aaade6284/scratch/backend_prediction.json',
    );

    if (!jsonFile.existsSync()) {
      fail('backend_prediction.json not found! Run python script first.');
    }

    final backendPrediction =
        jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

    final snapshot = PredictionSnapshotModel.fromMap(backendPrediction);

    final report = AnalyticsEngine.generateReport(
      checkins: history,
      predictions: [snapshot],
      ageCategory: 'Adult',
    );

    final context = {
      'prediction': snapshot.toMap(),
      'hasCheckinData': true,
      'hasPredictonData': true,
      'userProfile': {
        'name': 'Sarah',
        'age': 25,
        'ageCategory': 'Adult',
        'gender': 'Female',
      },
      'checkin': {
        'sleepHours': history[0].sleepHours,
        'steps': history[0].steps,
        'heartRate': history[0].heartRate,
        'systolic': history[0].systolic,
        'diastolic': history[0].diastolic,
        'glucose': history[0].glucose,
        'timestamp': history[0].timestamp?.toIso8601String(),
      },
    };

    final assistantOfflineGeneral =
        generator.generate('how can I improve?', context);

    final assistantOfflineSleep =
        generator.generate('tell me about my sleep', context);

    final assistantOfflineActivity =
        generator.generate('tell me about my activity', context);

    final output = {
      'snapshot': snapshot.toMap(),
      'analyticsInsight': report.insightText,
      'assistantOffline': {
        'generalImprovement': assistantOfflineGeneral,
        'sleepQuery': assistantOfflineSleep,
        'activityQuery': assistantOfflineActivity,
      }
    };

    final file = File(
      'C:/Users/Nitisha Pujari/.gemini/antigravity-ide/brain/3df7209c-b1bb-4197-9b7f-b70aaade6284/scratch/dart_audit_output.json',
    );

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    file.writeAsStringSync(jsonEncode(output));
  });
}