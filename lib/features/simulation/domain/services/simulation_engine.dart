import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../checkin/domain/models/daily_checkin_model.dart';
import '../models/simulation_model.dart';
import '../../../../services/api_service.dart';

/// Service to handle future wellness projections based on user-provided scenarios.
class SimulationEngine {
  bool _isBackendOffline = false;

  bool get isBackendOffline => _isBackendOffline;

  /// Simulates future wellness score and trends based on custom habit inputs.
  Future<SimulationResult> simulate(
    SimulationInput input, {
    List<DailyCheckinModel>? history,
    String? ageCategory,
  }) async {
    final isSenior = ageCategory == 'Senior' || ageCategory == 'Senior Citizen';
    
    // Default weights for score contribution:
    // Sleep: 30%, Activity/Steps: 25%, Consistency: 25%, Routine Quality: 20%
    
    // 1. Sleep score component (max 100)
    double sleepScore = 50.0;
    final sleepThreshold = isSenior ? 6.5 : 7.0;
    if (input.sleepHours >= sleepThreshold && input.sleepHours <= 9.0) {
      sleepScore = 90.0 + (input.sleepHours - sleepThreshold) * 5;
    } else if (input.sleepHours > 9.0) {
      sleepScore = 85.0 - (input.sleepHours - 9.0) * 10;
    } else {
      sleepScore = 40.0 + (input.sleepHours / sleepThreshold) * 20;
    }
    sleepScore = sleepScore.clamp(0, 100);

    // 2. Activity/Steps component (max 100)
    double activityScore = 50.0;
    final stepThreshold = isSenior ? 4000 : 5000;
    if (input.steps >= stepThreshold) {
      activityScore = 85.0 + ((input.steps - stepThreshold) / (15000 - stepThreshold) * 15);
    } else {
      activityScore = 40.0 + (input.steps / stepThreshold * 25);
    }
    activityScore = activityScore.clamp(0, 100);

    // 3. Consistency and Routine components (direct inputs)
    final consistencyScore = input.consistencyLevel.clamp(0.0, 100.0);
    final routineScore = input.routineQuality.clamp(0.0, 100.0);

    // Calculate final projected score
    double baseScore = (sleepScore * 0.3) +
        (activityScore * 0.25) +
        (consistencyScore * 0.25) +
        (routineScore * 0.20);
    int projectedScore = baseScore.round().clamp(0, 100);

    // Try backend if available
    _isBackendOffline = false;
    try {
      final apiBaseUrl = ApiService().baseUrl;
      final response = await http.post(
        Uri.parse('$apiBaseUrl/simulate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sleep_hours': input.sleepHours,
          'steps': input.steps,
          'consistency_level': input.consistencyLevel,
          'routine_quality': input.routineQuality,
          'is_senior': isSenior,
        }),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        projectedScore = data['projected_score'] ?? projectedScore;
      } else {
        _isBackendOffline = true;
      }
    } catch (_) {
      _isBackendOffline = true;
    }

    // Generate trend shifts and observations
    final trendShifts = <String, String>{};
    final observations = <SimulationObservation>[];

    // Sleep trend shift
    if (input.sleepHours >= sleepThreshold) {
      trendShifts['Sleep Wellness'] = 'Needs Attention → Improving';
      observations.add(const SimulationObservation(
        title: 'Restorative Sleep Path',
        description: 'Maintaining a stable sleep window supports neurocognitive recovery and cellular rest.',
      ));
    } else {
      trendShifts['Sleep Wellness'] = 'Stable → Needs Attention';
      observations.add(const SimulationObservation(
        title: 'Rest Considerations',
        description: 'A minor deficit in sleep hours may accumulate wellness fatigue over time. Consider a steady wind-down window.',
        isPositive: false,
      ));
    }

    // Activity trend shift
    if (input.steps >= stepThreshold) {
      trendShifts['Activity Wellness'] = 'Needs Attention → Improving';
      observations.add(const SimulationObservation(
        title: 'Consistent Movement Benefit',
        description: 'Active steps stimulate vascular circulation and metabolic balance naturally.',
      ));
    } else {
      trendShifts['Activity Wellness'] = 'Stable → Needs Attention';
      observations.add(const SimulationObservation(
        title: 'Activity Level Notice',
        description: 'Lower physical activity may lead to sluggish energy trends. Gentle walking can gently lift this baseline.',
        isPositive: false,
      ));
    }

    // Consistency & Routine shifts
    if (input.consistencyLevel >= 70) {
      observations.add(const SimulationObservation(
        title: 'Consistency Outlook',
        description: 'Strong daily habit consistency stabilizes your long-term wellness equilibrium.',
      ));
    }
    if (input.routineQuality >= 70) {
      observations.add(const SimulationObservation(
        title: 'Optimal Routine Balance',
        description: 'Curating a mindful daily routine helps buffer physiological stressors.',
      ));
    }

    // General summary based on score
    String summary = 'Your simulated habits indicate a steady path towards wellness balance.';
    if (projectedScore >= 85) {
      summary = 'An exceptional combination of restful sleep, steady activity, and routine consistency.';
    } else if (projectedScore < 65) {
      summary = 'Small adjustments in sleep consistency or daily movement could lift your overall wellness outlook.';
    }

    return SimulationResult(
      projectedWellnessScore: projectedScore,
      supportiveSummary: summary,
      observations: observations,
      trendShifts: trendShifts,
    );
  }
}
