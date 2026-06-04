import 'package:flutter_test/flutter_test.dart';
import 'package:vitalshield_ai/features/wellness/domain/models/cycle_model.dart';
import 'package:vitalshield_ai/features/wellness/domain/services/cycle_engine.dart';

void main() {
  group('CycleEngine Tests', () {
    test('getCurrentContext returns null when tracking is disabled', () {
      const data = CycleData(isTrackingEnabled: false);
      final context = CycleEngine.getCurrentContext(data);
      expect(context, isNull);
    });

    test('getCurrentContext correctly identifies Rest & Recovery phase (Days 1-5)', () {
      final now = DateTime.now();
      // Cycle started 2 days ago -> Day 3
      final data = CycleData(
        isTrackingEnabled: true,
        lastCycleStart: now.subtract(const Duration(days: 2)),
        averageCycleLength: 28,
      );

      final context = CycleEngine.getCurrentContext(data);

      expect(context, isNotNull);
      expect(context!.phaseLabel, CyclePhaseLabel.restAndRecovery);
      expect(context.daysIntoCycle, 3);
      expect(context.isLowerEnergyPhase, isTrue);
      expect(CycleEngine.getLabelString(context.phaseLabel), 'Rest & Recovery');
      expect(CycleEngine.getPhaseAdvice(context.phaseLabel), contains('Prioritize gentle stretching'));
    });

    test('getCurrentContext correctly identifies Active Phase (Days 6-13)', () {
      final now = DateTime.now();
      // Cycle started 7 days ago -> Day 8
      final data = CycleData(
        isTrackingEnabled: true,
        lastCycleStart: now.subtract(const Duration(days: 7)),
        averageCycleLength: 28,
      );

      final context = CycleEngine.getCurrentContext(data);

      expect(context, isNotNull);
      expect(context!.phaseLabel, CyclePhaseLabel.activePhase);
      expect(context.daysIntoCycle, 8);
      expect(context.isLowerEnergyPhase, isFalse);
      expect(CycleEngine.getLabelString(context.phaseLabel), 'Active Phase');
    });

    test('getCurrentContext correctly identifies Peak Energy phase (Days 14-16)', () {
      final now = DateTime.now();
      // Cycle started 14 days ago -> Day 15
      final data = CycleData(
        isTrackingEnabled: true,
        lastCycleStart: now.subtract(const Duration(days: 14)),
        averageCycleLength: 28,
      );

      final context = CycleEngine.getCurrentContext(data);

      expect(context, isNotNull);
      expect(context!.phaseLabel, CyclePhaseLabel.peakEnergy);
      expect(context.daysIntoCycle, 15);
      expect(context.isLowerEnergyPhase, isFalse);
      expect(CycleEngine.getLabelString(context.phaseLabel), 'Peak Energy');
    });

    test('getCurrentContext correctly identifies Wind Down phase (Days 17-28)', () {
      final now = DateTime.now();
      // Cycle started 20 days ago -> Day 21
      final data = CycleData(
        isTrackingEnabled: true,
        lastCycleStart: now.subtract(const Duration(days: 20)),
        averageCycleLength: 28,
      );

      final context = CycleEngine.getCurrentContext(data);

      expect(context, isNotNull);
      expect(context!.phaseLabel, CyclePhaseLabel.windDown);
      expect(context.daysIntoCycle, 21);
      expect(context.isLowerEnergyPhase, isFalse); // Days 22+ are lower energy

      // Test day 24 (should be lower energy in wind down phase)
      final dataLate = CycleData(
        isTrackingEnabled: true,
        lastCycleStart: now.subtract(const Duration(days: 23)),
        averageCycleLength: 28,
      );
      final contextLate = CycleEngine.getCurrentContext(dataLate);
      expect(contextLate!.daysIntoCycle, 24);
      expect(contextLate.isLowerEnergyPhase, isTrue);
      expect(CycleEngine.getLabelString(contextLate.phaseLabel), 'Wind Down');
    });
  });
}
