
/// Inputs for the Future Wellness Simulation.
class SimulationInput {
  final double sleepHours;
  final int steps;
  final double consistencyLevel; // 0 - 100
  final double routineQuality; // 0 - 100

  const SimulationInput({
    this.sleepHours = 7.0,
    this.steps = 5000,
    this.consistencyLevel = 50.0,
    this.routineQuality = 50.0,
  });

  SimulationInput copyWith({
    double? sleepHours,
    int? steps,
    double? consistencyLevel,
    double? routineQuality,
  }) {
    return SimulationInput(
      sleepHours: sleepHours ?? this.sleepHours,
      steps: steps ?? this.steps,
      consistencyLevel: consistencyLevel ?? this.consistencyLevel,
      routineQuality: routineQuality ?? this.routineQuality,
    );
  }
}

/// A specific simulation observation.
class SimulationObservation {
  final String title;
  final String description;
  final bool isPositive;

  const SimulationObservation({
    required this.title,
    required this.description,
    this.isPositive = true,
  });
}

/// The result of the wellness simulation.
class SimulationResult {
  final int projectedWellnessScore;
  final String supportiveSummary;
  final List<SimulationObservation> observations;
  final Map<String, String> trendShifts; // Category -> shift text (e.g. "Sleep: Stable -> Improving")

  const SimulationResult({
    required this.projectedWellnessScore,
    required this.supportiveSummary,
    required this.observations,
    required this.trendShifts,
  });
}
