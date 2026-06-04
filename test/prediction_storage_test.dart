import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/predictions/data/prediction_storage.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PredictionStorage Tests', () {
    late PredictionStorage storage;
    final now = DateTime.now();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = PredictionStorage();
    });

    test('savePredictionSnapshot appends first prediction snapshot', () async {
      final snapshot = PredictionSnapshotModel(
        id: 'pred_1',
        timestamp: now,
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      await storage.savePredictionSnapshot(snapshot);

      final history = await storage.getPredictionHistory();
      expect(history.length, 1);
      expect(history.first.id, 'pred_1');
    });

    test('savePredictionSnapshot deduplicates identical predictions on same day', () async {
      final snapshot1 = PredictionSnapshotModel(
        id: 'pred_1',
        timestamp: now,
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      // Slightly later timestamp, same day, same values
      final snapshot2 = PredictionSnapshotModel(
        id: 'pred_2',
        timestamp: now.add(const Duration(minutes: 5)),
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      await storage.savePredictionSnapshot(snapshot1);
      await storage.savePredictionSnapshot(snapshot2);

      final history = await storage.getPredictionHistory();
      // Should not duplicate
      expect(history.length, 1);
      expect(history.first.id, 'pred_1');
    });

    test('savePredictionSnapshot replaces prediction snapshot on same day if contents differ', () async {
      final snapshot1 = PredictionSnapshotModel(
        id: 'pred_1',
        timestamp: now,
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      // Same day, different values (e.g. check-in was updated)
      final snapshot2 = PredictionSnapshotModel(
        id: 'pred_2',
        timestamp: now.add(const Duration(minutes: 5)),
        overallWellnessScore: 85,
        categories: [],
        primaryInsight: 'Updated patterns',
      );

      await storage.savePredictionSnapshot(snapshot1);
      await storage.savePredictionSnapshot(snapshot2);

      final history = await storage.getPredictionHistory();
      // Should replace the previous entry for the day instead of appending
      expect(history.length, 1);
      expect(history.first.id, 'pred_2');
      expect(history.first.overallWellnessScore, 85);
      expect(history.first.primaryInsight, 'Updated patterns');
    });

    test('savePredictionSnapshot appends predictions on different days', () async {
      final snapshot1 = PredictionSnapshotModel(
        id: 'pred_1',
        timestamp: now.subtract(const Duration(days: 1)),
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      final snapshot2 = PredictionSnapshotModel(
        id: 'pred_2',
        timestamp: now,
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      await storage.savePredictionSnapshot(snapshot1);
      await storage.savePredictionSnapshot(snapshot2);

      final history = await storage.getPredictionHistory();
      expect(history.length, 2);
      expect(history[0].id, 'pred_1');
      expect(history[1].id, 'pred_2');
    });

    test('getPredictionHistory cleans up existing consecutive duplicates and persists changes', () async {
      final snapshot1 = PredictionSnapshotModel(
        id: 'pred_1',
        timestamp: now,
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      final snapshot2 = PredictionSnapshotModel(
        id: 'pred_2',
        timestamp: now.add(const Duration(minutes: 5)),
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      final snapshot3 = PredictionSnapshotModel(
        id: 'pred_3',
        timestamp: now.add(const Duration(minutes: 10)),
        overallWellnessScore: 80,
        categories: [],
        primaryInsight: 'Healthy patterns',
      );

      // Manually set initial mock values with duplicates directly to SharedPreferences simulating legacy data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('prediction_snapshot_history', [
        snapshot1.toJson(),
        snapshot2.toJson(),
        snapshot3.toJson(),
      ]);

      // Retrieve history (should perform clean-up)
      final history = await storage.getPredictionHistory();
      expect(history.length, 1);
      expect(history.first.id, 'pred_1');

      // Verify that changes were persisted to storage
      final storedList = prefs.getStringList('prediction_snapshot_history') ?? [];
      expect(storedList.length, 1);
    });
  });
}
