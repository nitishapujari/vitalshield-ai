/// Represents the wellness rhythm cycle data for a user.
class CycleData {
  final DateTime? lastCycleStart;
  final int averageCycleLength;
  final bool isTrackingEnabled;

  const CycleData({
    this.lastCycleStart,
    this.averageCycleLength = 28,
    this.isTrackingEnabled = false,
  });

  CycleData copyWith({
    DateTime? lastCycleStart,
    int? averageCycleLength,
    bool? isTrackingEnabled,
  }) {
    return CycleData(
      lastCycleStart: lastCycleStart ?? this.lastCycleStart,
      averageCycleLength: averageCycleLength ?? this.averageCycleLength,
      isTrackingEnabled: isTrackingEnabled ?? this.isTrackingEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastCycleStart': lastCycleStart?.toIso8601String(),
      'averageCycleLength': averageCycleLength,
      'isTrackingEnabled': isTrackingEnabled,
    };
  }

  factory CycleData.fromJson(Map<String, dynamic> json) {
    return CycleData(
      lastCycleStart: json['lastCycleStart'] != null
          ? DateTime.parse(json['lastCycleStart'] as String)
          : null,
      averageCycleLength: json['averageCycleLength'] as int? ?? 28,
      isTrackingEnabled: json['isTrackingEnabled'] as bool? ?? false,
    );
  }
}

/// User-facing names for wellness rhythm phases.
enum CyclePhaseLabel {
  restAndRecovery, // days 1-5: rest & gentle recovery
  activePhase,      // days 6-13: rising energy
  peakEnergy,       // days 14-16: highest energy
  windDown,         // days 17-28+: gradual recovery
}

/// Contextual wellness state for cycle adaptation.
class CycleContext {
  final CyclePhaseLabel phaseLabel;
  final int daysIntoCycle;
  final bool isLowerEnergyPhase;

  const CycleContext({
    required this.phaseLabel,
    required this.daysIntoCycle,
    required this.isLowerEnergyPhase,
  });
}
