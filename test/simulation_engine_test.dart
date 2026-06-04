import 'package:flutter_test/flutter_test.dart';
import 'package:vitalshield_ai/features/simulation/domain/services/simulation_engine.dart';
import 'package:vitalshield_ai/features/simulation/domain/models/simulation_model.dart';

void main() {
  group('SimulationEngine Tests', () {
    late SimulationEngine engine;

    setUp(() {
      engine = SimulationEngine();
    });

    test('default simulation with balanced inputs calculates high projected score', () async {
      const input = SimulationInput(
        sleepHours: 8.0,
        steps: 8000,
        consistencyLevel: 80.0,
        routineQuality: 80.0,
      );

      final result = await engine.simulate(input);

      expect(result.projectedWellnessScore, greaterThanOrEqualTo(80));
      expect(result.observations, isNotEmpty);
      expect(result.trendShifts['Sleep Wellness'], contains('Improving'));
      expect(result.trendShifts['Activity Wellness'], contains('Improving'));
    });

    test('low-input scenario calculates lower projected score', () async {
      const input = SimulationInput(
        sleepHours: 5.0,
        steps: 2000,
        consistencyLevel: 30.0,
        routineQuality: 30.0,
      );

      final result = await engine.simulate(input);

      expect(result.projectedWellnessScore, lessThan(65));
      expect(result.trendShifts['Sleep Wellness'], contains('Needs Attention'));
      expect(result.trendShifts['Activity Wellness'], contains('Needs Attention'));
    });

    test('age-aware simulation (senior thresholds)', () async {
      // For seniors, sleepHours 6.5 and steps 4000 are the positive thresholds
      const seniorInput = SimulationInput(
        sleepHours: 6.5,
        steps: 4000,
        consistencyLevel: 75.0,
        routineQuality: 75.0,
      );

      // Wise & Well/Senior is the category name for senior citizen
      final result = await engine.simulate(seniorInput, ageCategory: 'Senior Citizen');

      expect(result.projectedWellnessScore, greaterThanOrEqualTo(75));
      // Trend shifts should be positive/improving for seniors at these thresholds
      expect(result.trendShifts['Sleep Wellness'], contains('Improving'));
      expect(result.trendShifts['Activity Wellness'], contains('Improving'));

      // If we do the same input for adult (thresholds 7.0 / 5000), it should be Needs Attention
      final adultResult = await engine.simulate(seniorInput, ageCategory: 'Adult');
      expect(adultResult.trendShifts['Sleep Wellness'], contains('Needs Attention'));
      expect(adultResult.trendShifts['Activity Wellness'], contains('Needs Attention'));
    });
  });
}
